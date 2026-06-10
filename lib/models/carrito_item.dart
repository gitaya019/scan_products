import 'producto_model.dart';

class CarritoItem {
  Producto producto;
  double cantidad;

  CarritoItem({required this.producto, this.cantidad = 1.0});

  double get subtotal => producto.precio * cantidad;

  bool get esPorPeso => producto.ventaPorPeso;
}
