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

    return await openDatabase(
        path, version: 6, onCreate: _createDB, onUpgrade: _onUpgrade);
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
        stock REAL DEFAULT 0.0,
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
        fecha TEXT,
        estado TEXT DEFAULT 'completada'
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
        cantidad REAL,
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
    if (oldVersion < 5) {
      await db.execute(
          "ALTER TABLE ventas ADD COLUMN estado TEXT DEFAULT 'completada'");
    }
    if (oldVersion < 6) {
      await db.execute(
          "ALTER TABLE venta_detalles ADD COLUMN unidad_medida TEXT");
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

  Future<int> updateStock(String codigo, double cantidad) async {
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
      'estado': 'completada',
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
        'unidad_medida': item.producto.unidadMedida,
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

  Future<void> anularVenta(int ventaId) async {
    final db = await database;
    final detalles = await getVentaDetalles(ventaId);

    for (var d in detalles) {
      await db.rawUpdate(
        'UPDATE productos SET stock = stock + ? WHERE codigo = ?',
        [d.cantidad, d.codigo],
      );
    }

    await db.update(
      'ventas',
      {'estado': 'anulada'},
      where: 'id = ?',
      whereArgs: [ventaId],
    );
  }

  Future<Map<String, dynamic>> getResumenVentas() async {
    final db = await database;
    final now = DateTime.now();

    final inicioHoy = DateTime(now.year, now.month, now.day);
    final inicioSemana =
        now.subtract(Duration(days: now.weekday - 1));
    final inicioSemanaDate =
        DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
    final inicioMes = DateTime(now.year, now.month, 1);

    final resumen = <String, dynamic>{};

    final periodos = [
      {'label': 'hoy', 'inicio': inicioHoy},
      {'label': 'semana', 'inicio': inicioSemanaDate},
      {'label': 'mes', 'inicio': inicioMes},
    ];

    for (final entry in periodos) {
      final inicio = entry['inicio'] as DateTime;
      final iso = inicio.toIso8601String();

      final resultVentas = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) as total
        FROM ventas
        WHERE fecha >= ? AND estado = 'completada'
      ''', [iso]);

      final resultCantidad = await db.rawQuery('''
        SELECT COALESCE(SUM(vd.cantidad), 0) as cantidad
        FROM venta_detalles vd
        JOIN ventas v ON vd.venta_id = v.id
        WHERE v.fecha >= ? AND v.estado = 'completada'
      ''', [iso]);

      final rawTotal = resultVentas.first['total'];
      resumen['total_${entry['label']}'] = (rawTotal is num ? rawTotal.toDouble() : 0.0);
      resumen['cantidad_${entry['label']}'] = resultCantidad.first['cantidad'] ?? 0;
    }

    final masVendido = await db.rawQuery('''
      SELECT vd.nombre, SUM(vd.cantidad) as total_cantidad
      FROM venta_detalles vd
      JOIN ventas v ON vd.venta_id = v.id
      WHERE v.estado = 'completada'
      GROUP BY vd.producto_id
      ORDER BY total_cantidad DESC
      LIMIT 1
    ''');

    if (masVendido.isNotEmpty && masVendido.first['nombre'] != null) {
      resumen['producto_top'] = masVendido.first['nombre'];
      resumen['producto_top_cantidad'] = masVendido.first['total_cantidad'];
    } else {
      resumen['producto_top'] = null;
      resumen['producto_top_cantidad'] = 0;
    }

    return resumen;
  }
}
