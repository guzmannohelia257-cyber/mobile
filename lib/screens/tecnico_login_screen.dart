import 'package:flutter/material.dart';

import '../models/taller_publico.dart';
import '../services/notification_service.dart';
import '../services/tecnico_auth_service.dart';

class TecnicoLoginScreen extends StatefulWidget {
  final TallerPublico taller;

  const TecnicoLoginScreen({
    super.key,
    required this.taller,
  });

  @override
  State<TecnicoLoginScreen> createState() => _TecnicoLoginScreenState();
}

class _TecnicoLoginScreenState extends State<TecnicoLoginScreen> {
  final TecnicoAuthService _authService = TecnicoAuthService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Completa email y contrasena';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.login(
        email: email,
        password: password,
        idTaller: widget.taller.idTaller,
      );

      await _notificationService.syncTokenWithBackend();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/tecnico-dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taller.nombre),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vas a entrar como tecnico de ${widget.taller.nombre}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _loading
                      ? null
                      : () => setState(() {
                            _emailController.text = 'juanperez.tecnico@gmail.com';
                            _passwordController.text = 'tecnico123!';
                          }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.bolt_outlined,
                            size: 13, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Demo',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contrasena',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Iniciar Sesion'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).pushReplacementNamed('/login'),
              child: const Text('Volver al login general'),
            ),
          ],
        ),
      ),
    );
  }
}
