import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/brand_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  static const String _tag = 'LoginScreen';
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    AppLogger.info('Pantalla de Login iniciada', tag: _tag);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    AppLogger.separator(title: 'INTENTANDO LOGIN MANUAL');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Completa tu correo y contraseña para continuar.';
        _isLoading = false;
      });
      return;
    }

    final result = await _authService.login(email, password);

    if (!mounted) return;

    if (result['success']) {
      final userData = result['data']['usuario'];
      final userRole = userData['id_rol'].toString();

      await _notificationService.syncTokenWithBackend();
      if (!mounted) return;

      if (userRole == '1') {
        Navigator.of(context).pushReplacementNamed('/conductor-home');
      } else if (userRole == '3') {
        Navigator.of(context).pushReplacementNamed('/tecnico-dashboard');
      } else {
        setState(() {
          _errorMessage = 'Tu cuenta no tiene acceso a esta aplicación.';
          _isLoading = false;
        });
      }
    } else {
      final raw = result['error'];
      String msg;
      if (raw is String) {
        msg = raw;
      } else if (raw is List && raw.isNotEmpty) {
        msg = raw.map((e) {
          if (e is Map && e['msg'] != null) return e['msg'].toString();
          return e.toString();
        }).join(', ');
      } else {
        msg = raw?.toString() ?? 'Error en el login';
      }
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _mostrarRegistroCliente() async {
    final nombreController = TextEditingController();
    final emailController = TextEditingController();
    final telefonoController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool loading = false;
    String? error;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final nombre = nombreController.text.trim();
              final email = emailController.text.trim();
              final telefono = telefonoController.text.trim();
              final password = passwordController.text;
              final confirmPassword = confirmPasswordController.text;

              if (nombre.length < 3) {
                setSheetState(() =>
                    error = 'Ingresa tu nombre completo (mínimo 3 caracteres).');
                return;
              }
              if (email.isEmpty || !email.contains('@')) {
                setSheetState(() => error = 'El correo no es válido.');
                return;
              }
              if (password.length < 8) {
                setSheetState(() =>
                    error = 'La contraseña debe tener al menos 8 caracteres.');
                return;
              }
              if (password != confirmPassword) {
                setSheetState(() => error = 'Las contraseñas no coinciden.');
                return;
              }

              setSheetState(() {
                loading = true;
                error = null;
              });

              final result = await _authService.registrarCliente(
                nombre: nombre,
                email: email,
                password: password,
                telefono: telefono.isEmpty ? null : telefono,
              );

              if (!sheetContext.mounted) return;

              if (result['success'] == true) {
                _emailController.text = email;
                _passwordController.text = password;
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cuenta creada. Inicia sesión para continuar.',
                      ),
                    ),
                  );
                }
                return;
              }

              setSheetState(() {
                loading = false;
                error = (result['error'] ?? 'No se pudo crear la cuenta.')
                    .toString();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Crear cuenta',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Solo para conductores. Las cuentas de técnicos las gestiona cada taller.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      _Field(
                        controller: nombreController,
                        enabled: !loading,
                        label: 'Nombre completo',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: emailController,
                        enabled: !loading,
                        label: 'Correo electrónico',
                        icon: Icons.alternate_email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: telefonoController,
                        enabled: !loading,
                        label: 'Teléfono (opcional)',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: passwordController,
                        enabled: !loading,
                        label: 'Contraseña',
                        icon: Icons.lock_outline_rounded,
                        obscure: obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.inkMuted,
                          ),
                          onPressed: () => setSheetState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        controller: confirmPasswordController,
                        enabled: !loading,
                        label: 'Confirmar contraseña',
                        icon: Icons.lock_outline_rounded,
                        obscure: obscureConfirmPassword,
                        suffix: IconButton(
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: AppColors.inkMuted,
                          ),
                          onPressed: () => setSheetState(
                            () => obscureConfirmPassword =
                                !obscureConfirmPassword,
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorTile(message: error!),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: loading ? null : submit,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text('Crear cuenta'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nombreController.dispose();
    emailController.dispose();
    telefonoController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
  }

  Future<void> _autoLoginConductor() async {
    AppLogger.separator(title: 'AUTO-LOGIN CONDUCTOR');
    await _handleLoginWithCredentials(
      'lucia.gutierrez@gmail.com',
      'cliente2026#',
    );
  }

  void _irASelectorTallerTecnico() {
    AppLogger.info('Tecnico: redirigiendo al selector de taller (M9)',
        tag: _tag);
    Navigator.of(context).pushNamed('/seleccionar-taller-login');
  }

  Future<void> _handleLoginWithCredentials(String email, String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _emailController.text = email;
      _passwordController.text = password;
    });

    final result = await _authService.login(email, password);

    if (!mounted) return;

    if (result['success']) {
      final userData = result['data']['usuario'];
      final userRole = userData['id_rol'].toString();

      await _notificationService.syncTokenWithBackend();
      if (!mounted) return;

      if (userRole == '1') {
        Navigator.of(context).pushReplacementNamed('/conductor-home');
      } else if (userRole == '3') {
        await _authService.logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecciona tu taller para continuar.'),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/seleccionar-taller-login');
      }
    } else {
      final raw = result['error'];
      String msg;
      if (raw is String) {
        msg = raw;
      } else if (raw is List && raw.isNotEmpty) {
        msg = raw.map((e) {
          if (e is Map && e['msg'] != null) return e['msg'].toString();
          return e.toString();
        }).join(', ');
      } else {
        msg = raw?.toString() ?? 'Error en el login';
      }
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAllData() async {
    try {
      await _authService.logout();
      setState(() {
        _emailController.clear();
        _passwordController.clear();
        _errorMessage = null;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión local limpiada.')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al limpiar: $e';
      });
    }
  }

  void _showDevMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'MODO DEMO',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DevTile(
                icon: Icons.bolt_outlined,
                title: 'Entrar como conductor demo',
                subtitle: 'lucia.gutierrez@gmail.com',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _autoLoginConductor();
                },
              ),
              _DevTile(
                icon: Icons.handyman_outlined,
                title: 'Acceso de técnico',
                subtitle: 'Seleccionar taller',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _irASelectorTallerTecnico();
                },
              ),
              const Divider(height: 24),
              _DevTile(
                icon: Icons.edit_outlined,
                title: 'Autorellenar conductor',
                subtitle: 'lucia.gutierrez@gmail.com',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    _emailController.text = 'lucia.gutierrez@gmail.com';
                    _passwordController.text = 'cliente2026#';
                  });
                },
              ),
              _DevTile(
                icon: Icons.edit_outlined,
                title: 'Autorellenar técnico',
                subtitle: 'rodrigo.anez@gmail.com',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() {
                    _emailController.text = 'rodrigo.anez@gmail.com';
                    _passwordController.text = 'tecnico2026#';
                  });
                },
              ),
              _DevTile(
                icon: Icons.cleaning_services_outlined,
                title: 'Limpiar sesión local',
                subtitle: 'Cierra y borra el token guardado',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _clearAllData();
                },
                isDestructive: true,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Fondo con degradado principal
          Container(
            height: size.height * 0.42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFB11D27),
                  Color(0xFF7C1419),
                  Color(0xFF4A0F14),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado de marca
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BrandMark(size: 56, onDark: true),
                        const SizedBox(height: 22),
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Asistencia\nvehicular cuando\nmás la necesitas.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tarjeta del formulario superpuesta sobre el fondo
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: AppColors.shadowLg,
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Inicia sesión',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ingresa tus credenciales para continuar.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        _Field(
                          controller: _emailController,
                          enabled: !_isLoading,
                          label: 'Correo electrónico',
                          icon: Icons.alternate_email_rounded,
                          keyboardType: TextInputType.emailAddress,
                          onSubmit: () => _passwordFocus.requestFocus(),
                        ),
                        const SizedBox(height: 14),
                        _Field(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          enabled: !_isLoading,
                          label: 'Contraseña',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscurePassword,
                          onSubmit: _handleLogin,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.inkMuted,
                            ),
                            onPressed: () => setState(() =>
                                _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _ErrorTile(message: _errorMessage!),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: const [
                                      Text('Entrar'),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿Eres nuevo aquí?',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _mostrarRegistroCliente,
                              child: const Text('Crear cuenta'),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _QuickCredRow(
                          disabled: _isLoading,
                          onConductor: _autoLoginConductor,
                          onTecnico: _irASelectorTallerTecnico,
                        ),
                      ],
                    ),
                  ),

                  // Acceso para técnicos
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                    child: _RoleSwitchCard(
                      onTap: _isLoading
                          ? null
                          : _irASelectorTallerTecnico,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Nota legal del pie
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Flujo Emergencia · Asistencia vehicular 24/7',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _DevFab(onTap: _showDevMenu),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final FocusNode? focusNode;
  final VoidCallback? onSubmit;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.focusNode,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction:
          onSubmit != null ? TextInputAction.next : TextInputAction.done,
      onSubmitted: (_) => onSubmit?.call(),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 44, minHeight: 22),
        suffixIcon: suffix,
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.brand, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: AppColors.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSwitchCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _RoleSwitchCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: AppColors.borderSubtle,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.slate.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  color: AppColors.slate,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acceso para técnicos',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selecciona tu taller para iniciar',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.inkMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _DevTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DevTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.brand : AppColors.ink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.brandSoft
                      : AppColors.overlay,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    size: 20,
                    color: isDestructive
                        ? AppColors.brand
                        : AppColors.inkSubtle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickCredRow extends StatelessWidget {
  final bool disabled;
  final VoidCallback onConductor;
  final VoidCallback onTecnico;

  const _QuickCredRow({
    required this.disabled,
    required this.onConductor,
    required this.onTecnico,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'DEMO',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.inkFaint,
          ),
        ),
        const SizedBox(width: 10),
        _Chip(
          label: 'Conductor',
          icon: Icons.directions_car_outlined,
          onTap: disabled ? null : onConductor,
        ),
        const SizedBox(width: 6),
        _Chip(
          label: 'Técnico',
          icon: Icons.handyman_outlined,
          onTap: disabled ? null : onTecnico,
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _Chip({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.overlay,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.inkMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevFab extends StatelessWidget {
  final VoidCallback onTap;
  const _DevFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppColors.shadowMd,
      ),
      child: Material(
        color: AppColors.ink,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
