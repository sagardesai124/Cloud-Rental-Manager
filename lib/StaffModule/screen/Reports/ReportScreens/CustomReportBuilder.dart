import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/Model/SavedReportModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/CustomReportService.dart';
import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CreateCustomReportScreen.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:three_zero_two_property/screens/Reports/ReportScreens/CustomReportConstants.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';

class CustomReportBuilder extends StatefulWidget {
  const CustomReportBuilder({super.key});

  @override
  State<CustomReportBuilder> createState() => _CustomReportBuilderState();
}

class _CustomReportBuilderState extends State<CustomReportBuilder>
    with NetworkRetryState {
  final CustomReportService _service = CustomReportService();
  List<SavedReport> _savedReports = [];
  SavedReport? _selectedReport;
  bool _loading = true;
  String? _errorMessage;
  String? _adminId;
  List<Map<String, dynamic>> _reportData = [];
  bool _reportDataLoading = false;
  String? _reportDataError;
  int? _expandedRowIndex;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadAdminAndReports();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAdminAndReports();
  }

  Future<void> _loadAdminAndReports() async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    if (adminId == null || adminId.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'Admin ID not found. Please login again.';
      });
      return;
    }
    setState(() => _adminId = adminId);
    await _fetchSavedReports();
  }

  Future<void> _fetchSavedReports() async {
    if (_adminId == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final result =
        await _service.fetchSavedReports(adminId: _adminId!, isStaff: true);
    setState(() {
      _loading = false;
      _savedReports = result.data;
      if (result.statusCode != 200) _errorMessage = result.message;
      // Do not auto-select: user must select a report to see data
    });
  }

  Future<void> _fetchReportData() async {
    if (_adminId == null || _selectedReport == null) {
      setState(() {
        _reportData = [];
        _reportDataError = null;
      });
      return;
    }
    final reportId = _selectedReport!.reportId;
    setState(() {
      _reportDataLoading = true;
      _reportDataError = null;
      _reportData = [];
    });
    // 1) GET /api/reports/saved/:reportId - get report config, then pass same report_id to POST
    final getResult = await _service.fetchSavedReportById(
      adminId: _adminId!,
      reportId: reportId,
      isStaff: true,
    );
    if (getResult.data == null) {
      setState(() {
        _reportDataLoading = false;
        _reportDataError = getResult.message ?? 'Failed to load report config';
      });
      return;
    }
    final reportFromGet = getResult.data!;
    // 2) POST /api/reports/custom - pass full report config from GET (same as web) so backend returns 7
    final result = await _service.fetchCustomReportData(
      adminId: _adminId!,
      reportId: reportFromGet.reportId,
      reportConfig: reportFromGet,
      isStaff: true,
    );
    setState(() {
      _reportDataLoading = false;
      if (result.statusCode == 200) {
        final rawList =
            result.data.map((e) => Map<String, dynamic>.from(e)).toList();
        final count = result.count;
        _reportData = rawList.length > count
            ? rawList.sublist(0, count)
            : rawList;
        _reportDataError = null;
      } else {
        _reportDataError = result.message;
        _reportData = [];
      }
    });
  }

  void _navigateToCreate() async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateCustomReportScreen(adminId: _adminId ?? '', isStaff: true),
      ),
    );
    if (result != null) {
      await _fetchSavedReports();
      setState(() {});
    }
  }

  void _onEditReport(SavedReport report) async {
    final updated = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCustomReportScreen(
          adminId: _adminId ?? '',
          existingReport: report,
          isStaff: true,
        ),
      ),
    );
    if (updated == true) {
      await _fetchSavedReports();
      if (mounted) setState(() {});
    }
  }

  SavedReport? get _dropdownValue {
    if (_selectedReport == null) return null;
    try {
      return _savedReports.firstWhere(
          (r) => r.reportId == _selectedReport!.reportId);
    } catch (_) {
      return null;
    }
  }

  void _onDeleteReport(SavedReport report) {
    Alert(
      context: context,
      type: AlertType.warning,
      title: 'Are you sure?',
      desc: 'Once deleted, you will not be able to recover this report!',
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: Text(
            'Cancel',
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(color: blueColor, width: 1.5),
        ),
        DialogButton(
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            Navigator.pop(context);
            if (_adminId == null) return;
            final res = await _service.deleteReport(
              adminId: _adminId!,
              reportId: report.reportId,
              isStaff: true,
            );
            if (!mounted) return;
            if (res.statusCode == 200) {
              if (_selectedReport?.reportId == report.reportId) {
                setState(() => _selectedReport = null);
              }
              await _fetchSavedReports();
            }
          },
          color: blueColor,
        ),
      ],
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Reports",
        dropdown: false,
      ),
      appBar: widget_302_Staff.App_Bar(context: context),
      // This screen had no offline state at all; a failed request used to
      // leave it blank or showing an error string with no way to retry.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : Column(
        children: [
          const ReportHeader(title: "Custom Report Builder"),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final padding = 24.0 * 2;
                final contentWidth = constraints.maxWidth > 0
                    ? constraints.maxWidth - padding
                    : MediaQuery.of(context).size.width - padding;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (_loading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SpinKitFadingCircle(color: blueColor, size: 50),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading reports...',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: ElevatedButton.icon(
                              onPressed: _navigateToCreate,
                              icon: const Icon(Icons.add, size: 20, color: Colors.white),
                              label: const Text('Create', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: ClipRect(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton2<String>(
                                  isExpanded: true,
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Export',
                                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.download, size: 18, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'pdf', child: Text('Export as PDF')),
                                    DropdownMenuItem(value: 'excel', child: Text('Export as Excel')),
                                    DropdownMenuItem(value: 'csv', child: Text('Export as CSV')),
                                  ],
                                  onChanged: (_reportData.isEmpty || _selectedReport == null)
                                      ? null
                                      : (value) async {
                                          if (value == 'pdf') await _generatePdf();
                                          else if (value == 'excel') await _generateExcel();
                                          else if (value == 'csv') await _generateCsv();
                                        },
                                  buttonStyleData: ButtonStyleData(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: (_reportData.isEmpty || _selectedReport == null)
                                          ? Colors.grey.shade400
                                          : blueColor,
                                    ),
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    maxHeight: 280,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Saved Reports',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton2<SavedReport>(
                                  isExpanded: true,
                                  hint: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      _savedReports.isEmpty ? 'No saved reports' : _dropdownValue?.name ?? 'Select report',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _dropdownValue == null ? const Color(0xFF8A95A8) : Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  items: _savedReports
                                      .map((r) => DropdownMenuItem<SavedReport>(
                                            value: r,
                                            child: Row(
                                              children: [
                                                Expanded(child: Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                                                IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey), onPressed: () { Navigator.pop(context); _onEditReport(r); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                                const SizedBox(width: 4),
                                                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () { Navigator.pop(context); _onDeleteReport(r); }, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                  value: _dropdownValue,
                                  onChanged: _savedReports.isEmpty ? null : (value) {
                                    setState(() { _selectedReport = value; _fetchReportData(); });
                                  },
                                  buttonStyleData: const ButtonStyleData(height: 42, padding: EdgeInsets.symmetric(horizontal: 12)),
                                  dropdownStyleData: DropdownStyleData(maxHeight: 300, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8))),
                                ),
                              ),
                            ),
                          ),
                          // The result count lives in the results header
                          // below - only fetch feedback is shown here.
                          if (_selectedReport != null && _reportDataLoading)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                '(Loading...)',
                                style: TextStyle(fontSize: 13, color: blueColor, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildTableSection(contentWidth),
                      ],
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static const _currencyKeys = {
    'lease_amount',
    'balance',
    'rentDueAmount',
    'purchase_price',
    'insured_value',
    'insurance_premium',
    'tax_amount',
    'zillow_value',
    'remaining_balance',
    'monthly_payment',
    'loan_amount',
  };

  static const _dateKeys = {
    'start_date',
    'end_date',
    'purchase_date',
    'mortgage_start_date',
    'mortgage_end_date',
    'mortgage_update_date',
    'placed_in_service',
  };

  static String formatCurrency(num value) {
    final n = value.toDouble();
    final absStr = NumberFormat('#,##0.00').format(n.abs());
    if (n < 0) return '\$-$absStr';
    return formatMoney(absStr);
  }

  String _formatCellValue(String key, dynamic value,
      [String Function(String)? formatDate]) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    final s = value.toString().trim();
    if (s.isEmpty) return 'N/A';
    if (_currencyKeys.contains(key)) {
      final num? n = num.tryParse(s);
      if (n != null) return formatCurrency(n);
    }
    if (key == 'interest_rate' && num.tryParse(s) != null) return '$s%';
    if (_dateKeys.contains(key) && formatDate != null) return formatDate(s);
    return s;
  }

  Widget _buildDetailCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            softWrap: true,
            overflow: TextOverflow.clip,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    Map<String, dynamic> row,
    List<String> columns,
    bool includeHistory,
  ) {
    final dateProvider =
        Provider.of<DateProvider>(context, listen: false);
    final entries = <MapEntry<String, String>>[];
    // All columns are repeated inside the expanded view - the row header can
    // clip long values (e.g. co-tenant names), so the first two must also be
    // readable in full here.
    final columnsToShow = columns;
    for (final key in columnsToShow) {
      final label = customReportColumnLabels[key] ?? key;
      final raw = row[key];
      final value = _formatCellValue(
          key, raw, dateProvider.formatCurrentDate);
      entries.add(MapEntry(label, value));
    }
    final historyDetailsRaw = row['historyDetails'];
    final historyDetailsList = historyDetailsRaw is List ? historyDetailsRaw : <dynamic>[];
    final hasHistoricValues = includeHistory && historyDetailsList.isNotEmpty;
    final historicEntries = <MapEntry<String, String>>[];
    if (hasHistoricValues) {
      for (final e in historyDetailsList) {
        if (e is Map) {
          final date = e['start_date'] ?? e['date'] ?? e['year'] ?? '';
          final val = e['amount'] ?? e['value'] ?? e['insured_value'];
          if (date.toString().isNotEmpty && val != null) {
            final fmt = val is num
                ? formatCurrency(val)
                : val.toString();
            historicEntries.add(MapEntry(date.toString(), fmt));
          }
        }
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: maxWidth, maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate((entries.length / 2).ceil(), (i) {
                  final left = entries.length > i * 2 ? entries[i * 2] : null;
                  final right = entries.length > i * 2 + 1 ? entries[i * 2 + 1] : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left != null ? _buildDetailCard(left.key, left.value) : const SizedBox.shrink()),
                        const SizedBox(width: 10),
                        Expanded(child: right != null ? _buildDetailCard(right.key, right.value) : const SizedBox.shrink()),
                      ],
                    ),
                  );
                }),
                if (historicEntries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      collapsedBackgroundColor: Colors.grey.shade100,
                      iconColor: blueColor,
                      collapsedIconColor: blueColor,
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Historic Insured Values:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${historicEntries.length} entries',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: blueColor,
                            ),
                          ),
                        ],
                      ),
                      children: historicEntries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              e.key,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// The standard empty state used across reports: the picture with a
  /// bold heading.
  Widget _emptyState(double maxW, String heading) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            "assets/images/no_data_transparent.png",
            height: 200,
            width: 200,
          ),
          const SizedBox(height: 10),
          Text(
            heading,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
                fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTableSection(double contentWidth) {
    final columns = _selectedReport?.selectedColumns ?? [];
    final maxW = contentWidth > 0 ? contentWidth : double.infinity;

    // Like web: "Please select a saved report" until one is picked.
    if (_selectedReport == null || columns.isEmpty) {
      return _emptyState(
          maxW,
          _selectedReport == null
              ? 'Please select a saved report'
              : 'No Data Available');
    }

    if (_reportDataLoading) {
      return Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SpinKitFadingCircle(color: blueColor, size: 50),
              const SizedBox(height: 16),
              const Text('Loading report data...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (_reportDataError != null) {
      return Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          _reportDataError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_reportData.isEmpty) {
      return _emptyState(maxW, 'No Data Available');
    }

    final includeHistory = _selectedReport!.includeHistory;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Padding(
              padding: const EdgeInsets.only(left: 0, right: 0, top: 0, bottom: 8),
              // The dropdown above already names the selected report - this
              // header only carries the result count.
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '(${_reportData.length} ${_reportData.length == 1 ? 'result' : 'results'})',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(_reportData.length, (index) {
              final row = _reportData[index];
              final rowColor = index % 2 != 0
                  ? const Color(0xFFF4F8FF)
                  : Colors.white;
              String titleText;
              if (columns.length >= 2) {
                final k1 = columns[0];
                final k2 = columns[1];
                final l1 = customReportColumnLabels[k1] ?? k1;
                final l2 = customReportColumnLabels[k2] ?? k2;
                final v1 = _formatCellValue(k1, row[k1], dateProvider.formatCurrentDate);
                final v2 = _formatCellValue(k2, row[k2], dateProvider.formatCurrentDate);
                titleText = '$l1: $v1 - $l2: $v2';
              } else if (columns.length == 1) {
                final k1 = columns[0];
                final l1 = customReportColumnLabels[k1] ?? k1;
                final v1 = _formatCellValue(k1, row[k1], dateProvider.formatCurrentDate);
                titleText = '$l1: $v1';
              } else {
                titleText = 'Property';
              }
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: rowColor,
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: ValueKey('report_row_${index}_exp_$_expandedRowIndex'),
                    initiallyExpanded: _expandedRowIndex == index,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _expandedRowIndex = expanded ? index : null;
                      });
                    },
                    tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    collapsedBackgroundColor: rowColor,
                    backgroundColor: rowColor,
                    iconColor: blueColor,
                    collapsedIconColor: blueColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    collapsedShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    title: Text(
                      titleText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: blueColor,
                      ),
                      // Web parity: full value stays visible (web table shows
                      // the complete tenant name) - wrap instead of truncating.
                      softWrap: true,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    children: [
                      _buildExpandedContent(
                          context, row, columns, includeHistory),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    if (_selectedReport == null || _reportData.isEmpty) return;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    try {
      GetAddressAdminPdfService service = GetAddressAdminPdfService();
      profile? profileData;
      try {
        profileData = await service.fetchAdminAddress();
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error fetching admin details',
          toastLength: Toast.LENGTH_SHORT,
        );
        return;
      }
      final image = pw.MemoryImage(
        (await rootBundle.load('assets/images/applogo.png'))
            .buffer
            .asUint8List(),
      );
      final DateTime now = DateTime.now();
      final formattedDateTime = DateFormat('dd/MMM/yyyy HH:mm:ss').format(now);
      final columns = _selectedReport!.selectedColumns;
      final headers =
          columns.map((k) => customReportColumnLabels[k] ?? k).toList();
      final companyName = profileData.companyName ?? '';
      final addressParts = [
        profileData.companyAddress,
        profileData.companyCity,
        profileData.companyState,
        profileData.companyPostalCode,
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      final companyAddress =
          addressParts.isEmpty ? '' : addressParts.join(', ');

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (pw.Context context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(image, width: 40, height: 40),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Custom Report: ${_selectedReport!.name}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Date: $formattedDateTime',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (companyAddress.isNotEmpty)
                    pw.Text(
                      companyAddress,
                      style: pw.TextStyle(fontSize: 9),
                    ),
                  pw.Text(
                    '${context.pageNumber}',
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          build: (pw.Context context) => [
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                for (int i = 0; i < headers.length; i++)
                  i: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#152B51'),
                  ),
                  children: headers
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 9,
                                    color: PdfColors.white)),
                          ))
                      .toList(),
                ),
                ..._reportData.map((row) {
                  return pw.TableRow(
                    children: columns
                        .map((key) => pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                _formatCellValue(key, row[key],
                                    dateProvider.formatCurrentDate),
                                style: const pw.TextStyle(fontSize: 8),
                              ),
                            ))
                        .toList(),
                  );
                }),
              ],
            ),
          ],
        ),
      );
      if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'custom-report.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'custom-report',
        format: PdfPageFormat.a4.landscape,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error generating PDF',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  Future<void> _generateExcel() async {
    if (_selectedReport == null || _reportData.isEmpty) return;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    try {
      final columns = _selectedReport!.selectedColumns;
      final workbook = syncXlsx.Workbook();
      final sheet = workbook.worksheets[0];
      for (int c = 0; c < columns.length; c++) {
        sheet
            .getRangeByIndex(1, c + 1)
            .setText(customReportColumnLabels[columns[c]] ?? columns[c]);
      }
      final headerStyle = workbook.styles.add('headerStyle');
      headerStyle.backColor = '#152B51';
      headerStyle.fontColor = '#FFFFFF';
      headerStyle.bold = true;
      sheet.getRangeByIndex(1, 1, 1, columns.length).cellStyle = headerStyle;
      int rowIndex = 2;
      for (final row in _reportData) {
        for (int c = 0; c < columns.length; c++) {
          final val = _formatCellValue(
              columns[c], row[columns[c]], dateProvider.formatCurrentDate);
          final numVal = num.tryParse(val.replaceAll(RegExp(r'[\$,%]'), ''));
          if (numVal != null) {
            sheet.getRangeByIndex(rowIndex, c + 1).setNumber(numVal.toDouble());
          } else {
            sheet.getRangeByIndex(rowIndex, c + 1).setText(val);
          }
        }
        rowIndex++;
      }
      for (int c = 1; c <= columns.length; c++) {
        sheet.autoFitColumn(c);
      }
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      final fileName =
          'CustomReport_${_selectedReport!.name.replaceAll(RegExp(r'[^\w]'), '_')}_${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.xlsx';
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      if (!await directory.exists() && !Platform.isIOS) {
        await directory.create(recursive: true);
      }
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles([XFile(path)]);
      Fluttertoast.showToast(
        msg: 'Excel file saved',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error generating Excel',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  Future<void> _generateCsv() async {
    if (_selectedReport == null || _reportData.isEmpty) return;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    try {
      final columns = _selectedReport!.selectedColumns;
      final headers = columns
          .map((k) =>
              '"${(customReportColumnLabels[k] ?? k).replaceAll('"', '""')}"')
          .toList();
      final buffer = StringBuffer();
      buffer.writeln(headers.join(','));
      for (final row in _reportData) {
        final values = columns
            .map((k) =>
                '"${_formatCellValue(k, row[k], dateProvider.formatCurrentDate).replaceAll('"', '""')}"')
            .toList();
        buffer.writeln(values.join(','));
      }
      final fileName =
          'CustomReport_${_selectedReport!.name.replaceAll(RegExp(r'[^\w]'), '_')}_${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}.csv';
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$fileName';
      if (!await directory.exists() && !Platform.isIOS) {
        await directory.create(recursive: true);
      }
      final file = File(path);
      await file.writeAsString(buffer.toString(), flush: true);
      await Share.shareXFiles([XFile(path)]);
      Fluttertoast.showToast(
        msg: 'CSV file saved',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error generating CSV',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }
}
