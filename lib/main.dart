import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'widgets/brand_mark.dart';
import 'screens/login_screen.dart';
import 'screens/conductor_home.dart';
import 'screens/tecnico_dashboard_screen.dart';
import 'screens/mis_vehiculos_screen.dart';
import 'screens/registrar_vehiculo_screen.dart';
import 'screens/vehiculo_debug_screen.dart';
import 'screens/perfil_screen.dart';
import 'screens/reportar_emergencia_screen.dart';
import 'screens/historial_emergencias_screen.dart';
import 'screens/mis_pagos_screen.dart';
import 'screens/asignacion_detalle_screen.dart';
import 'screens/mensajes_screen.dart';
import 'screens/notificaciones_screen.dart';
import 'screens/calificar_servicio_screen.dart';
import 'screens/cotizaciones_screen.dart';
import 'screens/esperando_taller_screen.dart';
import 'screens/cliente_tracking_screen.dart';
import 'screens/seleccionar_taller_login_screen.dart';
import 'config/stripe_config.dart';
import 'services/auth_service.dart';
import 'services/tecnico_auth_service.dart';
import 'services/notification_service.dart';
import 'services/realtime_service.dart';
import 'services/offline/outbox_service.dart';
import 'widgets/offline_banner.dart';
import 'utils/app_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await OutboxService().start();

  AppLogger.separator(title: 'INICIANDO APLICACIÓN');

  Stripe.publishableKey = StripeConfig.publishableKey;

  try {
    await SharedPreferences.getInstance();
    AppLogger.success('SharedPreferences inicializado', tag: 'MAIN');
  } catch (e) {
    AppLogger.error('Error SharedPreferences', tag: 'MAIN', error: e);
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final userId = prefs.getString('user_id');
    if (token != null && token.isNotEmpty) {
      RealtimeService().connect(token);
      if (userId != null && userId.isNotEmpty) {
        RealtimeService().subscribe('usuario:$userId');
      }
    }
  } catch (e) {
    AppLogger.warning('No se pudo iniciar RealtimeService', tag: 'MAIN');
  }

  try {
    await Firebase.initializeApp();
    await NotificationService().init();
    AppLogger.success('Firebase inicializado', tag: 'MAIN');
  } catch (e) {
    AppLogger.error('Firebase no disponible (sin google-services.json?)', tag: 'MAIN', error: e);
  }

  AppLogger.info('Iniciando aplicación...', tag: 'MAIN');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Flujo Emergencia — Asistencia Vehicular',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) {
        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const _InitialScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/conductor-home': (context) => const ConductorHomeScreen(),
        '/tecnico-home': (context) => const TecnicoDashboardScreen(),
        '/tecnico-dashboard': (context) => const TecnicoDashboardScreen(),
        '/mis-vehiculos': (context) => MisVehiculosScreen(),
        '/registrar-vehiculo': (context) => RegistrarVehiculoScreen(),
        '/debug-vehiculos': (context) => VehiculoDebugScreen(),
        '/perfil': (context) => const PerfilScreen(),
        '/reportar-emergencia': (context) =>
            const ReportarEmergenciaScreen(vehiculos: []),
        '/historial-emergencias': (context) =>
            const HistorialEmergenciasScreen(),
        '/mis-pagos': (context) => const MisPagosScreen(),
        '/notificaciones': (context) => const NotificacionesScreen(),
        '/calificar-servicio': (context) {
          final id = ModalRoute.of(context)?.settings.arguments as int?;
          if (id == null || id == 0) {
            return const Scaffold(
              body: Center(child: Text('Incidente no disponible')),
            );
          }
          return CalificarServicioScreen(idIncidente: id);
        },
        '/asignacion-detalle': (context) {
          final id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
          return AsignacionDetalleScreen(idAsignacion: id);
        },
        '/mensajes': (context) {
          final id = ModalRoute.of(context)?.settings.arguments as int? ?? 0;
          return MensajesScreen(idIncidente: id);
        },
        '/cotizaciones': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final id = args?['id_incidente'] as int?;
          if (id == null || id == 0) {
            return const Scaffold(
              body: Center(child: Text('Incidente no disponible')),
            );
          }
          return CotizacionesScreen(idIncidente: id);
        },
        '/esperando-taller': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final id = args?['id_incidente'] as int?;
          if (id == null || id == 0) {
            return const Scaffold(
              body: Center(child: Text('Incidente no disponible')),
            );
          }
          return EsperandoTallerScreen(idIncidente: id);
        },
        '/cliente-tracking': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final idInc = args?['id_incidente'] as int?;
          final idAsig = args?['id_asignacion'] as int?;
          if (idInc == null || idAsig == null) {
            return const Scaffold(
              body: Center(child: Text('Datos de seguimiento incompletos')),
            );
          }
          // ubicacion_incidente puede venir como LatLng o como Map {lat, lng}
          final ubic = args?['ubicacion_incidente'];
          LatLng latLng;
          if (ubic is LatLng) {
            latLng = ubic;
          } else if (ubic is Map) {
            latLng = LatLng(
              (ubic['lat'] ?? ubic['latitud'] ?? -16.5).toDouble(),
              (ubic['lng'] ?? ubic['longitud'] ?? -68.15).toDouble(),
            );
          } else {
            latLng = const LatLng(-16.5, -68.15);
          }
          return ClienteTrackingScreen(
            idIncidente: idInc,
            idAsignacion: idAsig,
            ubicacionIncidente: latLng,
            taller: args?['taller'] as Map<String, dynamic>?,
          );
        },
        '/seleccionar-taller-login': (context) =>
            const SeleccionarTallerLoginScreen(),
      },
    );
  }
}

