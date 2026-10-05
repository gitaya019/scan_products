import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/utils/unidades.dart';

void main() {
  group('Unidades.factor', () {
    test('misma unidad da 1', () {
      expect(Unidades.factor(origen: 'g', destino: 'g'), 1);
      expect(Unidades.factor(origen: 'lb', destino: 'lb'), 1);
      expect(Unidades.factor(origen: 'unidad', destino: 'unidad'), 1);
    });

    test('masa entre si: kg, g, lb', () {
      expect(Unidades.factor(origen: 'kg', destino: 'g'), 1000);
      expect(
          Unidades.factor(origen: 'g', destino: 'kg'), closeTo(0.001, 1e-12));
      expect(
        Unidades.factor(origen: 'lb', destino: 'g'),
        closeTo(453.59237, 1e-9),
      );
      expect(
        Unidades.factor(origen: 'kg', destino: 'lb'),
        closeTo(2.20462, 1e-5),
      );
    });

    test('volumen entre si: L y mL', () {
      expect(Unidades.factor(origen: 'L', destino: 'mL'), 1000);
      expect(
          Unidades.factor(origen: 'mL', destino: 'L'), closeTo(0.001, 1e-12));
    });

    test('masa contra volumen no tiene conversion', () {
      expect(Unidades.factor(origen: 'kg', destino: 'L'), isNull);
      expect(Unidades.factor(origen: 'g', destino: 'mL'), isNull);
    });

    test('conteo contra medida no tiene conversion', () {
      // `paquete` -> `caja` necesita saber cuantas trae el paquete, y la app no
      // lo sabe. Inventar un factor seria peor que no convertir.
      expect(Unidades.factor(origen: 'paquete', destino: 'caja'), isNull);
      expect(Unidades.factor(origen: 'unidad', destino: 'kg'), isNull);
    });

    test('unidad desconocida no tiene conversion', () {
      expect(Unidades.factor(origen: 'arroba', destino: 'lb'), isNull);
    });
  });

  group('Unidades.convertir', () {
    test('120 g son 0,2646 lb', () {
      final libras = Unidades.convertir(
        120,
        origen: 'g',
        destino: 'lb',
      );
      expect(libras, closeTo(0.264555, 1e-6));
    });

    test('conversion invalida devuelve la cantidad sin tocar', () {
      expect(Unidades.convertir(120, origen: 'g', destino: 'L'), 120);
      expect(Unidades.convertir(3, origen: 'unidad', destino: 'caja'), 3);
    });
  });

  group('Unidades.aUnidadPrecio', () {
    test('el caso de la cebolla: 120 g con la libra a 5.000', () {
      final libras = Unidades.aUnidadPrecio(
        120,
        unidadVenta: 'g',
        unidadPrecio: 'lb',
      );
      expect(libras, closeTo(0.264555, 1e-6));
      // El total que sale de ahi debe ser 1.323, no 600.000.
      expect(libras * 5000, closeTo(1322.77, 1e-2));
    });

    test('0,5 kg con el kilo a 8.000 no convierte nada', () {
      expect(
        Unidades.aUnidadPrecio(0.5, unidadVenta: 'kg', unidadPrecio: 'kg'),
        0.5,
      );
    });
  });

  group('Unidades.equivalencia', () {
    test('la misma unidad no necesita explicacion', () {
      expect(
        Unidades.equivalencia(unidadVenta: 'kg', unidadPrecio: 'kg'),
        isNull,
      );
    });

    test('muestra el factor cuando si hay conversion', () {
      final texto = Unidades.equivalencia(
        unidadVenta: 'lb',
        unidadPrecio: 'kg',
      );
      expect(texto, isNotNull);
      expect(texto, startsWith('1 lb = '));
      expect(texto, contains(' kg'));
    });

    test('sin conversion posible no inventa texto', () {
      expect(
        Unidades.equivalencia(unidadVenta: 'g', unidadPrecio: 'L'),
        isNull,
      );
      expect(
        Unidades.equivalencia(unidadVenta: 'paquete', unidadPrecio: 'caja'),
        isNull,
      );
    });
  });

  group('clasificacion de unidades', () {
    test('conteo, masa y volumen se distinguen', () {
      expect(Unidades.esConteo('unidad'), isTrue);
      expect(Unidades.esConteo('paquete'), isTrue);
      expect(Unidades.esConteo('caja'), isTrue);
      expect(Unidades.esConteo('kg'), isFalse);

      expect(Unidades.esMasa('lb'), isTrue);
      expect(Unidades.esMasa('L'), isFalse);

      expect(Unidades.esVolumen('mL'), isTrue);
      expect(Unidades.esVolumen('g'), isFalse);
    });

    test('las de conteo no admiten decimales', () {
      expect(Unidades.admiteDecimales('unidad'), isFalse);
      expect(Unidades.admiteDecimales('caja'), isFalse);
      expect(Unidades.admiteDecimales('kg'), isTrue);
      expect(Unidades.admiteDecimales('g'), isTrue);
    });

    test('la lista de unidades cubre todo el catalogo', () {
      expect(
          Unidades.todas,
          containsAll(
              ['unidad', 'kg', 'g', 'lb', 'L', 'mL', 'paquete', 'caja']));
    });
  });
}
