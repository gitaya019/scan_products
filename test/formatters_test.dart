import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/utils/formatters.dart';

void main() {
  group('formatCurrency', () {
    test('usa separador de miles colombiano', () {
      expect(formatCurrency(12500), '12.500');
      expect(formatCurrency(1000000), '1.000.000');
    });

    test('redondea a la unidad mas cercana', () {
      expect(formatCurrency(1999.4), '1.999');
      expect(formatCurrency(1999.6), '2.000');
    });

    test('no deja espacios ni simbolos', () {
      expect(formatCurrency(500), '500');
      expect(formatCurrency(500), isNot(contains(' ')));
    });
  });

  group('parseCurrency', () {
    test('ignora separadores y simbolos', () {
      expect(parseCurrency('12.500'), 12500);
      expect(parseCurrency(r'$1.250.000'), 1250000);
    });

    test('devuelve 0 para texto no numerico', () {
      expect(parseCurrency('abc'), 0.0);
      expect(parseCurrency(''), 0.0);
    });
  });

  group('formatCantidad', () {
    test('por peso acepta decimales de una cifra', () {
      expect(formatCantidad(1.5, porPeso: true), '1.5');
      expect(formatCantidad(2.0, porPeso: true), '2');
      expect(formatCantidad(0.25, porPeso: true), '0.3');
    });

    test('por unidad siempre entero', () {
      expect(formatCantidad(3.7, porPeso: false), '3');
    });
  });

  group('labelCantidad', () {
    test('usa "Peso" para masa', () {
      expect(labelCantidad(porPeso: true, unidadMedida: 'kg'), 'Peso (kg)');
      expect(labelCantidad(porPeso: true, unidadMedida: 'lb'), 'Peso (lb)');
    });

    test('usa "Volumen" para liquidos', () {
      expect(labelCantidad(porPeso: true, unidadMedida: 'L'), 'Volumen (L)');
      expect(labelCantidad(porPeso: true, unidadMedida: 'mL'), 'Volumen (mL)');
    });

    test('sin unidad devuelve "Cantidad"', () {
      expect(labelCantidad(porPeso: true, unidadMedida: null), 'Cantidad');
      expect(labelCantidad(porPeso: false, unidadMedida: 'kg'), 'Cantidad');
    });
  });

  group('labelStock', () {
    test('distingue por peso y por unidad', () {
      expect(labelStock(porPeso: true, unidadMedida: 'kg'), 'Stock (kg)');
      expect(
          labelStock(porPeso: false, unidadMedida: 'kg'), 'Stock (unidades)');
    });
  });

  group('formatFecha', () {
    test('formatea ISO a texto legible', () {
      expect(formatFecha('2026-03-12T09:41:00.000'), contains('12 mar 2026'));
      expect(formatFecha('2026-03-12T09:41:00.000'), contains('09:41'));
    });

    test('devuelve el original si no es una fecha valida', () {
      expect(formatFecha('no-es-fecha'), 'no-es-fecha');
    });
  });
}
