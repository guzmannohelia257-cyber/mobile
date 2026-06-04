import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'local_db.dart';

/// Evidencia capturada localmente (aun no subida) persistida para reanudar.
class WizardEvidencia {
  final String ruta;
  final int tipo; // 1=imagen, 2=audio

  const WizardEvidencia(this.ruta, this.tipo);

  Map<String, dynamic> toJson() => {'ruta': ruta, 'tipo': tipo};

  factory WizardEvidencia.fromJson(Map<String, dynamic> j) =>
      WizardEvidencia(j['ruta'] as String, (j['tipo'] as num).toInt());
}

/// Progreso del asistente de "reportar emergencia", para reanudar donde quedo.
///
/// paso: 1 = formulario, 2 = evidencias, 3 = seleccionar taller.
class WizardDraft {
  final int paso;
  final int? idVehiculo;
  final String? descripcion;
  final double? latitud;
  final double? longitud;
  final String? ubicacionTexto;
  final int? idIncidente;
  final String? idempotencyKey;
  final int? categoriaId;
  final List<WizardEvidencia> evidencias;

  const WizardDraft({
    required this.paso,
    this.idVehiculo,
    this.descripcion,
    this.latitud,
    this.longitud,
    this.ubicacionTexto,
    this.idIncidente,
    this.idempotencyKey,
    this.categoriaId,
    this.evidencias = const [],
  });
}

/// Guarda/lee/borra un unico reporte en curso (fila id=1) en SQLite.
class WizardDraftService {
  static final WizardDraftService _instance = WizardDraftService._();
  factory WizardDraftService() => _instance;
  WizardDraftService._();

  static const int _rowId = 1; // un solo reporte a la vez

  Future<void> guardar(WizardDraft d) async {
    try {
      final db = await LocalDB.instance;
      await db.insert(
        'wizard_draft',
        {
          'id': _rowId,
          'paso': d.paso,
          'id_vehiculo': d.idVehiculo,
          'descripcion': d.descripcion,
          'latitud': d.latitud,
          'longitud': d.longitud,
          'ubicacion_texto': d.ubicacionTexto,
          'id_incidente': d.idIncidente,
          'idempotency_key': d.idempotencyKey,
          'categoria_id': d.categoriaId,
          'evidencias_json':
              jsonEncode(d.evidencias.map((e) => e.toJson()).toList()),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Persistir el progreso nunca debe romper el flujo de reporte.
    }
  }

  Future<WizardDraft?> cargar() async {
    try {
      final db = await LocalDB.instance;
      final rows = await db.query(
        'wizard_draft',
        where: 'id = ?',
        whereArgs: [_rowId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final r = rows.first;

      final evidencias = <WizardEvidencia>[];
      final evJson = r['evidencias_json'] as String?;
      if (evJson != null && evJson.isNotEmpty) {
        for (final e in jsonDecode(evJson) as List) {
          evidencias
              .add(WizardEvidencia.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      }

      return WizardDraft(
        paso: (r['paso'] as num).toInt(),
        idVehiculo: (r['id_vehiculo'] as num?)?.toInt(),
        descripcion: r['descripcion'] as String?,
        latitud: (r['latitud'] as num?)?.toDouble(),
        longitud: (r['longitud'] as num?)?.toDouble(),
        ubicacionTexto: r['ubicacion_texto'] as String?,
        idIncidente: (r['id_incidente'] as num?)?.toInt(),
        idempotencyKey: r['idempotency_key'] as String?,
        categoriaId: (r['categoria_id'] as num?)?.toInt(),
        evidencias: evidencias,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar() async {
    try {
      final db = await LocalDB.instance;
      await db.delete('wizard_draft', where: 'id = ?', whereArgs: [_rowId]);
    } catch (_) {}
  }
}
