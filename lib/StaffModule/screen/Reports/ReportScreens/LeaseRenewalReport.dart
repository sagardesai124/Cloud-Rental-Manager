import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:three_zero_two_property/Model/lease_renewal_report.dart'
    as model;
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/StaffModule/repository/lease_renewal_report_repo.dart';
import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart' as widget_302_Staff;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class LeaseRenewalReportScreen extends StatefulWidget {
  @override
  _LeaseRenewalReportScreenState createState() =>
      _LeaseRenewalReportScreenState();
}

class _LeaseRenewalReportScreenState extends State<LeaseRenewalReportScreen>
    with NetworkRetryState {
  final LeaseRenewalReportRepository _repository =
      LeaseRenewalReportRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  /// Web's From/To check (null when the range is fine).
  String? get _dateRangeError =>
      reportDateRangeError(_startDateController.text, _endDateController.text);

  model.LeaseRenewalReport? _reportData;
  bool _isLoading = false;
  String _searchQuery = '';
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  String? _selectedDateRange = 'Last Year';
  bool _showCustomDates = false;

  // Expanded state for leases ending
  Map<int, bool> _expandedLeasesEnding = {};
  // Expanded state for month-to-month leases
  Map<int, bool> _expandedMtmLeases = {};

  /// Required by [NetworkRetryState]: re-issue this screen's own load,
  /// called by the Retry button and when the connection comes back.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    // Just the fetch. initState also seeds the default date range, which a
    // reload must NOT redo or it would throw away the user's chosen dates.
    await _fetchReport();
  }

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    // Set default date range (last year)
    _updateDateRange('Last Year');
    _fetchReport();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back; confirm before
    // believing it, or this screen strands itself offline.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Convert date format from MM/dd/yyyy to yyyy-MM-dd for API
      String? startDate;
      String? endDate;
      if (_startDateController.text.isNotEmpty &&
          _endDateController.text.isNotEmpty) {
        try {
          final start =
              DateFormat('MM/dd/yyyy').parse(_startDateController.text);
          final end = DateFormat('MM/dd/yyyy').parse(_endDateController.text);
          startDate = DateFormat('yyyy-MM-dd').format(start);
          endDate = DateFormat('yyyy-MM-dd').format(end);
        } catch (e) {
          // If parsing fails, try yyyy-MM-dd format
          startDate = _startDateController.text;
          endDate = _endDateController.text;
        }
      }

      final report = await _repository.fetchLeaseRenewalReport(
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _reportData = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      Fluttertoast.showToast(
        msg: 'Error loading report: ${friendlyErrorMessage(e)}',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  void _updateDateRange(String? range) {
    final now = DateTime.now();
    setState(() {
      _selectedDateRange = range;
      _showCustomDates = range == 'Custom';

      if (range == 'Last Year') {
        _startDateController.text =
            DateFormat('MM/dd/yyyy').format(DateTime(now.year - 1, 1, 1));
        _endDateController.text =
            DateFormat('MM/dd/yyyy').format(DateTime(now.year - 1, 12, 31));
      } else if (range == 'This Year') {
        _startDateController.text =
            DateFormat('MM/dd/yyyy').format(DateTime(now.year, 1, 1));
        _endDateController.text =
            DateFormat('MM/dd/yyyy').format(DateTime(now.year, 12, 31));
      } else if (range == 'This Month') {
        _startDateController.text =
            DateFormat('MM/dd/yyyy').format(DateTime(now.year, now.month, 1));
        _endDateController.text = DateFormat('MM/dd/yyyy')
            .format(DateTime(now.year, now.month + 1, 0));
      } else if (range == 'Last Month') {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDateController.text = DateFormat('MM/dd/yyyy').format(lastMonth);
        _endDateController.text =
            DateFormat('MM/dd/yyyy').format(DateTime(now.year, now.month, 0));
      }
    });
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateFormat('MM/dd/yyyy').parse(controller.text)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  List<model.LeaseEnding> get _filteredLeasesEnding {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.leasesEnding;

    final query = _searchQuery.toLowerCase();
    return _reportData!.leasesEnding.where((lease) {
      return lease.propertyAddress.toLowerCase().contains(query) ||
          lease.tenants
              .any((tenant) => tenant.tenantName.toLowerCase().contains(query));
    }).toList();
  }

  List<model.MonthToMonthLease> get _filteredMtmLeases {
    if (_reportData == null) return [];
    if (_searchQuery.isEmpty) return _reportData!.mtmLeases;

    final query = _searchQuery.toLowerCase();
    return _reportData!.mtmLeases.where((lease) {
      return lease.propertyAddress.toLowerCase().contains(query) ||
          lease.tenants
              .any((tenant) => tenant.tenantName.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _generatePdf() async {
    if (_reportData == null) {
      Fluttertoast.showToast(msg: 'No data to export');
      return;
    }

    try {
      final GetAddressAdminPdfService service = GetAddressAdminPdfService();
      profile? profileData;

      try {
        profileData = await service.fetchAdminAddress();
      } catch (e) {
        logError("Error fetching profile data: $e");
      }

      final pdf = pw.Document();
      final image = pw.MemoryImage(
        (await rootBundle.load('assets/images/applogo.png'))
            .buffer
            .asUint8List(),
      );
      final currentDate = DateFormat('MM/dd/yyyy').format(DateTime.now());
      final dateRange =
          '${_startDateController.text} to ${_endDateController.text}';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(30),
          footer: (pw.Context context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(color: PdfColors.grey),
              ),
            );
          },
          header: (pw.Context context) => pw.Column(children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 50, height: 50),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Lease Renewal Report',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated on: $currentDate',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Date Range: $dateRange',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (profileData != null) ...[
                      pw.Text(
                        profileData.companyName ?? '',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (profileData.companyAddress?.isNotEmpty == true)
                        pw.Text(
                          profileData.companyAddress!,
                          style: pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20)
          ]),
          build: (pw.Context context) {
            return [
              // Leases Ending Section
              pw.Text(
                'LEASES ENDING',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: [
                  'Property',
                  'Tenant',
                  '2023 Rent',
                  '2024 Rent',
                  'Deposits',
                  'New Rent',
                  'Includes Trash?',
                  'Increase',
                  'Times Late',
                  'Court Filings',
                  'Need Trash Svc?',
                  'Notes',
                ],
                data: _generateLeasesEndingTableData(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5A86D5"),
                ),
                cellStyle: pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                  6: pw.FlexColumnWidth(1),
                  7: pw.FlexColumnWidth(1),
                  8: pw.FlexColumnWidth(0.8),
                  9: pw.FlexColumnWidth(0.8),
                  10: pw.FlexColumnWidth(1),
                  11: pw.FlexColumnWidth(2),
                },
                border: null,
              ),
              pw.SizedBox(height: 20),
              // MTM Leases Section
              pw.Text(
                'MTM LEASES',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: [
                  'Property',
                  'Tenant',
                  '2023 Rent',
                  '2024 Rent',
                  '2025 Rent',
                  'Last Increase',
                  'Sec. Dep.',
                  'New Rent',
                  'Includes Trash?',
                  'Increase',
                  'Late',
                  'Court',
                  'Need Trash Svc?',
                  'Notes',
                ],
                data: _generateMtmLeasesTableData(),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5A86D5"),
                ),
                cellStyle: pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: pw.FlexColumnWidth(1.5),
                  1: pw.FlexColumnWidth(1.5),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                  6: pw.FlexColumnWidth(1),
                  7: pw.FlexColumnWidth(1),
                  8: pw.FlexColumnWidth(1),
                  9: pw.FlexColumnWidth(1),
                  10: pw.FlexColumnWidth(0.8),
                  11: pw.FlexColumnWidth(0.8),
                  12: pw.FlexColumnWidth(1),
                  13: pw.FlexColumnWidth(2),
                },
                border: null,
              ),
            ];
          },
        ),
      );

      if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'LeaseRenewalReport.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'LeaseRenewalReport',
        format: PdfPageFormat.a4.landscape,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }

      Fluttertoast.showToast(msg: 'PDF exported successfully');
    } catch (e) {
      logError('Error generating PDF: $e');
      Fluttertoast.showToast(msg: 'Error generating PDF: ${friendlyErrorMessage(e)}');
    }
  }

  List<List<dynamic>> _generateLeasesEndingTableData() {
    final List<List<dynamic>> tableData = [];

    for (var lease in _filteredLeasesEnding) {
      final tenant = lease.tenants.isNotEmpty ? lease.tenants.first : null;
      final notes = lease.notes.isNotEmpty
          ? lease.notes.map((n) => n.content).join(', ')
          : 'No notes';

      tableData.add([
        lease.propertyAddress,
        tenant?.tenantName ?? 'N/A',
        _formatCurrency(lease.rentData.rentYear1),
        _formatCurrency(lease.rentData.rentYear2),
        _formatCurrency(lease.deposits.totalDeposits),
        _formatCurrency(lease.rentData.newRentAmount),
        lease.rentData.newRentIncludesTrashService,
        _formatCurrency(lease.rentData.rentIncrease),
        lease.metrics.timeLateCount.toString(),
        lease.metrics.courtFilings.toString(),
        lease.tenantNeedsTrashService,
        notes,
      ]);
    }

    return tableData;
  }

  List<List<dynamic>> _generateMtmLeasesTableData() {
    final List<List<dynamic>> tableData = [];

    for (var lease in _filteredMtmLeases) {
      final tenant = lease.tenants.isNotEmpty ? lease.tenants.first : null;
      final notes = lease.notes.isNotEmpty
          ? lease.notes.map((n) {
              try {
                final date =
                    DateFormat('yyyy-MM-dd HH:mm:ss').parse(n.createdAt);
                return '${DateFormat('MM/dd/yyyy').format(date)}-${n.content}';
              } catch (e) {
                return n.content;
              }
            }).join(', ')
          : 'No notes';

      tableData.add([
        lease.propertyAddress,
        tenant?.tenantName ?? 'N/A',
        _formatCurrency(lease.rentData.rentYear1),
        _formatCurrency(lease.rentData.rentYear2),
        _formatCurrency(lease.rentData.rentYear3),
        lease.rentData.lastIncreaseDate.isNotEmpty
            ? lease.rentData.lastIncreaseDate
            : 'N/A',
        _formatCurrency(lease.deposits.totalDeposits),
        _formatCurrency(lease.rentData.newRentAmount),
        lease.rentData.newRentIncludesTrashService,
        _formatCurrency(lease.rentData.rentIncrease),
        lease.metrics.timeLateCount.toString(),
        lease.metrics.courtFilings.toString(),
        lease.tenantNeedsTrashService,
        notes,
      ]);
    }

    return tableData;
  }

  Future<void> _generateExcel() async {
    if (_reportData == null) {
      Fluttertoast.showToast(msg: 'No data to export');
      return;
    }

    try {
      final syncXlsx.Workbook workbook = syncXlsx.Workbook();

      // Leases Ending Sheet
      final syncXlsx.Worksheet sheet1 = workbook.worksheets[0];
      sheet1.name = 'Leases Ending';

      // Title and date range
      sheet1.getRangeByIndex(1, 1).setText('Lease Renewal Report');
      sheet1.getRangeByIndex(1, 1).cellStyle.bold = true;
      sheet1.getRangeByIndex(1, 1).cellStyle.fontSize = 16;

      final currentDate = DateFormat('MM/dd/yyyy').format(DateTime.now());
      final dateRange =
          '${_startDateController.text} to ${_endDateController.text}';
      sheet1.getRangeByIndex(2, 1).setText('Generated on: $currentDate');
      sheet1.getRangeByIndex(3, 1).setText('Date Range: $dateRange');
      sheet1.getRangeByIndex(4, 1).setText(''); // Empty row

      // Headers for Leases Ending
      final headers1 = [
        'Property',
        'Tenant',
        '2023 Rent',
        '2024 Rent',
        'Deposits',
        'New Rent',
        'Includes Trash?',
        'Increase',
        'Times Late',
        'Court Filings',
        'Need Trash Svc?',
        'Notes',
      ];

      for (int i = 0; i < headers1.length; i++) {
        sheet1.getRangeByIndex(5, i + 1).setText(headers1[i]);
        sheet1.getRangeByIndex(5, i + 1).cellStyle.bold = true;
        sheet1.getRangeByIndex(5, i + 1).cellStyle.backColor = '#5A86D5';
        sheet1.getRangeByIndex(5, i + 1).cellStyle.fontColor = '#FFFFFF';
      }

      // Data for Leases Ending
      int row = 6;
      for (var lease in _filteredLeasesEnding) {
        final tenant = lease.tenants.isNotEmpty ? lease.tenants.first : null;
        final notes = lease.notes.isNotEmpty
            ? lease.notes.map((n) => n.content).join(', ')
            : 'No notes';

        sheet1.getRangeByIndex(row, 1).setText(lease.propertyAddress);
        sheet1.getRangeByIndex(row, 2).setText(tenant?.tenantName ?? 'N/A');
        sheet1
            .getRangeByIndex(row, 3)
            .setText(_formatCurrency(lease.rentData.rentYear1));
        sheet1
            .getRangeByIndex(row, 4)
            .setText(_formatCurrency(lease.rentData.rentYear2));
        sheet1
            .getRangeByIndex(row, 5)
            .setText(_formatCurrency(lease.deposits.totalDeposits));
        sheet1
            .getRangeByIndex(row, 6)
            .setText(_formatCurrency(lease.rentData.newRentAmount));
        sheet1
            .getRangeByIndex(row, 7)
            .setText(lease.rentData.newRentIncludesTrashService);
        sheet1
            .getRangeByIndex(row, 8)
            .setText(_formatCurrency(lease.rentData.rentIncrease));
        sheet1
            .getRangeByIndex(row, 9)
            .setNumber(lease.metrics.timeLateCount.toDouble());
        sheet1
            .getRangeByIndex(row, 10)
            .setNumber(lease.metrics.courtFilings.toDouble());
        sheet1.getRangeByIndex(row, 11).setText(lease.tenantNeedsTrashService);
        sheet1.getRangeByIndex(row, 12).setText(notes);
        row++;
      }

      // MTM Leases Sheet
      final syncXlsx.Worksheet sheet2 = workbook.worksheets.add();
      sheet2.name = 'MTM Leases';

      // Title and date range
      sheet2.getRangeByIndex(1, 1).setText('Lease Renewal Report');
      sheet2.getRangeByIndex(1, 1).cellStyle.bold = true;
      sheet2.getRangeByIndex(1, 1).cellStyle.fontSize = 16;
      sheet2.getRangeByIndex(2, 1).setText('Generated on: $currentDate');
      sheet2.getRangeByIndex(3, 1).setText('Date Range: $dateRange');
      sheet2.getRangeByIndex(4, 1).setText(''); // Empty row

      // Headers for MTM Leases
      final headers2 = [
        'Property',
        'Tenant',
        '2023 Rent',
        '2024 Rent',
        '2025 Rent',
        'Last Increase',
        'Sec. Dep.',
        'New Rent',
        'Includes Trash?',
        'Increase',
        'Late',
        'Court',
        'Need Trash Svc?',
        'Notes',
      ];

      for (int i = 0; i < headers2.length; i++) {
        sheet2.getRangeByIndex(5, i + 1).setText(headers2[i]);
        sheet2.getRangeByIndex(5, i + 1).cellStyle.bold = true;
        sheet2.getRangeByIndex(5, i + 1).cellStyle.backColor = '#5A86D5';
        sheet2.getRangeByIndex(5, i + 1).cellStyle.fontColor = '#FFFFFF';
      }

      // Data for MTM Leases
      row = 6;
      for (var lease in _filteredMtmLeases) {
        final tenant = lease.tenants.isNotEmpty ? lease.tenants.first : null;
        final notes = lease.notes.isNotEmpty
            ? lease.notes
                .map((n) {
                  try {
                    final date = DateFormat('yyyy-MM-dd HH:mm:ss')
                        .parse(n.createdAt);
                    return '${DateFormat('MM/dd/yyyy').format(date)}-${n.content}';
                  } catch (e) {
                    return n.content;
                  }
                })
                .join(', ')
            : 'No notes';

        sheet2.getRangeByIndex(row, 1).setText(lease.propertyAddress);
        sheet2.getRangeByIndex(row, 2).setText(tenant?.tenantName ?? 'N/A');
        sheet2
            .getRangeByIndex(row, 3)
            .setText(_formatCurrency(lease.rentData.rentYear1));
        sheet2
            .getRangeByIndex(row, 4)
            .setText(_formatCurrency(lease.rentData.rentYear2));
        sheet2
            .getRangeByIndex(row, 5)
            .setText(_formatCurrency(lease.rentData.rentYear3));
        sheet2.getRangeByIndex(row, 6).setText(
            lease.rentData.lastIncreaseDate.isNotEmpty
                ? lease.rentData.lastIncreaseDate
                : 'N/A');
        sheet2
            .getRangeByIndex(row, 7)
            .setText(_formatCurrency(lease.deposits.totalDeposits));
        sheet2
            .getRangeByIndex(row, 8)
            .setText(_formatCurrency(lease.rentData.newRentAmount));
        sheet2
            .getRangeByIndex(row, 9)
            .setText(lease.rentData.newRentIncludesTrashService);
        sheet2
            .getRangeByIndex(row, 10)
            .setText(_formatCurrency(lease.rentData.rentIncrease));
        sheet2
            .getRangeByIndex(row, 11)
            .setNumber(lease.metrics.timeLateCount.toDouble());
        sheet2
            .getRangeByIndex(row, 12)
            .setNumber(lease.metrics.courtFilings.toDouble());
        sheet2.getRangeByIndex(row, 13).setText(lease.tenantNeedsTrashService);
        sheet2.getRangeByIndex(row, 14).setText(notes);
        row++;
      }

      // Save file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'LeaseRenewalReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
      final filePath = '${directory.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Lease Renewal Report',
      );

      Fluttertoast.showToast(msg: 'Excel exported successfully');
    } catch (e) {
      logError('Error generating Excel: $e');
      Fluttertoast.showToast(msg: 'Error generating Excel: ${friendlyErrorMessage(e)}');
    }
  }

  Widget _buildLeaseEndingCard(model.LeaseEnding lease, int index) {
    final isExpanded = _expandedLeasesEnding[index] ?? false;
    final tenant = lease.tenants.isNotEmpty ? lease.tenants.first : null;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFDBE0E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _expandedLeasesEnding[index] = !isExpanded;
              });
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lease.propertyAddress,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (tenant != null)
                        Text(
                          tenant.tenantName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedLeasesEnding[index] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: !isExpanded
                        ? EdgeInsets.only(bottom: 10)
                        : EdgeInsets.only(top: 10),
                    child: FaIcon(
                      isExpanded
                          ? FontAwesomeIcons.sortUp
                          : FontAwesomeIcons.sortDown,
                      size: 20,
                      color: blueColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) _buildExpandedContent(lease, true),
        ],
      ),
    );
  }

  Widget _buildMtmLeaseCard(model.MonthToMonthLease lease, int index) {
    final isExpanded = _expandedMtmLeases[index] ?? false;
    final tenant = lease.tenants.isNotEmpty ? lease.tenants.first : null;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFDBE0E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _expandedMtmLeases[index] = !isExpanded;
              });
            },
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lease.propertyAddress,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (tenant != null)
                        Text(
                          tenant.tenantName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _expandedMtmLeases[index] = !isExpanded;
                    });
                  },
                  child: Container(
                    padding: !isExpanded
                        ? EdgeInsets.only(bottom: 10)
                        : EdgeInsets.only(top: 10),
                    child: FaIcon(
                      isExpanded
                          ? FontAwesomeIcons.sortUp
                          : FontAwesomeIcons.sortDown,
                      size: 20,
                      color: blueColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isExpanded) _buildExpandedContent(lease, false),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(dynamic lease, bool isLeaseEnding) {
    // lease can be either model.LeaseEnding or model.MonthToMonthLease
    final rentData = lease.rentData;
    final deposits = lease.deposits;
    final metrics = lease.metrics;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFDBE0E5))),
        color: Colors.grey[50],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial Details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('${rentData.year1} RENT',
                        _formatCurrency(rentData.rentYear1)),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        'DEPOSIT', _formatCurrency(deposits.totalDeposits)),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        'INCREASE',
                        rentData.rentIncrease > 0
                            ? '+${_formatCurrency(rentData.rentIncrease)}'
                            : _formatCurrency(rentData.rentIncrease),
                        isGreen: rentData.rentIncrease > 0),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        'TIMES LATE', metrics.timeLateCount.toString()),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('${rentData.year2} RENT',
                        _formatCurrency(rentData.rentYear2)),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        'NEW RENT', _formatCurrency(rentData.newRentAmount),
                        isHighlight: true),
                    SizedBox(height: 8),
                    _buildDetailRow(
                        'COURT FILINGS',
                        metrics.courtFilings > 0
                            ? metrics.courtFilings.toString()
                            : 'None'),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Notes Section
          if (lease.notes.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              'NOTES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lease.notes.map<Widget>((note) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      note.content,
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isHighlight = false, bool isGreen = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isHighlight
                ? blueColor
                : isGreen
                    ? Colors.green
                    : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Grey only when the report genuinely has no leases (raw), NOT when the
    // text search narrows the view to empty.
    final bool hasExportData = (_reportData?.leasesEnding.isNotEmpty ?? false) ||
        (_reportData?.mtmLeases.isNotEmpty ?? false);
    return Scaffold(
      appBar: widget_302_Staff.widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Reports",
        dropdown: false,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Lease Renewal Report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: blueColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Field
                        Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFDBE0E5)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(fontSize: 14),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            cursorColor: blueColor,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Search here...",
                              hintStyle: TextStyle(
                                color: Color(0xFF8A95A8),
                                fontSize: 14,
                              ),
                              suffixIcon: Icon(
                                Icons.search,
                                color: Color(0xFF8A95A8),
                                size: 20,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Date Range Dropdown
                        Text(
                          'Date Range',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFDBE0E5)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedDateRange,
                              items: [
                                'Last Year',
                                'This Year',
                                'This Month',
                                'Last Month',
                                'Custom',
                              ].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      value,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                _updateDateRange(newValue);
                              },
                              icon: Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(Icons.keyboard_arrow_down,
                                    color: Color(0xFF8A95A8)),
                              ),
                            ),
                          ),
                        ),
                        // Custom Date Fields (shown when Custom is selected)
                        if (_showCustomDates) ...[
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Color(0xFFDBE0E5)),
                                      ),
                                      child: TextField(
                                        controller: _startDateController,
                                        readOnly: true,
                                        onTap: () => _selectDate(
                                            context, _startDateController),
                                        style: TextStyle(fontSize: 14),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "MM/DD/YYYY",
                                          hintStyle: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontSize: 14,
                                          ),
                                          suffixIcon: Icon(
                                            Icons.calendar_today,
                                            color: Color(0xFF8A95A8),
                                            size: 20,
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'To',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Color(0xFFDBE0E5)),
                                      ),
                                      child: TextField(
                                        controller: _endDateController,
                                        readOnly: true,
                                        onTap: () => _selectDate(
                                            context, _endDateController),
                                        style: TextStyle(fontSize: 14),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "MM/DD/YYYY",
                                          hintStyle: TextStyle(
                                            color: Color(0xFF8A95A8),
                                            fontSize: 14,
                                          ),
                                          suffixIcon: Icon(
                                            Icons.calendar_today,
                                            color: Color(0xFF8A95A8),
                                            size: 20,
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_dateRangeError != null)
                          ReportDateRangeErrorText(_dateRangeError!),
                        SizedBox(height: 24),
                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: _dateRangeError != null ? null : _fetchReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                disabledBackgroundColor: blueColor.withOpacity(0.6),
                                disabledForegroundColor: Colors.white,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Run'),
                            ),
                            SizedBox(width: 12),
                            PopupMenuButton<String>(
                              enabled: hasExportData,
                              offset: Offset(0, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 12),
                                decoration: BoxDecoration(
                                  color: hasExportData
                                      ? blueColor
                                      : Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Export',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down,
                                        color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                              itemBuilder: (BuildContext context) => [
                                PopupMenuItem<String>(
                                  value: 'pdf',
                                  child: Row(
                                    children: [
                                      Icon(Icons.picture_as_pdf,
                                          color: blueColor, size: 20),
                                      SizedBox(width: 8),
                                      Text('Export as PDF'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'excel',
                                  child: Row(
                                    children: [
                                      Icon(Icons.table_chart,
                                          color: blueColor, size: 20),
                                      SizedBox(width: 8),
                                      Text('Export as Excel'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'csv',
                                  child: Row(
                                    children: [
                                      Icon(Icons.description,
                                          color: blueColor, size: 20),
                                      SizedBox(width: 8),
                                      Text('Export as CSV'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (String value) {
                                Navigator.pop(context);
                                if (value == 'pdf') {
                                  _generatePdf();
                                } else if (value == 'excel') {
                                  _generateExcel();
                                } else if (value == 'csv') {
                                  Fluttertoast.showToast(
                                      msg: 'CSV export coming soon');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Content
                  _isLoading
                      ? Padding(
                          padding: EdgeInsets.all(8),
                          child: ColabShimmerLoadingWidget(),
                        )
                      : _reportData == null
                          ? Padding(
                              padding: EdgeInsets.all(40),
                              child: Text(
                                'No data available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leases Ending Section
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'LEASES ENDING (${_filteredLeasesEnding.length})',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  ..._filteredLeasesEnding
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    return _buildLeaseEndingCard(
                                        entry.value, entry.key);
                                  }),
                                  SizedBox(height: 24),
                                  // Month-to-Month Section
                                  Text(
                                    'MONTH-TO-MONTH (${_filteredMtmLeases.length})',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  ..._filteredMtmLeases
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    return _buildMtmLeaseCard(
                                        entry.value, entry.key);
                                  }),
                                  SizedBox(height: 24),
                                ],
                              ),
                            ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}

