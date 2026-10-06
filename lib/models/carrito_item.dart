import '../utils/precios.dart';
import '../utils/unidades.dart';
import 'producto_model.dart';

class CarritoItem {
  Producto producto;

  /// Cantidad tal como la capturo el usuario, en [Producto.unidad].
  ///
  /// 120 para una cebolla de 120 g, aunque el precio este por libra.
  double cantidad;

  /// Como se redondea [subtotal]. Lo elige el tendero en "Opciones de cobro".
  ///
  /// Vive en la linea y no solo en el total porque si se redondease solo el
  /// total, la suma de las lineas del ticket no daria lo que se cobro y el
  /// cliente podria reclamarlo con razon.
  ///
  /// Es mutable a proposito: si el usuario cambia el ajuste con la venta
  /// abierta, el punto de venta reasigna el modo a las lineas que ya estan en el
  /// carrito. Dejarlo fijo mezclaria dos reglas en un mismo total.
  RedondeoCobro redondeo;

  CarritoItem({
    required this.producto,
    this.cantidad = 1.0,
    this.redondeo = RedondeoCobro.sinRedondeo,
  });

  /// Cantidad expresada en la unidad en la que esta cotizado el producto.
  ///
  /// 120 g -> 0,24 lb. Si no hay conversion posible devuelve la cantidad tal
  /// cual, porque un factor inventado seria peor que no convertir.
  double get cantidadEnUnidadPrecio => producto.necesitaConversion
      ? Unidades.aUnidadPrecio(
          cantidad,
          unidadVenta: producto.unidad,
          unidadPrecio: producto.unidadPrecio,
        )
      : cantidad;

  /// Precio de una unidad de [Producto.unidad].
  ///
  /// Si el precio esta en otra unidad hay que escalarlo para poder multiplicar
  /// por la cantidad capturada. Por eso 5.000 por lb son 10 por g.
  double get precioUnitarioVenta => producto.necesitaConversion
      ? producto.precio *
          Unidades.aUnidadPrecio(
            1,
            unidadVenta: producto.unidad,
            unidadPrecio: producto.unidadPrecio,
          )
      : producto.precio;

  /// Total de la linea, ya redondeado al modo de cobro elegido.
  double get subtotal =>
      Precios.redondearCobro(precioUnitarioVenta * cantidad, redondeo);

  bool get esPorPeso => producto.ventaPorPeso;

  /// Texto que aclara el cobro cuando las unidades no coinciden.
  ///
  /// "120 g a 11,02 el g" en vez de solo "120 g", que con un precio de 5.000
  /// por libra suena a 600.000.
  String? get notaConversion {
    if (!producto.necesitaConversion) return null;
    return '${formatear(cantidad)} ${producto.unidad} × '
        '${formatear(precioUnitarioVenta)} el ${producto.unidad}';
  }

  static String formatear(double valor) {
    if (valor == valor.roundToDouble()) return valor.toInt().toString();
    return valor
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '')
        .replaceAll('.', ',');
  }
}
