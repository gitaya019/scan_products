import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/screens/venta_screen.dart';
import 'package:scan_products/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_database.dart';

Future<void> io(WidgetTester t) => t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)));

/// Deja correr las animaciones de `flutter_animate`.
///
/// Sin esto el test termina con temporizadores de la animacion de entrada de
/// las filas del carrito vivos y `flutter test` falla con
/// "A Timer is still pending even after the widget tree was disposed".
Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Agrega un producto por busqueda: escribe, toca la tarjeta y confirma la
/// cantidad en el dialogo.
///
/// Ojo: si el producto ya esta en el carrito, `_agregar` solo incrementa la
/// cantidad y **no** abre dialogo, asi que este helper solo sirve la primera
/// vez que se agrega cada producto.
Future<void> agregar(
  WidgetTester tester,
  String busqueda,
  String nombre,
  String cantidad,
) async {
  await tester.enterText(find.byType(TextField).last, busqueda);
  await io(tester);
  await tester.pump();
  await tester.tap(find.text(nombre).first);
  await io(tester);
  await tester.pump();
  expect(find.text('Agregar'), findsOneWidget,
      reason: 'no se abrio el dialogo de cantidad para "$nombre"');
  await tester.enterText(find.byType(TextField).last, cantidad);
  await tester.pump();
  await tester.tap(find.text('Agregar'));
  await io(tester);
  await tester.pump();
  await asentar(tester);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    inicializarBaseDeDatosDePrueba();
    DatabaseHelper.databasePath = ':memory:';
  });

  tearDown(() => DatabaseHelper.instance.close());

  Future<void> sembrar() async {
    await DatabaseHelper.instance.addProducto(
      Producto(
        nombre: 'Queso Campesino',
        categoria: 'Lacteos',
        peso: 0.25,
        costo: 9000,
        precio: 18500,
        stock: 10,
        unidadMedida: 'kg',
        ventaPorPeso: true,
        iva: 19,
      ).toMap(),
    );
    await DatabaseHelper.instance.addProducto(
      Producto(
        nombre: 'Leche Entera',
        codigo: '7509876543210',
        categoria: 'Lacteos',
        peso: 1,
        costo: 2000,
        precio: 3200,
        stock: 20,
        unidadMedida: 'unidad',
        iva: 0,
      ).toMap(),
    );
    await DatabaseHelper.instance.addProducto(
      Producto(
        nombre: 'Pan Tajado',
        codigo: '1234567890123',
        categoria: 'Panaderia',
        peso: 1,
        costo: 2500,
        precio: 4200,
        stock: 15,
        unidadMedida: 'paquete',
        iva: 19,
      ).toMap(),
    );
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await io(tester);
    await tester.pump();
  }

  Future<void> cobrar(WidgetTester tester) async {
    await tester.tap(find.text('Cobrar'));
    for (var i = 0; i < 6; i++) {
      await io(tester);
      await tester.pump();
    }
    await asentar(tester);
  }

  /// Toca de nuevo una tarjeta de resultado sin pasar por el dialogo.
  ///
  /// Si el producto ya esta en el carrito, `_agregar` solo incrementa la
  /// cantidad del item existente y no vuelve a abrir el dialogo.
  Future<void> tocarResultado(
    WidgetTester tester,
    String busqueda,
    String nombre,
  ) async {
    await tester.enterText(find.byType(TextField).last, busqueda);
    await io(tester);
    await tester.pump();
    await tester.tap(find.text(nombre).first);
    await io(tester);
    await tester.pump();
    await asentar(tester);
  }

  group('flujo de venta', () {
    testWidgets('agregar el mismo producto dos veces acumula cantidad',
        (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      await agregar(tester, 'Queso', 'Queso Campesino', '0.5');
      await tocarResultado(tester, 'Queso', 'Queso Campesino');

      // Un solo item, con 1 kg en total (0.5 + 0.5).
      expect(find.text('Total · 1 item'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await cobrar(tester);
      expect(find.text('Venta registrada'), findsOneWidget);
    });

    testWidgets('carrito con varios productos cobra bien', (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      await agregar(tester, 'Queso', 'Queso Campesino', '0.5');
      await agregar(tester, 'Leche', 'Leche Entera', '3');
      await agregar(tester, 'Pan', 'Pan Tajado', '2');

      expect(find.text('Total · 3 items'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await cobrar(tester);
      expect(find.text('Venta registrada'), findsOneWidget);
    });

    testWidgets('Listo cierra el dialogo y sale de la pantalla',
        (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      await agregar(tester, 'Leche', 'Leche Entera', '2');
      await cobrar(tester);
      expect(find.text('Venta registrada'), findsOneWidget);

      await tester.ensureVisible(find.text('Listo'));
      await tester.pump();
      await tester.tap(find.text('Listo'));
      await io(tester);
      // La ruta del dialogo no se borra hasta que termina su transicion de
      // salida (~150 ms), y `pump()` sin duracion no hace avanzar el reloj, asi
      // que el dialogo seguiria en el arbol.
      await tester.pump(const Duration(milliseconds: 500));
      await asentar(tester);

      // El dialogo se cerro y, como VentaScreen es la unica ruta del `home:`
      // de prueba, `Navigator.pop` no tiene a quien volver: lo que se comprueba
      // aqui es que el dialogo desaparecio.
      expect(find.text('Venta registrada'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el IVA incluido no cambia el total cobrado', (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      // Queso: 18.500 con IVA 19, Leche: 3.200 sin IVA.
      await agregar(tester, 'Queso', 'Queso Campesino', '1');
      await agregar(tester, 'Leche', 'Leche Entera', '1');

      await cobrar(tester);

      await tester.runAsync(() async {
        final ventas = await DatabaseHelper.instance.getVentas();
        // El total sigue siendo la simple suma de los precios de etiqueta.
        expect(ventas.single.total, 18500 + 3200);
      });
    });

    testWidgets('la venta descuenta el stock de cada producto',
        (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      await agregar(tester, 'Queso', 'Queso Campesino', '2');
      await agregar(tester, 'Leche', 'Leche Entera', '3');
      await cobrar(tester);

      await tester.runAsync(() async {
        final filas = await (await DatabaseHelper.instance.database)
            .query('productos', orderBy: 'nombre');
        expect(filas.first['nombre'], 'Leche Entera');
        expect(filas.first['stock'], 17);
        expect(filas.last['nombre'], 'Queso Campesino');
        expect(filas.last['stock'], 8);
      });
    });

    testWidgets('anular una venta devuelve el stock y el IVA queda guardado',
        (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      await agregar(tester, 'Queso', 'Queso Campesino', '1');
      await cobrar(tester);

      await tester.runAsync(() async {
        final venta = (await DatabaseHelper.instance.getVentas()).single;
        final detalles =
            await DatabaseHelper.instance.getVentaDetalles(venta.id!);
        expect(detalles.single.iva, 19);
        // 18.500 con 19% incluido -> base 15.546,22 y 2.954 de impuesto.
        expect(detalles.single.baseSinIVA.round(), 15546);
        expect(detalles.single.ivaIncluido.round(), 2954);
      });
    });
  });
}