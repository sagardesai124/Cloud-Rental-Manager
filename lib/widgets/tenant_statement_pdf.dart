import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/tenant_statement.dart';

const PdfColor _ink = PdfColor.fromInt(0xFF212529);
const PdfColor _muted = PdfColor.fromInt(0xFF6C757D);

/// The Tenant Statement header, like web's drawTenantStatementPdf: the
/// letterhead band (company name, address and phone left; "Tenant
/// Statement", the period and "Report Date" in the middle; the logo, or the
/// company's name, right), then the tenant name(s) and address, then the
/// property line. Used as a MultiPage header, so the complete header repeats
/// on every page, like web.
pw.Widget tenantStatementPdfHeader(TenantStatementHeader h,
    {pw.ImageProvider? logo}) {
  final companyLines =
      [h.companyName, ...h.companyLines].where((s) => s.isNotEmpty).toList();
  final toLines = [
    if (h.tenantNames.isNotEmpty) h.tenantNames.join(', '),
    ...h.mailingLines,
  ];

  pw.Widget logoOrName() {
    if (logo != null) {
      // Web's 42 x 24 mm box.
      return pw.ConstrainedBox(
        constraints: const pw.BoxConstraints(maxWidth: 119, maxHeight: 68),
        child: pw.Image(logo, fit: pw.BoxFit.contain),
      );
    }
    if (h.companyName.isEmpty) return pw.SizedBox();
    return pw.Text(h.companyName,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
            fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink));
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final line in companyLines)
                  pw.Text(line,
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(h.title,
                    style: const pw.TextStyle(fontSize: 18, color: _ink)),
                if (h.dateRangeText.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4),
                    child: pw.Text(h.dateRangeText,
                        style: const pw.TextStyle(fontSize: 11, color: _ink)),
                  ),
                if (h.reportDate.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text('Report Date: ${h.reportDate}',
                        style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  ),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Align(
              alignment: pw.Alignment.topRight,
              child: logoOrName(),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 11),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final line in toLines)
              pw.Text(line, style: const pw.TextStyle(fontSize: 11, color: _ink)),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
      if (h.propertyLine.isNotEmpty)
        pw.Text(h.propertyLine,
            style: const pw.TextStyle(fontSize: 10, color: _ink)),
      pw.SizedBox(height: 8),
    ],
  );
}

/// The Tenant Statement table, like web's drawTenantStatementPdf (autoTable,
/// striped): Date, Tenant, Type, Description, Charge, Payment, Balance; a
/// grey header with dark bold text, rows 1, 3, 5... shaded, no borders, and
/// Charge, Payment and Balance on the right, their headers too.
pw.Widget tenantStatementPdfTable(List<List<String>> rows) {
  final moneyRight = {
    for (final c in tenantStatementMoneyColumns) c: pw.Alignment.topRight,
  };
  return pw.TableHelper.fromTextArray(
    headers: tenantStatementHead,
    data: rows,
    border: null,
    headerDecoration:
        const pw.BoxDecoration(color: PdfColor.fromInt(0xFFDEE2E6)),
    headerStyle: pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: _ink),
    cellStyle:
        const pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF505050)),
    // Web shades the 1st, 3rd, 5th... body row (autoTable's striped theme);
    // the others are white.
    rowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
    oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
    headerPadding: const pw.EdgeInsets.all(5),
    cellPadding: const pw.EdgeInsets.all(5),
    headerAlignment: pw.Alignment.topLeft,
    cellAlignment: pw.Alignment.topLeft,
    headerAlignments: moneyRight,
    cellAlignments: moneyRight,
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2), // Date
      1: pw.FlexColumnWidth(1.25), // Tenant
      2: pw.FlexColumnWidth(0.95), // Type
      3: pw.FlexColumnWidth(2.25), // Description
      4: pw.FlexColumnWidth(1.0), // Charge
      5: pw.FlexColumnWidth(1.0), // Payment
      6: pw.FlexColumnWidth(0.95), // Balance
    },
  );
}
