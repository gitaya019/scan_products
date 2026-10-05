import '../utils/precios.dart';

class VentaDetalle {
  int? id;
  int ventaId;
  int? productoId;
  String nombre;
  String? codigo;
  double precioUnitario;
  double cantidad;
  double subtotal;
  String? unidadMedida;

  /// Unidad en la que se capturo la [cantidad].
  ///
  /// Puede diferir de [unidadMedida] (precio por libra, cantidad en gramos).
  /// Se guarda para que el historial siga siendo legible meses despues, aunque
  /// el producto cambie de unidad.
  String? unidadVenta;

  bool ventaPorPeso;

  /// IVA como porcentaje. El [subtotal] ya lo incluye.
  double iva;

  VentaDetalle({
    this.id,
    required this.ventaId,
    this.productoId,
    required this.nombre,
    this.codigo,
    required this.precioUnitario,
    required this.cantidad,
    required this.subtotal,
    this.unidadMedida,
    this.unidadVenta,
    this.ventaPorPeso = false,
    this.iva = 0.0,
  });

  /// Parte del subtotal que corresponde a impuesto.
  double get ivaIncluido => Precios.ivaIncluido(subtotal, iva);

  /// Parte del subtotal que es base gravable.
  double get baseSinIVA => Precios.precioSinIVA(subtotal, iva);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venta_id': ventaId,
      'producto_id': productoId,
      'nombre': nombre,
      'codigo': codigo,
      'precio_unitario': precioUnitario,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'unidad_medida': unidadMedida,
      'unidad_venta': unidadVenta,
      'venta_por_peso': ventaPorPeso ? 1 : 0,
      'iva': iva,
    };
  }

  /// SQLite devuelve `int` cuando el valor no tiene decimales, asi que se
  /// normaliza a `double` antes de asignar.
  static double _aDoble(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse('$valor') ?? 0.0;
  }

  factory VentaDetalle.fromMap(Map<String, dynamic> map) {
    return VentaDetalle(
      id: map['id'],
      ventaId: map['venta_id'] ?? 0,
      productoId: map['producto_id'],
      nombre: map['nombre'] ?? '',
      codigo: map['codigo'],
      precioUnitario: _aDoble(map['precio_unitario']),
      cantidad: _aDoble(map['cantidad']),
      subtotal: _aDoble(map['subtotal']),
      unidadMedida: map['unidad_medida'],
      unidadVenta: map['unidad_venta'],
      ventaPorPeso: map['venta_por_peso'] == 1,
      // Columna agregada en la v8: en bases viejas llega null y el IVA queda
      // en 0, que es el valor correcto para las ventas ya registradas.
      iva: _aDoble(map['iva']),
    );
  }
}
