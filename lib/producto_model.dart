class Producto {
  int? id;
  String nombre;
  String codigo;
  String categoria;
  double precio;
  double peso;

  Producto({
    this.id,
    required this.nombre,
    required this.codigo,
    required this.categoria,
    required this.precio,
    required this.peso,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'categoria': categoria,
      'precio': precio,
      'peso': peso,
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
    );
  }
}
