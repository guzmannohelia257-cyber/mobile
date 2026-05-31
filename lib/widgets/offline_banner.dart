import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../services/offline/outbox_service.dart';
import '../theme/app_colors.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _online = true;
  int _pending = 0;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    Connectivity().checkConnectivity().then(_apply);
    _connSub = Connectivity().onConnectivityChanged.listen(_apply);
    OutboxService().pendingCount.addListener(_onCount);
    _pending = OutboxService().pendingCount.value;
  }

  void _apply(List<ConnectivityResult> results) {
    if (!mounted) return;
    setState(() {
      _online = results.any((r) => r != ConnectivityResult.none);
    });
  }

  void _onCount() {
    if (!mounted) return;
    setState(() => _pending = OutboxService().pendingCount.value);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    OutboxService().pendingCount.removeListener(_onCount);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online && _pending == 0) return const SizedBox.shrink();

    final isSync = _online;
    final bg = isSync ? AppColors.amber : AppColors.brand;
    final icon = isSync ? Icons.sync_rounded : Icons.cloud_off_rounded;
    final text = isSync
        ? 'Sincronizando $_pending acción${_pending == 1 ? '' : 'es'}…'
        : 'Sin conexión · $_pending pendiente${_pending == 1 ? '' : 's'}';

    return SafeArea(
      bottom: false,
      child: Material(
        color: bg,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
