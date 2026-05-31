import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../services/incidente_service.dart';
import '../models/evidencia.dart';
import '../models/incidente.dart';
import '../models/categoria.dart';
import 'seleccionar_taller_screen.dart';
import '../services/taller_service.dart';

/// Evidencia capturada localmente, aún no subida al backend.
class _PendingEvidencia {
  final File archivo;
  final int tipo; // 1=imagen, 2=audio
  _PendingEvidencia(this.archivo, this.tipo);
  bool get esImagen => tipo == 1;
  bool get esAudio => tipo == 2;
}

class SubirEvidenciaScreen extends StatefulWidget {
  // Modo A: incidente ya creado (desde historial) — sube directo al backend.
  final int? idIncidente;

  // Modo B: reporte nuevo (desde formulario) — acumula local, crea al finalizar.
  final int? idVehiculo;
  final String? descripcionUsuario;
  final double? latitud;
  final double? longitud;

  const SubirEvidenciaScreen({
    super.key,
    this.idIncidente,
    this.idVehiculo,
    this.descripcionUsuario,
    this.latitud,
    this.longitud,
  }) : assert(
          idIncidente != null ||
              (idVehiculo != null &&
                  descripcionUsuario != null &&
                  latitud != null &&
                  longitud != null),
          'Pasa idIncidente (modo existente) o los datos del reporte (modo nuevo)',
        );

  bool get esNuevoReporte => idIncidente == null;

  @override
  State<SubirEvidenciaScreen> createState() => _SubirEvidenciaScreenState();
}

class _SubirEvidenciaScreenState extends State<SubirEvidenciaScreen> {
  final incidenteService = IncidenteService();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  // Modo existente: evidencias del backend
  List<Evidencia> evidencias = [];
  // Modo nuevo: evidencias locales en memoria
  List<_PendingEvidencia> pendientes = [];

  bool cargando = false;
  bool subiendo = false;
  bool grabando = false;
  bool reportando = false;
  // Idempotency key estable para esta sesión de reporte: si el usuario
  // hace doble tap o pierde conexión y reintenta, el backend devuelve el
  // mismo incidente sin duplicar.
  late final String _idempotencyKey = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    if (!widget.esNuevoReporte) {
      cargando = true;
      _cargarEvidencias();
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _cargarEvidencias() async {
    final resultado =
        await incidenteService.listarEvidencias(widget.idIncidente!);
    if (!mounted) return;
    if (resultado['success']) {
      setState(() {
        evidencias = resultado['evidencias'] as List<Evidencia>;
        cargando = false;
      });
    } else {
      setState(() => cargando = false);
    }
  }

  Future<void> _tomarFoto() async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (foto == null) return;
    await _agregar(File(foto.path), 1);
  }

