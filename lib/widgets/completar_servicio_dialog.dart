import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/completar_servicio_form.dart';

class CompletarServicioDialog extends StatefulWidget {
  final Future<void> Function(CompletarServicioForm form) onConfirm;

  const CompletarServicioDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  State<CompletarServicioDialog> createState() =>
      _CompletarServicioDialogState();
}

class _CompletarServicioDialogState extends State<CompletarServicioDialog> {
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _resumenController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _costoController.dispose();
    _resumenController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final costo = _costoController.text.trim().isNotEmpty
        ? double.tryParse(_costoController.text.trim())
        : null;
    final resumen = _resumenController.text.trim().isEmpty
        ? null
        : _resumenController.text.trim();

    if (costo == null && (resumen == null || resumen.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa costo o resumen del trabajo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (costo != null && costo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El costo no puede ser negativo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (resumen != null && resumen.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El resumen no puede exceder 1000 caracteres'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final form = CompletarServicioForm(
        costoFinal: costo,
        resumenTrabajo: resumen,
      );

      await widget.onConfirm(form);

      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Completar Servicio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cobro final (USD)'),
            const SizedBox(height: 4),
            Text(
              'Ajustalo si hubo gastos adicionales (la tarifa de la cotizacion es solo referencial).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _costoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                hintText: 'Ej: 85.00',
                prefixText: r'$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Resumen del trabajo realizado'),
            const SizedBox(height: 8),
            TextField(
              controller: _resumenController,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                hintText: 'Describe el trabajo realizado',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Al menos uno de los dos campos es obligatorio',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _confirmar,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Completar'),
        ),
      ],
    );
  }
}
