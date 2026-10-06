import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/services/database_helper.dart';

import 'helpers/test_database.dart';

/// Atajo de lectura: los metodos son todos del singleton.
DatabaseHelper get db => DatabaseHelper.instance;

/// Producto de ejemplo con [marca] como texto plano.
///
/// Se construye a mano y **no** pasa por `agregarMarca` a proposito: asi se
/// comprueba que el cascado de `renombrarMarca` alcanza tambien a los productos
/// que se guardaron antes de que existiera el catalogo de marcas.
Future<void> producto(String nombre, String marca) => db.addProducto(
      Producto(
        nombre: nombre,
        codigo: 'cod-$nombre',
        categoria: 'Varios',
        peso: 1,
        costo: 1000,
        precio: 2000,
        stock: 5,
        marca: marca,
        unidadMedida: 'unidad',
        iva: 19,
      ).toMap(),
    );

void main() {
  setUp(() async {
    inicializarBaseDeDatosDePrueba();
    DatabaseHelper.databasePath = ':memory:';
  });

  tearDown(() => DatabaseHelper.instance.close());

  group('catalogo de marcas', () {
    test('agrega y lee las marcas en orden alfabetico', () async {
      await db.agregarMarca('La Ramada');
      await db.agregarMarca('Alfa');

      expect(await db.getMarcas(), ['Alfa', 'La Ramada']);
    });

    test('no distingue mayusculas: "alfa" reutiliza "Alfa"', () async {
      await db.agregarMarca('Alfa');

      final creada = await db.agregarMarca('alfa');

      expect(creada, 'Alfa');
      expect(await db.getMarcas(), ['Alfa'],
          reason: 'no debe crear una segunda marca por capitalizacion');
    });

    test('espacios sobrantes se colapsan', () async {
      await db.agregarMarca('  Pan   de  la  casa ');

      expect(await db.getMarcas(), ['Pan de la casa']);
    });

    test('nombre vacio no crea nada', () async {
      expect(await db.agregarMarca('   '), '');
      expect(await db.getMarcas(), isEmpty);
    });

    test('getMarca resuelve sin distinguir mayusculas', () async {
      await db.agregarMarca('Nutresa');

      expect(await db.getMarca('NUTRESA'), 'Nutresa');
      expect(await db.getMarca('alfa'), isNull);
    });
  });

  group('conteo de productos', () {
    test('cuenta solo los productos de esa marca', () async {
      await producto('Leche', 'Alfa');
      await producto('Queso', 'Alfa');
      await producto('Arroz', 'La Ramada');

      expect(await db.contarProductosPorMarca('Alfa'), 2);
      expect(await db.contarProductosPorMarca('La Ramada'), 1);
      expect(await db.contarProductosPorMarca('Colgate'), 0);
    });

    test('el conteo no distingue mayusculas ni espacios', () async {
      await producto('Leche', 'Alfa');

      expect(await db.contarProductosPorMarca('  alfa '), 1);
    });

    test('getMarcasConConteo trae nombre y cuenta juntos', () async {
      await db.agregarMarca('Alfa');
      await db.agregarMarca('Colgate');
      await producto('Leche', 'Alfa');
      await producto('Queso', 'Alfa');

      final catalogo = await db.getMarcasConConteo();

      expect(catalogo, {'Alfa': 2, 'Colgate': 0},
          reason:
              'una marca sin productos debe aparecer con 0, no desaparecer');
    });
  });

  group('renombrar', () {
    test('mueve los productos que usan la marca', () async {
      await db.agregarMarca('Alfa');
      await db.agregarMarca('La Ramada');
      await producto('Leche', 'Alfa');
      await producto('Queso', 'Alfa');
      // Este producto se inserta a proposito sin pasar por `agregarMarca`, para
      // que el cascado tenga que distinguir mayusculas.
      await producto('Arroz', 'La Ramada');

      final resultado = await db.renombrarMarca('Alfa', 'Alfa Fresh');

      expect(resultado, 'Alfa Fresh');
      expect(await db.getMarcas(), ['Alfa Fresh', 'La Ramada']);
      expect(await db.contarProductosPorMarca('Alfa Fresh'), 2);
      expect(await db.contarProductosPorMarca('Alfa'), 0,
          reason: 'el nombre viejo ya no debe quedar en ningun producto');
    });

    test('tambien mueve los productos guardados con otra capitalizacion',
        () async {
      await db.agregarMarca('Alfa');
      // Producto escrito a mano antes de que existiera el catalogo.
      await producto('Leche', 'alfa');

      await db.renombrarMarca('Alfa', 'Alfa Fresh');

      expect(await db.contarProductosPorMarca('Alfa Fresh'), 1);
    });

    test('una marca que no existe devuelve null sin tocar nada', () async {
      await db.agregarMarca('Alfa');

      expect(await db.renombrarMarca('Fantasma', 'Otra'), isNull);
      expect(await db.getMarcas(), ['Alfa']);
    });

    test('nombre vacio devuelve el original sin renombrar', () async {
      await db.agregarMarca('Alfa');

      expect(await db.renombrarMarca('Alfa', '   '), 'Alfa');
      expect(await db.getMarcas(), ['Alfa']);
    });

    test('renombrar a si mismo no falla ni duplica', () async {
      await db.agregarMarca('Alfa');
      await producto('Leche', 'Alfa');

      final resultado = await db.renombrarMarca('Alfa', 'alfa');

      // Conserva la capitalizacion que ya estaba guardada.
      expect(resultado, 'Alfa');
      expect(await db.getMarcas(), ['Alfa']);
      expect(await db.contarProductosPorMarca('Alfa'), 1,
          reason: 'renombrar a si mismo no puede dejar el producto sin marca');
    });

    test('si el destino ya existe avisa en vez de fusionar a ciegas', () async {
      await db.agregarMarca('Alfa');
      await db.agregarMarca('Colgate');
      await producto('Leche', 'Alfa');

      expect(
        () => db.renombrarMarca('Alfa', 'Colgate'),
        throwsA(isA<EstadoMarcaException>()),
      );

      // Y nada se movio: las dos marcas siguen intactas.
      expect(await db.getMarcas(), containsAll(['Alfa', 'Colgate']));
      expect(await db.contarProductosPorMarca('Alfa'), 1);
    });
  });

  group('eliminar', () {
    test('borra una marca que ningun producto usa', () async {
      await db.agregarMarca('Alfa');

      expect(await db.eliminarMarca('Alfa'), isTrue);
      expect(await db.getMarcas(), isEmpty);
    });

    test('no borra una marca en uso y dice por que', () async {
      await db.agregarMarca('Alfa');
      await producto('Leche', 'Alfa');

      expect(await db.eliminarMarca('Alfa'), isFalse);
      expect(await db.getMarcas(), ['Alfa']);
    });
  });

  group('sincronizar desde productos', () {
    test('copia las marcas que existen en productos y no en la tabla',
        () async {
      // Producto escrito a mano: no paso por `agregarMarca`.
      await producto('Leche', 'Alfa');

      await db.sincronizarMarcasDesdeProductos();

      expect(await db.getMarcas(), ['Alfa']);
    });

    test('es idempotente: correrla dos veces no duplica', () async {
      await producto('Leche', 'Alfa');

      await db.sincronizarMarcasDesdeProductos();
      await db.sincronizarMarcasDesdeProductos();

      expect(await db.getMarcas(), ['Alfa']);
    });
  });
}
