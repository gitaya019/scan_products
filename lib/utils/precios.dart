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

  /// Redondea [valor] segun el modo de cobro elegido en los ajustes.
  ///
  /// El redondeo a pesos ([RedondeoCobro.sinRedondeo]) siempre ocurre: es el
  /// piso, no una opcion. Los otros dos modos llevan la cifra a un numero que
  /// se pueda dictar por teléfono sin dudar.
  ///
  /// - [RedondeoCobro.multiploDe50] es el mas cercano: 927 -> 950, 980 -> 1.000.
  /// - [RedondeoCobro.techoCien] siempre sube: 924 -> 1.000, 9.823 -> 9.900.
  ///
  /// Ojo con [RedondeoCobro.techoCien]: es agresivo a proposito. Un producto de
  /// 300 pesos pasa a 400. Quien quiera un redondeo que solo ajuste la ultima
  /// cifra tiene [RedondeoCobro.multiploDe50].
  static double redondearCobro(
    double valor, [
    RedondeoCobro modo = RedondeoCobro.sinRedondeo,
  ]) {
    // Primero a pesos enteros: en COP no hay centimos, y esto evita que el ruido
    // de punto flotante (`0.1 + 0.2`) termine en un peso de mas al dividir entre
    // el paso de redondeo.
    final pesos = redondearMoneda(valor);
    if (pesos <= 0) return 0;

    switch (modo) {
      case RedondeoCobro.sinRedondeo:
        return pesos;
      case RedondeoCobro.multiploDe50:
        return (pesos / 50).round() * 50;
      case RedondeoCobro.techoCien:
        // `ceil` a secas sube de mas lo que ya es multiplo exacto, porque
        // 9.800 / 100 puede dar 97,99999999999999 en punto flotante. Comparar
        // contra el entero ya redondeado distingue los dos casos sin `epsilon`.
        final paso = (pesos / 100).round();
        return paso * 100 >= pesos ? paso * 100 : (paso + 1) * 100;
    }
  }

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
  static double baseDeLineas(
      Iterable<({double subtotal, double tasa})> lineas) {
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

/// Como se redondea una cifra al cobrar.
///
/// Se elige en "Opciones de cobro" (barra lateral) y se guarda entre sesiones.
/// El valor por defecto es [sinRedondeo]: la app no cambia los numeros que ya
/// funcionan, el redondeo es una decision del tendero, no un comportamiento
/// impuesto.
enum RedondeoCobro {
  /// Solo pesos enteros. Lo que hacia la app antes.
  sinRedondeo,

  /// Al multiplo de 50 mas cercano. 927 -> 950, 980 -> 1.000, 10.737 -> 10.750.
  multiploDe50,

  /// Siempre hacia arriba a la siguiente centena. 924 -> 1.000, 9.823 -> 9.900.
  techoCien;

  /// Texto corto para el selector.
  String get etiqueta => switch (this) {
        RedondeoCobro.sinRedondeo => 'Sin redondeo',
        RedondeoCobro.multiploDe50 => 'Multiplos de 50',
        RedondeoCobro.techoCien => 'Subir a la centena',
      };

  /// Una linea de ejemplo con el modo aplicado, para que el tendero vea el
  /// efecto antes de activarlo en una venta real.
  String get ejemplo => switch (this) {
        RedondeoCobro.sinRedondeo => '927 queda 927',
        RedondeoCobro.multiploDe50 => '927 queda 950 · 980 queda 1.000',
        RedondeoCobro.techoCien => '924 queda 1.000 · 9.823 queda 9.900',
      };

  /// Valor persistido. Se guarda el `name` para no depender del orden del enum.
  static RedondeoCobro desdeNombre(String? nombre) {
    for (final modo in RedondeoCobro.values) {
      if (modo.name == nombre) return modo;
    }
    return RedondeoCobro.sinRedondeo;
  }
}
