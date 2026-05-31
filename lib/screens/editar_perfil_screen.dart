import 'package:flutter/material.dart';
import '../services/usuario_service.dart';

class EditarPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> usuarioInicial;
  
  const EditarPerfilScreen({required this.usuarioInicial});
  
  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final usuarioService = UsuarioService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nombreController;
  late TextEditingController _emailController;
  late TextEditingController _telefonoController;
  
  bool guardando = false;
  String? errorGeneral;
  
  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.usuarioInicial['nombre'] ?? ''
    );
    _emailController = TextEditingController(
      text: widget.usuarioInicial['email'] ?? ''
    );
    _telefonoController = TextEditingController(
      text: widget.usuarioInicial['telefono'] ?? ''
    );
  }
  
  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }
  
  void guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      guardando = true;
      errorGeneral = null;
    });
    
    final resultado = await usuarioService.actualizarPerfil(
      nombre: _nombreController.text.trim(),
      email: _emailController.text.trim(),
      telefono: _telefonoController.text.trim().isEmpty 
        ? null 
        : _telefonoController.text.trim(),
    );
    
    if (!mounted) return;
    
    if (resultado['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Perfil actualizado exitosamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
      Future.delayed(Duration(seconds: 1), () {
        Navigator.pop(context, resultado['usuario']);
      });
    } else {
      setState(() => errorGeneral = resultado['error']);
      
      if (resultado['code'] == 'AUTH_EXPIRED') {
        Future.delayed(Duration(seconds: 2), () {
          Navigator.of(context).pushReplacementNamed('/login');
        });
      }
    }
    
    setState(() => guardando = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Perfil'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error general
              if (errorGeneral != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorGeneral!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
              
              // Campo Nombre
              Text(
                'Nombre Completo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  hintText: 'Tu nombre completo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ingresa tu nombre';
                  if (value!.length < 3) return 'Mínimo 3 caracteres';
                  return null;
                },
                enabled: !guardando,
              ),
              SizedBox(height: 20),
              
              // Campo Email
              Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'tu@email.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Ingresa tu email';
                  if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                      .hasMatch(value!)) {
                    return 'Email inválido';
                  }
                  return null;
                },
                enabled: !guardando,
              ),
              SizedBox(height: 20),
              
              // Campo Teléfono
              Text(
                'Teléfono (Opcional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+57 3001234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (value.length < 7) {
                      return 'Teléfono muy corto (mínimo 7 caracteres)';
                    }
                  }
                  return null;
                },
                enabled: !guardando,
              ),
              SizedBox(height: 32),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: guardando ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: guardando ? null : guardarCambios,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: guardando
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              'Guardar Cambios',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
