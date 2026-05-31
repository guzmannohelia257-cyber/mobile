import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

/// Handler global para mensajes en background (debe ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignorar si ya está inicializado o no es necesario en esta plataforma.
  }
  debugPrint('[FCM] Mensaje en background: ${message.messageId}');
}

class NotificationService {
  static const String _baseUrl = ApiConfig.baseUrl;
  static const String _channelId = 'flujo_emergencia_high_importance';
  static const String _channelName = 'Flujo Emergencia Notificaciones';
  static const String _channelDesc = 'Alertas de asignaciones, pagos y mensajes';

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final AuthService _authService = AuthService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Inicializa FCM. Llámalo una sola vez en main() tras Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await _initLocalNotifications();

    // Solicitar permiso en iOS / Android 13+
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permiso: ${settings.authorizationStatus}');

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Registrar token en el backend al obtenerlo
    FirebaseMessaging.instance.onTokenRefresh.listen(_registrarToken);
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _registrarToken(token);
    }

    // Mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title} ${message.data}');
      _showForegroundNotification(message);
    });

    // App abierta desde notificación (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Abierto desde notificación: ${message.data}');
      _navigateFromData(message.data);
    });

    // App abierta desde notificación estando la aplicación terminada
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] Initial message: ${initialMessage.data}');
      _navigateFromData(initialMessage.data);
    }
  }

  /// Fuerza registro del token actual en backend.
  /// Útil justo después de login para evitar perder el registro del token.
  Future<void> syncTokenWithBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] No hay token para sincronizar');
        return;
      }
      await _registrarToken(token);
    } catch (e) {
      debugPrint('[FCM] Error en syncTokenWithBackend: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          _navigateFromData(data);
        } catch (e) {
          debugPrint('[FCM] Error parsing local notif payload: $e');
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Nueva notificación';
    final body = message.notification?.body ??
        (message.data['mensaje']?.toString() ?? 'Tienes una actualización.');

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails();

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(android: android, iOS: ios),
      payload: jsonEncode(message.data),
    );
  }

  void _navigateFromData(Map<String, dynamic> data, {int retry = 0}) {
    final nav = navigatorKey.currentState;
    if (nav == null) {
      if (retry < 3) {
        Future.delayed(
          const Duration(milliseconds: 500),
          () => _navigateFromData(data, retry: retry + 1),
        );
      }
      return;
    }

    final tipo = data['tipo']?.toString() ?? '';
    final accion = data['accion']?.toString() ?? '';
    final idIncidente = int.tryParse(data['id_incidente']?.toString() ?? '');

    switch (tipo) {
      case 'nuevo_pago':
        nav.pushNamed('/mis-pagos');
        break;
      case 'solicitar_resena':
        if (accion == 'calificar_taller' && idIncidente != null) {
          nav.pushNamed('/calificar-servicio', arguments: idIncidente);
          break;
        }
        nav.pushNamed('/historial-emergencias');
        break;
      case 'estado_asignacion':
      case 'asignacion_aceptada':
        nav.pushNamed('/historial-emergencias');
        break;
      case 'mensaje':
        if (idIncidente != null) {
          nav.pushNamed('/mensajes', arguments: idIncidente);
        } else {
          nav.pushNamed('/historial-emergencias');
        }
        break;
      case 'asignacion_tecnico':
        nav.pushNamed('/tecnico-dashboard');
        break;
      default:
        nav.pushNamed('/conductor-home');
    }
  }

  Future<void> _registrarToken(String token) async {
    try {
      final authToken = await _authService.getToken();
      if (authToken == null) {
        debugPrint('[FCM] Sin auth token, no se puede registrar push token aún');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/notificaciones/push-token'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'push_token': token}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('[FCM] Token registrado en backend');
      } else {
        debugPrint('[FCM] Error al registrar token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[FCM] Error al registrar token: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listarMisNotificaciones({
    bool soloNoLeidas = false,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return [];

    final uri = Uri.parse(
      '$_baseUrl/notificaciones/mis-notificaciones?solo_no_leidas=$soloNoLeidas',
    );
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      debugPrint('[NOTIF] listarMisNotificaciones error ${response.statusCode}: ${response.body}');
      return [];
    }

    final List<dynamic> raw = jsonDecode(response.body) as List<dynamic>;
    return raw
        .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<bool> marcarLeida(int idNotificacion) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return false;

    final response = await http.put(
      Uri.parse('$_baseUrl/notificaciones/$idNotificacion/leer'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }
}
