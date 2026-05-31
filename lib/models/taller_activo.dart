class TallerActivo {
  final int idTaller;
  final int idTenant;
  final String nombre;

  TallerActivo({
    required this.idTaller,
    required this.idTenant,
    required this.nombre,
  });

  factory TallerActivo.fromJson(Map<String, dynamic> json) => TallerActivo(
        idTaller: json['id_taller'] ?? 0,
        idTenant: json['id_tenant'] ?? 0,
        nombre: json['nombre'] ?? 'Taller',
      );
}
