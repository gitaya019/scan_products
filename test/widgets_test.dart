import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/data/categorias.dart';
import 'package:scan_products/models/marca.dart';
import 'package:scan_products/models/producto_model.dart';
import 'package:scan_products/theme/app_theme.dart';
import 'package:scan_products/widgets/categoria_selector.dart';
import 'package:scan_products/widgets/marca_selector.dart';
import 'package:scan_products/widgets/presentacion_selector.dart';
import 'package:scan_products/widgets/vista_previa_cobro.dart';

/// Monta un widget suelto en el tema por defecto.
///
/// No usa `pumpAndSettle`: los widgets de esta app viven bajo
/// `AuroraBackground`, que anima en bucle, y no hay frame estable. Aqui tampoco
/// hace falta: estos widgets no animan nada.
Future<void> _montar(WidgetTester tester, Widget hijo) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: hijo,
        )),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('CategoriaSelector', () {
    testWidgets('escribe, filtra y elige una predeterminada', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        CategoriaSelector(controller: controller),
      );

      // Escribir filtra: "ques" solo deja "Quesos".
      await tester.enterText(find.byType(TextFormField), 'ques');
      await tester.pump();
      expect(find.text('Quesos'), findsOneWidget);

      await tester.tap(find.text('Quesos'));
      await tester.pump();
      expect(controller.text, 'Quesos');
    });

    testWidgets('avisa que una categoria nueva se guardara asi', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        CategoriaSelector(
          controller: controller,
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'rancho');
      await tester.pump();
      expect(find.textContaining('Rancho'), findsWidgets);
    });

    testWidgets('la seccion desplegable no dispara aserciones al abrirla', (tester) async {
      // El `ListTile` del `ExpansionTile` pinta sobre el `Material` mas
      // cercano. Sin el `Material` intermedio que lo envuelve, Flutter tira la
      // asercion "ListTile background color or ink splashes may be invisible".
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        CategoriaSelector(
          controller: controller,
        ),
      );

      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('secciones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('Frescos'), findsOneWidget);
    });

    testWidgets('el validador se ejecuta dentro del Form', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();

      await _montar(
        tester,
        Form(
          key: formKey,
          child: CategoriaSelector(
            controller: controller,
            validator: (v) => (v == null || v.isEmpty) ? 'Falta' : null,
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.enterText(find.byType(TextFormField), 'Granos');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
    });

    testWidgets('las categorias del catalogo se pueden elegir todas', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        CategoriaSelector(controller: controller),
      );

      await tester.tap(find.textContaining('secciones'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Cuantas mas secciones, mas completo esta el catalogo.
      expect(find.text('Frescos'), findsOneWidget);
      expect(find.text('Mascotas'), findsOneWidget);
      expect(Categorias.todas.length, greaterThan(60));
    });
  });

  group('MarcaSelector', () {
    testWidgets('sugiere las marcas existentes', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        MarcaSelector(
          controller: controller,
          marcas: const [
            Marca(nombre: 'Alfa'),
            Marca(nombre: 'La Ramada'),
            Marca(nombre: 'Colgate'),
          ],
          onCrear: (_) {},
        ),
      );

      await tester.enterText(find.byType(TextField), 'al');
      await tester.pump();

      expect(find.text('Alfa'), findsOneWidget);
      await tester.tap(find.text('Alfa'));
      await tester.pump();
      expect(controller.text, 'Alfa');
    });

    testWidgets('busca sin tildes ni mayusculas', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        MarcaSelector(
          controller: controller,
          marcas: const [Marca(nombre: 'Café Dunois')],
          onCrear: (_) {},
        ),
      );

      await tester.enterText(find.byType(TextField), 'DUNOIS');
      await tester.pump();
      expect(find.text('Café Dunois'), findsOneWidget);
    });

    testWidgets('ofrece crear una marca que no existe', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? creada;

      await _montar(
        tester,
        MarcaSelector(
          controller: controller,
          marcas: const [Marca(nombre: 'Alfa')],
          onCrear: (n) => creada = n,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Nueva');
      await tester.pump();

      expect(find.text('Crear la marca "Nueva"'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Crear'));
      await tester.pump();
      expect(creada, 'Nueva');
    });

    testWidgets('no ofrece crear una marca que ya existe', (tester) async {
      final controller = TextEditingController(text: 'Alfa');
      addTearDown(controller.dispose);

      await _montar(
        tester,
        MarcaSelector(
          controller: controller,
          marcas: const [Marca(nombre: 'Alfa')],
          onCrear: (_) {},
        ),
      );

      expect(find.textContaining('Crear la marca'), findsNothing);
    });
  });

  group('UnidadVentaSelector', () {
    testWidgets('marca la unidad elegida', (tester) async {
      String elegida = 'lb';

      await _montar(
        tester,
        StatefulBuilder(
          builder: (context, setState) => UnidadVentaSelector(
            unidadPrecio: 'lb',
            unidadVenta: elegida,
            candidatas: const ['lb', 'g', 'kg'],
            onChanged: (v) => setState(() => elegida = v),
          ),
        ),
      );

      expect(find.text('lb'), findsOneWidget);
      await tester.tap(find.text('g'));
      await tester.pump();
      expect(elegida, 'g');
    });

    testWidgets('muestra la equivalencia para que se entienda el cobro', (tester) async {
      await _montar(
        tester,
        const UnidadVentaSelector(
          unidadPrecio: 'lb',
          unidadVenta: 'g',
          candidatas: ['lb', 'g', 'kg'],
          onChanged: _nada,
        ),
      );

      expect(find.textContaining('1 g = '), findsOneWidget);
    });

    testWidgets('sin conversion posible no muestra equivalencia', (tester) async {
      await _montar(
        tester,
        const UnidadVentaSelector(
          unidadPrecio: 'kg',
          unidadVenta: 'kg',
          candidatas: ['kg'],
          onChanged: _nada,
        ),
      );

      expect(find.textContaining('='), findsNothing);
    });
  });

  group('PresentacionSelector', () {
    testWidgets('las dos opciones quedan escritas, sin adivinar', (tester) async {
      bool porPeso = false;

      await _montar(
        tester,
        StatefulBuilder(
          builder: (context, setState) => PresentacionSelector(
            ventaPorPeso: porPeso,
            unidadMedida: 'kg',
            onChanged: (v) => setState(() => porPeso = v),
          ),
        ),
      );

      expect(find.text('Por unidades'), findsOneWidget);
      expect(find.text('Por peso o volumen'), findsOneWidget);

      await tester.tap(find.text('Por peso o volumen'));
      await tester.pump();
      expect(porPeso, isTrue);
    });
  });

  group('VistaPreviaCobro', () {
    Producto cebolla() => Producto(
          nombre: 'Cebolla',
          categoria: 'Verduras',
          precio: 5000,
          peso: 1,
          stock: 5000,
          unidadMedida: 'lb',
          unidadVenta: 'g',
          ventaPorPeso: true,
        );

    testWidgets('muestra cuanto se cobra segun lo que se escribe', (tester) async {
      final controller = TextEditingController(text: '120');
      addTearDown(controller.dispose);

      await _montar(
        tester,
        VistaPreviaCobro(producto: cebolla(), controller: controller),
      );

      // 120 g con la libra a 5.000 son 1.323, no 600.000.
      expect(find.text('Se cobra 1.323'), findsOneWidget);
    });

    testWidgets('explica de donde sale el total', (tester) async {
      final controller = TextEditingController(text: '120');
      addTearDown(controller.dispose);

      await _montar(
        tester,
        VistaPreviaCobro(producto: cebolla(), controller: controller),
      );

      expect(find.textContaining('equivale a'), findsOneWidget);
      expect(find.textContaining('lb a 5.000'), findsOneWidget);
    });

    testWidgets('sin cantidad escrita pide escribirla', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        VistaPreviaCobro(producto: cebolla(), controller: controller),
      );

      expect(find.textContaining('Escribe la cantidad'), findsOneWidget);
    });

    testWidgets('se actualiza sola al teclear', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await _montar(
        tester,
        // El `setState` real lo pone el dialogo; aqui se comprueba solo que el
        // widget lee el controller en cada build.
        StatefulBuilder(
          builder: (context, setState) => ListenableBuilder(
            listenable: controller,
            builder: (context, _) =>
                VistaPreviaCobro(producto: cebolla(), controller: controller),
          ),
        ),
      );

      expect(find.textContaining('Escribe la cantidad'), findsOneWidget);
      controller.text = '453';
      await tester.pump();
      // 453,59 g ~= una libra.
      // 453 / 453,59237 x 5.000 = 4.993,38 -> 4.993
      expect(find.text('Se cobra 4.993'), findsOneWidget);
    });

    testWidgets('sin conversion no inventa explicacion', (tester) async {
      final controller = TextEditingController(text: '2');
      addTearDown(controller.dispose);

      final producto = Producto(
        nombre: 'Leche',
        categoria: 'Lacteos',
        precio: 3500,
        peso: 1,
        stock: 10,
        unidadMedida: 'unidad',
      );

      await _montar(
        tester,
        VistaPreviaCobro(producto: producto, controller: controller),
      );

      expect(find.text('Se cobra 7.000'), findsOneWidget);
      expect(find.textContaining('equivale a'), findsNothing);
    });
  });
}

void _nada(String _) {}