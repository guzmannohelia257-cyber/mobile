class Cotizacion {
  final int idCotizacion;
  final int idIncidente;
  final int idTaller;
  final double? montoServicio;
  final double? montoRepuestos;
  final double? distanciaKm;
  final double? montoTraslado;
  final int? garantiaDias;
  final int? tiempoEstimadoMin;
  final String? nota;
  final DateTime? validezHasta;
  final DateTime createdAt;
  final String estadoNombre;
  final String? tallerNombre;
  final String? tallerTelefono;

  Cotizacion({
    required this.idCotizacion,
    required this.idIncidente,
    required this.idTaller,
    this.montoServicio,
    this.montoRepuestos,
    this.distanciaKm,
    this.montoTraslado,
    this.garantiaDias,
    this.tiempoEstimadoMin,
    this.nota,
    this.validezHasta,
    required this.createdAt,
    required this.estadoNombre,
    this.tallerNombre,
    this.tallerTelefono,
  });

  double? get montoTotal {
    if (montoServicio == null) return null;
    return montoServicio! + (montoRepuestos ?? 0) + (montoTraslado ?? 0);
  }

  /// Formato amigable: "3 h 30 min" o "45 min".
  String? get tiempoEstimadoLabel {
    final m = tiempoEstimadoMin;
    if (m == null || m <= 0) return null;
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '$r min';
    if (r == 0) return '$h h';
    return '$h h $r min';
  }

  factory Cotizacion.fromJson(Map<String, dynamic> json) {
    return Cotizacion(
      idCotizacion: json['id_cotizacion'] ?? 0,
      idIncidente: json['id_incidente'] ?? 0,
      idTaller: json['id_taller'] ?? 0,
      montoServicio: (json['monto_servicio'] as num?)?.toDouble(),
      montoRepuestos: (json['monto_repuestos'] as num?)?.toDouble(),
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      montoTraslado: (json['monto_traslado'] as num?)?.toDouble(),
      garantiaDias: json['garantia_dias'],
      tiempoEstimadoMin: json['tiempo_estimado_min'] as int?,
      nota: json['nota'],
      validezHasta: json['validez_hasta'] != null
          ? DateTime.parse(json['validez_hasta'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      estadoNombre: json['estado']?['nombre'] ?? 'desconocido',
      tallerNombre: json['taller']?['nombre'],
      tallerTelefono: json['taller']?['telefono'],
    );
  }
}
