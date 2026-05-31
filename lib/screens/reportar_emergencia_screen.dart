import 'package:flutter/material.dart';
import '../services/incidente_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'subir_evidencia_screen.dart';

class ReportarEmergenciaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> vehiculos;

  const ReportarEmergenciaScreen({super.key, this.vehiculos = const []});

  @override
  State<ReportarEmergenciaScreen> createState() =>
      _ReportarEmergenciaScreenState();
}

class _ReportarEmergenciaScreenState extends State<ReportarEmergenciaScreen> {
  final incidenteService = IncidenteService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _descripcionController;

  int? vehiculoSeleccionado;
  double? latitud;
  double? longitud;
  bool obteniendo = false;
  String? ubicacionTexto;
  String? errorGeneral;

  @override
  void initState() {
    super.initState();
    _descripcionController = TextEditingController();
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  void _obtenerUbicacion() async {
    setState(() => obteniendo = true);

    final resultado = await incidenteService.obtenerUbicacionActual();

    if (!mounted) return;

    if (resultado != null) {
      setState(() {
        latitud = resultado['latitud'];
        longitud = resultado['longitud'];
        ubicacionTexto =
            '${resultado['latitud']?.toStringAsFixed(4)}, ${resultado['longitud']?.toStringAsFixed(4)}';
        errorGeneral = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación obtenida correctamente.'),
        ),
      );
    } else {
      setState(() {
        ubicacionTexto = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo obtener tu ubicación. Verifica que el GPS esté activo.',
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() => obteniendo = false);
  }

  void _irASubirEvidencia() {
    if (!_formKey.currentState!.validate()) return;

    if (vehiculoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona uno de tus vehículos.')),
      );
      return;
    }

    if (latitud == null || longitud == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Necesitamos tu ubicación GPS.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubirEvidenciaScreen(
          idVehiculo: vehiculoSeleccionado!,
          descripcionUsuario: _descripcionController.text.trim(),
          latitud: latitud!,
          longitud: longitud!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tieneUbicacion = latitud != null && longitud != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reportar emergencia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroCard(),
              const SizedBox(height: 28),

              if (errorGeneral != null) ...[
                _ErrorBanner(message: errorGeneral!),
                const SizedBox(height: 20),
              ],

              _StepLabel(number: '01', text: 'Selecciona tu vehículo'),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: vehiculoSeleccionado,
                decoration: const InputDecoration(
                  hintText: 'Vehículo afectado',
                  prefixIcon: Icon(Icons.directions_car_outlined),
                ),
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppColors.inkMuted),
                items: widget.vehiculos.isEmpty
                    ? const [
                        DropdownMenuItem(
                          enabled: false,
                          child: Text('No tienes vehículos registrados'),
                        ),
                      ]
                    : widget.vehiculos.map<DropdownMenuItem<int>>((v) {
                        return DropdownMenuItem<int>(
                          value: v['id_vehiculo'],
                          child: Text(
                            '${v['marca']} ${v['modelo']} · ${v['placa']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                onChanged: widget.vehiculos.isEmpty
                    ? null
                    : (v) => setState(() => vehiculoSeleccionado = v),
                validator: (v) =>
                    v == null ? 'Selecciona un vehículo' : null,
              ),
              const SizedBox(height: 24),

              _StepLabel(number: '02', text: '¿Qué está pasando?'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descripcionController,
                maxLines: 5,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'Describe el problema. Por ejemplo: el motor no enciende, hay una llanta pinchada en la rueda delantera derecha…',
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Ingresa una descripción';
                  if (v!.length < 10) return 'Al menos 10 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _StepLabel(number: '03', text: 'Comparte tu ubicación'),
              const SizedBox(height: 10),
              _buildLocationCard(tieneUbicacion),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _irASubirEvidencia,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.attach_file_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Continuar y subir evidencia'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(height: 24),

              _buildTipsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB11D27), Color(0xFF8B1620)],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Asistencia en camino',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Llena estos pasos y un técnico cercano será asignado automáticamente.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(bool tieneUbicacion) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: tieneUbicacion
              ? AppColors.forest.withValues(alpha: 0.35)
              : AppColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tieneUbicacion
                      ? AppColors.forestSoft
                      : AppColors.overlay,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tieneUbicacion
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                  color: tieneUbicacion
                      ? AppColors.forest
                      : AppColors.inkMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tieneUbicacion
                          ? 'Ubicación detectada'
                          : 'Ubicación no obtenida',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tieneUbicacion
                          ? ubicacionTexto ?? ''
                          : 'Toca el botón para enviar tu posición GPS.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: obteniendo ? null : _obtenerUbicacion,
              icon: obteniendo
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Icon(
                      tieneUbicacion
                          ? Icons.refresh_rounded
                          : Icons.my_location_rounded,
                      size: 18,
                    ),
              label: Text(
                obteniendo
                    ? 'Obteniendo ubicación…'
                    : tieneUbicacion
                        ? 'Actualizar ubicación'
                        : 'Obtener mi ubicación',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.indigoSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lightbulb_outline_rounded,
                    color: AppColors.indigo, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Para una asistencia más rápida',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Tip('Describe el problema con el mayor detalle posible.'),
          _Tip('Asegúrate de tener el GPS activo y buena señal.'),
          _Tip('El técnico verá tus evidencias antes de salir.'),
          _Tip('Puedes seguir el estado desde tu historial.'),
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String number;
  final String text;
  const _StepLabel({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.brand,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(Icons.check_rounded,
                size: 14, color: AppColors.forest),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.inkSubtle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.brand, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.brandInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