  Future<void> _elegirGaleria() async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (foto == null) return;
    await _agregar(File(foto.path), 1);
  }

  Future<void> _toggleGrabacion() async {
    if (grabando) {
      final path = await _recorder.stop();
      setState(() => grabando = false);
      if (path != null) {
        await _agregar(File(path), 2);
      }
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/evidencia_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        setState(() => grabando = true);
      } else {
        _mostrarError('Permiso de micrófono denegado');
      }
    }
  }

  /// Agrega evidencia: en modo existente sube al backend; en modo nuevo solo local.
  Future<void> _agregar(File archivo, int tipo) async {
    if (widget.esNuevoReporte) {
      setState(() {
        pendientes.add(_PendingEvidencia(archivo, tipo));
      });
      _mostrarInfo('Evidencia agregada (${pendientes.length})');
      return;
    }

    setState(() => subiendo = true);
    final resultado = await incidenteService.subirEvidencia(
      idIncidente: widget.idIncidente!,
      idTipoEvidencia: tipo,
      archivo: archivo,
    );
    if (!mounted) return;
    setState(() => subiendo = false);

    if (resultado['success']) {
      _mostrarInfo('✅ Evidencia subida');
      _cargarEvidencias();
    } else {
      _mostrarError(resultado['error'] ?? 'Error al subir');
    }
  }

  void _mostrarInfo(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $msg'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      ),
    );
  }

  /// Reporta el incidente: lo crea, sube las evidencias, ejecuta la IA y muestra la selección de talleres.
  Future<void> _reportarIncidente() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reportar incidente?'),
        content: Text(
          pendientes.isEmpty
              ? 'No has agregado evidencias. ¿Reportar de todos modos?'
              : 'Se reportará la emergencia con ${pendientes.length} '
                  'evidencia(s) y se analizará con IA.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.emergency),
            label: const Text('Reportar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => reportando = true);

    // 1) Crear incidencia (con idempotency_key para deduplicar reintentos)
    final creacion = await incidenteService.crearIncidencia(
      idVehiculo: widget.idVehiculo!,
      descripcionUsuario: widget.descripcionUsuario!,
      latitud: widget.latitud!,
      longitud: widget.longitud!,
      idempotencyKey: _idempotencyKey,
    );

    if (!mounted) return;

    if (!creacion['success']) {
      setState(() => reportando = false);
      _mostrarError(creacion['error'] ?? 'No se pudo reportar');
      if (creacion['code'] == 'AUTH_EXPIRED') {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    final idIncidente = (creacion['incidente'] as dynamic).idIncidente as int;

    // 2) Subir evidencias secuencialmente
    for (final p in pendientes) {
      final r = await incidenteService.subirEvidencia(
        idIncidente: idIncidente,
        idTipoEvidencia: p.tipo,
        archivo: p.archivo,
      );
      if (!mounted) return;
      if (!r['success']) {
        _mostrarError('Falló una evidencia: ${r['error']}');
      }
    }

    if (!mounted) return;

    // 3) 🤖 Disparar IA (bloqueante: espera a que termine)
    _mostrarLoadingIA(idIncidente);

    final resultadoIA = await incidenteService.analizarConIA(idIncidente);

    if (!mounted) return;
    Navigator.pop(context); // Cerrar loading dialog

    if (!resultadoIA['success']) {
      setState(() => reportando = false);
      _mostrarError(
        resultadoIA['error'] ?? 'Error al analizar con IA',
      );
      if (resultadoIA['code'] == 'AUTH_EXPIRED') {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // 4) Obtener incidente actualizado
    final obtenerResult = await incidenteService.obtenerIncidencia(idIncidente);

    if (!mounted) return;

    if (!obtenerResult['success']) {
      setState(() => reportando = false);
      _mostrarError('Error al obtener datos del incidente');
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/conductor-home',
        (route) => false,
      );
      return;
    }

    final incidenteActualizado = obtenerResult['incidente'] as IncidenteDetalle;
    final idCategoria = incidenteActualizado.idCategoria;

    if (idCategoria == null) {
      setState(() => reportando = false);
      _mostrarError('No se pudo determinar la categoria del incidente');
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/conductor-home',
        (route) => false,
      );
      return;
    }

    Categoria categoria;
    try {
      categoria = await TallerService().getCategoria(idCategoria);
    } catch (e) {
      setState(() => reportando = false);
      _mostrarError('Error al cargar categoria');
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/conductor-home',
        (route) => false,
      );
      return;
    }

    if (!mounted) return;

    // 5) 🏪 Mostrar pantalla de selección de talleres
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarTallerScreen(
          categoria: categoria,
          latitud: widget.latitud!,
          longitud: widget.longitud!,
          idIncidente: incidenteActualizado.idIncidente,
        ),
      ),
    );

    if (!mounted) return;

    _mostrarInfo(
      '✅ Emergencia #$idIncidente reportada. Taller asignado correctamente.',
    );

    // 6) Volver al home
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/conductor-home',
      (route) => false,
    );
  }

  /// Muestra el diálogo de carga mientras la IA analiza el incidente.
  void _mostrarLoadingIA(int idIncidente) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              '🤖 Analizando con IA...',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Emergencia #$idIncidente',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'Buscando talleres disponibles',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _volverAlMenu() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/conductor-home',
      (route) => false,
    );
  }

  int get _totalEvidencias =>
      widget.esNuevoReporte ? pendientes.length : evidencias.length;

  @override
  Widget build(BuildContext context) {
    final titulo = widget.esNuevoReporte
        ? '📎 Evidencias (nuevo reporte)'
        : '📎 Evidencias #${widget.idIncidente}';

    final botonTexto = widget.esNuevoReporte
        ? (reportando ? '⏳ Reportando...' : '🚨 REPORTAR INCIDENTE')
        : 'VOLVER AL MENÚ';

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú',
          onPressed: reportando ? null : _volverAlMenu,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: subiendo || reportando ? null : _tomarFoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
                ElevatedButton.icon(
                  onPressed: subiendo || reportando ? null : _elegirGaleria,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
                ElevatedButton.icon(
                  onPressed:
                      subiendo || reportando ? null : _toggleGrabacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: grabando ? Colors.red : null,
                    foregroundColor: grabando ? Colors.white : null,
                  ),
                  icon: Icon(grabando ? Icons.stop : Icons.mic),
                  label: Text(grabando ? 'Detener' : 'Grabar audio'),
                ),
              ],
            ),
          ),
          if (subiendo)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Subiendo...'),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : _totalEvidencias == 0
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No hay evidencias aún'),
                          ],
                        ),
                      )
                    : widget.esNuevoReporte
                        ? _buildLocalList()
                        : _buildRemoteList(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: reportando || subiendo
                      ? null
                      : (widget.esNuevoReporte
                          ? _reportarIncidente
                          : _volverAlMenu),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: reportando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.emergency),
                  label: Text(
                    botonTexto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: pendientes.length,
      itemBuilder: (ctx, i) {
        final p = pendientes[i];
        return Card(
          child: ListTile(
            leading: p.esImagen
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(
                      p.archivo,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  )
                : const Icon(Icons.audiotrack, size: 40, color: Colors.red),
            title: Text(p.esImagen ? 'Imagen' : 'Audio'),
            subtitle: const Text(
              'Pendiente de enviar',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Quitar',
              onPressed: reportando
                  ? null
                  : () => setState(() => pendientes.removeAt(i)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemoteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: evidencias.length,
      itemBuilder: (ctx, i) {
        final e = evidencias[i];
        return Card(
          child: ListTile(
            leading: e.esImagen
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      e.urlArchivo,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  )
                : Icon(
                    e.esAudio ? Icons.audiotrack : Icons.description,
                    size: 40,
                    color: Colors.red,
                  ),
            title: Text(e.getTipoNombre()),
            subtitle: Text(
              e.descripcionIa ?? 'Pendiente de análisis IA',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: e.esAudio
                ? IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _player.play(UrlSource(e.urlArchivo)),
                  )
                : null,
          ),
        );
      },
    );
  }
}
