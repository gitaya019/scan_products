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
        500,
      );
      // La libra del comercio es medio kilo, no la libra exacta de 453,59237 g.
      expect(
        Unidades.factor(origen: 'kg', destino: 'lb'),
        2,
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
    test('120 g son 0,24 lb', () {
      final libras = Unidades.convertir(
        120,
        origen: 'g',
        destino: 'lb',
      );
      expect(libras, closeTo(0.24, 1e-9));
    });

    test('las equivalencias pedidas: 1 kg = 1.000 g, 2 lb = 1 kg', () {
      expect(Unidades.convertir(1, origen: 'kg', destino: 'g'), 1000);
      expect(Unidades.convertir(2, origen: 'lb', destino: 'kg'), 1);
      expect(Unidades.convertir(1, origen: 'lb', destino: 'g'), 500);
      // Y de vuelta: 1 kg son dos libras, no 2,2.
      expect(Unidades.convertir(1, origen: 'kg', destino: 'lb'), 2);
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
      expect(libras, closeTo(0.24, 1e-9));
      // El total que sale de ahi debe ser 1.200, no 600.000.
      expect(libras * 5000, closeTo(1200, 1e-2));
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

    test('el factor se muestra sin ceros de relleno', () {
      // Con la libra en 500 g, 1 g son exactamente 0,002 lb. Sin recortar los
      // ceros el formulario mostraria "1 g = 0,002000 lb".
      expect(
        Unidades.equivalencia(unidadVenta: 'g', unidadPrecio: 'lb'),
        '1 g = 0,002 lb',
      );
      expect(
        Unidades.equivalencia(unidadVenta: 'g', unidadPrecio: 'kg'),
        '1 g = 0,001 kg',
      );
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
