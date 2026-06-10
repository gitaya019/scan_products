class Producto {
  int? id;
  String nombre;
  String codigo;
  String categoria;
  double precio;
  double peso;
  double stock;
  String? marca;
  String? unidadMedida;
  double iva;

  Producto({
    this.id,
    required this.nombre,
    required this.codigo,
    required this.categoria,
    required this.precio,
    required this.peso,
    this.stock = 0.0,
    this.marca,
    this.unidadMedida,
    this.iva = 0.0,
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
      'marca': marca,
      'unidad_medida': unidadMedida,
      'iva': iva,
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
      stock: (map['stock'] ?? 0).toDouble(),
      marca: map['marca'],
      unidadMedida: map['unidad_medida'],
      iva: (map['iva'] ?? 0.0).toDouble(),
    );
  }
}
