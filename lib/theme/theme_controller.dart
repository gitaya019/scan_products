import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controla el modo claro/oscuro y lo persiste entre sesiones.
///
/// Se usa un [ValueNotifier] en lugar de un provider externo para no añadir
/// dependencias de inyeccion; la app es pequena y un solo consumidor basta.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.dark) {
    _cargar();
  }

  static const String _preferenceKey = 'tema_oscuro';

  bool get isDark => value == ThemeMode.dark;

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oscuro = prefs.getBool(_preferenceKey);
      if (oscuro != null) {
        value = oscuro ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (_) {
      // Si la preferencia falla, se mantiene el tema oscuro por defecto.
    }
  }

  Future<void> toggle() async {
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_preferenceKey, isDark);
    } catch (_) {
      // Sin persistencia la preferencia solo dura la sesion actual.
    }
  }
}
