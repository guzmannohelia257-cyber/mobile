class PagoClienteItem {
  final int idIncidente;
  final int? idPago;
  final double montoTotal;
  final String estado;
  final String? referenciaExterna;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PagoClienteItem({
    required this.idIncidente,
    this.idPago,
    required this.montoTotal,
    required this.estado,
    this.referenciaExterna,
    this.createdAt,
    this.updatedAt,
  });

  factory PagoClienteItem.fromJson(Map<String, dynamic> json) {
    return PagoClienteItem(
      idIncidente: json['id_incidente'] ?? 0,
      idPago: json['id_pago'],
      montoTotal: (json['monto_total'] as num?)?.toDouble() ?? 0,
      estado: (json['estado'] ?? 'pendiente').toString(),
      referenciaExterna: json['referencia_externa']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  bool get estaCompletado => estado.toLowerCase() == 'completado';

  bool get estaPendiente {
    final s = estado.toLowerCase();
    return s == 'pendiente' || s == 'procesando' || s == 'fallido';
  }

  String get estadoLabel {
    switch (estado.toLowerCase()) {
      case 'completado':
        return 'Completado';
      case 'procesando':
        return 'Procesando';
      case 'fallido':
        return 'Fallido';
      case 'reembolsado':
        return 'Reembolsado';
      default:
        return 'Pendiente';
    }
  }
}
