import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/screens/add_producto_screen.dart';
import 'package:scan_products/screens/categorias_screen.dart';
import 'package:scan_products/screens/edit_producto_screen.dart';
import 'package:scan_products/screens/historial_ventas_screen.dart';
import 'package:scan_products/screens/home_screen.dart';
import 'package:scan_products/screens/reporte_ventas_screen.dart';
import 'package:scan_products/screens/venta_screen.dart';
import 'package:scan_products/services/database_helper.dart';
import 'package:scan_products/theme/app_theme.dart';
import 'package:scan_products/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_database.dart';

/// Monta una pantalla en el tema indicado y espera a que termine de cargar.
///
/// [pantalla] es un constructor porque `HomeScreen` recibe el
/// `ThemeController`. Recibe el mismo controller que usa el `MaterialApp`, tal
/// como hace `main.dart`, para que [brillo] mande de verdad sobre lo que se
/// renderiza.
///
/// Dos trampas del entorno de pruebas, ambas resueltas aqui:
///
/// * `testWidgets` corre dentro de una zona `FakeAsync`. `sqflite_common_ffi`
///   hace E/C real en otra hilo, asi que un `await` normal nunca completa y el
///   test se queda colgado. Hay que salir de la zona falsa con
///   [WidgetTester.runAsync].
/// * `AuroraBackground` anima en bucle infinito, asi que no hay frame estable
///   y `pumpAndSettle` se quedaria esperando hasta expirar. El pump es manual.
Future<void> montar(
  WidgetTester tester,
  Widget Function(ThemeController controlador) pantalla, {
  Brightness brillo = Brightness.dark,
  Size tamano = const Size(1080, 2400),
}) async {
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final controlador = ThemeController();
  addTearDown(controlador.dispose);
  controlador.value =
      brillo == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: controlador.value,
      home: pantalla(controlador),
    ),
  );

  // El primer frame dispara las consultas de `initState`.
  await tester.pump();
  // Las deja terminar contra la base real.
  await esperarCarga(tester);
  // Repinta ya con los datos cargados y deja morir las animaciones de entrada,
  // que si no dejan temporizadores vivos y el test falla con `!timersPending`.
  await tester.pump(const Duration(milliseconds: 900));
}

/// Espera a que la pantalla deje de mostrar su indicador de carga.
///
/// Cada pantalla encadena un numero distinto de consultas en `initState`, y cada
/// una es E/C real sobre `sqflite_common_ffi`. Fijar un numero de vueltas a
/// ciegas es fragil: con una sola, el test mira la pantalla todavia en el
/// `CircularProgressIndicator`; con diez, el archivo entero se vuelve lento.
/// Preguntar si ya cargo es exacto y sale en cuanto puede.
Future<void> esperarCarga(WidgetTester tester, {int max = 20}) async {
  for (var i = 0; i < max; i++) {
    await _dejarCorrerLaBase(tester);
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

/// Deja que la E/C real de la base de datos se resuelva.
///
/// Sale de la zona `FakeAsync` de `testWidgets`, pumps el event loop real y
/// vuelve a entrar. Sin esto cualquier consulta a `sqflite` cuelga el test.
Future<void> _dejarCorrerLaBase(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
}

/// Vacia las tablas y siembra tres productos que ejercitan los caminos
/// interesantes del catalogo: stock alto, stock bajo (dispara el aviso) y venta
/// por peso con stock fraccionario.
///
/// Devuelve los ids insertados.
Future<List<int>> prepararProductos(WidgetTester tester) async {
  final ids = <int>[];
  await tester.runAsync(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('venta_detalles');
    await db.delete('ventas');
    await db.delete('productos');
    // El catalogo se vuelve a llenar solo desde los productos que se siembran,
    // asi que se limpia para partir de un estado conocido.
    await db.delete('categorias');
    await db.delete('marcas');

    for (final producto in [
      Producto(
        nombre: 'Arroz Diana 500g',
        codigo: '7501234567890',
        categoria: 'Granos',
        precio: 12500,
        peso: 0.5,
        stock: 24,
        marca: 'Diana',
        unidadMedida: 'kg',
        ventaPorPeso: true,
        iva: 5,
      ),
      Producto(
        nombre: 'Leche Entera',
        codigo: '7509876543210',
        categoria: 'Lacteos',
        precio: 3200,
        peso: 1,
        stock: 3,
        unidadMedida: 'unidad',
      ),
      Producto(
        nombre: 'Queso Campesino',
        categoria: 'Lacteos',
        precio: 18500,
        peso: 0.25,
        stock: 0.5,
        unidadMedida: 'kg',
        ventaPorPeso: true,
      ),
    ]) {
      ids.add(await DatabaseHelper.instance.addProducto(producto.toMap()));
    }
  });
  return ids;
}

/// Vacia las tablas y deja el catalogo sin productos.
///
/// tambien limpia `categorias`: si no, la categoria que creo el test anterior
/// sigue ahi y el estado vacio que se quiere comprobar no aparece nunca.
Future<void> prepararVacio(WidgetTester tester) async {
  await tester.runAsync(() async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('venta_detalles');
    await db.delete('ventas');
    await db.delete('productos');
    await db.delete('categorias');
    await db.delete('marcas');
  });
}

