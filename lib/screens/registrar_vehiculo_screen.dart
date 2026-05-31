import 'package:flutter/material.dart';
import '../services/vehiculo_service.dart';

class RegistrarVehiculoScreen extends StatefulWidget {
  @override
  State<RegistrarVehiculoScreen> createState() => _RegistrarVehiculoScreenState();
}

class _RegistrarVehiculoScreenState extends State<RegistrarVehiculoScreen> {
  final vehiculoService = VehiculoService();
  
  late TextEditingController placaController;
  late TextEditingController marcaController;
  late TextEditingController modeloController;
  late TextEditingController anioController;
  late TextEditingController colorController;
  
  bool cargando = false;
  String? error;
  
  @override
  void initState() {
    super.initState();
    placaController = TextEditingController();
    marcaController = TextEditingController();
    modeloController = TextEditingController();
    anioController = TextEditingController();
    colorController = TextEditingController();
  }
  
  void registrarVehiculo() async {
    // Validar placa obligatoria
    if (placaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La placa es obligatoria'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => cargando = true);
    
    final resultado = await vehiculoService.registrarVehiculo(
      placa: placaController.text.toUpperCase(),
      marca: marcaController.text.isEmpty ? null : marcaController.text,
      modelo: modeloController.text.isEmpty ? null : modeloController.text,
      anio: anioController.text.isEmpty ? null : int.tryParse(anioController.text),
      color: colorController.text.isEmpty ? null : colorController.text,
    );
    
    setState(() => cargando = false);
    
    if (resultado['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Vehículo registrado correctamente'), backgroundColor: Colors.green),
      );
      // Limpiar formulario
      placaController.clear();
      marcaController.clear();
      modeloController.clear();
      anioController.clear();
      colorController.clear();
      setState(() => error = null);
      
      // Volver a pantalla anterior
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pop(context, resultado['vehiculo']);
      });
    } else {
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
      } else {
        setState(() => error = resultado['error']);
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
        title: Text('Registrar Vehículo'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(error!, style: TextStyle(color: Colors.red.shade700)),
              ),
            
            // Placa (obligatoria)
            Text('Placa del Vehículo *', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: placaController,
              decoration: InputDecoration(
                hintText: 'Ej: ABC-1234',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            SizedBox(height: 20),
            
            Text('Marca', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: marcaController,
              decoration: InputDecoration(
                hintText: 'Ej: Toyota',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_offer),
              ),
            ),
            SizedBox(height: 20),
            
            Text('Modelo', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: modeloController,
              decoration: InputDecoration(
                hintText: 'Ej: Corolla',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_car_filled),
              ),
            ),
            SizedBox(height: 20),
            
            Text('Año', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: anioController,
              decoration: InputDecoration(
                hintText: 'Ej: 2022',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            
            Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: colorController,
              decoration: InputDecoration(
                hintText: 'Ej: Blanco',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.palette),
              ),
            ),
            SizedBox(height: 30),
            
            // Botón Registrar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cargando ? null : registrarVehiculo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: cargando
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Text(
                        'Registrar Vehículo',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    placaController.dispose();
    marcaController.dispose();
    modeloController.dispose();
    anioController.dispose();
    colorController.dispose();
    super.dispose();
  }
}
