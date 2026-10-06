import 'package:flutter/material.dart';

/// Como se pago una venta.
///
/// Vive en la propia enumeracion y no en un `String` suelto porque cada metodo
/// decide una cosa distinta: [efectivo] tiene un billete que entra y un vuelto
/// que sale, [nequi] no tiene ninguno de los dos. Anadir un metodo nuevo obliga
/// a decidir ambas cosas, que es justo lo que se quiere que pase en vez de
/// descubrirlo en el momento de cobrar.
///
/// El valor persistido en `ventas.metodo_pago` es el `name` (`efectivo`,
/// `nequi`), no el indice: reordenar el enum no debe cambiar lo que hay
/// guardado en la base.
enum MetodoPago {
  efectivo,
  nequi;

  /// Texto corto para el selector.
  String get etiqueta => switch (this) {
        MetodoPago.efectivo => 'Efectivo',
        MetodoPago.nequi => 'Nequi',
      };

  /// Icono del selector. Va aqui y no en la pantalla para que las dos salidas
  /// que lo usan (el dialogo de cobro y la ficha de la venta) sean identicas.
  IconData get icono => switch (this) {
        MetodoPago.efectivo => Icons.payments_rounded,
        MetodoPago.nequi => Icons.phone_iphone_rounded,
      };

  /// Si hay que pedir el billete recibido para poder calcular el vuelto.
  ///
  /// Un pago por Nequi ya se recibe exacto: preguntar cuanto le dieron al
  /// cajero no tiene sentido.
  bool get pideVuelto => this == MetodoPago.efectivo;

  /// Subtexto del selector, para explicar que se hace con ese metodo.
  String get ayuda => switch (this) {
        MetodoPago.efectivo => 'Pide el billete y calcula el vuelto',
        MetodoPago.nequi => 'Pago exacto, sin vuelto',
      };

  /// Convierte lo guardado en la base. Un valor desconocido cae en
  /// [MetodoPago.efectivo], que es lo que usa la mayoria de las tiendas.
  static MetodoPago desdeNombre(String? nombre) {
    for (final metodo in MetodoPago.values) {
      if (metodo.name == nombre) return metodo;
    }
    return MetodoPago.efectivo;
  }
}
