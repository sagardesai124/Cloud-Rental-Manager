import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every report opened from Reports has the back arrow beside its title.
/// Lease Renewal and Mortgages had none (QA, Android 1.0.245+248).

void main() {
  group('Lease Renewal uses the report header with the back arrow', () {
    for (final entry in {
      'lib/screens/Reports/ReportScreens/LeaseRenewalReport.dart':
          'ReportHeader(',
      'lib/StaffModule/screen/Reports/ReportScreens/LeaseRenewalReport.dart':
          'StaffReportHeader(',
    }.entries) {
      test(entry.key, () {
        final src = File(entry.key).readAsStringSync();
        final header = src.indexOf(entry.value);
        expect(header, isNonNegative);
        expect(src.substring(header, header + 120),
            contains("title: 'Lease Renewal Report'"));
      });
    }
  });

  group('Mortgages has the back arrow beside its title', () {
    for (final path in [
      'lib/screens/Rental/mortgage/mortgageTable.dart',
      'lib/StaffModule/screen/Rental/mortgage/mortgageTable.dart',
    ]) {
      test(path, () {
        final src = File(path).readAsStringSync();
        // The title is plain blue text like the other reports' headers,
        // not the dark title bar.
        final title = src.indexOf(RegExp(r"Text\(\s*'Mortgages',"));
        expect(title, isNonNegative);
        expect(src, isNot(contains('titleBar(')));
        final back = src.indexOf('Icons.arrow_back_ios_new');
        expect(back, isNonNegative);
        expect(back, lessThan(title), reason: 'arrow sits before the title');
        final tap = src.lastIndexOf('onTap:', back);
        expect(src.substring(tap, back), contains('Navigator.pop(context)'));
      });
    }
  });
}
