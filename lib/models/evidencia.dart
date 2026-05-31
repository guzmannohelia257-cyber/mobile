class Evidencia {
  final int idEvidencia;
  final int idIncidente;
  final int idTipoEvidencia;
  final String urlArchivo;
  final String? transcripcionAudio;
  final String? descripcionIa;
  final DateTime createdAt;

  Evidencia({
    required this.idEvidencia,
    required this.idIncidente,
    required this.idTipoEvidencia,
    required this.urlArchivo,
    this.transcripcionAudio,
    this.descripcionIa,
    required this.createdAt,
  });

  factory Evidencia.fromJson(Map<String, dynamic> json) {
    return Evidencia(
      idEvidencia: json['id_evidencia'] ?? 0,
      idIncidente: json['id_incidente'] ?? 0,
      idTipoEvidencia: json['id_tipo_evidencia'] ?? 1,
      urlArchivo: json['url_archivo'] ?? '',
      transcripcionAudio: json['transcripcion_audio'],
      descripcionIa: json['descripcion_ia'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get esImagen => idTipoEvidencia == 1;
  bool get esAudio => idTipoEvidencia == 2;
  bool get esTexto => idTipoEvidencia == 3;

  String getTipoNombre() {
    switch (idTipoEvidencia) {
      case 1:
        return '📷 Imagen';
      case 2:
        return '🎤 Audio';
      case 3:
        return '📝 Texto';
      default:
        return 'Desconocido';
    }
  }
}
