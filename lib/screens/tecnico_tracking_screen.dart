import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/incidente_service.dart';
import '../widgets/cancelar_button.dart';
import 'package:app_emergencias/theme/app_colors.dart';

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
  int? _idAsignacion;
  double? _distanciaKm;
  int? _etaMinutos;

  @override
  void initState() {
    super.initState();
    _cargarUbicacion();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
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
        _idAsignacion = (data['id_asignacion'] as num?)?.toInt();
        _distanciaKm = (data['distancia_km'] as num?)?.toDouble();
        _etaMinutos = (data['eta_minutos'] as num?)?.toInt();
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

    // La distancia/ETA vienen del backend (OSRM), para que sean iguales en todas
    // las vistas (cliente y tecnico). No se recalculan aqui.
    final distanciaKm = _distanciaKm;
    final etaMinutos = _etaMinutos;

    // El cliente puede cancelar mientras el servicio no haya terminado; la
    // compensacion al taller se cobra segun el estado (en_camino/llegado = 100%).
    final puedeCancelar = _idAsignacion != null &&
        _estadoAsignacion != 'completada' &&
        _estadoAsignacion != 'cancelada' &&
        _estadoAsignacion != 'desconocido';

    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento #${widget.idIncidente}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarUbicacion,
          ),
        ],
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
                                      color: AppColors.danger,
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
                              Icon(Icons.location_on, color: AppColors.danger),
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
      bottomNavigationBar: puedeCancelar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CancelarButton(
                  idAsignacion: _idAsignacion!,
                  onCancelado: () => Navigator.of(context).pop(),
                ),
              ),
            )
          : null,
    );
  }

}
