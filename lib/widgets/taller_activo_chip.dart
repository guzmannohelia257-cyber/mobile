import 'package:flutter/material.dart';

import '../models/taller_activo.dart';
import '../services/tecnico_auth_service.dart';

/// Chip del AppBar del tecnico que muestra el taller activo (post-M9)
/// y ofrece menu para cambiar de taller o cerrar sesion.
///
/// Insertar en `appBar: AppBar(actions: [const TallerActivoChip(), ...])`.
class TallerActivoChip extends StatefulWidget {
  const TallerActivoChip({super.key});

  @override
  State<TallerActivoChip> createState() => _TallerActivoChipState();
}

class _TallerActivoChipState extends State<TallerActivoChip> {
  TallerActivo? _taller;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final t = await TecnicoAuthService().tallerActivoActual();
    if (!mounted) return;
    setState(() => _taller = t);
  }

  Future<void> _cambiarTaller() async {
    // Cierra la sesion y navega al selector de taller M9.
    await TecnicoAuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/seleccionar-taller-login',
      (route) => false,
    );
  }

  Future<void> _cerrarSesion() async {
    await TecnicoAuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_taller == null) return const SizedBox.shrink();
    final nombre = _taller!.nombre;
    return PopupMenuButton<String>(
      tooltip: 'Taller activo: $nombre',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.business, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                nombre,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.white),
          ],
        ),
      ),
      onSelected: (value) {
        if (value == 'cambiar') _cambiarTaller();
        if (value == 'logout') _cerrarSesion();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'header',
          enabled: false,
          child: Text('Sesion del tecnico', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'cambiar',
          child: Row(children: [
            Icon(Icons.swap_horiz, size: 18),
            SizedBox(width: 8),
            Text('Cambiar taller'),
          ]),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(children: [
            Icon(Icons.logout, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Cerrar sesion', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}
