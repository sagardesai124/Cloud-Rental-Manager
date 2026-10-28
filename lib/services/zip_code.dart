import 'package:flutter/services.dart';

/// Zip Code typing, the same as web's My Profile and Vendor Profile
/// (Profile.jsx / VendorProfile.jsx): only digits are kept; up to 5 digits as
/// typed, then ZIP+4 with the hyphen added automatically ("12345-6789"), at
/// most 9 digits.
final TextInputFormatter zipCodeFormatter =
    TextInputFormatter.withFunction((oldValue, newValue) {
  var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
  if (digits.length > 9) digits = digits.substring(0, 9);
  final text = digits.length <= 5
      ? digits
      : '${digits.substring(0, 5)}-${digits.substring(5)}';
  return TextEditingValue(
      text: text, selection: TextSelection.collapsed(offset: text.length));
});

/// Web's Zip Code check: 5 digits or ZIP+4, with web's messages. An empty
/// zip passes unless [required] (Vendor Profile requires it; My Profile
/// doesn't).
String? validateZipCode(String? value, {bool required = false}) {
  final zip = value?.trim() ?? '';
  if (zip.isEmpty) return required ? 'Zip code is required' : null;
  return RegExp(r'^\d{5}(-\d{0,4})?$').hasMatch(zip)
      ? null
      : 'Zip code must be 5 digits or 5+4 format';
}
