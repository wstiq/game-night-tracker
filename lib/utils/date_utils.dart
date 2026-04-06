const _months = [
  'янв','фев','мар','апр','май','июн',
  'июл','авг','сен','окт','ноя','дек',
];

String formatNightTitle(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return 'Вечер ${dt.day} ${_months[dt.month - 1]} ${dt.year}, $hh:$mm';
}

String formatDate(DateTime dt) {
  final d  = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  return '$d.$mo.${dt.year}';
}

String formatDateTime(DateTime dt) {
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '${formatDate(dt)} $hh:$mm';
}

String formatRubles(double amount) {
  final abs = amount.abs().toInt();
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('\u202f');
    buf.write(s[i]);
  }
  return '${buf.toString()} ₽';
}
