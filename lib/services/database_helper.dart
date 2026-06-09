import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/producto_model.dart';

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

    return await openDatabase(path, version: 3, onCreate: _createDB, onUpgrade: _onUpgrade);
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
        stock INTEGER DEFAULT 0,
        marca TEXT,
        unidad_medida TEXT,
        iva REAL DEFAULT 0.0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE productos ADD COLUMN marca TEXT');
      await db.execute('ALTER TABLE productos ADD COLUMN unidad_medida TEXT');
      await db.execute('ALTER TABLE productos ADD COLUMN iva REAL DEFAULT 0.0');
    }
  }

  Future<int> addProducto(Map<String, dynamic> producto) async {
    final db = await database;
    return await db.insert('productos', producto);
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final db = await database;
    return await db.query('productos');
  }

  Future<int> updateStock(String codigo, int cantidad) async {
    final db = await database;
    return await db.rawUpdate(
      'UPDATE productos SET stock = stock + ? WHERE codigo = ?',
      [cantidad, codigo],
    );
  }

  Future<int> updateProducto(Map<String, dynamic> producto) async {
    final db = await database;
    return await db.update(
      'productos',
      producto,
      where: 'id = ?',
      whereArgs: [producto['id']],
    );
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return await db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Producto?> getProductoByCodigo(String codigo) async {
    final db = await database;
    return await db.query(
      'productos',
      where: 'codigo = ?',
      whereArgs: [codigo],
    ).then((result) {
      if (result.isNotEmpty) {
        return Producto.fromMap(result.first);
      }
      return null;
    });
  }
}
