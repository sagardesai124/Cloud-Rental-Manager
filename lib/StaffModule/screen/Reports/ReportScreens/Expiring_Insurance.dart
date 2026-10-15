import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:three_zero_two_property/Model/Expiring_insurance_model.dart';
import 'package:three_zero_two_property/Model/ReportExpiringLease.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/StaffModule/repository/Expiring_insurance.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/staff_report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:shimmer/shimmer.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/repository/ExpiringLeaseTable.dart';
import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';

import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class ExpiringInsurance extends StatefulWidget {
  @override
  _ExpiringInsuranceState createState() => _ExpiringInsuranceState();
}

class _ExpiringInsuranceState extends State<ExpiringInsurance>
    with NetworkRetryState {
  Future<List<RentersInsuranceData>>? _futureReport;

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
    DateTime today = DateTime.now();

    // Calculate one month later dynamically
    DateTime oneMonthLater = DateTime(today.year, today.month + 1, today.day);
    if (oneMonthLater.day != today.day) {
      // Adjust for months with fewer days (e.g., February)
      oneMonthLater = DateTime(oneMonthLater.year, oneMonthLater.month, 0);
    }

    // Format date strings using DateProvider
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    String todayStr = dateProvider.formatCurrentDate(today.toString());
    String oneMonthLaterStr =
        dateProvider.formatCurrentDate(oneMonthLater.toString());

    // Set default values to text controllers
    _fromDateController.text = todayStr;
    _toDateController.text = oneMonthLaterStr;

    // Store last selected dates
    lastFromDate = todayStr;
    lastToDate = oneMonthLaterStr;

    // Default the filter to "Custom Date" (today -> +1 month shown, fields
    // editable). Do NOT auto-load — data loads only when the user taps Run.
    daterange = 'Custom';
    customdate = true;
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
  String? daterange;
  bool customdate = false;
  DateTime? _selectedDate;
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
    if (picked != null) {
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
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        _toDateController.text = dateProvider.formatCurrentDate(apiFormatDate);
      });
    }
  }

  String convertToApiFormat(String dateStr) {
    try {
      final date = DateFormat('dd-MM-yyyy').parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateStr; // Return the original if parsing fails
    }
  }

  /// Web's From/To check (null when the range is fine).
  String? get _dateRangeError =>
      reportDateRangeError(_fromDateController.text, _toDateController.text);

  void _fetchData({bool force = false}) {
    String currentFromDate = _fromDateController.text;
    String currentToDate = _toDateController.text;

    // Check if the current dates are the same as the last selected dates.
    // Run passes force: true so it always re-applies the selected range.
    if (!force && currentFromDate == lastFromDate && currentToDate == lastToDate) {
      // If the dates are the same, do not call the API
      return;
    }

    if (currentFromDate.isNotEmpty && currentToDate.isNotEmpty) {
      // Convert display dates to API format (yyyy-MM-dd)
      String apiFromDate = formatDate(currentFromDate);
      String apiToDate = formatDate(currentToDate);

      _futureReport = ExpiringInsuranceTableService().fetchExpiringInsurnce(
        startDate: apiFromDate,
        endDate: apiToDate,
      );

      // Update the last selected dates
      lastFromDate = currentFromDate;
      lastToDate = currentToDate;
    } else {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Please select both From and To dates.')),
      // );
      // return;
      // Convert display dates to API format (yyyy-MM-dd)
      String apiFromDate = formatDate(currentFromDate);
      String apiToDate = formatDate(currentToDate);

      _futureReport = ExpiringInsuranceTableService().fetchExpiringInsurnce(
        startDate: apiFromDate,
        endDate: apiToDate,
      );
      lastFromDate = currentFromDate;
      lastToDate = currentToDate;
    }
    setState(() {});
  }

  /// The shown From/To date (company date format) as the yyyy-MM-dd the
  /// server reads, like web. Used for Run and the exports.
  String formatDate(String dateStr) => reverseFormatDate(dateStr);

  Future<void> generatePdf(List<RentersInsuranceData> leaseData) async {
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
      pw.Page(
        margin: const pw.EdgeInsets.all(30), // Adjust margin as needed
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 50, height: 50),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Expiring Renter's Insurance",
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
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: [
                  'Insurance\nCompany',
                  'Policy\nID',
                  'Effective\nDate',
                  'Expiration\nDate',
                  'Liability\nCoverage',
                  'Tenants',
                ],
                data: leaseData.map((lease) {
                  return [
                    lease.insuranceCompany ?? '',
                    lease.policyId ?? '',
                    lease.effectiveDate != null
                        ? dateProvider.formatCurrentDate(lease.effectiveDate!)
                        : '',
                    lease.expirationDate != null
                        ? dateProvider.formatCurrentDate(lease.expirationDate!)
                        : '',
                    formatCurrency(lease.liabilityCoverage.toDouble()),
                    lease.tenantDetails != null
                        ? lease.tenantDetails
                            ?.map((tenant) =>
                                "${tenant.tenantFirstName} ${tenant.tenantLastName}")
                            .join(', ')
                        : '',
                  ];
                }).toList(),
                border: pw.TableBorder.all(
                  color: const PdfColor.fromInt(0xFFBDBDBD), // Gray[400] color
                  width: 1,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5A86D5"),
                ),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                    color: PdfColors.white),
                headerAlignment: pw.Alignment.centerLeft,
                cellStyle: const pw.TextStyle(
                  fontSize: 10,
                ),
                cellHeight: 30,
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.5), // Property
                  1: const pw.FlexColumnWidth(0.7), // Unit
                  2: const pw.FixedColumnWidth(90), // Tenant (fixed width)
                  3: const pw.FlexColumnWidth(1), // Rent
                  4: const pw.FlexColumnWidth(1.1), // Non-rent
                  5: const pw.FlexColumnWidth(1.2), // Lease Start
                },
              ),
            ],
          );
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Expiring-Renter-Insurances-Report.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Expiring-Renter-Insurances-Report',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> generateExcel(List<RentersInsuranceData> leaseData) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    // Create a new Excel document.
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    // Adjusting column widths
    sheet.getRangeByName('A1:H1').columnWidth = 20;

    // Adding table headers
    final List<String> headers = [
      'Insurance Company',
      'Policy ID',
      'Company Phone',
      'EffectiveDate',
      'ExpirationDate',
      'LiabilityCoverage',
      'Tenants',
    ];
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#D3D3D3'; // Gray color for header
    headerCellStyle.hAlign =
        syncXlsx.HAlignType.left; // Center alignment for header

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1); // Start at row 6
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    // Adding lease data starting from row 7
    for (int i = 0; i < leaseData.length; i++) {
      final lease = leaseData[i];
      sheet.getRangeByIndex(2 + i, 1).setText(lease.insuranceCompany ?? '');
      sheet.getRangeByIndex(2 + i, 2).setText(lease.policyId ?? '');
      sheet.getRangeByIndex(2 + i, 3).setText(
          formatPhoneNumberedit(lease.insuranceCompanyPhoneNumber ?? ''));
      sheet.getRangeByIndex(2 + i, 4).setText(lease.effectiveDate != null
          ? dateProvider.formatCurrentDate(lease.effectiveDate!)
          : "");
      sheet.getRangeByIndex(2 + i, 5).setText(lease.expirationDate != null
          ? dateProvider.formatCurrentDate(lease.expirationDate!)
          : "");
      sheet
          .getRangeByIndex(2 + i, 6)
          .setText(formatCurrency(lease.liabilityCoverage.toDouble()));
      String? tenantNames = lease.tenantDetails != null
          ? lease.tenantDetails
              ?.map((tenant) =>
                  "${tenant.tenantFirstName} ${tenant.tenantLastName}")
              .join(', ')
          : '';
      sheet.getRangeByIndex(2 + i, 7).setText(tenantNames);
    }

    // Save the document.
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    //  Generate a unique file name
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Renters_insurance_report_$formattedDate.xlsx';

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
    // final DateTime now = DateTime.now();
    // final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    // final String fileName = 'Account_totals_report_$formattedDate.xlsx';
    //
    // final Directory directory = Platform.isIOS
    //     ? await getApplicationDocumentsDirectory()
    //     : Directory('/storage/emulated/0/Download');
    //
    // // Create directory if it doesn't exist (for Android)
    // if (!await directory.exists() && !Platform.isIOS) {
    //   await directory.create(recursive: true);
    // }
    // final path = '${directory.path}/$fileName';
    // final File file = File(path);
    // await file.writeAsBytes(bytes, flush: true);
    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

