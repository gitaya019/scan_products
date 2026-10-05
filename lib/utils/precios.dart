import 'dart:math' as math;

/// Matematica de precios, IVA y margen.
///
/// ## Convencion de IVA
///
/// En este proyecto el **precio de venta ya incluye el IVA**. El cliente paga
/// exactamente el precio que ve en la etiqueta, y el IVA unicamente se extrae
/// para efectos de informacion (cuanto impuesto contiene cada venta) y de
/// reporte. Por eso [precioSinIVA] nunca cambia el total cobrado.
///
/// La tasa se maneja como porcentaje (19 = 19%).
class Precios {
  const Precios._();

  /// Precio base sin IVA, a partir de un precio que si lo incluye.
  ///
  /// precio 11.900 con tasa 19 -> 10.000
  static double precioSinIVA(double precio, double tasa) {
    if (tasa <= 0) return precio;
    return precio / (1 + tasa / 100);
  }

  /// Parte del [precio] que corresponde a impuesto.
  ///
  /// precio 11.900 con tasa 19 -> 1.900
  static double ivaIncluido(double precio, double tasa) {
    if (tasa <= 0) return 0;
    return precio - precioSinIVA(precio, tasa);
  }

  /// Precio de venta a partir del costo y el margen de ganancia esperado.
  ///
  /// El margen se aplica sobre el **costo**, que es la convencion que usa el
  /// comercio: "le gano el 30%" significa 30% sobre lo que me costo.
  ///
  /// costo 10.000 con margen 30 -> 13.000 (y ese precio ya incluye IVA)
  static double precioDesdeCosto(double costo, double margen) {
    return redondearMoneda(costo * (1 + margen / 100));
  }

  /// Margen de ganancia que representa un precio sobre un costo.
  ///
  /// Es la operacion inversa de [precioDesdeCosto]. Si el costo es 0 devuelve
  /// 0 en vez de infinito, porque un costo desconocido no da informacion util.
  static double margenDesdePrecios(double costo, double precio) {
    if (costo <= 0) return 0;
    return (precio - costo) / costo * 100;
  }

  /// Ganancia en pesos: cuanto queda por encima del costo.
  static double ganancia(double costo, double precio) => precio - costo;

  /// Redondea a pesos enteros.
  ///
  /// Los precios en COP no manejan centimos, y un precio como 13_456.78 se
  /// guarda, se multiplica por cantidades y produce subtotales con decimales
  /// que el cliente nunca ve pero que si se acumulan en el reporte.
  static double redondearMoneda(double valor) => valor.roundToDouble();

  /// IVA acumulado de una venta con lineas de tasas distintas.
  ///
  /// Cada linea puede tener un IVA distinto (0, 5, 10, 19), asi que se extrae
  /// linea por linea y se suma. Devuelve 0 si no hay lineas con impuesto.
  static double ivaDeLineas(Iterable<({double subtotal, double tasa})> lineas) {
    var total = 0.0;
    for (final linea in lineas) {
      total += ivaIncluido(linea.subtotal, linea.tasa);
    }
    return redondearMoneda(total);
  }

  /// Base gravable de una venta con lineas de tasas distintas.
  static double baseDeLineas(Iterable<({double subtotal, double tasa})> lineas) {
    var total = 0.0;
    for (final linea in lineas) {
      total += precioSinIVA(linea.subtotal, linea.tasa);
    }
    return redondearMoneda(total);
  }

  /// Tasa de IVA mas común, usada como punto de partida en los formularios.
  static const double tasaPorDefecto = 19;

  /// Tasas ofrecidas en el selector de IVA.
  static const List<double> tasasIVA = [0, 5, 10, 19];

  /// Convierte un porcentaje escrito por el usuario a `double`.
  ///
  /// Acepta "30", "30,5", "30.5" y descarta cualquier simbolo.
  ///
  /// La coma se trata como separador decimal antes de limpiarla: en Colombia
  /// "30,5" es cinco, no trescientos cinco. Sin esa conversion el panel de
  /// margen multiplicaba por diez al teclear con el teclado del celular, que en
  /// muchos equipos manda coma.
  static double parsePorcentaje(String texto) {
    final normalizado = texto.trim().replaceAll(',', '.');
    final esNegativo = normalizado.startsWith('-');
    final limpio = normalizado.replaceAll(RegExp(r'[^0-9.]'), '');

    final valor = double.tryParse(limpio) ?? 0;
    return math.min(math.max(esNegativo ? -valor : valor, 0), 9999);
  }
}