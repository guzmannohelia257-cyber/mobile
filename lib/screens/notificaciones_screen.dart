import 'package:flutter/material.dart';

import '../models/incidente.dart';
import '../services/incidente_service.dart';
import '../services/notification_service.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final NotificationService _notificationService = NotificationService();
  final IncidenteService _incidenteService = IncidenteService();

  bool _loading = true;
  bool _soloNoLeidas = false;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    final data = await _notificationService.listarMisNotificaciones(
      soloNoLeidas: _soloNoLeidas,
    );
    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  Future<void> _marcarLeida(Map<String, dynamic> item) async {
    final id = item['id_notificacion'];
    if (id is! int) return;

    final ok = await _notificationService.marcarLeida(id);
    if (!mounted) return;

    if (ok) {
      setState(() {
        item['leido'] = true;
      });
    }
  }

  bool _esNotificacionCalificar(String titulo, String mensaje) {
    final t = titulo.toLowerCase();
    final m = mensaje.toLowerCase();
    return t.contains('califica') || m.contains('califica');
  }

  Future<void> _abrirCalificacionSiAplica(Map<String, dynamic> item) async {
    final titulo = (item['titulo'] ?? '').toString();
    final mensaje = (item['mensaje'] ?? '').toString();
    if (!_esNotificacionCalificar(titulo, mensaje)) return;

    final idIncidenteRaw = item['id_incidente'];
    final idIncidente = idIncidenteRaw is int
        ? idIncidenteRaw
        : int.tryParse(idIncidenteRaw?.toString() ?? '');
    if (idIncidente == null || idIncidente == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidente no disponible')),
      );
      return;
    }

    final result = await _incidenteService.obtenerIncidencia(idIncidente);
    if (!mounted) return;

    if (result['success'] == true) {
      final inc = result['incidente'] as IncidenteDetalle;
      if (inc.evaluado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya calificaste este servicio')),
        );
        return;
      }

      final updated = await Navigator.of(context).pushNamed(
        '/calificar-servicio',
        arguments: idIncidente,
      );
      if (updated == true) {
        _cargar();
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['error']?.toString() ?? 'Error al abrir')),
    );
  }

  String _fechaBonita(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Solo no leídas'),
            value: _soloNoLeidas,
            onChanged: (value) {
              setState(() => _soloNoLeidas = value);
              _cargar();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text('No hay notificaciones.'),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargar,
                        child: ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final titulo = (item['titulo'] ?? '').toString();
                            final mensaje = (item['mensaje'] ?? '').toString();
                            final leido = item['leido'] == true;
                            final fecha = _fechaBonita(item['created_at']);

                            return ListTile(
                              leading: Icon(
                                leido
                                    ? Icons.notifications_none
                                    : Icons.notifications_active,
                                color: leido ? Colors.grey : Colors.red,
                              ),
                              title: Text(
                                titulo,
                                style: TextStyle(
                                  fontWeight:
                                      leido ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '$mensaje\n$fecha',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              onTap: () async {
                                await _marcarLeida(item);
                                await _abrirCalificacionSiAplica(item);
                              },
                              trailing: leido
                                  ? null
                                  : TextButton(
                                      onPressed: () => _marcarLeida(item),
                                      child: const Text('Marcar leída'),
                                    ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
