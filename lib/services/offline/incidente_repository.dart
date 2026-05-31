import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import 'local_db.dart';
import 'outbox_service.dart';

class IncidenteRepository {
  static final IncidenteRepository _instance = IncidenteRepository._();
  factory IncidenteRepository() => _instance;
  IncidenteRepository._();

  Future<bool> get _online async {
    // connectivity_plus 6.x devuelve List<ConnectivityResult>.
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<List<Map<String, dynamic>>> listar() async {
    if (await _online) {
      try {
        final token = await _token();
        final resp = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/incidencias/mis-incidencias'),
          headers: {if (token != null) 'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final items = (jsonDecode(resp.body) as List)
              .cast<Map<String, dynamic>>();
          await _cacheList(items);
          return items;
        }
      } catch (_) {}
    }
    return _readCached();
  }

  Future<Map<String, dynamic>> reportar({
    required Map<String, dynamic> body,
    List<String> fotos = const [],
  }) async {
    final token = await _token();

    // Idempotency key estable: se genera una sola vez y se envía en el body
    // tanto en el envío online como en el outbox. Si el envío online se cuelga
    // por timeout y el cliente reintenta, el backend devuelve el mismo
    // incidente (no duplica).
    final bodyConKey = <String, dynamic>{
      ...body,
      'idempotency_key': body['idempotency_key'] ?? const Uuid().v4(),
    };

    if (await _online) {
      try {
        final resp = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/incidencias/'),
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(bodyConKey),
        );
        if (resp.statusCode == 201 || resp.statusCode == 200) {
          final created = jsonDecode(resp.body) as Map<String, dynamic>;
          await _upsertOne(created);
          return created;
        }
      } catch (_) {}
    }

    final clientId = await OutboxService().enqueue(
      method: 'POST',
      path: '/incidencias/',
      body: bodyConKey,
      files: fotos,
      token: token ?? '',
    );

    final localId = -DateTime.now().millisecondsSinceEpoch;
    final pending = <String, dynamic>{
      ...bodyConKey,
      'id_incidente': localId,
      'client_id': clientId,
      'estado_nombre': 'pendiente_local',
      'created_at': DateTime.now().toIso8601String(),
    };
    await _upsertOne(pending);
    return pending;
  }

  Future<void> _cacheList(List<Map<String, dynamic>> items) async {
    final db = await LocalDB.instance;
    await db.transaction((tx) async {
      await tx.delete('incidentes', where: 'id_incidente > 0');
      for (final i in items) {
        await tx.insert(
          'incidentes',
          _row(i),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> _upsertOne(Map<String, dynamic> i) async {
    final db = await LocalDB.instance;
    await db.insert(
      'incidentes',
      _row(i),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> _readCached() async {
    final db = await LocalDB.instance;
    return await db.query('incidentes', orderBy: 'created_at DESC');
  }

  Map<String, Object?> _row(Map<String, dynamic> i) => {
        'id_incidente': i['id_incidente'],
        'client_id': i['client_id'],
        'id_categoria': i['id_categoria'],
        'descripcion_usuario': i['descripcion_usuario'],
        'resumen_ia': i['resumen_ia'],
        'latitud': (i['latitud'] as num).toDouble(),
        'longitud': (i['longitud'] as num).toDouble(),
        'estado_nombre': i['estado_nombre'] ?? (i['estado']?['nombre']),
        'created_at': i['created_at'],
        'cached_at': DateTime.now().toIso8601String(),
      };
}
