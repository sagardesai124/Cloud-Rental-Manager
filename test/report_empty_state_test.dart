import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// With no data, every report shows the standard empty state (CRM-4744): the
/// magnifying-glass picture with a bold blue "No Data Available" heading, like
/// Expiring Renter's Insurance and Renter's Insurance (QA, Android
/// 1.0.245+248).

const _reports = {
  'Recurring_Payments_Configuration_table': ['Text("No Data Available")'],
  'LeaseRenewalReport': ["'No data available'"],
  'LoanSummaryReport': ["'No loans found'"],
  'OutstandingLeaseBalance': [
    "'No Outstanding Lease Balance Data'",
    "'There are no outstanding lease balances to display'",
  ],
};

void _expectStandard(String path, List<String> oldTexts) {
  final src = File(path).readAsStringSync();
  final standard = RegExp(
      r'Image\.asset\(\s*"assets/images/no_data_transparent\.png",\s*height: 200,\s*width: 200,\s*\),'
      r'\s*(const )?SizedBox\(height: 10\),'
      r'\s*Text\(\s*"No Data Available",\s*style: TextStyle\(\s*fontWeight: FontWeight\.bold,'
      r'\s*color: blueColor,\s*fontSize: 16\)');
  expect(standard.hasMatch(src), isTrue, reason: '$path: standard empty state');
  for (final old in oldTexts) {
    expect(src, isNot(contains(old)), reason: '$path: old "$old"');
  }
}

void main() {
  for (final dir in [
    'lib/screens/Reports/ReportScreens',
    'lib/StaffModule/screen/Reports/ReportScreens',
  ]) {
    group(dir, () {
      _reports.forEach((name, oldTexts) {
        test(name, () => _expectStandard('$dir/$name.dart', oldTexts));
      });
    });
  }

  group('Mortgages', () {
    for (final path in [
      'lib/screens/Rental/mortgage/mortgageTable.dart',
      'lib/StaffModule/screen/Rental/mortgage/mortgageTable.dart',
    ]) {
      test(path, () {
        _expectStandard(path, [
          'Icons.inbox_outlined',
          "'No mortgages found'",
          "'Try adjusting your search or add a new mortgage'",
        ]);
      });
    }
  });

  // The JPG has a solid white background that shows as a white box on the
  // light-grey report pages; the PNG copy is transparent.
  test('no report uses the white-background picture', () {
    final files = [
      ...Directory('lib/screens/Reports').listSync(recursive: true),
      ...Directory('lib/StaffModule/screen/Reports').listSync(recursive: true),
      File('lib/screens/Rental/mortgage/mortgageTable.dart'),
      File('lib/StaffModule/screen/Rental/mortgage/mortgageTable.dart'),
    ].whereType<File>().where((f) => f.path.endsWith('.dart'));
    for (final f in files) {
      expect(f.readAsStringSync(), isNot(contains('assets/images/no_data.jpg')),
          reason: f.path);
    }
    expect(File('assets/images/no_data_transparent.png').existsSync(), isTrue);
  });

  test('Reopen Work Orders: both empty branches use it', () {
    final src = File('lib/screens/Reports/ReportScreens/ReopenWorkorder.dart')
        .readAsStringSync();
    _expectStandard('lib/screens/Reports/ReportScreens/ReopenWorkorder.dart', [
      '"No Work Orders on Hold Found"',
      "'No reopen work orders found'",
    ]);
    // Nothing on hold comes back as a non-200 reply (errorMessage set), an
    // empty list as 200 + [] — both show the same view.
    expect(
        RegExp(r'errorMessage != null\) \.\.\.\[\s*_emptyFilters\(\),\s*_noDataView\(\),')
            .hasMatch(src),
        isTrue);
    expect(
        RegExp(r'reopenWorkOrders\.isEmpty\) \.\.\.\[\s*_emptyFilters\(\),\s*_noDataView\(\),')
            .hasMatch(src),
        isTrue);
  });

  for (final path in [
    'lib/screens/Reports/ReportScreens/CustomReportBuilder.dart',
    'lib/StaffModule/screen/Reports/ReportScreens/CustomReportBuilder.dart',
  ]) {
    test('Custom Report Builder: $path', () {
      final src = File(path).readAsStringSync();
      expect(
          RegExp(r'Image\.asset\(\s*"assets/images/no_data_transparent\.png",\s*height: 200,\s*width: 200,\s*\),'
                  r'\s*const SizedBox\(height: 10\),\s*Text\(\s*heading,\s*style: TextStyle\(\s*fontWeight: FontWeight\.bold,'
                  r'\s*color: blueColor,\s*fontSize: 16\)')
              .hasMatch(src),
          isTrue,
          reason: 'standard design');
      expect(src, contains("? 'Please select a saved report'"));
      expect(src, contains("return _emptyState(maxW, 'No Data Available');"));
      expect(src, isNot(contains('Select a report from Saved Reports to view data')));
      expect(src, isNot(contains("'No data for this report.'")));
    });
  }

  for (final path in [
    'lib/screens/Reports/ReportScreens/Rent_collection.dart',
    'lib/StaffModule/screen/Reports/ReportScreens/Rent_collection.dart',
  ]) {
    test('Rent Collection filter-empty uses the shared one: $path', () {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains('Icons.filter_alt_off')));
      expect(src, isNot(contains('"Try adjusting your filters"')));
      expect(src, contains('kNoSearchResults(context),'));
    });
  }

  test('the shared search-empty state has no white box', () {
    final src = File('lib/constant/constant.dart').readAsStringSync();
    final start = src.indexOf('Widget kNoSearchResults(BuildContext context)');
    final body = src.substring(start, src.indexOf('\n}\n', start));
    expect(body, contains('"assets/images/no_data_transparent.png"'));
    expect(body, isNot(contains('no_data.jpg')));
    // Its own wording stays (CRM-4365: a search that matched nothing).
    expect(body, contains('"No Results Found"'));
  });

  test('Lease Renewal shows it when neither section has a lease', () {
    for (final dir in [
      'lib/screens/Reports/ReportScreens',
      'lib/StaffModule/screen/Reports/ReportScreens',
    ]) {
      final src = File('$dir/LeaseRenewalReport.dart').readAsStringSync();
      expect(
          RegExp(r'_reportData == null \|\|\s*\(_filteredLeasesEnding\.isEmpty &&'
                  r'\s*_filteredMtmLeases\.isEmpty\)')
              .hasMatch(src),
          isTrue,
          reason: dir);
    }
  });
}
