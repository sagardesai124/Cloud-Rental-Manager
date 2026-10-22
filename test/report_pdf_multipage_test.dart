import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Expiring Insurance (Admin and Staff) and Staff Expiring Leases print their
/// PDF over as many pages as the rows need, like the web PDF (autoTable): the
/// title block on the first page and the table carried on with its column
/// headings repeated. Before, each built one `pw.Page`, and a table taller
/// than one page was dropped, leaving a PDF with only the header (QA: 144
/// policies → header only).

const _screens = [
  'lib/screens/Reports/ReportScreens/Expiring_Insurance.dart',
  'lib/StaffModule/screen/Reports/ReportScreens/Expiring_Insurance.dart',
  'lib/StaffModule/screen/Reports/ReportScreens/ExpiringLeases.dart',
];

void main() {
  test('each report PDF is laid out over several pages, not one', () {
    for (final path in _screens) {
      final src = File(path).readAsStringSync();
      final start = src.indexOf('  Future<void> generatePdf(');
      expect(start, greaterThan(0), reason: path);
      final pdfCode = src.substring(start, src.indexOf('Printing.', start));
      expect(pdfCode, contains('pw.MultiPage('), reason: path);
      expect(pdfCode, isNot(contains('pw.Page(')), reason: path);
      expect(pdfCode, contains('Table.fromTextArray('), reason: path);
    }
  });

  test('the same layout really carries 144 rows over several pages', () async {
    // The shape the screens now use: title row, then the table, inside a
    // MultiPage.
    final rows = List.generate(
        144, (i) => ['Insurer $i', 'POL-$i', '01/01/2026', '12/31/2026', '\$100.00', 'Tenant $i']);
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      margin: const pw.EdgeInsets.all(30),
      build: (context) => [
        pw.Text("Expiring Renter's Insurance"),
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: const ['Insurance\nCompany', 'Policy\nID', 'Effective\nDate',
              'Expiration\nDate', 'Liability\nCoverage', 'Tenants'],
          data: rows,
          cellHeight: 30,
        ),
      ],
    ));
    final bytes = await doc.save();
    expect(doc.document.pdfPageList.pages.length, greaterThan(1),
        reason: '144 rows need several pages');
    expect(bytes, isNotEmpty);

    // A single pw.Page with the same content cannot lay the table out.
    final single = pw.Document();
    single.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (context) => pw.Column(children: [
        pw.Text("Expiring Renter's Insurance"),
        pw.Table.fromTextArray(data: rows, cellHeight: 30),
      ]),
    ));
    expect(single.document.pdfPageList.pages.length, 1);
  });
}
