class CompletarServicioForm {
  final double? costoFinal;
  final String? resumenTrabajo;

  const CompletarServicioForm({
    this.costoFinal,
    this.resumenTrabajo,
  });

  bool get isValid {
    return (costoFinal != null && costoFinal! > 0) ||
        (resumenTrabajo != null && resumenTrabajo!.trim().isNotEmpty);
  }
}
