import 'package:flutter/material.dart';
import '../services/realtime_service.dart';
import '../theme/app_colors.dart';

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final rt = RealtimeService();
    return StreamBuilder<WsState>(
      stream: rt.state,
      initialData: rt.currentState,
      builder: (_, snap) {
        final s = snap.data ?? WsState.disconnected;
        late final Color dot;
        late final Color fg;
        late final Color bg;
        late final String label;

        switch (s) {
          case WsState.connected:
            dot = const Color(0xFF22C55E);
            fg = AppColors.forest;
            bg = AppColors.forestSoft;
            label = 'En vivo';
            break;
          case WsState.connecting:
            dot = AppColors.amber;
            fg = const Color(0xFF7C2D12);
            bg = AppColors.amberSoft;
            label = 'Conectando';
            break;
          case WsState.reconnecting:
            dot = AppColors.amber;
            fg = const Color(0xFF7C2D12);
            bg = AppColors.amberSoft;
            label = 'Reconectando';
            break;
          case WsState.disconnected:
            dot = AppColors.inkFaint;
            fg = AppColors.inkSubtle;
            bg = AppColors.overlay;
            label = 'Sin conexión';
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: fg.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
