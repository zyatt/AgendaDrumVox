// lib/utils/formatters.dart

import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final DateFormat _dateShort = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dateLong = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');
  static final DateFormat _monthYear = DateFormat("MMMM 'de' yyyy", 'pt_BR');
  static final DateFormat _timeFormat = DateFormat('HH:mm');

  static String currency(double value) => _currency.format(value);

  static String dateShort(DateTime date) => _dateShort.format(date);

  static String dateLong(DateTime date) => _dateLong.format(date);

  static String monthYear(DateTime date) => _monthYear.format(date);

  static String time(DateTime date) => _timeFormat.format(date);

  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;

    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Amanhã';
    if (diff == -1) return 'Ontem';
    if (diff > 1 && diff <= 7) return 'Em $diff dias';
    if (diff < -1 && diff >= -7) return 'Há ${-diff} dias';
    return dateShort(date);
  }
}