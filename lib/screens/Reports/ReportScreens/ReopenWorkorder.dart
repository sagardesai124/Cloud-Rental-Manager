import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/ReopenWorkOrderModel.dart';
import 'package:three_zero_two_property/repository/ReopenWorkOrderRepo.dart';
import 'package:three_zero_two_property/StaffModule/repository/ReopenWorkOrderRepo.dart'
    as staff_repo;
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as staff_appbar;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    as staff_drawer;
import 'package:three_zero_two_property/StaffModule/widgets/staff_report_header.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

/// The Reopen Work Orders CSV, the same as web's (ReopenWorkOrderReport.jsx
/// generateCSV): web's 9 columns, "N/A" for an empty value, the property as
/// "address - unit", and [formatDate] (the account date format) for dates.
String buildReopenWorkOrdersCsv(List<ReopenWorkOrderData> orders,
    String Function(String date) formatDate) {
  String orNa(String? value) =>
      (value == null || value.isEmpty) ? 'N/A' : value;
  String dateOrNa(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    final formatted = formatDate(value);
    return formatted.isEmpty ? 'N/A' : formatted;
  }

  final csv = StringBuffer();
  csv.writeln(csvRow(const [
    '#',
    'Subject',
    'Category',
    'Priority',
    'Property',
    'Assigned To',
    'Due Date',
    'Reopen Date',
    'Created Date',
  ]));
  for (final order in orders) {
    csv.writeln(csvRow([
      orNa(order.ticketNumber),
      orNa(order.workSubject),
      orNa(order.workCategory),
      orNa(order.priority),
      formatLeasePropertyLine(order.rentalAddress, order.rentalUnit),
      orNa(order.staffmemberName),
      dateOrNa(order.date),
      dateOrNa(order.reopenDate),
      dateOrNa(order.createdAt),
    ]));
  }
  return csv.toString();
}

class ReopenWorkorder extends StatefulWidget {
  /// When true, uses staff repository (staff_id, content type) and staff UI (app bar, drawer, header).
  final bool isStaffMode;

  const ReopenWorkorder({super.key, this.isStaffMode = false});

  @override
  State<ReopenWorkorder> createState() => _ReopenWorkorderState();
}

