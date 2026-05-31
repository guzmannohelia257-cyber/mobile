import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/cotizacion.dart';

class CotizacionService {
  static const String baseUrl = ApiConfig.baseUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    final secureToken = await _secureStorage.read(key: 'token');
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, dynamic>> solicitar({
    required int idIncidente,
    double radioKm = 20,
    int maxTalleres = 3,
    int validezHoras = 2,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw 'No autenticado';
    }

    final response = await http.post(
      Uri.parse('$baseUrl/incidentes/$idIncidente/cotizaciones/solicitar'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'radio_km': radioKm,
        'max_talleres': maxTalleres,
        'validez_horas': validezHoras,
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw body['detail'] ?? 'Error solicitando';
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Cotizacion>> listar(int idIncidente) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw 'No autenticado';
    }

    final response = await http.get(
      Uri.parse('$baseUrl/incidentes/$idIncidente/cotizaciones'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw 'Error listando';
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((j) => Cotizacion.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<int> aceptar(int idCotizacion) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw 'No autenticado';
    }

    final response = await http.post(
      Uri.parse('$baseUrl/cotizaciones/$idCotizacion/aceptar'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw body['detail'] ?? 'Error';
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id_asignacion'] ?? 0;
  }
}
