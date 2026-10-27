import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/Model/ReopenWorkOrderModel.dart';
import 'package:three_zero_two_property/Model/lease_renewal_report.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/ReopenWorkorder.dart';
import 'package:three_zero_two_property/services/lease_renewal_csv.dart';

/// Three report exports now match web staging:
/// - Rent Collection PDF shows "-" for empty values, like web's PDF
///   (RentCollectionReport.jsx), instead of "N/A";
/// - Reopen Work Orders "CSV" is a real CSV with web's 9 columns
///   (ReopenWorkOrderReport.jsx generateCSV), instead of a .txt report;
/// - Lease Renewal "CSV" exports web's two sections (LeaseRenewalReport.jsx
///   generateCSV), instead of "CSV export coming soon" (Admin and Staff).

const _dirs = [
  'lib/screens/Reports/ReportScreens',
  'lib/StaffModule/screen/Reports/ReportScreens',
];

List<List<dynamic>> _read(String csv) =>
    const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(csv);

/// The body of the function [name] in [src], from its `{` to the matching `}`.
String _body(String src, String signature) {
  final start = src.indexOf(signature);
  expect(start, isNonNegative, reason: signature);
  final open = src.indexOf('{', start);
  var depth = 0, end = open;
  for (; end < src.length; end++) {
    if (src[end] == '{') depth++;
    if (src[end] == '}' && --depth == 0) break;
  }
  return src.substring(open, end + 1);
}

/// The account date format the tests pretend to use.
String _fmt(String d) => 'D:$d';

