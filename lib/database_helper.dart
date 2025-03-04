import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('productos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE productos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        codigo TEXT UNIQUE,
        categoria TEXT,
        precio REAL,
        peso REAL,
      )
    ''');
  }

  Future<int> addProducto(Map<String, dynamic> producto) async {
    final db = await database;
    return await db.insert('productos', producto);
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final db = await database;
    return await db.query('productos');
  }
}
