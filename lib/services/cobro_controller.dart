import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/precios.dart';

/// Guarda el modo de redondeo del cobro entre sesiones.
///
/// Es un [ValueNotifier] como `ThemeController` y por el mismo motivo: un solo
/// consumidor de verdad (la pantalla de "Opciones de cobro") no justifica
/// traerse un paquete de inyeccion de dependencias.
///
/// ## Por que un [InheritedWidget] y no pasarlo por constructor
///
/// El modo lo necesita la barra lateral (para cambiarlo) y el punto de venta
/// (para aplicarlo). Pasarlo por constructor obligaria a threading un parametro
/// por `main` -> `HomeScreen` -> `VentaScreen`, mas todos los constructores de
/// las pruebas. [CobroScope] deja que cualquiera lo lea con
/// `CobroScope.of(context)` y que las pruebas que montan una pantalla suelta
/// sigan funcionando sin tocar nada.
class CobroController extends ValueNotifier<RedondeoCobro> {
  CobroController() : super(RedondeoCobro.sinRedondeo) {
    _cargar();
  }

  static const String _preferenceKey = 'redondeo_cobro';

  bool get redondea => value != RedondeoCobro.sinRedondeo;

  /// Aplica el modo elegido a un importe.
  double aplicar(double valor) => Precios.redondearCobro(valor, value);

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_preferenceKey);
      if (guardado != null) value = RedondeoCobro.desdeNombre(guardado);
    } catch (_) {
      // Si la preferencia falla se queda el modo por defecto: cobrar nunca
      // puede depender de que se haya podido leer una preferencia.
    }
  }

  Future<void> cambiar(RedondeoCobro modo) async {
    if (modo == value) return;
    value = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferenceKey, modo.name);
    } catch (_) {
      // Sin persistencia el modo dura lo que la sesion abierta.
    }
  }
}

/// Instancia de [CobroController] para el arbol de widgets.
///
/// [main] lo envuelve una vez sobre `MaterialApp`. Si no hay scope —una prueba
/// que monta `VentaScreen` suelta, por ejemplo— [of] devuelve un controller
/// recien creado en vez de fallar: la ausencia de configuracion tiene que
/// significar "sin redondeo", no un crash.
class CobroScope extends InheritedWidget {
  final CobroController controller;

  const CobroScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// Controller vigente. No crea dependencia mas alla del subtree.
  static CobroController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CobroScope>()?.controller ??
      _porDefecto();

  static CobroController _porDefecto() => CobroController();

  @override
  bool updateShouldNotify(CobroScope oldWidget) =>
      oldWidget.controller != controller;
}
