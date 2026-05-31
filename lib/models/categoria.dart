class Categoria {
  final int idCategoria;
  final String? codigo;
  final String nombre;
  final String? descripcion;
  final bool requiereCotizacion;

  Categoria({
    required this.idCategoria,
    this.codigo,
    required this.nombre,
    this.descripcion,
    required this.requiereCotizacion,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      idCategoria: json['id_categoria'] ?? 0,
      codigo: json['codigo'],
      nombre: json['nombre'] ?? 'Categoria',
      descripcion: json['descripcion'],
      requiereCotizacion: json['requiere_cotizacion'] ?? false,
    );
  }
}
