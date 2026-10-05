import 'venta_detalle.dart';

class Venta {
  int? id;
  double total;
  String fecha;
  String estado;
  List<VentaDetalle>? detalles;

  Venta({
    this.id,
    required this.total,
    required this.fecha,
    this.estado = 'completada',
    this.detalles,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total': total,
      'fecha': fecha,
      'estado': estado,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    final total = map['total'];
    return Venta(
      id: map['id'],
      total: total is num ? total.toDouble() : 0.0,
      fecha: map['fecha'] ?? '',
      estado: map['estado'] ?? 'completada',
    );
  }
}
