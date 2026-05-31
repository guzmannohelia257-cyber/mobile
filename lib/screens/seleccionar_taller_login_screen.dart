import 'package:flutter/material.dart';

import '../models/taller_publico.dart';
import '../services/tecnico_auth_service.dart';
import 'tecnico_login_screen.dart';

class SeleccionarTallerLoginScreen extends StatefulWidget {
  const SeleccionarTallerLoginScreen({super.key});

  @override
  State<SeleccionarTallerLoginScreen> createState() => _State();
}

class _State extends State<SeleccionarTallerLoginScreen> {
  final _svc = TecnicoAuthService();
  bool _cargando = true;
  String? _error;
  List<TallerPublico> _talleres = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      _talleres = await _svc.listarTalleresPublicos();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona tu taller')),
      body: _build(),
    );
  }

  Widget _build() {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_error!),
            const SizedBox(height: 8),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    // Demo taller (Taller Excelente, id=1 — juanperez.tecnico@gmail.com / tecnico123!)
    final tallerDemo = TallerPublico(idTaller: 1, nombre: 'Taller Excelente');

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '¿En que taller trabajas? Luego ingresaras tu email y contrasena.',
            textAlign: TextAlign.center,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TecnicoLoginScreen(taller: tallerDemo),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Demo: Taller Excelente  ·  juanperez.tecnico@gmail.com',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _talleres.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = _talleres[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.business)),
                title: Text(t.nombre),
                subtitle: t.direccion != null ? Text(t.direccion!) : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TecnicoLoginScreen(taller: t),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
