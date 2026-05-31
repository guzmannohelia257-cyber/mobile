import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Utilidad de debug para verificar el estado de la aplicación
class DebugHelper {
  static Future<void> printAppState() async {
    try {
      debugPrint('\n═════════════════════════════════════════');
      debugPrint('📱 DEBUG: Estado de la Aplicación');
      debugPrint('═════════════════════════════════════════');

      final prefs = await SharedPreferences.getInstance();

      final hasToken = prefs.containsKey('access_token');
      final token = prefs.getString('access_token');
      final userRole = prefs.getString('user_rol');
      final userName = prefs.getString('user_name');
      final userEmail = prefs.getString('user_email');

      debugPrint('✅ SharedPreferences accesible');
      debugPrint('─────────────────────────────────────');
      debugPrint('🔐 Token guardado: $hasToken');
      if (hasToken) {
        debugPrint('   Token: ${token?.substring(0, 20)}...');
      }
      debugPrint('👤 Usuario: $userName ($userEmail)');
      debugPrint('📋 Rol: $userRole');
      debugPrint('─────────────────────────────────────');
      debugPrint('═════════════════════════════════════════\n');
    } catch (e) {
      debugPrint('❌ Error en DEBUG: $e');
    }
  }

  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('🧹 Todos los datos han sido limpios');
    } catch (e) {
      debugPrint('❌ Error al limpiar datos: $e');
    }
  }
}
