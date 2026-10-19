import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:three_zero_two_property/Model/OpenWorkOrderReportModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/OpenWorkOrderReportService.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';

import 'dart:io';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class OpenWorkOrders extends StatefulWidget {
  @override
  State<OpenWorkOrders> createState() => _OpenWorkOrdersState();
}

class _OpenWorkOrdersState extends State<OpenWorkOrders>
    with NetworkRetryState {
  Future<List<WorkOrderReportData>>? _futureReport;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  /// Required by [NetworkRetryState]: re-issue this report's own load.
  /// Lifted from the hand-written Retry this replaces, so it fetches
  /// exactly what that button already fetched.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    _fetchOpenWorkOrders();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });

    // Set today's date in the fields and fetch today's data
    _setTodayDateAndFetch();
    checkInternet();
  }

  void _setTodayDateAndFetch() {
    // Set today's date in the fields
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    String todayDisplayFormat = dateProvider
        .formatCurrentDate(DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _fromDateController.text = todayDisplayFormat;
    _toDateController.text = todayDisplayFormat;

    // Set default date range to "Today"
    daterange = "Today";
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that can
    // stay `none` after the connection is back (reliably so on the iOS
    // simulator), which made every freshly-opened report declare itself
    // offline. Confirm with a real lookup before believing `none`.
    if (connectiondata == ConnectivityResult.none && await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  void _fetchOpenWorkOrders(
      {String? fromDate, String? toDate, String? status}) {
    setState(() {
      // Re-running with new filters can return fewer pages than the page the
      // user was already on, which left the view skipped past all the new
      // rows and showing "No results found" even though data came back.
      currentPage = 0;
      _futureReport = OpenWorkOrderService().fetchOpenWorkOrders(
        fromDate: fromDate,
        toDate: toDate,
        status: status,
      );
    });
  }

  void _runReport() {
    // Get status parameter
    String? statusParam = statusType == 'All Statuses' ? null : statusType;

    // Get date parameters and convert to API format (yyyy-MM-dd)
    String? fromDateParam;
    String? toDateParam;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    if (_fromDateController.text.isNotEmpty) {
      // Convert display date to API format (yyyy-MM-dd)
      fromDateParam =
          convertDisplayDateToApiFormat(_fromDateController.text, dateProvider);
    }

    if (_toDateController.text.isNotEmpty) {
      // Convert display date to API format (yyyy-MM-dd)
      toDateParam =
          convertDisplayDateToApiFormat(_toDateController.text, dateProvider);
    }

    // Print API parameters for debugging

    // Fetch data with filters
    _fetchOpenWorkOrders(
      fromDate: fromDateParam,
      toDate: toDateParam,
      status: statusParam,
    );
  }

  // Date picker methods
  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor,
            colorScheme: ColorScheme.light(
              primary: blueColor,
            ),
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        _fromDateController.text =
            dateProvider.formatCurrentDate(apiFormatDate);
      });
    }
  }

  Future<void> _endDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor,
            colorScheme: ColorScheme.light(
              primary: blueColor,
            ),
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        _toDateController.text = dateProvider.formatCurrentDate(apiFormatDate);
      });
    }
  }

  Widget _buildDataCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16, bottom: 20.0),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  int totalrecords = 0;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [
    10,
    25,
    50,
    100,
  ];

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0; // Reset to the first page when changing rows per page
    });
  }

  List<WorkOrderReportData> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String searchvalue = "";
  String? selectedValue;

  // Filter variables
  String? statusType;
  String? daterange;
  bool customdate = false;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  /// Web's From/To check (null when the range is fine).
  String? get _dateRangeError =>
      reportDateRangeError(_fromDateController.text, _toDateController.text);
  DateTime? _selectedDate;

  List<WorkOrderReportData> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  Widget _buildPaginationControls() {
    int numorpages = (_tableData.length / _rowsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          elevation: 2,
          color: Colors.white,
          child: Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                items: [10, 25, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    _changeRowsPerPage(newValue);
                  }
                },
                icon: const Icon(
                  Icons.arrow_drop_down,
                  size: 40,
                ),
                style: const TextStyle(color: Colors.black, fontSize: 17),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.circleChevronLeft,
            size: 30,
            color: _currentPage == 0 ? Colors.grey : blueColor,
          ),
          onPressed: _currentPage == 0
              ? null
              : () {
                  setState(() {
                    _currentPage--;
                  });
                },
        ),
        Text(
          'Page ${_currentPage + 1} of $numorpages',
          style: const TextStyle(fontSize: 18),
        ),
        IconButton(
          icon: FaIcon(
            size: 30,
            FontAwesomeIcons.circleChevronRight,
            color: (_currentPage + 1) * _rowsPerPage >= _tableData.length
                ? Colors.grey
                : blueColor, // Change color based on availability
          ),
          onPressed: (_currentPage + 1) * _rowsPerPage >= _tableData.length
              ? null
              : () {
                  setState(() {
                    _currentPage++;
                  });
                },
        ),
      ],
    );
  }

  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;
  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.only(
          left: MediaQuery.of(context).size.width > 500 ? 10 : 0,
          right: MediaQuery.of(context).size.width > 500 ? 10 : 0),
      child: Container(
        // decoration: BoxDecoration(
        //   color: blueColor,
        //   borderRadius: BorderRadius.only(
        //     topLeft: Radius.circular(13),
        //     topRight: Radius.circular(13),
        //   ),
        // ),
        decoration: BoxDecoration(
            color: const Color(0xFFF4F8FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDBE0E5))),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          // leading: Container(
          //   child: Icon(
          //     Icons.expand_less,
          //     color: Colors.transparent,
          //   ),
          // ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Container(
                child: Icon(
                  Icons.expand_less,
                  color: Colors.transparent,
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (sorting1 == true) {
                        sorting2 = false;
                        sorting3 = false;
                        ascending1 = !ascending1;
                        ascending2 = false;
                        ascending3 = false;
                      } else {
                        sorting1 = true;
                        sorting2 = false;
                        sorting3 = false;
                        ascending1 = true;
                        ascending2 = false;
                        ascending3 = false;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      width < 400
                          ? Text("Date",
                              style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15))
                          : Text("Date",
                              style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                      // Text("Property", style: TextStyle(color: Colors.white)),
                      SizedBox(width: 3),
                      ascending1
                          ? Padding(
                              padding: const EdgeInsets.only(top: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortUp,
                                size: 20,
                                color: blueColor,
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortDown,
                                size: 20,
                                color: blueColor,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (sorting2) {
                        sorting1 = false;
                        sorting2 = true;
                        sorting3 = false;
                        ascending2 = !ascending2;
                        ascending1 = false;
                        ascending3 = false;
                      } else {
                        sorting1 = false;
                        sorting2 = true;
                        sorting3 = false;
                        ascending2 = true;
                        ascending1 = false;
                        ascending3 = false;
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Text("Address",
                          style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(width: 5),
                      ascending2
                          ? Padding(
                              padding: const EdgeInsets.only(top: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortUp,
                                size: 20,
                                color: blueColor,
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortDown,
                                size: 20,
                                color: blueColor,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Text("Ticket",
                    style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(WorkOrderReportData d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField, columnIndex, !_sortAscending);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Text(text,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              if (_sortColumnIndex == columnIndex)
                Icon(_sortAscending
                    ? Icons.arrow_drop_down_outlined
                    : Icons.arrow_drop_up_outlined),
            ],
          ),
        ),
      ),
    );
  }

  void _sort<T>(Comparable<T> Function(WorkOrderReportData d) getField,
      int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _tableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        final result = aValue.compareTo(bValue as T);
        return _sortAscending ? result : -result;
      });
    });
  }

  void sortData(List<WorkOrderReportData> data) {
    if (sorting1) {
      // Date column = the work order's Due Date (same as Completed report).
      data.sort((a, b) {
        DateTime? dateA = (a.date ?? '').isNotEmpty ? DateTime.tryParse(a.date!) : null;
        DateTime? dateB = (b.date ?? '').isNotEmpty ? DateTime.tryParse(b.date!) : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return ascending1 ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      });
    } else if (sorting2) {
      data.sort((a, b) {
        String aValue = a.rentalAddress ?? '';
        String bValue = b.rentalAddress ?? '';
        return ascending2 ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      });
    } else if (sorting3) {
      data.sort((a, b) {
        String aValue = a.workSubject ?? '';
        String bValue = b.workSubject ?? '';
        return ascending3 ? aValue.compareTo(bValue) : bValue.compareTo(aValue);
      });
    }
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('dd-MM-yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateStr; // If the date is not valid, return the original string
    }
  }

  // Convert display date back to API format (yyyy-MM-dd)
  String convertDisplayDateToApiFormat(
      String displayDate, DateProvider dateProvider) {
    if (displayDate.isEmpty) return displayDate;

    try {
      // Get the current date format from DateProvider
      String currentDateFormat = dateProvider.dateFormat;

      // List of possible date formats to try
      List<String> formatsToTry = [
        currentDateFormat, // Try the user's preferred format first
        'MM/dd/yyyy',
        'M/d/yyyy',
        'dd-MM-yyyy',
        'd-M-yyyy',
        'yyyy-MM-dd',
        'yyyy-M-d',
      ];

      DateTime? parsedDate;

      // Try parsing with each format
      for (String format in formatsToTry) {
        try {
          parsedDate = DateFormat(format).parse(displayDate);
          break; // Successfully parsed
        } catch (e) {
          continue; // Try next format
        }
      }

      // If parsing succeeded, format as yyyy-MM-dd
      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }

      // If all parsing attempts failed, return original (shouldn't happen)
      return displayDate;
    } catch (e) {
      logError('Error converting display date to API format: $e');
      return displayDate;
    }
  }

  Future<void> generateWorkOrderPdf(
      List<WorkOrderReportData> workOrderData) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      // Handle error
      logError("Error fetching profile data: $e");
      return;
    }
    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );
    final currentDate =
        dateProvider.formatCurrentDate(DateTime.now().toString());

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Image(image, width: 50, height: 50),
            pw.SizedBox(width: 50),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Open Work Orders',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('As of $currentDate'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Company/contact block: omit empty fields (web parity) —
                // never render "N/A". See buildPdfCompanyLines.
                ...buildPdfCompanyLines(
                  companyName: profileData?.companyName,
                  companyAddress: profileData?.companyAddress,
                  companyCity: profileData?.companyCity,
                  companyState: profileData?.companyState,
                  companyCountry: profileData?.companyCountry,
                  companyPostalCode: profileData?.companyPostalCode,
                ).map(
                  (line) => pw.Text(
                    line,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
        build: (pw.Context context) => [
          pw.Table.fromTextArray(
            headers: [
              'Date',
              'Address',
              'Ticket',
              'Work',
              'Performed',
            ],
            data: workOrderData.map((workOrder) {
              return [
                workOrder.date != null && workOrder.date!.isNotEmpty
                    ? dateProvider.formatCurrentDate(workOrder.date!)
                    : '-',
                (workOrder.rentalAddress == null ||
                        workOrder.rentalAddress!.isEmpty)
                    ? '-'
                    : workOrder.rentalAddress!,
                (workOrder.ticketNumber == null ||
                        workOrder.ticketNumber!.isEmpty)
                    ? '-'
                    : workOrder.ticketNumber!,
                (workOrder.workSubject == null ||
                        workOrder.workSubject!.isEmpty)
                    ? '-'
                    : workOrder.workSubject!,
                (workOrder.workPerformed == null ||
                        workOrder.workPerformed!.isEmpty)
                    ? '-'
                    : workOrder.workPerformed!,
              ];
            }).toList(),
            border: pw.TableBorder.all(
              color: PdfColor.fromInt(0xFFBDBDBD),
              width: 1,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
            cellStyle: pw.TextStyle(
              fontSize: 10,
            ),
            cellHeight: 30,
            columnWidths: {
              0: pw.FlexColumnWidth(1.2), // Date
              1: pw.FlexColumnWidth(1.5), // Address
              2: pw.FlexColumnWidth(1.2), // Ticket
              3: pw.FlexColumnWidth(1.5), // Work
              4: pw.FlexColumnWidth(1.5), // Performed
            },
          ),
        ],
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Open-work-orders.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Open-work-orders',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> generateWorkOrderExcel(
      List<WorkOrderReportData> workOrderData) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    sheet.getRangeByName('A1:E1').columnWidth = 20;

    final List<String> headers = [
      'Date',
      'Address',
      'Ticket',
      'Work',
      'Performed',
    ];

    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#D3D3D3';
    headerCellStyle.hAlign = syncXlsx.HAlignType.center;

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    for (int i = 0; i < workOrderData.length; i++) {
      final workOrder = workOrderData[i];

      // Safe date parsing with default/fallback value
      String formattedDate;
      try {
        formattedDate = workOrder.date != null && workOrder.date!.isNotEmpty
            ? dateProvider.formatCurrentDate(workOrder.date!)
            : '-';
      } catch (e) {
        formattedDate = '-';
      }

      sheet.getRangeByIndex(2 + i, 1).setText(formattedDate);
      sheet.getRangeByIndex(2 + i, 2).setText(
          (workOrder.rentalAddress == null || workOrder.rentalAddress!.isEmpty)
              ? '-'
              : workOrder.rentalAddress!);
      sheet.getRangeByIndex(2 + i, 3).setText(
          (workOrder.ticketNumber == null || workOrder.ticketNumber!.isEmpty)
              ? '-'
              : workOrder.ticketNumber!);
      sheet.getRangeByIndex(2 + i, 4).setText(
          (workOrder.workSubject == null || workOrder.workSubject!.isEmpty)
              ? '-'
              : workOrder.workSubject!);
      sheet.getRangeByIndex(2 + i, 5).setText(
          (workOrder.workPerformed == null || workOrder.workPerformed!.isEmpty)
              ? '-'
              : workOrder.workPerformed!);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'OpenWorkOrderReport_$formattedDate.xlsx';

    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(path)]);
    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

  Future<void> generateWorkOrderCsv(
      List<WorkOrderReportData> workOrderData) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    List<List<dynamic>> rows = [
      ['Date', 'Address', 'Ticket', 'Work', 'Performed']
    ];

    for (var workOrder in workOrderData) {
      rows.add([
        workOrder.date != null && workOrder.date!.isNotEmpty
            ? dateProvider.formatCurrentDate(workOrder.date!)
            : '-',
        (workOrder.rentalAddress == null || workOrder.rentalAddress!.isEmpty)
            ? '-'
            : workOrder.rentalAddress!,
        (workOrder.ticketNumber == null || workOrder.ticketNumber!.isEmpty)
            ? '-'
            : workOrder.ticketNumber!,
        (workOrder.workSubject == null || workOrder.workSubject!.isEmpty)
            ? '-'
            : workOrder.workSubject!,
        (workOrder.workPerformed == null || workOrder.workPerformed!.isEmpty)
            ? '-'
            : workOrder.workPerformed!,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'OpenWorkOrderReport_$formattedDate.csv';

    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsString(csv);
    Share.shareXFiles([XFile(path)]);
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      drawer: CustomDrawer(
        currentpage: "Reports",
        dropdown: false,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  ReportHeader(
                    title: "Open Work Order",
                  ),
                  // Filter Section
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10.0,
                      right: 10.0,
                    ),
                    child: Column(
                      children: [
                        // Date Range Dropdown
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: Colors.grey)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: Text(
                                          daterange ?? "Date Range",
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: daterange == null
                                                ? const Color(0xFF8A95A8)
                                                : Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      items: [
                                        DropdownMenuItem<String>(
                                          value: 'Today',
                                          child: Text(
                                            'Today',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Yesterday',
                                          child: Text(
                                            'Yesterday',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last 7 Days',
                                          child: Text(
                                            'Last 7 Days',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last 14 Days',
                                          child: Text(
                                            'Last 14 Days',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last 30 Days',
                                          child: Text(
                                            'Last 30 Days',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'This Week',
                                          child: Text(
                                            'This Week',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last Week',
                                          child: Text(
                                            'Last Week',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'This Month',
                                          child: Text(
                                            'This Month',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last Month',
                                          child: Text(
                                            'Last Month',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'This Quarter',
                                          child: Text(
                                            'This Quarter',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last Quarter',
                                          child: Text(
                                            'Last Quarter',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Year to Date',
                                          child: Text(
                                            'Year to Date',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Last Year',
                                          child: Text(
                                            'Last Year',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'Custom',
                                          child: Text(
                                            'Custom Date',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      value: daterange,
                                      onChanged: (value) {
                                        final dateProvider =
                                            Provider.of<DateProvider>(context,
                                                listen: false);
                                        setState(() {
                                          daterange = value;
                                          DateTime now = DateTime.now();
                                          customdate = false;

                                          if (value == "Today") {
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime.now().toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime.now().toString());
                                          } else if (value == "Yesterday") {
                                            DateTime yesterday =
                                                now.subtract(Duration(days: 1));
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    yesterday.toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    yesterday.toString());
                                          } else if (value == "Last 7 Days") {
                                            // Last 7 Days including today: subtract 6 days (not 7)
                                            DateTime startDate =
                                                now.subtract(Duration(days: 6));
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    startDate.toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    now.toString());
                                          } else if (value == "Last 14 Days") {
                                            // Last 14 Days including today: subtract 13 days (not 14)
                                            DateTime startDate = now
                                                .subtract(Duration(days: 13));
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    startDate.toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    now.toString());
                                          } else if (value == "Last 30 Days") {
                                            // Last 30 Days including today: subtract 29 days (not 30)
                                            DateTime startDate = now
                                                .subtract(Duration(days: 29));
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    startDate.toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    now.toString());
                                          } else if (value == "This Week") {
                                            // Start of current week (Monday)
                                            DateTime startOfWeek = now.subtract(
                                                Duration(
                                                    days: now.weekday - 1));
                                            // End of current week (Sunday)
                                            DateTime endOfWeek = startOfWeek
                                                .add(Duration(days: 6));
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    startOfWeek.toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    endOfWeek.toString());
                                          } else if (value == "Last Week") {
                                            // Start of current week (Monday)
                                            DateTime startOfCurrentWeek =
                                                now.subtract(Duration(
                                                    days: now.weekday - 1));
                                            // Start of last week (Monday of last week) - subtract 7 days from current week start
                                            DateTime startOfLastWeek =
                                                startOfCurrentWeek.subtract(
                                                    Duration(days: 7));
                                            // End of last week (Sunday of last week)
                                            DateTime endOfLastWeek =
                                                startOfLastWeek
                                                    .add(Duration(days: 6));
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    startOfLastWeek.toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    endOfLastWeek.toString());
                                          } else if (value == "This Month") {
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(now.year,
                                                            now.month, 1)
                                                        .toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(now.year,
                                                            now.month + 1, 0)
                                                        .toString());
                                          } else if (value == "Last Month") {
                                            DateTime lastMonth = DateTime(
                                                now.year, now.month - 1, 1);
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(lastMonth.year,
                                                            lastMonth.month, 1)
                                                        .toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(
                                                            lastMonth.year,
                                                            lastMonth.month + 1,
                                                            0)
                                                        .toString());
                                          } else if (value == "This Quarter") {
                                            int currentQuarter =
                                                ((now.month - 1) ~/ 3) + 1;
                                            int quarterStartMonth =
                                                (currentQuarter - 1) * 3 + 1;
                                            int quarterEndMonth =
                                                currentQuarter * 3;
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(
                                                            now.year,
                                                            quarterStartMonth,
                                                            1)
                                                        .toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(
                                                            now.year,
                                                            quarterEndMonth + 1,
                                                            0)
                                                        .toString());
                                          } else if (value == "Last Quarter") {
                                            int currentQuarter =
                                                ((now.month - 1) ~/ 3) + 1;
                                            int lastQuarter =
                                                currentQuarter == 1
                                                    ? 4
                                                    : currentQuarter - 1;
                                            int lastQuarterYear =
                                                currentQuarter == 1
                                                    ? now.year - 1
                                                    : now.year;
                                            int quarterStartMonth =
                                                (lastQuarter - 1) * 3 + 1;
                                            int quarterEndMonth =
                                                lastQuarter * 3;
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(
                                                            lastQuarterYear,
                                                            quarterStartMonth,
                                                            1)
                                                        .toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(
                                                            lastQuarterYear,
                                                            quarterEndMonth + 1,
                                                            0)
                                                        .toString());
                                          } else if (value == "Year to Date") {
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(now.year, 1, 1)
                                                        .toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    now.toString());
                                          } else if (value == "Last Year") {
                                            _fromDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(now.year - 1, 1, 1)
                                                        .toString());
                                            _toDateController.text =
                                                dateProvider.formatCurrentDate(
                                                    DateTime(now.year - 1, 12,
                                                            31)
                                                        .toString());
                                          } else if (value == "Custom") {
                                            customdate = true;
                                          }

                                          if (value != "Custom" &&
                                              customdate == true) {
                                            customdate = false;
                                            _fromDateController.text = "";
                                            _toDateController.text = "";
                                          }
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 42,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          color: Colors.white,
                                        ),
                                        elevation: 0,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 250,
                                        width: 200,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        offset: const Offset(-20, 0),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(40),
                                          thickness:
                                              MaterialStateProperty.all(6),
                                          thumbVisibility:
                                              MaterialStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                          const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // From Date and To Date fields with theme
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                  child: Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: Color(0xFF8A95A8),
                                      colorScheme: ColorScheme.light(
                                        primary: Color(0xFF8A95A8),
                                      ),
                                      buttonTheme: ButtonThemeData(
                                        textTheme: ButtonTextTheme.primary,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: _fromDateController,
                                      onTap: customdate
                                          ? () {
                                              _pickDate(context);
                                            }
                                          : null,
                                      readOnly: true,
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      textInputAction: TextInputAction.next,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 11, horizontal: 11),
                                        isDense: true,
                                        hintText: "From",
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color: Colors.grey,
                                      width: 1,
                                    ),
                                  ),
                                  child: Theme(
                                    data: ThemeData.light().copyWith(
                                      primaryColor: blueColor,
                                      colorScheme: ColorScheme.light(
                                        primary: blueColor,
                                      ),
                                      buttonTheme: ButtonThemeData(
                                        textTheme: ButtonTextTheme.primary,
                                      ),
                                    ),
                                    child: TextFormField(
                                      controller: _toDateController,
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.black),
                                      onTap: customdate
                                          ? () {
                                              _endDate(context);
                                            }
                                          : null,
                                      readOnly: true,
                                      textInputAction: TextInputAction.next,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                vertical: 11, horizontal: 11),
                                        isDense: true,
                                        hintText: "To",
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_dateRangeError != null)
                          ReportDateRangeErrorText(_dateRangeError!),
                        const SizedBox(height: 10),
                        // Status and Run Report Button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: const Row(
                                        children: [
                                          SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Status',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.black,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: const [
                                        DropdownMenuItem<String>(
                                          value: 'All Statuses',
                                          child: Text('All Statuses'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'New',
                                          child: Text('New'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'In Progress',
                                          child: Text('In Progress'),
                                        ),
                                        DropdownMenuItem<String>(
                                          value: 'On Hold',
                                          child: Text('On Hold'),
                                        ),
                                      ],
                                      value: statusType,
                                      onChanged: (value) {
                                        setState(() {
                                          statusType = value;
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 45,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          color: Colors.white,
                                        ),
                                        elevation: 0,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 250,
                                        width: 200,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        offset: const Offset(-20, 0),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(40),
                                          thickness:
                                              MaterialStateProperty.all(6),
                                          thumbVisibility:
                                              MaterialStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                          const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: blueColor,
                                    disabledBackgroundColor: blueColor.withOpacity(0.6),
                                    disabledForegroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  onPressed: _dateRangeError != null ? null : () {
                                    _runReport();
                                  },
                                  child: const Text(
                                    'Run Report',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // if (MediaQuery.of(context).size.width < 500)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10.0,
                      right: 10.0,
                    ),
                    child: FutureBuilder<List<WorkOrderReportData>>(
                      future: _futureReport,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ColabShimmerLoadingWidget(),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                              child: friendlyErrorState(snapshot.error));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Container(
                            height: MediaQuery.of(context).size.height * .5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    "assets/images/no_data.jpg",
                                    height: 200,
                                    width: 200,
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    "No Data Available",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize: 16),
                                  )
                                ],
                              ),
                            ),
                          );
                        }

                        var data = snapshot.data!;

                        // Filter CUMULATIVELY: narrow by the selected value
                        // first (when one is chosen and it isn't "All"), then
                        // search what remains. These used to be exclusive
                        // else-if branches, so a search silently discarded the
                        // selection (and "All" discarded the search).
                        if (selectedValue != null && selectedValue != "All") {
                          data = data
                              .where((workOrder) =>
                                  workOrder.workSubject == selectedValue)
                              .toList();
                        }
                        if (searchvalue.isNotEmpty) {
                          data = data
                              .where((workOrder) =>
                                  (workOrder.workSubject ?? '')
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  (workOrder.rentalAddress ?? '')
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()))
                              .toList();
                        }

                        // Sort data if necessary
                        sortData(data);

                        // Pagination logic
                        final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                        final currentPageData = data
                            .skip(currentPage * itemsPerPage)
                            .take(itemsPerPage)
                            .toList();

                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              // SizedBox(
                              //   height: 8,
                              // ),
                              // Padding(
                              //   padding:  EdgeInsets.only(left: MediaQuery.of(context).size.width > 500? 10 : 0, right:MediaQuery.of(context).size.width > 500? 10 : 0),
                              //   child: Expanded(
                              //     flex: 0,
                              //     child: Padding(
                              //       padding: const EdgeInsets.only(
                              //         left: 5.0,
                              //         right: 5.0,
                              //       ),
                              //       child: Row(
                              //         mainAxisAlignment:
                              //             MainAxisAlignment.spaceBetween,
                              //         children: [
                              //           Material(
                              //             elevation: 3,
                              //             borderRadius:
                              //                 BorderRadius.circular(8),
                              //             child: Container(
                              //               padding: const EdgeInsets.symmetric(
                              //                   horizontal: 10),
                              //               // height: 40,
                              //               height: MediaQuery.of(context)
                              //                           .size
                              //                           .width <
                              //                       500
                              //                   ? 48
                              //                   : 50,
                              //               width: MediaQuery.of(context)
                              //                           .size
                              //                           .width <
                              //                       500
                              //                   ? MediaQuery.of(context)
                              //                           .size
                              //                           .width *
                              //                       .53
                              //                   : MediaQuery.of(context)
                              //                           .size
                              //                           .width *
                              //                       .4,
                              //               decoration: BoxDecoration(
                              //                 color: Colors.white,
                              //                 borderRadius:
                              //                     BorderRadius.circular(8),
                              //                 border: Border.all(
                              //                     color:
                              //                         const Color(0xFF8A95A8)),
                              //               ),
                              //               child: TextField(
                              //                 onChanged: (value) {
                              //                   setState(() {
                              //                     searchvalue = value;
                              //                   });
                              //                 },
                              //                 decoration: const InputDecoration(
                              //                   border: InputBorder.none,
                              //                   hintText: "Search here...",
                              //                   hintStyle: TextStyle(
                              //                       color: Color(0xFF8A95A8)),
                              //                   // contentPadding: EdgeInsets.all(10),
                              //                 ),
                              //               ),
                              //             ),
                              //           ),
                              //           ElevatedButton(
                              //             style: ElevatedButton.styleFrom(
                              //               backgroundColor: blueColor,
                              //             ),
                              //             onPressed: () {},
                              //             child: PopupMenuButton<String>(
                              //               onSelected: (value) async {
                              //                 // Add your export logic here based on the selected value
                              //                 if (value == 'PDF') {
                              //                   print('pdf');
                              //                   generateWorkOrderPdf(data);
                              //                   // Export as PDF
                              //                 } else if (value == 'XLSX') {
                              //                   print('XLSX');
                              //                   generateWorkOrderExcel(data);
                              //                   // Export as XLSX
                              //                 } else if (value == 'CSV') {
                              //                   print('CSV');
                              //                   generateWorkOrderCsv(data);
                              //                   // Export as CSV
                              //                 }
                              //               },
                              //               itemBuilder:
                              //                   (BuildContext context) =>
                              //                       <PopupMenuEntry<String>>[
                              //                 const PopupMenuItem<String>(
                              //                   value: 'PDF',
                              //                   child: Text('PDF'),
                              //                 ),
                              //                 const PopupMenuItem<String>(
                              //                   value: 'XLSX',
                              //                   child: Text('XLSX'),
                              //                 ),
                              //                 const PopupMenuItem<String>(
                              //                   value: 'CSV',
                              //                   child: Text('CSV'),
                              //                 ),
                              //               ],
                              //               child: Row(
                              //                 mainAxisSize: MainAxisSize.min,
                              //                 children: [
                              //                   Text('Export'),
                              //                   Icon(Icons.arrow_drop_down),
                              //                 ],
                              //               ),
                              //             ),
                              //           )
                              //         ],
                              //       ),
                              //     ),
                              //   ),
                              // ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.only(
                                  left: MediaQuery.of(context).size.width > 500
                                      ? 10
                                      : 0,
                                  right: MediaQuery.of(context).size.width > 500
                                      ? 10
                                      : 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // // Search box expands
                                    // Expanded(
                                    //   child: Padding(
                                    //     padding: const EdgeInsets.symmetric(
                                    //         horizontal: 5.0),
                                    //     child: Material(
                                    //       elevation: 3,
                                    //       borderRadius:
                                    //           BorderRadius.circular(8),
                                    //       child: Container(
                                    //         padding: const EdgeInsets.symmetric(
                                    //             horizontal: 10),
                                    //         height: MediaQuery.of(context)
                                    //                     .size
                                    //                     .width <
                                    //                 500
                                    //             ? 48
                                    //             : 50,
                                    //         decoration: BoxDecoration(
                                    //           color: Colors.white,
                                    //           borderRadius:
                                    //               BorderRadius.circular(8),
                                    //           border: Border.all(
                                    //               color:
                                    //                   const Color(0xFF8A95A8)),
                                    //         ),
                                    //         child: TextField(
                                    //           onChanged: (value) {
                                    //             setState(() {
                                    //               searchvalue = value;
                                    //             });
                                    //           },
                                    //           decoration: const InputDecoration(
                                    //             border: InputBorder.none,
                                    //             hintText: "Search here...",
                                    //             hintStyle: TextStyle(
                                    //                 color: Color(0xFF8A95A8)),
                                    //           ),
                                    //         ),
                                    //       ),
                                    //     ),
                                    //   ),
                                    // ),

                                    // Export button: half screen width, right-aligned under Run Report
                                    Expanded(
                                      child: Align(
                                      alignment: Alignment.centerRight,
                                      child: FractionallySizedBox(
                                        widthFactor: 0.5,
                                        child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5.0),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor,
                                          minimumSize:
                                              const Size(double.infinity, 44),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 12),
                                        ),
                                        onPressed: () {},
                                        child: PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'PDF') {
                                              generateWorkOrderPdf(data);
                                            } else if (value == 'XLSX') {
                                              generateWorkOrderExcel(data);
                                            } else if (value == 'CSV') {
                                              generateWorkOrderCsv(data);
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                              <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                                value: 'PDF',
                                                child: Text('PDF')),
                                            const PopupMenuItem<String>(
                                                value: 'XLSX',
                                                child: Text('XLSX')),
                                            const PopupMenuItem<String>(
                                                value: 'CSV',
                                                child: Text('CSV')),
                                          ],
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Export',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Icon(Icons.arrow_drop_down,
                                                  color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    ),
                                    ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 8),
                              _buildHeaders(),
                              SizedBox(height: 15),
                              Padding(
                                padding: EdgeInsets.only(
                                    left:
                                        MediaQuery.of(context).size.width > 500
                                            ? 10
                                            : 0,
                                    right:
                                        MediaQuery.of(context).size.width > 500
                                            ? 10
                                            : 0),
                                child: Container(
                                  // decoration: BoxDecoration(
                                  //     border: Border.all(
                                  //         color: Color.fromRGBO(
                                  //             152, 162, 179, .5))),
                                  // decoration: BoxDecoration(
                                  //     border: Border.all(color: blueColor)),
                                  child: Column(
                                    children: currentPageData.isEmpty
                                        ? [kNoSearchResults(context)]
                                        : currentPageData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int index = entry.key;
                                      bool isExpanded = expandedIndex == index;
                                      WorkOrderReportData workOrder =
                                          entry.value;

                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: index % 2 != 0
                                              ? const Color(0xFFF4F8FF)
                                              : Colors.white,
                                          border: Border.all(
                                              color: const Color(0xFFDBE0E5)),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        // decoration: BoxDecoration(
                                        //   border: Border.all(color: blueColor),
                                        // ),
                                        child: Column(
                                          children: <Widget>[
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Padding(
                                                padding:
                                                    const EdgeInsets.all(2.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: <Widget>[
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          if (expandedIndex ==
                                                              index) {
                                                            expandedIndex =
                                                                null;
                                                          } else {
                                                            expandedIndex =
                                                                index;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: EdgeInsets.only(
                                                            left: 5),
                                                        padding: !isExpanded
                                                            ? EdgeInsets.only(
                                                                bottom: 10)
                                                            : EdgeInsets.only(
                                                                top: 10),
                                                        child: FaIcon(
                                                          isExpanded
                                                              ? FontAwesomeIcons
                                                                  .sortUp
                                                              : FontAwesomeIcons
                                                                  .sortDown,
                                                          size: 20,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Text(
                                                        '   ${workOrder.date == null || workOrder.date!.isEmpty ? '-' : dateProvider.formatCurrentDate(workOrder.date!)} ',
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .04),
                                                    Expanded(
                                                      child: Text(
                                                        '${(workOrder.rentalAddress == null || workOrder.rentalAddress!.isEmpty) ? '-' : workOrder.rentalAddress}',
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .04),
                                                    Expanded(
                                                      child: Text(
                                                        '${(workOrder.ticketNumber == null || workOrder.ticketNumber!.isEmpty) ? '-' : workOrder.ticketNumber}',
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    // SizedBox(
                                                    //     width: MediaQuery.of(context)
                                                    //             .size
                                                    //             .width *
                                                    //         .08),
                                                    // Expanded(
                                                    //   child: Text(
                                                    //     // '${widget.data.createdAt}',
                                                    //     '${lease.status}',
                                                    //     style: TextStyle(
                                                    //       color: blueColor,
                                                    //       fontWeight: FontWeight.bold,
                                                    //       fontSize: 13,
                                                    //     ),
                                                    //   ),
                                                    // ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .02),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isExpanded)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8.0),
                                                margin:
                                                    EdgeInsets.only(bottom: 20),
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        children: [
                                                          FaIcon(
                                                            isExpanded
                                                                ? FontAwesomeIcons
                                                                    .sortUp
                                                                : FontAwesomeIcons
                                                                    .sortDown,
                                                            size: 50,
                                                            color: Colors
                                                                .transparent,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: <Widget>[
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            'Work :   ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${(workOrder.workSubject == null || workOrder.workSubject!.isEmpty) ? '-' : workOrder.workSubject}',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            'Description :   ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${(workOrder.workPerformed == null || workOrder.workPerformed!.isEmpty) ? '-' : workOrder.workPerformed}',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            'Note :   ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${(workOrder.vendorNotes == null || workOrder.vendorNotes!.isEmpty) ? '-' : workOrder.vendorNotes}',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  height: 5,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Container(
                                                            width: 40,
                                                            child: Column(
                                                              children: [],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(width: 10),
                                      Material(
                                        elevation: 3,
                                        child: Container(
                                          height: 40,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12.0),
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: Colors.grey),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: itemsPerPage,
                                              items: itemsPerPageOptions
                                                  .map((int value) {
                                                return DropdownMenuItem<int>(
                                                  value: value,
                                                  child: Text(value.toString()),
                                                );
                                              }).toList(),
                                              onChanged: (newValue) {
                                                setState(() {
                                                  itemsPerPage = newValue!;
                                                  currentPage =
                                                      0; // Reset to first page when items per page change
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: FaIcon(
                                          FontAwesomeIcons.circleChevronLeft,
                                          color: currentPage == 0
                                              ? Colors.grey
                                              : blueColor,
                                        ),
                                        onPressed: currentPage == 0
                                            ? null
                                            : () {
                                                setState(() {
                                                  currentPage--;
                                                });
                                              },
                                      ),
                                      Text(
                                          'Page ${currentPage + 1} of $totalPages'),
                                      IconButton(
                                        icon: FaIcon(
                                          FontAwesomeIcons.circleChevronRight,
                                          color: currentPage < totalPages - 1
                                              ? blueColor
                                              : Colors.grey,
                                        ),
                                        onPressed: currentPage < totalPages - 1
                                            ? () {
                                                setState(() {
                                                  currentPage++;
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   Padding(
                  //     padding: const EdgeInsets.only(left: 21.0, right: 21.0),
                  //     child: Expanded(
                  //         flex: 0,
                  //         child: Padding(
                  //           padding:
                  //               const EdgeInsets.only(left: 16.0, right: 16.0),
                  //           child: Row(
                  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //             children: [
                  //               Material(
                  //                 elevation: 3,
                  //                 borderRadius: BorderRadius.circular(2),
                  //                 child: Container(
                  //                   padding: const EdgeInsets.symmetric(
                  //                       horizontal: 10),
                  //                   // height: 40,
                  //                   height:
                  //                       MediaQuery.of(context).size.width < 500
                  //                           ? 48
                  //                           : 50,
                  //                   width: MediaQuery.of(context).size.width <
                  //                           500
                  //                       ? MediaQuery.of(context).size.width *
                  //                           .45
                  //                       : MediaQuery.of(context).size.width *
                  //                           .4,
                  //                   decoration: BoxDecoration(
                  //                     color: Colors.white,
                  //                     borderRadius: BorderRadius.circular(2),
                  //                     border: Border.all(
                  //                         color: const Color(0xFF8A95A8)),
                  //                   ),
                  //                   child: TextField(
                  //                     onChanged: (value) {
                  //                       setState(() {
                  //                         searchvalue = value;
                  //                       });
                  //                     },
                  //                     decoration: const InputDecoration(
                  //                       border: InputBorder.none,
                  //                       hintText: "Search here...",
                  //                       hintStyle:
                  //                           TextStyle(color: Color(0xFF8A95A8)),
                  //                       // contentPadding: EdgeInsets.all(10),
                  //                     ),
                  //                   ),
                  //                 ),
                  //               ),
                  //               ElevatedButton(
                  //                 style: ElevatedButton.styleFrom(
                  //                   backgroundColor: blueColor,
                  //                 ),
                  //                 onPressed: () {},
                  //                 child: PopupMenuButton<String>(
                  //                   onSelected: (value) async {
                  //                     // Add your export logic here based on the selected value
                  //                     if (value == 'PDF') {
                  //                       print('pdf');
                  //                       // Export as PDF
                  //                     } else if (value == 'XLSX') {
                  //                       print('XLSX');
                  //                       // Export as XLSX
                  //                     } else if (value == 'CSV') {
                  //                       print('CSV');
                  //                       // Export as CSV
                  //                     }
                  //                   },
                  //                   itemBuilder: (BuildContext context) =>
                  //                       <PopupMenuEntry<String>>[
                  //                     const PopupMenuItem<String>(
                  //                       value: 'PDF',
                  //                       child: Text('PDF'),
                  //                     ),
                  //                     const PopupMenuItem<String>(
                  //                       value: 'XLSX',
                  //                       child: Text('XLSX'),
                  //                     ),
                  //                     const PopupMenuItem<String>(
                  //                       value: 'CSV',
                  //                       child: Text('CSV'),
                  //                     ),
                  //                   ],
                  //                   child: Row(
                  //                     mainAxisSize: MainAxisSize.min,
                  //                     children: [
                  //                       Text('Export'),
                  //                       Icon(Icons.arrow_drop_down),
                  //                     ],
                  //                   ),
                  //                 ),
                  //               )
                  //             ],
                  //           ),
                  //         )),
                  //   ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   FutureBuilder<List<WorkOrderReportData>>(
                  //     future: _futureReport,
                  //     builder: (context, snapshot) {
                  //       if (snapshot.connectionState ==
                  //           ConnectionState.waiting) {
                  //         return ShimmerTabletTable();
                  //       } else if (snapshot.hasError) {
                  //         return Center(
                  //             child: friendlyErrorState(snapshot.error));
                  //       } else if (!snapshot.hasData ||
                  //           snapshot.data!.isEmpty) {
                  //         return Container(
                  //           height: MediaQuery.of(context).size.height * .5,
                  //           child: Center(
                  //             child: Column(
                  //               mainAxisAlignment: MainAxisAlignment.center,
                  //               crossAxisAlignment: CrossAxisAlignment.center,
                  //               children: [
                  //                 Image.asset(
                  //                   "assets/images/no_data.jpg",
                  //                   height: 200,
                  //                   width: 200,
                  //                 ),
                  //                 SizedBox(
                  //                   height: 10,
                  //                 ),
                  //                 Text(
                  //                   "No Data Available",
                  //                   style: TextStyle(
                  //                       fontWeight: FontWeight.bold,
                  //                       color: blueColor,
                  //                       fontSize: 16),
                  //                 )
                  //               ],
                  //             ),
                  //           ),
                  //         );
                  //       }
                  //
                  //       var data = snapshot.data!;
                  //
                  //       // Apply filtering based on selectedValue and searchvalue
                  //       if (selectedValue == null && searchvalue.isEmpty) {
                  //         data = snapshot.data!;
                  //       } else if (selectedValue == "All") {
                  //         data = snapshot.data!;
                  //       } else if (searchvalue.isNotEmpty) {
                  //         data = snapshot.data!
                  //             .where((workOrder) =>
                  //                 (workOrder.workSubject ?? '')
                  //                     .toLowerCase()
                  //                     .contains(searchvalue.toLowerCase()) ||
                  //                 (workOrder.rentalAddress ?? '')
                  //                     .toLowerCase()
                  //                     .contains(searchvalue.toLowerCase()))
                  //             .toList();
                  //       } else {
                  //         data = snapshot.data!
                  //             .where((workOrder) =>
                  //                 workOrder.workSubject == selectedValue)
                  //             .toList();
                  //       }
                  //
                  //       // Update _tableData with the filtered data
                  //       _tableData = data;
                  //
                  //       // Get the paged data
                  //       final pagedData = _pagedData;
                  //
                  //       return SingleChildScrollView(
                  //         scrollDirection: Axis.horizontal,
                  //         child: SizedBox(
                  //           width: MediaQuery.of(context).size.width * 0.95,
                  //           child: Padding(
                  //             padding: const EdgeInsets.all(16.0),
                  //             child: Column(
                  //               children: [
                  //                 Table(
                  //                   defaultColumnWidth: IntrinsicColumnWidth(),
                  //                   columnWidths: {
                  //                     0: FlexColumnWidth(),
                  //                     1: FlexColumnWidth(),
                  //                     2: FlexColumnWidth(),
                  //                     3: FlexColumnWidth(),
                  //                     4: FlexColumnWidth(),
                  //                   },
                  //                   children: [
                  //                     TableRow(
                  //                       decoration: BoxDecoration(
                  //                         border: Border.all(color: blueColor),
                  //                       ),
                  //                       children: [
                  //                         _buildHeader(
                  //                             'Date',
                  //                             0,
                  //                             (workOrder) =>
                  //                                 workOrder.createdAt ?? ''),
                  //                         _buildHeader(
                  //                             'Address',
                  //                             1,
                  //                             (workOrder) =>
                  //                                 workOrder.rentalAddress ??
                  //                                 ''),
                  //                         _buildHeader(
                  //                             'Work',
                  //                             2,
                  //                             (workOrder) =>
                  //                                 workOrder.workSubject ?? ''),
                  //                         _buildHeader(
                  //                             'Description',
                  //                             3,
                  //                             (workOrder) =>
                  //                                 workOrder.workPerformed ??
                  //                                 ''),
                  //                         _buildHeader(
                  //                             'Note',
                  //                             5,
                  //                             (workOrder) =>
                  //                                 workOrder.vendorNotes ?? ''),
                  //                       ],
                  //                     ),
                  //                     TableRow(
                  //                       decoration: BoxDecoration(
                  //                         border: Border.symmetric(
                  //                             horizontal: BorderSide.none),
                  //                       ),
                  //                       children: List.generate(
                  //                           5,
                  //                           (index) => TableCell(
                  //                               child: Container(height: 20))),
                  //                     ),
                  //                     for (var i = 0; i < pagedData.length; i++)
                  //                       TableRow(
                  //                         decoration: BoxDecoration(
                  //                           border: Border(
                  //                             left:
                  //                                 BorderSide(color: blueColor),
                  //                             right:
                  //                                 BorderSide(color: blueColor),
                  //                             top: BorderSide(color: blueColor),
                  //                             bottom: i == pagedData.length - 1
                  //                                 ? BorderSide(color: blueColor)
                  //                                 : BorderSide.none,
                  //                           ),
                  //                         ),
                  //                         children: [
                  //                           _buildDataCell(
                  //                               pagedData[i].date ?? ''),
                  //                           _buildDataCell(
                  //                               pagedData[i].rentalAddress ??
                  //                                   ''),
                  //                           _buildDataCell(
                  //                               pagedData[i].workSubject ?? ''),
                  //                           _buildDataCell(
                  //                               pagedData[i].workPerformed ??
                  //                                   ''),
                  //                           _buildDataCell(
                  //                               pagedData[i].vendorNotes ?? ''),
                  //                         ],
                  //                       ),
                  //                   ],
                  //                 ),
                  //                 SizedBox(height: 25),
                  //                 _buildPaginationControls(),
                  //                 SizedBox(height: 25),
                  //               ],
                  //             ),
                  //           ),
                  //         ),
                  //       );
                  //     },
                  //   )
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
