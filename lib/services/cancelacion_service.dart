import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/cancelacion_response.dart';

class CancelacionService {
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

  Future<CancelacionResponse> cancelar(int idAsignacion, String motivo) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw 'No autenticado';
    }

    final response = await http.post(
      Uri.parse('$baseUrl/asignaciones/$idAsignacion/cancelar'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'motivo': motivo}),
    );

    if (response.statusCode == 409) {
      final body = jsonDecode(response.body);
      throw body['detail'] ?? 'No se puede cancelar';
    }

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw body['detail'] ?? 'Error cancelando';
    }

    return CancelacionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
