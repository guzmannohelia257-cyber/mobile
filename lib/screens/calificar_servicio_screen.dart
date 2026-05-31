import 'package:flutter/material.dart';

import '../models/incidente.dart';
import '../services/incidente_service.dart';

class CalificarServicioScreen extends StatefulWidget {
  final int idIncidente;

  const CalificarServicioScreen({super.key, required this.idIncidente});

  @override
  State<CalificarServicioScreen> createState() => _CalificarServicioScreenState();
}

class _CalificarServicioScreenState extends State<CalificarServicioScreen> {
  final IncidenteService _incidenteService = IncidenteService();
  final TextEditingController _comentarioController = TextEditingController();

  bool _loading = true;
  bool _enviando = false;
  bool _yaEvaluado = false;
  String? _error;
  int _estrellas = 0;
  IncidenteDetalle? _incidente;

  @override
  void initState() {
    super.initState();
    _cargarIncidente();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _cargarIncidente() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _incidenteService.obtenerIncidencia(widget.idIncidente);
    if (!mounted) return;

    if (result['success'] == true) {
      final inc = result['incidente'] as IncidenteDetalle;
      setState(() {
        _incidente = inc;
        _yaEvaluado = inc.evaluado;
        _loading = false;
      });
      return;
    }

    setState(() {
      _error = (result['error'] ?? 'No se pudo cargar la incidencia').toString();
      _loading = false;
    });
  }

  Future<void> _enviarCalificacion() async {
    if (_enviando || _yaEvaluado || _estrellas == 0) return;

    setState(() => _enviando = true);

    final result = await _incidenteService.evaluarServicio(
      idIncidente: widget.idIncidente,
      estrellas: _estrellas,
      comentario: _comentarioController.text,
    );

    if (!mounted) return;
    setState(() => _enviando = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por tu calificación')),
      );
      Navigator.of(context).pop(true);
      return;
    }

    if (result['code'] == 'ALREADY_RATED') {
      setState(() => _yaEvaluado = true);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['error']?.toString() ?? 'Error al enviar')),
    );
  }

  Widget _buildStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final active = index < _estrellas;
        return IconButton(
          onPressed: _yaEvaluado
              ? null
              : () {
                  setState(() => _estrellas = index + 1);
                },
          icon: Icon(
            active ? Icons.star : Icons.star_border,
            color: active ? Colors.amber : Colors.grey,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inc = _incidente;

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar servicio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (inc != null) ...[
                        Text(
                          'Incidente #${inc.idIncidente}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(inc.getEstadoNombre()),
                        const SizedBox(height: 16),
                      ],
                      if (_yaEvaluado)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: const Text(
                            'Ya calificaste este servicio. Gracias.',
                            style: TextStyle(color: Colors.green),
                          ),
                        )
                      else ...[
                        const Text('Selecciona una calificación:'),
                        _buildStars(),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _comentarioController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Comentario (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _enviando || _estrellas == 0
                              ? null
                              : _enviarCalificacion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: _enviando
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Enviar calificación'),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
