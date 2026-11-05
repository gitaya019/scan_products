import 'package:flutter/material.dart';

/// Controla el modo claro/oscuro de la app.
///
/// La app siempre inicia en modo claro ([ThemeMode.light]). El usuario
/// puede alternar a modo oscuro en cualquier momento durante la sesión
/// desde el interruptor del menú lateral.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light);

  bool get isDark => value == ThemeMode.dark;

  void toggle() {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
