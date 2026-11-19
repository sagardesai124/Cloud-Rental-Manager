import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/repository/tenant_statement_repo.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:three_zero_two_property/services/tenant_statement.dart';
import 'package:three_zero_two_property/services/tenant_statement_xlsx.dart';
import 'package:three_zero_two_property/widgets/tenant_statement_pdf.dart';

/// Lease → Financial → Export (Admin and Staff): the Tenant Statement
/// letterhead, like web staging (utils/tenantStatement.js, CRM-5247). The
/// cases and values are web's own (tenantStatement.test.js). Before, the
/// app's PDF printed the app's logo, the address with the unit and the
/// company's address with "N/A" for anything missing, with no period, report
/// date or tenant names, and the Excel and CSV files had only the table.

// Shapes as the two endpoints return them (web's fixtures).
const _company = {
  'company_name': '302 Properties, LLC',
  'brand_logo': 'data:image/png;base64,iVBORw0KGgo=',
  'mailing_street': '250 Corporate Blvd., Suite L',
  'mailing_city': 'Newark',
  'mailing_state': 'DE',
  'mailing_zip': '19702',
  'office_phone_number': '(302)525-4302',
};
const _leaseTenant = {
  'rental_adress': '64 Wildfire Lane',
  'rental_city': 'New Castle',
  'rental_state': 'DE',
  'rental_zip': '19720',
  'tenants': [
    {'tenant_firstName': 'Antoinette', 'tenant_lastName': 'Thornton'},
    {'tenant_firstName': 'Lawrence', 'tenant_lastName': 'Thornton'},
  ],
};
// Rows arrive newest-first; order must not matter.
const _rows = ['2024-03-05', '08/27/2019', '2019-08-26'];
final _now = DateTime(2026, 10, 27, 12);

