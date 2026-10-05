class Producto {
  int? id;
  String nombre;
  String? codigo;
  String categoria;
  double precio;

  /// Precio de compra del producto.
  ///
  /// Es opcional: se guarda para saber cuanto se gano por unidad, pero un
  /// producto puede existir sin costo conocido (0) y eso no debe romper nada.
  double costo;
  double peso;
  double stock;
  String? marca;
  String? unidadMedida;

  /// IVA como porcentaje (19 = 19%). El precio ya lo incluye.
  double iva;
  bool ventaPorPeso;

  Producto({
    this.id,
    required this.nombre,
    this.codigo,
    required this.categoria,
    required this.precio,
    this.costo = 0.0,
    required this.peso,
    this.stock = 0.0,
    this.marca,
    this.unidadMedida,
    this.iva = 0.0,
    this.ventaPorPeso = false,
  });

  /// Ganancia en pesos por unidad: precio de venta menos costo.
  double get ganancia => precio - costo;

  /// Margen de ganancia sobre el costo, en porcentaje.
  ///
  /// Devuelve 0 cuando el costo es 0 porque el margen seria infinito y no
  /// significa nada util para mostrar.
  double get margen => costo > 0 ? ganancia / costo * 100 : 0;

  /// Parte del precio que es base gravable (precio sin IVA).
  double get baseSinIVA => precio / (1 + iva / 100);

  /// Parte del precio que corresponde a impuesto.
  double get ivaContenido => precio - baseSinIVA;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo?.isEmpty == true ? null : codigo,
      'categoria': categoria,
      'precio': precio,
      'costo': costo,
      'peso': peso,
      'stock': stock,
      'marca': marca,
      'unidad_medida': unidadMedida,
      'iva': iva,
      'venta_por_peso': ventaPorPeso ? 1 : 0,
    };
  }

  /// Convierte un valor numerico de SQLite a `double`.
  ///
  /// SQLite devuelve `int` cuando el valor no tiene decimales, asi que
  /// `1` llega como `int` y hay que normalizarlo antes de asignarlo a un
  /// campo `double`.
  static double _aDoble(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse('$valor') ?? 0.0;
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      codigo: map['codigo'],
      categoria: map['categoria'] ?? '',
      precio: _aDoble(map['precio']),
      // La columna se agrego en la version 8, asi que en bases viejas el mapa
      // no la trae y el costo queda en 0 (producto sin costo conocido).
      costo: _aDoble(map['costo']),
      peso: _aDoble(map['peso']),
      stock: _aDoble(map['stock']),
      marca: map['marca'],
      unidadMedida: map['unidad_medida'],
      iva: _aDoble(map['iva']),
      ventaPorPeso: map['venta_por_peso'] == 1,
    );
  }
}