class _ReopenWorkorderState extends State<ReopenWorkorder>
    with NetworkRetryState {
  List<ReopenWorkOrderData> reopenWorkOrders = [];
  bool isLoading = true;
  String? errorMessage;
  int? expandedRowIndex;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
  String? selectedPriority;
  String? selectedCategory;
  String? selectedStatus;
  String? selectedStaffMember;
  List<String> priorityList = ['All', 'High', 'Normal', 'Low'];
  List<String> categoryList = [
    'All',
    'Roof',
    'Electrical',
    'Plumbing',
    'HVAC',
    'General'
  ];
  List<String> statusList = [
    'All',
    'On Hold',
    'In Progress',
    'Completed',
    'Cancelled'
  ];
  List<String> staffMemberList = ['All'];
  String? selectedRentalAddress;
  List<String> rentalAddressList = ['All'];
  String searchvalue = "";
  int currentPage = 1;
  int itemsPerPage = 10;
  int totalPages = 1;
  String? selectedAdminId;
  bool isDataLoading = false;

  /// Required by [NetworkRetryState]: re-issue this screen's own load,
  /// called by the Retry button and when the connection comes back.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    fetchReport();
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
    fetchReport();
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

  void fetchReport() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString("adminId");
      if (!widget.isStaffMode && adminId == null) {
        setState(() {
          errorMessage = "Admin ID not found";
          isLoading = false;
        });
        return;
      }

      selectedAdminId = adminId;
      ReopenWorkOrderResponse response;
      if (widget.isStaffMode) {
        response = await staff_repo.ReopenWorkOrderStaffRepository()
            .fetchReopenWorkOrders();
      } else {
        response =
            await ReopenWorkOrderRepository().fetchReopenWorkOrders(adminId!);
      }

      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          reopenWorkOrders = response.data!;
          isLoading = false;

          // Populate filter lists
          staffMemberList = ['All'];
          rentalAddressList = ['All'];

          for (var order in reopenWorkOrders) {
            if (order.staffmemberName != null &&
                !staffMemberList.contains(order.staffmemberName)) {
              staffMemberList.add(order.staffmemberName!);
            }
            if (order.rentalAddress != null &&
                !rentalAddressList.contains(order.rentalAddress)) {
              rentalAddressList.add(order.rentalAddress!);
            }
          }

          totalPages = (reopenWorkOrders.isEmpty ? 1 : (reopenWorkOrders.length / itemsPerPage).ceil());
        });
      } else {
        setState(() {
          errorMessage = response.message ?? "Failed to fetch data";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  List<ReopenWorkOrderData> get filteredData {
    List<ReopenWorkOrderData> filtered = reopenWorkOrders;

    // Search filter
    if (searchvalue.isNotEmpty) {
      String searchTerm = searchvalue.toLowerCase();
      filtered = filtered
          .where((order) =>
              order.ticketNumber?.toLowerCase().contains(searchTerm) == true ||
              order.workSubject?.toLowerCase().contains(searchTerm) == true ||
              order.rentalAddress?.toLowerCase().contains(searchTerm) == true ||
              order.staffmemberName?.toLowerCase().contains(searchTerm) == true ||
              // Web parity (ReopenWorkOrderReport.jsx filterWorkOrdersBySearch):
              // category, priority, unit and the raw date strings match too.
              order.workCategory?.toLowerCase().contains(searchTerm) == true ||
              order.priority?.toLowerCase().contains(searchTerm) == true ||
              order.rentalUnit?.toLowerCase().contains(searchTerm) == true ||
              order.date?.toLowerCase().contains(searchTerm) == true ||
              order.reopenDate?.toLowerCase().contains(searchTerm) == true ||
              order.createdAt?.toLowerCase().contains(searchTerm) == true)
          .toList();
    }

    // Priority filter
    if (selectedPriority != null && selectedPriority != 'All') {
      filtered = filtered
          .where((order) => order.priority == selectedPriority)
          .toList();
    }

    // Category filter
    if (selectedCategory != null && selectedCategory != 'All') {
      filtered = filtered
          .where((order) => order.workCategory == selectedCategory)
          .toList();
    }

    // Status filter
    if (selectedStatus != null && selectedStatus != 'All') {
      filtered =
          filtered.where((order) => order.status == selectedStatus).toList();
    }

    // Staff member filter
    if (selectedStaffMember != null && selectedStaffMember != 'All') {
      filtered = filtered
          .where((order) => order.staffmemberName == selectedStaffMember)
          .toList();
    }

    // Rental address filter
    if (selectedRentalAddress != null && selectedRentalAddress != 'All') {
      filtered = filtered
          .where((order) => order.rentalAddress == selectedRentalAddress)
          .toList();
    }

    return filtered;
  }

  List<ReopenWorkOrderData> get currentPageData {
    List<ReopenWorkOrderData> filtered = filteredData;
    int startIndex = (currentPage - 1) * itemsPerPage;
    int endIndex = (startIndex + itemsPerPage).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  Widget _buildHeaders() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFF7F9FC),
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              ' Property',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: blueColor,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '#',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: blueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateWithProvider(DateProvider dateProvider, String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    final formatted = dateProvider.formatCurrentDate(dateStr);
    return formatted.isEmpty ? 'N/A' : formatted;
  }

  Widget _buildDataRow(ReopenWorkOrderData order, int index) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    bool isExpanded = expandedRowIndex == index;
    final rowColor = index % 2 == 0 ? const Color(0xFFF4F8FF) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expandedRowIndex == index) {
                  expandedRowIndex = null;
                } else {
                  expandedRowIndex = index;
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const SizedBox(width: 5),
                  Expanded(
                    flex: 4,
                    child: Text(
                      order.rentalAddress ?? 'N/A',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: Text(
                      order.ticketNumber ?? 'N/A',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (expandedRowIndex == index) {
                          expandedRowIndex = null;
                        } else {
                          expandedRowIndex = index;
                        }
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      child: Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: blueColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Column(
              children: [
                const Divider(thickness: 2),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                                'Subject', order.workSubject ?? 'N/A'),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                                'Category', order.workCategory ?? 'N/A'),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                                'Priority', order.priority ?? 'N/A'),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                                'Assigned To', order.staffmemberName ?? 'N/A'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 35),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                  'Due Date',
                                  _formatDateWithProvider(
                                      dateProvider, order.date)),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                  'Reopen Date',
                                  _formatDateWithProvider(
                                      dateProvider, order.reopenDate)),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                  'Created Date',
                                  _formatDateWithProvider(
                                      dateProvider, order.createdAt)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + ' :',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: blueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  /// The filter bar for the no-rows states, padded like the table view.
  /// The standard empty state used across reports.
  Widget _noDataView() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          Image.asset(
            "assets/images/no_data_transparent.png",
            height: 200,
            width: 200,
          ),
          const SizedBox(height: 10),
          Text(
            "No Data Available",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
                fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _emptyFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5),
      child: Column(
        children: [
          const SizedBox(height: 5),
          filters(data: const []),
        ],
      ),
    );
  }

  static const double _filterRadius = 14.0;
  static const Color _filterBorderColor = Color(0xFFCED4DA);
  static const Color _filterHintColor = Color(0xFF8A95A8);

  /// Search box and Export. Also shown when the report has no rows, so
  /// Export keeps its place, greyed and not tappable.
  Widget filters({List<ReopenWorkOrderData>? data}) {
    final bool hasRows = data != null && data.isNotEmpty;
    final Color exportIconColor =
        hasRows ? _filterHintColor : Colors.grey.shade400;
    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Search Bar - rounded, light border, white (like image)
              Expanded(
                child: Container(
                  height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_filterRadius),
                    border: Border.all(color: _filterBorderColor, width: 1),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        searchvalue = value;
                        currentPage = 1;
                      });
                    },
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 500 ? 13 : 14,
                      color: Colors.grey[800],
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "Search here ...",
                      hintStyle: const TextStyle(color: _filterHintColor),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      suffixIcon: const Icon(
                        Icons.search,
                        color: _filterHintColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Export Button - rounded, light border, download + chevron
              Container(
                height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(_filterRadius),
                  border: Border.all(color: _filterBorderColor, width: 1),
                ),
                child: PopupMenuButton<String>(
                  enabled: hasRows,
                  onSelected: (value) async {
                    if (value == 'PDF' && data != null) {
                      _exportToPDF(context);
                    } else if (value == 'XLSX' && data != null) {
                      _exportToExcel(context);
                    } else if (value == 'CSV' && data != null) {
                      _exportToCsv(context);
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                        value: 'PDF', child: Text('PDF')),
                    const PopupMenuItem<String>(
                        value: 'XLSX', child: Text('XLSX')),
                    const PopupMenuItem<String>(
                        value: 'CSV', child: Text('CSV')),
                  ],
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined,
                            color: exportIconColor, size: 22),
                        const SizedBox(width: 8),
                        Icon(Icons.keyboard_arrow_down,
                            color: exportIconColor, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    int totalFilteredItems = filteredData.length;
    int totalPages = (totalFilteredItems == 0 ? 1 : (totalFilteredItems / itemsPerPage).ceil());

    if (totalPages <= 1) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              'Showing ${((currentPage - 1) * itemsPerPage) + 1} to ${(currentPage * itemsPerPage).clamp(0, totalFilteredItems)} of $totalFilteredItems items'),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1
                    ? () {
                        setState(() {
                          currentPage--;
                        });
                      }
                    : null,
                icon: FaIcon(
                  FontAwesomeIcons.circleChevronLeft,
                  size: 30,
                  color: currentPage > 1 ? blueColor : Colors.grey,
                ),
              ),
              Text('Page $currentPage of $totalPages',
                  style: TextStyle(fontSize: 18)),
              IconButton(
                onPressed: currentPage < totalPages
                    ? () {
                        setState(() {
                          currentPage++;
                        });
                      }
                    : null,
                icon: FaIcon(
                  FontAwesomeIcons.circleChevronRight,
                  size: 30,
                  color: currentPage < totalPages ? blueColor : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportToPDF(BuildContext context) async {
    try {
      setState(() {
        isDataLoading = true;
      });

      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      String fmt(String? d) {
        if (d == null || d.isEmpty) return 'N/A';
        final f = dateProvider.formatCurrentDate(d);
        return f.isEmpty ? 'N/A' : f;
      }

      final pdf = pw.Document();

      // Add logo
      final image = await rootBundle.load('assets/images/newlogo.png');
      final imageBytes = image.buffer.asUint8List();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          header: (pw.Context context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(pw.MemoryImage(imageBytes), width: 50, height: 50),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Reopen Work Order Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Generated on: ${dateProvider.formatCurrentDate(DateFormat('yyyy-MM-dd').format(DateTime.now()))}',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('keybrainstech', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('gg', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 20),
              pw.Table(
                border: null,
                columnWidths: {
                  0: pw.FlexColumnWidth(1.2), // #
                  1: pw.FlexColumnWidth(1.5), // Subject
                  2: pw.FlexColumnWidth(1.0), // Category
                  3: pw.FlexColumnWidth(1.0), // Priority
                  4: pw.FlexColumnWidth(2.0), // Property
                  5: pw.FlexColumnWidth(1.5), // Assigned To
                  6: pw.FlexColumnWidth(1.2), // Due Date
                  7: pw.FlexColumnWidth(1.2), // Reopen Date
                  8: pw.FlexColumnWidth(1.2), // Created Date
                },
                children: [
                  // Header row with blue background
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex("#5A86D5")),
                    children: [
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('#',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Subject',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Category',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Priority',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Property',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Assigned To',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Due Date',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Reopen Date',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Created Date',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                    ],
                  ),
                  // Data rows - dates via DateProvider
                  ...filteredData.map((order) => pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(order.ticketNumber ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(order.workSubject ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(order.workCategory ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(order.priority ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(order.rentalAddress ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(order.staffmemberName ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(fmt(order.date),
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(fmt(order.reopenDate),
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(fmt(order.createdAt),
                                  style: pw.TextStyle(fontSize: 10))),
                        ],
                      )),
                ],
              ),
            ];
          },
        ),
      );

      if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Reopen_Work_Order_Report.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'Reopen_Work_Order_Report',
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }

      setState(() {
        isDataLoading = false;
      });

      // Fluttertoast.showToast(msg: 'PDF exported successfully');
    } catch (e) {
      setState(() {
        isDataLoading = false;
      });
      // Fluttertoast.showToast(msg: 'Error exporting PDF: $e');
      logError('Error exporting PDF: $e');
    }
  }

  void _exportToExcel(BuildContext context) async {
    try {
      setState(() {
        isDataLoading = true;
      });

      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      String fmt(String? d) {
        if (d == null || d.isEmpty) return '';
        final f = dateProvider.formatCurrentDate(d);
        return f;
      }

      final workbook = syncXlsx.Workbook();
      final worksheet = workbook.worksheets[0];
      worksheet.name = 'Reopen Work Orders';

      // Add headers
      List<String> headers = [
        'Ticket #',
        'Subject',
        'Category',
        'Priority',
        'Status',
        'Address',
        'Staff',
        'Due Date',
        'Reopen Date',
        'Created Date',
        'Work Performed',
        'Vendor Notes'
      ];
      for (int i = 0; i < headers.length; i++) {
        worksheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        worksheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
      }

      // Add data - dates via DateProvider
      for (int i = 0; i < filteredData.length; i++) {
        var order = filteredData[i];
        worksheet.getRangeByIndex(i + 2, 1).setText(order.ticketNumber ?? '');
        worksheet.getRangeByIndex(i + 2, 2).setText(order.workSubject ?? '');
        worksheet.getRangeByIndex(i + 2, 3).setText(order.workCategory ?? '');
        worksheet.getRangeByIndex(i + 2, 4).setText(order.priority ?? '');
        worksheet.getRangeByIndex(i + 2, 5).setText(order.status ?? '');
        worksheet.getRangeByIndex(i + 2, 6).setText(order.rentalAddress ?? '');
        worksheet
            .getRangeByIndex(i + 2, 7)
            .setText(order.staffmemberName ?? '');
        worksheet.getRangeByIndex(i + 2, 8).setText(fmt(order.date));
        worksheet.getRangeByIndex(i + 2, 9).setText(fmt(order.reopenDate));
        worksheet.getRangeByIndex(i + 2, 10).setText(fmt(order.createdAt));
        worksheet.getRangeByIndex(i + 2, 11).setText(order.workPerformed ?? '');
        worksheet.getRangeByIndex(i + 2, 12).setText(order.vendorNotes ?? '');
      }

      // Auto-fit columns
      for (int i = 1; i <= headers.length; i++) {
        worksheet.autoFitColumn(i);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/reopen_work_orders_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);

      setState(() {
        isDataLoading = false;
      });

      Fluttertoast.showToast(msg: 'Excel file exported to: ${file.path}');
    } catch (e) {
      setState(() {
        isDataLoading = false;
      });
      Fluttertoast.showToast(msg: 'Error exporting Excel: ${friendlyErrorMessage(e)}');
    }
  }

  // Like web's CSV (ReopenWorkOrderReport.jsx generateCSV): the rows on
  // screen, web's columns and file name.
  void _exportToCsv(BuildContext context) async {
    try {
      setState(() {
        isDataLoading = true;
      });

      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      final csv = buildReopenWorkOrdersCsv(
          filteredData, (d) => dateProvider.formatCurrentDate(d));

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/Reopen_Work_Order_Report.csv');
      await file.writeAsString(csv, flush: true);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Reopen Work Orders Report');

      setState(() {
        isDataLoading = false;
      });
    } catch (e) {
      setState(() {
        isDataLoading = false;
      });
      Fluttertoast.showToast(msg: 'Error sharing report: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isStaffMode
          ? staff_appbar.widget_302_Staff.App_Bar(context: context)
          : widget_302.App_Bar(context: context),
      drawer: widget.isStaffMode
          ? staff_drawer.CustomDrawerStaff(
              currentpage: "Report",
              dropdown: false,
            )
          : CustomDrawer(
              currentpage: "Report",
              dropdown: false,
            ),
      body: !isOffline
          ? Column(
              children: [
                widget.isStaffMode
                    ? const StaffReportHeader(
                        title: 'Work Orders Scheduled to Reopen Report')
                    : const ReportHeader(title: 'Work Orders Scheduled to Reopen Report'),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (isLoading)
                          Center(
                            child: Column(
                              children: [
                                SizedBox(height: 100),
                                SpinKitFadingCircle(color:blueColor,size: 50.0,),
                              
                            ],
                            ),
                          )
                        // Nothing on hold comes back as a non-200 reply,
                        // so both branches show the standard empty state.
                        else if (errorMessage != null) ...[
                          _emptyFilters(),
                          _noDataView(),
                        ] else if (reopenWorkOrders.isEmpty) ...[
                          _emptyFilters(),
                          _noDataView(),
                        ] else
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 5),
                            child: Column(
                              children: [
                                SizedBox(height: 5),
                                filters(data: filteredData),
                                const SizedBox(height: 10),
                                _buildHeaders(),
                                const SizedBox(height: 10),
                                Column(
                                  children: currentPageData.isEmpty
                                      ? [kNoSearchResults(context)]
                                      : currentPageData
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    int rowIndex = entry.key;
                                    var order = entry.value;
                                    return _buildDataRow(order, rowIndex);
                                  }).toList(),
                                ),
                                _buildPagination(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
