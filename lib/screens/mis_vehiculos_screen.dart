import 'package:flutter/material.dart';
import '../services/vehiculo_service.dart';
import 'registrar_vehiculo_screen.dart';
import 'editar_vehiculo_screen.dart';

class MisVehiculosScreen extends StatefulWidget {
  @override
  State<MisVehiculosScreen> createState() => _MisVehiculosScreenState();
}

class _MisVehiculosScreenState extends State<MisVehiculosScreen> {
  final vehiculoService = VehiculoService();
  
  List<dynamic> vehiculos = [];
  bool cargando = true;
  String? error;
  
  @override
  void initState() {
    super.initState();
    cargarVehiculos();
  }
  
  void cargarVehiculos() async {
    setState(() => cargando = true);
    
    final resultado = await vehiculoService.listarMisVehiculos();
    
    if (resultado['success']) {
      setState(() {
        vehiculos = resultado['vehiculos'] ?? [];
        error = null;
      });
    } else {
      setState(() => error = resultado['error']);
      
      // Si el error es de autenticación expirada, redirigir a login
      if (resultado['code'] == 'AUTH_EXPIRED') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sesión expirada. Debes iniciar sesión nuevamente.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }
    }
    
    setState(() => cargando = false);
  }
  
  void irRegistrar() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegistrarVehiculoScreen()),
    );
    
    if (resultado != null) {
      cargarVehiculos(); // Recargar lista
    }
  }

  void irEditar(Map<String, dynamic> vehiculo) async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarVehiculoScreen(vehiculo: vehiculo),
      ),
    );
    
    if (resultado != null) {
      cargarVehiculos(); // Recargar lista
    }
  }
  
  void eliminarVehiculo(int idVehiculo, String placa) async {
    final confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar Vehículo'),
        content: Text('¿Deseas dar de baja el vehículo $placa?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Eliminar')),
        ],
      ),
    );
    
    if (confirmar == true) {
      final resultado = await vehiculoService.eliminarVehiculo(idVehiculo);
      
      if (resultado['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Vehículo eliminado'), backgroundColor: Colors.green),
        );
        cargarVehiculos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${resultado['error']}'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mis Vehículos'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: cargarVehiculos,
          )
        ],
      ),
      body: cargando
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(error!),
                      SizedBox(height: 16),
                      ElevatedButton(onPressed: cargarVehiculos, child: Text('Reintentar')),
                    ],
                  ),
                )
              : vehiculos.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_filled, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No tienes vehículos registrados'),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: irRegistrar,
                            child: Text('Registrar Primer Vehículo'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: vehiculos.length,
                      itemBuilder: (context, index) {
                        final vehiculo = vehiculos[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(Icons.directions_car, color: Colors.blue),
                            title: Text(vehiculo['placa'], style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${vehiculo['marca']} ${vehiculo['modelo']} (${vehiculo['anio']})'),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Text('Editar'),
                                  onTap: () => irEditar(vehiculo),
                                ),
                                PopupMenuItem(
                                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                  onTap: () => eliminarVehiculo(vehiculo['id_vehiculo'], vehiculo['placa']),
                                ),
                              ],
                            ),
                            onTap: () => irEditar(vehiculo),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: irRegistrar,
        child: Icon(Icons.add),
        tooltip: 'Registrar Nuevo Vehículo',
      ),
    );
  }
}
