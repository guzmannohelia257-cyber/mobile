import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';
import 'notification_service.dart';
import 'realtime_service.dart';

class AuthService {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String _tag = 'AuthService';

  // Registro exclusivo para clientes (rol=1 en backend)
  Future<Map<String, dynamic>> registrarCliente({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    AppLogger.separator(title: 'INICIANDO REGISTRO CLIENTE');
    AppLogger.auth('Intento de registro cliente con: $email', tag: _tag);

    try {
      final url = '$baseUrl/usuarios/registro';
      final body = {
        'nombre': nombre,
        'email': email,
        'password': password,
        'telefono': (telefono == null || telefono.trim().isEmpty) ? null : telefono.trim(),
      };

      AppLogger.httpRequest(
        'POST',
        url,
        tag: _tag,
        body: body,
        headers: {'Content-Type': 'application/json'},
      );

      final startTime = DateTime.now();
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final duration = DateTime.now().difference(startTime);
      AppLogger.httpResponse(
        'POST',
        url,
        response.statusCode,
        tag: _tag,
        duration: duration,
        body: response.body.length > 500
            ? '${response.body.substring(0, 500)}...'
            : response.body,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        AppLogger.success('Registro cliente exitoso para: $email', tag: _tag);
        return {'success': true, 'data': data};
      }

      try {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['detail'] ?? 'Error en registro';
        return {'success': false, 'error': errorMessage.toString()};
      } catch (_) {
        return {
          'success': false,
          'error': 'Error del servidor: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Timeout: No se puede conectar con el servidor. Intenta de nuevo.',
      };
    } catch (e) {
      AppLogger.error('Error inesperado en registro cliente', tag: _tag, error: e);
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Inicio de sesión con email y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    AppLogger.separator(title: 'INICIANDO LOGIN');
    AppLogger.auth('Intento de login con: $email', tag: _tag);
    
    try {
      final url = '$baseUrl/usuarios/login';
      final body = {
        'email': email,
        'password': password,
      };
      
      AppLogger.httpRequest('POST', url, 
        tag: _tag,
        body: body,
        headers: {'Content-Type': 'application/json'},
      );
      
      final startTime = DateTime.now();
      
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30), onTimeout: () {
            AppLogger.error(
              'Timeout esperando respuesta del servidor (30s)',
              tag: _tag,
            );
            AppLogger.info(
              'URL intentado: $url',
              tag: _tag,
            );
            AppLogger.info(
              'Verifica que el API está corriendo en esa dirección',
              tag: _tag,
            );
            throw TimeoutException(
              'No se recibió respuesta en 30 segundos',
              const Duration(seconds: 30),
            );
          });

      final duration = DateTime.now().difference(startTime);
      
      AppLogger.httpResponse(
        'POST',
        url,
        response.statusCode,
        tag: _tag,
        duration: duration,
        body: response.body.length > 500 
          ? '${response.body.substring(0, 500)}...'
          : response.body,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          AppLogger.success('Login exitoso para: $email', tag: _tag);
          AppLogger.info('Guardando datos del usuario...', tag: _tag);
          
          await _saveUserData(data);

          AppLogger.success('Datos del usuario guardados correctamente', tag: _tag);

          final token = data['access_token']?.toString();
          if (token != null && token.isNotEmpty) {
            RealtimeService().connect(token);
          }

          final usuario = data['usuario'] as Map<String, dynamic>?;
          final userId = usuario?['id_usuario']?.toString();
          if (userId != null && userId.isNotEmpty) {
            RealtimeService().subscribe('usuario:$userId');
          }

          // Registrar token FCM para que las notificaciones lleguen al usuario actual
          NotificationService().syncTokenWithBackend();

          return {
            'success': true,
            'data': data,
          };
        } catch (parseError) {
          AppLogger.error(
            'Error al parsear respuesta JSON: $parseError',
            tag: _tag,
            error: parseError,
          );
          return {
            'success': false,
            'error': 'Error al procesar respuesta del servidor',
          };
        }
      } else {
        AppLogger.warning(
          'Status code no exitoso: ${response.statusCode}',
          tag: _tag,
        );
        
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['detail'] ?? 'Error en login';
          AppLogger.error('Error del servidor: $errorMessage', tag: _tag);
          
          return {
            'success': false,
            'error': errorMessage,
          };
        } catch (e) {
          final errorMsg = 'Error del servidor: ${response.statusCode}';
          AppLogger.error(errorMsg, tag: _tag);
          
          return {
            'success': false,
            'error': errorMsg,
          };
        }
      }
    } on TimeoutException catch (e) {
      AppLogger.error(
        'TimeoutException: No se recibió respuesta del servidor',
        tag: _tag,
        error: e,
      );
      AppLogger.info('Verifica:',  tag: _tag);
      AppLogger.info('  1. El API está corriendo en $baseUrl',  tag: _tag);
      AppLogger.info('  2. La red está conectada',  tag: _tag);
      AppLogger.info('  3. El firewall permite la conexión',  tag: _tag);
      
      return {
        'success': false,
        'error': 'Timeout: No se puede conectar con el servidor. Intenta de nuevo.',
      };
    } catch (e) {
      AppLogger.error(
        'Error inesperado en login',
        tag: _tag,
        error: e,
      );
      
      return {
        'success': false,
        'error': 'Error de conexión: $e',
      };
    }
  }

  // Guarda los datos del usuario en SharedPreferences
  Future<void> _saveUserData(Map<String, dynamic> data) async {
    AppLogger.info('Iniciando guardado de datos del usuario...', tag: _tag);
    
    try {
      final prefs = await SharedPreferences.getInstance();

      // Validar que existan los datos necesarios
      if (!data.containsKey('access_token')) {
        throw Exception('Token no encontrado en respuesta');
      }
      
      if (!data.containsKey('usuario')) {
        throw Exception('Datos del usuario no encontrados en respuesta');
      }

      final usuario = data['usuario'];
      
      AppLogger.storage('Guardando access_token...', tag: _tag);
      await prefs.setString('access_token', data['access_token'] ?? '');
      
      AppLogger.storage('Guardando token_type...', tag: _tag);
      await prefs.setString('token_type', data['token_type'] ?? 'bearer');
      
      AppLogger.storage('Guardando user_id...', tag: _tag);
      await prefs.setString('user_id', usuario['id_usuario'].toString());
      
      AppLogger.storage('Guardando user_rol...', tag: _tag);
      await prefs.setString('user_rol', usuario['id_rol'].toString());
      
      AppLogger.storage('Guardando user_name...', tag: _tag);
      await prefs.setString('user_name', usuario['nombre'] ?? 'Usuario');
      
      AppLogger.storage('Guardando user_email...', tag: _tag);
      await prefs.setString('user_email', usuario['email'] ?? '');
      
      AppLogger.storage('Guardando user_activo...', tag: _tag);
      await prefs.setBool('user_activo', usuario['activo'] ?? false);
      
      AppLogger.storage('Guardando login_time...', tag: _tag);
      await prefs.setString('login_time', DateTime.now().toIso8601String());
      
      AppLogger.table('Usuario Guardado', {
        'ID': usuario['id_usuario'].toString(),
        'Email': usuario['email'] ?? 'N/A',
        'Nombre': usuario['nombre'] ?? 'N/A',
        'Rol': usuario['id_rol'].toString(),
        'Activo': usuario['activo'].toString(),
      }, tag: _tag);
      
      AppLogger.success('Todos los datos guardados correctamente', tag: _tag);
    } catch (e) {
      AppLogger.error(
        'Error crítico al guardar datos: $e',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  // Recupera el token almacenado
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      
      if (token != null && token.isNotEmpty) {
        AppLogger.debug('Token recuperado exitosamente', tag: _tag);
        return token;
      } else {
        AppLogger.warning('No hay token guardado', tag: _tag);
        return null;
      }
    } catch (e) {
      AppLogger.error('Error al recuperar token', tag: _tag, error: e);
      return null;
    }
  }

  // Obtiene el ID del usuario
  Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      
      if (userId != null && userId.isNotEmpty) {
        AppLogger.debug('User ID: $userId', tag: _tag);
        return userId;
      } else {
        AppLogger.warning('No hay user_id guardado', tag: _tag);
        return null;
      }
    } catch (e) {
      AppLogger.error('Error getting user ID', tag: _tag, error: e);
      return null;
    }
  }

  // Obtiene el rol del usuario
  Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_rol');
      
      if (role != null && role.isNotEmpty) {
        AppLogger.debug('User Role: $role', tag: _tag);
        return role;
      } else {
        AppLogger.warning('No hay user_rol guardado', tag: _tag);
        return null;
      }
    } catch (e) {
      AppLogger.error('Error getting user role', tag: _tag, error: e);
      return null;
    }
  }

  // Obtiene el nombre del usuario
  Future<String?> getUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name');
      
      if (name != null && name.isNotEmpty) {
        AppLogger.debug('User Name: $name', tag: _tag);
        return name;
      } else {
        AppLogger.warning('No hay user_name guardado', tag: _tag);
        return null;
      }
    } catch (e) {
      AppLogger.error('Error getting user name', tag: _tag, error: e);
      return null;
    }
  }

  // Obtiene el email del usuario
  Future<String?> getUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      
      if (email != null && email.isNotEmpty) {
        AppLogger.debug('User Email: $email', tag: _tag);
        return email;
      } else {
        AppLogger.warning('No hay user_email guardado', tag: _tag);
        return null;
      }
    } catch (e) {
      AppLogger.error('Error getting user email', tag: _tag, error: e);
      return null;
    }
  }

  // Verifica si el usuario está autenticado
  Future<bool> isAuthenticated() async {
    try {
      final token = await getToken();
      final isAuth = token != null && token.isNotEmpty;
      
      AppLogger.debug('Verificación de autenticación: ${isAuth ? 'Autenticado' : 'No autenticado'}', tag: _tag);
      
      return isAuth;
    } catch (e) {
      AppLogger.error('Error checking authentication', tag: _tag, error: e);
      return false;
    }
  }

  // Cierra sesión y limpia todos los datos almacenados
  Future<void> logout() async {
    AppLogger.info('Iniciando proceso de logout...', tag: _tag);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      AppLogger.storage('Limpiando access_token...', tag: _tag);
      await prefs.remove('access_token');
      
      AppLogger.storage('Limpiando token_type...', tag: _tag);
      await prefs.remove('token_type');
      
      AppLogger.storage('Limpiando user_id...', tag: _tag);
      await prefs.remove('user_id');
      
      AppLogger.storage('Limpiando user_rol...', tag: _tag);
      await prefs.remove('user_rol');
      
      AppLogger.storage('Limpiando user_name...', tag: _tag);
      await prefs.remove('user_name');
      
      AppLogger.storage('Limpiando user_email...', tag: _tag);
      await prefs.remove('user_email');
      
      AppLogger.storage('Limpiando user_activo...', tag: _tag);
      await prefs.remove('user_activo');
      
      AppLogger.storage('Limpiando login_time...', tag: _tag);
      await prefs.remove('login_time');
      
      AppLogger.success('Logout completado y datos limpios', tag: _tag);
      RealtimeService().disconnect();
    } catch (e) {
      AppLogger.error('Error al hacer logout', tag: _tag, error: e);
    }
  }

  // Realiza una solicitud HTTP autenticada con el token del usuario
  Future<http.Response> authenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    AppLogger.debug('Preparando solicitud autenticada: $method $endpoint', tag: _tag);
    
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        AppLogger.error('No hay token de autenticación disponible', tag: _tag);
        throw Exception('No authentication token found');
      }

      AppLogger.debug('Token encontrado, longitud: ${token.length}', tag: _tag);

      final requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      final url = Uri.parse('$baseUrl$endpoint');
      final startTime = DateTime.now();

      AppLogger.httpRequest(
        method,
        url.toString(),
        tag: _tag,
        body: body,
        headers: requestHeaders,
      );

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: requestHeaders)
              .timeout(const Duration(seconds: 30));
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 30));
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(const Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await http.delete(
            url,
            headers: requestHeaders,
          ).timeout(const Duration(seconds: 30));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      final duration = DateTime.now().difference(startTime);
      
      AppLogger.httpResponse(
        method,
        url.toString(),
        response.statusCode,
        tag: _tag,
        duration: duration,
        body: response.body.length > 200 
          ? '${response.body.substring(0, 200)}...'
          : response.body,
      );

      return response;
    } catch (e) {
      AppLogger.error(
        'Error en solicitud autenticada',
        tag: _tag,
        error: e,
      );
      rethrow;
    }
  }

  // Ver perfil
  Future<Map<String, dynamic>> obtenerPerfil() async {
    try {
      final response = await authenticatedRequest('GET', '/usuarios/perfil');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Perfil obtenido correctamente');
        return {'success': true, 'perfil': data};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sesión expirada. Por favor inicia sesión nuevamente'};
      } else {
        return {'success': false, 'error': 'Error al obtener perfil: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('❌ Error en obtenerPerfil: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  // Editar perfil
  Future<Map<String, dynamic>> editarPerfil({
    String? nombre,
    String? telefono,
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nombre != null) body['nombre'] = nombre;
      if (telefono != null) body['telefono'] = telefono;
      if (password != null) body['password'] = password;

      if (body.isEmpty) {
        return {'success': false, 'error': 'No hay campos para actualizar'};
      }

      final response = await authenticatedRequest(
        'PUT',
        '/usuarios/perfil',
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Actualizar datos en SharedPreferences si se cambió el nombre
        if (nombre != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', nombre);
        }
        
        debugPrint('✅ Perfil actualizado correctamente');
        return {'success': true, 'perfil': data};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sesión expirada. Por favor inicia sesión nuevamente'};
      } else if (response.statusCode == 422) {
        return {'success': false, 'error': 'Datos inválidos. Verifica los campos'};
      } else {
        return {'success': false, 'error': 'Error al actualizar perfil: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('❌ Error en editarPerfil: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
}
