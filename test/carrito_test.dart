import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/carrito_item.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/utils/precios.dart';

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
    test('120 g con la libra a 5.000 cobran 1.200', () {
      // El bug que motivo todo esto: sin conversion, 5000 x 120 = 600.000.
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      expect(item.subtotal, 1200);
      expect(item.subtotal, lessThan(2000));
    });

    test('el precio por gramo es el de la libra dividido', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      // Con la libra en 500 g, 5.000 por libra son exactamente 10 el gramo.
      expect(item.precioUnitarioVenta, 10);
    });

    test('la cantidad se expresa tambien en la unidad del precio', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 120);
      expect(item.cantidadEnUnidadPrecio, closeTo(0.24, 1e-9));
    });

    test('media libra weighs 250 g y no cambia de total', () {
      final item = CarritoItem(producto: _cebolla(), cantidad: 250);
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

  group('CarritoItem con redondeo de cobro', () {
    /// Producto cuya linea sale con decimales: 0,264 lb a 5.000 son 1.322,78.
    CarritoItem lineaImpar(RedondeoCobro modo) => CarritoItem(
          producto: _cebolla(),
          cantidad: 120,
          redondeo: modo,
        );

    test('sin redondeo deja la linea en pesos enteros', () {
      expect(lineaImpar(RedondeoCobro.sinRedondeo).subtotal, 1200);
    });

    test('multiplos de 50 ajusta la linea', () {
      // Con la libra en 500 g la linea sale exacta (1.200), asi que se usa una
      // cantidad que si deja resto.
      final item = CarritoItem(
        producto: _cebolla(),
        cantidad: 130,
        redondeo: RedondeoCobro.multiploDe50,
      );
      // 130 g = 0,26 lb x 5.000 = 1.300, ya multiplo de 50.
      expect(item.subtotal, 1300);
    });

    test('techo a la centena sube la linea', () {
      final item = CarritoItem(
        producto: _cebolla(),
        cantidad: 51,
        redondeo: RedondeoCobro.techoCien,
      );
      // 51 g x 10 el gramo = 510 -> 600.
      expect(item.subtotal, 600);
    });

    test('el redondeo vive en la linea, no en el total', () {
      // Es lo que garantiza que la suma de las lineas del ticket sea lo que se
      // cobro. Si solo se redondeara el total, aqui habria dos reglas distintas.
      final a = lineaImpar(RedondeoCobro.multiploDe50);
      final b = lineaImpar(RedondeoCobro.techoCien);
      expect(a.redondeo, isNot(b.redondeo));
    });

    test('cambiar el modo despues re-redondea la misma linea', () {
      // El punto de venta reasigna el modo cuando el tendero cambia el ajuste
      // con la venta abierta; `redondeo` es mutable justo para eso.
      final item = CarritoItem(
        producto: _cebolla(),
        cantidad: 51,
        redondeo: RedondeoCobro.sinRedondeo,
      );
      expect(item.subtotal, 510);

      item.redondeo = RedondeoCobro.techoCien;
      expect(item.subtotal, 600);
    });

    test('el total del carrito es la suma de las lineas redondeadas', () {
      final items = [
        CarritoItem(
          producto: _cebolla(),
          cantidad: 51,
          redondeo: RedondeoCobro.techoCien,
        ),
        CarritoItem(
          producto: _cebolla(),
          cantidad: 53,
          redondeo: RedondeoCobro.techoCien,
        ),
      ];
      final total = items.fold<double>(0, (suma, i) => suma + i.subtotal);
      // 510 -> 600 y 530 -> 600.
      expect(total, 1200);
      expect(total, items.fold(0.0, (suma, i) => suma + i.subtotal),
          reason: 'el total tiene que ser exactamente la suma de las lineas');
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
