import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/taller_activo.dart';
import '../models/taller_publico.dart';
import 'realtime_service.dart';

class TecnicoAuthService {
  static final TecnicoAuthService _instance = TecnicoAuthService._();
  factory TecnicoAuthService() => _instance;
  TecnicoAuthService._();

  static const String _baseUrl = ApiConfig.baseUrl;
  static const String _tecnicoTokenKey = 'tecnico_token';
  static const String _tecnicoIdKey = 'tecnico_user_id';
  static const String _tecnicoRolKey = 'tecnico_user_rol';
  static const String _tecnicoTallerIdKey = 'tecnico_taller_id';
  static const String _tecnicoTallerNombreKey = 'tecnico_taller_nombre';
  static const String _tecnicoTenantIdKey = 'tecnico_tenant_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<List<TallerPublico>> listarTalleresPublicos() async {
    final r = await http.get(
      Uri.parse('$_baseUrl/tecnicos/talleres-publicos'),
    );
    if (r.statusCode != 200) throw 'Error cargando talleres';
    return (jsonDecode(r.body) as List)
        .map((j) => TallerPublico.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<TallerActivo> login({
    required String email,
    required String password,
    required int idTaller,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/tecnicos/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'id_taller': idTaller,
      }),
    );

    if (response.statusCode == 401) {
      throw Exception('Email o contrasena incorrectos');
    }
    if (response.statusCode == 403) {
      final detail = jsonDecode(response.body)['detail'] ?? 'No autorizado';
      throw Exception(detail.toString());
    }
    if (response.statusCode != 200) {
      throw Exception('Error en login');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['access_token'] as String;
    final tallerActivo =
        TallerActivo.fromJson(data['taller_activo'] as Map<String, dynamic>);
    final usuario = data['usuario'] as Map<String, dynamic>;

    await _storage.write(key: _tecnicoTokenKey, value: token);
    await _storage.write(
      key: _tecnicoIdKey,
      value: usuario['id_usuario'].toString(),
    );
    await _storage.write(key: _tecnicoRolKey, value: '3');
    await _storage.write(
      key: _tecnicoTallerIdKey,
      value: tallerActivo.idTaller.toString(),
    );
    await _storage.write(
      key: _tecnicoTallerNombreKey,
      value: tallerActivo.nombre,
    );
    await _storage.write(
      key: _tecnicoTenantIdKey,
      value: tallerActivo.idTenant.toString(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_id', usuario['id_usuario'].toString());
    await prefs.setString('user_rol', '3');
    await prefs.setString('user_name', usuario['nombre'] ?? 'Tecnico');
    await prefs.setString('user_email', usuario['email'] ?? email);

    RealtimeService().connect(token);
    RealtimeService().subscribe('usuario:${usuario['id_usuario']}');
    RealtimeService().subscribe('tenant:${tallerActivo.idTenant}');

    return tallerActivo;
  }

  Future<String?> getTecnicoToken() async {
    return _storage.read(key: _tecnicoTokenKey);
  }

  Future<int?> getTecnicoId() async {
    final id = await _storage.read(key: _tecnicoIdKey);
    return id != null ? int.tryParse(id) : null;
  }

  Future<int?> getTecnicoRol() async {
    final id = await _storage.read(key: _tecnicoRolKey);
    return id != null ? int.tryParse(id) : null;
  }

  Future<bool> isTecnicoLoggedIn() async {
    final token = await _storage.read(key: _tecnicoTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    debugPrint('[TecnicoAuthService] logout');
    RealtimeService().disconnect();
    await _storage.delete(key: _tecnicoTokenKey);
    await _storage.delete(key: _tecnicoIdKey);
    await _storage.delete(key: _tecnicoRolKey);
    await _storage.delete(key: _tecnicoTallerIdKey);
    await _storage.delete(key: _tecnicoTallerNombreKey);
    await _storage.delete(key: _tecnicoTenantIdKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('user_rol');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
  }

  Future<TallerActivo?> tallerActivoActual() async {
    final id = await _storage.read(key: _tecnicoTallerIdKey);
    if (id == null) return null;
    final tenant = await _storage.read(key: _tecnicoTenantIdKey) ?? '0';
    final nombre = await _storage.read(key: _tecnicoTallerNombreKey) ?? '';
    return TallerActivo(
      idTaller: int.tryParse(id) ?? 0,
      idTenant: int.tryParse(tenant) ?? 0,
      nombre: nombre,
    );
  }
}
