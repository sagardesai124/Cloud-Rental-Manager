import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_zero_two_property/services/csv_row.dart';

/// Report CSV exports quote values like web's CSVs, so a value with a comma
/// (`$3,000.00`, `Miami, Florida, 33131`, `Joseph Martin, Jessica Thompson`)
/// stays in one column and every row keeps the header's column count.
/// Before, each report joined values with bare commas and columns shifted
/// (QA: Expiring Renter's Insurance 24 of 144 rows right, Rent Collection 0
/// of 3 / 1 of ~18). Rent Collection exports use "-" for empty values, like
/// web (CRM-2923), instead of "N/A".

const _reports = [
  'AccountTotals',
  'Expiring_Insurance',
  'InsurancePremiumReport',
  'OutstandingLeaseBalance',
  'Payment_Exception',
  'PropertyRevenueReport',
  'Rent_collection',
  'dailytransaction',
  'rentalownerreport',
];
const _dirs = [
  'lib/screens/Reports/ReportScreens',
  'lib/StaffModule/screen/Reports/ReportScreens',
];

/// Reads [csv] back the way a spreadsheet does.
List<List<dynamic>> _read(String csv) =>
    const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
        .convert(csv);

/// The lines of [src] that write the CSV (from the first to the last
/// `csvBuffer` use), without comments.
String _csvSection(String src) {
  final lines = src.split('\n');
  final idx = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].contains('csvBuffer') && !lines[i].trim().startsWith('//')) i
  ];
  return lines
      .sublist(idx.first, idx.last + 1)
      .where((l) => !l.trim().startsWith('//'))
      .join('\n');
}

