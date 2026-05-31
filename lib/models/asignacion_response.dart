import 'evidencia.dart';

class AsignacionResponse {
  final int idAsignacion;
  final int idIncidente;
  final int idTaller;
  final int? idUsuario;
  final String estadoAsignacion;
  final int? etaMinutos;
  final int? tiempoEstimadoReparacionMin;
  final String? notaTaller;
  final DateTime createdAt;
  final IncidenteResponse incidente;

  AsignacionResponse({
    required this.idAsignacion,
    required this.idIncidente,
    required this.idTaller,
    this.idUsuario,
    required this.estadoAsignacion,
    this.etaMinutos,
    this.tiempoEstimadoReparacionMin,
    this.notaTaller,
    required this.createdAt,
    required this.incidente,
  });

  /// Formato amigable: "3 h 30 min" o "45 min".
  String? get tiempoEstimadoLabel {
    final m = tiempoEstimadoReparacionMin;
    if (m == null || m <= 0) return null;
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '$r min';
    if (r == 0) return '$h h';
    return '$h h $r min';
  }

  factory AsignacionResponse.fromJson(Map<String, dynamic> json) {
    return AsignacionResponse(
      idAsignacion: (json['id_asignacion'] ?? 0) as int,
      idIncidente: (json['id_incidente'] ?? 0) as int,
      idTaller: (json['id_taller'] ?? 0) as int,
      idUsuario: (json['id_usuario'] ?? json['id_tecnico']) as int?,
      estadoAsignacion: ((json['estado'] as Map<String, dynamic>?)?['nombre'] ??
              'desconocido')
          as String,
      etaMinutos: json['eta_minutos'] as int?,
      tiempoEstimadoReparacionMin:
          json['tiempo_estimado_reparacion_min'] as int?,
      notaTaller: json['nota_taller'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      incidente: IncidenteResponse.fromJson(
        (json['incidente'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
    );
  }
}

class IncidenteResponse {
  final int idIncidente;
  final String descripcionUsuario;
  final String? resumenIa;
  final double latitud;
  final double longitud;
  final String categoria;
  final String prioridad;
  final Map<String, dynamic>? usuario;
  final Map<String, dynamic>? vehiculo;
  final List<Evidencia> evidencias;

  IncidenteResponse({
    required this.idIncidente,
    required this.descripcionUsuario,
    this.resumenIa,
    required this.latitud,
    required this.longitud,
    required this.categoria,
    required this.prioridad,
    this.usuario,
    this.vehiculo,
    this.evidencias = const [],
  });

  factory IncidenteResponse.fromJson(Map<String, dynamic> json) {
    final evidenciasJson = json['evidencias'] as List<dynamic>? ?? [];
    return IncidenteResponse(
      idIncidente: (json['id_incidente'] ?? 0) as int,
      descripcionUsuario: (json['descripcion_usuario'] ?? '') as String,
      resumenIa: json['resumen_ia'] as String?,
      latitud: (json['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (json['longitud'] as num?)?.toDouble() ?? 0.0,
      categoria:
          ((json['categoria'] as Map<String, dynamic>?)?['nombre'] ?? 'Desconocida')
              as String,
      prioridad:
          ((json['prioridad'] as Map<String, dynamic>?)?['nivel'] ?? 'normal')
              as String,
      usuario: json['usuario'] as Map<String, dynamic>?,
      vehiculo: json['vehiculo'] as Map<String, dynamic>?,
      evidencias: evidenciasJson
          .map((e) => Evidencia.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
