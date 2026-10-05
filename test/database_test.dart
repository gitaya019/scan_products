import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/carrito_item.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/models/venta_detalle.dart';
import 'package:scan_products/services/database_helper.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(() async {
    inicializarBaseDeDatosDePrueba();
    DatabaseHelper.databasePath = ':memory:';
  });

  setUp(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('venta_detalles');
    await db.delete('ventas');
    await db.delete('productos');
  });

  tearDownAll(() => DatabaseHelper.instance.close());

  Producto crearProducto({
    String codigo = '7501234567890',
    double stock = 10,
    bool ventaPorPeso = false,
  }) {
    return Producto(
      nombre: 'Producto de prueba',
      codigo: codigo,
      categoria: 'General',
      precio: 1000,
      peso: 1,
      stock: stock,
      unidadMedida: ventaPorPeso ? 'kg' : 'unidad',
      ventaPorPeso: ventaPorPeso,
    );
  }

  group('productos', () {
    test('inserta y recupera productos', () async {
      await DatabaseHelper.instance.addProducto(crearProducto().toMap());

      final productos = await DatabaseHelper.instance.getProductos();

      expect(productos, hasLength(1));
      expect(productos.first['nombre'], 'Producto de prueba');
    });

    test('busca por nombre y por codigo', () async {
      await DatabaseHelper.instance.addProducto(crearProducto().toMap());
      await DatabaseHelper.instance.addProducto(
        crearProducto(codigo: '1112223334445').toMap(),
      );

      final porNombre = await DatabaseHelper.instance.searchProductos('prueba');
      final porCodigo = await DatabaseHelper.instance.searchProductos('11122');

      expect(porNombre, hasLength(2));
      expect(porCodigo.single.codigo, '1112223334445');
    });

    test('getProductoByCodigo devuelve null si no existe', () async {
      expect(await DatabaseHelper.instance.getProductoByCodigo('nada'), isNull);
    });

    test('updateStock acumula por codigo', () async {
      await DatabaseHelper.instance.addProducto(crearProducto().toMap());

      await DatabaseHelper.instance.updateStock('7501234567890', 5);
      await DatabaseHelper.instance.updateStock('7501234567890', -2);

      final productos = await DatabaseHelper.instance.getProductos();
      expect(productos.first['stock'], 13.0);
    });

    test('updateStock funciona con decimales para venta por peso', () async {
      await DatabaseHelper.instance.addProducto(
        crearProducto(stock: 1.0, ventaPorPeso: true).toMap(),
      );

      await DatabaseHelper.instance.updateStock('7501234567890', 0.5);

      final productos = await DatabaseHelper.instance.getProductos();
      expect(productos.first['stock'], 1.5);
    });

    test('updateStock funciona por id cuando no hay codigo', () async {
      final id = await DatabaseHelper.instance
          .addProducto(crearProducto(codigo: '').toMap());

      await DatabaseHelper.instance.updateStock(null, 3, id: id);

      final productos = await DatabaseHelper.instance.getProductos();
      expect(productos.first['stock'], 13.0);
    });

    test('elimina un producto', () async {
      final id =
          await DatabaseHelper.instance.addProducto(crearProducto().toMap());

      await DatabaseHelper.instance.deleteProducto(id);

      expect(await DatabaseHelper.instance.getProductos(), isEmpty);
    });
  });

  group('ventas', () {
    test('registra la venta con sus lineas', () async {
      final producto = crearProducto();
      await DatabaseHelper.instance.addProducto(producto.toMap());
      producto.id = 1;

      await DatabaseHelper.instance.addVenta(3000, [
        CarritoItem(producto: producto, cantidad: 2),
        CarritoItem(producto: producto, cantidad: 1),
      ]);

      final ventas = await DatabaseHelper.instance.getVentas();
      expect(ventas, hasLength(1));
      expect(ventas.first.total, 3000);

      final detalles =
          await DatabaseHelper.instance.getVentaDetalles(ventas.first.id!);
      expect(detalles, hasLength(2));
    });

    test('getVentas ordena de mas reciente a mas antigua', () async {
      final db = await DatabaseHelper.instance.database;
      await db.insert('ventas', {
        'total': 100.0,
        'fecha': '2026-01-01T10:00:00.000',
        'estado': 'completada',
      });
      await db.insert('ventas', {
        'total': 200.0,
        'fecha': '2026-06-01T10:00:00.000',
        'estado': 'completada',
      });

      final ventas = await DatabaseHelper.instance.getVentas();

      expect(ventas.first.total, 200.0);
      expect(ventas.last.total, 100.0);
    });

    test('anular una venta repone el stock y marca el estado', () async {
      final producto = crearProducto(stock: 10);
      await DatabaseHelper.instance.addProducto(producto.toMap());
      producto.id = 1;

      await DatabaseHelper.instance
          .updateStock(producto.codigo, -4, id: producto.id);

      await DatabaseHelper.instance.addVenta(4000, [
        CarritoItem(producto: producto, cantidad: 4),
      ]);

      final venta = (await DatabaseHelper.instance.getVentas()).single;
      await DatabaseHelper.instance.anularVenta(venta.id!);

      final productos = await DatabaseHelper.instance.getProductos();
      expect(productos.first['stock'], 10.0);

      final ventas = await DatabaseHelper.instance.getVentas();
      expect(ventas.single.estado, 'anulada');
    });

    test('los detalles conservan la unidad de medida', () async {
      final producto = crearProducto(stock: 5, ventaPorPeso: true);
      await DatabaseHelper.instance.addProducto(producto.toMap());
      producto.id = 1;

      await DatabaseHelper.instance.addVenta(1500, [
        CarritoItem(producto: producto, cantidad: 1.5),
      ]);

      final venta = (await DatabaseHelper.instance.getVentas()).single;
      final VentaDetalle detalle =
          (await DatabaseHelper.instance.getVentaDetalles(venta.id!)).single;

      expect(detalle.unidadMedida, 'kg');
      expect(detalle.ventaPorPeso, isTrue);
      expect(detalle.cantidad, 1.5);
    });
  });

  group('resumen de ventas', () {
    test('devuelve cero cuando no hay ventas', () async {
      final resumen = await DatabaseHelper.instance.getResumenVentas();

      expect(resumen['total_hoy'], 0.0);
      expect(resumen['total_semana'], 0.0);
      expect(resumen['total_mes'], 0.0);
      expect(resumen['producto_top'], isNull);
    });

    test('acumula hoy, semana y mes, e ignora las anuladas', () async {
      final db = await DatabaseHelper.instance.database;
      final ahora = DateTime.now().toIso8601String();

      await db.insert('ventas', {
        'total': 5000.0,
        'fecha': ahora,
        'estado': 'completada',
      });
      await db.insert('ventas', {
        'total': 9999.0,
        'fecha': ahora,
        'estado': 'anulada',
      });

      final resumen = await DatabaseHelper.instance.getResumenVentas();

      expect(resumen['total_hoy'], 5000.0);
      expect(resumen['total_semana'], 5000.0);
      expect(resumen['total_mes'], 5000.0);
    });

    test('identifica el producto mas vendido', () async {
      final producto = crearProducto(stock: 100);
      await DatabaseHelper.instance.addProducto(producto.toMap());
      producto.id = 1;

      await DatabaseHelper.instance.addVenta(5000, [
        CarritoItem(producto: producto, cantidad: 5),
      ]);

      final resumen = await DatabaseHelper.instance.getResumenVentas();

      expect(resumen['producto_top'], 'Producto de prueba');
      expect(resumen['producto_top_cantidad'], 5);
      expect(resumen['cantidad_hoy'], 5);
    });
  });
}
