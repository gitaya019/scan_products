class Producto {
  int? id;
  String nombre;
  String codigo;
  String categoria;
  double precio;
  double peso;
  int stock;

  Producto({
    this.id,
    required this.nombre,
    required this.codigo,
    required this.categoria,
    required this.precio,
    required this.peso,
    this.stock = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'categoria': categoria,
      'precio': precio,
      'peso': peso,
      'stock': stock,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      nombre: map['nombre'],
      codigo: map['codigo'],
      categoria: map['categoria'],
      precio: map['precio'],
      peso: map['peso'],
      stock: map['stock'],
    );
  }
}