class _InitialScreen extends StatefulWidget {
  const _InitialScreen();

  @override
  State<_InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<_InitialScreen> {
  final AuthService _authService = AuthService();
  final TecnicoAuthService _tecnicoAuthService = TecnicoAuthService();

  @override
  void initState() {
    super.initState();
    AppLogger.info('Iniciando verificación de autenticación...', tag: 'INITIAL_SCREEN');
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      AppLogger.debug('Esperando 500ms antes de verificar...', tag: 'INITIAL_SCREEN');
      await Future.delayed(const Duration(milliseconds: 500));
      
      AppLogger.info('Verificando si hay sesión activa...', tag: 'INITIAL_SCREEN');
      
      final isAuthenticated = await _authService.isAuthenticated();
      AppLogger.info('Estado de autenticación: ${isAuthenticated ? 'Autenticado ✅' : 'No autenticado ❌'}', tag: 'INITIAL_SCREEN');

      if (!mounted) {
        AppLogger.warning('El widget fue desmontado, canceling navegación', tag: 'INITIAL_SCREEN');
        return;
      }

      if (isAuthenticated) {
        final userRole = await _authService.getUserRole();
        final userName = await _authService.getUserName();
        final userId = await _authService.getUserId();
        final tecnicoLogged = await _tecnicoAuthService.isTecnicoLoggedIn();

        AppLogger.table('Información de Usuario', {
          'Nombre': userName ?? 'N/A',
          'ID': userId ?? 'N/A',
          'Rol': userRole ?? 'N/A',
          'Token Técnico': tecnicoLogged ? 'Sí' : 'No',
        }, tag: 'INITIAL_SCREEN');

        if (!mounted) return;
        if (userRole == '1') {
          AppLogger.success('Navegando a: Conductor Home', tag: 'INITIAL_SCREEN');
          Navigator.of(context).pushReplacementNamed('/conductor-home');
        } else if (userRole == '3') {
          AppLogger.success('Navegando a: Técnico Dashboard', tag: 'INITIAL_SCREEN');
          Navigator.of(context).pushReplacementNamed('/tecnico-dashboard');
        } else {
          AppLogger.warning('Rol desconocido: $userRole', tag: 'INITIAL_SCREEN');
          Navigator.of(context).pushReplacementNamed('/login');
        }
      } else {
        AppLogger.info('Sin sesión activa, navegando a Login', tag: 'INITIAL_SCREEN');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error crítico al verificar autenticación',
        tag: 'INITIAL_SCREEN',
        error: e,
        stackTrace: stackTrace,
      );
      
      if (mounted) {
        AppLogger.info('Navegando a Login como fallback', tag: 'INITIAL_SCREEN');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brand.withValues(alpha: 0.10),
                    AppColors.brand.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.slate.withValues(alpha: 0.06),
                    AppColors.slate.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(size: 76),
                const SizedBox(height: 28),
                Text(
                  'Flujo Emergencia',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Asistencia vehicular en carretera',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.brand),
                    backgroundColor:
                        AppColors.brand.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Text(
                'PREPARANDO TU EXPERIENCIA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                  color: AppColors.inkFaint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
