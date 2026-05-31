class TallerPublico {
  final int idTaller;
  final String nombre;
  final String? direccion;
  final double? latitud;
  final double? longitud;

  TallerPublico({
    required this.idTaller,
    required this.nombre,
    this.direccion,
    this.latitud,
    this.longitud,
  });

  factory TallerPublico.fromJson(Map<String, dynamic> json) => TallerPublico(
        idTaller: json['id_taller'] ?? 0,
        nombre: json['nombre'] ?? 'Taller',
        direccion: json['direccion'],
        latitud: (json['latitud'] as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
      );
}
