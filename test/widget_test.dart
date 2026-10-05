import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan_products/main.dart';
import 'package:scan_products/theme/app_theme.dart';

import 'helpers/test_database.dart';

void main() {
  setUpAll(inicializarBaseDeDatosDePrueba);

  testWidgets('la app arranca mostrando el inventario', (tester) async {
    await tester.pumpWidget(const ScanProductsApp());
    await tester.pump();

    expect(find.text('Inventario'), findsOneWidget);
  });

  test('los dos temas se construyen con la luminosidad correcta', () {
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.brightness, Brightness.light);
  });

  test('el tema oscuro usa la paleta neona', () {
    final scheme = AppTheme.dark.colorScheme;
    expect(scheme.primary, AppColors.neonViolet);
    expect(scheme.secondary, AppColors.neonCyan);
  });
}
