import 'package:flutter/material.dart';

import '../services/adenda_service.dart';

/// Tarjeta que muestra una adenda pendiente del taller para que el cliente
/// la apruebe o rechace. Pensada para colocarse en pantallas de tracking
/// o detalle del incidente.
class AdendaPendienteCard extends StatefulWidget {
  final Adenda adenda;
  final VoidCallback? onResuelta;

  const AdendaPendienteCard({
    super.key,
    required this.adenda,
    this.onResuelta,
  });

  @override
  State<AdendaPendienteCard> createState() => _AdendaPendienteCardState();
}

class _AdendaPendienteCardState extends State<AdendaPendienteCard> {
  final _svc = AdendaService();
  bool _enviando = false;
  String? _motivo;

  Future<void> _responder(bool aprobar) async {
    if (_enviando) return;
    if (!aprobar && (_motivo == null || _motivo!.trim().isEmpty)) {
      _motivo = await _pedirMotivo();
      if (_motivo == null) return; // El cliente cerró el diálogo sin indicar motivo.
    }
    setState(() => _enviando = true);
    final r = await _svc.responder(
      idAdenda: widget.adenda.idAdenda,
      aprobar: aprobar,
      motivo: _motivo,
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    if (r['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(aprobar
              ? 'Ampliacion aprobada. El servicio continua.'
              : 'Ampliacion rechazada. El servicio se cancelara.'),
          backgroundColor: aprobar ? Colors.green : Colors.orange,
        ),
      );
      widget.onResuelta?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${r['error']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _pedirMotivo() async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Motivo del rechazo'),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Explica brevemente por que rechazas la ampliacion',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctl.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.adenda;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Ampliacion de presupuesto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'El taller solicita un costo adicional de '
              '\$${ad.montoAdicional.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(ad.descripcion),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _enviando ? null : () => _responder(false),
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _enviando ? null : () => _responder(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Aprobar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
