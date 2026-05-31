import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/taller.dart';
import '../services/incidente_service.dart';
import '../services/taller_service.dart';

/// Pantalla M1: cliente ve talleres compatibles con la categoria detectada
/// para su incidente, filtrados por cercania.
class SeleccionarTallerScreen extends StatefulWidget {
  final Categoria categoria;
  final double latitud;
  final double longitud;
  /// ID del incidente ya creado (opcional). Si viene, se pasa a las pantallas
  /// siguientes (/cotizaciones o /esperando-taller) para suscribirse a WS.
  final int? idIncidente;

  const SeleccionarTallerScreen({
    super.key,
    required this.categoria,
    required this.latitud,
    required this.longitud,
    this.idIncidente,
  });

  @override
  State<SeleccionarTallerScreen> createState() => _SeleccionarTallerScreenState();
}

class _SeleccionarTallerScreenState extends State<SeleccionarTallerScreen> {
  final _svc = TallerService();
  final _incidenteService = IncidenteService();
  bool _cargando = true;
  String? _error;
  List<TallerCompatible> _talleres = [];
  double _radioKm = 20;
  bool _confirmando = false;
  bool _tallerConfirmado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    // Si el cliente sale sin elegir taller, descartamos el borrador
    // para que no aparezca como "pendiente" en su historial.
    if (!_tallerConfirmado && widget.idIncidente != null) {
      _incidenteService.descartarBorrador(widget.idIncidente!);
    }
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_confirmando) return false;
    if (_tallerConfirmado) return true;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el reporte?'),
        content: const Text(
          'Si sales ahora no se enviará la solicitud a ningún taller. '
          'Tu reporte no quedará guardado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir eligiendo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _svc.compatibles(
        idCategoria: widget.categoria.idCategoria,
        latitud: widget.latitud,
        longitud: widget.longitud,
        radioKm: _radioKm,
      );
      if (!mounted) return;
      setState(() {
        _talleres = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _onTallerTap(TallerCompatible t) async {
    if (widget.idIncidente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Falta el incidente: vuelve y reporta primero.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_confirmando) return;
    setState(() => _confirmando = true);

    final res = await _incidenteService.confirmarIncidencia(
      idIncidente: widget.idIncidente!,
      idTallerPreferido: t.idTaller,
    );

    if (!mounted) return;
    if (!res['success']) {
      setState(() => _confirmando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'No se pudo confirmar'),
          backgroundColor: Colors.red,
        ),
      );
      if (res['code'] == 'AUTH_EXPIRED') {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // Una vez confirmado, el borrador ya es 'pendiente' en el backend y
    // por tanto no debe descartarse en dispose().
    _tallerConfirmado = true;

    if (widget.categoria.requiereCotizacion) {
      Navigator.pushReplacementNamed(
        context,
        '/cotizaciones',
        arguments: {
          'id_incidente': widget.idIncidente,
          'taller_preferido': t.idTaller,
        },
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/esperando-taller',
        arguments: {
          'id_incidente': widget.idIncidente,
          'taller_preferido': t.idTaller,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Talleres compatibles'),
            Text(
              widget.categoria.nombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.categoria.requiereCotizacion)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade50,
              child: Row(children: const [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este servicio requiere cotizacion previa. Podras comparar precios antes de decidir.',
                  ),
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Text('Radio: ${_radioKm.toInt()} km'),
              Expanded(
                child: Slider(
                  value: _radioKm,
                  min: 5,
                  max: 50,
                  divisions: 9,
                  onChanged: (v) => setState(() => _radioKm = v),
                  onChangeEnd: (_) => _cargar(),
                ),
              ),
            ]),
          ),
          Expanded(child: _buildContenido()),
        ],
      ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_talleres.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay talleres compatibles en este radio. Amplia la busqueda.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: _talleres.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final t = _talleres[i];
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (t.distanciaKm != null)
                Text(
                  '${t.distanciaKm!.toStringAsFixed(1)} km'
                  '${t.etaLlegadaLabel != null ? '  ·  llega en ${t.etaLlegadaLabel}' : ''}',
                ),
              if (t.tiempoReparacionLabel != null)
                Text(
                  'Reparacion: ${t.tiempoReparacionLabel}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              if (t.totalEstimado != null) ...[
                Text(
                  'Total estimado: \$${t.totalEstimado!.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (t.tarifaBase != null && t.montoTraslado != null && t.montoTraslado! > 0)
                  Text(
                    'Servicio \$${t.tarifaBase!.toStringAsFixed(0)} + traslado \$${t.montoTraslado!.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ] else if (t.tarifaBase != null) ...[
                Text('Desde \$${t.tarifaBase!.toStringAsFixed(0)}'),
              ],
              if (t.ratingPromedio != null)
                Row(children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  Text(' ${t.ratingPromedio!.toStringAsFixed(1)}'),
                ]),
            ],
          ),
          trailing: _confirmando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          enabled: !_confirmando,
          onTap: _confirmando ? null : () => _onTallerTap(t),
        );
      },
    );
  }
}
