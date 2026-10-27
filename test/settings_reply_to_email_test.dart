import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/screens/Profile/Settings_screen.dart';

/// Settings → Email Services: the Reply-To address is checked like web
/// (Settings.jsx validateReplyToEmail) before saving. Empty is allowed;
/// anything typed must look like name@domain.tld, otherwise web's message
/// "Please enter a valid email address." shows and nothing is saved.
/// Before, the app saved anything (e.g. "abc@test") and every tenant email
/// then used that Reply-To. Staff uses this same Settings screen.

void main() {
  test('same rule as web', () {
    for (final ok in [
      '',
      '   ',
      'owner@example.com',
      'Leasing.Team+replies@mercantile-rentals.co.uk',
      ' owner@example.com ',
    ]) {
      expect(isValidReplyToEmail(ok), isTrue, reason: '"$ok" is valid');
    }
    for (final bad in [
      'abc@test',
      'abc',
      'abc@',
      '@example.com',
      'abc@example.c',
      'abc example@test.com',
    ]) {
      expect(isValidReplyToEmail(bad), isFalse, reason: '"$bad" is invalid');
    }
    expect(kInvalidReplyToEmailMessage, 'Please enter a valid email address.');
  });

  test('Save checks the Reply-To address before saving', () {
    final src = File('lib/screens/Profile/Settings_screen.dart').readAsStringSync();
    final guard = src.indexOf('if (!isValidReplyToEmail(replyToEmail.text)) {');
    expect(guard, greaterThan(0));
    final save = src.indexOf('await updateMail();', guard);
    expect(save, greaterThan(guard), reason: 'check runs before saving');
    expect(src.substring(guard, save), contains('return;'),
        reason: 'an invalid address stops the save');
    expect(src, contains('_replyToEmailError!'), reason: 'message shown under the field');
  });
}
