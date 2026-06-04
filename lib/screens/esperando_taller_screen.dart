import 'dart:async';

import 'package:flutter/material.dart';

import 'package:app_emergencias/theme/app_colors.dart';
import '../models/categoria.dart';
import '../services/incidente_service.dart';
import '../services/realtime_service.dart';
import 'mensajes_screen.dart';
import 'seleccionar_taller_screen.dart';

class EsperandoTallerScreen extends StatefulWidget {
  final int idIncidente;
  // Opcionales: permiten "elegir otro taller" reabriendo la lista.
  final Categoria? categoria;
  final double? latitud;
  final double? longitud;

  const EsperandoTallerScreen({
    super.key,
    required this.idIncidente,
    this.categoria,
    this.latitud,
    this.longitud,
  });

  @override
  State<EsperandoTallerScreen> createState() => _EsperandoTallerScreenState();
}

class _EsperandoTallerScreenState extends State<EsperandoTallerScreen>
    with SingleTickerProviderStateMixin {
  final _rt = RealtimeService();
  final _incidenteService = IncidenteService();
  StreamSubscription? _sub;
  late AnimationController _pulseCtrl;
  Timer? _timeoutTimer;

  int _segundosEspera = 0;
  Timer? _tickTimer;
  bool _navegando = false;

  /// Reabre la lista de talleres para elegir otro (reasigna el incidente).
  Future<void> _elegirOtroTaller() async {
    final cat = widget.categoria;
    if (cat == null || widget.latitud == null || widget.longitud == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarTallerScreen(
          categoria: cat,
          latitud: widget.latitud!,
          longitud: widget.longitud!,
          idIncidente: widget.idIncidente,
          modoCambio: true,
        ),
      ),
    );
    // Al volver seguimos esperando (ahora al nuevo taller elegido).
  }

  /// Cancela la emergencia (el incidente ya esta 'pendiente') y vuelve al home.
  Future<void> _cancelar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la emergencia?'),
        content: const Text(
          'Se cancelará tu solicitud y no se enviará a ningún taller.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final res = await _incidenteService.cancelarIncidente(widget.idIncidente);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/conductor-home',
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error']?.toString() ?? 'No se pudo cancelar'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rt.subscribe('incidente:${widget.idIncidente}');
    _sub = _rt.events.listen(_onEvent);

    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _segundosEspera++);
    });

    _timeoutTimer = Timer(const Duration(minutes: 3), _mostrarTimeout);
  }

  void _onEvent(WsEvent evt) {
    if (_navegando) return;

    if (evt.event == 'incidente.asignado' &&
        evt.data?['id_incidente'] == widget.idIncidente) {
      _navegando = true;
      // El taller acepto: llevar al historial y abrir el detalle del incidente
      // (desde ahi el cliente ve tecnico, mensajes y evidencias).
      Navigator.pushReplacementNamed(
        context,
        '/historial-emergencias',
        arguments: widget.idIncidente,
      );
    }
  }

  void _mostrarTimeout() {
    if (!mounted || _navegando) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sin respuesta'),
        content: const Text(
          'Han pasado 3 minutos sin que ningun taller acepte tu solicitud. '
          '¿Quieres seguir esperando o cancelar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Seguir esperando'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, ModalRoute.withName('/conductor-home'));
            },
            child: const Text('Cancelar emergencia'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rt.unsubscribe('incidente:${widget.idIncidente}');
    _sub?.cancel();
    _pulseCtrl.dispose();
    _tickTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: const Text('Esperando al taller'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                return Container(
                  width: 160 + (_pulseCtrl.value * 40),
                  height: 160 + (_pulseCtrl.value * 40),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2 - _pulseCtrl.value * 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search, size: 70, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Esperando confirmación del taller',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Te avisaremos en cuanto el taller que elegiste acepte tu solicitud.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _formatTime(_segundosEspera),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MensajesScreen(idIncidente: widget.idIncidente),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Mensaje al taller'),
            ),
            if (widget.categoria != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _elegirOtroTaller,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Elegir otro taller'),
              ),
            ],
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _cancelar,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.close),
              label: const Text('Cancelar emergencia'),
            ),
          ],
        ),
      ),
    );
  }
}
