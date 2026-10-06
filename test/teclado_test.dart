import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/screens/categorias_screen.dart';
import 'package:scan_products/screens/marcas_screen.dart';
import 'package:scan_products/screens/venta_screen.dart';
import 'package:scan_products/services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_database.dart';

Future<void> io(WidgetTester t) =>
    t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));

Future<void> asentar(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Deja terminar una recarga que lee de la base.
///
/// Alterna `runAsync` (donde el I/O real puede avanzar) y `pump` (donde el
/// `setState` del widget se aplica). Pump solo no basta: el `await` se queda
/// colgado en el `FakeAsync`; `runAsync` solo no basta: el `setState` que
/// depende de el queda pendiente.
Future<void> recargar(WidgetTester tester, {int vueltas = 4}) async {
  for (var i = 0; i < vueltas; i++) {
    await io(tester);
    await tester.pump();
    await asentar(tester);
  }
}

/// Espera a que [finder] aparezca, alternando reloj real y artificial.
///
/// Un numero fijo de vueltas es una apuesta: la recarga de una pantalla encadena
/// varias lecturas de la base y la cantidad de `pump` que hacen falta depende de
/// cuantas hay pendientes. Aqui se espera a la condicion y se usa el numero de
/// vueltas solo como techo, para que un fallo se reporte en vez de colgarse.
///
/// El orden importa. `pump` solo no avanza el I/O de `sqflite`; `runAsync` solo
/// no aplica el `setState` que depende de el. Hay que alternar.
Future<void> esperarHasta(
  WidgetTester tester,
  Finder finder, {
  int vueltas = 15,
}) async {
  for (var i = 0; i < vueltas; i++) {
    await asentar(tester);
    await io(tester);
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// Vuelca **todas** las excepciones pendientes, no solo la primera.
///
/// `tester.takeException()` devuelve la primera y las demas las reporta el
/// binding al final, todas juntas. Forma tipica del bug que se busca aqui: la
/// primera excepcion es util, pero las que la siguen ("_dependents.isEmpty",
/// "'attached': is not true") son las que dicen que widget se rompio.
///
/// Nota: no se sustituye `FlutterError.onError` para esto. El binding de
/// pruebas lo necesita para registrar la excepcion pendiente, y tragarsela a
/// mano hace fallar el test con "'_pendingExceptionDetails != null': A test
/// overrode FlutterError.onError...", que dice menos que el error real.
List<String> drenar(WidgetTester tester) {
  final errores = <String>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    errores.add(e.toString().split('\n').first);
    if (errores.length > 20) break;
  }
  return errores;
}

/// Si el campo de texto de la pantalla sigue con el foco.
///
/// Es la forma de preguntar "¿sigue abierto el teclado?" sin depender del IME:
/// un `EditableText` con foco es lo que mantiene abierta la vista de insercion
/// en Android.
bool _enfocado(WidgetTester tester) {
  final editables = tester.widgetList<EditableText>(find.byType(EditableText));
  return editables.isNotEmpty && editables.first.focusNode.hasFocus;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    inicializarBaseDeDatosDePrueba();
    DatabaseHelper.databasePath = ':memory:';
  });

  tearDown(() => DatabaseHelper.instance.close());

  Future<void> sembrar() => DatabaseHelper.instance.addProducto(
        Producto(
          nombre: 'Leche Entera',
          codigo: '7509876543210',
          categoria: 'Abastos',
          peso: 1,
          costo: 2000,
          precio: 3200,
          stock: 20,
          unidadMedida: 'unidad',
          iva: 0,
        ).toMap(),
      );

  void ajustarPantalla(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('venta completa con el teclado abierto', (tester) async {
    await tester.runAsync(sembrar);
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await recargar(tester);

    // El teclado aparece **despues** de escribir, que es como pasa en un
    // mostrador. Ademas lo hace solo: los dialogos de cantidad y de cobro abren
    // con `autofocus`, asi que el `viewInsets` cambia mientras la ruta acaba de
    // montarse sin que nadie lo pida a mano.
    await tester.enterText(find.byType(TextField).last, 'Leche');
    await recargar(tester);
    expect(find.text('Leche Entera'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pump();

    await tester.tap(find.text('Leche Entera').first);
    await asentar(tester);
    expect(find.text('Agregar'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '2');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await asentar(tester);

    await tester.tap(find.text('Cobrar'));
    await recargar(tester);
    expect(find.text('METODO DE PAGO'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '10000');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await recargar(tester, vueltas: 6);

    expect(find.text('Venta registrada'), findsOneWidget);

    // El teclado baja al confirmar, mientras las rutas siguen cerrandose: es
    // justo el momento en que el `MediaQuery` de los dialogos cambia por
    // segunda vez con los controllers ya liberados.
    tester.view.viewInsets = FakeViewPadding.zero;
    await asentar(tester);

    await tester.tap(find.text('Listo'));
    await asentar(tester);

    expect(drenar(tester), isEmpty,
        reason: 'la venta con teclado lanzo excepciones');
  });

  testWidgets('anular el cobro con el teclado abierto no registra nada',
      (tester) async {
    await tester.runAsync(sembrar);
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await recargar(tester);

    await tester.enterText(find.byType(TextField).last, 'Leche');
    await recargar(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pump();

    await tester.tap(find.text('Leche Entera').first);
    await asentar(tester);
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await asentar(tester);

    await tester.tap(find.text('Cobrar'));
    await recargar(tester);

    // Cancelar con el teclado abierto es la combinacion que mas falla: el
    // dialogo se pops y el `viewInsets` sigue cambiando durante la salida.
    await tester.tap(find.text('Cancelar'));
    await asentar(tester);

    expect(drenar(tester), isEmpty,
        reason: 'cancelar el cobro con teclado lanzo excepciones');
    expect(find.text('METODO DE PAGO'), findsNothing);

    final ventas = await tester.runAsync(
      () => DatabaseHelper.instance.getVentas(),
    );
    expect(ventas, isEmpty, reason: 'no se debe registrar una venta anulada');
  });

  testWidgets('el teclado no se cierra mientras se busca', (tester) async {
    await tester.runAsync(sembrar);
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await recargar(tester);

    // Enfocar el campo es lo que abre el teclado en un celular real.
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();
    await asentar(tester);

    await tester.enterText(find.byType(TextField).first, 'Leche');
    await recargar(tester);

    expect(_enfocado(tester), isTrue,
        reason: 'el teclado se escondio mientras se escribia');

    await esperarHasta(tester, find.text('Leche Entera'));
    expect(find.text('Leche Entera'), findsOneWidget);
    expect(drenar(tester), isEmpty);
  });

  testWidgets('el campo de busqueda no se recrea al abrir el teclado',
      (tester) async {
    await tester.runAsync(sembrar);
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await recargar(tester);

    final nodoAntes =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;

    // Abrir el teclado oculta la zona de escaneo. Ese cambio **no** puede tocar
    // el `TextField`: un `Column` empareja sus hijos por posicion, y quitar el
    // primero reconstruye todos los siguientes en otro hueco. El `FocusNode`
    // vive en el `State` del `TextField`, asi que un `TextField` recreado
    // pierde el foco — y con el se cierra el teclado a mitad de la busqueda,
    // que es justo lo que hacia que el usuario no pudiera buscar.
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await asentar(tester);

    final nodoDespues =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(identical(nodoAntes, nodoDespues), isTrue,
        reason: 'el campo de busqueda se reconstruyo al abrir el teclado');

    // Cerrarlo tampoco: la zona de escaneo vuelve a su lugar.
    tester.view.viewInsets = FakeViewPadding.zero;
    await asentar(tester);

    expect(
      identical(
        nodoAntes,
        tester.widget<EditableText>(find.byType(EditableText)).focusNode,
      ),
      isTrue,
      reason: 'el campo de busqueda se reconstruyo al cerrar el teclado',
    );
    expect(drenar(tester), isEmpty);
  });

  testWidgets('cobro insuficiente avisa y no cobra', (tester) async {
    await tester.runAsync(sembrar);
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: VentaScreen()));
    await recargar(tester);

    await tester.enterText(find.byType(TextField).last, 'Leche');
    await recargar(tester);
    await tester.tap(find.text('Leche Entera').first);
    await asentar(tester);
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await asentar(tester);

    await tester.tap(find.text('Cobrar'));
    await recargar(tester);

    // El producto vale 3.200: un billete de 2.000 no alcanza.
    await tester.enterText(find.byType(TextField).last, '2000');
    await tester.pump();
    await tester.tap(find.text('Confirmar'));
    await asentar(tester);

    expect(find.textContaining('Faltan'), findsOneWidget);
    expect(find.text('METODO DE PAGO'), findsOneWidget,
        reason: 'el dialogo debe seguir abierto');

    expect(drenar(tester), isEmpty);
  });

  testWidgets('renombrar categoria con el teclado abierto', (tester) async {
    await tester.runAsync(sembrar);
    await tester
        .runAsync(() => DatabaseHelper.instance.agregarCategoria('Abastos'));

    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: CategoriasScreen()));
    await esperarHasta(tester, find.text('Abastos'));

    expect(find.text('Abastos'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.edit_rounded).first);
    await asentar(tester);
    expect(find.text('Renombrar categoria'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Leches y quesos');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await asentar(tester);

    expect(drenar(tester), isEmpty,
        reason: 'renombrar categoria con teclado lanzo excepciones');

    await esperarHasta(tester, find.text('Leches y quesos'));
    expect(find.text('Leches y quesos'), findsOneWidget);
  });

  testWidgets('crear categoria con el teclado abierto', (tester) async {
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: CategoriasScreen()));
    await recargar(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pump();

    await tester.tap(find.text('Nueva'));
    await asentar(tester);
    expect(find.text('Nueva categoria'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Frescos');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await asentar(tester);

    expect(drenar(tester), isEmpty,
        reason: 'crear categoria con teclado lanzo excepciones');

    await esperarHasta(tester, find.text('Frescos'));
    expect(find.text('Frescos'), findsOneWidget);
  });

  testWidgets('crear marca con el teclado abierto', (tester) async {
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: MarcasScreen()));
    await recargar(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pump();

    await tester.tap(find.text('Nueva'));
    await asentar(tester);
    expect(find.text('Nueva marca'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Alfa');
    await tester.pump();
    await tester.tap(find.text('Agregar'));
    await asentar(tester);

    expect(drenar(tester), isEmpty,
        reason: 'crear marca con teclado lanzo excepciones');

    await esperarHasta(tester, find.text('Alfa'));
    expect(find.text('Alfa'), findsOneWidget);
  });

  testWidgets('cancelar el dialogo de categoria con el teclado abierto',
      (tester) async {
    ajustarPantalla(tester);

    await tester.pumpWidget(const MaterialApp(home: CategoriasScreen()));
    await recargar(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pump();

    await tester.tap(find.text('Nueva'));
    await asentar(tester);

    await tester.enterText(find.byType(TextField).last, 'Frutas');
    await tester.pump();
    await tester.tap(find.text('Cancelar'));
    await asentar(tester);

    expect(drenar(tester), isEmpty,
        reason: 'cancelar con teclado lanzo excepciones');
    expect(find.text('Nueva categoria'), findsNothing);
  });
}
