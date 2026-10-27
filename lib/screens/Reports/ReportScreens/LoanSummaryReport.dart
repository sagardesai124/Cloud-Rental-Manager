import 'dart:io';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/LoanSummaryReportService.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';

class Loansummaryreport extends StatefulWidget {
  const Loansummaryreport({super.key});

  @override
  State<Loansummaryreport> createState() => _LoansummaryreportState();
}

class _LoansummaryreportState extends State<Loansummaryreport>
    with NetworkRetryState {
  final LoanSummaryReportService _service = LoanSummaryReportService();

  List<LoanSummaryItem> _allItems = [];
  List<LoanSummaryItem> _filteredItems = [];
  bool _isLoading = false;
  String? _error;

  String _selectedLender = 'All Lenders';
  List<String> _lenderOptions = ['All Lenders'];

  int? _expandedIndex;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadData();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId') ?? '';
      final items = await _service.fetchLoanSummary(adminId);
      if (items != null) {
        final lenders = items.map((e) => e.bankName).toSet().toList()..sort();
        setState(() {
          _allItems = items;
          _lenderOptions = ['All Lenders', ...lenders];
          _applyFilter();
        });
      } else {
        setState(() => _error = 'Failed to load loan summary report.');
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_selectedLender == 'All Lenders') {
      _filteredItems = List.from(_allItems);
    } else {
      _filteredItems =
          _allItems.where((e) => e.bankName == _selectedLender).toList();
    }
    _expandedIndex = null;
  }

  String _fmtCurrency(double value) =>
      NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(value);

  String _fmtDate(String iso) {
    try {
      return DateFormat('MM/dd/yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _fmtLtv(double? ltv) =>
      ltv == null ? '—' : '${ltv.toStringAsFixed(1)}%';

  // ─── Export ───────────────────────────────────────────────────────────────

  List<String> get _headers => [
        'Lender', 'Loan #', 'Properties', 'Property Value',
        'Balance', 'LTV', 'NOI', 'Debt Service', 'DSCR',
        'Start Date', 'End Date', 'Addresses',
      ];

  List<List<String>> get _rows => _filteredItems.map((i) => [
        i.bankName, i.mortgageNo, i.propertyCount.toString(),
        _fmtCurrency(i.propertyValue), _fmtCurrency(i.remainingBalance),
        _fmtLtv(i.ltvPercent), _fmtCurrency(i.noi),
        _fmtCurrency(i.debtService), i.dscr.toStringAsFixed(2),
        _fmtDate(i.startDate), _fmtDate(i.endDate),
        i.properties.join('; '),
      ]).toList();

  Future<void> _exportPdf() async {
    if (_filteredItems.isEmpty) {
      Fluttertoast.showToast(msg: 'No data to export');
      return;
    }
    try {
      profile? profileData;
      try { profileData = await GetAddressAdminPdfService().fetchAdminAddress(); } catch (_) {}
      final pdf = pw.Document();
      final logo = pw.MemoryImage(
        (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
      );
      final now = DateFormat('MM/dd/yyyy').format(DateTime.now());
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(color: PdfColors.grey, fontSize: 9)),
        ),
        header: (ctx) => pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Image(logo, width: 44, height: 44),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Loan Summary Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Generated on: $now', style: pw.TextStyle(fontSize: 9)),
              if (_selectedLender != 'All Lenders')
                pw.Text('Lender: $_selectedLender', style: pw.TextStyle(fontSize: 9)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              if (profileData?.companyName?.isNotEmpty == true)
                pw.Text(profileData!.companyName!,
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              if (profileData?.companyAddress?.isNotEmpty == true)
                pw.Text(profileData!.companyAddress!, style: pw.TextStyle(fontSize: 9)),
            ]),
          ]),
          pw.SizedBox(height: 16),
        ]),
        build: (ctx) => [
          pw.TableHelper.fromTextArray(
            headers: _headers,
            data: _rows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#152B51')),
            cellStyle: pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            border: null,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.4),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(0.6),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(0.7),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1),
              8: const pw.FlexColumnWidth(0.6),
              9: const pw.FlexColumnWidth(0.9),
              10: const pw.FlexColumnWidth(0.9),
              11: const pw.FlexColumnWidth(2),
            },
          ),
        ],
      ));
      if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'Loan_Summary_Report.pdf');
    } else {
      await Printing.layoutPdf(
          name: 'Loan_Summary_Report',
          format: PdfPageFormat.a4.landscape,
          onLayout: (_) async => pdf.save());
    }
      Fluttertoast.showToast(msg: 'PDF exported successfully');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error generating PDF: ${friendlyErrorMessage(e)}');
    }
  }

  Future<void> _exportExcel() async {
    if (_filteredItems.isEmpty) {
      Fluttertoast.showToast(msg: 'No data to export');
      return;
    }
    try {
      final workbook = syncXlsx.Workbook();
      final sheet = workbook.worksheets[0];
      sheet.name = 'Loan Summary';
      sheet.getRangeByIndex(1, 1).setText('Loan Summary Report');
      sheet.getRangeByIndex(1, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(1, 1).cellStyle.fontSize = 14;
      sheet.getRangeByIndex(2, 1).setText(
          'Generated on: ${DateFormat('MM/dd/yyyy').format(DateTime.now())}');
      if (_selectedLender != 'All Lenders')
        sheet.getRangeByIndex(3, 1).setText('Lender: $_selectedLender');
      for (int i = 0; i < _headers.length; i++) {
        sheet.getRangeByIndex(5, i + 1).setText(_headers[i]);
        sheet.getRangeByIndex(5, i + 1).cellStyle.bold = true;
        sheet.getRangeByIndex(5, i + 1).cellStyle.backColor = '#152B51';
        sheet.getRangeByIndex(5, i + 1).cellStyle.fontColor = '#FFFFFF';
      }
      int row = 6;
      for (final r in _rows) {
        for (int i = 0; i < r.length; i++) {
          sheet.getRangeByIndex(row, i + 1).setText(r[i]);
          if (row.isEven)
            sheet.getRangeByIndex(row, i + 1).cellStyle.backColor = '#F4F8FF';
        }
        row++;
      }
      final bytes = workbook.saveAsStream();
      workbook.dispose();
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/LoanSummaryReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Loan Summary Report');
      Fluttertoast.showToast(msg: 'Excel exported successfully');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error generating Excel: ${friendlyErrorMessage(e)}');
    }
  }

  Future<void> _exportCsv() async {
    if (_filteredItems.isEmpty) {
      Fluttertoast.showToast(msg: 'No data to export');
      return;
    }
    try {
      final buf = StringBuffer();
      buf.writeln(_headers.map(_esc).join(','));
      for (final r in _rows) buf.writeln(r.map(_esc).join(','));
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/LoanSummaryReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv');
      await file.writeAsString(buf.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Loan Summary Report');
      Fluttertoast.showToast(msg: 'CSV exported successfully');
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error generating CSV: ${friendlyErrorMessage(e)}');
    }
  }

  String _esc(String v) =>
      (v.contains(',') || v.contains('"') || v.contains('\n'))
          ? '"${v.replaceAll('"', '""')}"'
          : v;

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(currentpage: 'Reports', dropdown: false),
      // This screen had no offline state at all; a failed request used to
      // leave it blank or showing an error string with no way to retry.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReportHeader(title: 'Loan Summary Report'),
          _buildFilterRow(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    // Web parity: Export always shows, greyed while loading or when the
    // lender filter leaves no rows (the rows the export writes).
    final bool hasExportData = !_isLoading && _filteredItems.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          // ── Lender filter dropdown ──────────────────────────────────
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDBE0E5)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedLender,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Filter by Lender',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey[500])),
                  ),
                  items: _lenderOptions
                      .map((l) => DropdownMenuItem(
                            value: l,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(l,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null)
                      setState(() {
                        _selectedLender = val;
                        _applyFilter();
                      });
                  },
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: Color(0xFF8A95A8)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // ── Export button ───────────────────────────────────────────
          PopupMenuButton<String>(
            enabled: hasExportData,
            offset: const Offset(0, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: hasExportData ? blueColor : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Export',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pdf',
                child: Row(children: [
                  Icon(Icons.picture_as_pdf, color: blueColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Export as PDF'),
                ]),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(children: [
                  Icon(Icons.table_chart, color: blueColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Export as Excel'),
                ]),
              ),
              PopupMenuItem(
                value: 'csv',
                child: Row(children: [
                  Icon(Icons.description, color: blueColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Export as CSV'),
                ]),
              ),
            ],
            onSelected: (v) {
              if (v == 'pdf') _exportPdf();
              if (v == 'excel') _exportExcel();
              if (v == 'csv') _exportCsv();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Padding(
          padding: const EdgeInsets.all(8), child: ColabShimmerLoadingWidget());
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(backgroundColor: blueColor),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ]),
      );
    }
    if (_filteredItems.isEmpty) {
      // The standard empty state used across reports.
      return Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset(
              "assets/images/no_data_transparent.png",
              height: 200,
              width: 200,
            ),
            const SizedBox(height: 10),
            Text(
              "No Data Available",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
            ),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 4),
          _buildHeaderRow(),
          const SizedBox(height: 8),
          if (_filteredItems.isEmpty) kNoSearchResults(context),
          ..._filteredItems.asMap().entries.map((e) =>
              _buildDataRow(e.value, e.key)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Table header row ──────────────────────────────────────────────────────
  Widget _buildHeaderRow() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            // invisible spacer matching chevron width
            const Icon(Icons.expand_less, color: Colors.transparent),
            Expanded(
              child: Text('Lender',
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Expanded(
              child: Text('Loan #',
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ── Data row (collapsed + expanded) ──────────────────────────────────────
  Widget _buildDataRow(LoanSummaryItem item, int index) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: index % 2 != 0 ? const Color(0xFFF4F8FF) : Colors.white,
        border: Border.all(color: const Color(0xFFDBE0E5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // ── Collapsed header ────────────────────────────────────────
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Padding(
              padding: const EdgeInsets.all(2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Chevron toggle
                  InkWell(
                    onTap: () => setState(() =>
                        _expandedIndex = isExpanded ? null : index),
                    child: Container(
                      margin: const EdgeInsets.only(left: 5),
                      padding: isExpanded
                          ? const EdgeInsets.only(top: 10)
                          : const EdgeInsets.only(bottom: 10),
                      child: FaIcon(
                        isExpanded
                            ? FontAwesomeIcons.sortUp
                            : FontAwesomeIcons.sortDown,
                        size: 20,
                        color: blueColor,
                      ),
                    ),
                  ),
                  // Lender name
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() =>
                          _expandedIndex = isExpanded ? null : index),
                      child: Text(
                        '   ${item.bankName}',
                        style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                      width: MediaQuery.of(context).size.width * .04),
                  // Loan #
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() =>
                          _expandedIndex = isExpanded ? null : index),
                      child: Text(
                        item.mortgageNo,
                        style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                      width: MediaQuery.of(context).size.width * .02),
                ],
              ),
            ),
          ),

          // ── Expanded details ────────────────────────────────────────
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // invisible spacer row
                  Row(children: [
                    FaIcon(FontAwesomeIcons.sortUp,
                        size: 50, color: Colors.transparent),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: Properties | Property Value | Balance
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _detailField(
                                    'Properties :',
                                    item.propertyCount.toString()),
                              ),
                              Expanded(
                                child: _detailField(
                                    'Property Value :',
                                    _fmtCurrency(item.propertyValue)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Row 2: Balance | LTV
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _detailField(
                                    'Balance :',
                                    _fmtCurrency(item.remainingBalance)),
                              ),
                              Expanded(
                                child: _detailField(
                                    'LTV :', _fmtLtv(item.ltvPercent)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Row 3: NOI | Debt Service
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _detailField(
                                    'NOI :',
                                    _fmtCurrency(item.noi)),
                              ),
                              Expanded(
                                child: _detailField(
                                    'Debt Service :',
                                    _fmtCurrency(item.debtService)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Row 4: DSCR | Start Date | End Date
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _detailField(
                                    'DSCR :',
                                    item.dscr.toStringAsFixed(2)),
                              ),
                              Expanded(
                                child: _detailField(
                                    'Start Date :',
                                    _fmtDate(item.startDate)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _detailField(
                              'End Date :',
                              _fmtDate(item.endDate)),
                          // Properties list
                          if (item.properties.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text.rich(TextSpan(children: [
                              TextSpan(
                                text: 'Properties :   ',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: blueColor),
                              ),
                            ])),
                            const SizedBox(height: 4),
                            ...item.properties.map((addr) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 13, color: grey),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          addr,
                                          style: TextStyle(
                                              color: grey,
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(TextSpan(children: [
        TextSpan(
          text: label + '   ',
          style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
        ),
        TextSpan(
          text: value,
          style: TextStyle(fontWeight: FontWeight.w700, color: grey),
        ),
      ])),
    );
  }
}
