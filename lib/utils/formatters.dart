import 'package:intl/intl.dart';

String formatCurrency(double value) {
  final format =
      NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0);
  return format.format(value);
}

double parseCurrency(String value) {
  final cleanedValue = value.replaceAll(RegExp(r'[^0-9]'), '');
  return double.tryParse(cleanedValue) ?? 0.0;
}
