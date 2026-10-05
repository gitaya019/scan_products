/// Categorias predeterminadas para una tienda de abarrotes.
///
/// No es una lista copiada de un catalogo oficial: es la estructura de
/// merchandising que usan los puntos de venta de la Distribucion minorista de
/// alimentacion (abarrotes y supermercado de barrio), agrupada por los lugares
/// fisicos donde el cliente busca el producto.
///
/// Se ofrecen como atajos en el formulario, pero el campo sigue siendo texto
/// libre: si una tienda necesita "Extras" o "Rancho" lo escribe y queda.
///
/// Nombres sin tildes de forma intencional, igual que el resto del texto de la
/// app.
class Categorias {
  const Categorias._();

  /// Categorias agrupadas por seccion. El orden de cada grupo va de lo mas
  /// buscado a lo menos buscado.
  static const List<Map<String, List<String>>> porSeccion = [
    {
      'Frescos': [
        'Frutas',
        'Verduras',
        'Carnes',
        'Pescados',
        'Pollo',
        'Huevos',
        'Panaderia',
        'Lacteos',
        'Quesos',
      ],
    },
    {
      'Abarrotes': [
        'Granos',
        'Arroz',
        'Pastas',
        'Harina y panificacion',
        'Azucar y salsas',
        'Aceites y vinagres',
        'Enlatados',
        'Conservas',
        'Cafe y te',
        'Fideos y sopas',
      ],
    },
    {
      'Snacks y dulces': [
        'Galletas',
        'Chocolates',
        'Confiteria',
        'Chips y papas',
        'Frutos secos',
        'Barras energeticas',
      ],
    },
    {
      'Bebidas': [
        'Gaseosas',
        'Agua',
        'Jugos',
        'Bebidas energeticas',
        'Cerveza',
        'Bebidas alcoholicas',
        'Tequila y mezcal',
      ],
    },
    {
      'Limpieza y aseo': [
        'Detergente',
        'Suavizante',
        'Blanqueador',
        'Jabones de loza',
        'Limpia pisos',
        'Papel higienico',
        'Toallas de cocina',
        'Bolsas de basura',
      ],
    },
    {
      'Higiene personal': [
        'Shampoo',
        'Jabon de cuerpo',
        'Crema dental',
        'Desodorante',
        'Cuidado facial',
      ],
    },
    {
      'Casa': [
        'Utensilios de cocina',
        'Vajilla',
        'Muebles',
        'Decoracion',
        'Ferreteria',
      ],
    },
    {
      'Mascotas': [
        'Comida para perros',
        'Comida para gatos',
        'Arena para gatos',
        'Accesorios para mascotas',
      ],
    },
    {
      'Infantil': [
        'Pañales',
        'Leche infantil',
        'Papel higienico infantil',
        'Juguetes',
      ],
    },
    {
      'Otros': [
        'Congelados',
        'Comida rapida',
        'Panaderia congelada',
        'Varios',
      ],
    },
  ];

  /// Todas las categorias en una sola lista, sin repetir y en orden de
  /// aparicion, listas para un `DropdownButton`.
  static List<String> get todas {
    final lista = <String>[];
    for (final grupo in porSeccion) {
      for (final categoria in grupo.values.first) {
        if (!lista.contains(categoria)) lista.add(categoria);
      }
    }
    return lista;
  }

  /// Busca coincidencias parciales, para el filtro del selector.
  ///
  /// Sin acentos ni mayusculas, asi que "lacte" encuentra "Lacteos" y "QUESO"
  /// encuentra "Quesos".
  static List<String> buscar(String texto, {int limite = 12}) {
    final t = texto.trim().toLowerCase();
    if (t.isEmpty) return todas.take(limite).toList();

    return todas
        .where((c) => c.toLowerCase().contains(t))
        .take(limite)
        .toList();
  }

  /// Nombre "bonito" a partir de lo que el usuario escribió en minusculas.
  ///
  /// "quesos" -> "Quesos", "panaderia" -> "Panaderia". Si la categoria ya existe
  /// en la lista devuelve la version oficial, para no crear "Lacteos" y
  /// "lácteos" como dos categorias distintas.
  static String normalizar(String texto) {
    final limpio = texto.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (limpio.isEmpty) return '';

    for (final oficial in todas) {
      if (oficial.toLowerCase() == limpio.toLowerCase()) return oficial;
    }

    return limpio[0].toUpperCase() + limpio.substring(1);
  }
}