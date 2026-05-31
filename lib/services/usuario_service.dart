import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';

class UsuarioService {
  static const String baseUrl = ApiConfig.baseUrl;
  
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      debugPrint('❌ Error obteniendo token: $e');
      return null;
    }
  }
  
  Future<void> _limpiarToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      debugPrint('🧹 Token eliminado de SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error limpiando token: $e');
    }
  }
  
  Future<Map<String, dynamic>> _manejarError401(String endpoint) async {
    debugPrint('❌ ERROR 401 - Autenticación rechazada en: $endpoint');
    await _limpiarToken();
    return {
      'success': false,
      'error': 'Sesión expirada. Por favor, inicia sesión nuevamente.',
      'code': 'AUTH_EXPIRED'
    };
  }
  
  // Obtener perfil
  Future<Map<String, dynamic>> obtenerPerfil() async {
    try {
      debugPrint('\n👤 === OBTENIENDO PERFIL ===');
      
      final token = await _getToken();
      if (token == null) {
        debugPrint('❌ Token es NULL');
        return {'success': false, 'error': 'No autenticado'};
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/usuarios/perfil'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      
      debugPrint('📥 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final usuario = jsonDecode(response.body);
        debugPrint('✅ Perfil cargado: ${usuario['nombre']}');
        return {'success': true, 'usuario': usuario};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/usuarios/perfil');
      }
      
      debugPrint('❌ Error: ${response.statusCode}');
      return {'success': false, 'error': 'Error al obtener perfil'};
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
  
  // Actualizar perfil
  Future<Map<String, dynamic>> actualizarPerfil({
    required String nombre,
    required String email,
    String? telefono,
  }) async {
    try {
      debugPrint('\n👤 === ACTUALIZANDO PERFIL ===');
      
      final token = await _getToken();
      if (token == null) {
        debugPrint('❌ Token es NULL');
        return {'success': false, 'error': 'No autenticado'};
      }
      
      final body = {
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
      };
      
      debugPrint('📤 Body: $body');
      
      final response = await http.put(
        Uri.parse('$baseUrl/usuarios/perfil'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      );
      
      debugPrint('📥 Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final usuario = jsonDecode(response.body);
        debugPrint('✅ Perfil actualizado');
        
        // Actualizar datos en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', usuario['nombre']);
        await prefs.setString('user_email', usuario['email']);
        
        return {'success': true, 'usuario': usuario};
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        debugPrint('⚠️ Validación: ${error['detail']}');
        return {'success': false, 'error': error['detail'] ?? 'Email ya existe'};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/usuarios/perfil');
      }
      
      debugPrint('❌ Error: ${response.statusCode}');
      return {'success': false, 'error': 'Error al actualizar perfil'};
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
}
