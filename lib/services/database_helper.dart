import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../data/categorias.dart';
import '../models/carrito_item.dart';
import '../models/producto_model.dart';
import '../models/venta_detalle.dart';
import '../models/venta_model.dart';
import '../utils/precios.dart';

/// Error de una operacion sobre el catalogo de categorias.
///
/// Se lanza, y no se devuelve como `null`, cuando el mensaje importa para el
/// usuario: renombrar "Lacteos" a "Quesos" cuando "Quesos" ya existe tiene que
/// decirselo, no fallar en silencio.
class EstadoCategoriaException implements Exception {
  final String mensaje;

  const EstadoCategoriaException(this.mensaje);

  @override
  String toString() => mensaje;
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  /// Ruta o nombre del archivo de base de datos.
  ///
  /// Solo se sobreescribe desde las pruebas para usar una base en memoria
  /// (`:memory:`). En la app siempre es `productos.db`.
  static String databasePath = 'productos.db';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(databasePath);
    return _database!;
  }

  /// Cierra la base de datos en cache. Util para reiniciar entre pruebas.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> _initDB(String filePath) async {
    final path = filePath == ':memory:'
        ? inMemoryDatabasePath
        : join(await getDatabasesPath(), filePath);

    return openDatabase(
      path,
      version: 9,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE productos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        codigo TEXT UNIQUE,
        categoria TEXT,
        precio REAL,
        costo REAL DEFAULT 0.0,
        peso REAL,
        stock REAL DEFAULT 0.0,
        marca TEXT,
        unidad_medida TEXT,
        unidad_venta TEXT,
        iva REAL DEFAULT 0.0,
        venta_por_peso INTEGER DEFAULT 0
      )
    ''');
    await _createMarcas(db);
    await _createCategorias(db);
    await _createVentasTables(db);
  }

  /// Categorias registradas, para administrarlas desde el menu lateral.
  ///
  /// Mismo criterio que `marcas`: `productos.categoria` sigue siendo TEXT para
  /// que un producto escrito a mano no dependa de que exista la fila. La tabla
  /// es el catalogo: alimenta el autocompletado del formulario y permite
  /// renombrar o borrar una categoria sin recorrer todos los productos.
  Future<void> _createCategorias(Database db) async {
    await db.execute('''
      CREATE TABLE categorias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        created_at TEXT
      )
    ''');
  }

  /// Marcas registradas, para el selector con creacion en linea.
  ///
  /// `productos.marca` sigue siendo TEXT a proposito: asi un producto escrito a
  /// mano con "Alfa" no depende de que exista la fila. Esta tabla solo alimenta
  /// el autocompletado y permite no escribir la marca dos veces.
  Future<void> _createMarcas(Database db) async {
    await db.execute('''
      CREATE TABLE marcas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        created_at TEXT
      )
    ''');
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
    // Las columnas deben coincidir con las de _onUpgrade (v4 -> v8), si no
    // una instalacion nueva fallaria al registrar la primera venta.
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
        unidad_medida TEXT,
        unidad_venta TEXT,
        venta_por_peso INTEGER DEFAULT 0,
        iva REAL DEFAULT 0.0,
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
      await db
          .execute("ALTER TABLE venta_detalles ADD COLUMN unidad_medida TEXT");
    }
    if (oldVersion < 7) {
      await db.execute(
          "ALTER TABLE productos ADD COLUMN venta_por_peso INTEGER DEFAULT 0");
      await db.execute(
          "ALTER TABLE venta_detalles ADD COLUMN venta_por_peso INTEGER DEFAULT 0");
    }
    if (oldVersion < 8) {
      // v8: costo de compra, unidad de venta y tasa de IVA por linea.
      //
      // - `costo`: para saber cuanto se gano por unidad.
      // - `unidad_venta`: el precio puede estar en una unidad (lb) y la balanza
      //   leer otra (g). Antes no habia forma de expresar esa diferencia.
      // - `iva`: el precio ya incluye impuesto, asi que se guarda la tasa para
      //   poder reportar cuanto contenia cada venta sin tocar el total cobrado.
      //
      // Los productos ya existentes se quedan con costo 0 (ganancia
      // desconocida) y con `unidad_venta` en NULL, que se interpreta como
      // "misma unidad que el precio".
      await db
          .execute("ALTER TABLE productos ADD COLUMN costo REAL DEFAULT 0.0");
      await db.execute("ALTER TABLE productos ADD COLUMN unidad_venta TEXT");
      await db.execute(
          "ALTER TABLE venta_detalles ADD COLUMN iva REAL DEFAULT 0.0");
      await db
          .execute("ALTER TABLE venta_detalles ADD COLUMN unidad_venta TEXT");
      await _createMarcas(db);
    }
    if (oldVersion < 9) {
      // v9: catalogo de categorias administrable.
      //
      // Se crea la tabla vacia a proposito: `sincronizarCategoriasDesdeProductos`
      // la llena con lo que ya existe en `productos.categoria`, de modo que los
      // productos viejos no quedan con una categoria huerfana que el usuario no
      // ve en el menu lateral.
      await _createCategorias(db);
    }
  }

  Future<int> addProducto(Map<String, dynamic> producto) async {
    final db = await database;
    return db.insert('productos', producto);
  }

  Future<List<Map<String, dynamic>>> getProductos() async {
    final db = await database;
    return db.query('productos');
  }

  /// Aplica un delta al stock del producto, sumando si es positivo y restando
  /// si es negativo (por ejemplo al cobrar una venta).
  Future<int> updateStock(String? codigo, double cantidad, {int? id}) async {
    final db = await database;
    final where =
        (codigo != null && codigo.isNotEmpty) ? 'codigo = ?' : 'id = ?';
    final argumento = (codigo != null && codigo.isNotEmpty) ? codigo : id;

    return db.rawUpdate(
      'UPDATE productos SET stock = stock + ? WHERE $where',
      [cantidad, argumento],
    );
  }

  Future<int> updateProducto(Map<String, dynamic> producto) async {
    final db = await database;
    return db.update(
      'productos',
      producto,
      where: 'id = ?',
      whereArgs: [producto['id']],
    );
  }

  Future<int> deleteProducto(int id) async {
    final db = await database;
    return db.delete(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Producto?> getProductoByCodigo(String codigo) async {
    if (codigo.isEmpty) return null;
    final db = await database;
    return db.query(
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

  Future<List<Producto>> searchProductos(String query) async {
    final db = await database;
    final term = '%$query%';
    final result = await db.query(
      'productos',
      where: 'nombre LIKE ? OR codigo LIKE ?',
      whereArgs: [term, term],
      orderBy: 'nombre ASC',
      limit: 20,
    );
    return result.map((e) => Producto.fromMap(e)).toList();
  }

  /// Registra una venta y sus lineas en una transaccion.
  ///
  /// Si falla cualquier insercion no queda una venta a medias.
  Future<int> addVenta(double total, List<CarritoItem> items) async {
    final db = await database;
    final fecha = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final ventaId = await txn.insert('ventas', {
        'total': total,
        'fecha': fecha,
        'estado': 'completada',
      });

      for (final item in items) {
        await txn.insert('venta_detalles', {
          'venta_id': ventaId,
          'producto_id': item.producto.id,
          'nombre': item.producto.nombre,
          'codigo': item.producto.codigo,
          'precio_unitario': item.producto.precio,
          'cantidad': item.cantidad,
          'subtotal': item.subtotal,
          'unidad_medida': item.producto.unidadMedida,
          'unidad_venta': item.producto.unidadVenta,
          'venta_por_peso': item.producto.ventaPorPeso ? 1 : 0,
          'iva': item.producto.iva,
        });
      }

      return ventaId;
    });
  }

  // --- Marcas -------------------------------------------------------------

  /// Marcas ordenadas alfabeticamente, para el autocompletado del formulario.
  Future<List<String>> getMarcas() async {
    final db = await database;
    final result =
        await db.query('marcas', orderBy: 'nombre COLLATE NOCASE ASC');
    return result.map((e) => e['nombre'] as String).toList();
  }

  /// Marca por nombre (sin distinguir mayusculas), o `null` si no existe.
  Future<String?> getMarca(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return null;

    final db = await database;
    final result = await db.query(
      'marcas',
      where: 'nombre = ? COLLATE NOCASE',
      whereArgs: [limpio],
      limit: 1,
    );
    return result.isEmpty ? null : result.first['nombre'] as String;
  }

  /// Registra una marca y devuelve el nombre canonico.
  ///
  /// Si ya existe (con otra capitalizacion) devuelve la que habia en vez de
  /// fallar: "alfa" y "Alfa" no pueden ser dos marcas distintas.
  Future<String> agregarMarca(String nombre) async {
    final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) return '';

    final existente = await getMarca(limpio);
    if (existente != null) return existente;

    final db = await database;
    await db.insert('marcas', {
      'nombre': limpio,
      'created_at': DateTime.now().toIso8601String(),
    });
    return limpio;
  }

  /// Registra la marca si falta y devuelve la que quedo, sin fallar nunca.
  ///
  /// Se usa al guardar un producto: que la marca sea nueva nunca debe impedir
  /// registrar la venta, asi que un error de escritura se ignora y se devuelve
  /// el nombre tal cual lo escribio el usuario.
  Future<String> asegurarMarca(String nombre) async {
    try {
      final agregada = await agregarMarca(nombre);
      return agregada.isEmpty ? nombre.trim() : agregada;
    } catch (_) {
      return nombre.trim();
    }
  }

  /// Marcas que aparecen en productos, incluidas las que no estan en la tabla
  /// `marcas` (base creada antes de que existiera).
  Future<void> sincronizarMarcasDesdeProductos() async {
    final db = await database;
    final resultado = await db.rawQuery('''
      SELECT DISTINCT marca FROM productos
      WHERE marca IS NOT NULL AND TRIM(marca) <> ''
    ''');

    for (final fila in resultado) {
      await asegurarMarca(fila['marca'] as String);
    }
  }

  // --- Categorias ----------------------------------------------------------

  /// Categorias del catalogo, ordenadas alfabeticamente.
  Future<List<String>> getCategorias() async {
    final db = await database;
    final result = await db.query(
      'categorias',
      orderBy: 'nombre COLLATE NOCASE ASC',
    );
    return result.map((e) => e['nombre'] as String).toList();
  }

  /// Categoria canonica por nombre (sin distinguir mayusculas), o `null`.
  Future<String?> getCategoria(String nombre) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return null;

    final db = await database;
    final result = await db.query(
      'categorias',
      where: 'nombre = ? COLLATE NOCASE',
      whereArgs: [limpio],
      limit: 1,
    );
    return result.isEmpty ? null : result.first['nombre'] as String;
  }

  /// Registra una categoria y devuelve el nombre canonico.
  ///
  /// Igual que las marcas: si ya existe con otra capitalizacion devuelve la que
  /// habia, para que "quesos" y "Quesos" no terminen como dos categorias.
  Future<String> agregarCategoria(String nombre) async {
    final limpio = nombre.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) return '';

    final existente = await getCategoria(limpio);
    if (existente != null) return existente;

    final db = await database;
    await db.insert('categorias', {
      'nombre': limpio,
      'created_at': DateTime.now().toIso8601String(),
    });
    return limpio;
  }

  /// Registra la categoria si falta y devuelve la que quedo, sin fallar nunca.
  ///
  /// Se usa al guardar un producto: que la categoria sea nueva nunca debe
  /// impedir registrar la venta.
  Future<String> asegurarCategoria(String nombre) async {
    try {
      final agregada = await agregarCategoria(nombre);
      return agregada.isEmpty ? nombre.trim() : agregada;
    } catch (_) {
      return nombre.trim();
    }
  }

  /// Renombra una categoria y arrastra los productos que la usan.
  ///
  /// `productos.categoria` guarda el texto, no el `id`, asi que el `UPDATE` va
  /// en cascada por nombre. La comparacion es sin distinguir mayusculas para
  /// que un producto guardado como "quesos" tambien se mueva a "Quesos".
  ///
  /// Devuelve el nombre canonico nuevo, o `null` si la categoria no existia.
  Future<String?> renombrarCategoria(String actual, String nuevo) async {
    final origen = await getCategoria(actual);
    if (origen == null) return null;

    final destino = nuevo.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (destino.isEmpty) return origen;

    // Si el destino ya existe no se fusiona a ciegas: el llamador debe
    // preguntar. Devolver `null` sin tocar nada seria indistinguible de
    // "no existia", asi que se lanza y el formulario lo reporta.
    final chocante = await getCategoria(destino);
    if (chocante != null && chocante.toLowerCase() != origen.toLowerCase()) {
      throw EstadoCategoriaException(
        'Ya existe la categoria "$chocante".',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'categorias',
        {'nombre': destino},
        where: 'nombre = ? COLLATE NOCASE',
        whereArgs: [origen],
      );
      await txn.update(
        'productos',
        {'categoria': destino},
        where: 'categoria = ? COLLATE NOCASE',
        whereArgs: [origen],
      );
    });

    return destino;
  }

  /// Catalogo con la cuenta de productos de cada categoria, en una sola consulta.
  ///
  /// La pantalla de categorias necesita el numero para cada fila. Consultarlo con
  /// `contarProductosPorCategoria` en un bucle son N viajes a la base (un N+1) y
  /// con ~100 categorias se nota; aqui se resuelve con un `LEFT JOIN`.
  Future<Map<String, int>> getCategoriasConConteo() async {
    final db = await database;
    final resultado = await db.rawQuery('''
    SELECT c.nombre AS nombre, COUNT(p.id) AS total
    FROM categorias c
    LEFT JOIN productos p ON p.categoria = c.nombre COLLATE NOCASE
    GROUP BY c.id
    ORDER BY c.nombre COLLATE NOCASE ASC
  ''');

    return {
      for (final fila in resultado)
        fila['nombre'] as String: (fila['total'] as int?) ?? 0,
    };
  }

  /// Cuantos productos usan esta categoria.
  Future<int> contarProductosPorCategoria(String nombre) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM productos '
      'WHERE categoria = ? COLLATE NOCASE',
      [nombre.trim()],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Borra la categoria del catalogo.
  ///
  /// Devuelve `false` — sin borrar nada — si hay productos que la usan. Como
  /// `productos.categoria` es texto plano, borrarla dejaria esos productos con
  /// una categoria que no aparece en ninguna parte: primero hay que moverlos.
  Future<bool> eliminarCategoria(String nombre) async {
    if (await contarProductosPorCategoria(nombre) > 0) return false;

    final db = await database;
    await db.delete(
      'categorias',
      where: 'nombre = ? COLLATE NOCASE',
      whereArgs: [nombre.trim()],
    );
    return true;
  }

  /// Nombre canonico de una categoria, sin escribir nada.
  ///
  /// Prioridad: el catalogo propio, luego las predeterminadas, y si no hay
  /// coincidencia el texto tal cual con la inicial en mayuscula. Existe para
  /// poder llamarlo **antes** de guardar el producto —normalizar contra el
  /// catalogo tiene que poder leer sin crear filas huerfanas si despues el
  /// guardado falla por codigo repetido—.
  Future<String> normalizarCategoria(String texto) async {
    final limpio = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) return '';

    final canonica = await getCategoria(limpio);
    if (canonica != null) return canonica;

    return Categorias.normalizar(limpio);
  }

  /// Copia a la tabla `categorias` lo que ya existe en `productos.categoria`.
  ///
  /// Necesario tras una migracion y util tras crear productos a mano, para que
  /// el menu lateral muestre todo lo que realmente se esta usando.
  Future<void> sincronizarCategoriasDesdeProductos() async {
    final db = await database;
    final resultado = await db.rawQuery('''
      SELECT DISTINCT categoria FROM productos
      WHERE categoria IS NOT NULL AND TRIM(categoria) <> ''
    ''');

    for (final fila in resultado) {
      await asegurarCategoria(fila['categoria'] as String);
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
      if (d.codigo != null && d.codigo!.isNotEmpty) {
        await db.rawUpdate(
          'UPDATE productos SET stock = stock + ? WHERE codigo = ?',
          [d.cantidad, d.codigo],
        );
      } else {
        await db.rawUpdate(
          'UPDATE productos SET stock = stock + ? WHERE id = ?',
          [d.cantidad, d.productoId],
        );
      }
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
    final inicioSemana = now.subtract(Duration(days: now.weekday - 1));
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

      // El IVA va incluido en el precio de cada linea, asi que se extrae linea
      // por linea (cada una puede tener una tasa distinta). SQLite no tiene una
      // funcion de "quitar impuesto", asi que se calcula en Dart con la misma
      // formula de `Precios.ivaIncluido`.
      final resultLineas = await db.rawQuery('''
        SELECT vd.subtotal, COALESCE(vd.iva, 0) as iva
        FROM venta_detalles vd
        JOIN ventas v ON vd.venta_id = v.id
        WHERE v.fecha >= ? AND v.estado = 'completada'
      ''', [iso]);

      final rawTotal = resultVentas.first['total'];
      final rawCantidad = resultCantidad.first['cantidad'];

      resumen['total_${entry['label']}'] =
          rawTotal is num ? rawTotal.toDouble() : 0.0;
      resumen['cantidad_${entry['label']}'] =
          rawCantidad is num ? rawCantidad.toDouble() : 0.0;
      resumen['iva_${entry['label']}'] = Precios.ivaDeLineas(
        resultLineas.map((r) => (
              subtotal: r['subtotal'] is num
                  ? (r['subtotal'] as num).toDouble()
                  : 0.0,
              tasa: r['iva'] is num ? (r['iva'] as num).toDouble() : 0.0,
            )),
      );
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
