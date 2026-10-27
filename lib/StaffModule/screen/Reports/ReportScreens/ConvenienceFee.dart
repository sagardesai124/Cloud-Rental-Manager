import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import 'package:flutter/cupertino.dart';

import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:three_zero_two_property/Model/DelinquentTenantsModel.dart';

import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/StaffModule/repository/ConvenienceFeeRepo.dart';
import 'package:three_zero_two_property/StaffModule/widgets/staff_report_header.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import 'package:three_zero_two_property/provider/dateProvider.dart';

import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';

import 'package:three_zero_two_property/repository/payment_Exception.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';

import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';

import '../../../../Model/ConvenienceFeeModel.dart';

import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class ConvenienceFeeReports extends StatefulWidget {
  const ConvenienceFeeReports({super.key});

  @override
  State<ConvenienceFeeReports> createState() => _ConvenienceFeeReportsState();
}

class _ConvenienceFeeReportsState extends State<ConvenienceFeeReports>
    with NetworkRetryState {
  late Future<List<Data>> _futureConvenienceFee;
  List<Data> DelinquentTenantsModel = [];
  bool isLoading = true;
  String? errorMessage;
  int? expandedRowIndex;
  Map<int, int?> expandedTenantIndex = {};
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    fromDate.dispose();
    toDate.dispose();
    super.dispose();
  }
  /// Required by [NetworkRetryState]: re-issue this report's own load.
  /// Lifted from the hand-written Retry this replaces, so it fetches
  /// exactly what that button already fetched.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    _retryFetch();
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

  void fetchReport() {
    setState(() {
      daterange = "Custom";
      customdate = true;
      fromDate.text = "";
      toDate.text = "";
      // fromDate.text = formatDate(DateTime.now().toString());
      // toDate.text = formatDate(DateTime.now().toString());
    });

    // Get the current date
    DateTime now = DateTime.now();

    // Set the fromDate and toDate for "Today"
    DateTime from = DateTime(now.year, now.month, now.day);
    DateTime to =
        DateTime(now.year, now.month, now.day, 23, 59, 59); // End of the day
    if (daterange == "Custom" && fromDate.text.isEmpty && toDate.text.isEmpty) {
      // Fetch all data logic here
      _futureConvenienceFee =
          fetchConvenienceFeeReportsData(); // Adjust this method to fetch all data
    }
    // Call the fetch method with the date range
    //_futureConvenienceFee = fetchPaymentExceptionReportsData(fromDate: from, toDate: to);
  }

  DateTime? parseDate(String dateString) {
    // Try parsing with the expected format
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      // If it fails, try parsing with the alternative format
      try {
        return DateFormat('dd-MM-yyyy').parse(dateString);
      } catch (e) {
        logError('Error parsing date: $dateString');
        return null; // Return null if parsing fails
      }
    }
  }

  Future<List<Data>> fetchConvenienceFeeReportsData(
      {DateTime? fromDate, DateTime? toDate}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      List<Data> data =
          await ConvenienceFeeReportsServices().fetchConvenienceFeeReports();

      // Filter data based on the provided date range
      // if (fromDate != null && toDate != null) {
      //   data = data.where((item) {
      //     DateTime? itemDate = parseDate(item.entry?.first.date ?? ""); // Use the new parseDate function
      //     if (itemDate == null) {
      //       return false; // Exclude this item if the date could not be parsed
      //     }
      //     return itemDate.isAfter(fromDate.subtract(Duration(days: 1))) && itemDate.isBefore(toDate.add(Duration(days: 1)));
      //   }).toList();
      // }

      setState(() {
        DelinquentTenantsModel = data;
        isLoading = false;
        errorMessage = null; // Reset error message on successful data fetch
      });
      return data;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = friendlyErrorMessage(e,
            fallbackMessage:
                'Failed to load convenience fee data. Please try again later.');
      });
      // Rethrow so the FutureBuilder reports hasError: a failed fetch must not
      // be presented as a report that legitimately has no rows.
      rethrow;
    }
  }

  // A fetch failure is not an empty report: show why it failed and offer a
  // retry, instead of leaving "No Data Available" on screen.
  Widget _reportErrorState({required VoidCallback onRetry}) {
    return Container(
      height: MediaQuery.of(context).size.height * .5,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: blueColor),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                errorMessage ?? 'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                    fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
              label: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _retryFetch() {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _futureConvenienceFee = fetchConvenienceFeeReportsData();
    });
  }

  double grandtotal = 0.0;
  List<DelinquentTenantsData> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String searchvalue = "";
  String? selectedValue;

  int totalrecords = 0;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [10, 25, 50, 100];

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0; // Reset to the first page when changing rows per page
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

  // Widget _buildHeader<T>(String text, int columnIndex,
  //     Comparable<T> Function(DelinquentTenantsData d)? getField) {
  //   return TableCell(
  //     child: GestureDetector(
  //       onTap: getField != null
  //           ? () {
  //         _sort(getField, columnIndex, !_sortAscending);
  //       }
  //           : null,
  //       child: Padding(
  //         padding: const EdgeInsets.all(18.0),
  //         child: Row(
  //           children: [
  //             Text(text,
  //                 style: const TextStyle(
  //                     fontWeight: FontWeight.bold, fontSize: 18)),
  //             if (_sortColumnIndex == columnIndex)
  //               Icon(_sortAscending
  //                   ? Icons.arrow_drop_down_outlined
  //                   : Icons.arrow_drop_up_outlined),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // void _sort<T>(Comparable<T> Function(DelinquentTenantsData d) getField,
  //     int columnIndex, bool ascending) {
  //   setState(() {
  //     _sortColumnIndex = columnIndex;
  //     _sortAscending = ascending;
  //     _tableData.sort((a, b) {
  //       final aValue = getField(a);
  //       final bValue = getField(b);
  //       final result = aValue.compareTo(bValue as T);
  //       return _sortAscending ? result : -result;
  //     });
  //   });
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

  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
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
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              child: GestureDetector(
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
                child: Padding(
                  padding: const EdgeInsets.only(left: 0),
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
                      const SizedBox(width: 3),
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
            ),
            Expanded(
              child: GestureDetector(
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
                    SizedBox(width: 22),
                    width < 400
                        ? Text("Lease\nEndDate",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15))
                        : Text("Lease\nEndDate",
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
            Expanded(
              child: GestureDetector(
                onTap: () {
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

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    SizedBox(width: 25),
                    Text("Tenant",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(width: 5),
                    ascending3
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
    );
  }

  PdfDelinquentTenantsData? globalDelinquentTenantsData;
  Future<PdfDelinquentTenantsData?> fetchDelinquentTenantsGrandTotal() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');

    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/charge/delinquent/$adminId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? adminId}",
      });

      if (response.statusCode == 200) {
        final parsedJson = jsonDecode(response.body);
        if (parsedJson['grandtotal'] != null) {
          globalDelinquentTenantsData =
              PdfDelinquentTenantsData.fromJson(parsedJson['grandtotal']);
          return globalDelinquentTenantsData;
        } else {
          throw Exception('Grand total data is not available');
        }
      } else {
        throw Exception('Failed to load delinquent tenants');
      }
    } catch (e) {
      logError('Error fetching data: $e');
      return null;
    }
  }

  bool istenantDataLoading = false;
  bool customdate = false;

