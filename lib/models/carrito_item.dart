import 'producto_model.dart';

class CarritoItem {
  Producto producto;
  int cantidad;

  CarritoItem({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}
