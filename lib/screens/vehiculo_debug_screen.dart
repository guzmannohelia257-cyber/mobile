import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/vehiculo_service.dart';

/// Pantalla de depuración para verificar el estado de autenticación y el token
class VehiculoDebugScreen extends StatefulWidget {
  @override
  State<VehiculoDebugScreen> createState() => _VehiculoDebugScreenState();
}

class _VehiculoDebugScreenState extends State<VehiculoDebugScreen> {
  final authService = AuthService();
  final vehiculoService = VehiculoService();
  
  String? token;
  String? userId;
  String? userRole;
  String? userName;
  bool isLoading = false;
  String testResult = '';

  @override
  void initState() {
    super.initState();
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    setState(() => isLoading = true);
    
    final t = await authService.getToken();
    final id = await authService.getUserId();
    final role = await authService.getUserRole();
    final name = await authService.getUserName();
    
    setState(() {
      token = t;
      userId = id;
      userRole = role;
      userName = name;
      isLoading = false;
    });
  }

  Future<void> _testVehiculos() async {
    setState(() => isLoading = true);
    
    // Mostrar datos guardados
    await vehiculoService.debugShowAllPreferences();
    
    // Intentar listar vehículos
    final resultado = await vehiculoService.listarMisVehiculos();
    
    setState(() {
      testResult = resultado['success'] 
          ? '✅ OK - ${resultado['vehiculos']?.length ?? 0} vehículos'
          : '❌ ERROR - ${resultado['error']}';
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🐛 DEBUG - Vehículos'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de información de autenticación
            _buildSection(
              'ℹ️ Información de Autenticación',
              [
                _buildInfoRow('Token', token != null ? '✅ ${token!.substring(0, 30)}...' : '❌ NULL'),
                _buildInfoRow('User ID', userId ?? '❌ NULL'),
                _buildInfoRow('User Role', userRole ?? '❌ NULL'),
                _buildInfoRow('User Name', userName ?? '❌ NULL'),
              ],
            ),
            SizedBox(height: 20),

            // Sección de prueba de vehículos
            _buildSection(
              '🧪 Test de Vehículos',
              [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _testVehiculos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : Text('Probar GET /vehiculos/mis-autos'),
                  ),
                ),
                if (testResult.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: testResult.startsWith('✅') ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: testResult.startsWith('✅') ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      testResult,
                      style: TextStyle(
                        color: testResult.startsWith('✅') ? Colors.green.shade700 : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 20),

            // Sección de acciones
            _buildSection(
              '🔧 Acciones',
              [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadAuthData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: Text('Recargar Datos'),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await vehiculoService.debugShowAllPreferences();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ver logs en consola')),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                    child: Text('Mostrar Preferencias (logs)'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Sección de instrucciones
            _buildSection(
              '📋 Instrucciones',
              [
                Text(
                  '1. Verifica que "Token" no sea NULL\n'
                  '2. Si es NULL, probablemente no iniciaste sesión\n'
                  '3. Presiona "Probar GET /vehiculos/mis-autos"\n'
                  '4. Revisa los logs en la consola de Flutter\n'
                  '5. Si ves ERROR 401, el token es inválido\n'
                  '\n'
                  '🔍 Los logs detallados aparecen en:\n'
                  'Android Studio → Logcat\n'
                  'VS Code → Debug Console',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: value.startsWith('✅') ? Colors.green : (value.startsWith('❌') ? Colors.red : Colors.grey.shade700),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
