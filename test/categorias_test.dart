import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/data/categorias.dart';

void main() {
  group('Categorias.todas', () {
    test('no tiene duplicados', () {
      final todas = Categorias.todas;
      expect(todas.toSet().length, todas.length);
    });

    test('cubre las tres secciones basicas de una tienda', () {
      final todas = Categorias.todas.map((c) => c.toLowerCase()).toList();
      expect(todas, contains('verduras'));
      expect(todas, contains('arroz'));
      expect(todas, contains('detergente'));
      expect(todas, contains('gaseosas'));
    });

    test('cada seccion trae categorias', () {
      for (final grupo in Categorias.porSeccion) {
        expect(grupo.categorias, isNotEmpty, reason: grupo.seccion);
        expect(grupo.seccion, isNotEmpty);
      }
      expect(Categorias.cantidadSecciones, greaterThan(5));
    });
  });

  group('Categorias.buscar', () {
    test('sin texto devuelve el comienzo de la lista', () {
      expect(Categorias.buscar(''), isNotEmpty);
      expect(Categorias.buscar('   '), isNotEmpty);
    });

    test('encuentra por fragmento, sin distinguir mayusculas', () {
      final resultado = Categorias.buscar('ques');
      expect(resultado, contains('Quesos'));
    });

    test('respeta el limite', () {
      expect(Categorias.buscar('', limite: 3), hasLength(3));
    });

    test('una categoria inexistente devuelve lista vacia', () {
      expect(Categorias.buscar('zzzz'), isEmpty);
    });
  });

  group('Categorias.normalizar', () {
    test('pone mayuscula inicial', () {
      expect(Categorias.normalizar('quesos'), 'Quesos');
      expect(Categorias.normalizar('  lacteos '), 'Lacteos');
    });

    test('si ya existe devuelve la version oficial', () {
      // Sin esto, "quesos" y "Quesos" serian dos categorias distintas en el
      // filtro y en los reportes.
      expect(Categorias.normalizar('quesos'), 'Quesos');
      expect(Categorias.normalizar('QUESOS'), 'Quesos');
      expect(Categorias.normalizar('verduras'), 'Verduras');
    });

    test('colapsa espacios repetidos', () {
      expect(Categorias.normalizar('  pan   del   dia '), 'Pan del dia');
    });

    test('una categoria inventada se capitaliza pero se respeta', () {
      expect(Categorias.normalizar('rancho'), 'Rancho');
      expect(Categorias.normalizar('rancho'), isNot(Categorias.todas));
    });

    test('texto vacio devuelve vacio', () {
      expect(Categorias.normalizar(''), '');
      expect(Categorias.normalizar('    '), '');
    });
  });
}