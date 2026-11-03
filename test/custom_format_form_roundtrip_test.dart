import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

/// With a custom company format, a date shown in a form field reads back to
/// the server's yyyy-MM-dd through the shared helper every form uses
/// (reverseFormatDate / the _convertToApiFormat copies delegate to
/// AppDateFormat first). Before, "28/Oct/2026" came back as "" and
/// "05-10-2026" (MM-DD-YYYY) came back as 5 October.
void main() {
  tearDown(() => AppDateFormat.set(kDefaultAppDateFormat));

  final samples = {
    // web format : (shown text, expected api date)
    'DD/MMM/YYYY': ('28/Oct/2026', '2026-10-28'),
    'MM-DD-YYYY': ('05-10-2026', '2026-05-10'),
    'DD-MM-YYYY': ('05-10-2026', '2026-10-05'),
    'M/D/YYYY': ('3/7/2026', '2026-03-07'),
    'MMMM D, YYYY': ('October 28, 2026', '2026-10-28'),
    'YYYY/MM/DD': ('2026/10/28', '2026-10-28'),
    'MM/DD/YYYY': ('10/28/2026', '2026-10-28'),
    'YYYY-MM-DD': ('2026-10-28', '2026-10-28'),
    'YYYY-MMM-DD': ('2026-Oct-28', '2026-10-28'),
  };

  samples.forEach((web, pair) {
    final (shown, api) = pair;
    test('$web: "$shown" shown → "$api" sent', () {
      AppDateFormat.set(AppDateFormat.toIntl(web));
      // What a field shows for that api date, then what Save sends back.
      expect(AppDateFormat.format(DateTime.parse(api)), shown);
      expect(reverseFormatDate(shown), api);
    });
  });

  test('a raw server date in a field is sent back unchanged (all formats)', () {
    for (final web in samples.keys) {
      AppDateFormat.set(AppDateFormat.toIntl(web));
      expect(reverseFormatDate('2026-10-28'), '2026-10-28', reason: web);
    }
  });
}
