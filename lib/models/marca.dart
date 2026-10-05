/// Marca de un producto (Alfa, La Ramada, Colgate...).
///
/// Es una entidad de apoyo, no un dato del producto: `productos.marca` sigue
/// siendo TEXT para que un producto escrito a mano no dependa de que exista la
/// fila. [Marca] solo alimenta el autocompletado del formulario.
class Marca {
  final int? id;
  final String nombre;
  final DateTime? createdAt;

  const Marca({this.id, required this.nombre, this.createdAt});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Marca.fromMap(Map<String, dynamic> map) {
    return Marca(
      id: map['id'],
      nombre: map['nombre'] ?? '',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'] as String),
    );
  }

  /// Deduplicacion sin tildes ni mayusculas.
  ///
  /// "Alfa" y "ALFA" tienen que ser la misma marca, o el autocompletado
  /// ofrece dos veces lo mismo.
  static String clave(String nombre) {
    const mapa = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', //
      'ü': 'u', 'ñ': 'n',
    };
    var salida = nombre.trim().toLowerCase();
    mapa.forEach((con, sin) => salida = salida.replaceAll(con, sin));
    return salida;
  }
}