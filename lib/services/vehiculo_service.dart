import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';

class VehiculoService {
  static const String baseUrl = ApiConfig.baseUrl;
  
  // Obtener token con depuración
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      debugPrint('🔑 Token obtenido: ${token != null ? '${token.substring(0, 20)}...' : 'NULL'}');
      if (token == null) {
        debugPrint('⚠️ ADVERTENCIA: Token es NULL - el usuario probablemente no está autenticado');
      } else if (token.isEmpty) {
        debugPrint('⚠️ ADVERTENCIA: Token está vacío');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error obteniendo token: $e');
      return null;
    }
  }
  
  // Limpiar token cuando falla la autenticación
  Future<void> _limpiarToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      debugPrint('🧹 Token eliminado de SharedPreferences');
    } catch (e) {
      debugPrint('❌ Error limpiando token: $e');
    }
  }
  
  // Manejar error 401
  Future<Map<String, dynamic>> _manejarError401(String endpoint) async {
    debugPrint('❌ ERROR 401 - Autenticación rechazada en: $endpoint');
    debugPrint('Posibles causas:');
    debugPrint('  1. Token expirado (más de 30 minutos de login)');
    debugPrint('  2. Token inválido o corrupto');
    debugPrint('  3. Sesión cerrada desde otro dispositivo');
    
    await _limpiarToken();
    
    return {
      'success': false,
      'error': 'Sesión expirada. Por favor, inicia sesión nuevamente.',
      'code': 'AUTH_EXPIRED'
    };
  }
  
  // Mostrar todas las preferencias guardadas (depuración)
  Future<void> debugShowAllPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint('\n=== 📋 PREFERENCIAS GUARDADAS ===');
      final keys = prefs.getKeys();
      for (var key in keys) {
        final value = prefs.get(key);
        if (key.contains('token')) {
          debugPrint('$key: ${value.toString().substring(0, 30)}...');
        } else {
          debugPrint('$key: $value');
        }
      }
      debugPrint('============================\n');
    } catch (e) {
      debugPrint('Error mostrando preferencias: $e');
    }
  }
  
  // Registrar vehículo con depuración
  Future<Map<String, dynamic>> registrarVehiculo({
    required String placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) async {
    try {
      debugPrint('\n🚗 === INICIANDO REGISTRAR VEHÍCULO ===');
      debugPrint('Placa: $placa');
      
      final token = await _getToken();
      if (token == null) {
        debugPrint('❌ FATAL: Token es NULL');
        await debugShowAllPreferences();
        return {'success': false, 'error': 'No autenticado - token no encontrado'};
      }
      
      debugPrint('✅ Token encontrado');
      debugPrint('📍 Endpoint: $baseUrl/vehiculos/');
      
      final uri = Uri.parse('$baseUrl/vehiculos/');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      
      final body = {
        'placa': placa,
        'marca': marca,
        'modelo': modelo,
        'anio': anio,
        'color': color,
      };
      
      debugPrint('📤 Request:');
      debugPrint('  - Method: POST');
      debugPrint('  - Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      
      debugPrint('📥 Respuesta: ${response.statusCode}');
      debugPrint('  - Body: ${response.body}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Vehículo registrado: ${data['id_vehiculo']}');
        return {'success': true, 'vehiculo': data};
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Placa ya registrada');
        return {'success': false, 'error': 'Esta placa ya está registrada'};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/vehiculos/');
      }
      
      return {'success': false, 'error': 'Error al registrar vehículo (${response.statusCode})'};
    } catch (e) {
      debugPrint('❌ Excepción: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
  
  // Listar mis vehículos con depuración
  Future<Map<String, dynamic>> listarMisVehiculos() async {
    try {
      debugPrint('\n🚗 === INICIANDO LISTAR VEHÍCULOS ===');
      
      final token = await _getToken();
      
      if (token == null) {
        debugPrint('❌ FATAL: Token es NULL - no se puede hacer la petición');
        await debugShowAllPreferences();
        return {'success': false, 'error': 'No autenticado - token no encontrado'};
      }
      
      debugPrint('✅ Token encontrado');
      debugPrint('📍 Endpoint: $baseUrl/vehiculos/mis-autos');
      
      final uri = Uri.parse('$baseUrl/vehiculos/mis-autos');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      };
      
      debugPrint('📤 Headers enviados:');
      debugPrint('  - Authorization: Bearer ${token.substring(0, 20)}...');
      debugPrint('  - Content-Type: application/json');
      
      final response = await http.get(uri, headers: headers);
      
      debugPrint('📥 Respuesta recibida:');
      debugPrint('  - Status: ${response.statusCode}');
      debugPrint('  - Headers: ${response.headers}');
      debugPrint('  - Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Vehículos cargados exitosamente: ${data.length} vehículos');
        return {'success': true, 'vehiculos': data};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/vehiculos/mis-autos');
      }
      
      debugPrint('❌ Error: ${response.statusCode}');
      return {'success': false, 'error': 'Error al cargar vehículos (${response.statusCode})'};
    } catch (e) {
      debugPrint('❌ Excepción: $e');
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
  
  // Obtener detalles del vehículo
  Future<Map<String, dynamic>> obtenerVehiculo(int idVehiculo) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'error': 'No autenticado'};
      
      final response = await http.get(
        Uri.parse('$baseUrl/vehiculos/$idVehiculo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'vehiculo': data};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/vehiculos/$idVehiculo');
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Vehículo no encontrado'};
      }
      
      return {'success': false, 'error': 'Error al cargar vehículo'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
  
  // Editar vehículo
  Future<Map<String, dynamic>> editarVehiculo(
    int idVehiculo, {
    String? placa,
    String? marca,
    String? modelo,
    int? anio,
    String? color,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'error': 'No autenticado'};
      
      final body = <String, dynamic>{};
      if (placa != null) body['placa'] = placa;
      if (marca != null) body['marca'] = marca;
      if (modelo != null) body['modelo'] = modelo;
      if (anio != null) body['anio'] = anio;
      if (color != null) body['color'] = color;
      
      final response = await http.put(
        Uri.parse('$baseUrl/vehiculos/$idVehiculo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'vehiculo': data};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/vehiculos/$idVehiculo');
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Vehículo no encontrado'};
      } else if (response.statusCode == 409) {
        return {'success': false, 'error': 'La placa ya está registrada'};
      }
      
      return {'success': false, 'error': 'Error al editar vehículo'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
  
  // Eliminar vehículo (baja lógica)
  Future<Map<String, dynamic>> eliminarVehiculo(int idVehiculo) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'error': 'No autenticado'};
      
      final response = await http.delete(
        Uri.parse('$baseUrl/vehiculos/$idVehiculo'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'mensaje': data['detalle']};
      } else if (response.statusCode == 401) {
        return await _manejarError401('/vehiculos/$idVehiculo');
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Vehículo no encontrado'};
      }
      
      return {'success': false, 'error': 'Error al eliminar vehículo'};
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
}
