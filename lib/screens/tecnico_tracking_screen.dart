import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/incidente_service.dart';

class TecnicoTrackingScreen extends StatefulWidget {
  final int idIncidente;
  final double clienteLat;
  final double clienteLng;

  const TecnicoTrackingScreen({
    super.key,
    required this.idIncidente,
    required this.clienteLat,
    required this.clienteLng,
  });

  @override
  State<TecnicoTrackingScreen> createState() => _TecnicoTrackingScreenState();
}

class _TecnicoTrackingScreenState extends State<TecnicoTrackingScreen> {
  final _service = IncidenteService();

  Timer? _timer;
  bool _cargando = true;
  String? _error;

  double? _tecnicoLat;
  double? _tecnicoLng;
  String _nombreTecnico = 'Técnico';
  String _estadoAsignacion = 'desconocido';

  @override
  void initState() {
    super.initState();
    _cargarUbicacion();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      _cargarUbicacion(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarUbicacion({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    final res = await _service.obtenerUbicacionTecnico(widget.idIncidente);

    if (!mounted) return;

    if (res['success'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      setState(() {
        _tecnicoLat = (data['latitud_tecnico'] as num?)?.toDouble();
        _tecnicoLng = (data['longitud_tecnico'] as num?)?.toDouble();
        _nombreTecnico = (data['nombre_tecnico'] ?? 'Técnico').toString();
        _estadoAsignacion = (data['estado_asignacion'] ?? 'desconocido').toString();
        _error = null;
        _cargando = false;
      });
    } else {
      final code = res['code']?.toString();
      if (code == 'AUTH_EXPIRED') {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      setState(() {
        _error = (res['error'] ?? 'No se pudo cargar la ubicación').toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cliente = LatLng(widget.clienteLat, widget.clienteLng);
    final tecnico = (_tecnicoLat != null && _tecnicoLng != null)
        ? LatLng(_tecnicoLat!, _tecnicoLng!)
        : null;

    final distanciaKm = tecnico != null
        ? _calcularDistanciaKm(
            cliente.latitude,
            cliente.longitude,
            tecnico.latitude,
            tecnico.longitude,
          )
        : null;
    final etaMinutos = distanciaKm != null
        ? _estimarMinutosDesdeKm(distanciaKm)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento #${widget.idIncidente}'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off, size: 64, color: Colors.orange),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _cargarUbicacion,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estado de atención',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text('Técnico: $_nombreTecnico'),
                          Text('Estado: $_estadoAsignacion'),
                          if (distanciaKm != null && etaMinutos != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Distancia aprox: ${distanciaKm.toStringAsFixed(1)} km',
                            ),
                            Text('Tiempo aprox: $etaMinutos min'),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            options: MapOptions(
                              initialCenter: tecnico ?? cliente,
                              initialZoom: tecnico != null ? 13.5 : 15,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'app.flujo.emergencia',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: cliente,
                                    width: 44,
                                    height: 44,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                  if (tecnico != null)
                                    Marker(
                                      point: tecnico,
                                      width: 44,
                                      height: 44,
                                      child: const Icon(
                                        Icons.build_circle,
                                        color: Colors.orange,
                                        size: 38,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Leyenda:'),
                          const SizedBox(height: 6),
                          Row(
                            children: const [
                              Icon(Icons.location_on, color: Colors.red),
                              SizedBox(width: 6),
                              Text('Cliente (incidente)'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.build_circle, color: Colors.orange),
                              SizedBox(width: 6),
                              Text('Técnico (ubicación actual)'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _cargarUbicacion,
        icon: const Icon(Icons.refresh),
        label: const Text('Actualizar'),
      ),
    );
  }

  double _calcularDistanciaKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double radioTierraKm = 6371.0;
    final dLat = _gradosARadianes(lat2 - lat1);
    final dLon = _gradosARadianes(lon2 - lon1);
    final a =
      (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      math.cos(_gradosARadianes(lat1)) *
        math.cos(_gradosARadianes(lat2)) *
        (math.sin(dLon / 2) * math.sin(dLon / 2));
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return radioTierraKm * c;
  }

  int _estimarMinutosDesdeKm(double distanciaKm) {
    const double velocidadPromedioKmh = 25.0;
    final horas = distanciaKm / velocidadPromedioKmh;
    final minutos = (horas * 60).round();
    return minutos < 1 ? 1 : minutos;
  }

  double _gradosARadianes(double grados) => grados * (3.141592653589793 / 180.0);
}
