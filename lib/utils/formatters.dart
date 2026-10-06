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

/// Texto del vuelto de un cobro en efectivo.
///
/// Tres casos y no dos: un vuelto negativo **no** es "0", es plata que falta.
/// Mostrarlo como `0` deja al cajero creyendo que entrego bien el cambio, y
/// ese error sale del local, no de la app.
String etiquetaVuelto(double total, double recibido) {
  final diferencia = (recibido - total).roundToDouble();
  if (diferencia < 0) return 'Faltan ${formatCurrency(-diferencia)}';
  // "Sin vuelto" y no "Vuelto 0": un cero en un ticket se lee como que falto
  // algo, y aqui no falto nada.
  if (diferencia == 0) return 'Sin vuelto';
  return 'Vuelto ${formatCurrency(diferencia)}';
}

/// Formatea una cantidad de stock segun si el producto se vende por peso.
/// Enteros sin decimales, decimales con una sola cifra.
String formatCantidad(double cantidad, {required bool porPeso}) {
  if (!porPeso) return cantidad.toInt().toString();
  if (cantidad == cantidad.roundToDouble()) return cantidad.toInt().toString();
  return cantidad.toStringAsFixed(1);
}

/// Etiqueta del campo de cantidad segun la unidad en la que se captura.
///
/// El stock y la cantidad del carrito se cuentan en `unidadVenta`, no en la del
/// precio, asi que la etiqueta usa la de venta.
String labelCantidad({required bool porPeso, String? unidadMedida}) {
  if (!porPeso) return 'Cantidad';
  return _labelMedida(unidadMedida);
}

/// Etiqueta del campo de stock segun si el producto se vende por peso.
String labelStock({required bool porPeso, String? unidadMedida}) {
  if (!porPeso) return 'Stock (unidades)';
  return 'Stock (${unidadMedida ?? 'unidad'})';
}

/// Que dice "Peso (kg)", "Volumen (L)" o "Cantidad (paquete)".
String _labelMedida(String? unidad) {
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
