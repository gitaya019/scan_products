import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/carrito_item.dart';
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
