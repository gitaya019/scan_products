import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/carrito_item.dart';
import 'package:scan_products/models/metodo_pago.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/models/venta_detalle.dart';
import 'package:scan_products/models/venta_model.dart';

void main() {
  group('Producto', () {
    test('toMap/fromMap conservan todos los campos', () {
      final original = Producto(
        id: 7,
        nombre: 'Arroz Diana',
        codigo: '7501234567890',
        categoria: 'Granos',
        precio: 4200,
        peso: 1,
        stock: 12.5,
        marca: 'Diana',
        unidadMedida: 'kg',
        iva: 5,
        ventaPorPeso: true,
      );

      final restaurado = Producto.fromMap(original.toMap());

      expect(restaurado.id, 7);
      expect(restaurado.nombre, 'Arroz Diana');
      expect(restaurado.codigo, '7501234567890');
      expect(restaurado.categoria, 'Granos');
      expect(restaurado.precio, 4200);
      expect(restaurado.stock, 12.5);
      expect(restaurado.marca, 'Diana');
      expect(restaurado.unidadMedida, 'kg');
      expect(restaurado.iva, 5);
      expect(restaurado.ventaPorPeso, isTrue);
    });

    test('codigo vacio se guarda como null (columna UNIQUE)', () {
      final producto = Producto(
        nombre: 'Sin codigo',
        codigo: '',
        categoria: 'Varios',
        precio: 100,
        peso: 1,
      );

      expect(producto.toMap()['codigo'], isNull);
    });

    test('ventaPorPeso se serializa como entero', () {
      final producto = Producto(
        nombre: 'Leche',
        categoria: 'Lacteos',
        precio: 3000,
        peso: 1,
        ventaPorPeso: true,
      );

      expect(producto.toMap()['venta_por_peso'], 1);
    });

    test('stock ausente en el mapa usa 0', () {
      final restaurado = Producto.fromMap({
        'id': 1,
        'nombre': 'X',
        'categoria': 'Y',
        'precio': 10,
        'peso': 1,
      });

      expect(restaurado.stock, 0.0);
      expect(restaurado.iva, 0.0);
      expect(restaurado.ventaPorPeso, isFalse);
    });
  });

  group('CarritoItem', () {
    final producto = Producto(
      nombre: 'Queso',
      categoria: 'Lacteos',
      precio: 15000,
      peso: 1,
      ventaPorPeso: true,
    );

    test('subtotal multiplica precio por cantidad', () {
      final item = CarritoItem(producto: producto, cantidad: 0.5);
      expect(item.subtotal, 7500);
    });

    test('esPorPeso se hereda del producto', () {
      expect(CarritoItem(producto: producto).esPorPeso, isTrue);
    });
  });

  group('Venta', () {
    test('estado por defecto es completada', () {
      final venta = Venta(total: 1000, fecha: '2026-03-12T10:00:00.000');
      expect(venta.estado, 'completada');
    });

    test('fromMap normaliza estado ausente', () {
      final venta = Venta.fromMap({
        'id': 1,
        'total': 500.0,
        'fecha': '2026-03-12T10:00:00.000',
      });

      expect(venta.estado, 'completada');
    });

    test('toMap/fromMap conservan el metodo de pago y el billete', () {
      final original = Venta(
        id: 7,
        total: 6400,
        fecha: '2026-03-12T10:00:00.000',
        metodoPago: MetodoPago.nequi,
        recibido: null,
      );

      final leida = Venta.fromMap(original.toMap());

      expect(leida.metodoPago, MetodoPago.nequi);
      expect(leida.recibido, isNull);
      expect(leida.total, 6400);
    });

    test('una venta vieja sin metodo_pago se lee como efectivo', () {
      // Las ventas anteriores a la v10 no tienen la columna. No se pueden
      // distinguir de un cobro en efectivo, y efectivo es la lectura correcta:
      // no se inventa un metodo de pago que nadie registro.
      final venta = Venta.fromMap({
        'id': 1,
        'total': 500.0,
        'fecha': '2026-03-12T10:00:00.000',
      });

      expect(venta.metodoPago, MetodoPago.efectivo);
      expect(venta.recibido, isNull);
      expect(venta.esEfectivo, isTrue);
    });

    test('el vuelto se deriva del billete, no se guarda', () {
      final venta = Venta(
        total: 6400,
        fecha: '2026-03-12T10:00:00.000',
        recibido: 10000,
      );

      expect(venta.vuelto, 3600);
    });

    test('sin dato de billete no hay vuelto inventado', () {
      // Un pago por Nequi llega exacto: `vuelto` es `null`, no 0. Son cosas
      // distintas y en un cierre de caja se necesitan las dos.
      final venta = Venta(
        total: 6400,
        fecha: '2026-03-12T10:00:00.000',
        metodoPago: MetodoPago.nequi,
      );

      expect(venta.vuelto, isNull);
    });

    test('un billete insuficiente da vuelto 0, nunca negativo', () {
      // El negativo es un cobro incompleto que el dialogo ya bloquea. Si llegara
      // aqui desde una base vieja, 0 es la lectura que no inventa plata.
      final venta = Venta(
        total: 6400,
        fecha: '2026-03-12T10:00:00.000',
        recibido: 2000,
      );

      expect(venta.vuelto, 0);
    });

    test('billete justo no da vuelto', () {
      final venta = Venta(
        total: 6400,
        fecha: '2026-03-12T10:00:00.000',
        recibido: 6400,
      );

      expect(venta.vuelto, 0);
    });
  });

  group('MetodoPago', () {
    test('desdeNombre acepta lo guardado y cae en efectivo si no conoce', () {
      expect(MetodoPago.desdeNombre('nequi'), MetodoPago.nequi);
      expect(MetodoPago.desdeNombre('efectivo'), MetodoPago.efectivo);
      expect(MetodoPago.desdeNombre('bitcoin'), MetodoPago.efectivo);
      expect(MetodoPago.desdeNombre(null), MetodoPago.efectivo);
    });

    test('solo el efectivo pide el billete para el vuelto', () {
      expect(MetodoPago.efectivo.pideVuelto, isTrue);
      expect(MetodoPago.nequi.pideVuelto, isFalse);
    });

    test('todos los metodos traen etiqueta, icono y ayuda', () {
      for (final metodo in MetodoPago.values) {
        expect(metodo.etiqueta, isNotEmpty);
        expect(metodo.ayuda, isNotEmpty);
        expect(metodo.icono, isNotNull);
      }
    });
  });

  group('VentaDetalle', () {
    test('toMap/fromMap conservan la linea de venta', () {
      final original = VentaDetalle(
        id: 3,
        ventaId: 2,
        productoId: 1,
        nombre: 'Pan',
        codigo: '123',
        precioUnitario: 2000,
        cantidad: 3,
        subtotal: 6000,
        unidadMedida: 'unidad',
      );

      final restaurado = VentaDetalle.fromMap(original.toMap());

      expect(restaurado.ventaId, 2);
      expect(restaurado.productoId, 1);
      expect(restaurado.subtotal, 6000);
      expect(restaurado.unidadMedida, 'unidad');
      expect(restaurado.ventaPorPeso, isFalse);
    });
  });
}
