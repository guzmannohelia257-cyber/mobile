import 'package:flutter/material.dart';
import '../services/incidente_service.dart';
import '../models/incidente.dart';
import '../models/candidato_asignacion.dart';
import 'subir_evidencia_screen.dart';
import 'mensajes_screen.dart';
import 'tecnico_tracking_screen.dart';

class HistorialEmergenciasScreen extends StatefulWidget {
  const HistorialEmergenciasScreen({super.key});

  @override
  State<HistorialEmergenciasScreen> createState() =>
      _HistorialEmergenciasScreenState();
}

class _HistorialEmergenciasScreenState
    extends State<HistorialEmergenciasScreen> {
  final incidenteService = IncidenteService();

  List<IncidenteDetalle> incidencias = [];
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _cargarIncidencias();
  }

  void _cargarIncidencias() async {
    final resultado = await incidenteService.listarMisIncidencias();

    if (!mounted) return;

    if (resultado['success']) {
      setState(() {
        incidencias = resultado['incidencias'] ?? [];
        error = null;
      });
    } else {
      setState(() => error = resultado['error']);
      if (resultado['code'] == 'AUTH_EXPIRED') {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }

    setState(() => cargando = false);
  }

  Color _getColorEstado(int idEstado) {
    switch (idEstado) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Mis Emergencias'),
        centerTitle: true,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            cargando = true;
                            error = null;
                          });
                          _cargarIncidencias();
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : incidencias.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No tienes emergencias reportadas'),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/reportar-emergencia',
                            ),
                            icon: const Icon(Icons.emergency),
                            label: const Text('Reportar Emergencia'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => cargando = true);
                        _cargarIncidencias();
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: incidencias.length,
                        itemBuilder: (context, index) {
                          final inc = incidencias[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getColorEstado(inc.idEstado),
                                child: const Icon(Icons.emergency,
                                    color: Colors.white),
                              ),
                              title: Text(
                                '#${inc.idIncidente} - ${inc.getMarca()} ${inc.getPlaca()}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    inc.getCategoriaNombre(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${inc.getEstadoNombre()} • ${inc.getNivelPrioridad()}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                  Text(
                                    inc.getFechaFormato(),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                _showDetailDialog(context, inc);
                              },
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final resultado = await Navigator.pushNamed(
            context,
            '/reportar-emergencia',
          );
          if (resultado != null) {
            _cargarIncidencias();
          }
        },
        label: const Text('Nueva Emergencia'),
        icon: const Icon(Icons.emergency),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showDetailDialog(BuildContext context, IncidenteDetalle inicial) {
    IncidenteDetalle inc = inicial;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> analizarIA() async {
            showDialog(
              context: ctx,
              barrierDismissible: false,
              builder: (_) => const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Analizando evidencias con IA...'),
                    SizedBox(height: 8),
                    Text(
                      'Puede tardar unos segundos',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );

            final resultado = await incidenteService.analizarConIA(inc.idIncidente);

            if (!mounted) return;
            Navigator.pop(ctx); // Cierra el diálogo de carga

            if (resultado['success']) {
              final actualizado = resultado['incidente'] as IncidenteDetalle;
              setDialogState(() => inc = actualizado);
              _cargarIncidencias();
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('✨ Análisis IA completado'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(resultado['error'] ?? 'Error IA'),
                  backgroundColor: Colors.red,
                ),
              );
              if (resultado['code'] == 'AUTH_EXPIRED') {
                Navigator.of(ctx).pushReplacementNamed('/login');
              }
            }
          }

          Future<void> cancelar() async {
            final confirmar = await showDialog<bool>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('¿Cancelar incidente?'),
                content: const Text(
                  'Esta acción no se puede deshacer. ¿Seguro que quieres cancelar esta solicitud?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
            if (confirmar != true) return;

            final resultado = await incidenteService.cancelarIncidente(inc.idIncidente);
            if (!mounted) return;

            if (resultado['success'] == true) {
              Navigator.pop(ctx);
              _cargarIncidencias();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Incidente cancelado'),
                  backgroundColor: Colors.orange,
                ),
              );
            } else {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(resultado['error'] ?? 'Error al cancelar'),
                  backgroundColor: Colors.red,
                ),
              );
              if (resultado['code'] == 'AUTH_EXPIRED') {
                Navigator.of(ctx).pushReplacementNamed('/login');
              }
            }
          }

          // Solo consideramos "taller confirmado" cuando un taller aceptó la
          // asignación: pendiente/rechazada no cuentan porque aún no hay un
          // técnico realmente asignado al cliente.
          const estadosAsigActivos = {
            'aceptada', 'en_camino', 'llegado', 'completada'
          };
          final asigActiva = (inc.asignaciones != null &&
                  inc.asignaciones!.isNotEmpty)
              ? inc.asignaciones!.firstWhere(
                  (a) => estadosAsigActivos.contains(
                      a.estado.nombre.toLowerCase()),
                  orElse: () => inc.asignaciones!.first,
                )
              : null;
          final tieneTallerConfirmado = asigActiva != null &&
              estadosAsigActivos.contains(asigActiva.estado.nombre.toLowerCase());

          return AlertDialog(
            title: Text('#${inc.idIncidente} - Detalles'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Estado:', inc.getEstadoNombre()),
                  _detailRow('Vehículo:', '${inc.getMarca()} ${inc.getPlaca()}'),
                  _detailRow('Categoría:', inc.getCategoriaNombre()),
                  _detailRow('Prioridad:', inc.getNivelPrioridad()),
                  _detailRow('Ubicación:', inc.getUbicacion()),
                  _detailRow('Fecha:', inc.getFechaFormato()),
                  if (inc.descripcionUsuario != null) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Descripción:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(inc.descripcionUsuario!),
                  ],
                  if (inc.resumenIa != null) ...[
                    const Divider(height: 28),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome,
                            color: Colors.deepPurple, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Análisis IA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const Spacer(),
                        if (inc.clasificacionIaConfianza != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _colorConfianza(
                                  inc.clasificacionIaConfianza!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${(inc.clasificacionIaConfianza! * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Text(
                        inc.resumenIa!,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                    if (inc.requiereRevisionManual) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.orange, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Baja confianza — un operador revisará manualmente.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (tieneTallerConfirmado) ...[
                    const Divider(height: 28),
                    Row(
                      children: [
                        const Icon(Icons.build_circle,
                            color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Asignación',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildAsignacionCard(asigActiva!),
                  ],
                  if (inc.idCategoria == null) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Analizar con IA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: analizarIA,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (inc.idEstado == 1 || inc.idEstado == 2)
                TextButton(
                  onPressed: cancelar,
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Cancelar solicitud'),
                ),
              if (inc.idEstado == 3 && !inc.evaluado)
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final updated = await Navigator.pushNamed(
                      context,
                      '/calificar-servicio',
                      arguments: inc.idIncidente,
                    );
                    if (updated == true) {
                      _cargarIncidencias();
                    }
                  },
                  icon: const Icon(Icons.star, size: 18),
                  label: const Text('Calificar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
              if (tieneTallerConfirmado)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MensajesScreen(idIncidente: inc.idIncidente),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Mensajes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (tieneTallerConfirmado)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TecnicoTrackingScreen(
                          idIncidente: inc.idIncidente,
                          clienteLat: inc.latitud,
                          clienteLng: inc.longitud,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Ver técnico'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubirEvidenciaScreen(
                        idIncidente: inc.idIncidente,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Evidencias'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _colorAsignacion(String estado) {
    switch (estado.toLowerCase()) {
      case 'aceptada':
      case 'en_camino':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      case 'completada':
        return Colors.blue;
      case 'pendiente':
      default:
        return Colors.orange;
    }
  }

  Widget _buildAsignacionCard(Asignacion a) {
    final color = _colorAsignacion(a.estado.nombre);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            a.getMensajeEstado(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
          if (a.notaTaller != null && a.notaTaller!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '💬 "${a.notaTaller!}"',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          if (a.taller.telefono != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  a.taller.telefono!,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _colorConfianza(double c) {
    if (c >= 0.8) return Colors.green;
    if (c >= 0.6) return Colors.orange;
    return Colors.red;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.bold),
              softWrap: true),
          const SizedBox(width: 12),
          Expanded(child: Text(value, softWrap: true)),
        ],
      ),
    );
  }
}
