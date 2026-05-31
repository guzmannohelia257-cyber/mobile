class TecnicoLoginResponse {
  final String accessToken;
  final String tokenType;
  final UsuarioTecnicoData usuario;

  TecnicoLoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.usuario,
  });

  factory TecnicoLoginResponse.fromJson(Map<String, dynamic> json) {
    return TecnicoLoginResponse(
      accessToken: (json['access_token'] ?? '') as String,
      tokenType: (json['token_type'] ?? 'bearer') as String,
      usuario: UsuarioTecnicoData.fromJson(
        (json['usuario'] ?? <String, dynamic>{}) as Map<String, dynamic>,
      ),
    );
  }
}

class UsuarioTecnicoData {
  final int idUsuario;
  final int idRol;
  final String nombre;
  final String email;
  final String? telefono;
  final bool activo;

  UsuarioTecnicoData({
    required this.idUsuario,
    required this.idRol,
    required this.nombre,
    required this.email,
    this.telefono,
    required this.activo,
  });

  factory UsuarioTecnicoData.fromJson(Map<String, dynamic> json) {
    return UsuarioTecnicoData(
      idUsuario: (json['id_usuario'] ?? 0) as int,
      idRol: (json['id_rol'] ?? 0) as int,
      nombre: (json['nombre'] ?? 'Tecnico') as String,
      email: (json['email'] ?? '') as String,
      telefono: json['telefono'] as String?,
      activo: (json['activo'] ?? true) as bool,
    );
  }
}