//Csv Generate method

  Future<void> requestPermissions() async {
    await Permission.storage.request();
  }

  Future<void> generateCsv(List<RentersInsuranceData> leaseData) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    // Request storage permissions
    await requestPermissions();

    // Prepare CSV data
    List<List<dynamic>> rows = [
      [
        'Insurance Company',
        'Policy ID',
        'Company Phone',
        'EffectiveDate',
        'ExpirationDate',
        'LiabilityCoverage',
        'Tenants',
      ]
    ];
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln(rows.first.join(','));
    for (var lease in leaseData) {
      csvBuffer.writeln([
        lease.insuranceCompany ?? '',
        lease.policyId ?? '',
        formatPhoneNumberedit(lease.insuranceCompanyPhoneNumber ?? ''),
        lease.effectiveDate != null
            ? dateProvider.formatCurrentDate(lease.effectiveDate!)
            : '',
        lease.expirationDate != null
            ? dateProvider.formatCurrentDate(lease.expirationDate!)
            : '',
        formatCurrency(lease.liabilityCoverage.toDouble()),
        lease.tenantDetails != null
            ? lease.tenantDetails
                ?.map((tenant) =>
                    "${tenant.tenantFirstName} ${tenant.tenantLastName}")
                .join(', ')
            : '',
      ].join(','));
    }
