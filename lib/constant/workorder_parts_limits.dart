import 'package:flutter/services.dart';

/// Parts and Labor row limits on the work order forms, same as web
/// (PARTS_QTY_MAX = 9999 and the $999,999.99 price cap).
const double partsQtyMax = 9999;
const String partsQtyMaxMessage = 'Quantity cannot exceed 9,999';
const double partsPriceMax = 999999.99;
const String partsPriceMaxMessage = 'Price cannot exceed \$999,999.99';

/// Quantity box like web: digits only, at most 5 of them (one more than
/// 9999, so "Quantity cannot exceed 9,999" can show).
final List<TextInputFormatter> partsQtyInputFormatters = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(5),
];

/// Price box like web: keeps only digits and ".". On an iPhone set to a
/// comma-decimal region the decimal keypad's only separator is ",", so one
/// typed "," becomes the "." while there is no "." yet (12,50 → 12.50, not
/// 1250). Any other comma, like in a pasted "1,234.50", is dropped as on web
/// (1234.50).
final List<TextInputFormatter> partsPriceInputFormatters = [
  _TypedCommaIsDecimalPoint(),
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
];

class _TypedCommaIsDecimalPoint extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final old = oldValue.text;
    var start = oldValue.selection.start;
    var end = oldValue.selection.end;
    if (start < 0 || end > old.length) start = end = old.length;
    // One key: the old text with its selection (or just the cursor)
    // replaced by a single ",".
    final typedComma = newValue.text == old.replaceRange(start, end, ',');
    if (!typedComma || old.replaceRange(start, end, '').contains('.')) {
      return newValue;
    }
    return newValue.copyWith(text: old.replaceRange(start, end, '.'));
  }
}

/// Quantity rule web checks besides the cap: at least 1, so "0" is refused.
String? partsQtyCheck(String value) {
  if (value.isEmpty) return null;
  // num, not int: an older saved quantity such as "0.5" is below 1 too.
  final qty = num.tryParse(value);
  if (qty != null && qty < 1) return 'Quantity must be at least 1';
  return null;
}

/// Price rules web checks besides the cap, in web's order: "1.2.3" or "."
/// is not a number, "12.345" has too many decimals, and a price of 0 shows
/// "Price is required" (web checks that after the cap; 0 is never over the
/// cap, so checking it here gives the same message).
String? partsPriceCheck(String value) {
  if (value.isEmpty) return null;
  final price = double.tryParse(value);
  if (price == null) return 'Price must be a number';
  final parts = value.split('.');
  if (parts.length > 1 && parts[1].length > 2) {
    return 'Price can have at most 2 decimal places';
  }
  if (price <= 0) return 'Price is required';
  return null;
}
