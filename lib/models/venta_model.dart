import 'venta_detalle.dart';

class Venta {
  int? id;
  double total;
  String fecha;
  List<VentaDetalle>? detalles;

  Venta({this.id, required this.total, required this.fecha, this.detalles});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total': total,
      'fecha': fecha,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    return Venta(
      id: map['id'],
      total: map['total'],
      fecha: map['fecha'],
    );
  }
}