// A real 1 x 1 PNG.
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  group("buildTenantStatementHeader, like web", () {
    final h = buildTenantStatementHeader(
      company: _company,
      leaseTenant: _leaseTenant,
      fallbackAddress: '64 Wildfire Lane',
      rowDates: _rows,
      datePattern: 'M/d/yyyy',
      now: _now,
    );

    test('prints the company letterhead: name, street, city/state/zip, phone',
        () {
      expect(h.companyName, '302 Properties, LLC');
      expect(h.companyLines,
          ['250 Corporate Blvd., Suite L', 'Newark, DE 19702', '(302)525-4302']);
    });

    test('runs from the first exported row to the statement date', () {
      expect(h.dateRangeText, '8/26/2019 - 10/27/2026');
    });

    test('names every tenant and the address in question, with no unit', () {
      expect(h.tenantNames, ['Antoinette Thornton', 'Lawrence Thornton']);
      expect(h.mailingLines, ['64 Wildfire Lane', 'New Castle, DE 19720']);
      expect(h.propertyLine, '64 Wildfire Lane');
    });

    test("carries the logo and today's Report Date in the company's format",
        () {
      expect(h.logo, _company['brand_logo']);
      expect(h.reportDate, '10/27/2026');
      final iso = buildTenantStatementHeader(
          rowDates: _rows, datePattern: 'yyyy-MM-dd', now: _now);
      expect(iso.reportDate, '2026-10-27');
    });

    test('feeds the same facts to the Excel and CSV leading rows', () {
      final rows = tenantStatementSheetRows(h);
      expect(rows.where((r) => r.isNotEmpty).map((r) => r.first).toList(), [
        'Tenant Statement',
        'Period: 8/26/2019 - 10/27/2026',
        'Report Date: 10/27/2026',
        '302 Properties, LLC',
        '250 Corporate Blvd., Suite L',
        'Newark, DE 19702',
        '(302)525-4302',
        'Antoinette Thornton, Lawrence Thornton',
        '64 Wildfire Lane',
        'New Castle, DE 19720',
        '64 Wildfire Lane',
      ]);
      // Web's blank rows: after the company block and before the table.
      expect(rows[7], isEmpty);
      expect(rows.last, isEmpty);
      // CSV rows are padded to the table's width, like web's padToTable.
      expect(padStatementRow(['Tenant Statement'], 6),
          ['Tenant Statement', '', '', '', '', '']);
      expect(padStatementRow([], 3), ['', '', '']);
    });
  });

  group('statementDateRange, like web', () {
    test('uses the From/To filters when set', () {
      final r = statementDateRange(
          rowDates: _rows, fromDate: '2020-01-01', toDate: '2021-06-30');
      expect(r.from, DateTime(2020, 1, 1));
      expect(r.to, DateTime(2021, 6, 30));
    });

    test('ends on the statement date when no To filter is set', () {
      final r = statementDateRange(rowDates: _rows, now: _now);
      expect(r.from, DateTime(2019, 8, 26));
      expect(r.to, DateTime(2026, 10, 27));
    });

    test('returns no start for no rows, and still ends on the statement date',
        () {
      final r = statementDateRange(rowDates: const [], now: _now);
      expect(r.from, isNull);
      expect(r.to, DateTime(2026, 10, 27));
      final h = buildTenantStatementHeader(
          rowDates: const [], datePattern: 'MM/dd/yyyy', now: _now);
      expect(h.dateRangeText, '10/27/2026');
    });

    test('reads the dates web reads, and skips what it cannot', () {
      expect(statementDay('2019-08-26'), DateTime(2019, 8, 26));
      expect(statementDay('08/27/2019'), DateTime(2019, 8, 27));
      expect(statementDay('8/7/2019'), DateTime(2019, 8, 7));
      expect(statementDay('2019-08-26T10:00:00.000Z'), isNotNull);
      expect(statementDay('not a date'), isNull);
      expect(statementDay(''), isNull);
    });
  });

  group('degraded inputs, like web', () {
    test('prints without the tenant block when lease_tenant failed', () {
      final h = buildTenantStatementHeader(
          company: _company,
          fallbackAddress: '64 Wildfire Lane',
          rowDates: _rows,
          now: _now);
      expect(h.tenantNames, isEmpty);
      expect(h.mailingLines, ['64 Wildfire Lane']);
      expect(h.propertyLine, '64 Wildfire Lane');
    });

    test('falls back to the office address, then the one-line address', () {
      expect(
          companyAddressLines({
            'office_street': '1 Main St',
            'office_city': 'Dover',
            'office_state': 'DE',
            'office_zip': '19901',
          }),
          ['1 Main St', 'Dover, DE 19901']);
      expect(
          companyAddressLines(
              {'mailing_address': 'PO Box 5, Newark DE', 'phone_number': '555'}),
          ['PO Box 5, Newark DE', '555']);
      expect(companyAddressLines({}), isEmpty);
    });

    test('uses the DBA when there is no company name', () {
      final h = buildTenantStatementHeader(
          company: {'company_dba': '302 Rentals'}, now: _now);
      expect(h.companyName, '302 Rentals');
    });
  });

  group('loading the facts at export, like web', () {
    setUp(() => SharedPreferences.setMockInitialValues({
          'token': 'tkn',
          'adminId': 'ADMIN-1',
          'staff_id': 'STAFF-1',
          'companyName': 'Saved Co',
          'brand_logo': 'data:image/png;base64,$_pngBase64',
        }));

    Future<({Map<String, dynamic> company, Map<String, dynamic> leaseTenant})>
        load(bool asStaff, List<http.Request> seen,
            {bool companyFails = false}) {
      return http.runWithClient(
          () => loadTenantStatementFacts(leaseId: 'L-1', asStaff: asStaff),
          () => MockClient((request) async {
                seen.add(request);
                if (request.url.path ==
                    '/api/tenantRental/companyName/ADMIN-1') {
                  return companyFails
                      ? http.Response('{}', 500)
                      : http.Response(jsonEncode(_company), 200);
                }
                if (request.url.path == '/api/leases/lease_tenant/L-1') {
                  return http.Response(
                      jsonEncode({'statusCode': 200, 'data': _leaseTenant}),
                      200);
                }
                return http.Response('{}', 404);
              }));
    }

    test('Admin: the company and the lease tenants, with the admin id', () async {
      final seen = <http.Request>[];
      final facts = await load(false, seen);
      expect(facts.company['company_name'], '302 Properties, LLC');
      expect(facts.leaseTenant['rental_adress'], '64 Wildfire Lane');
      expect(seen.map((r) => r.headers['id']).toSet(), {'CRM ADMIN-1'});
    });

    test("Staff: the same, with the staff member's id", () async {
      final seen = <http.Request>[];
      final facts = await load(true, seen);
      expect(facts.company['company_name'], '302 Properties, LLC');
      expect((facts.leaseTenant['tenants'] as List), hasLength(2));
      expect(seen.map((r) => r.headers['id']).toSet(), {'CRM STAFF-1'});
    });

    test('a failed company reply falls back to the saved name and logo',
        () async {
      final facts = await load(false, [], companyFails: true);
      expect(facts.company['company_name'], 'Saved Co');
      expect(facts.company['brand_logo'], startsWith('data:image/png'));
      expect(facts.leaseTenant['rental_adress'], '64 Wildfire Lane');
    });
  });

  group('the logo, like web', () {
    test('a PNG/JPEG/WEBP data URI is used; SVG and blanks print the name',
        () async {
      expect(await resolveStatementLogo('data:image/png;base64,$_pngBase64'),
          isNotNull);
      expect(await resolveStatementLogo('data:image/jpeg;base64,/9j/4AA='),
          isNotNull);
      expect(
          await resolveStatementLogo('data:image/svg+xml;base64,PHN2Zz4='),
          isNull);
      expect(await resolveStatementLogo(''), isNull);
      expect(await resolveStatementLogo(null), isNull);
      expect(await resolveStatementLogo('logo.png'), isNull);
    });

    test('an http(s) logo is fetched; a failed or non-image reply prints the name',
        () async {
      Future<dynamic> fetch(http.Response reply) => http.runWithClient(
          () => resolveStatementLogo('https://cdn.example.com/logo.png'),
          () => MockClient((_) async => reply));
      expect(
          await fetch(http.Response.bytes(base64Decode(_pngBase64), 200,
              headers: {'content-type': 'image/png'})),
          isNotNull);
      expect(
          await fetch(http.Response('<html>', 200,
              headers: {'content-type': 'text/html'})),
          isNull);
      expect(await fetch(http.Response('', 404)), isNull);
    });
  });

  group('the PDF, like web', () {
    final h = buildTenantStatementHeader(
      company: _company,
      leaseTenant: _leaseTenant,
      rowDates: _rows,
      datePattern: 'M/d/yyyy',
      now: _now,
    );

    /// The PDF's words in drawing order (the pdf package writes each word as
    /// its own `[(word)]TJ` run) and its page count.
    Future<({String text, int pages})> render(
        {pw.ImageProvider? logo, int rows = 3}) async {
      final doc = pw.Document(compress: false);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (_) => tenantStatementPdfHeader(h, logo: logo),
        footer: (ctx) => pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}'),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Tenants', 'Type', 'Description', 'Amount', 'Balance'],
            data: [
              for (var i = 0; i < rows; i++)
                ['2024-03-05', 'Antoinette Thornton', 'Charge', 'Rent', r'$100', r'$100'],
            ],
          ),
        ],
      ));
      final raw = latin1.decode(await doc.save());
      final words = RegExp(r'\[\((.*?)\)\]TJ').allMatches(raw).map((m) => m[1]!
          .replaceAll(r'\(', '(')
          .replaceAll(r'\)', ')')
          .replaceAll(r'\\', r'\'));
      return (
        text: words.join(' '),
        pages: RegExp(r'/Type/Page[^s]').allMatches(raw).length,
      );
    }

    int count(String text, String s) =>
        RegExp(RegExp.escape(s)).allMatches(text).length;

    test('prints the letterhead, the tenants and the address, with no unit',
        () async {
      final text = (await render()).text;
      for (final s in [
        'Tenant Statement',
        '8/26/2019 - 10/27/2026',
        'Report Date: 10/27/2026',
        '302 Properties, LLC',
        '250 Corporate Blvd., Suite L',
        'Newark, DE 19702',
        '(302)525-4302',
        'Antoinette Thornton, Lawrence Thornton',
        'New Castle, DE 19720',
      ]) {
        expect(text, contains(s), reason: s);
      }
    });

    test('repeats the complete header on every page, like web', () async {
      final pdf = await render(rows: 60);
      expect(pdf.pages, greaterThan(1));
      for (final s in [
        'Tenant Statement',
        '8/26/2019 - 10/27/2026',
        'Report Date: 10/27/2026',
        'Antoinette Thornton, Lawrence Thornton',
        'New Castle, DE 19720',
      ]) {
        expect(count(pdf.text, s), pdf.pages, reason: s);
      }
      expect(count(pdf.text, 'Page 1 of ${pdf.pages}'), 1);
    });

    test("with a logo the company's name is not repeated top-right", () async {
      final logo = pw.MemoryImage(base64Decode(_pngBase64));
      final withLogo = (await render(logo: logo)).text;
      final noLogo = (await render()).text;
      // Without a logo the name prints top-left and in the logo's place.
      expect(count(withLogo, '302 Properties, LLC'), 1);
      expect(count(noLogo, '302 Properties, LLC'), 2);
    });
  });

  group("the table, like web (statementHead, buildStatementRow)", () {
    const ruth = {'tenant_firstName': 'Ruth', 'tenant_lastName': 'Parker'};
    List<String> row({
      String? type,
      Object? tenant,
      String? response,
      String? paymentType,
      String? responseText,
      List<({String? memo, String? account})> entries = const [],
      List<String?> dates = const ['2026-05-04'],
      double? total,
      double? balance,
      String pattern = 'yyyy-MM-dd',
    }) =>
        tenantStatementRow(
            type: type,
            tenantData: tenant,
            response: response,
            paymentType: paymentType,
            responseText: responseText,
            entries: entries,
            dates: dates,
            totalAmount: total,
            balance: balance,
            datePattern: pattern);

    test("web's columns, with Charge, Payment and Balance on the right", () {
      expect(tenantStatementHead, [
        'Date',
        'Tenant',
        'Type',
        'Description',
        'Charge',
        'Payment',
        'Balance',
      ]);
      expect(tenantStatementMoneyColumns, {4, 5, 6});
    });

    test("2596 Watson Street prints web's rows", () {
      expect(
          row(
              type: 'Payment',
              tenant: ruth,
              response: 'SUCCESS',
              paymentType: 'ACH',
              responseText: '',
              total: 3.15,
              balance: -3.15),
          [
            '2026-05-04',
            'Ruth Parker',
            'Payment',
            'ACH Payment SUCCESS',
            '',
            r'$3.15',
            r'($3.15)'
          ]);
      expect(
          row(
              type: 'Charge',
              entries: [(memo: 'Convenience Fee', account: 'Convenience Fee')],
              total: 0.15,
              balance: -3.0),
          ['2026-05-04', '-', 'Charge', 'Convenience Fee', r'$0.15', '', r'($3.00)']);
      expect(
          row(
              type: 'Payment',
              tenant: ruth,
              response: 'SUCCESS',
              paymentType: 'Card',
              total: 1.05,
              balance: -4.05)[3],
          'Card Payment SUCCESS');
      // No gateway response: web prints the entry's memo, never "null".
      expect(
          row(
              type: 'Payment',
              tenant: ruth,
              paymentType: 'Card',
              entries: [(memo: 'Payment', account: 'Rent')],
              dates: ['2026-05-09'],
              total: 1.05,
              balance: -6.05),
          ['2026-05-09', 'Ruth Parker', 'Payment', 'Payment', '', r'$1.05', r'($6.05)']);
    });

    test('tenant: "External Source" for a payment with no tenant, else "-"',
        () {
      expect(statementTenantCell(type: 'Payment'), 'External Source');
      expect(statementTenantCell(type: 'Charge'), '-');
      expect(statementTenantCell(tenantData: const {}, type: 'Payment'), '-');
    });

    test('description: the memo, else the account, joined; "-" for none', () {
      expect(
          statementDescription(entries: [
            (memo: ' ', account: 'Rent'),
            (memo: 'Late fee', account: 'Fees'),
          ]),
          'Rent, Late fee');
      expect(statementDescription(), '-');
      expect(
          statementDescription(
              type: 'Payment',
              response: 'SUCCESS',
              paymentType: 'Check',
              responseText: 'Approved'),
          'Check Payment SUCCESS Approved');
    });

    test('amounts like web', () {
      expect(statementChargeCell(type: 'Refund', totalAmount: -5), r'($5.00)');
      expect(statementChargeCell(type: 'Payment', totalAmount: 5), '');
      expect(statementPaymentCell(type: 'Payment', totalAmount: 0), '');
      expect(statementPaymentCell(type: 'Payment', totalAmount: 1234.5),
          r'$1,234.50');
      expect(statementPaymentCell(type: 'Charge', totalAmount: 5), '');
      expect(statementBalanceCell(0), r'$0.00');
      expect(statementBalanceCell(1e-12), r'$0.00');
      expect(statementBalanceCell(null), r'$0.00');
      expect(statementBalanceCell(2500), r'$2,500.00');
    });

    test("dates: entry, payment, charge, then created, in the company's format",
        () {
      expect(statementDateCell(['2026-05-04'], 'MM/dd/yyyy'), '05/04/2026');
      expect(statementDateCell([null, '', '2026-05-07', '2026-05-08'], 'yyyy-MM-dd'),
          '2026-05-07');
      expect(statementDateCell([null, null, null, null], 'yyyy-MM-dd'), '-');
      expect(statementDateCell(['not a date'], 'yyyy-MM-dd'), 'Invalid date');
    });

    test('CSV like web: every cell quoted, money columns padded on the left',
        () {
      final lines = tenantStatementCsv([
        ['Tenant Statement'],
        [],
        tenantStatementHead,
        ['2026-05-04', '-', 'Charge', 'Fee "A"', r'$0.15', '', r'($3.00)'],
      ]).split('\n');
      expect(lines, [
        '"Tenant Statement","","","","      ","       ","       "',
        '"","","","","      ","       ","       "',
        '"Date","Tenant","Type","Description","Charge","Payment","Balance"',
        r'"2026-05-04","-","Charge","Fee ""A"""," $0.15","       ","($3.00)"',
      ]);
    });

    test('Excel like web: a "Statement" sheet, money columns on the right',
        () {
      final workbook = tenantStatementWorkbook([
        ['Tenant Statement'],
        [],
        tenantStatementHead,
        [
          '2026-05-04',
          'Ruth Parker',
          'Payment',
          'ACH Payment SUCCESS',
          '',
          r'$3.15',
          r'($3.15)'
        ],
      ]);
      final sheet = workbook.worksheets[0];
      expect(sheet.name, 'Statement');
      expect(sheet.getRangeByIndex(1, 1).getText(), 'Tenant Statement');
      expect(sheet.getRangeByIndex(3, 5).getText(), 'Charge');
      expect(sheet.getRangeByIndex(4, 6).getText(), r'$3.15');
      for (final r in [3, 4]) {
        for (var c = 1; c <= 7; c++) {
          final align = sheet.getRangeByIndex(r, c).cellStyle.hAlign;
          if (c >= 5) {
            expect(align, xlsio.HAlignType.right, reason: 'row $r col $c');
          } else {
            expect(align, isNot(xlsio.HAlignType.right),
                reason: 'row $r col $c');
          }
        }
      }
      workbook.dispose();
    });

    test(
        'PDF like web: a grey header, rows 1, 3, 5 shaded, no borders, money '
        'columns and their headers on the right', () {
      final table = tenantStatementPdfTable([
        row(type: 'Payment', tenant: ruth, total: 3.15, balance: -3.15),
        row(type: 'Charge', total: 0.15, balance: -3.0),
      ]) as pw.Table;
      expect(table.border, isNull);
      expect(table.children.first.decoration?.color,
          const PdfColor.fromInt(0xFFDEE2E6));
      expect(table.children[1].decoration?.color,
          const PdfColor.fromInt(0xFFF5F5F5));
      expect(table.children[2].decoration?.color, PdfColors.white);
      for (final r in [0, 1]) {
        final cells = table.children[r].children.cast<pw.Container>();
        for (var c = 0; c < 7; c++) {
          expect(
              cells[c].alignment,
              c >= 4 ? pw.Alignment.topRight : pw.Alignment.topLeft,
              reason: 'row $r col $c');
        }
      }
    });

    test('PDF: web columns and cells, no Amount column or Balance Due line',
        () async {
      final doc = pw.Document(compress: false);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          tenantStatementPdfTable([
            row(
                type: 'Payment',
                tenant: ruth,
                response: 'SUCCESS',
                paymentType: 'ACH',
                total: 3.15,
                balance: -3.15),
            row(
                type: 'Charge',
                entries: [(memo: 'Convenience Fee', account: null)],
                total: 0.15,
                balance: -3.0),
          ]),
        ],
      ));
      final raw = latin1.decode(await doc.save());
      final text = RegExp(r'\[\((.*?)\)\]TJ')
          .allMatches(raw)
          .map((m) => m[1]!.replaceAll(r'\(', '(').replaceAll(r'\)', ')'))
          .join(' ');
      for (final s in [
        'Date Tenant Type Description Charge Payment Balance',
        'Ruth Parker Payment ACH Payment SUCCESS',
        r'$3.15',
        r'($3.15)',
        'Charge Convenience Fee',
        r'$0.15',
      ]) {
        expect(text, contains(s), reason: s);
      }
      for (final s in ['Amount', 'Balance Due', 'N/A', 'Manual']) {
        expect(text, isNot(contains(s)), reason: s);
      }
    });
  });

  test('Admin and Staff exports use the letterhead and table in PDF, Excel '
      'and CSV', () {
    for (final (path, asStaff) in [
      ('lib/screens/Leasing/RentalRoll/Financial.dart', 'false'),
      ('lib/StaffModule/screen/Leasing/RentalRoll/Financial.dart', 'true'),
    ]) {
      final code = File(path).readAsStringSync();
      final pdfStart = code.indexOf('Future<void> generateWorkOrderPdf(');
      final pdfEnd = code.indexOf('Future<void> generateWorkOrderExcel(');
      final pdf = code.substring(pdfStart, pdfEnd);
      final exports =
          code.substring(pdfStart, code.indexOf('final _formKey', pdfStart));
      expect(pdf, contains('tenantStatementPdfHeader(statementHeader'), reason: path);
      expect(pdf, isNot(contains('applogo.png')), reason: '$path: no app logo');
      expect(pdf, isNot(contains('rentalUnit')), reason: '$path: no unit');
      expect(code, contains('asStaff: $asStaff'), reason: path);
      expect('tenantStatementSheetRows('.allMatches(code).length, 2,
          reason: '$path: Excel and CSV');
      // The table, like web, in all three formats.
      expect(pdf, contains('tenantStatementPdfTable('), reason: path);
      expect(pdf, contains("'Tenant_statement.pdf'"), reason: path);
      expect(pdf, isNot(contains("'Balance Due'")), reason: path);
      expect(exports, contains('tenantStatementWorkbook(rows)'), reason: path);
      expect(exports, contains('tenantStatementCsv('), reason: path);
      expect('.map(_statementRow)'.allMatches(exports).length, 3,
          reason: '$path: PDF, Excel and CSV');
      expect(exports, isNot(contains("'Amount'")), reason: path);
    }
  });
}
