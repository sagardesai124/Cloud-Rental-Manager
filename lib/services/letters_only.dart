import 'dart:math' as math;

import 'package:flutter/services.dart';

final RegExp _lettersAndSpaces = RegExp(r'^[a-zA-Z\s]*$');

/// City / Country typing on Add and Edit Property, the same as web
/// (Rentals.jsx, used by Admin and Staff): what you type or paste must be
/// letters and spaces, otherwise the keystroke or paste is ignored and the
/// text stays as it was.
///
/// Only the NEW text is checked; what is already in the box is never
/// changed. So a saved city that has punctuation (e.g. "St. Louis" or
/// "Winston-Salem", which web's address search fills in) keeps it, and a
/// saved value like "N/A" can still be deleted. For any value without
/// punctuation this is exactly web's rule.
final TextInputFormatter typedLettersAndSpacesOnly =
    TextInputFormatter.withFunction((oldValue, newValue) {
  final before = oldValue.text;
  final after = newValue.text;
  final shorter = math.min(before.length, after.length);
  var start = 0;
  while (start < shorter &&
      before.codeUnitAt(start) == after.codeUnitAt(start)) {
    start++;
  }
  var end = 0;
  while (end < before.length - start &&
      end < after.length - start &&
      before.codeUnitAt(before.length - 1 - end) ==
          after.codeUnitAt(after.length - 1 - end)) {
    end++;
  }
  final added = after.substring(start, after.length - end);
  return _lettersAndSpaces.hasMatch(added) ? newValue : oldValue;
});
