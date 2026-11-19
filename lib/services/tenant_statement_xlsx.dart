import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import 'tenant_statement.dart';

/// The Tenant Statement workbook, like web's Excel export (LeaseFinancialTab
/// → XLSX): [rows] (the letterhead rows, the table's header, then its rows)
/// on a sheet named "Statement", with Charge, Payment and Balance on the
/// right in every row, the header too. The caller saves and disposes it.
xlsio.Workbook tenantStatementWorkbook(List<List<String>> rows) {
  final workbook = xlsio.Workbook();
  final sheet = workbook.worksheets[0];
  sheet.name = 'Statement';
  sheet.getRangeByName('A1:G1').columnWidth = 15;
  sheet.getRangeByName('D1').columnWidth = 45;
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final cell = sheet.getRangeByIndex(r + 1, c + 1);
      cell.setText(rows[r][c]);
      if (tenantStatementMoneyColumns.contains(c)) {
        cell.cellStyle.hAlign = xlsio.HAlignType.right;
      }
    }
  }
  return workbook;
}
