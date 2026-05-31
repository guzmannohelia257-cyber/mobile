import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import 'local_db.dart';

class OutboxService {
  static final OutboxService _instance = OutboxService._();
  factory OutboxService() => _instance;
  OutboxService._();

  final _connectivity = Connectivity();
  bool _syncing = false;
  // connectivity_plus 6.x: el stream emite List<ConnectivityResult>.
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  final pendingCount = ValueNotifier<int>(0);

  Future<void> start() async {
    await _refreshCount();
    _connSub = _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) drain();
    });
    drain();
  }

  void stop() => _connSub?.cancel();

  Future<String> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    List<String>? files,
    required String token,
  }) async {
    final db = await LocalDB.instance;
    final clientId = const Uuid().v4();
    await db.insert('outbox', {
      'client_id': clientId,
      'method': method,
      'path': path,
      'body_json': body == null ? null : jsonEncode(body),
      'files_paths': files == null ? null : files.join('|'),
      'token': token,
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _refreshCount();
    unawaited(drain());
    return clientId;
  }

  Future<void> drain({int maxAttempts = 5}) async {
    if (_syncing) return;
    final conn = await _connectivity.checkConnectivity();
    if (conn.every((r) => r == ConnectivityResult.none)) return;

    _syncing = true;
    try {
      final db = await LocalDB.instance;
      final items = await db.query('outbox', orderBy: 'created_at ASC');
      for (final item in items) {
        final ok = await _send(item);
        if (ok) {
          await db.delete('outbox', where: 'id = ?', whereArgs: [item['id']]);
        } else {
          final attempts = (item['attempts'] as int) + 1;
          await db.update(
            'outbox',
            {'attempts': attempts, 'last_error': 'http error'},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          if (attempts >= maxAttempts) {
            await db.delete('outbox', where: 'id = ?', whereArgs: [item['id']]);
          }
        }
      }
    } finally {
      _syncing = false;
      await _refreshCount();
    }
  }

  Future<bool> _send(Map<String, Object?> item) async {
    final method = item['method'] as String;
    final path = item['path'] as String;
    final token = item['token'] as String?;
    final body = item['body_json'] == null
        ? null
        : jsonDecode(item['body_json'] as String) as Map<String, dynamic>;
    final filesPaths = (item['files_paths'] as String?)?.split('|') ?? [];

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-Client-Id': item['client_id'] as String,
    };

    try {
      http.Response resp;
      if (filesPaths.isNotEmpty) {
        final req = http.MultipartRequest(method, uri)..headers.addAll(headers);
        body?.forEach((k, v) => req.fields[k.toString()] = v.toString());
        for (final p in filesPaths) {
          final file = File(p);
          if (await file.exists()) {
            req.files.add(await http.MultipartFile.fromPath('archivo', p));
          }
        }
        resp = await http.Response.fromStream(await req.send());
      } else {
        headers['Content-Type'] = 'application/json';
        switch (method) {
          case 'POST':
            resp = await http.post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
            break;
          case 'PUT':
            resp = await http.put(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
            break;
          case 'PATCH':
            resp = await http.patch(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
            break;
          case 'DELETE':
            resp = await http.delete(uri, headers: headers);
            break;
          default:
            return true;
        }
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) return true;
      if (resp.statusCode >= 400 && resp.statusCode < 500) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshCount() async {
    final db = await LocalDB.instance;
    final res = await db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    pendingCount.value = (res.first['c'] as int?) ?? 0;
  }
}
