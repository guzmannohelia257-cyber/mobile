class TallerCompatible {
  final int idTaller;
  final String nombre;
  final String? telefono;
  final double? latitud;
  final double? longitud;
  final double? distanciaKm;
  final double? tarifaBase;
  final double? montoTraslado;
  final double? totalEstimado;
  final int? tiempoReparacionMin;
  final int? etaLlegadaMin;
  final double? ratingPromedio;
  final bool disponible;

  TallerCompatible({
    required this.idTaller,
    required this.nombre,
    this.telefono,
    this.latitud,
    this.longitud,
    this.distanciaKm,
    this.tarifaBase,
    this.montoTraslado,
    this.totalEstimado,
    this.tiempoReparacionMin,
    this.etaLlegadaMin,
    this.ratingPromedio,
    this.disponible = true,
  });

  factory TallerCompatible.fromJson(Map<String, dynamic> json) {
    return TallerCompatible(
      idTaller: json['id_taller'] ?? 0,
      nombre: json['nombre'] ?? 'Taller',
      telefono: json['telefono'],
      latitud: (json['latitud'] as num?)?.toDouble(),
      longitud: (json['longitud'] as num?)?.toDouble(),
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      tarifaBase: (json['tarifa_base'] as num?)?.toDouble(),
      montoTraslado: (json['monto_traslado'] as num?)?.toDouble(),
      totalEstimado: (json['total_estimado'] as num?)?.toDouble(),
      tiempoReparacionMin: json['tiempo_reparacion_min'] as int?,
      etaLlegadaMin: json['eta_llegada_min'] as int?,
      ratingPromedio: (json['rating_promedio'] as num?)?.toDouble(),
      disponible: json['disponible'] ?? true,
    );
  }

  static String _fmtMin(int min) {
    final h = min ~/ 60;
    final r = min % 60;
    if (h == 0) return '$r min';
    if (r == 0) return '$h h';
    return '$h h $r min';
  }

  String? get tiempoReparacionLabel =>
      tiempoReparacionMin != null ? _fmtMin(tiempoReparacionMin!) : null;

  String? get etaLlegadaLabel =>
      etaLlegadaMin != null ? _fmtMin(etaLlegadaMin!) : null;
}