Future<Producto> productoPorId(WidgetTester tester, int id) async {
  late Producto producto;
  await tester.runAsync(() async {
    final filas = await (await DatabaseHelper.instance.database).query(
      'productos',
      where: 'id = ?',
      whereArgs: [id],
    );
    producto = Producto.fromMap(filas.first);
  });
  return producto;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    inicializarBaseDeDatosDePrueba();
    DatabaseHelper.databasePath = ':memory:';
  });

  tearDownAll(() async => DatabaseHelper.instance.close());

  group('cada pantalla se renderiza sin desbordamientos', () {
    testWidgets('inventario con productos', (tester) async {
      await prepararProductos(tester);
      await montar(tester, (c) => HomeScreen(themeController: c));

      expect(find.text('Inventario'), findsOneWidget);
      expect(find.text('Arroz Diana 500g'), findsOneWidget);
      expect(find.text('Leche Entera'), findsOneWidget);
    });

    testWidgets('inventario vacio', (tester) async {
      await prepararVacio(tester);
      await montar(tester, (c) => HomeScreen(themeController: c));

      expect(find.text('Inventario vacio'), findsOneWidget);
    });

    testWidgets('punto de venta', (tester) async {
      await prepararProductos(tester);
      await montar(tester, (_) => const VentaScreen());

      expect(find.text('Nueva venta'), findsOneWidget);
      expect(find.text('Escanear producto'), findsOneWidget);
    });

    testWidgets('alta de producto', (tester) async {
      await prepararProductos(tester);
      await montar(tester, (_) => const AddProductoScreen());

      expect(find.text('Nuevo producto'), findsOneWidget);
    });

    testWidgets('edicion de producto', (tester) async {
      final ids = await prepararProductos(tester);
      final producto = await productoPorId(tester, ids.last);
      await montar(tester, (_) => EditProductoScreen(producto: producto));

      expect(find.text('Editar producto'), findsOneWidget);
    });

    // Los formularios son un `ListView`: en un movil normal el boton de
    // eliminar queda por debajo del pliegue y el widget ni siquiera se
    // construye. Con una ventana alta se laysoutea el formulario entero, que
    // es donde aparecen los desbordamientos largos.
    testWidgets('alta de producto completa', (tester) async {
      await prepararProductos(tester);
      await montar(
        tester,
        (_) => const AddProductoScreen(),
        // Con el panel de precios (costo, margen, IVA y vista previa) y los
        // selectores de categoria y marca, el formulario quedo mas alto; la
        // ventana tiene que crecer con el para que el boton siga construyendo
        // sin scroll.
        tamano: const Size(1080, 6000),
      );

      expect(find.text('Guardar producto'), findsOneWidget);
    });

    testWidgets('edicion de producto completa', (tester) async {
      final ids = await prepararProductos(tester);
      final producto = await productoPorId(tester, ids.last);
      await montar(
        tester,
        (_) => EditProductoScreen(producto: producto),
        tamano: const Size(1080, 7000),
      );

      expect(find.text('Eliminar producto'), findsWidgets);
    });

    testWidgets('historial de ventas vacio', (tester) async {
      await prepararProductos(tester);
      await montar(tester, (_) => const HistorialVentasScreen());

      expect(find.text('Historial de ventas'), findsOneWidget);
      expect(find.text('Sin ventas todavía'), findsOneWidget);
    });

    testWidgets('reporte de ventas', (tester) async {
      await prepararProductos(tester);
      await montar(tester, (_) => const ReporteVentasScreen());

      expect(find.text('Reporte de ventas'), findsOneWidget);
      expect(find.text('INGRESOS DEL MES'), findsOneWidget);
    });

    testWidgets('categorias', (tester) async {
      await prepararProductos(tester);
      await montar(tester, (_) => const CategoriasScreen());

      expect(find.text('Categorias'), findsOneWidget);
      // `prepararProductos` siembra dos productos en "Lacteos", asi que el
      // catalogo debe traerla con su conteo y no como "Sin productos".
      expect(find.text('Lacteos'), findsOneWidget);
      expect(find.text('2 productos'), findsOneWidget);
    });

    testWidgets('categorias sin catalogo', (tester) async {
      await prepararVacio(tester);
      await montar(tester, (_) => const CategoriasScreen());

      expect(find.text('Sin categorias'), findsOneWidget);
    });
  });

  group('el tema claro renderiza lo mismo', () {
    testWidgets('inventario claro', (tester) async {
      await prepararProductos(tester);
      await montar(
        tester,
        (c) => HomeScreen(themeController: c),
        brillo: Brightness.light,
      );

      expect(find.text('Arroz Diana 500g'), findsOneWidget);
    });

    testWidgets('punto de venta claro', (tester) async {
      await prepararProductos(tester);
      await montar(
        tester,
        (_) => const VentaScreen(),
        brillo: Brightness.light,
      );

      expect(find.text('Nueva venta'), findsOneWidget);
    });

    testWidgets('reporte claro', (tester) async {
      await prepararProductos(tester);
      await montar(
        tester,
        (_) => const ReporteVentasScreen(),
        brillo: Brightness.light,
      );

      expect(find.text('INGRESOS DEL MES'), findsOneWidget);
    });

    testWidgets('categorias claro', (tester) async {
      await prepararProductos(tester);
      await montar(
        tester,
        (_) => const CategoriasScreen(),
        brillo: Brightness.light,
      );

      expect(find.text('Lacteos'), findsOneWidget);
    });
  });
}
