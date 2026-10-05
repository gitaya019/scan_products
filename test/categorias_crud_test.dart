import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/services/database_helper.dart';

import 'helpers/test_database.dart';

/// Atajo de lectura: los metodos son todos del singleton.
DatabaseHelper get db => DatabaseHelper.instance;

void main() {
  setUp(() async {
    inicializarBaseDeDatosDePrueba();
    DatabaseHelper.databasePath = ':memory:';
  });

  tearDown(() => DatabaseHelper.instance.close());

  Future<void> producto(String nombre, String categoria) => db.addProducto(
        Producto(
          nombre: nombre,
          codigo: 'cod-$nombre',
          categoria: categoria,
          peso: 1,
          costo: 1000,
          precio: 2000,
          stock: 5,
          unidadMedida: 'unidad',
          iva: 19,
        ).toMap(),
      );

  group('catalogo de categorias', () {
    test('agrega y lee las categorias en orden alfabetico', () async {
      await db.agregarCategoria('Lacteos');
      await db.agregarCategoria('Abarrotes');

      expect(await db.getCategorias(), ['Abarrotes', 'Lacteos']);
    });

    test('no distingue mayusculas: "quesos" reutiliza "Quesos"', () async {
      await db.agregarCategoria('Quesos');

      final creada = await db.agregarCategoria('quesos');

      expect(creada, 'Quesos');
      expect(await db.getCategorias(), ['Quesos'],
          reason: 'no debe crear una segunda categoria por capitalizacion');
    });

    test('espacios sobrantes se colapsan', () async {
      await db.agregarCategoria('  Pan   de  la  casa ');

      expect(await db.getCategorias(), ['Pan de la casa']);
    });

    test('nombre vacio no crea nada', () async {
      expect(await db.agregarCategoria('   '), '');
      expect(await db.getCategorias(), isEmpty);
    });

    test('getCategoria resuelve sin distinguir mayusculas', () async {
      await db.agregarCategoria('Verduras');

      expect(await db.getCategoria('VERDURAS'), 'Verduras');
      expect(await db.getCategoria('frutas'), isNull);
    });
  });

  group('conteo de productos', () {
    test('cuenta solo los productos de esa categoria', () async {
      await producto('Leche', 'Lacteos');
      await producto('Queso', 'Lacteos');
      await producto('Arroz', 'Abarrotes');

      expect(await db.contarProductosPorCategoria('Lacteos'), 2);
      expect(await db.contarProductosPorCategoria('Abarrotes'), 1);
      expect(await db.contarProductosPorCategoria('Bebidas'), 0);
    });

    test('el conteo no distingue mayusculas ni espacios', () async {
      await producto('Leche', 'Lacteos');

      expect(await db.contarProductosPorCategoria('  lacteos '), 1);
    });
  });

  group('renombrar', () {
    test('mueve los productos que usan la categoria', () async {
      await db.agregarCategoria('Lacteos');
      await producto('Leche', 'Lacteos');
      await producto('Queso', 'Lacteos');
      await producto('Arroz', 'Abarrotes');

      final resultado =
          await db.renombrarCategoria('Lacteos', 'Leches y quesos');

      expect(resultado, 'Leches y quesos');
      expect(await db.getCategorias(), ['Leches y quesos']);
      expect(await db.contarProductosPorCategoria('Leches y quesos'), 2);
      expect(await db.contarProductosPorCategoria('Lacteos'), 0,
          reason: 'el nombre viejo ya no debe quedar en ningun producto');
    });

    test('tambien mueve los productos guardados con otra capitalizacion',
        () async {
      await db.agregarCategoria('Lacteos');
      // Un producto escrito a mano antes de que existiera el catalogo.
      await producto('Leche', 'lacteos');

      await db.renombrarCategoria('Lacteos', 'Leches');

      expect(await db.contarProductosPorCategoria('Leches'), 1);
      expect(await db.contarProductosPorCategoria('Lacteos'), 0);
    });

    test('devuelve null si la categoria no existe', () async {
      expect(await db.renombrarCategoria('No existe', 'Otro'), isNull);
    });

    test('lanza si el destino ya existe', () async {
      await db.agregarCategoria('Lacteos');
      await db.agregarCategoria('Quesos');

      await expectLater(
        db.renombrarCategoria('Lacteos', 'quesos'),
        throwsA(isA<EstadoCategoriaException>()),
      );
      expect(await db.getCategorias(), containsAll(['Lacteos', 'Quesos']),
          reason: 'un rechazo no debe haber tocado nada');
    });

    test('renombrar a si mismo no falla', () async {
      await db.agregarCategoria('Lacteos');

      expect(await db.renombrarCategoria('Lacteos', 'Lacteos'), 'Lacteos');
    });
  });

  group('eliminar', () {
    test('borra una categoria sin productos', () async {
      await db.agregarCategoria('Extras');

      expect(await db.eliminarCategoria('Extras'), isTrue);
      expect(await db.getCategorias(), isEmpty);
    });

    test('no borra una categoria en uso y no borra nada', () async {
      await db.agregarCategoria('Lacteos');
      await producto('Leche', 'Lacteos');

      expect(await db.eliminarCategoria('Lacteos'), isFalse);
      expect(await db.getCategorias(), ['Lacteos'],
          reason: 'la categoria debe seguir en el catalogo');
      expect(await db.contarProductosPorCategoria('Lacteos'), 1);
    });

    test('eliminar una categoria inexistente no falla', () async {
      expect(await db.eliminarCategoria('No existe'), isTrue);
    });
  });

  group('normalizar', () {
    test('prefiere el nombre canonico del catalogo', () async {
      await db.agregarCategoria('Lacteos y derivados');

      expect(await db.normalizarCategoria('  lacteos Y derivados '),
          'Lacteos y derivados');
    });

    test('cae a las predeterminadas si no esta en el catalogo', () async {
      expect(await db.normalizarCategoria('quesos'), 'Quesos');
    });

    test('si no existe en ningun lado, capitaliza la inicial', () async {
      expect(await db.normalizarCategoria('rancho'), 'Rancho');
    });

    test('no escribe nada: es solo lectura', () async {
      await db.normalizarCategoria('Inventada');

      expect(await db.getCategorias(), isEmpty,
          reason:
              'normalizar no debe crear filas antes de guardar el producto');
    });

    test('texto vacio queda vacio', () async {
      expect(await db.normalizarCategoria('   '), '');
    });
  });

  group('sincronizar desde productos', () {
    test('copia al catalogo lo que ya usaban los productos', () async {
      await producto('Leche', 'Lacteos');
      await producto('Arroz', 'Abarrotes');
      await producto('Detalle', 'Bebidas');

      await db.sincronizarCategoriasDesdeProductos();

      expect(await db.getCategorias(), ['Abarrotes', 'Bebidas', 'Lacteos']);
    });

    test('es idempotente', () async {
      await producto('Leche', 'Lacteos');

      await db.sincronizarCategoriasDesdeProductos();
      await db.sincronizarCategoriasDesdeProductos();

      expect(await db.getCategorias(), ['Lacteos']);
    });

    test('ignora productos sin categoria', () async {
      await db.addProducto(
        Producto(
          nombre: 'Sin categoria',
          codigo: 'sin-cat',
          categoria: '',
          peso: 1,
          precio: 100,
        ).toMap(),
      );

      await db.sincronizarCategoriasDesdeProductos();

      expect(await db.getCategorias(), isEmpty);
    });
  });

  group('asegurarCategoria', () {
    test('crea la que falta y devuelve el nombre canonico', () async {
      await db.agregarCategoria('Quesos');

      expect(await db.asegurarCategoria('QUESOS'), 'Quesos');
    });

    test('crea una nueva si no existe', () async {
      expect(await db.asegurarCategoria('Extras'), 'Extras');
      expect(await db.getCategorias(), ['Extras']);
    });
  });
}
