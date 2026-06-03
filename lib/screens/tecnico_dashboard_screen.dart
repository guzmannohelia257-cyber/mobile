import 'dart:async';

import 'package:flutter/material.dart';

import '../models/asignacion_response.dart';
import '../models/evidencia.dart';
import '../services/auth_service.dart';
import '../services/realtime_service.dart';
import '../services/tecnico_asignaciones_service.dart';
import '../services/tecnico_auth_service.dart';
import '../widgets/taller_activo_chip.dart';
import 'tecnico_ruta_screen.dart';

class TecnicoDashboardScreen extends StatefulWidget {
  const TecnicoDashboardScreen({super.key});

  @override
  State<TecnicoDashboardScreen> createState() => _TecnicoDashboardScreenState();
}

class _TecnicoDashboardScreenState extends State<TecnicoDashboardScreen> {
  final TecnicoAsignacionesService _tecnicoService =
      TecnicoAsignacionesService();
  final AuthService _authService = AuthService();
  final TecnicoAuthService _tecnicoAuthService = TecnicoAuthService();
  final RealtimeService _realtime = RealtimeService();
  StreamSubscription<WsEvent>? _rtSub;

  AsignacionResponse? _asignacion;
  IncidenteResponse? _incidente;
  // ETA en vivo consultado periodicamente al backend, para que la tarjeta
  // muestre el MISMO valor que ve el resto de las vistas (no el snapshot
  // estatico de la asignacion). Es null hasta que llega la primera respuesta.
  int? _etaEnVivo;
  Timer? _etaTimer;
  bool _isLoading = true;
  String? _errorMessage;
  List<Evidencia> _evidencias = [];
  bool _loadingEvidencias = false;
  // Evita dobles envios (doble toque o recarga por realtime) que dispararian
  // una segunda transicion de estado ya invalida en el backend (400).
  bool _accionEnCurso = false;

  void _log(String message) {
    debugPrint('[TEC DASH] $message');
  }

  @override
  void initState() {
    super.initState();
    _log('initState -> dashboard tecnico inicializado');
    _loadAsignacion();
    // Tiempo real: el técnico ya está suscrito a su canal usuario:{id} en el
    // login. Cuando el taller lo asigna, el backend publica 'asignacion.asignada'
    // y recargamos la asignación sin que el técnico tenga que refrescar.
    _rtSub = _realtime.events.listen(_onRealtimeEvent);
  }

  void _onRealtimeEvent(WsEvent evt) {
    if (!mounted) return;
    if (evt.event == 'asignacion.asignada') {
      _log('realtime -> asignacion.asignada, recargando asignacion');
      _loadAsignacion();
    }
  }

  @override
  void dispose() {
    _rtSub?.cancel();
    _etaTimer?.cancel();
    _tecnicoService.detenerSeguimientoUbicacion();
    super.dispose();
  }

  /// Estados en los que el tecnico va en camino y tiene sentido consultar el
  /// ETA en vivo de la asignacion.
  static const _estadosConEta = {'aceptada', 'en_camino', 'llegado'};

  /// Arranca (o reinicia) el sondeo periodico del ETA en vivo cada 8s. Cancela
  /// cualquier timer previo y limpia el ETA cacheado para no mezclar valores de
  /// una asignacion anterior.
  void _iniciarEtaEnVivo() {
    _etaTimer?.cancel();
    _etaEnVivo = null;
    final asignacion = _asignacion;
    if (asignacion == null) return;

    Future<void> consultar() async {
      final actual = _asignacion;
      if (actual == null) return;
      final resp = await _tecnicoService.obtenerEtaAsignacion(actual.idAsignacion);
      if (!mounted) return;
      final eta = (resp?['eta_minutos'] as num?)?.toInt();
      if (eta == null) return;
      setState(() => _etaEnVivo = eta);
    }

    consultar();
    _etaTimer = Timer.periodic(const Duration(seconds: 8), (_) => consultar());
  }

  /// Detiene el sondeo del ETA en vivo y limpia el valor cacheado.
  void _detenerEtaEnVivo() {
    _etaTimer?.cancel();
    _etaTimer = null;
    _etaEnVivo = null;
  }

