import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLogger {
  static const String _tag = 'APP_LOGGER';
  static final DateFormat _dateFormat = DateFormat('HH:mm:ss.SSS');
  
  // Colores ANSI para terminal
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _cyan = '\x1B[36m';
  static const String _magenta = '\x1B[35m';

  /// Log crítico para errores importantes
  static void error(String message, {String? tag, dynamic error, StackTrace? stackTrace}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] ❌ ERROR [$logTag]: $message';
    
    debugPrint('$_red$fullMessage$_reset');
    
    if (error != null) {
      debugPrint('$_red   Error: $error$_reset');
    }
    
    if (stackTrace != null) {
      debugPrint('$_red   StackTrace: $stackTrace$_reset');
    }
  }

  /// Log de éxito
  static void success(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] ✅ SUCCESS [$logTag]: $message';
    
    debugPrint('$_green$fullMessage$_reset');
  }

  /// Log de información
  static void info(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] ℹ️  INFO [$logTag]: $message';
    
    debugPrint('$_blue$fullMessage$_reset');
  }

  /// Log de advertencia
  static void warning(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] ⚠️  WARNING [$logTag]: $message';
    
    debugPrint('$_yellow$fullMessage$_reset');
  }

  /// Log de debug
  static void debug(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] 🔍 DEBUG [$logTag]: $message';
    
    debugPrint('$_cyan$fullMessage$_reset');
  }

  /// Log de red/HTTP
  static void network(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] 📡 NETWORK [$logTag]: $message';
    
    debugPrint('$_magenta$fullMessage$_reset');
  }

  /// Log detallado de respuesta HTTP
  static void httpResponse(
    String method,
    String url,
    int statusCode, {
    String? tag,
    String? body,
    Map<String, String>? headers,
    Duration? duration,
  }) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    
    final logMessage = '''
[$timestamp] 📡 HTTP_RESPONSE [$logTag]:
  → Method: $method
  → URL: $url
  → Status: $statusCode$durationStr
  ${headers != null ? '→ Headers: ${headers.toString()}' : ''}
  ${body != null ? '→ Body: $body' : ''}
''';
    
    debugPrint('$_magenta$logMessage$_reset');
  }

  /// Log detallado de solicitud HTTP
  static void httpRequest(
    String method,
    String url, {
    String? tag,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    
    final logMessage = '''
[$timestamp] 📤 HTTP_REQUEST [$logTag]:
  → Method: $method
  → URL: $url
  ${headers != null ? '→ Headers: $headers' : ''}
  ${body != null ? '→ Body: $body' : ''}
''';
    
    debugPrint('$_magenta$logMessage$_reset');
  }

  /// Log de autenticación
  static void auth(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] 🔐 AUTH [$logTag]: $message';
    
    debugPrint('$_green$fullMessage$_reset');
  }

  /// Log de almacenamiento
  static void storage(String message, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] 💾 STORAGE [$logTag]: $message';
    
    debugPrint('$_cyan$fullMessage$_reset');
  }

  /// Log separador para secciones
  static void separator({String? title}) {
    if (title != null) {
      debugPrint('$_blue═════════════════════════════════════════$_reset');
      debugPrint('$_blue  $title$_reset');
      debugPrint('$_blue═════════════════════════════════════════$_reset');
    } else {
      debugPrint('$_blue───────────────────────────────────────────$_reset');
    }
  }

  /// Log con tabla de datos
  static void table(String title, Map<String, String> data, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    
    debugPrint('$_cyan[$timestamp] 📊 TABLE [$logTag]: $title$_reset');
    
    for (var entry in data.entries) {
      debugPrint('$_cyan   ${entry.key}: ${entry.value}$_reset');
    }
  }

  /// Log de tiempo de ejecución
  static void timing(String operation, Duration duration, {String? tag}) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logTag = tag ?? _tag;
    final fullMessage = '[$timestamp] ⏱️  TIMING [$logTag]: $operation took ${duration.inMilliseconds}ms';
    
    debugPrint('$_magenta$fullMessage$_reset');
  }
}
