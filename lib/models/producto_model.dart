import '../utils/precios.dart';
import '../utils/unidades.dart';

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

  /// Unidad en la que esta **cotizado** el precio.
  ///
  /// "5.000 por lb" -> `'lb'`.
  String? unidadMedida;

  /// Unidad en la que se **pese y se cuenta el stock**.
  ///
  /// Puede ser distinta de [unidadMedida]: la libra vale 5.000 pero la balanza
  /// del local lee gramos, asi que se captura 120 y se cobra la fraccion de
  /// libra que eso pesa. `null` significa "la misma que [unidadMedida]", que es
  /// lo que entienden los productos que ya estaban en la base.
  String? unidadVenta;

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
    this.unidadVenta,
    this.iva = 0.0,
    this.ventaPorPeso = false,
  });

  /// Unidad efectiva de venta, resolviendo el `null` heredado.
  String get unidad => ventaPorPeso
      ? (unidadVenta ?? unidadMedida ?? 'kg')
      : (unidadMedida ?? 'unidad');

  /// Unidad real en la que se expresa el precio.
  String get unidadPrecio => unidadMedida ?? 'unidad';

  /// Si la unidad de venta difiere de la del precio **y** hay conversion.
  ///
  /// Comprueba tambien que la conversion exista: si las unidades no son
  /// compatibles (masa contra volumen, o una unidad sin definir) no se toca el
  /// total, porque un factor inventado seria peor que no convertir.
  bool get necesitaConversion =>
      unidad != unidadPrecio &&
      Unidades.factor(origen: unidad, destino: unidadPrecio) != null;

  /// Que dice la equivalencia, o `null` si no hay conversion que explicar.
  String? get equivalencia => necesitaConversion
      ? Unidades.equivalencia(
          unidadVenta: unidad,
          unidadPrecio: unidadPrecio,
        )
      : null;

  /// Ganancia en pesos por unidad: precio de venta menos costo.
  double get ganancia => precio - costo;

  /// Margen de ganancia sobre el costo, en porcentaje.
  ///
  /// Devuelve 0 cuando el costo es 0 porque el margen seria infinito y no
  /// significa nada util para mostrar.
  double get margen => Precios.margenDesdePrecios(costo, precio);

  /// Parte del precio que es base gravable (precio sin IVA).
  double get baseSinIVA => Precios.precioSinIVA(precio, iva);

  /// Parte del precio que corresponde a impuesto.
  double get ivaContenido => Precios.ivaIncluido(precio, iva);

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
      'unidad_venta': unidadVenta,
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
      // Columna agregada en la v8. `null` se resuelve a la unidad del precio,
      // asi que los productos anteriores se comportan igual que antes.
      unidadVenta: map['unidad_venta'],
      iva: _aDoble(map['iva']),
      ventaPorPeso: map['venta_por_peso'] == 1,
    );
  }
}
