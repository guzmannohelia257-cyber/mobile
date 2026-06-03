import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:app_emergencias/theme/app_colors.dart';

import '../services/tecnico_asignaciones_service.dart';

/// Vista de ruta estilo "delivery" para el tecnico.
///
/// Muestra la ubicacion del cliente, la posicion propia del tecnico en vivo
/// (GPS del dispositivo), la ruta optima por calles entre ambos (OSRM) y el
/// tiempo/distancia estimados. La pantalla la abre el propio tecnico mientras
/// se dirige al cliente, por eso la posicion del tecnico se toma del dispositivo
/// y no del servidor.
///
/// El constructor se mantiene exactamente igual (idIncidente, clienteLat,
/// clienteLng) para no romper a los llamadores existentes.
class TecnicoRutaScreen extends StatefulWidget {
  final int idIncidente;
  final double clienteLat;
  final double clienteLng;

  const TecnicoRutaScreen({
    super.key,
    required this.idIncidente,
    required this.clienteLat,
    required this.clienteLng,
  });

  @override
  State<TecnicoRutaScreen> createState() => _TecnicoRutaScreenState();
}

class _TecnicoRutaScreenState extends State<TecnicoRutaScreen> {
  // Servidor OSRM publico (mismo que usa el backend para calcular rutas/ETA).
  static const String _osrmBase = 'https://router.project-osrm.org';

  // Umbral de movimiento (metros) que dispara un recalculo de la ruta. Evita
  // saturar OSRM en cada fix del GPS.
  static const double _umbralRecalculoMetros = 120.0;

  final MapController _mapController = MapController();
  final TecnicoAsignacionesService _asignacionesService = TecnicoAsignacionesService();

  StreamSubscription<Position>? _posSub;
  bool _mapaListo = false;

  // Estados de pantalla.
  bool _esperandoGps = true;
  String? _error;
  bool _permisoDenegado = false;

  // Posicion viva del tecnico (dispositivo).
  double? _tecnicoLat;
  double? _tecnicoLng;

  // Ultimo punto donde se solicito la ruta (para comparar el movimiento).
  LatLng? _puntoUltimaRuta;

  // Ruta optima (lista de puntos de la polyline).
  List<LatLng> _rutaPuntos = const [];
  bool _rutaEsFallback = false;
  bool _calculandoRuta = false;

  // Metricas mostradas en la barra de info.
  double? _distanciaKm;
  int? _etaMinutos;

  LatLng get _cliente => LatLng(widget.clienteLat, widget.clienteLng);

  LatLng? get _tecnico => (_tecnicoLat != null && _tecnicoLng != null)
      ? LatLng(_tecnicoLat!, _tecnicoLng!)
      : null;