void main() {
  group('csvRow', () {
    test('plain values are left as they are', () {
      expect(csvRow(['Test', '09/01/2026', '-', 12, null]),
          'Test,09/01/2026,-,12,');
    });

    test('values with a comma, quote or line break are quoted', () {
      expect(csvCell(r'$3,000.00'), r'"$3,000.00"');
      expect(csvCell('Miami, Florida, 33131'), '"Miami, Florida, 33131"');
      expect(csvCell('6" pipe'), '"6"" pipe"');
      expect(csvCell('10/01: called\n10/02: paid'), '"10/01: called\n10/02: paid"');
    });

    test("QA's Rent Collection line keeps the header's 8 columns", () {
      const header = [
        'Street', 'City State Zip', 'Entity', 'Move-in Date',
        'Monthly Rent', 'Balance', 'Auto-Pay', 'Notes'
      ];
      final line = csvRow([
        '1050 Brickell Ave Apt 1002', 'Miami, Florida, 33131', 'Test',
        '09/01/2026', r'$3,000.00', r'$3,000.00', '-', '-'
      ]);
      final rows = _read('${csvRow(header)}\n$line\n');
      expect(rows[1], hasLength(header.length));
      expect(rows[1][1], 'Miami, Florida, 33131');
      expect(rows[1][4], r'$3,000.00');
      // The old way: the same values joined with bare commas.
      final old = _read(
          '1050 Brickell Ave Apt 1002,Miami, Florida, 33131,Test,09/01/2026,\$3,000.00,\$3,000.00,N/A,N/A\n');
      expect(old.first.length, greaterThan(header.length),
          reason: 'bare commas split the row (the reported bug)');
    });

    test("QA's Expiring Insurance and Rent Collection summary values", () {
      final insurance = _read('${csvRow([
            'State Farm', 'P-1', '(555) 555-5555', '01/01/2026', '12/31/2026',
            r'$100,000.00', 'Joseph Martin, Jessica Thompson'
          ])}\n');
      expect(insurance.first, hasLength(7));
      expect(insurance.first[5], r'$100,000.00');
      expect(insurance.first[6], 'Joseph Martin, Jessica Thompson');

      final summary =
          _read('${csvRow(['Owner Co', r'$8,450.50', r'$15,721.00', '54'])}\n');
      expect(summary.first, hasLength(4));
      expect(summary.first[1], r'$8,450.50');
    });
  });

  group('every affected report uses it (Admin and Staff)', () {
    for (final dir in _dirs) {
      for (final name in _reports) {
        final path = '$dir/$name.dart';
        test(path, () {
          final src = File(path).readAsStringSync();
          expect(src, contains("import 'package:three_zero_two_property/services/csv_row.dart';"));
          final section = _csvSection(src);
          expect(section, contains('csvRow('));
          expect(section, isNot(contains(".join(',')")),
              reason: 'no CSV line joined with bare commas');
          expect(section, isNot(contains(".replaceAll(',', ' ')")),
              reason: 'commas are kept and quoted, like web');
        });
      }
    }
  });

  // Admin-only reports that write rows with `csv.writeln(...)`.
  group('Live Property, Property Insurance Summary and Property Tax use it', () {
    for (final name in [
      'LivePropertyReport',
      'PropertyInsuranceSummary',
      'PropertyTaxReport',
    ]) {
      test(name, () {
        final src =
            File('lib/screens/Reports/ReportScreens/$name.dart').readAsStringSync();
        expect(src, contains("import 'package:three_zero_two_property/services/csv_row.dart';"));
        final start = src.indexOf('StringBuffer csv');
        final end = src.indexOf('csv.toString()', start);
        expect(start, isNonNegative);
        expect(end, greaterThan(start));
        final section = src
            .substring(start, end)
            .split('\n')
            .where((l) => !l.trim().startsWith('//'))
            .join('\n');
        expect(section, contains('csv.writeln(csvRow(['));
        // The old rows: one string with values joined by bare commas.
        expect(RegExp(r"\$\{[^}]*\},\$\{").hasMatch(section), isFalse,
            reason: 'no row built as "\${a},\${b}"');
      });
    }
  });

  // Web's CSV layout (RentCollectionReport.jsx / ExpiringRenterInsurancesReport.jsx).
  group('CSV layout matches web', () {
    for (final dir in _dirs) {
      test('$dir Rent Collection: Details first, web headers', () {
        final section =
            _csvSection(File('$dir/Rent_collection.dart').readAsStringSync());
        final details = section.indexOf("'City, State, Zip'");
        final summary = section.indexOf("'Total Outstanding'");
        final delinquent = section.indexOf("'Delinquent Leases'");
        expect(details, isNonNegative);
        expect(section, contains("'Address'"));
        expect(summary, greaterThan(details), reason: 'Summary after Details');
        expect(delinquent, greaterThan(summary));
        expect(section, isNot(contains('Total Pending')));
        expect(section, isNot(contains('Street,City State Zip')));
        expect(section, isNot(contains("writeln('Summary')")));
        expect(section, isNot(contains("writeln('Details')")));
        // Summary rows sit under web's padded columns.
        expect(section, contains("csvRow(['', '', row[0], '', row[1], row[2], row[3]])"));
      });

      test('$dir Rent Collection: delinquent address is "city, state, zip"', () {
        final src = File('$dir/Rent_collection.dart').readAsStringSync();
        final start =
            src.indexOf('List<List<dynamic>> _generateDelinquentLeasesTableDataExcel(');
        final body = src.substring(start, src.indexOf('return tableData;', start));
        expect(body, contains("rentalCity ?? '-'}, '"));
        expect(body, contains("rentalState ?? '-'}, '"));
      });

      test('$dir Expiring Insurance: web title block and headers', () {
        final section =
            _csvSection(File('$dir/Expiring_Insurance.dart').readAsStringSync());
        final title = section.indexOf("csvRow(['Insurance Report'])");
        final asOf = section.indexOf("csvRow(['As of \$asOf'])");
        final header = section.indexOf('csvRow(rows.first)');
        expect(title, isNonNegative);
        expect(asOf, greaterThan(title));
        expect(header, greaterThan(asOf));
        expect(section, contains("'No record found'"));
        final src = File('$dir/Expiring_Insurance.dart').readAsStringSync();
        final csvFn = src.substring(src.indexOf('Future<void> generateCsv('));
        for (final h in ['Effective Date', 'Expiration Date', 'Liability Coverage']) {
          expect(csvFn, contains("'$h'"));
        }
        expect(csvFn.substring(0, csvFn.indexOf('writeAsBytes')),
            isNot(contains("'EffectiveDate'")));
      });
    }
  });

  group('Rent Collection exports use "-" for empty values', () {
    for (final dir in _dirs) {
      test(dir, () {
        final src = File('$dir/Rent_collection.dart').readAsStringSync();
        for (final fn in [
          '_generateSummaryTableDataExcel',
          '_generateDetailsTableDataExcel',
          '_generateDelinquentLeasesTableDataExcel',
        ]) {
          final start = src.indexOf('List<List<dynamic>> $fn(');
          expect(start, isNonNegative, reason: fn);
          // The function body: from its first `{` to the matching `}`.
          final open = src.indexOf('{', start);
          var depth = 0, end = open;
          for (; end < src.length; end++) {
            if (src[end] == '{') depth++;
            if (src[end] == '}' && --depth == 0) break;
          }
          final body = src.substring(open, end + 1);
          expect(body, isNot(contains("'N/A'")), reason: '$fn uses "-"');
          expect(body, contains("'-'"));
        }
      });
    }
  });
}
