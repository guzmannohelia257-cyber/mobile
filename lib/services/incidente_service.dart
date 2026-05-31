import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../config/api_config.dart';
import '../models/incidente.dart';
import '../models/evidencia.dart';

class IncidenteService {
  static const String baseUrl = ApiConfig.baseUrl;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String?> _getToken() async {
    final secureToken = await _secureStorage.read(key: 'token');
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Crear emergencia.
  ///
  /// [idempotencyKey] permite deduplicar reintentos (modo offline, timeouts,
  /// doble tap). Si el cliente envia el mismo key, el backend devuelve el
  /// incidente ya creado sin crear uno nuevo.
  Future<Map<String, dynamic>> crearIncidencia({
    required int idVehiculo,
    required String descripcionUsuario,
    required double latitud,
    required double longitud,
    String? idempotencyKey,
  }) async {
    try {
      debugPrint('[INCIDENTE] 🚨 Reportando emergencia...');
      debugPrint('[INCIDENTE] Vehículo: $idVehiculo');
      debugPrint('[INCIDENTE] Descripción: $descripcionUsuario');
      debugPrint('[INCIDENTE] GPS: $latitud, $longitud');
      if (idempotencyKey != null) {
        debugPrint('[INCIDENTE] idempotency_key: $idempotencyKey');
      }

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final body = <String, dynamic>{
        'id_vehiculo': idVehiculo,
        'descripcion_usuario': descripcionUsuario,
        'latitud': latitud,
        'longitud': longitud,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/incidencias/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('[INCIDENTE] Status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final incidente =
            IncidenteResponse.fromJson(jsonDecode(response.body));
        debugPrint('[INCIDENTE] ✅ Emergencia reportada: #${incidente.idIncidente}');

        return {
          'success': true,
          'incidente': incidente,
          'message': '✅ Emergencia reportada. Técnicos en camino...',
        };
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'error': error['detail'] ?? 'Datos inválidos',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Vehículo no encontrado'};
      }

      return {'success': false, 'error': 'Error al reportar emergencia'};
    } on TimeoutException catch (_) {
      debugPrint('[INCIDENTE] ❌ Timeout');
      return {'success': false, 'error': 'Tiempo de conexión agotado'};
    } catch (e) {
      debugPrint('[INCIDENTE] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Confirma el borrador de incidente eligiendo (opcionalmente) un taller.
  /// Promueve el estado a 'pendiente' y dispara el broadcast a talleres.
  Future<Map<String, dynamic>> confirmarIncidencia({
    required int idIncidente,
    int? idTallerPreferido,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final body = <String, dynamic>{};
      if (idTallerPreferido != null) {
        body['id_taller_preferido'] = idTallerPreferido;
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/incidencias/$idIncidente/confirmar'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('[INCIDENTE] confirmar status=${response.statusCode}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'incidente': IncidenteResponse.fromJson(jsonDecode(response.body)),
        };
      }

      final error = jsonDecode(response.body);
      return {
        'success': false,
        'error': error['detail']?.toString() ?? 'No se pudo confirmar',
        if (response.statusCode == 401) 'code': 'AUTH_EXPIRED',
      };
    } catch (e) {
      debugPrint('[INCIDENTE] confirmar exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Descarta un borrador (cliente abandonó el flujo antes de elegir taller).
  /// Idempotente: si el borrador ya no existe, devuelve success.
  Future<Map<String, dynamic>> descartarBorrador(int idIncidente) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .delete(
            Uri.parse('$baseUrl/incidencias/$idIncidente/borrador'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[INCIDENTE] descartar borrador status=${response.statusCode}');
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': 'No se pudo descartar (${response.statusCode})',
      };
    } catch (e) {
      debugPrint('[INCIDENTE] descartar borrador exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Listar mis emergencias.
  Future<Map<String, dynamic>> listarMisIncidencias() async {
    try {
      debugPrint('[INCIDENTE] 📋 Cargando historial...');

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/incidencias/mis-incidencias'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[INCIDENTE] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final incidencias =
            data.map((json) => IncidenteDetalle.fromJson(json)).toList();

        debugPrint('[INCIDENTE] ✅ ${incidencias.length} incidencias cargadas');
        return {'success': true, 'incidencias': incidencias};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      }

      return {'success': false, 'error': 'Error al cargar incidencias'};
    } catch (e) {
      debugPrint('[INCIDENTE] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Obtener detalle.
  Future<Map<String, dynamic>> obtenerIncidencia(int idIncidente) async {
    try {
      debugPrint('[INCIDENTE] 📌 Cargando detalle #$idIncidente...');

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/incidencias/$idIncidente'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final incidente =
            IncidenteDetalle.fromJson(jsonDecode(response.body));
        return {'success': true, 'incidente': incidente};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Incidencia no encontrada'};
      }

      return {'success': false, 'error': 'Error al cargar incidencia'};
    } catch (e) {
      debugPrint('[INCIDENTE] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Evaluar servicio.
  Future<Map<String, dynamic>> evaluarServicio({
    required int idIncidente,
    required int estrellas,
    String? comentario,
  }) async {
    try {
      debugPrint('[INCIDENTE] ⭐ Evaluando servicio #$idIncidente...');

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final body = {
        'estrellas': estrellas,
        'comentario': comentario?.trim().isEmpty == true ? null : comentario,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/incidencias/$idIncidente/evaluar'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return {'success': true};
      }

      if (response.statusCode == 409) {
        return {
          'success': false,
          'error': 'Ya evaluaste este servicio',
          'code': 'ALREADY_RATED',
        };
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      }

      return {
        'success': false,
        'error': 'Error al enviar evaluación',
      };
    } catch (e) {
      debugPrint('[INCIDENTE] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Obtener la ubicación del técnico asignado.
  Future<Map<String, dynamic>> obtenerUbicacionTecnico(int idIncidente) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/incidencias/$idIncidente/tecnico-ubicacion'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': true,
          'data': data,
        };
      }

      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      }

      if (response.statusCode == 404) {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error': body['detail'] ?? 'Ubicación no disponible',
        };
      }

      return {
        'success': false,
        'error': 'Error al obtener ubicación del técnico',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Subir evidencia (imagen / audio).
  Future<Map<String, dynamic>> subirEvidencia({
    required int idIncidente,
    required int idTipoEvidencia,
    required File archivo,
  }) async {
    try {
      debugPrint('[EVIDENCIA] 📤 Subiendo archivo...');
      debugPrint('[EVIDENCIA] Incidente: $idIncidente, Tipo: $idTipoEvidencia');
      debugPrint('[EVIDENCIA] Ruta: ${archivo.path}');

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final uri = Uri.parse('$baseUrl/incidencias/$idIncidente/evidencias');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['id_tipo_evidencia'] = idTipoEvidencia.toString();
      request.files
          .add(await http.MultipartFile.fromPath('archivo', archivo.path));

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      debugPrint('[EVIDENCIA] Status: ${response.statusCode}');
      debugPrint('[EVIDENCIA] Body: ${response.body}');

      if (response.statusCode == 201) {
        final evidencia = Evidencia.fromJson(jsonDecode(response.body));
        debugPrint('[EVIDENCIA] ✅ Subida: #${evidencia.idEvidencia}');
        return {'success': true, 'evidencia': evidencia};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Incidente no encontrado'};
      }

      return {'success': false, 'error': 'Error ${response.statusCode}'};
    } on TimeoutException catch (_) {
      return {'success': false, 'error': 'Tiempo de conexión agotado (60s)'};
    } catch (e) {
      debugPrint('[EVIDENCIA] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Listar las evidencias de un incidente.
  Future<Map<String, dynamic>> listarEvidencias(int idIncidente) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/incidencias/$idIncidente/evidencias'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final evidencias =
            data.map((j) => Evidencia.fromJson(j)).toList();
        return {'success': true, 'evidencias': evidencias};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      }

      return {'success': false, 'error': 'Error al cargar evidencias'};
    } catch (e) {
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Analizar incidente con IA (Gemini).
  Future<Map<String, dynamic>> analizarConIA(int idIncidente) async {
    try {
      debugPrint('[IA] 🤖 Analizando incidente #$idIncidente...');

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/incidencias/$idIncidente/analizar-ia'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 45));

      debugPrint('[IA] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final incidente = IncidenteDetalle.fromJson(data);
        debugPrint('[IA] ✅ Análisis completado (confianza: '
            '${incidente.clasificacionIaConfianza})');
        return {'success': true, 'incidente': incidente};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Incidente no encontrado'};
      } else if (response.statusCode == 502) {
        return {
          'success': false,
          'error': 'Servicio de IA no disponible. Intenta más tarde.',
        };
      }

      return {'success': false, 'error': 'Error al analizar: ${response.statusCode}'};
    } on TimeoutException catch (_) {
      return {'success': false, 'error': 'IA tardó demasiado. Intenta de nuevo.'};
    } catch (e) {
      debugPrint('[IA] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Obtener la ubicación actual.
  Future<Map<String, double>?> obtenerUbicacionActual() async {
    try {
      debugPrint('[GPS] 📍 Solicitando ubicación...');

      final permiso = await _verificarPermisoGPS();
      if (!permiso) {
        debugPrint('[GPS] ❌ Permiso denegado');
        return null;
      }

      Position? posicion;

      try {
        posicion = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('[GPS] ⚠️ getCurrentPosition falló ($e), probando lastKnown...');
        posicion = await Geolocator.getLastKnownPosition();
      }

      if (posicion == null) {
        debugPrint('[GPS] ❌ Sin ubicación disponible');
        return null;
      }

      debugPrint('[GPS] ✅ ${posicion.latitude}, ${posicion.longitude}');
      return {
        'latitud': posicion.latitude,
        'longitud': posicion.longitude,
      };
    } catch (e) {
      debugPrint('[GPS] ❌ Exception: $e');
      return null;
    }
  }

  /// Verificar permisos de GPS.
  Future<bool> _verificarPermisoGPS() async {
    try {
      final habilitado = await Geolocator.isLocationServiceEnabled();
      if (!habilitado) {
        debugPrint('[GPS] ❌ Servicios de ubicación deshabilitados');
        return false;
      }

      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          return false;
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        debugPrint('[GPS] ❌ Permiso permanentemente denegado');
        return false;
      }

      debugPrint('[GPS] ✅ Permiso otorgado');
      return true;
    } catch (e) {
      debugPrint('[GPS] ❌ Error: $e');
      return false;
    }
  }

  /// Cancelar incidente.
  Future<Map<String, dynamic>> cancelarIncidente(int idIncidente) async {
    try {
      final token = await _getToken();
      if (token == null) return {'success': false, 'error': 'No autenticado'};

      final response = await http
          .patch(
            Uri.parse('$baseUrl/incidencias/$idIncidente/cancelar'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return {'success': true};
      } else if (response.statusCode == 400 || response.statusCode == 404) {
        final body = jsonDecode(response.body);
        return {'success': false, 'error': body['detail'] ?? 'No se pudo cancelar'};
      } else if (response.statusCode == 401) {
        return {'success': false, 'error': 'Sesión expirada', 'code': 'AUTH_EXPIRED'};
      }
      return {'success': false, 'error': 'Error ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  /// Cambiar el taller seleccionado.
  Future<Map<String, dynamic>> cambiarTaller({
    required int idIncidente,
    required int idCandidato,
  }) async {
    try {
      debugPrint('[TALLER] 🔄 Cambiando taller... Candidato: $idCandidato');

      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'error': 'No autenticado'};
      }

      final response = await http
          .put(
            Uri.parse('$baseUrl/incidencias/$idIncidente/cambiar-taller'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'id_candidato': idCandidato}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[TALLER] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('[TALLER] ✅ Taller cambiado correctamente');
        return {'success': true, 'message': 'Taller actualizado'};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Sesión expirada',
          'code': 'AUTH_EXPIRED',
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'error': 'Incidente o candidato no encontrado'};
      }

      return {'success': false, 'error': 'Error al cambiar taller'};
    } catch (e) {
      debugPrint('[TALLER] ❌ Exception: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }
}
