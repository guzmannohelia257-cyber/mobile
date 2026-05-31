import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Datos de una adenda (ampliacion de presupuesto) registrada por el
/// tecnico durante el servicio.
class Adenda {
  final int idAdenda;
  final int idAsignacion;
  final double montoAdicional;
  final String descripcion;
  final String estado; // pendiente | aprobada | rechazada
  final String? motivoCliente;
  final DateTime createdAt;
  final DateTime? respondidaAt;

  Adenda({
    required this.idAdenda,
    required this.idAsignacion,
    required this.montoAdicional,
    required this.descripcion,
    required this.estado,
    this.motivoCliente,
    required this.createdAt,
    this.respondidaAt,
  });

  bool get esPendiente => estado == 'pendiente';

  factory Adenda.fromJson(Map<String, dynamic> json) {
    return Adenda(
      idAdenda: (json['id_adenda'] ?? 0) as int,
      idAsignacion: (json['id_asignacion'] ?? 0) as int,
      montoAdicional: (json['monto_adicional'] as num?)?.toDouble() ?? 0.0,
      descripcion: (json['descripcion'] ?? '') as String,
      estado: (json['estado'] ?? 'pendiente') as String,
      motivoCliente: json['motivo_cliente'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      respondidaAt: json['respondida_at'] != null
          ? DateTime.tryParse(json['respondida_at'].toString())
          : null,
    );
  }
}

class AdendaService {
  static const String _base = ApiConfig.baseUrl;

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Lista todas las adendas de una asignacion (cliente o tecnico).
  Future<List<Adenda>> listar(int idAsignacion) async {
    final token = await _token();
    final r = await http.get(
      Uri.parse('$_base/asignaciones/$idAsignacion/adendas'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    );
    if (r.statusCode != 200) return [];
    final data = jsonDecode(r.body) as List<dynamic>;
    return data
        .map((e) => Adenda.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tecnico registra una ampliacion (rol=3).
  Future<Map<String, dynamic>> crear({
    required int idAsignacion,
    required double montoAdicional,
    required String descripcion,
  }) async {
    final token = await _token();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    final r = await http.post(
      Uri.parse('$_base/asignaciones/$idAsignacion/adendas'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'monto_adicional': montoAdicional,
        'descripcion': descripcion,
      }),
    );
    if (r.statusCode == 201) {
      return {'success': true, 'adenda': Adenda.fromJson(jsonDecode(r.body))};
    }
    return {'success': false, 'error': _detail(r.body)};
  }

  /// Cliente aprueba o rechaza.
  Future<Map<String, dynamic>> responder({
    required int idAdenda,
    required bool aprobar,
    String? motivo,
  }) async {
    final token = await _token();
    if (token == null) return {'success': false, 'error': 'No autenticado'};

    final r = await http.post(
      Uri.parse('$_base/adendas/$idAdenda/responder'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'decision': aprobar ? 'aprobar' : 'rechazar',
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      }),
    );
    if (r.statusCode == 200) {
      return {'success': true, 'adenda': Adenda.fromJson(jsonDecode(r.body))};
    }
    return {'success': false, 'error': _detail(r.body)};
  }

  String _detail(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      return j['detail']?.toString() ?? 'Error desconocido';
    } catch (_) {
      return body.isNotEmpty ? body : 'Error desconocido';
    }
  }
}
