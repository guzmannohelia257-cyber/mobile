import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/pago_cliente_item.dart';
import '../utils/app_logger.dart';

class PagosService {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String _tag = 'PAGOS_SERVICE';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<Map<String, dynamic>> listarMisPagos() async {
    try {
      final token = await _getToken();
      if (token == null) {
        AppLogger.warning('Token no encontrado al listar pagos', tag: _tag);
        return {'success': false, 'error': 'No autenticado'};
      }

      final url = '$baseUrl/pagos/mis-pagos';
      AppLogger.httpRequest('GET', url, tag: _tag, headers: {'Authorization': 'Bearer ***'});
      final start = DateTime.now();
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      AppLogger.httpResponse(
        'GET',
        url,
        response.statusCode,
        tag: _tag,
        body: response.body,
        duration: DateTime.now().difference(start),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        final items = data
            .map((j) => PagoClienteItem.fromJson(j as Map<String, dynamic>))
            .toList();

        final pendientes = items.where((e) => e.estaPendiente).toList();
        final completados = items.where((e) => e.estaCompletado).toList();

        return {
          'success': true,
          'items': items,
          'pendientes': pendientes,
          'completados': completados,
        };
      }

      if (response.statusCode == 401) {
        AppLogger.warning('Sesion expirada al listar pagos', tag: _tag);
        return {
          'success': false,
          'error': 'Sesion expirada',
          'code': 'AUTH_EXPIRED',
        };
      }

      if (response.statusCode == 403) {
        AppLogger.warning('Sin permisos al listar pagos', tag: _tag);
        return {
          'success': false,
          'error': 'No tienes permisos para consultar pagos',
        };
      }

      AppLogger.warning('Respuesta inesperada al listar pagos', tag: _tag);
      return {'success': false, 'error': 'Error al cargar pagos'};
    } catch (e) {
      AppLogger.error('Excepcion al listar pagos', tag: _tag, error: e);
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Crea un PaymentIntent en Stripe a través del backend.
  /// Retorna {'success': true, 'client_secret': '...', 'payment_intent_id': '...'} o {'success': false, 'error': '...'}.
  Future<Map<String, dynamic>> crearPaymentIntent({
    required int idIncidente,
    required double montoTotal,
    int idMetodoPago = 1,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        AppLogger.warning('Token no encontrado al crear PaymentIntent', tag: _tag);
        return {'success': false, 'error': 'No autenticado'};
      }

      final url = '$baseUrl/pagos/crear-intent';
      final requestBody = {
        'id_incidente': idIncidente,
        'monto_total': montoTotal,
        'id_metodo_pago': idMetodoPago,
      };
      AppLogger.httpRequest('POST', url, tag: _tag, headers: {
        'Authorization': 'Bearer ***',
        'Content-Type': 'application/json',
      }, body: requestBody);
      final start = DateTime.now();
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      AppLogger.httpResponse(
        'POST',
        url,
        response.statusCode,
        tag: _tag,
        body: response.body,
        duration: DateTime.now().difference(start),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'client_secret': data['client_secret'] as String,
          'payment_intent_id': data['payment_intent_id'] as String,
          'monto_centavos': data['monto_centavos'] as int,
        };
      }

      if (response.statusCode == 401) {
        AppLogger.warning('Sesion expirada al crear PaymentIntent', tag: _tag);
        return {'success': false, 'error': 'Sesion expirada', 'code': 'AUTH_EXPIRED'};
      }

      final errorBody = _parseError(response.body);
      AppLogger.warning('Error al crear PaymentIntent: $errorBody', tag: _tag);
      return {'success': false, 'error': errorBody};
    } catch (e) {
      AppLogger.error('Excepcion al crear PaymentIntent', tag: _tag, error: e);
      return {'success': false, 'error': 'Error de red: $e'};
    }
  }

  /// Notifica al backend que el pago fue completado desde la app.
  /// El backend consulta Stripe y actualiza el estado del pago en la BD.
  Future<Map<String, dynamic>> confirmarPagoApp(String paymentIntentId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        AppLogger.warning('Token no encontrado al confirmar pago', tag: _tag);
        return {'success': false, 'error': 'No autenticado'};
      }

      final url = '$baseUrl/pagos/confirmar-app';
      final requestBody = {'payment_intent_id': paymentIntentId};
      AppLogger.httpRequest('POST', url, tag: _tag, headers: {
        'Authorization': 'Bearer ***',
        'Content-Type': 'application/json',
      }, body: requestBody);
      final start = DateTime.now();
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      AppLogger.httpResponse(
        'POST',
        url,
        response.statusCode,
        tag: _tag,
        body: response.body,
        duration: DateTime.now().difference(start),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'estado': data['estado']};
      }

      final errorBody = _parseError(response.body);
      AppLogger.warning('Error al confirmar pago: $errorBody', tag: _tag);
      return {'success': false, 'error': errorBody};
    } catch (e) {
      AppLogger.error('Excepcion al confirmar pago', tag: _tag, error: e);
      return {'success': false, 'error': 'Error de red: $e'};
    }
  }

  /// Preautoriza el pago con el monto estimado por IA. Aun no cobra,
  /// solo reserva. Devuelve el client_secret para confirmar la tarjeta.
  Future<Map<String, dynamic>> preautorizar(int idIncidente) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'error': 'No autenticado'};

      final url = '$baseUrl/pagos/preautorizar/$idIncidente';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'client_secret': data['client_secret'] as String?,
          'payment_intent_id': data['payment_intent_id'] as String?,
          'monto_centavos': data['monto_centavos'] as int?,
          'monto_usd': (data['monto_usd'] as num?)?.toDouble(),
        };
      }
      if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sesion expirada', 'code': 'AUTH_EXPIRED'};
      }
      return {'success': false, 'error': _parseError(response.body)};
    } catch (e) {
      return {'success': false, 'error': 'Error de red: $e'};
    }
  }

  /// Captura el PaymentIntent reservado con el monto final cuando el
  /// servicio termina. Si [montoFinal] es null, captura el monto reservado.
  Future<Map<String, dynamic>> capturar(int idIncidente,
      {double? montoFinal}) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'error': 'No autenticado'};

      final url = '$baseUrl/pagos/capturar/$idIncidente';
      final body = montoFinal != null ? {'monto_final': montoFinal} : null;
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body != null ? jsonEncode(body) : null,
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body) as Map<String, dynamic>,
        };
      }
      if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sesion expirada', 'code': 'AUTH_EXPIRED'};
      }
      return {'success': false, 'error': _parseError(response.body)};
    } catch (e) {
      return {'success': false, 'error': 'Error de red: $e'};
    }
  }

  String _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail']?.toString() ?? 'Error desconocido';
    } catch (_) {
      return body.isNotEmpty ? body : 'Error desconocido';
    }
  }
}