//for pdf
  Future<void> generateAccountTotalReportPdf(
      List<Data> delinquentTenantsData, DateProvider dateProvider) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      // Handle error
      logError("Error fetching profile data: $e");
      return;
    }
    setState(() {
      istenantDataLoading = true;
    });
    await fetchDelinquentTenantsGrandTotal();
    setState(() {
      istenantDataLoading = false;
    });
    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());

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
              style: const pw.TextStyle(color: PdfColors.grey),
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
                    'Convenience Fee Override',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
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
                  'Lease End Date',
                  'Tenant',
                  'Override Percentage',
                ],
                data: _generateTableData(delinquentTenantsData, dateProvider),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5A86D5"),
                  //color:PdfColor.fromRYB(90, 134, 213,)
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                border: null),
            // pw.Divider(thickness: 3),
            // pw.Padding(
            //     padding: pw.EdgeInsets.symmetric(horizontal: 5),
            //     child: pw.Row(
            //         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            //         children: [
            //           pw.Text('Grand Total',
            //               style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            //           pw.Text(formatCurrency(grandtotal),
            //               style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
            //         ])),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Convenience_fee_override.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Convenience_fee_override',
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> generateAccountTotalReportExcel(
      List<Data> rentalOwnerReports, DateProvider dateProvider) async {
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    List<String> headerData = [];

    // Set column widths
    sheet.getRangeByName('A1:ZZ1').columnWidth = 20;

    final List<String> headers = [
      'Property',
      'Lease End Date',
      'Tenant',
      'Override Percentage',
    ];

    // Header cell style
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#5A86D5';
    headerCellStyle.fontColor = '#FFFFFF';
    headerCellStyle.fontSize = 16;
    headerCellStyle.hAlign = syncXlsx.HAlignType.center;

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    // Currency cell style
    final syncXlsx.Style currencyCellStyle =
        workbook.styles.add('currencyCellStyle');
    currencyCellStyle.numberFormat = '\$#,##0.00'; // Currency format
    currencyCellStyle.hAlign = syncXlsx.HAlignType.right; // Right-align amounts

    // Bold amount style
    final syncXlsx.Style boldAmountStyle =
        workbook.styles.add('boldAmountStyle');
    boldAmountStyle.bold = true;
    boldAmountStyle.numberFormat = '\$#,##0.00';
    boldAmountStyle.hAlign = syncXlsx.HAlignType.right;

    // Set headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    int rowIndex = 2;
    double grandTotal = 0.0;

    final syncXlsx.Style rightAlignedTextStyle =
        workbook.styles.add('rightAlignedTextStyle');
    rightAlignedTextStyle.hAlign = syncXlsx.HAlignType.right;

    for (int i = 0; i < rentalOwnerReports.length; i++) {
      final workOrder = rentalOwnerReports[i];

      sheet.getRangeByIndex(2 + i, 1).setText(
          '${workOrder.rentalData?.rentalAddress ?? '-'}${(workOrder.rentalData?.rentalAddress != null && workOrder.unitData?.rentalUnit != null) ? ' - ' : ''}${workOrder.unitData?.rentalUnit ?? ''}');
      sheet.getRangeByIndex(2 + i, 2).setText(
          dateProvider.formatCurrentDate(formatDate(workOrder.endDate ?? "")));
      // sheet.getRangeByIndex(2 + i, 3).setText('${workOrder.tenantData!.first.tenantFirstName}''${workOrder.tenantData!.first.tenantLastName}');
      String tenantInfo = '';
      if (workOrder.tenantData != null && workOrder.tenantData!.isNotEmpty) {
        for (var tenant in workOrder.tenantData!) {
          tenantInfo += '${tenant.tenantFirstName} ${tenant.tenantLastName} , ';
        }
        // Remove the trailing comma and space
        tenantInfo = tenantInfo.substring(0, tenantInfo.length - 2);
      } else {
        tenantInfo = 'N/A';
      }

// Set tenant info
      sheet.getRangeByIndex(rowIndex + i, 3).setText(tenantInfo);
      String overrideFee = '';
      if (workOrder.tenantData != null && workOrder.tenantData!.isNotEmpty) {
        overrideFee = workOrder.tenantData!
            .map((tenant) => '${tenant.overrideFee}%')
            .join(', ');
      } else {
        overrideFee = 'N/A';
      }
      sheet.getRangeByIndex(rowIndex + i, 4).setText(overrideFee);
      sheet.getRangeByIndex(rowIndex + i, 4).cellStyle =
          rightAlignedTextStyle; // Apply right alignment style

      sheet.getRangeByIndex(2 + i, 4).cellStyle = rightAlignedTextStyle;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Convenience_fee_override_$formattedDate.xlsx';

    final Directory directory = await getApplicationDocumentsDirectory();

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }
    final path = '${directory.path}/$fileName';
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(path)]);
    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

  Future<void> generateAccountTotalReportCsv(
      List<Data> rentalOwnerReports, DateProvider dateProvider) async {
    final List<List<String>> rows = [];

    // Define headers for CSV
    final List<String> headers = [
      'Property',
      'Lease End Date',
      'Tenant',
      'Override Percentage',
    ];

    rows.add(headers);

    for (final workOrder in rentalOwnerReports) {
      // Check if tenantData is not empty
      if (workOrder.tenantData != null && workOrder.tenantData!.isNotEmpty) {
        // Get property and lease end date
        final String property =
            '${workOrder.rentalData?.rentalAddress ?? '-'}${(workOrder.rentalData?.rentalAddress != null && workOrder.unitData?.rentalUnit != null) ? ' - ' : ''}${workOrder.unitData?.rentalUnit ?? ''}';
        final String leaseEndDate =
            dateProvider.formatCurrentDate(formatDate(workOrder.endDate ?? ""));

        // Iterate through each tenant
        for (int i = 0; i < workOrder.tenantData!.length; i++) {
          final tenant = workOrder.tenantData![i];
          final List<String> row = []; // Stores data for a single row

          // Add property and lease end date only for the first tenant
          if (i == 0) {
            row.add(property); // Add property
            row.add(leaseEndDate); // Add lease end date
          } else {
            row.add(''); // Leave property blank for subsequent tenants
            row.add(''); // Leave lease end date blank for subsequent tenants
          }

          // Add tenant's full name
          row.add('${tenant.tenantFirstName} ${tenant.tenantLastName}');

          // Add override fee
          row.add('${tenant.overrideFee ?? 'N/A'}%');

          // Add the row to the rows list
          rows.add(row);
        }
      } else {
        // If there are no tenants, add a row with N/A for tenant and override percentage
        final List<String> row = [
          '${workOrder.rentalData?.rentalAddress ?? '-'}${(workOrder.rentalData?.rentalAddress != null && workOrder.unitData?.rentalUnit != null) ? ' - ' : ''}${workOrder.unitData?.rentalUnit ?? ''}',
          dateProvider.formatCurrentDate(formatDate(workOrder.endDate ?? "")),
          'N/A',
          'N/A',
        ];
        rows.add(row);
      }
    }

    // Create a buffer to store CSV data
    final StringBuffer csvBuffer = StringBuffer();

    // Add headers to the CSV file
    for (final row in rows) {
      csvBuffer.writeln(
          row.map((item) => '"$item"').join(',')); // Wrap each item in quotes
    }

    // Convert buffer to list of bytes for CSV file
    final List<int> bytes = utf8.encode(csvBuffer.toString());

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Convenience_fee_override_$formattedDate.csv';

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
    Share.shareXFiles([XFile(path)]);
    // Show success toast message
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  // List<List<dynamic>> _generateTableData(
  //     List<Data> rentalOwnerReports) {
  //   final List<List<dynamic>> tableData = [];
  //   double total = 0.0;
  //
  //   for (var owner in rentalOwnerReports) {
  //     // Main row for the rental owner name
  //     tableData.add([
  //       pw.Text('${owner.rentalData?.rentalAddress ?? '-'}${(owner.rentalData?.rentalAddress != null && owner.unitData?.rentalUnit != null) ? ' - ' : ''}${owner.unitData?.rentalUnit ?? ''}',
  //           style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
  //       pw.Text(formatDate(owner.endDate ?? ""),
  //           style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
  //       pw.Text('${owner.tenantData!.first.tenantFirstName}''${owner.tenantData!.first.tenantLastName}' ,
  //           style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
  //       pw.Text(' ${owner.tenantData?.isNotEmpty == true ? owner.tenantData?.first.overrideFee : 'N/A'} \%',
  //           style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
  //
  //     ]);
  //
  //
  //
  //
  //
  //   }
  //
  //   setState(() {
  //     grandtotal = total;
  //   });
  //
  //   return tableData;
  // }
  List<List<dynamic>> _generateTableData(
      List<Data> rentalOwnerReports, DateProvider dateProvider) {
    final List<List<dynamic>> tableData = [];
    double total = 0.0;

    for (var owner in rentalOwnerReports) {
      // Get property and lease end date
      final String property =
          '${owner.rentalData?.rentalAddress ?? '-'}${(owner.rentalData?.rentalAddress != null && owner.unitData?.rentalUnit != null) ? ' - ' : ''}${owner.unitData?.rentalUnit ?? ''}';
      final String leaseEndDate =
          dateProvider.formatCurrentDate(formatDate(owner.endDate ?? ""));

      // Check if tenantData is not empty
      if (owner.tenantData != null && owner.tenantData!.isNotEmpty) {
        // Add the main row for the rental owner with property and lease end date
        tableData.add([
          pw.Text(property,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(leaseEndDate,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(
              '${owner.tenantData!.first.tenantFirstName} ${owner.tenantData!.first.tenantLastName}',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text('${owner.tenantData!.first.overrideFee ?? 'N/A'}%',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ]);

        // Iterate through each tenant and add their details
        for (int i = 1; i < owner.tenantData!.length; i++) {
          final tenant = owner.tenantData![i];
          tableData.add([
            pw.Text('',
                style:
                    const pw.TextStyle(fontSize: 10)), // Leave property blank
            pw.Text('',
                style: const pw.TextStyle(
                    fontSize: 10)), // Leave lease end date blank
            pw.Text('${tenant.tenantFirstName} ${tenant.tenantLastName}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('${tenant.overrideFee ?? 'N/A'}%',
                style: const pw.TextStyle(fontSize: 10)),
          ]);
        }
      } else {
        // If there are no tenants, add a row with N/A for tenant and override percentage
        tableData.add([
          pw.Text(property,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(leaseEndDate,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text('N/A', style: const pw.TextStyle(fontSize: 10)),
          pw.Text('N/A', style: const pw.TextStyle(fontSize: 10)),
        ]);
      }
    }

    setState(() {
      grandtotal = total;
    });

    return tableData;
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime? _selectedDate;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor,
            colorScheme: ColorScheme.light(
              primary: blueColor,
            ),
            buttonTheme: const ButtonThemeData(
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

        // Update the fromDate text field
        fromDate.text = DateFormat('yyyy-MM-dd').format(picked);
        // Assuming you want to set the toDate to the same day for now
        toDate.text = DateFormat('yyyy-MM-dd').format(picked);

        // Call fetchConvenienceFeeReportsData with the selected date
        _futureConvenienceFee = fetchConvenienceFeeReportsData(
          fromDate: picked,
          toDate: picked, // You can adjust this as needed
        );
      });
    }
  }

  Future<void> _endDate(BuildContext context) async {
    DateTime? _selectedDate;
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor,
            colorScheme: ColorScheme.light(
              primary: blueColor,
            ),
            buttonTheme: const ButtonThemeData(
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

        // Update the toDate text field
        toDate.text = DateFormat('yyyy-MM-dd').format(picked);

        // Call fetchConvenienceFeeReportsData with both fromDate and toDate
        _futureConvenienceFee = fetchConvenienceFeeReportsData(
          fromDate:
              DateTime.parse(fromDate.text), // Assuming fromDate is already set
          toDate: picked, // Use the selected end date
        );
      });
    }
  }

  List<Map<String, dynamic>> rentalowners = [];
  Future<void> fetchRentalOwners() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('${Api_url}/api/rentals/rental-owners/$id'), headers: {
      "authorization": "CRM $token",
      "id": "CRM ${prefs.getString('staff_id') ?? id}",
    });
    final jsonData = json.decode(response.body);
    if (response.statusCode == 200) {
      // setState(() {
      //   rentalowners = (jsonDecode(response.body) as List)
      //       .map((e) => e as Map<String, dynamic>)!
      //       .toList();
      // });

      final List<dynamic> jsonData = jsonDecode(response.body);
      setState(() {
        rentalowners = jsonData.map((e) {
          return {
            'rentalowner_id':
                e['rentalowner_id'] ?? '', // Default value for null
            'rentalOwner_name':
                e['rentalOwner_name'] ?? 'Unknown', // Default value for null
          } as Map<String, dynamic>;
        }).toList();
      });
      log(' rentalowners ${rentalowners.toString()}');
    } else {
      throw Exception('Failed to load data');
    }
  }

  TextEditingController fromDate = TextEditingController();
  TextEditingController toDate = TextEditingController();
  String? daterange;
  String? chargeType;
  String? selectedrenatalownerid;

  List<Data> filteredData = [];
  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      drawer: CustomDrawerStaff(
        currentpage: "Report",
        dropdown: false,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  StaffReportHeader(
                    title: 'Convenience Fee Override',
                  ),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(height: 16),
                  if (MediaQuery.of(context).size.width < 500)
                    FutureBuilder<List<Data>>(
                      future: _futureConvenienceFee,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                filters(),
                                const SizedBox(
                                  height: 10,
                                ),
                                ColabShimmerLoadingWidget(),
                              ],
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                filters(),
                                _reportErrorState(onRetry: _retryFetch),
                              ],
                            ),
                          );
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                filters(),
                                Container(
                                  height:
                                      MediaQuery.of(context).size.height * .5,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          "assets/images/no_data_transparent.png",
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
                                ),
                              ],
                            ),
                          );
                        }

                        var data = snapshot.data!;
                        if (selectedValue == null && searchvalue.isEmpty) {
                          data = snapshot.data!;
                        } else if (selectedValue == "All") {
                          data = snapshot.data!;
                        } else if (searchvalue.isNotEmpty) {
                          data = snapshot.data!
                              .where((lease) =>
                                  (lease.rentalData!.rentalAddress ?? '')
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  (lease.tenantData!.first.tenantFirstName ?? '')
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()) ||
                                  (lease.tenantData!.first.tenantLastName ?? '')
                                      .toLowerCase()
                                      .contains(searchvalue.toLowerCase()))
                              .toList();
                        } else {
                          data = snapshot.data!
                              .where((lease) =>
                                  lease.tenantData!.first.tenantFirstName ==
                                  selectedValue)
                              .toList();
                        }

                        // Pagination logic
                        final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                        final currentPageData = data
                            .skip(currentPage * itemsPerPage)
                            .take(itemsPerPage)
                            .toList();

                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 5),
                            child: Column(
                              children: [
                                const SizedBox(
                                  height: 5,
                                ),
                                filters(data: data),
                                const SizedBox(height: 10),
                                _buildHeaders(),
                                const SizedBox(height: 10),
                                // if (snapshot.data?.first.tenantData != null && snapshot.data!.first.tenantData!.isNotEmpty)
                                Container(
                                  child: Column(
                                    children: currentPageData.isEmpty
                                        ? [kNoSearchResults(context)]
                                        : currentPageData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int rowIndex = entry.key;
                                      var item = entry.value;
                                      bool isRowExpanded =
                                          expandedRowIndex == rowIndex;
                                      Data rental = entry.value;
                                      return Container(
                                        // decoration: BoxDecoration(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: rowIndex % 2 != 0
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
                                                    GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          if (expandedRowIndex ==
                                                              rowIndex) {
                                                            expandedRowIndex =
                                                                null;
                                                          } else {
                                                            expandedRowIndex =
                                                                rowIndex;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 5, right: 5),
                                                        padding: !isRowExpanded
                                                            ? const EdgeInsets
                                                                .only(
                                                                bottom: 10)
                                                            : const EdgeInsets
                                                                .only(top: 10),
                                                        child: FaIcon(
                                                          isRowExpanded
                                                              ? FontAwesomeIcons
                                                                  .sortUp
                                                              : FontAwesomeIcons
                                                                  .sortDown,
                                                          size: 20,
                                                          color: isRowExpanded
                                                              ? blueColor
                                                              : blueColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 4,
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            if (expandedRowIndex ==
                                                                rowIndex) {
                                                              expandedRowIndex =
                                                                  null;
                                                            } else {
                                                              expandedRowIndex =
                                                                  rowIndex;
                                                            }
                                                          });
                                                        },
                                                        child: Text(
                                                          '${rental.rentalData?.rentalAddress ?? '-'}${(rental.rentalData?.rentalAddress != null && rental.unitData?.rentalUnit != null) ? ' - ' : ''}${rental.unitData?.rentalUnit ?? ''}',
                                                          style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 15,
                                                    ),
                                                    // SizedBox(
                                                    //     width:
                                                    //     MediaQuery.of(context)
                                                    //         .size
                                                    //         .width *
                                                    //         .3),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        dateProvider
                                                            .formatCurrentDate(
                                                                '${formatDate('${rental.endDate ?? '-'}')}'),
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 10,
                                                    ),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: rental
                                                                .tenantData
                                                                ?.map((tenant) {
                                                              return Text(
                                                                '${tenant.tenantFirstName ?? '-'} ${tenant.tenantLastName ?? '-'}',
                                                                style:
                                                                    TextStyle(
                                                                  color:
                                                                      blueColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                              );
                                                            }).toList() ??
                                                            [
                                                              Text(
                                                                'N/A',
                                                                style:
                                                                    TextStyle(
                                                                  color:
                                                                      blueColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ],
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 5,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isRowExpanded)
                                              Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      FaIcon(
                                                        isRowExpanded
                                                            ? FontAwesomeIcons
                                                                .sortUp
                                                            : FontAwesomeIcons
                                                                .sortDown,
                                                        size: 40,
                                                        color:
                                                            Colors.transparent,
                                                      ),
                                                      Expanded(
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: <Widget>[
                                                            Text(
                                                              'Override Percentage : ',
                                                              style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    blueColor,
                                                              ),
                                                            ),
                                                            // Check if there are tenants and display their override fees
                                                            ...?rental
                                                                    .tenantData
                                                                    ?.map(
                                                                        (tenant) {
                                                                  return Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            10,
                                                                        right:
                                                                            10),
                                                                    child: Text(
                                                                      '${tenant.overrideFee ?? 'N/A'}%',
                                                                      style:
                                                                          TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        color:
                                                                            grey,
                                                                      ),
                                                                    ),
                                                                  );
                                                                }) ??
                                                                [
                                                                  Text(
                                                                    'N/A',
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color:
                                                                          grey,
                                                                    ),
                                                                  ),
                                                                ],
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        const SizedBox(width: 10),
                                        Material(
                                          elevation: 3,
                                          child: Container(
                                            height: 40,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12.0),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: itemsPerPage,
                                                items: itemsPerPageOptions
                                                    .map((int value) {
                                                  return DropdownMenuItem<int>(
                                                    value: value,
                                                    child:
                                                        Text(value.toString()),
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
                                          onPressed:
                                              currentPage < totalPages - 1
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
                          ),
                        );
                      },
                    ),
                  /* if (MediaQuery.of(context).size.width > 500)
              FutureBuilder<List<DelinquentTenantsData>>(
                future: _futureRentersInsurance,
                builder: (context, snapshot) {
                  if (isLoading) {
                    return ShimmerTabletTable();
                  } else if (snapshot.hasError) {
                    return Center(child: Text(errorMessage ?? 'Unknown error'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No data available'));
                  }

                  var data = snapshot.data!;

                  // Apply filtering based on selectedValue and searchValue
                  if (selectedValue == null && searchvalue.isEmpty) {
                    data = snapshot.data!;
                  } else if (selectedValue == "All") {
                    data = snapshot.data!;
                  } else if (searchvalue.isNotEmpty) {
                    data = snapshot.data!
                        .where((item) =>
                    (item.rentalAddress ?? '')
                        .toLowerCase()
                        .contains(searchvalue.toLowerCase()) ||
                        item.tenants!.any((tenant) => (tenant.tenantName ?? '')
                            .toLowerCase()
                            .contains(searchvalue.toLowerCase())))
                        .toList();
                  } else {
                    data = snapshot.data!
                        .where((item) => item.rentalAddress == selectedValue)
                        .toList();
                  }

                  // Pagination logic
                  final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                  final currentPageData = data
                      .skip(currentPage * itemsPerPage)
                      .take(itemsPerPage)
                      .toList();

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 0.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    height:
                                    MediaQuery.of(context).size.width <
                                        500
                                        ? 48
                                        : 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                          color: Colors.grey),
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
                                        hintStyle: TextStyle(
                                            color: Color(0xFF8A95A8)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: blueColor,
                                  ),
                                  onPressed: () {},
                                  child: PopupMenuButton<String>(
                                    onSelected: (value) async {
                                      // Export logic
                                      if (value == 'PDF') {
                                        print('pdf');
                                        generateDelinquentTenantsPdf(data);
                                      } else if (value == 'XLSX') {
                                        print('XLSX');
                                        generateDelinquentTenantsExcel(data);
                                      } else if (value == 'CSV') {
                                        print('CSV');
                                        generateDelinquentTenantsCsv(data);
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
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Export'),
                                        Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildHeaders(),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                                border: Border.all(color: blueColor


)),
                            // decoration: BoxDecoration(
                            //     border: Border.all(color: blueColor)),
                            child: Column(
                              children:
                              currentPageData.asMap().entries.map((entry) {
                                int rowIndex = entry.key;
                                var item = entry.value;
                                bool isRowExpanded =
                                    expandedRowIndex == rowIndex;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: rowIndex %2 != 0 ? Colors.white : blueColor.withOpacity(0.09),
                                    border: Border.all(color: blueColor


),
                                  ),
                                  // decoration: BoxDecoration(
                                  //   border: Border.all(color: blueColor),
                                  // ),
                                  child: Column(
                                    children: <Widget>[
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                            children: <Widget>[
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    if (expandedRowIndex ==
                                                        rowIndex) {
                                                      expandedRowIndex = null;
                                                    } else {
                                                      expandedRowIndex =
                                                          rowIndex;
                                                    }
                                                  });
                                                },
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      left: 5),
                                                  padding: !isRowExpanded
                                                      ? const EdgeInsets.only(
                                                      bottom: 10)
                                                      : const EdgeInsets.only(
                                                      top: 10),
                                                  child: FaIcon(
                                                    isRowExpanded
                                                        ? FontAwesomeIcons
                                                        .sortUp
                                                        : FontAwesomeIcons
                                                        .sortDown,
                                                    size: 20,
                                                    color: isRowExpanded
                                                        ? Color.fromARGB(
                                                        255, 35, 67, 126)
                                                        : blueColor


,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                  width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                      .04),
                                              Expanded(
                                                child: Text(
                                                  '${item.rentalAddress ?? '-'}',
                                                  style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (isRowExpanded)
                                        Column(
                                          children: item.tenants!
                                              .asMap()
                                              .entries
                                              .map((tenantEntry) {
                                            int tenantIndex = tenantEntry.key;
                                            var tenant = tenantEntry.value;
                                            bool isTenantExpanded =
                                                expandedTenantIndex[rowIndex] ==
                                                    tenantIndex;

                                            return Column(
                                              children: <Widget>[
                                                Divider(
                                                  color: blueColor,
                                                ),
                                                ListTile(
                                                  contentPadding:
                                                  EdgeInsets.zero,
                                                  title: Padding(
                                                    padding:
                                                    const EdgeInsets.all(
                                                        2.0),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .start,
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .center,
                                                      children: <Widget>[
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              if (expandedTenantIndex[
                                                              rowIndex] ==
                                                                  tenantIndex) {
                                                                expandedTenantIndex[
                                                                rowIndex] =
                                                                null;
                                                              } else {
                                                                expandedTenantIndex[
                                                                rowIndex] =
                                                                    tenantIndex;
                                                              }
                                                            });
                                                          },
                                                          child: Container(
                                                            margin:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 5),
                                                            padding: !isTenantExpanded
                                                                ? const EdgeInsets
                                                                .only(
                                                                bottom: 10)
                                                                : const EdgeInsets
                                                                .only(
                                                                top: 10),
                                                            child: Padding(
                                                              padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 24),
                                                              child: FaIcon(
                                                                isTenantExpanded
                                                                    ? FontAwesomeIcons
                                                                    .sortUp
                                                                    : FontAwesomeIcons
                                                                    .sortDown,
                                                                size: 20,
                                                                color: isTenantExpanded
                                                                    ? Color
                                                                    .fromARGB(
                                                                    255,
                                                                    35,
                                                                    67,
                                                                    126)
                                                                    : Color
                                                                    .fromRGBO(
                                                                    21,
                                                                    43,
                                                                    83,
                                                                    1),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                            width: MediaQuery.of(
                                                                context)
                                                                .size
                                                                .width *
                                                                .02),
                                                        Expanded(
                                                          child: RichText(
                                                              text: TextSpan(
                                                                  children: [
                                                                    TextSpan(
                                                                      text:
                                                                      'Tenant ${tenantIndex + 1} ',
                                                                      style:
                                                                      TextStyle(
                                                                        color: Colors
                                                                            .grey[
                                                                        600],
                                                                        fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                        fontSize:
                                                                        14,
                                                                      ),
                                                                    ),
                                                                    TextSpan(
                                                                      text:
                                                                      ': ${tenant.tenantName ?? '-'}',
                                                                      style:
                                                                      TextStyle(
                                                                        color:
                                                                        blueColor,
                                                                        fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                        fontSize:
                                                                        14,
                                                                      ),
                                                                    ),
                                                                  ])),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (isTenantExpanded)
                                                  Container(
                                                    width: double.infinity,
                                                    // color: Colors.amber,
                                                    child: Padding(
                                                      padding:
                                                      const EdgeInsets.all(
                                                          16.0),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Column(
                                                            crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                            children: [
                                                              SingleChildScrollView(
                                                                scrollDirection:
                                                                Axis.horizontal,
                                                                child: Row(
                                                                  children: [
                                                                    SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .06),
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          'Total Amount',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            blueColor,
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '${tenant.pdfDelinquentTenantsData!.totalDaysAmount ?? '-'}',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            Colors.grey[500],
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .04),
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          'Last 30 Days',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            blueColor,
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '${tenant.pdfDelinquentTenantsData!.last30Days ?? '-'}',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            Colors.grey[500],
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .04),
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          'Last 31 to 60 days',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            blueColor,
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '${tenant.pdfDelinquentTenantsData!.last31To60Days ?? '-'}',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            Colors.grey[500],
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .04),
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          'Last 61 to 90 Days',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            blueColor,
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '${tenant.pdfDelinquentTenantsData!.last61To90Days ?? '-'}',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            Colors.grey[500],
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    SizedBox(
                                                                        width: MediaQuery.of(context).size.width *
                                                                            .04),
                                                                    Column(
                                                                      crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                      children: [
                                                                        Text(
                                                                          'Last 91+ Days',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            blueColor,
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                        Text(
                                                                          '${tenant.pdfDelinquentTenantsData!.last91PlusDays ?? '-'}',
                                                                          style:
                                                                          TextStyle(
                                                                            color:
                                                                            Colors.grey[500],
                                                                            fontWeight:
                                                                            FontWeight.bold,
                                                                            fontSize:
                                                                            16,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 10,
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Material(
                                    elevation: 3,
                                    child: Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
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
                    ),
                  );
                },
              ),*/
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }

  String _getDisplayValue(String? value) {
    // Return 'N/A' if the value is null or empty, otherwise return the value
    return (value == null || value.trim().isEmpty) ? 'N/A' : value;
  }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                const SizedBox(height: 4.0), // Space between label and value
                Text(
                  leftValue,
                  style: TextStyle(color: grey),
                ),
              ],
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rightLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                const SizedBox(height: 4.0), // Space between label and value
                Text(
                  rightValue,
                  style: TextStyle(color: grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<TableRow> _buildExpandableRows(
      int rowIndex, DelinquentTenantsData item) {
    return [
      TableRow(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: blueColor),
            right: BorderSide(color: blueColor),
            top: BorderSide(color: blueColor),
            bottom: item.tenants!.isEmpty
                ? BorderSide(color: blueColor)
                : BorderSide.none,
          ),
        ),
        children: [
          _buildDataCell(item.rentalAddress ?? '-'),
          _buildDataCell(''),
          _buildDataCell(''),
          _buildDataCell(''),
          _buildDataCell(''),
        ],
      ),
      for (var tenantEntry in item.tenants!.asMap().entries)
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: blueColor),
              right: BorderSide(color: blueColor),
              bottom: tenantEntry.key == item.tenants!.length - 1
                  ? BorderSide(color: blueColor)
                  : BorderSide.none,
            ),
          ),
          children: [
            _buildDataCell('${item.tenants!.first.unitDetails ?? '-'}'),
            _buildDataCell('${tenantEntry.value.tenantName ?? '-'}'),
            _buildDataCell(
                '${tenantEntry.value.pdfDelinquentTenantsData!.last30Days ?? '-'}'),
            _buildDataCell(
                ' ${tenantEntry.value.pdfDelinquentTenantsData!.last30Days ?? '-'}\n'),
            _buildDataCell(
                ' ${tenantEntry.value.pdfDelinquentTenantsData!.last30Days ?? '-'}\n'),
          ],
        ),
    ];
  }

  String convertDateFormat(String date) {
    // Assuming the input date is in the format of "dd-MM-yyyy"
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        // parts[0] is day, parts[1] is month, parts[2] is year
        return '${parts[2]}-${parts[1]}-${parts[0]}'; // Convert to "yyyy-MM-dd"
      }
    } catch (e) {
      logError('Error converting date format: $e');
    }
    return date; // Return the original date if conversion fails
  }

  filters({List<Data>? data}) {
    // Export is greyed out and not tappable while the (searched) report
    // has no rows.
    final bool hasExportData = data?.isNotEmpty ?? false;
    return Column(
      children: [
        const SizedBox(
          height: 10,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      // height: 40,
                      height:
                          MediaQuery.of(context).size.width < 500 ? 45 : 50,
                      width: MediaQuery.of(context).size.width < 500
                          ? MediaQuery.of(context).size.width * .44
                          : MediaQuery.of(context).size.width * .4,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.grey),
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
                          hintStyle: TextStyle(color: Color(0xFF8A95A8)),
                          contentPadding: EdgeInsets.all(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: SizedBox(
                  //  width: 100,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueColor,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white,
                    ),
                    onPressed: hasExportData ? () {} : null,
                    child: PopupMenuButton<String>(
                      enabled: hasExportData,
                      onSelected: (value) async {
                        // Export logic
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        if (value == 'PDF' && data != null) {
                          generateAccountTotalReportPdf(data, dateProvider);
                        } else if (value == 'XLSX' && data != null) {
                          generateAccountTotalReportExcel(data, dateProvider);
                        } else if (value == 'CSV' && data != null) {
                          generateAccountTotalReportCsv(data, dateProvider);
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          istenantDataLoading
                              ? const Center(
                                  child: SpinKitFadingCircle(
                                    color: Colors.white,
                                    size: 21.0,
                                  ),
                                )
                              : const Text('Export'),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 0.0),
        //   child: Row(
        //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //     children: [
        //       Expanded(
        //         child: Container(
        //           height: 42,
        //           decoration: BoxDecoration(
        //               borderRadius: BorderRadius.circular(5),
        //               border: Border.all(color: Colors.grey)),
        //           child: DropdownButtonHideUnderline(
        //             child: DropdownButton<String>(
        //               value: daterange,
        //               padding: EdgeInsets.symmetric(horizontal: 5),
        //               hint: Text(
        //                 "Date Range",
        //                 style: TextStyle(fontSize: 14, color: Colors.black),
        //               ),
        //               items: const [
        //                 DropdownMenuItem<String>(
        //                   value: 'Today',
        //                   child: Text('Today'),
        //                 ),
        //                 DropdownMenuItem<String>(
        //                   value: 'This Week',
        //                   child: Text('This Week'),
        //                 ),
        //                 DropdownMenuItem<String>(
        //                   value: 'This Month',
        //                   child: Text('This Month'),
        //                 ),
        //                 DropdownMenuItem<String>(
        //                   value: 'This Year',
        //                   child: Text('This Year'),
        //                 ),
        //                 DropdownMenuItem<String>(
        //                   value: 'Custom',
        //                   child: Text('Custom'),
        //                 ),
        //               ],
        //               onChanged: (value) {
        //                 setState(() {
        //                   daterange = value;
        //                   if (value == "Today") {
        //                     customdate = false;
        //                     fromDate.text =
        //                         formatDate(DateTime.now().toString());
        //                     toDate.text = formatDate(DateTime.now().toString());
        //                   } else if (value == "This Week") {
        //                     DateTime now = DateTime.now();
        //                     //  fromDate.text = formatDate(now.toString());
        //                     customdate = false;
        //                     fromDate.text = formatDate(now.subtract(Duration(days: now.weekday - 1)).toString());
        //                     toDate.text = formatDate(now.add(Duration(
        //                         days: DateTime.daysPerWeek - now.weekday)).toString());
        //                   } else if (value == "This Month") {
        //                     customdate = false;
        //                     DateTime now = DateTime.now();
        //                     fromDate.text = formatDate(
        //                         DateTime(now.year, now.month, 1).toString());
        //                     toDate.text = formatDate(
        //                         DateTime(now.year, now.month + 1, 0)
        //                             .toString());
        //                   } else if (value == "This Year") {
        //                     customdate = false;
        //                     DateTime now = DateTime.now();
        //                     fromDate.text =
        //                         formatDate(DateTime(now.year, 1, 1).toString());
        //                     toDate.text = formatDate(
        //                         DateTime(now.year, 12, 31).toString());
        //                   } else if (value == "Custom") {
        //                     customdate = true;
        //                     fromDate.text = ""; // Set fromDate to empty
        //                     toDate.text = "";
        //                     _futureConvenienceFee = fetchConvenienceFeeReportsData();// Set toDate to empty
        //                   }
        //                   // Fetch the report data with the selected date range
        //                   if (daterange != "Custom") {
        //                     DateTime from = DateTime.parse(convertDateFormat(fromDate.text));
        //                     DateTime to = DateTime.parse(convertDateFormat(toDate.text));
        //                     _futureConvenienceFee = fetchConvenienceFeeReportsData(fromDate: from, toDate: to);
        //                   }
        //
        //                 });
        //                 // Handle the selected charge type
        //                 print(value);
        //               },
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 6),
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 10),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 0.0),
        //   child: Row(
        //     //mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //     children: [
        //       Expanded(
        //         child: Container(
        //           // width: 110,
        //           child: TextFormField(
        //             controller: fromDate,
        //             // enabled: customdate,
        //             onTap: customdate
        //                 ? () {
        //               _pickDate(context);
        //             }
        //                 : null,
        //             readOnly: true,
        //             style: TextStyle(fontSize: 14, color: Colors.black),
        //             textInputAction: TextInputAction.next,
        //             textAlignVertical: TextAlignVertical.center,
        //             decoration: InputDecoration(
        //               contentPadding: const EdgeInsets.symmetric(
        //                   vertical: 10, horizontal: 10), //Imp Line
        //               isDense: true,
        //
        //               hintText: "From",
        //
        //               border: OutlineInputBorder(
        //                   borderRadius: BorderRadius.circular(5),
        //                   borderSide: const BorderSide(
        //                     width: 1,
        //                   )),
        //             ),
        //           ),
        //         ),
        //       ),
        //       SizedBox(width: 10),
        //       Expanded(
        //         child: Container(
        //           // width: 110,
        //           child: TextFormField(
        //             controller: toDate,
        //             // enabled: customdate,
        //             style: TextStyle(fontSize: 14, color: Colors.black),
        //             onTap: customdate
        //                 ? () {
        //               _endDate(context);
        //             }
        //                 : null,
        //             readOnly: true,
        //             textInputAction: TextInputAction.next,
        //             textAlignVertical: TextAlignVertical.center,
        //             decoration: InputDecoration(
        //               contentPadding: const EdgeInsets.symmetric(
        //                   vertical: 10, horizontal: 10), //Imp Line
        //               isDense: true,
        //               hintText: "To",
        //
        //               border: OutlineInputBorder(
        //                   borderRadius: BorderRadius.circular(5),
        //                   borderSide: const BorderSide(
        //                     width: 0.5,
        //                   )),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 6),
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 10),
      ],
    );
  }
}
