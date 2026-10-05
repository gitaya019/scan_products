import '../utils/precios.dart';
import '../utils/unidades.dart';
import 'producto_model.dart';

class CarritoItem {
  Producto producto;

  /// Cantidad tal como la capturo el usuario, en [Producto.unidad].
  ///
  /// 120 para una cebolla de 120 g, aunque el precio este por libra.
  double cantidad;

  CarritoItem({required this.producto, this.cantidad = 1.0});

  /// Cantidad expresada en la unidad en la que esta cotizado el producto.
  ///
  /// 120 g -> 0,2646 lb. Si no hay conversion posible devuelve la cantidad tal
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
  /// por la cantidad capturada. Por eso 5.000 por lb son 11,02 por g.
  double get precioUnitarioVenta => producto.necesitaConversion
      ? producto.precio *
          Unidades.aUnidadPrecio(
            1,
            unidadVenta: producto.unidad,
            unidadPrecio: producto.unidadPrecio,
          )
      : producto.precio;

  /// Total de la linea, ya redondeado a pesos.
  double get subtotal =>
      Precios.redondearMoneda(precioUnitarioVenta * cantidad);

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
