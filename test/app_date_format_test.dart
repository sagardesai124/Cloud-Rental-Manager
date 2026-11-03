import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

/// The company's date format app-wide, like web's `themes.format`:
/// - web (moment) tokens ⇄ intl tokens;
/// - dates format exactly as web's `moment(d).format(fmt)`, moment-only
///   tokens (DDD day of the year) included;
/// - a date shown in the company format reads back to the server's
///   `yyyy-MM-dd` (strictly, so another format is never misread), through
///   both the shared [AppDateFormat] and the app's global [reverseFormatDate].
void main() {
  final d = DateTime(2026, 10, 28);

  tearDown(() => AppDateFormat.set(kDefaultAppDateFormat));

  group('token conversion (web ⇄ intl)', () {
    test('web → intl: D→d, Y→y, M unchanged', () {
      expect(AppDateFormat.toIntl('DD/MMM/YYYY'), 'dd/MMM/yyyy');
      expect(AppDateFormat.toIntl('M/D/YYYY'), 'M/d/yyyy');
      expect(AppDateFormat.toIntl('YYYY-MM-DD'), 'yyyy-MM-dd');
    });
    test('intl → web round-trips', () {
      for (final f in ['DD/MMM/YYYY', 'M/D/YYYY', 'MM-DD-YYYY', 'DDD/YYYY']) {
        expect(AppDateFormat.toWeb(AppDateFormat.toIntl(f)), f, reason: f);
      }
    });
    test('presets are web\'s three options only', () {
      expect(AppDateFormat.isPreset('MM/DD/YYYY'), isTrue);
      expect(AppDateFormat.isPreset('YYYY-MMM-DD'), isTrue);
      expect(AppDateFormat.isPreset('M/D/YYYY'), isFalse);
      expect(AppDateFormat.isPreset('DD/MMM/YYYY'), isFalse);
    });
  });

  group('format like web (moment)', () {
    // Expected values are what moment gives for 2026-10-28 (day 301).
    final cases = {
      'DD/MMM/YYYY': '28/Oct/2026',
      'DD-MM-YYYY': '28-10-2026',
      'M/D/YYYY': '10/28/2026',
      'MMMM D YYYY': 'October 28 2026',
      'YYYY-MM-DD': '2026-10-28',
      'DDD/YYYY': '301/2026',
      'DDDD-MM-YYYY': '0301-10-2026',
    };
    cases.forEach((web, expected) {
      test('$web → $expected', () {
        expect(AppDateFormat.format(d, AppDateFormat.toIntl(web)), expected);
      });
    });
    test('format() with no pattern uses the current company format', () {
      AppDateFormat.set('dd/MMM/yyyy');
      expect(AppDateFormat.format(d), '28/Oct/2026');
    });
  });

  group('read a shown date back to yyyy-MM-dd', () {
    test('custom DD/MMM/YYYY', () {
      AppDateFormat.set('dd/MMM/yyyy');
      expect(AppDateFormat.parseShownToApi('28/Oct/2026'), '2026-10-28');
      expect(reverseFormatDate('28/Oct/2026'), '2026-10-28');
    });
    test('custom MM-DD-YYYY is not swapped with day-month', () {
      AppDateFormat.set('MM-dd-yyyy');
      expect(AppDateFormat.parseShownToApi('05-10-2026'), '2026-05-10');
      expect(reverseFormatDate('05-10-2026'), '2026-05-10',
          reason: 'before, the generic list read this as 5 October');
    });
    test('custom DD-MM-YYYY', () {
      AppDateFormat.set('dd-MM-yyyy');
      expect(reverseFormatDate('05-10-2026'), '2026-10-05');
    });
    test('M/D/YYYY (custom on web)', () {
      AppDateFormat.set('M/d/yyyy');
      expect(reverseFormatDate('3/7/2026'), '2026-03-07');
    });
    test('day-of-year format round-trips', () {
      AppDateFormat.set('ddd/yyyy');
      expect(AppDateFormat.format(d), '301/2026');
      expect(AppDateFormat.parseShownToApi('301/2026'), '2026-10-28');
      expect(reverseFormatDate('301/2026'), '2026-10-28');
    });
    test('the server\'s own yyyy-MM-dd always passes through', () {
      AppDateFormat.set('dd/MMM/yyyy');
      expect(AppDateFormat.parseToApi('2026-10-28'), '2026-10-28');
      expect(AppDateFormat.parseToApi('2026-10-28T00:00:00.000Z'), '2026-10-28');
      expect(reverseFormatDate('2026-10-28'), '2026-10-28');
    });
    test('text that is not a date in the company format → null / fallback', () {
      AppDateFormat.set('dd/MMM/yyyy');
      expect(AppDateFormat.parseShownToApi('hello'), isNull);
      expect(AppDateFormat.parseShownToApi('10/28/2026'), isNull,
          reason: 'strict: not the company format');
      // reverseFormatDate still falls back to its generic list for presets.
      expect(reverseFormatDate('10/28/2026'), '2026-10-28');
    });
    test('presets keep working unchanged', () {
      for (final (fmt, shown) in [
        ('MM/dd/yyyy', '10/28/2026'),
        ('yyyy-MM-dd', '2026-10-28'),
        ('yyyy-MMM-dd', '2026-Oct-28'),
      ]) {
        AppDateFormat.set(fmt);
        expect(reverseFormatDate(shown), '2026-10-28', reason: fmt);
      }
    });
  });
}
