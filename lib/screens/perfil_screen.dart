import 'package:flutter/material.dart';
import '../services/usuario_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'editar_perfil_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final usuarioService = UsuarioService();

  Map<String, dynamic>? usuario;
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    cargarPerfil();
  }

  void cargarPerfil() async {
    setState(() => cargando = true);

    final resultado = await usuarioService.obtenerPerfil();

    if (!mounted) return;

    if (resultado['success']) {
      setState(() {
        usuario = resultado['usuario'];
        error = null;
      });
    } else {
      setState(() => error = resultado['error']);

      if (resultado['code'] == 'AUTH_EXPIRED') {
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }
    }

    if (!mounted) return;
    setState(() => cargando = false);
  }

  void irEditar() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarPerfilScreen(usuarioInicial: usuario!),
      ),
    );

    if (resultado != null) {
      setState(() => usuario = resultado);
    }
  }

  String _initials(String nombre) {
    final parts =
        nombre.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!cargando && usuario != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: irEditar,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
            ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 28,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No se pudo cargar tu perfil',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              error ?? '',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 200,
              child: FilledButton(
                onPressed: cargarPerfil,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final nombre = (usuario!['nombre'] ?? 'Usuario').toString();
    final email = (usuario!['email'] ?? '').toString();
    final telefono = (usuario!['telefono'] ?? '').toString();
    final activo = usuario!['activo'] == true;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1F2937),
                  Color(0xFF0B1220),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.slate.withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -50,
                  right: -30,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brand.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Avatar(initials: _initials(nombre)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getRolNombre(usuario!['id_rol']),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                  color:
                                      Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: activo
                            ? AppColors.forest.withValues(alpha: 0.18)
                            : AppColors.brand.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: activo
                              ? AppColors.forest.withValues(alpha: 0.4)
                              : AppColors.brand.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activo
                                  ? const Color(0xFF22C55E)
                                  : AppColors.brand,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            activo ? 'Cuenta activa' : 'Cuenta inactiva',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'INFORMACIÓN DE CONTACTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Correo electrónico',
                    value: email.isEmpty ? '—' : email,
                  ),
                  const _RowDivider(),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Teléfono',
                    value: telefono.isEmpty ? 'Sin registrar' : telefono,
                    placeholder: telefono.isEmpty,
                  ),
                  const _RowDivider(),
                  _InfoRow(
                    icon: Icons.event_outlined,
                    label: 'Miembro desde',
                    value: _formatoFecha(usuario!['created_at']),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'CUENTA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.edit_outlined,
                    title: 'Editar mi información',
                    subtitle: 'Nombre, correo y teléfono',
                    onTap: irEditar,
                  ),
                  const _RowDivider(),
                  _ActionRow(
                    icon: Icons.directions_car_outlined,
                    title: 'Mis vehículos',
                    subtitle: 'Gestionar vehículos registrados',
                    onTap: () =>
                        Navigator.pushNamed(context, '/mis-vehiculos'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _getRolNombre(int? idRol) {
    const roles = {
      1: 'CONDUCTOR',
      2: 'GERENTE DE TALLER',
      3: 'TÉCNICO',
      4: 'ADMINISTRADOR',
    };
    return roles[idRol ?? 0] ?? 'USUARIO';
  }

  String _formatoFecha(dynamic fecha) {
    if (fecha == null) return '—';
    try {
      final dt = DateTime.parse(fecha.toString());
      const meses = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      return '${dt.day} de ${meses[dt.month - 1]} de ${dt.year}';
    } catch (_) {
      return fecha.toString();
    }
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB11D27), Color(0xFF7C1419)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool placeholder;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.placeholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.overlay,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.inkSubtle, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: placeholder
                        ? AppColors.inkFaint
                        : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.inkSubtle, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
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

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 68),
      child: Divider(height: 1, color: AppColors.borderSubtle),
    );
  }
}
