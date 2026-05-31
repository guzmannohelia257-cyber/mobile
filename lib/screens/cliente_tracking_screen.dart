import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/adenda_service.dart';
import '../services/realtime_service.dart';
import '../widgets/adenda_pendiente_card.dart';
import '../widgets/cancelar_button.dart';

class ClienteTrackingScreen extends StatefulWidget {
  final int idIncidente;
  final int idAsignacion;
  final LatLng ubicacionIncidente;
  final Map<String, dynamic>? taller;

  const ClienteTrackingScreen({
    super.key,
    required this.idIncidente,
    required this.idAsignacion,
    required this.ubicacionIncidente,
    this.taller,
  });

  @override
  State<ClienteTrackingScreen> createState() => _ClienteTrackingScreenState();
}

class _ClienteTrackingScreenState extends State<ClienteTrackingScreen> {
  final _rt = RealtimeService();
  StreamSubscription? _sub;
  final _mapCtrl = MapController();

  LatLng? _posTecnico;
  int? _etaMinutos;
  double? _distanciaKm;
  bool _llego = false;

  final _adendaSvc = AdendaService();
  List<Adenda> _adendasPendientes = [];
  Timer? _adendaPollTimer;

  @override
  void initState() {
    super.initState();
    _rt.subscribe('incidente:${widget.idIncidente}');
    _sub = _rt.events.listen(_onEvent);
    _refrescarAdendas();
    // Sondeo periódico de adendas nuevas mientras el servicio está en curso.
    _adendaPollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refrescarAdendas(),
    );
  }

  Future<void> _refrescarAdendas() async {
    final lista = await _adendaSvc.listar(widget.idAsignacion);
    if (!mounted) return;
    setState(() {
      _adendasPendientes = lista.where((a) => a.esPendiente).toList();
    });
  }

  void _onEvent(WsEvent evt) {
    if (!mounted) return;
    final data = evt.data;
    if (data == null) return;

    if (evt.event == 'tecnico.posicion' &&
        data['id_asignacion'] == widget.idAsignacion) {
      final lat = (data['latitud'] as num?)?.toDouble();
      final lng = (data['longitud'] as num?)?.toDouble();
      final eta = data['eta'] as Map<String, dynamic>?;
      if (lat != null && lng != null) {
        setState(() {
          _posTecnico = LatLng(lat, lng);
          if (eta != null) {
            _etaMinutos = eta['eta_minutos'] as int?;
            _distanciaKm = (eta['distancia_km'] as num?)?.toDouble();
          }
        });
        _centrarMapa();
      }
    } else if (evt.event == 'asignacion.llegado' &&
        data['id_asignacion'] == widget.idAsignacion) {
      setState(() => _llego = true);
      _mostrarDialogoLlegada();
    }
  }

  void _centrarMapa() {
    if (_posTecnico == null) return;
    final centroLat =
        (_posTecnico!.latitude + widget.ubicacionIncidente.latitude) / 2;
    final centroLng =
        (_posTecnico!.longitude + widget.ubicacionIncidente.longitude) / 2;
    _mapCtrl.move(LatLng(centroLat, centroLng), 14);
  }

  Future<void> _mostrarDialogoLlegada() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('El tecnico llego'),
        ]),
        content: const Text('El tecnico esta a menos de 100m de tu ubicacion.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rt.unsubscribe('incidente:${widget.idIncidente}');
    _sub?.cancel();
    _adendaPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tallerNombre = widget.taller?['nombre'] ?? 'Taller asignado';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tallerNombre, style: const TextStyle(fontSize: 16)),
            Text(
              _llego
                  ? 'Llego'
                  : (_etaMinutos != null
                      ? 'ETA: $_etaMinutos min'
                      : 'En camino...'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          _buildMapa(),
          if (_distanciaKm != null) _buildInfoBar(),
          if (_llego) _buildLlegoBanner(),
          if (_adendasPendientes.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SingleChildScrollView(
                child: Column(
                  children: _adendasPendientes
                      .map((a) => AdendaPendienteCard(
                            adenda: a,
                            onResuelta: _refrescarAdendas,
                          ))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: CancelarButton(
          idAsignacion: widget.idAsignacion,
          onCancelado: () =>
              Navigator.popUntil(context, ModalRoute.withName('/conductor-home')),
        ),
      ),
    );
  }

  Widget _buildMapa() {
    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: widget.ubicacionIncidente,
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'app.flujo.emergencia',
          maxZoom: 19,
        ),
        if (_posTecnico != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [_posTecnico!, widget.ubicacionIncidente],
                strokeWidth: 3,
                color: Colors.blue.withValues(alpha: 0.5),
                pattern: StrokePattern.dashed(segments: const [10, 5]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.ubicacionIncidente,
              width: 50,
              height: 50,
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 50,
              ),
            ),
            if (_posTecnico != null)
              Marker(
                point: _posTecnico!,
                width: 50,
                height: 50,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black26)],
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                const Icon(Icons.straighten),
                Text('${_distanciaKm!.toStringAsFixed(1)} km'),
              ]),
              Column(children: [
                const Icon(Icons.access_time),
                Text(_etaMinutos != null ? '$_etaMinutos min' : '-'),
              ]),
              if (widget.taller?['telefono'] != null)
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green),
                  tooltip: 'Llamar al taller',
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLlegoBanner() {
    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'El tecnico llego al sitio',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
