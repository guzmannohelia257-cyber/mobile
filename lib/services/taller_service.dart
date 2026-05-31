import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/categoria.dart';
import '../models/taller.dart';

class TallerService {
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

  Future<List<Categoria>> listarCategorias() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw 'No autenticado';
    }

    final response = await http.get(
      Uri.parse('$baseUrl/categorias'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw 'Error listando categorias';
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((j) => Categoria.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Categoria> getCategoria(int idCategoria) async {
    final categorias = await listarCategorias();
    return categorias.firstWhere(
      (c) => c.idCategoria == idCategoria,
      orElse: () => Categoria(
        idCategoria: idCategoria,
        nombre: 'Categoria',
        requiereCotizacion: false,
      ),
    );
  }

  Future<List<TallerCompatible>> compatibles({
    required int idCategoria,
    required double latitud,
    required double longitud,
    double radioKm = 20,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw 'No autenticado';
    }

    final uri = Uri.parse(
      '$baseUrl/talleres/compatibles'
      '?id_categoria=$idCategoria'
      '&latitud=$latitud'
      '&longitud=$longitud'
      '&radio_km=$radioKm',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw 'Error buscando talleres';
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((j) => TallerCompatible.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
