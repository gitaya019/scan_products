import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/utils/precios.dart';

void main() {
  group('Precios.precioSinIVA', () {
    test('11.900 con tasa 19 son 10.000 de base', () {
      expect(Precios.precioSinIVA(11900, 19), closeTo(10000, 1e-9));
    });

    test('18.500 con tasa 19', () {
      expect(Precios.precioSinIVA(18500, 19), closeTo(15546.22, 0.01));
    });

    test('tasa 0 deja el precio igual', () {
      expect(Precios.precioSinIVA(11900, 0), 11900);
    });

    test('tasa negativa se trata como 0 en vez de dar un numero raro', () {
      // Sin este guardia, 11900 / (1 - 0,19) daria 15.554, que es un precio
      // mas alto que el original: no tiene sentido como base gravable.
      expect(Precios.precioSinIVA(11900, -19), 11900);
    });
  });

  group('Precios.ivaIncluido', () {
    test('11.900 con tasa 19 contiene 1.900', () {
      expect(Precios.ivaIncluido(11900, 19), closeTo(1900, 1e-9));
    });

    test('base + impuesto reconstruyen el precio', () {
      const precio = 18500.0;
      final base = Precios.precioSinIVA(precio, 19);
      final iva = Precios.ivaIncluido(precio, 19);
      expect(base + iva, closeTo(precio, 1e-9));
    });

    test('tasa 0 no contiene impuesto', () {
      expect(Precios.ivaIncluido(11900, 0), 0);
    });
  });

  group('Precios.precioDesdeCosto', () {
    test('costo 10.000 con 30% da 13.000', () {
      expect(Precios.precioDesdeCosto(10000, 30), 13000);
    });

    test('redondea a pesos enteros', () {
      // 3.333 x 1,15 = 3.832,95 -> 3.833. Sin redondear, el subtotal arrastra
      // centavos que el cliente nunca ve pero se acumulan en el reporte.
      expect(Precios.precioDesdeCosto(3333, 15), 3833);
    });

    test('costo 0 da precio 0, no NaN', () {
      expect(Precios.precioDesdeCosto(0, 30), 0);
    });

    test('margen 0 devuelve el costo', () {
      expect(Precios.precioDesdeCosto(7500, 0), 7500);
    });
  });

  group('Precios.margenDesdePrecios', () {
    test('costo 10.000 y precio 13.000 es 30%', () {
      expect(Precios.margenDesdePrecios(10000, 13000), closeTo(30, 1e-9));
    });

    test('costo 0 da 0 en vez de infinito', () {
      // Un margen infinito no se puede pintar en pantalla ni guardar.
      expect(Precios.margenDesdePrecios(0, 13000), 0);
    });

    test('precio menor que el costo da margen negativo', () {
      expect(Precios.margenDesdePrecios(10000, 8000), -20);
    });

    test('es la inversa de precioDesdeCosto', () {
      const costo = 12345.0;
      final precio = Precios.precioDesdeCosto(costo, 42);
      expect(Precios.margenDesdePrecios(costo, precio), closeTo(42, 0.01));
    });
  });

  group('Precios.ivaDeLineas', () {
    test('suma el impuesto de lineas con tasas distintas', () {
      // Una linea de 11.900 al 19% trae 1.900; una de 10.000 al 5% trae 476,19.
      final total = Precios.ivaDeLineas([
        (subtotal: 11900, tasa: 19),
        (subtotal: 10000, tasa: 5),
      ]);
      expect(total, closeTo(2376, 0.5));
    });

    test('sin lineas devuelve 0', () {
      expect(Precios.ivaDeLineas([]), 0);
    });

    test('lineas exentas no aportan impuesto', () {
      expect(
        Precios.ivaDeLineas([
          (subtotal: 5000, tasa: 0),
          (subtotal: 3000, tasa: 0),
        ]),
        0,
      );
    });

    test('el total del cliente no se altera al extraer el impuesto', () {
      // Este es el punto de la convencion: 11.900 se cobran 11.900.
      const total = 11900.0;
      final base = Precios.precioSinIVA(total, 19);
      final iva = Precios.ivaIncluido(total, 19);
      expect(base + iva, closeTo(total, 1e-9));
    });
  });

  group('Precios.baseDeLineas', () {
    test('suma la base de cada linea', () {
      final base = Precios.baseDeLineas([
        (subtotal: 11900, tasa: 19),
        (subtotal: 10000, tasa: 19),
      ]);
      // 10.000 + 8.403,36 = 18.403
      expect(base, 18403);
    });
  });

  group('Precios.parsePorcentaje', () {
    test('la coma es separador decimal, no un simbolo a descartar', () {
      // Este era un bug real: "30,5" se limpiaba a "305" y el margen se
      // multiplicaba por diez al teclear con el teclado del celular.
      expect(Precios.parsePorcentaje('30,5'), 30.5);
      expect(Precios.parsePorcentaje('19,'), 19);
    });

    test('acepta punto tambien', () {
      expect(Precios.parsePorcentaje('30.5'), 30.5);
    });

    test('descarta simbolos', () {
      expect(Precios.parsePorcentaje('19 %'), 19);
      expect(Precios.parsePorcentaje(r'$19'), 19);
    });

    test('texto no numerico da 0, no lanza', () {
      expect(Precios.parsePorcentaje('abc'), 0);
      expect(Precios.parsePorcentaje(''), 0);
    });

    test('acota a un rango utilizable', () {
      expect(Precios.parsePorcentaje('-5'), 0);
      expect(Precios.parsePorcentaje('999999'), 9999);
    });
  });

  group('constantes', () {
    test('las tasas ofrezcas son las colombianas', () {
      expect(Precios.tasasIVA, [0, 5, 10, 19]);
      expect(Precios.tasaPorDefecto, 19);
    });
  });

  group('Precios.redondearMoneda', () {
    test('a pesos enteros', () {
      expect(Precios.redondearMoneda(1322.77), 1323);
      expect(Precios.redondearMoneda(1322.22), 1322);
    });
  });

  group('Precios.redondearCobro', () {
    test('sin redondeo solo deja pesos enteros', () {
      expect(Precios.redondearCobro(1322.77), 1323);
      expect(Precios.redondearCobro(1322.22), 1322);
      expect(
        Precios.redondearCobro(1322.77, RedondeoCobro.sinRedondeo),
        1323,
      );
    });

    test('multiplos de 50 toma el mas cercano', () {
      const m = RedondeoCobro.multiploDe50;
      // Los cuatro ejemplos que pidio el caso de uso.
      expect(Precios.redondearCobro(927, m), 950);
      expect(Precios.redondearCobro(980, m), 1000);
      expect(Precios.redondearCobro(10737, m), 10750);
      expect(Precios.redondearCobro(25000, m), 25000,
          reason: 'lo que ya es multiplo se queda, no sube ni baja');
    });

    test('multiplos de 50 empata hacia arriba', () {
      // 925 esta a 25 de 900 y a 25 de 950. `round` en Dart empata hacia
      // arriba, que es lo que quiere el tendero: 25 pesos mas de venta nunca
      // se quejan, 25 menos si.
      expect(Precios.redondearCobro(925, RedondeoCobro.multiploDe50), 950);
    });

    test('techo a la centena siempre sube', () {
      const t = RedondeoCobro.techoCien;
      expect(Precios.redondearCobro(924, t), 1000);
      expect(Precios.redondearCobro(9823, t), 9900);
      expect(Precios.redondearCobro(1, t), 100);
    });

    test('techo a la centena respeta lo que ya es multiplo exacto', () {
      // El bug clasico: 9800 / 100 puede dar 97,99999999999999 en punto
      // flotante y un `ceil` a secas lo sube a 9900. Con el divisor ya
      // redondeado, 9.800 se queda en 9.800.
      const t = RedondeoCobro.techoCien;
      expect(Precios.redondearCobro(9800, t), 9800);
      expect(Precios.redondearCobro(10000, t), 10000);
      expect(Precios.redondearCobro(10700, t), 10700);
      expect(Precios.redondearCobro(25000, t), 25000);
    });

    test('el ruido de punto flotante no sube un peso de mas', () {
      // 0.1 + 0.2 = 0.30000000000000004. Redondeado a pesos es 0 y el techo
      // no tiene nada que subir. Sin el paso previo a pesos enteros, el
      // redondeo multiple lo habria carriedo a 50.
      expect(Precios.redondearCobro(0.1 + 0.2, RedondeoCobro.multiploDe50), 0);
      expect(Precios.redondearCobro(0, RedondeoCobro.techoCien), 0);
    });

    test('cero y negativos no se inflan', () {
      for (final modo in RedondeoCobro.values) {
        expect(Precios.redondearCobro(0, modo), 0);
        expect(Precios.redondearCobro(-500, modo), 0,
            reason: 'un total negativo es un dato roto, no un descuento');
      }
    });

    test('es idempotente: aplicar dos veces da el mismo numero', () {
      // Importante para el guardado: si el precio ya se redondeo al crear el
      // producto, pasarlo otra vez al cobrar no debe moverlo.
      for (final modo in RedondeoCobro.values) {
        for (final importe in const <double>[924, 980, 9823, 10737, 25000]) {
          final uno = Precios.redondearCobro(importe, modo);
          expect(Precios.redondearCobro(uno, modo), uno,
              reason: '$importe con $modo no es estable');
        }
      }
    });
  });

  group('RedondeoCobro', () {
    test('desdeNombre acepta lo guardado y rechaza lo desconocido', () {
      expect(RedondeoCobro.desdeNombre('techoCien'), RedondeoCobro.techoCien);
      expect(RedondeoCobro.desdeNombre('multiploDe50'),
          RedondeoCobro.multiploDe50);
      // Un valor desconocido o ausente cae en el modo por defecto: cobrar
      // nunca puede depender de que una preferencia se haya podido leer.
      expect(RedondeoCobro.desdeNombre('inventado'), RedondeoCobro.sinRedondeo);
      expect(RedondeoCobro.desdeNombre(null), RedondeoCobro.sinRedondeo);
    });

    test('todos los modos tienen etiqueta y ejemplo', () {
      for (final modo in RedondeoCobro.values) {
        expect(modo.etiqueta, isNotEmpty);
        expect(modo.ejemplo, isNotEmpty);
      }
    });
  });
}
