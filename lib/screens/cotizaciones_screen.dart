import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cotizacion.dart';
import '../services/cotizacion_service.dart';

class CotizacionesScreen extends StatefulWidget {
  final int idIncidente;

  const CotizacionesScreen({
    super.key,
    required this.idIncidente,
  });

  @override
  State<CotizacionesScreen> createState() => _CotizacionesScreenState();
}

class _CotizacionesScreenState extends State<CotizacionesScreen> {
  final _svc = CotizacionService();
  Timer? _pollTimer;
  bool _solicitando = true;
  bool _aceptando = false;
  String? _error;
  List<Cotizacion> _cotizaciones = [];
  int _invitadas = 0;

  @override
  void initState() {
    super.initState();
    _solicitarYpoll();
  }

  Future<void> _solicitarYpoll() async {
    try {
      final resp = await _svc.solicitar(idIncidente: widget.idIncidente);
      _invitadas = resp['invitadas'] ?? 0;
      setState(() => _solicitando = false);
      _startPolling();
    } catch (e) {
      setState(() {
        _solicitando = false;
        _error = e.toString();
      });
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final lista = await _svc.listar(widget.idIncidente);
        if (!mounted) return;
        setState(() => _cotizaciones = lista);
        final enviadas = lista.where((c) => c.estadoNombre == 'enviada').length;
        if (_invitadas > 0 && enviadas >= _invitadas) {
          _pollTimer?.cancel();
        }
      } catch (_) {}
    });

    _svc.listar(widget.idIncidente).then((l) {
      if (mounted) setState(() => _cotizaciones = l);
    });
  }

  Future<void> _aceptar(Cotizacion c) async {
    setState(() => _aceptando = true);
    try {
      final idAsig = await _svc.aceptar(c.idCotizacion);
      if (!mounted) return;
      try {
        Navigator.pushReplacementNamed(
          context,
          '/cliente-tracking',
          arguments: {
            'id_asignacion': idAsig,
            'id_incidente': widget.idIncidente,
          },
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ruta de tracking no configurada. Continua con M6.'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _aceptando = false);
      }
    } catch (e) {
      setState(() {
        _aceptando = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar cotizaciones')),
      body: _build(),
    );
  }

  Widget _build() {
    if (_solicitando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Solicitando cotizaciones a talleres...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final enviadas =
        _cotizaciones.where((c) => c.estadoNombre == 'enviada').toList();
    final pendientes =
        _cotizaciones.where((c) => c.estadoNombre == 'pendiente').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(children: [
            Expanded(
              child: Text(
                '$_invitadas talleres invitados — ${enviadas.length} respondieron, $pendientes pendientes',
              ),
            ),
            if (pendientes > 0)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ]),
        ),
        if (enviadas.isEmpty)
          const Expanded(
            child: Center(child: Text('Esperando respuestas...')),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: enviadas.length,
              itemBuilder: (_, i) {
                final c = enviadas[i];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.tallerNombre ?? 'Taller #${c.idTaller}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _row('Servicio', _money(c.montoServicio)),
                        _row('Repuestos', _money(c.montoRepuestos)),
                        if (c.montoTraslado != null && c.montoTraslado! > 0)
                          _row(
                            c.distanciaKm != null
                                ? 'Traslado (${c.distanciaKm!.toStringAsFixed(1)} km)'
                                : 'Traslado',
                            _money(c.montoTraslado),
                          ),
                        _row('Total', _money(c.montoTotal), bold: true),
                        if (c.garantiaDias != null)
                          _row('Garantia', '${c.garantiaDias} dias'),
                        if (c.tiempoEstimadoLabel != null)
                          _row('Tiempo reparacion', c.tiempoEstimadoLabel!),
                        if (c.nota != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              c.nota!,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _aceptando
                                ? null
                                : () => _confirmarAceptar(c),
                            child: const Text('Aceptar esta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  String _money(double? value) {
    if (value == null) return '—';
    return '\$${value.toStringAsFixed(2)}';
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarAceptar(Cotizacion c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aceptar cotizacion'),
        content: Text(
          '¿Confirmas aceptar la cotizacion de ${c.tallerNombre ?? 'Taller'} '
          'por ${_money(c.montoTotal)}?\n\n'
          'Las otras cotizaciones quedaran rechazadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (ok == true) _aceptar(c);
  }
}
