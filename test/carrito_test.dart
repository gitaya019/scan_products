import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/carrito_item.dart';
import 'package:scan_products/models/producto_model.dart';

/// Producto de ejemplo con precio por libra y venta en gramos.
Producto _cebolla() => Producto(
      nombre: 'Cebolla',
      categoria: 'Verduras',
      precio: 5000,
      peso: 1,
      stock: 5000,
      unidadMedida: 'lb',
      unidadVenta: 'g',
      iva: 0,
      ventaPorPeso: true,
    );

void main() {
  group('CarritoItem con unidades distintas', () {
    test('120 g con la libra a 5.000 cobran 1.323', () {
      // El bug que motivo todo esto: sin conversion, 5000 x 120 = 600.000.
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      expect(item.subtotal, 1323);
      expect(item.subtotal, lessThan(2000));
    });

    test('el precio por gramo es el de la libra dividido', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      expect(item.precioUnitarioVenta, closeTo(11.0231, 1e-3));
    });

    test('la cantidad se expresa tambien en la unidad del precio', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      expect(item.cantidadEnUnidadPrecio, closeTo(0.264555, 1e-6));
    });

    test('media libra weighs 227 g y no cambia de total', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 226.8);
      expect(item.subtotal, closeTo(2500, 1));
    });

    test('la nota de conversion explica el cobro', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      expect(item.notaConversion, contains('120 g'));
      expect(item.notaConversion, contains('el g'));
    });
  });

  group('CarritoItem con la misma unidad', () {
    test('se comporta como antes: precio x cantidad', () {
      final producto = Producto(
        nombre: 'Leche',
        categoria: 'Lacteos',
        precio: 3500,
        peso: 1,
        stock: 20,
        unidadMedida: 'unidad',
        iva: 19,
      );
      final item = CarritoItem(producto: producto, cantidad: 3);
      expect(item.subtotal, 10500);
      expect(item.precioUnitarioVenta, 3500);
      expect(item.notaConversion, isNull);
    });

    test('unidad_venta null equivale a la del precio', () {
      // Productos guardados antes de la columna: no deben cambiar de comportamiento.
      final producto = Producto(
        nombre: 'Arroz',
        categoria: 'Granos',
        precio: 10000,
        peso: 1,
        stock: 50,
        unidadMedida: 'kg',
        ventaPorPeso: true,
      );
      expect(producto.unidad, 'kg');
      expect(producto.necesitaConversion, isFalse);
      expect(CarritoItem(producto: producto, cantidad: 2.5).subtotal, 25000);
    });
  });

  group('CarritoItem con unidades incompatibles', () {
    test('masa contra volumen no inventa un factor', () {
      final producto = Producto(
        nombre: 'Algo raro',
        categoria: 'Varios',
        precio: 5000,
        peso: 1,
        stock: 10,
        unidadMedida: 'L',
        unidadVenta: 'g',
        ventaPorPeso: true,
      );
      // No hay conversion de g a L, asi que no se toca el total.
      expect(producto.necesitaConversion, isFalse);
      expect(CarritoItem(producto: producto, cantidad: 2).subtotal, 10000);
    });

    test('paquete a caja no inventa un factor', () {
      final producto = Producto(
        nombre: 'Refri',
        categoria: 'Bebidas',
        precio: 8000,
        peso: 1,
        stock: 10,
        unidadMedida: 'paquete',
        unidadVenta: 'caja',
        ventaPorPeso: true,
      );
      expect(producto.necesitaConversion, isFalse);
      expect(CarritoItem(producto: producto, cantidad: 2).subtotal, 16000);
    });
  });

  group('CarritoItem.formatear', () {
    test('enteros sin decimales', () {
      expect(CarritoItem.formatear(120), '120');
      expect(CarritoItem.formatear(1), '1');
    });

    test('decimales con coma y sin ceros de sobra', () {
      expect(CarritoItem.formatear(0.264555), '0,265');
      expect(CarritoItem.formatear(11.0231), '11,023');
      expect(CarritoItem.formatear(0.5), '0,5');
    });
  });

  group('CarritoItem redondeo', () {
    test('el subtotal se redondea a pesos', () {
      final producto = Producto(
        nombre: 'Queso',
        categoria: 'Lacteos',
        precio: 3333,
        peso: 1,
        stock: 10,
        unidadMedida: 'kg',
        ventaPorPeso: true,
      );
      // 3.333 x 0,3 = 999,9 -> 1.000. El cliente paga pesos, no centavos.
      final item = CarritoItem(producto: producto, cantidad: 0.3);
      expect(item.subtotal, 1000);
    });
  });
}
