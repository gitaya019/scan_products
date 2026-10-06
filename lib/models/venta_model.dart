import 'metodo_pago.dart';
import 'venta_detalle.dart';

class Venta {
  int? id;
  double total;
  String fecha;
  String estado;
  List<VentaDetalle>? detalles;

  /// Como se cobro (v10). Las ventas anteriores a la v10 se leen como
  /// [MetodoPago.efectivo], que es lo que se uso antes de que existiera el dato.
  MetodoPago metodoPago;

  /// Billete que entrego el cliente, o `null` si no se registro.
  ///
  /// No es el total: es lo que llego a la mano. Para un pago exacto de Nequi se
  /// guarda `null` en vez de copiar el total, porque "no aplica" y "llego
  /// exactamente este monto" no son el mismo dato y en un cierre de caja se
  /// necesita distinguirlos.
  double? recibido;

  Venta({
    this.id,
    required this.total,
    required this.fecha,
    this.estado = 'completada',
    this.metodoPago = MetodoPago.efectivo,
    this.recibido,
    this.detalles,
  });

  /// Vuelto a devolver, o `null` si no hay dato de billete.
  ///
  /// Nunca negativo: si el billete no alcanza, el problema es del cobro y se
  /// avisa antes de guardar, no algo que un `0` pueda esconder.
  double? get vuelto {
    if (recibido == null) return null;
    final diferencia = (recibido! - total).roundToDouble();
    return diferencia < 0 ? 0 : diferencia;
  }

  /// `true` si la venta se cobro en efectivo.
  bool get esEfectivo => metodoPago == MetodoPago.efectivo;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total': total,
      'fecha': fecha,
      'estado': estado,
      'metodo_pago': metodoPago.name,
      'recibido': recibido,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map) {
    final total = map['total'];
    final recibido = map['recibido'];
    return Venta(
      id: map['id'],
      total: total is num ? total.toDouble() : 0.0,
      fecha: map['fecha'] ?? '',
      estado: map['estado'] ?? 'completada',
      metodoPago: MetodoPago.desdeNombre(map['metodo_pago'] as String?),
      recibido: recibido is num ? recibido.toDouble() : null,
    );
  }
}
