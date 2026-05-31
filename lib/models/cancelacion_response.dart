class CancelacionResponse {
  final int idAsignacion;
  final int idTaller;
  final String? canceladaPor;
  final String? motivoCancelacion;
  final double compensacionMonto;
  final bool compensacionPagada;
  final String nuevoEstado;

  CancelacionResponse({
    required this.idAsignacion,
    required this.idTaller,
    this.canceladaPor,
    this.motivoCancelacion,
    required this.compensacionMonto,
    required this.compensacionPagada,
    required this.nuevoEstado,
  });

  factory CancelacionResponse.fromJson(Map<String, dynamic> json) {
    return CancelacionResponse(
      idAsignacion: json['id_asignacion'] ?? 0,
      idTaller: json['id_taller'] ?? 0,
      canceladaPor: json['cancelada_por'],
      motivoCancelacion: json['motivo_cancelacion'],
      compensacionMonto: (json['compensacion_monto'] as num?)?.toDouble() ?? 0,
      compensacionPagada: json['compensacion_pagada'] ?? false,
      nuevoEstado: json['nuevo_estado'] ?? 'cancelada',
    );
  }
}
