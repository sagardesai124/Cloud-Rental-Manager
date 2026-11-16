/// Property › Taxes & Insurance › Edit Insurance Premium / Edit Insurance
/// Policy, like web (PropDetails.jsx `hasInsurancePremiumChanges` and
/// `hasInsuranceChanges`): when editing, Update stays greyed out until
/// something differs from what the form was opened with.
library;

import 'package:flutter/services.dart';

/// "1234567" → "1,234,567": whole-dollar digits grouped by commas.
String _groupThousands(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A number written the way web's `String(number)` writes it: no ".0" on a
/// whole amount (2, not 2.0).
String _jsNumberText(double value) {
  if (value == 0) return '0';
  if (value == value.truncateToDouble() && value.abs() < 1e21) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

/// What Edit Insurance Premium shows for a saved premium, like web
/// (handleEditInsurancePremium: `String(roundToCents(stored))`): rounded to
/// cents, no trailing zeros, no commas. 2 shows "2" (not "2.00"), 2.5 shows
/// "2.5", 1500 shows "1500", 15.6666 shows "15.67". Text that is not a
/// number is shown as it is, as on web.
String insurancePremiumBoxText(Object? stored) {
  final text = stored?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return text;
  // Web's Math.round(value * 100) / 100 (premiums are never negative).
  return _jsNumberText((value * 100).roundToDouble() / 100);
}

/// What Edit Insurance Policy shows in Premium Amount and Deductible for a
/// saved amount, like web (formatNumber, then formatCurrencyInput): commas
/// between thousands, at most two decimals, no trailing zeros. 3 shows "3"
/// (not "3.0"), 1500 shows "1,500", 1234.5 shows "1,234.5"; no amount
/// leaves the box empty.
String insurancePolicyAmountBoxText(num? amount) {
  if (amount == null || amount.isNaN || amount.isInfinite) return '';
  final parts = amount.abs().toDouble().toStringAsFixed(2).split('.');
  final cents = parts[1].replaceFirst(RegExp(r'0+$'), '');
  final whole = _groupThousands(parts[0]);
  return cents.isEmpty ? whole : '$whole.$cents';
}

/// The largest premium web lets you type on Add/Edit Insurance Premium
/// (MAX_ANNUAL_EXPENSE_AMOUNT): a keystroke that goes past it is refused.
const double insurancePremiumMaxAmount = 999999999.99;

/// An amount box's text with the commas in place, the way web shows it:
/// commas between thousands, no leading zeros ("05" → "5"), and a "0"
/// before a leading ".". The cursor stays after the digit it was after.
/// Text that is not an amount is left as it is.
TextEditingValue insuranceAmountTidy(TextEditingValue value) {
  var raw = value.text.replaceAll(',', '');
  if (raw.isEmpty || !RegExp(r'^\d*\.?\d*$').hasMatch(raw)) return value;

  // Where the cursor is, counted in characters other than commas.
  final at = value.selection.isValid
      ? value.selection.extentOffset.clamp(0, value.text.length)
      : value.text.length;
  var cursor = value.text.substring(0, at).replaceAll(',', '').length;

  final zeros = RegExp(r'^0+(?=\d)').stringMatch(raw)?.length ?? 0;
  raw = raw.substring(zeros);
  cursor -= cursor < zeros ? cursor : zeros;
  if (raw.startsWith('.')) {
    raw = '0$raw';
    cursor++;
  }

  final dot = raw.indexOf('.');
  final text = dot < 0
      ? _groupThousands(raw)
      : '${_groupThousands(raw.substring(0, dot))}${raw.substring(dot)}';

  var offset = 0;
  for (var seen = 0; offset < text.length && seen < cursor; offset++) {
    if (text[offset] != ',') seen++;
  }
  return TextEditingValue(
      text: text, selection: TextSelection.collapsed(offset: offset));
}

/// Typing in an insurance amount box (Insurance Premium, and Premium Amount
/// and Deductible on Insurance Policy): digits with one "." and at most two
/// decimals, shown with commas between thousands as you type, like web
/// ("1,500"). Anything else is refused, as is going past [max] when it is
/// set.
class InsuranceAmountInputFormatter extends TextInputFormatter {
  const InsuranceAmountInputFormatter({this.max});

  /// The largest amount that can be typed; null for no limit.
  final double? max;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return const TextEditingValue();
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(raw)) return oldValue;
    final limit = max;
    if (limit != null && (double.tryParse(raw) ?? 0) > limit) return oldValue;
    return insuranceAmountTidy(newValue);
  }
}

/// Web's premium rule: Year and Carrier are compared trimmed; the premium is
/// compared as a number ("$" and commas ignored), so "1,200" and "1200.00"
/// are the same. A stored premium with more than two decimals (15.6666) that
/// the form shows rounded (15.67) counts as a change, so Update writes the
/// corrected amount, as on web.
bool insurancePremiumChanged({
  required String? year,
  required String carrier,
  required String premium,
  required String? originalYear,
  required String originalCarrier,
  required String originalPremium,
}) {
  if ((year ?? '').trim() != (originalYear ?? '').trim()) return true;
  if (carrier.trim() != originalCarrier.trim()) return true;

  String clean(String v) => v.replaceAll(r'$', '').replaceAll(',', '').trim();
  final current = clean(premium);
  final original = clean(originalPremium);
  if (current.isEmpty && original.isEmpty) return false;
  if (current.isEmpty || original.isEmpty) return true;
  final c = double.tryParse(current);
  final o = double.tryParse(original);
  if (c == null || o == null) return current != original;
  return (c - o).abs() > 1e-9;
}

/// Web's policy rule: any field differs from what the form was opened with.
bool formValuesChanged(
    Map<String, String?> current, Map<String, String?> original) {
  for (final key in {...current.keys, ...original.keys}) {
    if ((current[key] ?? '') != (original[key] ?? '')) return true;
  }
  return false;
}
