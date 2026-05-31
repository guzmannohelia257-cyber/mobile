import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/connection_badge.dart';
import 'reportar_emergencia_screen.dart';

class ConductorHomeScreen extends StatefulWidget {
  const ConductorHomeScreen({super.key});

  @override
  State<ConductorHomeScreen> createState() => _ConductorHomeScreenState();
}

class _ConductorHomeScreenState extends State<ConductorHomeScreen> {
  final AuthService _authService = AuthService();
  String _userName = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await _authService.getUserName();

    if (!mounted) return;
    setState(() {
      _userName = name ?? 'Conductor';
      _isLoading = false;
    });
  }

  String _saludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buenos días';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(' ').where((s) => s.isNotEmpty);
    return parts.isEmpty ? fullName : parts.first;
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Volverás a la pantalla de inicio. Tu información local se mantiene.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  Future<void> _reportarEmergencia() async {
    final vehiculoService = VehiculoService();
    final resultado = await vehiculoService.listarMisVehiculos();
    if (!mounted) return;

    if (resultado['success']) {
      final vehiculos = List<Map<String, dynamic>>.from(
        (resultado['vehiculos'] as List? ?? [])
            .map((v) => Map<String, dynamic>.from(v as Map)),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReportarEmergenciaScreen(vehiculos: vehiculos),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado['error'] ?? 'Error al cargar vehículos'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildEmergencyCard(),
                        const SizedBox(height: 28),
                        _sectionLabel('ACCIONES'),
                        const SizedBox(height: 12),
                        _buildQuickGrid(),
                        const SizedBox(height: 28),
                        _sectionLabel('CONSEJOS'),
                        const SizedBox(height: 12),
                        _buildTipCard(),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: BrandMark(size: 44, onDark: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Flujo Emergencia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      'Asistencia vehicular',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const ConnectionBadge(),
              const SizedBox(width: 4),
              _IconBtn(
                icon: Icons.notifications_none_rounded,
                onTap: () =>
                    Navigator.pushNamed(context, '/notificaciones'),
              ),
              _IconBtn(
                icon: Icons.logout_rounded,
                onTap: _handleLogout,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _AvatarChip(initials: _initials(_userName)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _saludo(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _firstName(_userName),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/perfil'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border:
                        Border.all(color: AppColors.borderSubtle, width: 1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.person_outline_rounded,
                          size: 16, color: AppColors.inkSubtle),
                      SizedBox(width: 6),
                      Text(
                        'Perfil',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _reportarEmergencia,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFB11D27),
                Color(0xFF8B1620),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                right: 30,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'DISPONIBLE 24/7',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Reportar\nuna emergencia',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Un técnico será asignado y te contactará en minutos.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: const [
                              Text(
                                'Solicitar ayuda',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brand,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: AppColors.brand),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }

  Widget _buildQuickGrid() {
    final items = [
      _ActionItem(
        icon: Icons.directions_car_outlined,
        label: 'Mis vehículos',
        hint: 'Gestionar registro',
        route: '/mis-vehiculos',
        accent: AppColors.slate,
        accentSoft: AppColors.slateSoft,
      ),
      _ActionItem(
        icon: Icons.history_rounded,
        label: 'Historial',
        hint: 'Incidentes anteriores',
        route: '/historial-emergencias',
        accent: AppColors.indigo,
        accentSoft: AppColors.indigoSoft,
      ),
      _ActionItem(
        icon: Icons.payments_outlined,
        label: 'Mis pagos',
        hint: 'Pendientes y pagados',
        route: '/mis-pagos',
        accent: AppColors.forest,
        accentSoft: AppColors.forestSoft,
      ),
      _ActionItem(
        icon: Icons.notifications_none_rounded,
        label: 'Notificaciones',
        hint: 'Avisos y mensajes',
        route: '/notificaciones',
        accent: AppColors.amber,
        accentSoft: AppColors.amberSoft,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.05,
      children: items.map((it) => _ActionTile(item: it)).toList(),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.amberSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mantente seguro',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _bulletRow(
            'Si tu vehículo está detenido en carretera, activa las luces intermitentes.',
          ),
          const SizedBox(height: 10),
          _bulletRow(
            'Ubica triángulos de seguridad a 30 m y 50 m si dispones de ellos.',
          ),
          const SizedBox(height: 10),
          _bulletRow(
            'Mantén tu perfil y vehículos actualizados para una asistencia más rápida.',
          ),
        ],
      ),
    );
  }

  Widget _bulletRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.inkSubtle,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final String initials;
  const _AvatarChip({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB11D27), Color(0xFF7C1419)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.borderSubtle, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String hint;
  final String route;
  final Color accent;
  final Color accentSoft;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.hint,
    required this.route,
    required this.accent,
    required this.accentSoft,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;
  const _ActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.borderSubtle, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.accent, size: 22),
              ),
              const Spacer(),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
