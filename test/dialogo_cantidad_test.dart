import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/screens/venta_screen.dart';
import 'package:scan_products/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_database.dart';

Future<void> io(WidgetTester t) =>
    t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));

/// Vuelve a correr la transicion de salida de la ruta.
///
/// `showDialog` devuelve en cuanto se hace `Navigator.pop`, pero el `Route`
/// sigue animandose su propio tiempo de transicion (~150 ms) con el arbol de
/// widgets **montado**. Es en esa ventana donde un `TextEditingController`
/// liberado demasiado pronto se lee todavia.
Future<void> transicionDeSalida(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
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
  }

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await io(tester);
    await tester.pump();
  }

  /// Abre el dialogo de cantidad buscando el producto.
  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).last, 'Leche');
    await io(tester);
    await tester.pump();
    await tester.tap(find.text('Leche Entera').first);
    await io(tester);
    await tester.pump();
    expect(find.text('Agregar'), findsOneWidget,
        reason: 'el dialogo de cantidad no se abrio');
  }

  group('ciclo de vida del controller del dialogo de cantidad', () {
    // Este es el bug reportado en el dispositivo:
    // "A TextEditingController was used after being disposed", seguido de
    // "'_dependents.isEmpty': is not true" y "'attached': is not true".
    testWidgets('no usa el controller disposed al confirmar', (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);
      await abrirDialogo(tester);

      await tester.tap(find.text('Agregar'));
      await transicionDeSalida(tester);

      expect(tester.takeException(), isNull,
          reason: 'el controller se disposteo con el dialogo todavia montado');
    });

    testWidgets('no usa el controller disposed al cancelar', (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);
      await abrirDialogo(tester);

      await tester.tap(find.text('Cancelar'));
      await transicionDeSalida(tester);

      expect(tester.takeException(), isNull,
          reason: 'el controller se disposteo con el dialogo todavia montado');
    });

    // El caso del log real: el teclado se levanta justo cuando se confirma.
    // El inset cambia el `MediaQuery`, el dialogo se reconstruye durante su
    // animacion de salida y el `TextField` vuelve a leer el controller.
    testWidgets('aguanta que el teclado se levante al confirmar',
        (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);
      await abrirDialogo(tester);

      await tester.tap(find.text('Agregar'));

      // El teclado sube durante la transicion de salida del dialogo.
      tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
      await transicionDeSalida(tester);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason:
              'reconstruir con el teclado arriba leyo el controller muerto');
    });

    testWidgets('el dialogo cabe con el teclado abierto', (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);
      await abrirDialogo(tester);

      // Con el teclado arriba queda poco alto, y el `AlertDialog` de Flutter
      // mete el contenido en un `Column` sin scroll: si no cabe, desborda.
      tester.view.viewInsets = const FakeViewPadding(bottom: 1400);
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'el dialogo desbordo con el teclado abierto');
    });

    testWidgets('varias veces seguidas no deja controllers muertos',
        (tester) async {
      await tester.runAsync(sembrar);
      await abrir(tester);

      for (var i = 0; i < 3; i++) {
        await abrirDialogo(tester);
        await tester.tap(find.text('Cancelar'));
        await transicionDeSalida(tester);
        expect(tester.takeException(), isNull, reason: 'en la vuelta $i');
      }
    });
  });
}
