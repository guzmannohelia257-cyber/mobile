import 'package:intl/intl.dart';
import 'candidato_asignacion.dart';

/// Respuesta del servidor al crear incidencia
class IncidenteResponse {
  final int idIncidente;
  final int idUsuario;
  final int idVehiculo;
  final int? idCategoria;
  final int? idPrioridad;
  final int idEstado;
  final String? descripcionUsuario;
  final double latitud;
  final double longitud;
  final DateTime createdAt;

  IncidenteResponse({
    required this.idIncidente,
    required this.idUsuario,
    required this.idVehiculo,
    this.idCategoria,
    this.idPrioridad,
    required this.idEstado,
    this.descripcionUsuario,
    required this.latitud,
    required this.longitud,
    required this.createdAt,
  });

  factory IncidenteResponse.fromJson(Map<String, dynamic> json) {
    return IncidenteResponse(
      idIncidente: json['id_incidente'] ?? 0,
      idUsuario: json['id_usuario'] ?? 0,
      idVehiculo: json['id_vehiculo'] ?? 0,
      idCategoria: json['id_categoria'],
      idPrioridad: json['id_prioridad'],
      idEstado: json['id_estado'] ?? 1,
      descripcionUsuario: json['descripcion_usuario'],
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String getEstadoNombre() {
    // Antes mapeábamos por id_estado, pero al agregar el estado 'borrador'
    // al catálogo los IDs cambiaron y todo quedó corrido. Ahora usamos el
    // nombre del estado que viene del backend cuando esté disponible.
    return _formatearEstado(idEstado: idEstado, nombreEstado: null);
  }

  String getUbicacion() =>
      '${latitud.toStringAsFixed(4)}, ${longitud.toStringAsFixed(4)}';

  String getFechaFormato() {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }
}

/// Helper compartido para formatear un estado de incidente con emoji.
/// Prefiere el `nombre` (string) que viene del backend; si solo tenemos el
/// id_estado caemos a un mapeo heurístico (queda como fallback).
String _formatearEstado({required int idEstado, required String? nombreEstado}) {
  final nombre = (nombreEstado ?? '').toLowerCase().trim();
  switch (nombre) {
    case 'borrador':
      return '📝 Borrador';
    case 'pendiente':
      return '⏳ Pendiente';
    case 'en_proceso':
      return '⚙️ En Proceso';
    case 'atendido':
      return '✅ Atendido';
    case 'cancelado':
      return '❌ Cancelado';
  }
  // Si no recibimos el nombre, usamos un mapeo por id como último recurso.
  // OJO: los IDs reales en BD dependen del orden de inserción; este fallback
  // sólo sirve para bases viejas donde el seed no incluía 'borrador'.
  const idsLegacy = {
    1: '⏳ Pendiente',
    2: '⚙️ En Proceso',
    3: '✅ Atendido',
    4: '❌ Cancelado',
  };
  return idsLegacy[idEstado] ?? 'Estado desconocido';
}

/// Incidencia con datos completos (desde listado)
class IncidenteDetalle {
  final int idIncidente;
  final int idUsuario;
  final int idVehiculo;
  final int idEstado;
  final int? idCategoria;
  final int? idPrioridad;
  final String? descripcionUsuario;
  final double latitud;
  final double longitud;
  final String? resumenIa;
  final double? clasificacionIaConfianza;
  final bool requiereRevisionManual;
  final bool evaluado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? vehiculo;
  final Map<String, dynamic>? estado;
  final Map<String, dynamic>? categoria;
  final Map<String, dynamic>? prioridad;
  final List<CandidatoAsignacion>? candidatos;
  final List<Asignacion>? asignaciones;

  IncidenteDetalle({
    required this.idIncidente,
    required this.idUsuario,
    required this.idVehiculo,
    required this.idEstado,
    this.idCategoria,
    this.idPrioridad,
    this.descripcionUsuario,
    required this.latitud,
    required this.longitud,
    this.resumenIa,
    this.clasificacionIaConfianza,
    this.requiereRevisionManual = false,
    this.evaluado = false,
    required this.createdAt,
    required this.updatedAt,
    this.vehiculo,
    this.estado,
    this.categoria,
    this.prioridad,
    this.candidatos,
    this.asignaciones,
  });

  factory IncidenteDetalle.fromJson(Map<String, dynamic> json) {
    return IncidenteDetalle(
      idIncidente: json['id_incidente'] ?? 0,
      idUsuario: json['id_usuario'] ?? 0,
      idVehiculo: json['id_vehiculo'] ?? 0,
      idEstado: json['estado']?['id_estado'] ?? json['id_estado'] ?? 1,
      // El backend serializa categoria/prioridad como objetos anidados en
      // IncidenteDetalle, no como id_categoria/id_prioridad sueltos. Leemos
      // primero del objeto y caemos al campo plano por compatibilidad.
      idCategoria: json['categoria']?['id_categoria'] ?? json['id_categoria'],
      idPrioridad: json['prioridad']?['id_prioridad'] ?? json['id_prioridad'],
      descripcionUsuario: json['descripcion_usuario'],
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      resumenIa: json['resumen_ia'],
      clasificacionIaConfianza:
          (json['clasificacion_ia_confianza'] as num?)?.toDouble(),
      requiereRevisionManual: json['requiere_revision_manual'] ?? false,
      evaluado: json['evaluado'] ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(
        (json['updated_at'] ?? json['created_at']) as String,
      ),
      vehiculo: json['vehiculo'],
      estado: json['estado'],
      categoria: json['categoria'],
      prioridad: json['prioridad'],
      candidatos: (json['candidatos'] as List?)
          ?.cast<Map<String, dynamic>>()
          .map((c) => CandidatoAsignacion.fromJson(c))
          .toList(),
      asignaciones: (json['asignaciones'] as List?)
          ?.cast<Map<String, dynamic>>()
          .map((a) => Asignacion.fromJson(a))
          .toList(),
    );
  }

  String getEstadoNombre() {
    // El estado mostrado al cliente se deriva del estado del incidente +
    // el estado de la asignación más reciente. La asignación da más
    // información sobre lo que está pasando del lado del taller/técnico.
    final asigActiva = _asignacionActiva();
    if (asigActiva != null) {
      final nombreAsig = asigActiva.estado.nombre.toLowerCase();
      switch (nombreAsig) {
        case 'aceptada':
          return '✅ Taller asignado';
        case 'en_camino':
          return '🚗 Técnico en camino';
        case 'llegado':
          return '📍 Técnico en sitio';
        case 'completada':
          return '🏁 Servicio completado';
        case 'rechazada':
          return '↪️ Buscando otro taller';
        case 'cancelada':
          return '❌ Cancelada por el taller';
      }
    }

    // Si no hay asignación activa, mostramos el estado del incidente.
    final nombreEstado = (estado?['nombre'] as String?)?.toLowerCase();
    return _formatearEstado(idEstado: idEstado, nombreEstado: nombreEstado);
  }

  /// Devuelve la asignación más relevante para mostrar al cliente.
  /// Prioriza estados activos (aceptada/en_camino/llegado/completada) sobre
  /// estados terminales (rechazada/cancelada) y pendiente.
  Asignacion? _asignacionActiva() {
    final asigs = asignaciones;
    if (asigs == null || asigs.isEmpty) return null;
    const prioridad = {
      'llegado': 5,
      'en_camino': 4,
      'aceptada': 3,
      'completada': 2,
      'cancelada': 1,
      'rechazada': 1,
      'pendiente': 0,
    };
    Asignacion? mejor;
    int mejorScore = -1;
    for (final a in asigs) {
      final score = prioridad[a.estado.nombre.toLowerCase()] ?? -1;
      if (score > mejorScore) {
        mejor = a;
        mejorScore = score;
      }
    }
    // Solo devolvemos si está en un estado posterior a "pendiente" — para
    // pendiente preferimos mostrar el estado del incidente directamente
    // (Pendiente / En proceso / etc.).
    if (mejor != null && mejorScore > 0) return mejor;
    return null;
  }

  String getPlaca() => vehiculo?['placa'] ?? 'N/A';
  String getMarca() => vehiculo?['marca'] ?? 'N/A';
  String getCategoriaNombre() => categoria?['nombre'] ?? '🤖 Por asignar';
  String getUbicacion() =>
      '${latitud.toStringAsFixed(4)}, ${longitud.toStringAsFixed(4)}';

  String getFechaFormato() {
    return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
  }

  String getNivelPrioridad() {
    final nivel = prioridad?['nivel']?.toString().toUpperCase() ?? 'N/A';
    if (nivel == 'CRITICA') return '🔴 CRÍTICA';
    if (nivel == 'ALTA') return '🟠 ALTA';
    if (nivel == 'MEDIA') return '🟡 MEDIA';
    if (nivel == 'BAJA') return '🟢 BAJA';
    return '🤖 $nivel';
  }
}
