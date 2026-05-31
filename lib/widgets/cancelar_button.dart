import 'package:flutter/material.dart';
import '../models/cancelacion_response.dart';
import '../services/cancelacion_service.dart';

class CancelarButton extends StatefulWidget {
  final int idAsignacion;
  final VoidCallback? onCancelado;

  const CancelarButton({
    super.key,
    required this.idAsignacion,
    this.onCancelado,
  });

  @override
  State<CancelarButton> createState() => _CancelarButtonState();
}

class _CancelarButtonState extends State<CancelarButton> {
  bool _enviando = false;

  Future<void> _abrirModal() async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cancelar servicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Indica el motivo (minimo 3 caracteres):'),
              const SizedBox(height: 8),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ej: Llego mi seguro',
                  border: OutlineInputBorder(),
                ),
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.amber.shade50,
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si el taller ya estaba en camino, recibira una compensacion.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: motivoCtrl.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Cancelar servicio'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    await _ejecutarCancelacion(motivoCtrl.text.trim());
  }

  Future<void> _ejecutarCancelacion(String motivo) async {
    setState(() => _enviando = true);
    try {
      final resp =
          await CancelacionService().cancelar(widget.idAsignacion, motivo);
      if (!mounted) return;
      await _mostrarConfirmacion(resp);
      widget.onCancelado?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _mostrarConfirmacion(CancelacionResponse r) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Servicio cancelado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text('Estado: ${r.nuevoEstado}'),
            ]),
            const SizedBox(height: 16),
            if (r.compensacionMonto == 0)
              const Text('Sin compensacion al taller (no habia salido).')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compensacion al taller: \$${r.compensacionMonto.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.compensacionPagada
                        ? 'Ya esta pagada'
                        : 'Pendiente de cobro por el taller',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _enviando ? null : _abrirModal,
        icon: _enviando
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cancel),
        label: const Text('Cancelar servicio', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
