/// One CSV line for a report export, quoted the way web's CSV exports are:
/// a value that contains a comma, a double quote or a line break is wrapped
/// in double quotes (inner quotes doubled), so `$3,000.00` or
/// `Miami, Florida, 33131` stays in one column and every row keeps the
/// header's column count.
String csvRow(Iterable<Object?> cells) => cells.map(csvCell).join(',');

/// One CSV value, quoted only when it has to be.
String csvCell(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r')) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
