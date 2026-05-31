import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asignacion_response.dart';
import '../models/completar_servicio_form.dart';
import '../services/adenda_service.dart';
import '../services/location_sender.dart';
import '../services/tecnico_asignaciones_service.dart';
import '../widgets/completar_servicio_dialog.dart';
import '../widgets/cancelar_button.dart';

class AsignacionDetalleScreen extends StatefulWidget {
  final int idAsignacion;

  const AsignacionDetalleScreen({
    super.key,
    required this.idAsignacion,
  });

  @override
  State<AsignacionDetalleScreen> createState() => _AsignacionDetalleScreenState();
}

class _AsignacionDetalleScreenState extends State<AsignacionDetalleScreen> {
  final TecnicoAsignacionesService _asignacionesService = TecnicoAsignacionesService();
  final LocationSender _sender = LocationSender();
  StreamSubscription<LocationSenderResult>? _senderSub;

  AsignacionResponse? _asignacion;
  bool _iniciandoViaje = false;
  bool _enviandoGps = false;
  int? _etaMinutos;
  double? _distanciaKm;

  @override
  void initState() {
    super.initState();
    _senderSub = _sender.results.listen((r) {
      if (!mounted) return;
      setState(() {
        _etaMinutos = r.etaMinutos;
        _distanciaKm = r.distanciaKm;
      });
      if (r.llegadoAuto) {
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Has llegado'),
            content: const Text(
              'Tu estado paso a "llegado". Procede con el servicio.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  void _abrirDialogoCompletar() {
    showDialog(
      context: context,
      builder: (context) => CompletarServicioDialog(
        onConfirm: _completarServicio,
      ),
    );
  }

  Future<void> _completarServicio(CompletarServicioForm form) async {
    try {
      final resultado = await _asignacionesService.completarServicio(
        widget.idAsignacion,
        costoFinal: form.costoFinal,
        resumenTrabajo: form.resumenTrabajo,
      );

      if (!mounted) return;

      setState(() {
        _asignacion = resultado;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Servicio completado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al completar servicio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _iniciarViajeAhora() async {
    setState(() => _iniciandoViaje = true);

    try {
      final resultado = await _asignacionesService.iniciarViaje(widget.idAsignacion);

      if (!mounted) return;

      setState(() {
        _asignacion = resultado;
      });

      final ok = await _sender.start(idAsignacion: widget.idAsignacion);
      if (!mounted) return;
      setState(() => _enviandoGps = ok);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viaje iniciado. Estado: ${resultado.estadoAsignacion}'),
          backgroundColor: Colors.green,
        ),
      );

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de GPS denegado. Activalo en ajustes.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _iniciandoViaje = false);
      }
    }
  }

  void _detenerEnvio() {
    _sender.stop();
    setState(() => _enviandoGps = false);
  }

  /// Dialog para que el tecnico registre una adenda durante el servicio.
  Future<void> _abrirDialogAdenda() async {
    final montoCtl = TextEditingController();
    final descCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Registrar ampliacion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montoCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto adicional (USD)',
                hintText: 'Ej: 50',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
                hintText: 'Por que se necesita el cobro adicional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final monto = double.tryParse(montoCtl.text.trim());
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monto invalido')),
      );
      return;
    }
    if (descCtl.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La descripcion debe tener al menos 5 caracteres')),
      );
      return;
    }

    final r = await AdendaService().crear(
      idAsignacion: widget.idAsignacion,
      montoAdicional: monto,
      descripcion: descCtl.text.trim(),
    );
    if (!mounted) return;
    if (r['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ampliacion enviada al cliente para su aprobacion'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${r['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _senderSub?.cancel();
    _sender.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incidente = _asignacion?.incidente;
    final estadoAsignacion = _asignacion?.estadoAsignacion ?? 'aceptada';
    final puedeCancelar = estadoAsignacion == 'aceptada' ||
      estadoAsignacion == 'en_camino' ||
      estadoAsignacion == 'pendiente' ||
      estadoAsignacion == 'llegado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Asignacion'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incidente',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text('ID Asignacion: ${widget.idAsignacion}'),
                    Text('Categoria: ${incidente?.categoria ?? 'Pendiente de cargar'}'),
                    Text('Prioridad: ${incidente?.prioridad ?? 'No disponible'}'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Descripcion: ${incidente?.descripcionUsuario ?? 'N/A'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de la Asignacion',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: estadoAsignacion == 'aceptada'
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        estadoAsignacion,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_asignacion?.tiempoEstimadoLabel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 18, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          Text(
                            'Tiempo estimado de reparacion: ${_asignacion!.tiempoEstimadoLabel}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (estadoAsignacion == 'aceptada')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _iniciandoViaje ? null : _iniciarViajeAhora,
                  icon: _iniciandoViaje
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.navigation),
                  label: const Text('Iniciar Viaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (_enviandoGps) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: Colors.green),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Enviando ubicacion cada 12s'),
                    ),
                    if (_etaMinutos != null)
                      Text('ETA: $_etaMinutos min'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Pausar envio'),
                  onPressed: _detenerEnvio,
                ),
              ),
              if (_distanciaKm != null) ...[
                const SizedBox(height: 8),
                Text('Distancia aprox: ${_distanciaKm!.toStringAsFixed(1)} km'),
              ],
            ],
            if (estadoAsignacion == 'en_camino' ||
                estadoAsignacion == 'llegado') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _abrirDialogAdenda,
                  icon: const Icon(Icons.add_card),
                  label: const Text('Registrar ampliacion (adenda)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (estadoAsignacion == 'en_camino' || estadoAsignacion == 'llegado')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _abrirDialogoCompletar,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Completar Servicio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (puedeCancelar) ...[
              const SizedBox(height: 16),
              CancelarButton(
                idAsignacion: widget.idAsignacion,
                onCancelado: () {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ],
            if (estadoAsignacion == 'completada')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Servicio Completado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'El cliente ya puede evaluar el servicio',
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
