import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'services/cobro_controller.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanProductsApp());
}

class ScanProductsApp extends StatefulWidget {
  const ScanProductsApp({super.key});

  @override
  State<ScanProductsApp> createState() => _ScanProductsAppState();
}

class _ScanProductsAppState extends State<ScanProductsApp> {
  final ThemeController _themeController = ThemeController();

  /// Modo de redondeo del cobro. Vive aqui por el mismo motivo que el tema:
  /// se crea una vez y se comparte por todo el arbol.
  final CobroController _cobroController = CobroController();

  @override
  void dispose() {
    _themeController.dispose();
    _cobroController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Solo vertical: la app es una herramienta de mostrador.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, mode, _) => CobroScope(
        controller: _cobroController,
        child: MaterialApp(
          title: 'Scan Products',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: HomeScreen(themeController: _themeController),
        ),
      ),
    );
  }
}
