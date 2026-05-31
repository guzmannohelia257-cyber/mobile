import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'tecnico_auth_service.dart';

enum LocationSenderStatus {
  idle,
  pidiendoPermisos,
  permisosDenegados,
  enviando,
  error,
}

class LocationSenderResult {
  final bool ok;
  final int? etaMinutos;
  final double? distanciaKm;
  final bool llegadoAuto;

  LocationSenderResult({
    required this.ok,
    this.etaMinutos,
    this.distanciaKm,
    this.llegadoAuto = false,
  });
}

class LocationSender {
  static const String _baseUrl = ApiConfig.baseUrl;
  final TecnicoAuthService _tecnicoAuth = TecnicoAuthService();
  final AuthService _auth = AuthService();

  Timer? _timer;
  int? _idAsignacionActiva;

  final _statusCtrl = StreamController<LocationSenderStatus>.broadcast();
  Stream<LocationSenderStatus> get status => _statusCtrl.stream;

  final _resultCtrl = StreamController<LocationSenderResult>.broadcast();
  Stream<LocationSenderResult> get results => _resultCtrl.stream;

  Future<bool> start({
    required int idAsignacion,
    Duration interval = const Duration(seconds: 12),
  }) async {
    _statusCtrl.add(LocationSenderStatus.pidiendoPermisos);

    final perm = await _requestPermission();
    if (!perm) {
      _statusCtrl.add(LocationSenderStatus.permisosDenegados);
      return false;
    }

    _idAsignacionActiva = idAsignacion;
    _statusCtrl.add(LocationSenderStatus.enviando);

    await _sendOnce();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _sendOnce());

    return true;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _idAsignacionActiva = null;
    _statusCtrl.add(LocationSenderStatus.idle);
  }

  Future<bool> _requestPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<String?> _getToken() async {
    final tecnicoToken = await _tecnicoAuth.getTecnicoToken();
    if (tecnicoToken != null && tecnicoToken.isNotEmpty) {
      return tecnicoToken;
    }
    return _auth.getToken();
  }

  Future<void> _sendOnce() async {
    if (_idAsignacionActiva == null) return;
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        _statusCtrl.add(LocationSenderStatus.error);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final response = await http
          .post(
            Uri.parse('$_baseUrl/tecnicos/me/ubicacion'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'latitud': pos.latitude,
              'longitud': pos.longitude,
              'accuracy_m': pos.accuracy,
              'velocidad_kmh': (pos.speed * 3.6),
              'id_asignacion': _idAsignacionActiva,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final eta = json['eta'] as Map<String, dynamic>?;
        final result = LocationSenderResult(
          ok: true,
          etaMinutos: eta?['eta_minutos'] as int?,
          distanciaKm: (eta?['distancia_km'] as num?)?.toDouble(),
          llegadoAuto: json['llegado_auto'] ?? false,
        );
        _resultCtrl.add(result);

        if (result.llegadoAuto) {
          stop();
        }
      } else {
        _statusCtrl.add(LocationSenderStatus.error);
      }
    } catch (_) {
      // Reintenta en el siguiente tick.
    }
  }

  void dispose() {
    stop();
    _statusCtrl.close();
    _resultCtrl.close();
  }
}
