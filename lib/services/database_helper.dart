import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/producto_model.dart';
import '../models/venta_model.dart';
import '../models/venta_detalle.dart';
import '../models/carrito_item.dart';

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

    return await openDatabase(path, version: 4, onCreate: _createDB, onUpgrade: _onUpgrade);
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
    await _createVentasTables(db);
  }

  Future<void> _createVentasTables(Database db) async {
    await db.execute('''
      CREATE TABLE ventas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        total REAL,
        fecha TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE venta_detalles(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id INTEGER,
        producto_id INTEGER,
        nombre TEXT,
        codigo TEXT,
        precio_unitario REAL,
        cantidad INTEGER,
        subtotal REAL,
        FOREIGN KEY (venta_id) REFERENCES ventas(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE productos ADD COLUMN marca TEXT');
      await db.execute('ALTER TABLE productos ADD COLUMN unidad_medida TEXT');
      await db.execute('ALTER TABLE productos ADD COLUMN iva REAL DEFAULT 0.0');
    }
    if (oldVersion < 4) {
      await _createVentasTables(db);
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

  Future<void> addVenta(double total, List<CarritoItem> items) async {
    final db = await database;
    final fecha = DateTime.now().toIso8601String();

    final ventaId = await db.insert('ventas', {
      'total': total,
      'fecha': fecha,
    });

    for (var item in items) {
      await db.insert('venta_detalles', {
        'venta_id': ventaId,
        'producto_id': item.producto.id,
        'nombre': item.producto.nombre,
        'codigo': item.producto.codigo,
        'precio_unitario': item.producto.precio,
        'cantidad': item.cantidad,
        'subtotal': item.subtotal,
      });
    }
  }

  Future<List<Venta>> getVentas() async {
    final db = await database;
    final result = await db.query('ventas', orderBy: 'fecha DESC');
    return result.map((e) => Venta.fromMap(e)).toList();
  }

  Future<List<VentaDetalle>> getVentaDetalles(int ventaId) async {
    final db = await database;
    final result = await db.query(
      'venta_detalles',
      where: 'venta_id = ?',
      whereArgs: [ventaId],
    );
    return result.map((e) => VentaDetalle.fromMap(e)).toList();
  }
}
