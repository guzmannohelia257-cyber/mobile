class CandidatoAsignacion {
  final int idCandidato;
  final int idIncidente;
  final int idTaller;
  final double? distanciaKm;
  final double? scoreTotal;
  final double? ratingPromedio;
  final bool seleccionado;
  final TallerMini taller;

  CandidatoAsignacion({
    required this.idCandidato,
    required this.idIncidente,
    required this.idTaller,
    this.distanciaKm,
    this.scoreTotal,
    this.ratingPromedio,
    required this.seleccionado,
    required this.taller,
  });

  factory CandidatoAsignacion.fromJson(Map<String, dynamic> json) {
    return CandidatoAsignacion(
      idCandidato: json['id_candidato'] ?? 0,
      idIncidente: json['id_incidente'] ?? 0,
      idTaller: json['id_taller'] ?? 0,
      distanciaKm: (json['distancia_km'] as num?)?.toDouble(),
      scoreTotal: (json['score_total'] as num?)?.toDouble(),
      ratingPromedio: (json['rating_promedio'] as num?)?.toDouble(),
      seleccionado: json['seleccionado'] ?? false,
      taller: json['taller'] != null
          ? TallerMini.fromJson(json['taller'] as Map<String, dynamic>)
          : TallerMini(idTaller: 0, nombre: 'Taller desconocido'),
    );
  }
}

class Asignacion {
  final int idAsignacion;
  final int idTaller;
  final int idEstadoAsignacion;
  final int? etaMinutos;
  final String? notaTaller;
  final String? motivoRechazo;
  final TallerMini taller;
  final EstadoAsignacion estado;

  Asignacion({
    required this.idAsignacion,
    required this.idTaller,
    required this.idEstadoAsignacion,
    this.etaMinutos,
    this.notaTaller,
    this.motivoRechazo,
    required this.taller,
    required this.estado,
  });

  factory Asignacion.fromJson(Map<String, dynamic> json) {
    return Asignacion(
      idAsignacion: json['id_asignacion'] ?? 0,
      idTaller: json['id_taller'] ?? 0,
      idEstadoAsignacion: json['id_estado_asignacion'] ?? 1,
      etaMinutos: json['eta_minutos'],
      notaTaller: json['nota_taller'],
      motivoRechazo: json['motivo_rechazo'],
      taller: json['taller'] != null
          ? TallerMini.fromJson(json['taller'] as Map<String, dynamic>)
          : TallerMini(idTaller: 0, nombre: 'Taller desconocido'),
      estado: json['estado'] != null
          ? EstadoAsignacion.fromJson(json['estado'] as Map<String, dynamic>)
          : EstadoAsignacion(idEstadoAsignacion: 1, nombre: 'pendiente'),
    );
  }

  String getMensajeEstado() {
    switch (estado.nombre.toLowerCase()) {
      case 'pendiente':
        return '⏳ Esperando confirmación de ${taller.nombre}';
      case 'aceptada':
        final eta = etaMinutos != null ? ' (ETA: $etaMinutos min)' : '';
        return '✅ ${taller.nombre} aceptó$eta';
      case 'rechazada':
        final motivo = motivoRechazo ?? 'Sin motivo';
        return '❌ Rechazada: $motivo. Elige otro taller.';
      case 'en_camino':
        final eta = etaMinutos != null ? ' (ETA: $etaMinutos min)' : '';
        return '🚗 ${taller.nombre} en camino$eta';
      case 'completada':
        return '🏁 Atención completada por ${taller.nombre}';
      default:
        return '📌 ${estado.nombre}';
    }
  }
}

class EstadoAsignacion {
  final int idEstadoAsignacion;
  final String nombre;

  EstadoAsignacion({
    required this.idEstadoAsignacion,
    required this.nombre,
  });

  factory EstadoAsignacion.fromJson(Map<String, dynamic> json) {
    return EstadoAsignacion(
      idEstadoAsignacion: json['id_estado_asignacion'] ?? 1,
      nombre: json['nombre'] ?? 'pendiente',
    );
  }
}

class TallerMini {
  final int idTaller;
  final String nombre;
  final String? direccion;
  final String? telefono;

  TallerMini({
    required this.idTaller,
    required this.nombre,
    this.direccion,
    this.telefono,
  });

  factory TallerMini.fromJson(Map<String, dynamic> json) {
    return TallerMini(
      idTaller: json['id_taller'] ?? 0,
      nombre: json['nombre'] ?? 'Taller sin nombre',
      direccion: json['direccion'],
      telefono: json['telefono'],
    );
  }
}
