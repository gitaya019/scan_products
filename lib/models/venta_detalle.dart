class VentaDetalle {
  int? id;
  int ventaId;
  int? productoId;
  String nombre;
  String codigo;
  double precioUnitario;
  double cantidad;
  double subtotal;

  VentaDetalle({
    this.id,
    required this.ventaId,
    this.productoId,
    required this.nombre,
    required this.codigo,
    required this.precioUnitario,
    required this.cantidad,
    required this.subtotal,
  });

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
    };
  }

  factory VentaDetalle.fromMap(Map<String, dynamic> map) {
    return VentaDetalle(
      id: map['id'],
      ventaId: map['venta_id'],
      productoId: map['producto_id'],
      nombre: map['nombre'],
      codigo: map['codigo'],
      precioUnitario: map['precio_unitario'],
      cantidad: (map['cantidad'] ?? 0).toDouble(),
      subtotal: map['subtotal'],
    );
  }
}