void main() {
  group('Rent Collection PDF uses "-" for empty values', () {
    for (final dir in _dirs) {
      test(dir, () {
        final src = File('$dir/Rent_collection.dart').readAsStringSync();
        for (final fn in [
          'List<List<dynamic>> _generateSummaryTableData(',
          'List<List<String>> _generateDetailsTableData(',
          'List<List<dynamic>> _generateDelinquentLeasesTableData(',
        ]) {
          final body = _body(src, fn);
          expect(body, isNot(contains("'N/A'")), reason: fn);
          expect(body, contains("'-'"), reason: fn);
        }
      });
    }
  });

  group('Reopen Work Orders CSV (web generateCSV)', () {
    final full = ReopenWorkOrderData.fromJson({
      'ticket_number': 'RW1',
      'work_subject': 'Leak, kitchen',
      'work_category': 'Plumbing',
      'priority': 'High',
      'status': 'On Hold',
      'rental_adress': '1050 Brickell Ave',
      'rental_unit': '1002',
      'staffmember_name': 'Pat Staff',
      'date': '2026-10-01',
      'reopen_date': '2026-11-01',
      'created_at': '2026-09-01',
    });
    final empty = ReopenWorkOrderData.fromJson({
      'rental_adress': '5 Oak St',
      'rental_unit': '5 Oak St Unit B',
    });

    test("web's 9 headers, one row per work order", () {
      final rows = _read(buildReopenWorkOrdersCsv([full, empty], _fmt));
      expect(rows.first, [
        '#',
        'Subject',
        'Category',
        'Priority',
        'Property',
        'Assigned To',
        'Due Date',
        'Reopen Date',
        'Created Date',
      ]);
      expect(rows, hasLength(3));
      for (final r in rows) {
        expect(r, hasLength(9));
      }
    });

    test('values, "address - unit", dates in the account format', () {
      final row = _read(buildReopenWorkOrdersCsv([full], _fmt))[1];
      expect(row, [
        'RW1',
        'Leak, kitchen',
        'Plumbing',
        'High',
        '1050 Brickell Ave - 1002',
        'Pat Staff',
        'D:2026-10-01',
        'D:2026-11-01',
        'D:2026-09-01',
      ]);
    });

    test('empty values are "N/A", like web', () {
      final row = _read(buildReopenWorkOrdersCsv([empty], _fmt))[1];
      expect(row, [
        'N/A',
        'N/A',
        'N/A',
        'N/A',
        '5 Oak St Unit B',
        'N/A',
        'N/A',
        'N/A',
        'N/A',
      ]);
    });

    test('the CSV menu writes this file, not the old .txt report', () {
      final src = File('lib/screens/Reports/ReportScreens/ReopenWorkorder.dart')
          .readAsStringSync();
      expect(src, contains('_exportToCsv(context);'));
      expect(src, contains('Reopen_Work_Order_Report.csv'));
      expect(RegExp(r'buildReopenWorkOrdersCsv\(\s*filteredData').hasMatch(src),
          isTrue,
          reason: 'exports the rows on screen');
      expect(src, isNot(contains('reopen_work_orders_report.txt')));
      expect(src, isNot(contains('_shareReport(')));
    });
  });

  group('Lease Renewal CSV (web generateCSV)', () {
    Map<String, dynamic> lease({String last = ''}) => {
          'property_address': '1050 Brickell Ave, Miami',
          'tenants': [
            {'tenant_name': 'Joseph Martin'},
            {'tenant_name': 'Jessica Thompson'},
          ],
          'rent_data': {
            'rent_year1': 1200,
            'rent_year2': 1250.5,
            'rent_year3': 1300,
            'year1': 2025,
            'year2': 2026,
            'year3': 2027,
            'new_rent_amount': 1400,
            'new_rent_includes_trash_service': 'Yes',
            'rent_increase': 149.5,
            'last_increase_date': last,
          },
          'deposits': {'total_deposits': 2500},
          'metrics': {'time_late_count': 2, 'court_filings': 1},
          'tenant_needs_trash_service': 'No',
          'notes': [
            {'content': 'Renew, raise rent'},
            {'content': 'second note'},
          ],
        };
    final ending = [LeaseEnding.fromJson(lease())];
    final mtm = [
      MonthToMonthLease.fromJson(lease(last: '2026-01-15')),
      MonthToMonthLease.fromJson({'property_address': '5 Oak St'}),
    ];

    test("web's two sections, headers and values", () {
      final csv = buildLeaseRenewalCsv(
          leasesEnding: ending, mtmLeases: mtm, formatDate: _fmt);
      final rows = _read(csv);
      expect(rows[0], ['Leases Ending']);
      expect(rows[1], [
        'Property',
        'Tenant',
        '2025 Rent',
        '2026 Rent',
        'Deposits',
        'New Rent',
        'Includes Trash?',
        'Increase',
        'Times Late',
        'Court Filings',
        'Need Trash Svc?',
        'Notes',
      ]);
      expect(rows[2], [
        '1050 Brickell Ave, Miami',
        'Joseph Martin, Jessica Thompson',
        r'$1,200.00',
        r'$1,250.50',
        r'$2,500.00',
        r'$1,400.00',
        'Yes',
        r'$149.50',
        '2',
        '1',
        'No',
        'Renew, raise rent',
      ]);
      // Blank line between the sections, like web.
      expect(csv, contains('\n\nMTM Leases\n'));
      final mtmAt = rows.indexWhere((r) => r.length == 1 && r[0] == 'MTM Leases');
      expect(rows[mtmAt + 1], [
        'Property',
        'Tenant',
        '2025 Rent',
        '2026 Rent',
        '2027 Rent',
        'Last Increase',
        'Sec. Dep.',
        'New Rent',
        'Includes Trash?',
        'Increase',
        'Late',
        'Court',
        'Need Trash Svc?',
        'Notes',
      ]);
      expect(rows[mtmAt + 2][5], 'D:2026-01-15',
          reason: 'last increase in the account date format');
      expect(rows[mtmAt + 2], hasLength(14));
      // A lease with nothing set: web's placeholders.
      expect(rows[mtmAt + 3], [
        '5 Oak St',
        'N/A',
        r'$0.00',
        r'$0.00',
        r'$0.00',
        'N/A',
        r'$0.00',
        r'$0.00',
        'No',
        r'$0.00',
        '0',
        '0',
        'No',
        'No notes',
      ]);
    });

    test('a section without rows is left out; years fall back like web', () {
      final onlyMtm = buildLeaseRenewalCsv(
          leasesEnding: const [],
          mtmLeases: [MonthToMonthLease.fromJson({'property_address': 'A'})],
          formatDate: _fmt);
      expect(onlyMtm, isNot(contains('Leases Ending')));
      expect(_read(onlyMtm)[1].sublist(2, 5),
          ['Year 1 Rent', 'Year 2 Rent', 'Year 3 Rent']);
      expect(
          buildLeaseRenewalCsv(
              leasesEnding: const [], mtmLeases: const [], formatDate: _fmt),
          isEmpty);
    });

    for (final dir in _dirs) {
      test('$dir: CSV option exports instead of "coming soon"', () {
        final src = File('$dir/LeaseRenewalReport.dart').readAsStringSync();
        expect(src, isNot(contains('CSV export coming soon')));
        expect(src, contains("} else if (value == 'csv') {\n                                  _generateCsv();"));
        final fn = _body(src, 'Future<void> _generateCsv() async');
        expect(fn, contains('buildLeaseRenewalCsv('));
        expect(fn, contains('_filteredLeasesEnding'));
        expect(fn, contains('_filteredMtmLeases'));
        expect(fn, contains("'Lease_Renewal_Report_"));
      });

      test('$dir: exporting keeps the report screen open', () {
        final src = File('$dir/LeaseRenewalReport.dart').readAsStringSync();
        // PopupMenuButton closes its menu before onSelected runs, so a pop
        // here would close the report screen itself.
        final onSelected = _body(src, 'onSelected: (String value)');
        expect(onSelected, contains('_generatePdf();'));
        expect(onSelected, isNot(contains('Navigator.pop')));
      });
    }
  });
}