  Future<void> _loadAsignacion() async {
    _log('_loadAsignacion -> INICIO');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _log('_loadAsignacion -> solicitando asignacion actual');
      final asig = await _tecnicoService.getAsignacionActual();
      if (asig == null) {
        _log('_loadAsignacion -> sin asignacion activa (null)');
        _detenerEtaEnVivo();
        setState(() {
          _asignacion = null;
          _incidente = null;
          _isLoading = false;
        });
        return;
      }

      _log(
        '_loadAsignacion -> asignacion recibida '
        'idAsignacion=${asig.idAsignacion}, idIncidente=${asig.idIncidente}, '
        'estado=${asig.estadoAsignacion}',
      );

      final incidente = asig.incidente;
      _log(
        '_loadAsignacion -> incidente embebido '
        'idIncidente=${incidente.idIncidente}, categoria=${incidente.categoria}, '
        'prioridad=${incidente.prioridad}',
      );

      setState(() {
        _asignacion = asig;
        _incidente = incidente;
        _isLoading = false;
      });

      // El seguimiento GPS en tiempo real solo se activa cuando la asignacion esta en_camino.
      if (asig.estadoAsignacion == 'en_camino') {
        _tecnicoService.iniciarSeguimientoUbicacion();
      } else {
        _tecnicoService.detenerSeguimientoUbicacion();
      }

      // El ETA en vivo se sondea mientras el tecnico va en camino (aceptada /
      // en_camino / llegado). Reiniciamos el timer en cada recarga para que use
      // siempre la asignacion vigente.
      if (_estadosConEta.contains(asig.estadoAsignacion)) {
        _iniciarEtaEnVivo();
      } else {
        _detenerEtaEnVivo();
      }

      // Cargar evidencias del incidente
      _cargarEvidencias(asig.idAsignacion);

      _log('_loadAsignacion -> FIN OK');
    } catch (e, st) {
      _log('_loadAsignacion -> ERROR: $e');
      _log('_loadAsignacion -> STACK: $st');
      if (e.toString().contains('401')) {
        _log('_loadAsignacion -> 401 detectado, forzando logout');
        await _logout();
        return;
      }
      setState(() {
        _errorMessage = _mapError(e);
        _isLoading = false;
      });
    }
  }

  String _mapError(dynamic error) {
    final text = error.toString();
    _log('_mapError -> raw=$text');
    if (text.contains('404')) {
      return 'No hay asignacion actual. Espera a que un taller te asigne.';
    }
    if (text.contains('401')) {
      return 'Sesion expirada. Vuelve a iniciar sesion.';
    }
    if (text.contains('409')) {
      return 'Ya tienes otra asignacion activa. Completala primero.';
    }
    if (text.contains('Connection') || text.contains('SocketException')) {
      return 'Error de conexion. Verifica tu internet.';
    }
    return 'Error: $error';
  }

  Future<void> _cargarEvidencias(int idAsignacion) async {
    setState(() => _loadingEvidencias = true);
    final lista = await _tecnicoService.obtenerEvidencias(idAsignacion);
    // También incluir las que ya vienen embebidas en el incidente
    final embebidas = _asignacion?.incidente.evidencias ?? [];
    final todas = [...embebidas];
    for (final e in lista) {
      if (!todas.any((x) => x.idEvidencia == e.idEvidencia)) {
        todas.add(e);
      }
    }
    if (mounted) setState(() { _evidencias = todas; _loadingEvidencias = false; });
  }

  Future<void> _handleIniciarViaje() async {
    // Guard: si ya hay una accion en curso (o no hay asignacion) ignoramos el
    // toque. Asi un segundo toque no dispara una 2a llamada que llegaria cuando
    // la asignacion ya esta en 'en_camino' (el backend responderia 400).
    if (_accionEnCurso || _asignacion == null) return;

    // Defensivo: si la asignacion ya no esta 'aceptada' (p.ej. se inicio por
    // otra via o el realtime aun no refresco), recargamos y salimos en vez de
    // reintentar una transicion invalida.
    if (_asignacion!.estadoAsignacion != 'aceptada') {
      _log('_handleIniciarViaje -> estado!=aceptada (${_asignacion!.estadoAsignacion}), recargando');
      await _loadAsignacion();
      return;
    }

    _log('_handleIniciarViaje -> INICIO idAsignacion=${_asignacion!.idAsignacion} estado=${_asignacion!.estadoAsignacion}');

    setState(() => _accionEnCurso = true);
    try {
      final updated = await _tecnicoService.iniciarViaje(_asignacion!.idAsignacion);
      _log('_handleIniciarViaje -> OK nuevoEstado=${updated.estadoAsignacion}');
      setState(() => _asignacion = updated);
      _tecnicoService.iniciarSeguimientoUbicacion();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Viaje iniciado. Compartiendo ubicación en tiempo real.')),
      );
    } catch (e, st) {
      _log('_handleIniciarViaje -> ERROR: $e');
      _log('_handleIniciarViaje -> STACK: $st');
      if (!mounted) return;
      // Si el error indica que la asignacion ya no esta 'aceptada' (la 1a
      // llamada SI funciono y ya esta 'en_camino'), no mostramos error feo:
      // el viaje ya esta iniciado, solo recargamos en silencio.
      final raw = e.toString().toLowerCase();
      if (raw.contains('iniciar viaje') ||
          raw.contains('en_camino') ||
          raw.contains('aceptada')) {
        _log('_handleIniciarViaje -> transicion ya aplicada, recargando silenciosamente');
        await _loadAsignacion();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _accionEnCurso = false);
    }
  }

  Future<void> _handleLlegue() async {
    if (_accionEnCurso || _asignacion == null) return;
    _log('_handleLlegue -> INICIO idAsignacion=${_asignacion!.idAsignacion}');
    setState(() => _accionEnCurso = true);
    try {
      final updated = await _tecnicoService.marcarLlegada(_asignacion!.idAsignacion);
      _log('_handleLlegue -> OK nuevoEstado=${updated.estadoAsignacion}');
      setState(() => _asignacion = updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Llegada marcada. Ya puedes finalizar el servicio.')),
      );
    } catch (e, st) {
      _log('_handleLlegue -> ERROR: $e');
      _log('_handleLlegue -> STACK: $st');
      if (!mounted) return;
      // Si el geofence ya la marco 'llegado', recargamos en silencio.
      final raw = e.toString().toLowerCase();
      if (raw.contains('llegado') || raw.contains('marcar llegada')) {
        await _loadAsignacion();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _accionEnCurso = false);
    }
  }

  Future<void> _handleCompletar() async {
    // Mismo guard que en iniciar viaje: evita abrir el dialogo o reenviar
    // mientras ya hay una accion en curso.
    if (_accionEnCurso || _asignacion == null) return;
    _log('_handleCompletar -> abrir dialogo idAsignacion=${_asignacion!.idAsignacion} estado=${_asignacion!.estadoAsignacion}');

    final resumenController = TextEditingController();
    // Pre-cargamos el cobro con la cotizacion que vio el cliente (si existe),
    // para que el tecnico la confirme o ajuste en lugar de partir de cero.
    final costoController = TextEditingController(
      text: _asignacion!.costoEstimado != null
          ? _asignacion!.costoEstimado!.toStringAsFixed(0)
          : '',
    );

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Completar Servicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_asignacion!.costoEstimado != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Cotización que vio el cliente: Bs ${_asignacion!.costoEstimado!.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Cobro final (obligatorio)'),
              const SizedBox(height: 8),
              TextField(
                controller: costoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ej: 85000',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Resumen del trabajo (opcional)'),
              const SizedBox(height: 8),
              TextField(
                controller: resumenController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Describe el trabajo realizado',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Guard contra dobles envios al confirmar el dialogo.
                if (_accionEnCurso) return;
                // El monto final es obligatorio: el backend lo exige (>0) y sin
                // el se generaba un cobro de $0 que el cliente no podia pagar.
                final costo = double.tryParse(costoController.text.trim());
                if (costo == null || costo <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa el monto final del servicio (mayor a 0).'),
                    ),
                  );
                  return;
                }
                // Capturamos el messenger ANTES de cerrar el dialogo: tras el
                // Navigator.pop el context del dialogo queda desactivado y
                // ScaffoldMessenger.of(context) lanzaria "deactivated widget".
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                setState(() => _accionEnCurso = true);
                try {
                  final resumen = resumenController.text.trim().isEmpty
                      ? null
                      : resumenController.text.trim();

                  _log('_handleCompletar -> enviando completar costo=$costo resumenLen=${resumen?.length ?? 0}');

                  final updated = await _tecnicoService.completar(
                    _asignacion!.idAsignacion,
                    costoFinal: costo,
                    resumenTrabajo: resumen,
                  );
                  _log('_handleCompletar -> OK nuevoEstado=${updated.estadoAsignacion}');
                  setState(() => _asignacion = updated);
                  _tecnicoService.detenerSeguimientoUbicacion();

                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Servicio completado.')),
                  );
                } catch (e, st) {
                  _log('_handleCompletar -> ERROR: $e');
                  _log('_handleCompletar -> STACK: $st');
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(_mapError(e))),
                  );
                } finally {
                  if (mounted) setState(() => _accionEnCurso = false);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmLogout() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesion'),
        content: const Text('Estas seguro de que deseas cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _logout();
    }
  }

  Future<void> _logout() async {
    _log('_logout -> limpiando sesiones tecnico/general');
    await _tecnicoAuthService.logout();
    await _authService.logout();
    _log('_logout -> completado, navegando a /login');
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Color _getColorForEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.grey;
      case 'aceptada':
        return Colors.green;
      case 'en_camino':
        return Colors.blue;
      case 'llegado':
        return Colors.indigo;
      case 'completada':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForEstado(String estado) {
    switch (estado) {
      case 'pendiente':
        return Icons.schedule;
      case 'aceptada':
        return Icons.check_circle;
      case 'en_camino':
        return Icons.directions_car;
      case 'llegado':
        return Icons.flag;
      case 'completada':
        return Icons.done_all;
      default:
        return Icons.help;
    }
  }

  /// Abre la vista de ruta estilo delivery hacia el cliente. La ubicacion del
  /// cliente proviene del incidente embebido en la asignacion (latitud/longitud,
  /// que el backend envia en IncidenteParaTecnico).
  void _abrirRutaCliente() {
    final incidente = _incidente ?? _asignacion?.incidente;
    if (incidente == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TecnicoRutaScreen(
          idIncidente: incidente.idIncidente,
          idAsignacion: _asignacion!.idAsignacion,
          clienteLat: incidente.latitud,
          clienteLng: incidente.longitud,
        ),
      ),
    );
  }

  /// Boton secundario para abrir la ruta hacia el cliente. Solo tiene sentido
  /// mientras el tecnico va en camino (estados aceptada / en_camino).
  Widget _buildBotonVerRuta() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _abrirRutaCliente,
        icon: const Icon(Icons.navigation),
        label: const Text('Ver ruta al cliente'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_asignacion == null) return const SizedBox.shrink();

    switch (_asignacion!.estadoAsignacion) {
      case 'pendiente':
        return Card(
          color: Colors.grey[200],
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Esperando que el taller acepte la asignacion...',
              textAlign: TextAlign.center,
            ),
          ),
        );

      case 'aceptada':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _accionEnCurso ? null : _handleIniciarViaje,
                icon: const Icon(Icons.directions_car),
                label: const Text('Iniciar Viaje'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildBotonVerRuta(),
          ],
        );

      case 'en_camino':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _accionEnCurso ? null : _handleLlegue,
                icon: const Icon(Icons.location_on),
                label: const Text('Ya llegué'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildBotonVerRuta(),
          ],
        );

      case 'llegado':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _accionEnCurso ? null : _handleCompletar,
            icon: const Icon(Icons.check_circle),
            label: const Text('Terminar / Finalizar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        );

      case 'completada':
        return Card(
          color: Colors.green[50],
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Servicio completado. El cliente puede evaluar tu trabajo.',
              textAlign: TextAlign.center,
            ),
          ),
        );

      default:
        return Text('Estado desconocido: ${_asignacion!.estadoAsignacion}');
    }
  }

  Widget _buildEvidencias() {
    if (_loadingEvidencias) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_evidencias.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'El cliente no subió evidencias.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: _evidencias.map((e) => _buildEvidenciaItem(e)).toList(),
    );
  }

  Widget _buildEvidenciaItem(Evidencia ev) {
    if (ev.esImagen) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            ev.urlArchivo,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 80,
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
            ),
          ),
        ),
      );
    }

    if (ev.esAudio) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.mic, color: Colors.white),
        ),
        title: const Text('Audio del cliente'),
        subtitle: ev.transcripcionAudio != null
            ? Text(ev.transcripcionAudio!, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
      );
    }

    // Texto / descripción IA
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: Colors.blue,
        child: Icon(Icons.description, color: Colors.white),
      ),
      title: const Text('Descripción adicional'),
      subtitle: ev.descripcionIa != null ? Text(ev.descripcionIa!) : null,
    );
  }

  Widget _buildGpsIndicator() {
    if (_asignacion?.estadoAsignacion != 'en_camino') return const SizedBox.shrink();
    return Card(
      color: Colors.blue[50],
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue, size: 18),
            SizedBox(width: 8),
            Text(
              'Compartiendo ubicación en tiempo real',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _log(
      'build -> isLoading=$_isLoading, error=${_errorMessage != null}, '
      'hasAsignacion=${_asignacion != null}, '
      'estado=${_asignacion?.estadoAsignacion ?? 'null'}',
    );

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Asignacion')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Asignacion')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: _loadAsignacion,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(140, 48),
                      ),
                      child: const Text('Reintentar'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(140, 48),
                      ),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesion'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_asignacion == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Mi Asignacion'),
          actions: [
            const TallerActivoChip(),
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => Navigator.pushNamed(context, '/notificaciones'),
              tooltip: 'Notificaciones',
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAsignacion),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _confirmLogout,
              tooltip: 'Cerrar sesion',
            ),
          ],
        ),
        body: const Center(
          child: Text('No hay asignacion pendiente en este momento.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Asignacion Actual'),
        actions: [
          const TallerActivoChip(),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => Navigator.pushNamed(context, '/notificaciones'),
            tooltip: 'Notificaciones',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAsignacion),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
            tooltip: 'Cerrar sesion',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAsignacion,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: _getColorForEstado(_asignacion!.estadoAsignacion),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estado', style: TextStyle(color: Colors.white70)),
                          Text(
                            _asignacion!.estadoAsignacion.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _getIconForEstado(_asignacion!.estadoAsignacion),
                        size: 40,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if ((_etaEnVivo ?? _asignacion!.etaMinutos) != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'ETA: ${_etaEnVivo ?? _asignacion!.etaMinutos} minutos',
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('Detalle del Incidente', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('👤 Cliente', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text(
                        _incidente?.usuario?['nombre'] ?? _asignacion!.incidente.usuario?['nombre'] ?? 'Nombre no disponible',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if ((_incidente?.usuario?['telefono'] ?? _asignacion!.incidente.usuario?['telefono']) != null)
                        Text('Tel: ${_incidente?.usuario?['telefono'] ?? _asignacion!.incidente.usuario?['telefono']}'),
                      
                      const Divider(),
                      
                      const Text('🚗 Vehículo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Row(
                        children: [
                          Text(
                            _incidente?.vehiculo?['placa'] ?? _asignacion!.incidente.vehiculo?['placa'] ?? 'Placa N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_incidente?.vehiculo?['marca'] ?? _asignacion!.incidente.vehiculo?['marca'] ?? ''} ${_incidente?.vehiculo?['modelo'] ?? _asignacion!.incidente.vehiculo?['modelo'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if ((_incidente?.vehiculo?['color'] ?? _asignacion!.incidente.vehiculo?['color']) != null)
                        Text('Color: ${_incidente?.vehiculo?['color'] ?? _asignacion!.incidente.vehiculo?['color']}'),
                        
                      const Divider(),
                      const Text('⚠️ Problema', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text('Categoria: ${_incidente?.categoria ?? _asignacion!.incidente.categoria}'),
                      Text('Prioridad: ${_incidente?.prioridad ?? _asignacion!.incidente.prioridad}'),
                      const SizedBox(height: 4),
                      const Text('Descripcion:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_incidente?.descripcionUsuario ?? _asignacion!.incidente.descripcionUsuario),
                      if ((_incidente?.resumenIa ?? _asignacion!.incidente.resumenIa) != null) ...[
                        const SizedBox(height: 8),
                        const Text('Analisis IA:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text((_incidente?.resumenIa ?? _asignacion!.incidente.resumenIa)!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildGpsIndicator(),
              const SizedBox(height: 16),
              Text('Evidencias del Cliente', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildEvidencias(),
                ),
              ),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
