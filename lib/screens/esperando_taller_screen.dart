import 'dart:async';

import 'package:flutter/material.dart';

import '../services/realtime_service.dart';

class EsperandoTallerScreen extends StatefulWidget {
  final int idIncidente;

  const EsperandoTallerScreen({
    super.key,
    required this.idIncidente,
  });

  @override
  State<EsperandoTallerScreen> createState() => _EsperandoTallerScreenState();
}

class _EsperandoTallerScreenState extends State<EsperandoTallerScreen>
    with SingleTickerProviderStateMixin {
  final _rt = RealtimeService();
  StreamSubscription? _sub;
  late AnimationController _pulseCtrl;
  Timer? _timeoutTimer;

  int _segundosEspera = 0;
  Timer? _tickTimer;
  bool _navegando = false;

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
      final data = evt.data ?? {};
      Navigator.pushReplacementNamed(
        context,
        '/cliente-tracking',
        arguments: {
          'id_incidente': widget.idIncidente,
          'id_asignacion': data['id_asignacion'],
          'taller': data['taller'],
          'ubicacion_incidente': data['ubicacion_incidente'],
        },
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
        title: const Text('Buscando taller'),
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
              'Notificando talleres cercanos...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Te avisaremos en cuanto un taller acepte tu solicitud.',
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
          ],
        ),
      ),
    );
  }
}
