import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

/// Settings → Date Format → "HOW IT APPEARS" shows the time with seconds,
/// like web (DateFormatSection.jsx: " HH:mm:ss" / " hh:mm:ss A"). Before, it
/// showed "2026-10-23 15:45" / "3:45 PM" while the time options above it
/// already showed seconds.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('24-hour: date plus HH:mm:ss', () {
    final p = DateProvider();
    p.updateDateFormatLocally('yyyy-MM-dd', 1);
    p.updateTimeFormatLocally('24', 0);
    expect(p.getFormattedDateTimePreview(),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$')));
  });

  test('12-hour: date plus hh:mm:ss AM/PM with a leading zero', () {
    final p = DateProvider();
    p.updateDateFormatLocally('yyyy-MM-dd', 1);
    p.updateTimeFormatLocally('12', 1);
    expect(p.getFormattedDateTimePreview(),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2} (0[1-9]|1[0-2]):\d{2}:\d{2} (AM|PM)$')));
  });

  test('only the Settings preview uses it', () {
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) =>
            f.readAsStringSync().contains('getFormattedDateTimePreview('))
        .map((f) => f.path)
        .toList()
      ..sort();
    expect(users, [
      'lib/provider/dateProvider.dart',
      'lib/screens/Profile/Settings_screen.dart',
    ]);
  });
}
