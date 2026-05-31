import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDB {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'flujo_emergencia.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
    return _db!;
  }

  static Future<void> _onCreate(Database db, int v) async {
    await db.execute('''
      CREATE TABLE incidentes (
        id_incidente INTEGER PRIMARY KEY,
        client_id TEXT,
        id_categoria INTEGER,
        descripcion_usuario TEXT,
        resumen_ia TEXT,
        latitud REAL NOT NULL,
        longitud REAL NOT NULL,
        estado_nombre TEXT,
        created_at TEXT NOT NULL,
        cached_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE vehiculos (
        id_vehiculo INTEGER PRIMARY KEY,
        placa TEXT NOT NULL,
        marca TEXT,
        modelo TEXT,
        anio INTEGER,
        color TEXT,
        cached_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL UNIQUE,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        body_json TEXT,
        files_paths TEXT,
        token TEXT,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('CREATE INDEX ix_outbox_created ON outbox(created_at);');
    await db.execute('CREATE INDEX ix_incidentes_created ON incidentes(created_at);');
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
