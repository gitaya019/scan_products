import 'package:intl/intl.dart';

/// Formatea un numero como pesos colombianos sin decimales.
/// Ej: 12500 -> "12.500"
///
/// No usa `currency` porque con `symbol: ''` deja un espacio (normalmente
/// inseparable) entre el numero y el simbolo vacio, que ensucia los valores.
///
/// El redondeo a enteros se hace aqui porque `decimalPattern` no acepta
/// `decimalDigits` como parametro con nombre.
String formatCurrency(double value) {
  final format = NumberFormat.decimalPattern('es_CO');
  return format.format(value.round());
}

/// Convierte texto de precio a double, ignorando cualquier caracter no numerico.
double parseCurrency(String value) {
  final cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(cleanedValue) ?? 0.0;
}

/// Formatea una cantidad de stock segun si el producto se vende por peso.
/// Enteros sin decimales, decimales con una sola cifra.
String formatCantidad(double cantidad, {required bool porPeso}) {
  if (!porPeso) return cantidad.toInt().toString();
  if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
  return cantidad.toStringAsFixed(1);
}

/// Etiqueta del campo de cantidad segun unidad de medida.
String labelCantidad({required bool porPeso, String? unidadMedida}) {
  if (!porPeso) return 'Cantidad';
  final unidad = unidadMedida;
  if (unidad == null || unidad.isEmpty) return 'Cantidad';
  switch (unidad) {
    case 'kg':
    case 'g':
    case 'lb':
      return 'Peso ($unidad)';
    case 'L':
    case 'mL':
      return 'Volumen ($unidad)';
    default:
      return 'Cantidad ($unidad)';
  }
}

/// Etiqueta del campo de stock segun si el producto se vende por peso.
String labelStock({required bool porPeso, String? unidadMedida}) {
  if (porPeso) return 'Stock ($unidadMedida)';
  return 'Stock (unidades)';
}

/// Fecha legible para historial: "12 mar 2026, 09:41"
String formatFecha(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;

  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', //
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  const dias = [
    'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom', //
  ];

  final hora = dt.hour.toString().padLeft(2, '0');
  final minuto = dt.minute.toString().padLeft(2, '0');
  return '${dias[dt.weekday - 1]} ${dt.day} ${meses[dt.month - 1]} ${dt.year}, $hora:$minuto';
}
