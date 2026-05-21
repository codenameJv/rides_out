import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  static final _compact = NumberFormat.compactCurrency(symbol: '₱', decimalDigits: 0);

  static String format(double amount) => _currency.format(amount);

  static String compact(double amount) {
    if (amount < 1000) return _currency.format(amount);
    return _compact.format(amount);
  }

  static String remaining(double budget, double spent) {
    final remaining = budget - spent;
    if (remaining < 0) {
      return '-${_currency.format(-remaining)}';
    }
    return _currency.format(remaining);
  }

  static double percentSpent(double budget, double spent) {
    if (budget <= 0) return 0;
    return (spent / budget).clamp(0.0, 1.0);
  }
}