  @override
  void initState() {
    super.initState();
    _iniciarSeguimientoGps();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Pide permisos (reutilizando el patron de location_sender) y se suscribe al
  /// stream de posiciones del dispositivo para mover al tecnico en el mapa.
  Future<void> _iniciarSeguimientoGps() async {
    setState(() {
      _esperandoGps = true;
      _error = null;
      _permisoDenegado = false;
    });

    final permitido = await _solicitarPermiso();
    if (!mounted) return;

    if (!permitido) {
      setState(() {
        _permisoDenegado = true;
        _esperandoGps = false;
        _error = 'Permiso de ubicacion denegado. Activa el GPS para ver la '
            'ruta hacia el cliente.';
      });
      return;
    }

    // distanceFilter ~10 m: emite un fix cada vez que el tecnico se desplaza esa
    // distancia, dando el efecto de movimiento en el mapa.
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onNuevaPosicion,
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _esperandoGps = false;
          _error = 'No se pudo obtener la ubicacion del dispositivo. '
              'Verifica que el GPS este activado.';
        });
      },
    );
  }

  /// Mismo patron que location_sender: checkPermission y, si esta denegado, lo
  /// solicita una vez.
  Future<bool> _solicitarPermiso() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  /// Procesa cada fix del GPS: actualiza la posicion viva, centra el mapa y
  /// decide si recalcular la ruta.
  void _onNuevaPosicion(Position pos) {
    if (!mounted) return;

    final esPrimerFix = _tecnico == null;

    setState(() {
      _tecnicoLat = pos.latitude;
      _tecnicoLng = pos.longitude;
      _esperandoGps = false;
      _error = null;
    });

    final tecnico = LatLng(pos.latitude, pos.longitude);

    // Sigue al tecnico en el mapa con cada nuevo fix.
    if (_mapaListo) {
      _mapController.move(tecnico, esPrimerFix ? 14.5 : _mapController.camera.zoom);
    }

    // Recalcula la ruta en el primer fix o cuando el tecnico se ha desplazado
    // mas que el umbral respecto al punto de la ultima ruta calculada.
    final ultimo = _puntoUltimaRuta;
    final desplazamiento = ultimo == null
        ? double.infinity
        : _distanciaMetros(
            ultimo.latitude,
            ultimo.longitude,
            tecnico.latitude,
            tecnico.longitude,
          );

    if (esPrimerFix || desplazamiento >= _umbralRecalculoMetros) {
      _calcularRuta(tecnico);
      // Reporta esta MISMA posicion al backend para que el ETA que ve el cliente
      // se calcule desde aqui y coincida con el que ve el tecnico.
      _asignacionesService.reportarUbicacion(tecnico.latitude, tecnico.longitude);
    }
  }

  /// Solicita la ruta optima por calles a OSRM. Si falla, dibuja una linea recta
  /// como respaldo y estima distancia/ETA con haversine.
  Future<void> _calcularRuta(LatLng tecnico) async {
    if (_calculandoRuta) return;
    _calculandoRuta = true;
    _puntoUltimaRuta = tecnico;

    final cliente = _cliente;
    final url = Uri.parse(
      '$_osrmBase/route/v1/driving/'
      '${tecnico.longitude},${tecnico.latitude};'
      '${cliente.longitude},${cliente.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) {
        throw Exception('OSRM respondio ${resp.statusCode}');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final rutas = body['routes'] as List<dynamic>?;
      if (rutas == null || rutas.isEmpty) {
        throw Exception('OSRM sin rutas');
      }

      final ruta = rutas.first as Map<String, dynamic>;
      final geometry = ruta['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;

      // GeoJSON entrega [lng, lat]; latlong2 espera LatLng(lat, lng).
      final puntos = coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      final duracionSeg = (ruta['duration'] as num?)?.toDouble() ?? 0.0;
      final distanciaMetros = (ruta['distance'] as num?)?.toDouble() ?? 0.0;

      final etaMin = (duracionSeg / 60).round();

      if (!mounted) return;
      setState(() {
        _rutaPuntos = puntos;
        _rutaEsFallback = false;
        _distanciaKm = distanciaMetros / 1000.0;
        _etaMinutos = etaMin < 1 ? 1 : etaMin;
      });
    } catch (_) {
      // Respaldo: linea recta y estimacion con haversine.
      _aplicarRutaFallback(tecnico, cliente);
    } finally {
      _calculandoRuta = false;
    }
  }

  /// Respaldo cuando OSRM no responde: linea recta punteada y estimacion simple.
  void _aplicarRutaFallback(LatLng tecnico, LatLng cliente) {
    final distanciaKm = _calcularDistanciaKm(
      tecnico.latitude,
      tecnico.longitude,
      cliente.latitude,
      cliente.longitude,
    );

    if (!mounted) return;
    setState(() {
      _rutaPuntos = [tecnico, cliente];
      _rutaEsFallback = true;
      _distanciaKm = distanciaKm;
      _etaMinutos = _estimarMinutosDesdeKm(distanciaKm);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento #${widget.idIncidente}'),
      ),
      body: _buildBody(),
      floatingActionButton: _tecnico != null
          ? FloatingActionButton.extended(
              onPressed: () {
                final t = _tecnico;
                if (t != null && _mapaListo) {
                  _mapController.move(t, 15);
                }
              },
              icon: const Icon(Icons.my_location),
              label: const Text('Centrar'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    // Permiso denegado o error sin posicion: pantalla de estado con reintento.
    if (_permisoDenegado || (_error != null && _tecnico == null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.orange),
              const SizedBox(height: 12),
              Text(
                _error ?? 'No se pudo obtener la ubicacion.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _iniciarSeguimientoGps,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    // Esperando el primer fix del GPS.
    if (_esperandoGps && _tecnico == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Obteniendo tu ubicacion...'),
          ],
        ),
      );
    }

    final tecnico = _tecnico;

    return Column(
      children: [
        _buildBarraInfo(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  // Al inicio centra en el cliente si aun no hay GPS; cuando
                  // llega el primer fix se reencuadra sobre el tecnico.
                  initialCenter: tecnico ?? _cliente,
                  initialZoom: tecnico != null ? 14.5 : 15,
                  onMapReady: () {
                    _mapaListo = true;
                    final t = _tecnico;
                    if (t != null) {
                      _mapController.move(t, 14.5);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'app.flujo.emergencia',
                  ),
                  if (_rutaPuntos.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _rutaPuntos,
                          strokeWidth: 5,
                          color: AppColors.slate,
                          pattern: _rutaEsFallback
                              ? const StrokePattern.dotted(spacingFactor: 2)
                              : const StrokePattern.solid(),
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _cliente,
                        width: 46,
                        height: 46,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.danger,
                          size: 42,
                        ),
                      ),
                      if (tecnico != null)
                        Marker(
                          point: tecnico,
                          width: 46,
                          height: 46,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.slate,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: AppColors.shadowSm,
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildLeyenda(),
      ],
    );
  }

  Widget _buildBarraInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slateSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation, color: AppColors.slate),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'En camino al cliente',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                if (_etaMinutos != null && _distanciaKm != null)
                  Text(
                    'Tiempo aprox: $_etaMinutos min  ·  '
                    'Distancia: ${_distanciaKm!.toStringAsFixed(1)} km'
                    '${_rutaEsFallback ? '  (estimado)' : ''}',
                    style: const TextStyle(color: AppColors.inkSubtle),
                  )
                else if (_calculandoRuta)
                  const Text(
                    'Calculando ruta...',
                    style: TextStyle(color: AppColors.inkSubtle),
                  )
                else
                  const Text(
                    'Preparando la ruta...',
                    style: TextStyle(color: AppColors.inkSubtle),
                  ),
              ],
            ),
          ),
          if (_calculandoRuta)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildLeyenda() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Leyenda:'),
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.location_on, color: AppColors.danger),
              SizedBox(width: 6),
              Text('Cliente (incidente)'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              Icon(Icons.navigation, color: AppColors.slate),
              SizedBox(width: 6),
              Text('Tu ubicacion (en vivo)'),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helpers de distancia/ETA (haversine) usados por el respaldo. ---

  /// Distancia en kilometros entre dos coordenadas (haversine).
  double _calcularDistanciaKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double radioTierraKm = 6371.0;
    final dLat = _gradosARadianes(lat2 - lat1);
    final dLon = _gradosARadianes(lon2 - lon1);
    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(_gradosARadianes(lat1)) *
            math.cos(_gradosARadianes(lat2)) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radioTierraKm * c;
  }

  /// Distancia en metros, reusando el calculo en km.
  double _distanciaMetros(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return _calcularDistanciaKm(lat1, lon1, lat2, lon2) * 1000.0;
  }

  int _estimarMinutosDesdeKm(double distanciaKm) {
    const double velocidadPromedioKmh = 30.0;
    final horas = distanciaKm / velocidadPromedioKmh;
    final minutos = (horas * 60).round();
    return minutos < 1 ? 1 : minutos;
  }

  double _gradosARadianes(double grados) =>
      grados * (3.141592653589793 / 180.0);
}
