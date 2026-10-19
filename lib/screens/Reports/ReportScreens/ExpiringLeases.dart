import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:flutter/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/cupertino.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:three_zero_two_property/Model/ReportExpiringLease.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/repository/ExpiringLeaseTable.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/widgets/CustomDateField.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class ExpiringLeases extends StatefulWidget {
  @override
  _ExpiringLeasesState createState() => _ExpiringLeasesState();
}

class _ExpiringLeasesState extends State<ExpiringLeases>
    with NetworkRetryState {
  Future<List<ReportExpiringLeaseData>>? _futureReport;

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
    _fetchData(force: true);
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
    checkInternet();
    // The date fields write straight to their controllers, so without
    // these the Run button never noticed a date was chosen and stayed
    // greyed out forever.
    _fromDateController.addListener(_onDateFieldChanged);
    _toDateController.addListener(_onDateFieldChanged);
    _fetchData();
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

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();

  String? lastFromDate;
  String? lastToDate;

  DateTime? _pickedFrom;
  DateTime? _pickedTo;

  /// Local filled date field. Kept local on purpose: the shared
  /// CustomDateField is used by many other screens, so the grey fill from the
  /// agreed design is applied here rather than changing that widget. Picker
  /// behaviour matches it — same theme, same range, same date formatting.
  Widget _filledDateField(TextEditingController controller,
      {required bool isFrom}) {
    final bool empty = controller.text.trim().isEmpty;
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: (isFrom ? _pickedFrom : _pickedTo) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              primaryColor: blueColor,
              colorScheme: ColorScheme.light(primary: blueColor),
            ),
            child: child!,
          ),
        );
        if (picked == null) return;
        final dp = Provider.of<DateProvider>(context, listen: false);
        setState(() {
          if (isFrom) {
            _pickedFrom = picked;
          } else {
            _pickedTo = picked;
          }
          controller.text = dp.formatCurrentDate(picked.toString());
          // Hand-picking a date means the preset no longer describes the range.
          daterange = 'Custom';
        });
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          border: Border.all(color: const Color(0xFFEDEFF2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                empty ? 'MM/DD/YYYY' : controller.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: empty ? const Color(0xFF8A95A8) : blueColor,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFF8A95A8)),
          ],
        ),
      ),
    );
  }

  static const List<String> _dateRangeOptions = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 14 Days',
    'Last 30 Days',
    'This Week',
    'Last Week',
    'This Month',
    'Last Month',
    'This Quarter',
    'Last Quarter',
    'Year to Date',
    'Last Year',
    'Custom',
  ];

  /// Small uppercase field label used across the filter card.
  Widget _filterLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF8A95A8),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      );

  /// Web parity: the Date Range dropdown starts on Custom with both dates
  /// empty, and Run stays disabled until a range is chosen.
  String? daterange = 'Custom';

  /// True once a run has returned rows. Export is hidden until then, so the
  /// search field spans the full width on an empty report.
  bool _hasRows = false;

  void _onDateFieldChanged() {
    if (mounted) setState(() {});
  }

  /// Web's From/To check (null when the range is fine).
  String? get _dateRangeError =>
      reportDateRangeError(_fromDateController.text, _toDateController.text);

  bool get _canRun =>
      _fromDateController.text.trim().isNotEmpty &&
      _toDateController.text.trim().isNotEmpty &&
      _dateRangeError == null;

  /// Fills From/To from a preset, matching the ranges the Expiring Insurance
  /// report already uses so both screens agree. Presets only set the fields —
  /// nothing loads until Run is tapped, exactly as web behaves.
  void _applyDateRangePreset(String value, DateProvider dateProvider) {
    final now = DateTime.now();
    String fmt(DateTime d) => dateProvider.formatCurrentDate(d.toString());
    DateTime? from;
    DateTime? to;
    switch (value) {
      case 'Today':
        from = now;
        to = now;
        break;
      case 'Yesterday':
        final y = now.subtract(const Duration(days: 1));
        from = y;
        to = y;
        break;
      case 'Last 7 Days':
        from = now.subtract(const Duration(days: 6));
        to = now;
        break;
      case 'Last 14 Days':
        from = now.subtract(const Duration(days: 13));
        to = now;
        break;
      case 'Last 30 Days':
        from = now.subtract(const Duration(days: 29));
        to = now;
        break;
      case 'This Week':
        from = now.subtract(Duration(days: now.weekday - 1));
        to = from.add(const Duration(days: 6));
        break;
      case 'Last Week':
        final start = now.subtract(Duration(days: now.weekday - 1 + 7));
        from = start;
        to = start.add(const Duration(days: 6));
        break;
      case 'This Month':
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        break;
      case 'Last Month':
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 0);
        break;
      case 'This Quarter':
        final q = (now.month - 1) ~/ 3;
        from = DateTime(now.year, q * 3 + 1, 1);
        to = DateTime(now.year, q * 3 + 4, 0);
        break;
      case 'Last Quarter':
        final q = (now.month - 1) ~/ 3 - 1;
        final year = q < 0 ? now.year - 1 : now.year;
        final qi = q < 0 ? 3 : q;
        from = DateTime(year, qi * 3 + 1, 1);
        to = DateTime(year, qi * 3 + 4, 0);
        break;
      case 'Year to Date':
        from = DateTime(now.year, 1, 1);
        to = now;
        break;
      case 'Last Year':
        from = DateTime(now.year - 1, 1, 1);
        to = DateTime(now.year - 1, 12, 31);
        break;
      case 'Custom':
      default:
        // Custom clears the fields so the user picks the range themselves,
        // which is why Run is greyed until they do.
        _fromDateController.clear();
        _toDateController.clear();
        return;
    }
    _fromDateController.text = fmt(from);
    _toDateController.text = fmt(to);
  }

  void _fetchData({bool force = false}) {
    String currentFromDate = _fromDateController.text;
    String currentToDate = _toDateController.text;

    // Check if the current dates are the same as the last selected dates.
    // Run passes force so tapping it always re-applies the current range.
    if (!force &&
        currentFromDate == lastFromDate &&
        currentToDate == lastToDate) {
      // If the dates are the same, do not call the API
      return;
    }

    if (currentFromDate.isNotEmpty && currentToDate.isNotEmpty) {
      _futureReport = ExpiringLeaseTableService().fetchExpiringLeases(
        fromDate: currentFromDate,
        toDate: currentToDate,
      );

      // Track whether the run produced rows so Export can appear only then.
      _futureReport!.then((rows) {
        if (mounted) setState(() => _hasRows = rows.isNotEmpty);
      }).catchError((_) {
        if (mounted) setState(() => _hasRows = false);
        return <ReportExpiringLeaseData>[];
      });

      // Update the last selected dates
      lastFromDate = currentFromDate;
      lastToDate = currentToDate;
    } else {
      // Web parity: with no range chosen the report stays empty and waits for
      // Run. Fetching unfiltered here is what made mobile show every lease
      // before a date was picked.
      _futureReport = null;
      _hasRows = false;
      lastFromDate = null;
      lastToDate = null;
    }
    setState(() {});
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final formatter = DateFormat('yyyy-MM-dd');
      return formatter.format(date);
    } catch (e) {
      return dateStr; // If the date is not valid, return the original string
    }
  }

  Future<void> generatePdf(List<ReportExpiringLeaseData> leaseData) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      logError("Error fetching profile data: $e");
      return;
    }

    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
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
                    'Expiring Lease',
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
                  //  pw.SizedBox(height: 30)
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20)
        ]),
        build: (pw.Context context) {
          return [
            pw.Table.fromTextArray(
                headers: [
                  'Property',
                  'Unit',
                  'Tenant',
                  'Rent',
                  'Non-rent',
                  'Lease Start',
                  'Lease End',
                  'Status',
                ],
                columnWidths: {
                  0: pw.FlexColumnWidth(1.5), // Property
                  1: pw.FlexColumnWidth(0.7), // Unit
                  2: pw.FixedColumnWidth(90), // Tenant (fixed width)
                  3: pw.FlexColumnWidth(1), // Rent
                  4: pw.FlexColumnWidth(1.1), // Non-rent
                  5: pw.FlexColumnWidth(1.2), // Lease Start
                  6: pw.FlexColumnWidth(1.2), // Lease End
                  7: pw.FlexColumnWidth(1), // Status
                },
                data: _generateTableData(leaseData),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5A86D5"),
                  //color:PdfColor.fromRYB(90, 134, 213,)
                ),
                cellStyle: pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                border: null),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Expiring-lease.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Expiring-lease',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  List<List<dynamic>> _generateTableData(
      List<ReportExpiringLeaseData> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];
    double total = 0.0;

    for (var owner in rentalOwnerReports) {
      // Main row for the rental owner name
      tableData.add([
        pw.Text(owner.rentalAddress!,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(owner.rentalUnit ?? "N/A"!,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(owner.tenantNames!,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(formatCurrency(owner.amount?.toDouble()),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(formatMoney(owner.recurring.toString()!),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(owner.startDate!,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(owner.endDate!,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
        pw.Text(owner.status!,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            )),
      ]);

      // for (var property in owner.payments) {
      //   tableData.add([
      //     pw.Padding(
      //         child: pw.Text(
      //           '${property.rentalData!.rentalAddress ?? 'N/A'}',
      //           style: pw.TextStyle(fontSize: 10,fontWeight: pw.FontWeight.bold),
      //         ),
      //         padding: pw.EdgeInsets.only(left: 15)),
      //     pw.Text( '${property.tenantData!.tenantFirstName ?? 'N/A'} ${property.tenantData!.tenantLastName ?? 'N/A'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),),// Property Name
      //     // Tenant Name
      //     pw.Text(property.createdAt.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),),// Payment Date
      //     pw.Text(property.paymentType ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),), // Payment Type
      //     pw.Text(property.transactionId ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),), // Transaction ID
      //     pw.Text( property.paymentId ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),), // References
      //     pw.Text(property.ccType ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),),// Card Type
      //     pw.Text(property.ccNumber ?? '',  style: pw.TextStyle(fontWeight: pw.FontWeight.bold,fontSize: 10,),),// Card Number
      //     pw.Align(
      //       alignment: pw.Alignment.centerRight,
      //       child: pw.Text(
      //         '\$${(property.totalAmount ?? 0.0).toStringAsFixed(2)}',
      //         style: pw.TextStyle(fontSize: 10,fontWeight: pw.FontWeight.bold),
      //         // Total Amount formatted to 2 decimal places
      //         // Align text to the right
      //       ),
      //     ),
      //   ]);
      //
      //   for (var payment in property.entry) {
      //     tableData.add([
      //       pw.Padding(
      //           child: pw.Text('${payment.account ?? 'N/A'}',
      //               style: pw.TextStyle(fontSize: 10)),
      //           padding: pw.EdgeInsets.only(left: 15)), // Account Name
      //       '', // Account Amount
      //       '', '', '', '', '', '',
      //       pw.Align(
      //           alignment: pw.Alignment.centerRight,
      //           child: pw.Text(
      //               formatCurrency(payment.amount),
      //               style: pw.TextStyle(fontSize: 10),
      //               textAlign: pw.TextAlign.right // Align text to the right
      //           ))
      //     ]);
      //   }
      //
      //   if (property.surcharge != 0.0) {
      //     tableData.add([
      //       pw.Padding(
      //           child: pw.Text(
      //             'Surcharge',
      //             style: pw.TextStyle(fontSize: 10),
      //           ),
      //           padding: pw.EdgeInsets.only(left: 15)),
      //       '', // Account Amount
      //       '', '', '', '', '', '',
      //       pw.Align(
      //           alignment: pw.Alignment.centerRight,
      //           child: pw.Text(
      //               '\$${(property.surcharge ?? 0.0).toStringAsFixed(2)}', // Surcharge formatted to 2 decimal places
      //               style: pw.TextStyle(fontSize: 10),
      //               textAlign: pw.TextAlign.right // Align text to the right
      //           ))
      //     ]);
      //   }
      // }

      // Subtotal row for the rental owner
      // tableData.add([
      //   pw.Padding(
      //       child: pw.Text('Subtotal ${owner.rentalOwnerName ?? 'N/A'}',
      //           style:
      //           pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
      //       padding: pw.EdgeInsets.only(
      //           left: 15)), // Label for rental owner subtotal
      //   '', '', '', '', '', '', '',
      //   pw.Text(
      //       '\$${(owner.subTotal ?? 0.0).toStringAsFixed(2)}', // Subtotal formatted to 2 decimal places
      //       style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      //       textAlign: pw.TextAlign.right // Align text to the right
      //   )
      // ]);
      //
      // total += owner.subTotal;
    }

    // setState(() {
    //   grandtotal = total;
    // });

    return tableData;
  }

  Future<void> generateExcel(List<ReportExpiringLeaseData> leaseData) async {
    // Create a new Excel document.
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    // Adjusting column widths
    sheet.getRangeByName('A1:H1').columnWidth = 20;

    // Adding table headers
    final List<String> headers = [
      'Property',
      'Unit',
      'Tenant',
      'Rent',
      'Non-rent',
      'Lease Start',
      'Lease End',
      'Status',
    ];
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#D3D3D3'; // Gray color for header
    headerCellStyle.hAlign =
        syncXlsx.HAlignType.center; // Center alignment for header

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(6, i + 1); // Start at row 6
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    // Adding lease data starting from row 7
    for (int i = 0; i < leaseData.length; i++) {
      final lease = leaseData[i];
      sheet.getRangeByIndex(7 + i, 1).setText(lease.rentalAddress ?? '');
      sheet.getRangeByIndex(7 + i, 2).setText(lease.rentalUnit ?? '');
      sheet.getRangeByIndex(7 + i, 3).setText(lease.tenantNames ?? '');
      sheet
          .getRangeByIndex(7 + i, 4)
          .setNumber((lease.amount ?? 0.0).toDouble());
      sheet
          .getRangeByIndex(7 + i, 5)
          .setNumber((lease.recurring ?? 0).toDouble());

      // Parse dates
      DateTime? startDate = lease.startDate != null
          ? DateFormat('yyyy-MM-dd').parse(lease.startDate!)
          : null;
      DateTime? endDate = lease.endDate != null
          ? DateFormat('yyyy-MM-dd').parse(lease.endDate!)
          : null;

      sheet.getRangeByIndex(7 + i, 6).setDateTime(startDate ?? DateTime.now());
      sheet.getRangeByIndex(7 + i, 7).setDateTime(endDate ?? DateTime.now());
      sheet.getRangeByIndex(7 + i, 8).setText(lease.status ?? '');
    }

    // Save the document.
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    // Generate a unique file name
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'ExpiringLeaseReport_$formattedDate.xlsx';

    // Get the directory to save the file.
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    // Save the file.
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(path)]);
    // Show a message with the file path.
    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

//Csv Generate method

  Future<void> requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> generateCsv(List<ReportExpiringLeaseData> leaseData) async {
    // Request storage permissions
    await requestPermissions();

    // Prepare CSV data
    List<List<dynamic>> rows = [
      [
        'Property',
        'Unit',
        'Tenant',
        'Rent',
        'Non-rent',
        'Lease Start',
        'Lease End',
        'Status'
      ]
    ];

    for (var lease in leaseData) {
      rows.add([
        lease.rentalAddress ?? '',
        lease.rentalUnit ?? '',
        lease.tenantNames ?? '',
        lease.amount ?? 0.0,
        lease.recurring ?? 0,
        lease.startDate ?? '',
        lease.endDate ?? '',
        lease.status ?? '',
      ]);
    }

    // Convert rows to CSV string
    String csv = const ListToCsvConverter().convert(rows);

    // Generate a unique file name
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'ExpiringLeaseReport_$formattedDate.csv';

    // Get the directory to save the file.
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    // Save the file
    final File file = File(path);
    await file.writeAsString(csv, flush: true);
    Share.shareXFiles([XFile(path)]);
    // Show a message with the file path
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  void sortData(List<ReportExpiringLeaseData> data) {
    if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.rentalAddress!.compareTo(b.rentalAddress!)
          : b.rentalAddress!.compareTo(a.rentalAddress!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.tenantNames!.compareTo(b.tenantNames!)
          : b.tenantNames!.compareTo(a.tenantNames!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.status!.compareTo(b.status!)
          : b.status!.compareTo(a.status!));
    }
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
                        ascending1 = sorting1 ? !ascending1 : true;
                        ascending2 = false;
                        ascending3 = false;
                      } else {
                        sorting1 = !sorting1;
                        sorting2 = false;
                        sorting3 = false;
                        ascending1 = sorting1 ? !ascending1 : true;
                        ascending2 = false;
                        ascending3 = false;
                      }

                      // Sorting logic here
                    });
                  },
                  child: Row(
                    children: [
                      width < 400
                          ? Text("Property",
                              style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15))
                          : Text("Property",
                              style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                      // Text("Property", style: TextStyle(color: Colors.white)),
                      SizedBox(width: 3),
                      ascending1
                          ? Padding(
                              padding: EdgeInsets.only(top: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortUp,
                                size: 20,
                                color: blueColor,
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.only(bottom: 7, left: 2),
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
                        sorting2 = sorting2;
                        sorting3 = false;
                        ascending2 = sorting2 ? !ascending2 : true;
                        ascending1 = false;
                        ascending3 = false;
                      } else {
                        sorting1 = false;
                        sorting2 = !sorting2;
                        sorting3 = false;
                        ascending2 = sorting2 ? !ascending2 : true;
                        ascending1 = false;
                        ascending3 = false;
                      }
                      // Sorting logic here
                    });
                  },
                  child: Row(
                    children: [
                      Text("Tenant",
                          style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(width: 5),
                      ascending2
                          ? Padding(
                              padding: EdgeInsets.only(top: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortUp,
                                size: 20,
                                color: blueColor,
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.only(bottom: 7, left: 2),
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
            ],
          ),
        ),
      ),
    );
  }

  String searchvalue = "";
  String? selectedValue;

  List<ReportExpiringLeaseData> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<ReportExpiringLeaseData> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    if (startIndex >= _tableData.length) startIndex = 0;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0; // Reset to the first page when changing rows per page
    });
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(ReportExpiringLeaseData d)? getField) {
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

  void _sort<T>(Comparable<T> Function(ReportExpiringLeaseData d) getField,
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

  Widget _buildDataCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16, bottom: 20.0),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildPaginationControls() {
    int numorpages = 1;
    numorpages = (totalrecords / _rowsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Text('Rows per page: '),
        // SizedBox(width: 10),
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

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
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
                  SizedBox(
                    height: 16,
                  ),
                  ReportHeader(
                    title: "Expiring Lease",
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                        left: MediaQuery.of(context).size.width > 500 ? 10 : 0,
                        right:
                            MediaQuery.of(context).size.width > 500 ? 10 : 0),
                    child: Container(
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 16.0, right: 16.0, bottom: 8),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: const Color(0xFFEDEFF2)),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Filter card laid out to the agreed
                                  // design: DATE RANGE beside Run, then
                                  // FROM/TO underneath, uppercase labels and
                                  // filled inputs.
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _filterLabel('DATE RANGE'),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 48,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF5F6F8),
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFEDEFF2)),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton2<String>(
                                                  isExpanded: true,
                                                  value: daterange,
                                                  // The plain DropdownButton
                                                  // opened a full-screen white
                                                  // sheet; this keeps the menu
                                                  // sized to the field.
                                                  iconStyleData: IconStyleData(
                                                    icon: Icon(
                                                        Icons
                                                            .keyboard_arrow_down,
                                                        color: blueColor),
                                                  ),
                                                  buttonStyleData:
                                                      const ButtonStyleData(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          height: 48),
                                                  menuItemStyleData:
                                                      const MenuItemStyleData(
                                                          height: 44),
                                                  dropdownStyleData:
                                                      DropdownStyleData(
                                                    maxHeight: 320,
                                                    elevation: 3,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFFE3E6EB)),
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                      color: blueColor,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                  items: _dateRangeOptions
                                                      .map((v) =>
                                                          DropdownMenuItem<
                                                              String>(
                                                            value: v,
                                                            child: Text(
                                                                v == 'Custom'
                                                                    ? 'Custom Date'
                                                                    : v,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis),
                                                          ))
                                                      .toList(),
                                                  onChanged: (value) {
                                                    if (value == null) return;
                                                    final dp = Provider.of<
                                                            DateProvider>(
                                                        context,
                                                        listen: false);
                                                    setState(() {
                                                      daterange = value;
                                                      _applyDateRangePreset(
                                                          value, dp);
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        height: 48,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _canRun
                                                ? blueColor
                                                : blueColor.withOpacity(0.4),
                                            foregroundColor: Colors.white,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 22),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: _canRun
                                              ? () => _fetchData(force: true)
                                              : null,
                                          child: const Text('Run',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _filterLabel('FROM'),
                                            const SizedBox(height: 6),
                                            _filledDateField(
                                                _fromDateController,
                                                isFrom: true),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _filterLabel('TO'),
                                            const SizedBox(height: 6),
                                            _filledDateField(
                                                _toDateController,
                                                isFrom: false),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_dateRangeError != null)
                                    ReportDateRangeErrorText(_dateRangeError!),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Expanded(
                  //     flex: 0,
                  //     child: Padding(
                  //       padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                  //       child: Row(
                  //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //         children: [
                  //           Material(
                  //             elevation: 3,
                  //             borderRadius: BorderRadius.circular(2),
                  //             child: Container(
                  //               padding: const EdgeInsets.symmetric(horizontal: 10),
                  //               // height: 40,
                  //               height:
                  //                   MediaQuery.of(context).size.width < 500 ? 40 : 50,
                  //               width: MediaQuery.of(context).size.width < 500
                  //                   ? MediaQuery.of(context).size.width * .45
                  //                   : MediaQuery.of(context).size.width * .4,
                  //               decoration: BoxDecoration(
                  //                 color: Colors.white,
                  //                 borderRadius: BorderRadius.circular(2),
                  //                 border: Border.all(color: const Color(0xFF8A95A8)),
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
                  //                   hintStyle: TextStyle(color: Color(0xFF8A95A8)),
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
                  //                   if (_fromDateController.text.isNotEmpty &&
                  //                       _toDateController.text.isNotEmpty) {
                  //                     final data = await ExpiringLeaseTableService()
                  //                         .fetchExpiringLeases(
                  //                       fromDate: _fromDateController.text,
                  //                       toDate: _toDateController.text,
                  //                     );

                  //                     await generatePdf(data);
                  //                   } else {
                  //                     final data = await ExpiringLeaseTableService()
                  //                         .fetchExpiringLeases();

                  //                     await generatePdf(data);
                  //                   }

                  //                   print('pdf');
                  //                   // Export as PDF
                  //                 } else if (value == 'XLSX') {
                  //                   if (_fromDateController.text.isNotEmpty &&
                  //                       _toDateController.text.isNotEmpty) {
                  //                     final data = await ExpiringLeaseTableService()
                  //                         .fetchExpiringLeases(
                  //                       fromDate: _fromDateController.text,
                  //                       toDate: _toDateController.text,
                  //                     );

                  //                     await generateExcel(data);
                  //                   } else {
                  //                     final data = await ExpiringLeaseTableService()
                  //                         .fetchExpiringLeases();

                  //                     await generateExcel(data);
                  //                   }
                  //                   print('XLSX');
                  //                   // Export as XLSX
                  //                 } else if (value == 'CSV') {
                  //                   if (_fromDateController.text.isNotEmpty &&
                  //                       _toDateController.text.isNotEmpty) {
                  //                     final data = await ExpiringLeaseTableService()
                  //                         .fetchExpiringLeases(
                  //                       fromDate: _fromDateController.text,
                  //                       toDate: _toDateController.text,
                  //                     );

                  //                     await generatePdf(data);
                  //                   } else {
                  //                     final data = await ExpiringLeaseTableService()
                  //                         .fetchExpiringLeases();

                  //                     await generatePdf(data);
                  //                   }
                  //                   print('CSV');
                  //                   // Export as CSV
                  //                 }
                  //               },
                  //               itemBuilder: (BuildContext context) =>
                  //                   <PopupMenuEntry<String>>[
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
                  //     )),
                  // if (MediaQuery.of(context).size.width < 500)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10.0,
                      right: 10.0,
                    ),
                    child: FutureBuilder<List<ReportExpiringLeaseData>>(
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
                              child: Text(
                                  // A raw Dart exception is not a user
                                  // message; keep the detail in the log.
                                  'Could not load the report. Please try again.',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 14)));
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

                        // Apply filtering based on selectedValue and searchvalue
                        if (selectedValue == null && searchvalue.isEmpty) {
                          data = snapshot.data!;
                        } else if (selectedValue == "All") {
                          data = snapshot.data!;
                        } else if (searchvalue.isNotEmpty) {
                          data = snapshot.data!
                              .where((lease) =>
                                  lease.rentalAddress
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.tenantNames
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.amount
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.status
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.startDate
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()))
                              .toList();
                        } else {
                          data = snapshot.data!
                              .where((lease) =>
                                  lease.rentalAddress == selectedValue)
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
                                  children: [
                                    // Search box expands
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: const Color(0xFFEDEFF2)),
                                          ),
                                          // Icon and field as explicit Row
                                          // children: the Row centres both, so
                                          // the hint no longer depends on the
                                          // input decorator's own padding.
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.search,
                                                  size: 20,
                                                  color: Color(0xFF8A95A8)),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: TextField(
                                                  textAlignVertical:
                                                      TextAlignVertical.center,
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      searchvalue = value;
                                                      currentPage = 0; // reset to first page on search change
                                                    });
                                                  },
                                                  decoration:
                                                      const InputDecoration(
                                                    border: InputBorder.none,
                                                    // Collapsed removes the
                                                    // decorator's built-in
                                                    // height so the text sits
                                                    // level with the icon.
                                                    isCollapsed: true,
                                                    hintText: "Search here...",
                                                    hintStyle: TextStyle(
                                                        color:
                                                            Color(0xFF8A95A8),
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Export appears only once the report has
                                    // rows, so the search field spans the full
                                    // width on an empty report.
                                    if (_hasRows)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5.0),
                                      // Fixed box so the pill is exactly as
                                      // tall as the search field; the nested
                                      // PopupMenuButton was adding its own
                                      // padding and pushing it taller.
                                      child: SizedBox(
                                        height: 52,
                                        child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor,
                                          foregroundColor: Colors.white,
                                          minimumSize:
                                              const Size(0, 52),
                                          tapTargetSize: MaterialTapTargetSize
                                              .shrinkWrap,
                                          padding: const EdgeInsets
                                              .symmetric(horizontal: 14),
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                        ),
                                        onPressed: () {},
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          onSelected: (value) async {
                                            final hasDates = _fromDateController
                                                    .text.isNotEmpty &&
                                                _toDateController
                                                    .text.isNotEmpty;

                                            // Export must match what the
                                            // report shows. Without a range
                                            // nothing has been run, so
                                            // exporting every lease would hand
                                            // back rows the user never saw.
                                            if (!hasDates) {
                                              Fluttertoast.showToast(
                                                msg:
                                                    'Choose a date range and tap Run before exporting.',
                                                backgroundColor: Colors.red,
                                              );
                                              return;
                                            }
                                            final data =
                                                await ExpiringLeaseTableService()
                                                    .fetchExpiringLeases(
                                              fromDate:
                                                  _fromDateController.text,
                                              toDate: _toDateController.text,
                                            );

                                            if (value == 'PDF') {
                                              await generatePdf(data);
                                            } else if (value == 'XLSX') {
                                              await generateExcel(data);
                                            } else if (value == 'CSV') {
                                              await generateCsv(data);
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
                                              Text('Export'),
                                              Icon(Icons.arrow_drop_down),
                                            ],
                                          ),
                                        ),
                                      ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),
                              _buildHeaders(),
                              SizedBox(height: 10),
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
                                  child: Column(
                                    children: currentPageData.isEmpty
                                        ? [kNoSearchResults(context)]
                                        : currentPageData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int index = entry.key;
                                      bool isExpanded = expandedIndex == index;
                                      ReportExpiringLeaseData lease =
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
                                                        '   ${lease.rentalAddress}',
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
                                                        '${lease.tenantNames}',
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
                                                                            'Rent : ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text: formatCurrency(lease
                                                                            .amount
                                                                            ?.toDouble()),
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
                                                                            'Non-Rent : ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${lease.recurring}',
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
                                                                            'Lease Start :  ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text: dateProvider
                                                                            .formatCurrentDate('${lease.createdAt}'),
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
                                                                            'Leasr End :  ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text: dateProvider
                                                                            .formatCurrentDate('${lease.endDate}'),
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
                                                                            'STATUS : ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${lease.status}',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
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
                  //   SizedBox(
                  //     height: 8,
                  //   ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   Expanded(
                  //       flex: 0,
                  //       child: Padding(
                  //         padding: const EdgeInsets.only(
                  //             left: 32.0, right: 32.0, bottom: 8),
                  //         child: Row(
                  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //           children: [
                  //             Material(
                  //               elevation: 3,
                  //               borderRadius: BorderRadius.circular(2),
                  //               child: Container(
                  //                 padding: const EdgeInsets.symmetric(
                  //                     horizontal: 10),
                  //                 // height: 40,
                  //                 height:
                  //                     MediaQuery.of(context).size.width < 500
                  //                         ? 40
                  //                         : 50,
                  //                 width: MediaQuery.of(context).size.width < 500
                  //                     ? MediaQuery.of(context).size.width * .45
                  //                     : MediaQuery.of(context).size.width * .4,
                  //                 decoration: BoxDecoration(
                  //                   color: Colors.white,
                  //                   borderRadius: BorderRadius.circular(2),
                  //                   border: Border.all(
                  //                       color: const Color(0xFF8A95A8)),
                  //                 ),
                  //                 child: TextField(
                  //                   onChanged: (value) {
                  //                     setState(() {
                  //                       searchvalue = value;
                  //                     });
                  //                   },
                  //                   decoration: const InputDecoration(
                  //                     border: InputBorder.none,
                  //                     hintText: "Search here...",
                  //                     hintStyle:
                  //                         TextStyle(color: Color(0xFF8A95A8)),
                  //                     contentPadding: EdgeInsets.all(10),
                  //                   ),
                  //                 ),
                  //               ),
                  //             ),
                  //             ElevatedButton(
                  //               style: ElevatedButton.styleFrom(
                  //                 backgroundColor: blueColor,
                  //               ),
                  //               onPressed: () {},
                  //               child: PopupMenuButton<String>(
                  //                 onSelected: (value) async {
                  //                   // Add your export logic here based on the selected value
                  //                   if (value == 'PDF') {
                  //                     if (_fromDateController.text.isNotEmpty &&
                  //                         _toDateController.text.isNotEmpty) {
                  //                       final data =
                  //                           await ExpiringLeaseTableService()
                  //                               .fetchExpiringLeases(
                  //                         fromDate: _fromDateController.text,
                  //                         toDate: _toDateController.text,
                  //                       );
                  //
                  //                       await generatePdf(data);
                  //                     } else {
                  //                       final data =
                  //                           await ExpiringLeaseTableService()
                  //                               .fetchExpiringLeases();
                  //
                  //                       await generatePdf(data);
                  //                     }
                  //
                  //                     print('pdf');
                  //                     // Export as PDF
                  //                   } else if (value == 'XLSX') {
                  //                     if (_fromDateController.text.isNotEmpty &&
                  //                         _toDateController.text.isNotEmpty) {
                  //                       final data =
                  //                           await ExpiringLeaseTableService()
                  //                               .fetchExpiringLeases(
                  //                         fromDate: _fromDateController.text,
                  //                         toDate: _toDateController.text,
                  //                       );
                  //
                  //                       await generateExcel(data);
                  //                     } else {
                  //                       final data =
                  //                           await ExpiringLeaseTableService()
                  //                               .fetchExpiringLeases();
                  //
                  //                       await generateExcel(data);
                  //                     }
                  //                     print('XLSX');
                  //                     // Export as XLSX
                  //                   } else if (value == 'CSV') {
                  //                     if (_fromDateController.text.isNotEmpty &&
                  //                         _toDateController.text.isNotEmpty) {
                  //                       final data =
                  //                           await ExpiringLeaseTableService()
                  //                               .fetchExpiringLeases(
                  //                         fromDate: _fromDateController.text,
                  //                         toDate: _toDateController.text,
                  //                       );
                  //
                  //                       await generateCsv(data);
                  //                     } else {
                  //                       final data =
                  //                           await ExpiringLeaseTableService()
                  //                               .fetchExpiringLeases();
                  //
                  //                       await generateCsv(data);
                  //                     }
                  //                     print('CSV');
                  //                     // Export as CSV
                  //                   }
                  //                 },
                  //                 itemBuilder: (BuildContext context) =>
                  //                     <PopupMenuEntry<String>>[
                  //                   const PopupMenuItem<String>(
                  //                     value: 'PDF',
                  //                     child: Text('PDF'),
                  //                   ),
                  //                   const PopupMenuItem<String>(
                  //                     value: 'XLSX',
                  //                     child: Text('XLSX'),
                  //                   ),
                  //                   const PopupMenuItem<String>(
                  //                     value: 'CSV',
                  //                     child: Text('CSV'),
                  //                   ),
                  //                 ],
                  //                 child: Row(
                  //                   mainAxisSize: MainAxisSize.min,
                  //                   children: [
                  //                     Text('Export'),
                  //                     Icon(Icons.arrow_drop_down),
                  //                   ],
                  //                 ),
                  //               ),
                  //             )
                  //           ],
                  //         ),
                  //       )),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   SizedBox(
                  //     height: 18,
                  //   ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //    FutureBuilder<List<ReportExpiringLeaseData>>(
                  //      future: _futureReport,
                  //      builder: (context, snapshot) {
                  //        if (snapshot.connectionState ==
                  //            ConnectionState.waiting) {
                  //          return ShimmerTabletTable();
                  //        } else if (snapshot.hasError) {
                  //          return Center(
                  //              child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                  //        } else if (!snapshot.hasData ||
                  //            snapshot.data!.isEmpty) {
                  //          return Container(
                  //            height: MediaQuery.of(context).size.height * .5,
                  //            child: Center(
                  //              child: Column(
                  //                mainAxisAlignment: MainAxisAlignment.center,
                  //                crossAxisAlignment: CrossAxisAlignment.center,
                  //                children: [
                  //                  Image.asset(
                  //                    "assets/images/no_data.jpg",
                  //                    height: 200,
                  //                    width: 200,
                  //                  ),
                  //                  SizedBox(
                  //                    height: 10,
                  //                  ),
                  //                  Text(
                  //                    "No Data Available",
                  //                    style: TextStyle(
                  //                        fontWeight: FontWeight.bold,
                  //                        color: blueColor,
                  //                        fontSize: 16),
                  //                  )
                  //                ],
                  //              ),
                  //            ),
                  //          );
                  //        }
                  //
                  //        var data = snapshot.data!;
                  //
                  //        // Apply filtering based on selectedValue and searchvalue
                  //        if (selectedValue == null && searchvalue.isEmpty) {
                  //          data = snapshot.data!;
                  //        } else if (selectedValue == "All") {
                  //          data = snapshot.data!;
                  //        } else if (searchvalue.isNotEmpty) {
                  //          data = snapshot.data!
                  //              .where((lease) =>
                  //                  lease.rentalAddress!
                  //                      .toLowerCase()
                  //                      .contains(searchvalue.toLowerCase()) ||
                  //                  lease.tenantNames!
                  //                      .toLowerCase()
                  //                      .contains(searchvalue.toLowerCase()))
                  //              .toList();
                  //        } else {
                  //          data = snapshot.data!
                  //              .where((lease) =>
                  //                  lease.rentalAddress == selectedValue)
                  //              .toList();
                  //        }
                  //
                  //        // Apply pagination
                  //        final int itemsPerPage = 10;
                  //        final int totalPages =
                  //            (data.length / itemsPerPage).ceil();
                  //        final int currentPage =
                  //            1; // Update this with your pagination logic
                  //        final List<ReportExpiringLeaseData> pagedData = data
                  //            .skip((currentPage - 1) * itemsPerPage)
                  //            .take(itemsPerPage)
                  //            .toList();
                  //
                  //        return SingleChildScrollView(
                  //          scrollDirection: Axis.horizontal,
                  //          child: SizedBox(
                  //            width: MediaQuery.of(context).size.width * 0.95,
                  //            child: Column(
                  //              children: [
                  //                Table(
                  //                  defaultColumnWidth: IntrinsicColumnWidth(),
                  //                  columnWidths: {
                  //                    0: FlexColumnWidth(),
                  //                    1: FlexColumnWidth(),
                  //                    2: FlexColumnWidth(),
                  //                    3: FlexColumnWidth(),
                  //                  },
                  //                  children: [
                  //                    TableRow(
                  //                      decoration: BoxDecoration(
                  //                        border: Border.all(color: blueColor),
                  //                      ),
                  //                      children: [
                  //                        _buildHeader('Rental Address', 0,
                  //                            (lease) => lease.rentalAddress!),
                  //                        _buildHeader('Tenant Names', 1,
                  //                            (lease) => lease.tenantNames!),
                  //                        _buildHeader('Lease Start', 2,
                  //                            (lease) => lease.createdAt!),
                  //                        _buildHeader('Rent', 3,
                  //                            (lease) => lease.createdAt!),
                  //                        _buildHeader('Lease End', 5,
                  //                            (lease) => lease.endDate!),
                  //                      ],
                  //                    ),
                  //                    TableRow(
                  //                      decoration: BoxDecoration(
                  //                        border: Border.symmetric(
                  //                            horizontal: BorderSide.none),
                  //                      ),
                  //                      children: List.generate(
                  //                          5,
                  //                          (index) => TableCell(
                  //                              child: Container(height: 20))),
                  //                    ),
                  //                    for (var i = 0; i < pagedData.length; i++)
                  //                      TableRow(
                  //                        decoration: BoxDecoration(
                  //                          border: Border(
                  //                            left: BorderSide(color: blueColor),
                  //                            right: BorderSide(color: blueColor),
                  //                            top: BorderSide(color: blueColor),
                  //                            bottom: i == pagedData.length - 1
                  //                                ? BorderSide(color: blueColor)
                  //                                : BorderSide.none,
                  //                          ),
                  //                        ),
                  //                        children: [
                  //                          _buildDataCell(
                  //                              pagedData[i].rentalAddress!),
                  //                          _buildDataCell(
                  //                              pagedData[i].tenantNames!),
                  //                          _buildDataCell(formatCurrency(
                  //                              pagedData[i].amount?.toDouble())),
                  //                          _buildDataCell(
                  //                              pagedData[i].createdAt!),
                  //                          _buildDataCell(pagedData[i].endDate!),
                  //                        ],
                  //                      ),
                  //                  ],
                  //                ),
                  //                SizedBox(height: 25),
                  //                _buildPaginationControls(),
                  //                SizedBox(height: 25),
                  //              ],
                  //            ),
                  //          ),
                  //        );
                  //      },
                  //    ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
