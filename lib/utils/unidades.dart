/// Conversion entre unidades de masa, volumen y conteo.
///
/// Existe porque el precio y la cantidad pueden vivir en unidades distintas:
/// un producto puede estar **cotizado por libra** y pesarse en la balanza en
/// **gramos** (una cebolla de 120 g). Sin esta tabla el total seria
/// `5000 * 120`, que es 45 veces lo que vale.
/// ## Dos unidades, no una
///
/// Un producto tiene dos unidades distintas y confundirlas es el bug que esta
/// clase viene a evitar:
///
/// - **unidad del precio**: en la que esta cotizado. "5.000 por lb".
/// - **unidad de venta**: en la que se pesa y se cuenta el stock. "120 g".
///
/// La cantidad se captura en `unidadVenta` y se convierte a `unidadPrecio` para
/// cobrar. Con una sola unidad, escribir 120 g en la balanza daria
/// `5000 * 120 = 600.000` en vez de 1.323.
class Unidades {
  const Unidades._();

  /// Todas las unidades que admite un producto.
  static const List<String> todas = [
    'unidad', 'kg', 'g', 'lb', 'L', 'mL', 'paquete', 'caja', //
  ];

  /// Unidades de masa, en gramos.
  static const Map<String, double> _masa = {
    'kg': 1000,
    'g': 1,
    'lb': 453.59237,
  };

  /// Unidades de volumen, en mililitros.
  static const Map<String, double> _volumen = {
    'L': 1000,
    'mL': 1,
  };

  /// Unidades de conteo: no son convertibles, solo comparables consigo mismas.
  static const Set<String> _conteo = {'unidad', 'paquete', 'caja'};

  static bool esConteo(String unidad) => _conteo.contains(unidad);

  static bool esMasa(String unidad) => _masa.containsKey(unidad);

  static bool esVolumen(String unidad) => _volumen.containsKey(unidad);

  /// Factor para pasar de [origen] a [destino].
  ///
  /// `null` cuando la conversion no tiene sentido fisico: de masa a volumen, o
  /// entre unidades de conteo distintas (`paquete` -> `caja` requiere saber
  /// cuantas trae el paquete, dato que la app no tiene).
  static double? factor({required String origen, required String destino}) {
    if (origen == destino) return 1;

    if (_masa.containsKey(origen) && _masa.containsKey(destino)) {
      return _masa[origen]! / _masa[destino]!;
    }
    if (_volumen.containsKey(origen) && _volumen.containsKey(destino)) {
      return _volumen[origen]! / _volumen[destino]!;
    }
    return null;
  }

  /// Convierte [cantidad] de [origen] a [destino].
  ///
  /// Si la conversion no es valida devuelve la cantidad sin tocar, para que un
  /// dato raro nunca multiplique el total por un factor inventado.
  static double convertir(
    double cantidad, {
    required String origen,
    required String destino,
  }) {
    final f = factor(origen: origen, destino: destino);
    return f == null ? cantidad : cantidad * f;
  }

  /// Convierte la cantidad capturada en la balanza a la unidad en la que se
  /// cobra el producto.
  ///
  /// `120` gramos con el precio por libra -> `0,2646` libras.
  static double aUnidadPrecio(
    double cantidad, {
    required String unidadVenta,
    required String unidadPrecio,
  }) =>
      convertir(
        cantidad,
        origen: unidadVenta,
        destino: unidadPrecio,
      );

  /// Texto corto que explica la equivalencia, o `null` si no hay conversion.
  ///
  /// Se muestra en el formulario para que quede claro que escribir "120" en la
  /// balanza se cobra como una fraccion de libra, no como 120 de algo.
  static String? equivalencia({
    required String unidadVenta,
    required String unidadPrecio,
  }) {
    if (unidadVenta == unidadPrecio) return null;
    final f = factor(origen: unidadVenta, destino: unidadPrecio);
    if (f == null) return null;

    // "1 g = 0,0022 lb" se lee mejor que "1 g = 0.00220462 lb".
    final texto = f.toStringAsFixed(f < 0.01 ? 6 : 4).replaceAll('.', ',');
    return '1 $unidadVenta = $texto $unidadPrecio';
  }

  /// Si la unidad admite decimales.
  ///
  /// Las unidades de conteo son enteras (`3 unidades`), pero las medidas si los
  /// aceptan: `0,250 kg` es un cuarto de kilo y `0,5 lb` media libra.
  static bool admiteDecimales(String unidad) => !esConteo(unidad);
}
