import 'package:intl/intl.dart';

class CurrencyUtils {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _formatterDecimal = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String format(num? amount, {bool showDecimal = false}) {
    if (amount == null) return '₹0';
    return showDecimal ? _formatterDecimal.format(amount) : _formatter.format(amount);
  }

  static String formatPlain(num? amount) {
    if (amount == null) return '0';
    return NumberFormat.decimalPattern('en_IN').format(amount);
  }
}