// Convert buffer to list of bytes for CSV file
    final List<int> bytes = utf8.encode(csvBuffer.toString());
    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Account_totals_report_$formattedDate.csv';

    // Define file path
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    // Write CSV file to the path
    final File file = File(path);

    await file.writeAsBytes(bytes, flush: true);

    //Share.shareXFiles([XFile(path)]);
    // // Convert rows to CSV string
    // String csv = const ListToCsvConverter().convert(rows);
    //
    // // Generate a unique file name
    // final DateTime now = DateTime.now();
    // final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    // final String fileName = 'Renters_insurance_report_$formattedDate.csv';
    //
    // // Get the directory to save the file.
    // final Directory directory = Platform.isIOS
    //     ? await getApplicationDocumentsDirectory()
    //     : Directory('/storage/emulated/0/Download');
    //
    // final path = '${directory.path}/$fileName';
    //
    // // Create directory if it doesn't exist (for Android)
    // if (!await directory.exists() && !Platform.isIOS) {
    //   await directory.create(recursive: true);
    // }
    //
    // // Save the file
    // final File file = File(path);
    // await file.writeAsString(csv, flush: true);
    // Share.shareXFiles([XFile(path)]);
    // // Show a message with the file path
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  // void sortData(List<RentersInsuranceData> data) {
  //   if (sorting1) {
  //     data.sort((a, b) => ascending1
  //         ? a.rentalAddress!.compareTo(b.rentalAddress!)
  //         : b.rentalAddress!.compareTo(a.rentalAddress!));
  //   } else if (sorting2) {
  //     data.sort((a, b) => ascending2
  //         ? a.tenantNames!.compareTo(b.tenantNames!)
  //         : b.tenantNames!.compareTo(a.tenantNames!));
  //   } else if (sorting3) {
  //     data.sort((a, b) => ascending3
  //         ? a.status!.compareTo(b.status!)
  //         : b.status!.compareTo(a.status!));
  //   }
  // }

  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;
  // Column widths shared by the header and every row so they line up.
  static const int _companyFlex = 1;
  static const int _dateFlex = 1;
  static const double _chevronWidth = 24;

  Widget _headerCell(String text, int flex, VoidCallback onTap) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: TextStyle(
            color: blueColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  /// The app's round page arrow: grey when it can't be used, navy when it can.
  Widget _pageButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FaIcon(
          icon,
          size: 26,
          color: onTap == null ? const Color(0xFF9E9E9E) : blueColor,
        ),
      ),
    );
  }



  Widget _buildHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(width: _chevronWidth),
          _headerCell("Insurance\nCompany", _companyFlex, () {
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
            });
          }),
          _headerCell("Effective\nDate", _dateFlex, () {
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
            });
          }),
          _headerCell("Expiration\nDate", _dateFlex, () {
            setState(() {
              if (sorting3) {
                sorting1 = false;
                sorting2 = false;
                sorting3 = sorting3;
                ascending3 = sorting3 ? !ascending3 : true;
                ascending2 = false;
                ascending1 = false;
              } else {
                sorting1 = false;
                sorting2 = false;
                sorting3 = !sorting3;
                ascending3 = sorting3 ? !ascending3 : true;
                ascending2 = false;
                ascending1 = false;
              }
            });
          }),
        ],
      ),
    );
  }

  /// Loading placeholder in the same layout as the table: the real header,
  /// then rounded rows with soft grey bars, at the same edges as the filters.
  Widget _loadingTable() {
    Widget bar(double widthFactor) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildHeaders(),
        const SizedBox(height: 6),
        Shimmer.fromColors(
          baseColor: const Color(0xFFE3E7ED),
          highlightColor: const Color(0xFFF4F6F9),
          child: Column(
            children: List.generate(5, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: _chevronWidth),
                    Expanded(flex: _companyFlex, child: bar(0.7)),
                    Expanded(flex: _dateFlex, child: bar(0.75)),
                    Expanded(flex: _dateFlex, child: bar(0.75)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  String searchvalue = "";
  String? selectedValue;

  List<RentersInsuranceData> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<RentersInsuranceData> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
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
      Comparable<T> Function(RentersInsuranceData d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField!, columnIndex, !_sortAscending);
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

  void _sort<T>(Comparable<T> Function(RentersInsuranceData d) getField,
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
              borderRadius: BorderRadius.circular(4.0),
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
      appBar: widget_302_Staff.App_Bar(context: context),
      drawer: CustomDrawerStaff(
        currentpage: "Reports",
        dropdown: false,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  StaffReportHeader(
                    title: "Expiring Renter's Insurance",
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15.0, 4.0, 15.0, 15.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Range Dropdown
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                                  child: Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCED4DA))),
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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
                                              fontWeight: FontWeight.w400,
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

                                          // Date range selection only sets the
                                          // From/To fields. Data loads only when
                                          // the user taps Run (web parity).
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 46,
                                        padding: const EdgeInsets.only(
                                            left: 0, right: 4),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          color: Colors.white,
                                        ),
                                        elevation: 0,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        maxHeight: 250,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        offset: const Offset(0, 0),
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
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // From Date and To Date fields with theme
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFCED4DA),
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
                                                  vertical: 11, horizontal: 14),
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
                                    height: 48,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFCED4DA),
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
                                                  vertical: 11, horizontal: 14),
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
                          const SizedBox(height: 12),
                          // Run + Export buttons — web parity (side by side,
                          // next to the Date Range / From / To filters).
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      onPressed: _dateRangeError == null
                                          ? () => _fetchData(force: true)
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: blueColor,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            blueColor.withOpacity(0.6),
                                        disabledForegroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text('Run'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: PopupMenuButton<String>(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'PDF') {
                                          final data =
                                              await ExpiringInsuranceTableService()
                                                  .fetchExpiringInsurnce(
                                            startDate: formatDate(
                                                _fromDateController.text),
                                            endDate: formatDate(
                                                _toDateController.text),
                                          );
                                          await generatePdf(data);
                                        } else if (value == 'XLSX') {
                                          final data =
                                              await ExpiringInsuranceTableService()
                                                  .fetchExpiringInsurnce(
                                            startDate: formatDate(
                                                _fromDateController.text),
                                            endDate: formatDate(
                                                _toDateController.text),
                                          );
                                          await generateExcel(data);
                                        } else if (value == 'CSV') {
                                          final data =
                                              await ExpiringInsuranceTableService()
                                                  .fetchExpiringInsurnce(
                                            startDate: formatDate(
                                                _fromDateController.text),
                                            endDate: formatDate(
                                                _toDateController.text),
                                          );
                                          await generateCsv(data);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'PDF',
                                          child: Text('PDF'),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'XLSX',
                                          child: Text('XLSX'),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'CSV',
                                          child: Text('CSV'),
                                        ),
                                      ],
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: blueColor,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text('Export',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                            Icon(Icons.arrow_drop_down,
                                                color: Colors.white),
                                          ],
                                        ),
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
                  if (MediaQuery.of(context).size.width < 500)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                      ),
                      child: FutureBuilder<List<RentersInsuranceData>>(
                        future: _futureReport,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _loadingTable();
                          } else if (snapshot.hasError) {
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
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "No expiring insurance found",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 16),
                                    )
                                  ],
                                ),
                              ),
                            );
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
                                    const SizedBox(
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
                                    lease.insuranceCompany
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    lease.policyId
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    lease.expirationDate
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    lease.effectiveDate
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    lease.liabilityCoverage
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()))
                                .toList();
                          } else {
                            data = snapshot.data!
                                .where((lease) =>
                                    lease.insuranceCompany == selectedValue)
                                .toList();
                          }

                          // Sort data if necessary
                          //sortData(data);

                          // Pagination logic
                          final totalPages =
                              (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                          final currentPageData = data
                              .skip(currentPage * itemsPerPage)
                              .take(itemsPerPage)
                              .toList();

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 6),
                                _buildHeaders(),
                                const SizedBox(height: 10),
                                Container(
                                  child: Column(
                                    children: currentPageData.isEmpty
                                        ? [kNoSearchResults(context)]
                                        : currentPageData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int index = entry.key;
                                      bool isExpanded = expandedIndex == index;
                                      RentersInsuranceData lease = entry.value;

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
                                            InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              onTap: () {
                                                setState(() {
                                                  expandedIndex =
                                                      expandedIndex == index
                                                          ? null
                                                          : index;
                                                });
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 12,
                                                    vertical: 16),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .center,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width: _chevronWidth,
                                                      child: Align(
                                                        alignment: Alignment
                                                            .centerLeft,
                                                        child: Icon(
                                                          isExpanded
                                                              ? Icons
                                                                  .arrow_drop_up
                                                              : Icons
                                                                  .arrow_drop_down,
                                                          size: 24,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: _companyFlex,
                                                      child: Text(
                                                        '${lease.insuranceCompany ?? 'N/A'}',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: _dateFlex,
                                                      child: Text(
                                                        lease.effectiveDate
                                                                    ?.isNotEmpty ==
                                                                true
                                                            ? dateProvider
                                                                .formatCurrentDate(
                                                                    '${lease?.effectiveDate?.split('T').first}')
                                                            : 'N/A',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: _dateFlex,
                                                      child: Text(
                                                        lease.expirationDate
                                                                    ?.isNotEmpty ==
                                                                true
                                                            ? dateProvider
                                                                .formatCurrentDate(
                                                                    '${lease?.expirationDate?.split('T').first}')
                                                            : 'N/A',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isExpanded)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 12 + _chevronWidth,
                                                    right: 12,
                                                    bottom: 16),
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text.rich(
                                                    TextSpan(
                                                      children: [
                                                        TextSpan(
                                                          text: 'Tenants : ',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  blueColor),
                                                        ),
                                                        TextSpan(
                                                          text: lease.tenantDetails !=
                                                                      null &&
                                                                  lease
                                                                      .tenantDetails!
                                                                      .isNotEmpty
                                                              ? lease
                                                                  .tenantDetails!
                                                                  .map((tenant) =>
                                                                      '${tenant.tenantFirstName ?? '-'} ${tenant.tenantLastName ?? '-'}')
                                                                  .join(', ')
                                                              : 'N/A',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: grey),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 20, bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        height: 42,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: const Color(0xFFDBE0E5)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: itemsPerPage,
                                            icon: Icon(Icons.arrow_drop_down,
                                                color: blueColor),
                                            style: TextStyle(
                                                color: blueColor,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
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
                                                currentPage = 0;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      _pageButton(
                                        FontAwesomeIcons.circleChevronLeft,
                                        currentPage == 0
                                            ? null
                                            : () => setState(() {
                                                  currentPage--;
                                                }),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Text(
                                          'Page ${currentPage + 1} of $totalPages',
                                          style: TextStyle(
                                              color: blueColor,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      _pageButton(
                                        FontAwesomeIcons.circleChevronRight,
                                        currentPage < totalPages - 1
                                            ? () => setState(() {
                                                  currentPage++;
                                                })
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(
                      height: 8,
                    ),
                  if (MediaQuery.of(context).size.width > 500)
                    Expanded(
                        flex: 0,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 32.0, right: 32.0, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Material(
                                elevation: 3,
                                borderRadius: BorderRadius.circular(2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  // height: 40,
                                  height:
                                      MediaQuery.of(context).size.width < 500
                                          ? 40
                                          : 50,
                                  width: MediaQuery.of(context).size.width < 500
                                      ? MediaQuery.of(context).size.width * .45
                                      : MediaQuery.of(context).size.width * .4,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                        color: const Color(0xFF8A95A8)),
                                  ),
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        searchvalue = value;
                                        currentPage = 0; // reset to first page on search change
                                      });
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Search here...",
                                      hintStyle:
                                          TextStyle(color: Color(0xFF8A95A8)),
                                      contentPadding: EdgeInsets.all(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(
                      height: 18,
                    ),
                  if (MediaQuery.of(context).size.width > 500)
                    FutureBuilder<List<RentersInsuranceData>>(
                      future: _futureReport,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ShimmerTabletTable();
                        } else if (snapshot.hasError) {
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
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    "No expiring insurance found",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize: 16),
                                  )
                                ],
                              ),
                            ),
                          );
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
                                  const SizedBox(
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
                                  lease.insuranceCompany
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.policyId
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.expirationDate
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.effectiveDate
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  lease.liabilityCoverage
                                      .toString()
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()))
                              .toList();
                        } else {
                          data = snapshot.data!
                              .where((lease) =>
                                  lease.insuranceCompany == selectedValue)
                              .toList();
                        }

                        // Apply pagination
                        final int itemsPerPage = 10;
                        final int totalPages =
                            (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                        final int currentPage =
                            1; // Update this with your pagination logic
                        final List<RentersInsuranceData> pagedData = data
                            .skip((currentPage - 1) * itemsPerPage)
                            .take(itemsPerPage)
                            .toList();

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.95,
                            child: Column(
                              children: [
                                Table(
                                  defaultColumnWidth:
                                      const IntrinsicColumnWidth(),
                                  columnWidths: {
                                    0: const FlexColumnWidth(),
                                    1: const FlexColumnWidth(),
                                    2: const FlexColumnWidth(),
                                    3: const FlexColumnWidth(),
                                  },
                                  children: [
                                    TableRow(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: blueColor),
                                      ),
                                      children: [
                                        _buildHeader(
                                            'InsuranceCompany',
                                            0,
                                            (lease) =>
                                                lease.insuranceCompany ?? ""),
                                        _buildHeader(
                                            'Effective Date',
                                            1,
                                            (lease) =>
                                                lease.effectiveDate ?? ""),
                                        _buildHeader(
                                            'Expiration Date',
                                            2,
                                            (lease) =>
                                                lease.expirationDate ?? ""),
                                        _buildHeader(
                                            'Tenants',
                                            3,
                                            (lease) => lease.liabilityCoverage
                                                .toString()),
                                      ],
                                    ),
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border.symmetric(
                                            horizontal: BorderSide.none),
                                      ),
                                      children: List.generate(
                                          5,
                                          (index) => TableCell(
                                              child: Container(height: 20))),
                                    ),
                                    for (var i = 0; i < pagedData.length; i++)
                                      TableRow(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(color: blueColor),
                                            right: BorderSide(color: blueColor),
                                            top: BorderSide(color: blueColor),
                                            bottom: i == pagedData.length - 1
                                                ? BorderSide(color: blueColor)
                                                : BorderSide.none,
                                          ),
                                        ),
                                        children: [
                                          _buildDataCell(
                                              pagedData[i].insuranceCompany!),
                                          _buildDataCell(
                                              pagedData[i].effectiveDate!),
                                          _buildDataCell(
                                              formatMoney(pagedData[i].expirationDate!)),
                                          _buildDataCell(pagedData[i]
                                              .liabilityCoverage
                                              .toString()),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 25),
                                _buildPaginationControls(),
                                const SizedBox(height: 25),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
