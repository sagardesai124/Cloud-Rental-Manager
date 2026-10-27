import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Expiring Lease uses the same filter layout as the other reports (Expiring
/// Renter's Insurance): outlined Date Range and From/To fields, then a
/// full-width Run beside Export. It used to be a rounded card with uppercase
/// labels, a small Run beside the dropdown and grey date fields (QA, Android
/// 1.0.245+248).

void main() {
  for (final path in [
    'lib/screens/Reports/ReportScreens/ExpiringLeases.dart',
    'lib/StaffModule/screen/Reports/ReportScreens/ExpiringLeases.dart',
  ]) {
    test(path, () {
      final src = File(path).readAsStringSync();
      // No filter card, uppercase labels or grey filled fields.
      expect(src, isNot(contains("'DATE RANGE'")));
      expect(src, isNot(contains('_filterLabel(')));
      expect(src, isNot(contains('Color(0xFFF5F6F8)')));
      expect(src, isNot(contains("'MM/DD/YYYY'")));
      // Outlined fields like the other reports.
      expect(
          RegExp(r'border: Border\.all\(\s*color: const Color\(0xFFCED4DA\)\)')
              .allMatches(src)
              .length,
          greaterThanOrEqualTo(3),
          reason: 'Date Range, date fields and search are outlined');
      // Run and Export share one row, each taking half.
      final run = src.indexOf("child: const Text('Run')");
      final export = src.indexOf('Expanded(child: _buildExportButton())');
      expect(run, isNonNegative);
      expect(export, greaterThan(run));
      expect(src.substring(run, export), isNot(contains('Padding(')),
          reason: 'Export sits right after Run in the same row');
      // The search row no longer carries Export.
      final search = src.indexOf('Widget _buildSearchRow()');
      final searchEnd = src.indexOf('Widget _buildExportButton()');
      expect(src.substring(search, searchEnd),
          isNot(contains('PopupMenuButton')));
    });
  }
}
