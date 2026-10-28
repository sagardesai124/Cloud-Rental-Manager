import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/screens/Profile/Profile_screen.dart';

/// Admin › My Profile showed Created Date as the server's raw value
/// ("2026-09-22T16:16:04.328Z"). Web (Profile.jsx formatDateTime) shows the
/// same moment in the account's date and time format, in local time: QA's
/// value reads "09/22/2026 09:46:04 PM" on web in India (UTC+5:30).

Future<DateProvider> _provider(String dateFormat, String timeFormat) async {
  SharedPreferences.setMockInitialValues({});
  final provider = DateProvider();
  // Let the constructor's load finish before choosing the formats.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  provider.updateDateFormatLocally(dateFormat, 0);
  provider.updateTimeFormatLocally(timeFormat, 0);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('12-hour: account date format + hh:mm:ss AM/PM, like web', () async {
    final p = await _provider('MM/dd/yyyy', '12');
    expect(formatProfileCreatedDate(p, '2026-09-22 21:46:04'),
        '09/22/2026 09:46:04 PM');
    expect(formatProfileCreatedDate(p, '2026-09-22 09:05:07'),
        '09/22/2026 09:05:07 AM');
    expect(formatProfileCreatedDate(p, '2026-09-22 00:15:00'),
        '09/22/2026 12:15:00 AM');
  });

  test('24-hour with another account date format', () async {
    final p = await _provider('yyyy-MM-dd', '24');
    expect(formatProfileCreatedDate(p, '2026-09-22 21:46:04'),
        '2026-09-22 21:46:04');
  });

  test("the server's UTC value is shown in local time, like web", () async {
    final p = await _provider('MM/dd/yyyy', '12');
    final shown = formatProfileCreatedDate(p, '2026-09-22T16:16:04.328Z');
    expect(shown, isNot(contains('T16')));
    expect(shown, isNot(contains('Z')));
    final local = DateTime.utc(2026, 9, 22, 16, 16, 4, 328).toLocal();
    expect(shown, DateFormat('MM/dd/yyyy hh:mm:ss a').format(local));
    if (local.timeZoneOffset == const Duration(hours: 5, minutes: 30)) {
      expect(shown, '09/22/2026 09:46:04 PM',
          reason: "QA's value, exactly as web shows it in India");
    }
  });

  test('empty stays empty; a value that is not a date is left as is',
      () async {
    final p = await _provider('MM/dd/yyyy', '24');
    expect(formatProfileCreatedDate(p, null), '');
    expect(formatProfileCreatedDate(p, '   '), '');
    expect(formatProfileCreatedDate(p, 'N/A'), 'N/A');
  });

  test('Created Date is display-only like web: no asterisk, no required check',
      () {
    final src =
        File('lib/screens/Profile/Profile_screen.dart').readAsStringSync();
    expect(src, isNot(contains("'Created Date *'")));
    expect(RegExp(r"const Text\(\s*'Created Date',").hasMatch(src), isTrue,
        reason: 'label without the required marker');
    final start = src.indexOf("buildTextField(\n"
        "                                        'Created Date',");
    expect(start, isNonNegative);
    final call = src.substring(start, src.indexOf('),', start));
    expect(call, isNot(contains('isRequired: true')),
        reason: 'an empty read-only date must not block Update');
    expect(call, isNot(contains('_validate')));
    expect(call, contains('isEnabled: false'));
  });

  test('the screen formats Created Date on load and never saves it', () {
    final src =
        File('lib/screens/Profile/Profile_screen.dart').readAsStringSync();
    expect(src,
        contains('formatProfileCreatedDate(dateProvider, profileData.createdAt)'));
    expect(src, isNot(contains('_createdDate.text = profileData.createdAt')));
    // Display only: the profile save sends no createdAt (web drops it too).
    expect(RegExp(r'''['"]createdAt['"]''').hasMatch(src), isFalse);
  });
}
