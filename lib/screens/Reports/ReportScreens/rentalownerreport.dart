import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:csv/csv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/DelinquentTenantsModel.dart';
import 'package:three_zero_two_property/Model/RentarsInsuranceModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/repository/DelinquentTenantsService.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/RentersInsuranceService.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';
import '../../../Model/rentalownerreport.dart';
import '../../../repository/rentalownerreport.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class RentalOwnerReports extends StatefulWidget {
  const RentalOwnerReports({super.key});

  @override
  State<RentalOwnerReports> createState() => _RentalOwnerReportsState();
}

class _RentalOwnerReportsState extends State<RentalOwnerReports>
    with NetworkRetryState {
  late Future<List<RentalOwnerReport>> _futureRentersInsurance;
  List<RentalOwnerReport> DelinquentTenantsModel = [];
  bool isLoading = true;
  String? errorMessage;
  int? expandedRowIndex;
  Map<int, int?> expandedTenantIndex = {};
  // Pagination for payments within each rental owner
  Map<int, int> paymentCurrentPage = {}; // Key: rowIndex, Value: current page
  Map<int, int> paymentItemsPerPage =
      {}; // Key: rowIndex, Value: items per page
  int defaultPaymentItemsPerPage = 5; // Default items per page for payments
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
    _selectedOwnersNotifier.value = [];
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    fetchRentalOwners();
    //fetchpdfrentalowner(); // this for pdf
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

  fetchReport() {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    setState(() {
      daterange = "Today";
      String todayApiFormat = DateFormat('yyyy-MM-dd').format(DateTime.now());
      fromDate.text = dateProvider.formatCurrentDate(todayApiFormat);
      toDate.text = dateProvider.formatCurrentDate(todayApiFormat);
    });
    DateTime time = DateTime.now();
    DateTime date = DateFormat('yyyy-MM-dd').parse(time.toString());
    _futureRentersInsurance = fetchDelinquentTenantsData(
        DateFormat('yyyy-MM-dd').format(date),
        DateFormat('yyyy-MM-dd').format(date));
  }

  Future<List<RentalOwnerReport>> fetchDelinquentTenantsData(
      String fromDate, String toDate,
      {String? rentalownerid, String? charge}) async {
    // Remember this exact call so Retry can replay it unchanged.
    _lastFetchCall = () => fetchDelinquentTenantsData(fromDate, toDate,
        rentalownerid: rentalownerid, charge: charge);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      String? chargedata = chargeType == "All" ? null : chargeType;

      String? selectedrenatalownerid = selectedRentalOwnerIds.isEmpty ||
              selectedRentalOwnerIds.contains("all")
          ? null
          : selectedRentalOwnerIds.join(',');
      List<RentalOwnerReport> data = await RentalOwnerReportService()
          .fetchRentalOwnerReport(id!, fromDate, toDate,
              rentalownerid: selectedrenatalownerid, chargetype: chargedata);

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
                'Failed to load rental owner data. Please try again later.');
      });
      // Rethrow so the FutureBuilder reports hasError: a failed fetch must not
      // be presented as a report that legitimately has no rows.
      rethrow;
    }
  }

  // Remembers the exact fetch the screen last ran so Retry replays it with the
  // user's current filter selections rather than resetting them.
  Future<List<RentalOwnerReport>> Function()? _lastFetchCall;

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
    final call = _lastFetchCall;
    if (call == null) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
      _futureRentersInsurance = call();
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

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(DelinquentTenantsData d)? getField) {
    return TableCell(
      child: GestureDetector(
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

  void _sort<T>(Comparable<T> Function(DelinquentTenantsData d) getField,
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
          left: MediaQuery.of(context).size.width > 500 ? 12 : 0,
          right: MediaQuery.of(context).size.width > 500 ? 12 : 0),
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
                            ? Text("Rental Owner",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))
                            : Text("Rental Owner",
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
              // Expanded(
              //   child: GestureDetector(
              //     onTap: () {
              //       setState(() {
              //         if (sorting2) {
              //           sorting1 = false;
              //           sorting2 = sorting2;
              //           sorting3 = false;
              //           ascending2 = sorting2 ? !ascending2 : true;
              //           ascending1 = false;
              //           ascending3 = false;
              //         } else {
              //           sorting1 = false;
              //           sorting2 = !sorting2;
              //           sorting3 = false;
              //           ascending2 = sorting2 ? !ascending2 : true;
              //           ascending1 = false;
              //           ascending3 = false;
              //         }
              //         // Sorting logic here
              //       });
              //     },
              //     child: Row(
              //       children: [
              //         Text("Address", style: TextStyle(color: Colors.white)),
              //         SizedBox(width: 5),
              //         ascending2
              //             ? Padding(
              //                 padding: const EdgeInsets.only(top: 7, left: 2),
              //                 child: FaIcon(
              //                   FontAwesomeIcons.sortUp,
              //                   size: 20,
              //                   color: Colors.white,
              //                 ),
              //               )
              //             : Padding(
              //                 padding: const EdgeInsets.only(bottom: 7, left: 2),
              //                 child: FaIcon(
              //                   FontAwesomeIcons.sortDown,
              //                   size: 20,
              //                   color: Colors.white,
              //                 ),
              //               ),
              //       ],
              //     ),
              //   ),
              // ),
              // Expanded(
              //   child: GestureDetector(
              //     onTap: () {
              //       setState(() {
              //         if (sorting3) {
              //           sorting1 = false;
              //           sorting2 = false;
              //           sorting3 = sorting3;
              //           ascending3 = sorting3 ? !ascending3 : true;
              //           ascending2 = false;
              //           ascending1 = false;
              //         } else {
              //           sorting1 = false;
              //           sorting2 = false;
              //           sorting3 = !sorting3;
              //           ascending3 = sorting3 ? !ascending3 : true;
              //           ascending2 = false;
              //           ascending1 = false;
              //         }

              //         // Sorting logic here
              //       });
              //     },
              //     child: Row(
              //       children: [
              //         Text("Work", style: TextStyle(color: Colors.white)),
              //         SizedBox(width: 5),
              //         ascending3
              //             ? Padding(
              //                 padding: const EdgeInsets.only(top: 7, left: 2),
              //                 child: FaIcon(
              //                   FontAwesomeIcons.sortUp,
              //                   size: 20,
              //                   color: Colors.white,
              //                 ),
              //               )
              //             : Padding(
              //                 padding: const EdgeInsets.only(bottom: 7, left: 2),
              //                 child: FaIcon(
              //                   FontAwesomeIcons.sortDown,
              //                   size: 20,
              //                   color: Colors.white,
              //                 ),
              //               ),
              //       ],
              //     ),
              //   ),
              // ),
            ],
          ),
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
        "id": "CRM $adminId",
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
  bool isAddLoading = false;
  bool customdate = false;
  Future<void> generateDelinquentTenantsPdf(
      List<RentalOwnerReport> delinquentTenantsData) async {
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
                    'Rental Owner Reports',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date: ${fromDate.text}',
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
                  'Tenant',
                  'Date',
                  'Pmt Type',
                  'Txn ID',
                  'Reference',
                  'Crd Type',
                  'Crd No',
                  'Total',
                ],
                data: _generateTableData(delinquentTenantsData),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5A86D5"),
                  //color:PdfColor.fromRYB(90, 134, 213,)
                ),
                cellStyle: pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  // Widths follow the header row above. Date and Total were
                  // sized for the old raw values and split a formatted date
                  // across two lines ("07/13/2" / "026"); the slack comes from
                  // Property and Reference, which wrap acceptably.
                  0: pw.FlexColumnWidth(1.7), // Property
                  1: pw.FlexColumnWidth(1.5), // Tenant
                  2: pw.FlexColumnWidth(1.4), // Date
                  3: pw.FlexColumnWidth(.8), // Pmt Type
                  4: pw.FlexColumnWidth(1.3), // Txn ID
                  5: pw.FlexColumnWidth(1.4), // Reference
                  6: pw.FlexColumnWidth(.8), // Crd Type
                  7: pw.FlexColumnWidth(1.5), // Crd No
                  8: pw.FlexColumnWidth(1.3), // Total
                },
                border: null),
            pw.Divider(thickness: 3),
            pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Grand Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(formatCurrency(grandtotal),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                    ])),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'rentalownerreport.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Rental_owner_transaction_report',
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  List<List<dynamic>> _generateTableData(
      List<RentalOwnerReport> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];
    double total = 0.0;

    for (var owner in rentalOwnerReports) {
      // Main row for the rental owner name
      tableData.add([
        pw.Text(owner.rentalOwnerName,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        ''
      ]);

      for (var property in owner.payments) {
        tableData.add([
          pw.Padding(
              child: pw.Text(
                '${property.rentalData!.rentalAddress! ?? 'N/A'}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              padding: pw.EdgeInsets.only(left: 15)), // Property Name
          pw.Text(
            '${property.tenantData!.tenantFirstName ?? 'N/A'} ${property.tenantData!.tenantLastName ?? 'N/A'}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Property Name
          // Tenant Name
          pw.Text(
            _transactionDate(property),
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Payment Date
          pw.Text(
            property.paymentType ?? '',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Payment Type
          pw.Text(
            property.transactionId ?? '',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Transaction ID
          pw.Text(
            property.paymentId ?? '',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // References
          pw.Text(
            property.ccType ?? '',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Card Type
          pw.Text(
            property.ccNumber ?? '',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Card Number
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              formatCurrency(property.totalAmount),
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              // Total Amount formatted to 2 decimal places
              // Align text to the right
            ),
          ),
        ]);

        if (property.response != "FAILURE")
          for (var payment in property.entry) {
            tableData.add([
              pw.Padding(
                  child: pw.Text('${payment.account ?? 'N/A'}',
                      style: pw.TextStyle(fontSize: 10)),
                  padding: pw.EdgeInsets.only(left: 15)), // Account Name
              '', // Account Amount
              '', '', '', '', '', '',
              pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(formatCurrency(payment.amount),
                      style: pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right // Align text to the right
                      ))
            ]);
          }
        if (property.response == "FAILURE")
          tableData.add([
            pw.Padding(
                child: pw.Text(
                    'Failed (reason:${property.responseText ?? 'N/A'})',
                    style: pw.TextStyle(fontSize: 10)),
                padding: pw.EdgeInsets.only(left: 15)), // Account Name
            '', // Account Amount
            '', '', '', '', '', '',
            ''
          ]);

        // if (property.surcharge != 0.0) {
        //   tableData.add([
        //     pw.Padding(
        //         child: pw.Text(
        //           'Surcharge',
        //           style: pw.TextStyle(fontSize: 10),
        //         ),
        //         padding: pw.EdgeInsets.only(left: 15)),
        //     '', // Account Amount
        //     '', '', '', '', '', '',
        //     pw.Align(
        //         alignment: pw.Alignment.centerRight,
        //         child: pw.Text(
        //             '\$${(property.surcharge ?? 0.0).toStringAsFixed(2)}', // Surcharge formatted to 2 decimal places
        //             style: pw.TextStyle(fontSize: 10),
        //             textAlign: pw.TextAlign.right // Align text to the right
        //             ))
        //   ]);
        // }
      }

      // Subtotal row for the rental owner
      tableData.add([
        pw.Padding(
            child: pw.Text('Subtotal ${owner.rentalOwnerName ?? 'N/A'}',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            padding: pw.EdgeInsets.only(
                left: 15)), // Label for rental owner subtotal
        '', '', '', '', '', '', '',
        pw.Text(
            formatCurrency(
                owner.subTotal), // Subtotal formatted to 2 decimal places
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            textAlign: pw.TextAlign.right // Align text to the right
            )
      ]);

      total += owner.subTotal;
    }

    setState(() {
      grandtotal = total;
    });

    return tableData;
  }

  Future<void> generateRentalOwnerReportExcel(
      List<RentalOwnerReport> rentalOwnerReports) async {
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    sheet.getRangeByName('A1:I1').columnWidth = 20;

    final List<String> headers = [
      'Property',
      'Tenant',
      'Date',
      'Pmt Type',
      'Txn ID',
      'Reference',
      'Crd Type',
      'Crd No',
      'Total',
    ];

    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#5A86D5';
    headerCellStyle.fontColor = '#FFFFFF';
    headerCellStyle.fontSize = 16;
    headerCellStyle.hAlign = syncXlsx.HAlignType.center;

    final syncXlsx.Style currencyCellStyle =
        workbook.styles.add('currencyCellStyle');
    currencyCellStyle.numberFormat = '\$#,##0.00'; // Currency format
    currencyCellStyle.hAlign = syncXlsx.HAlignType.right; // Right-align amounts

    final syncXlsx.Style boldAmountStyle =
        workbook.styles.add('boldAmountStyle');
    boldAmountStyle.bold = true;
    boldAmountStyle.numberFormat = '\$#,##0.00';
    boldAmountStyle.hAlign = syncXlsx.HAlignType.right;
    final syncXlsx.Style AmountTitleStyle =
        workbook.styles.add('AmountTitleStyle');
    boldAmountStyle.bold = true;
    boldAmountStyle.numberFormat = '\$#,##0.00';

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    int rowIndex = 2;
    double grandTotal = 0.0;

    for (var owner in rentalOwnerReports) {
      final rentalOwnerCell = sheet.getRangeByIndex(rowIndex, 1);
      rentalOwnerCell.setText(owner.rentalOwnerName ?? '');
      rentalOwnerCell.cellStyle.bold = true;
      sheet.getRangeByName('A$rowIndex:I$rowIndex').merge();
      rowIndex++;

      for (var property in owner.payments) {
        sheet
            .getRangeByIndex(rowIndex, 1)
            .setText(property.rentalData!.rentalAddress ?? 'N/A');
        sheet.getRangeByIndex(rowIndex, 2).setText(
            '${property.tenantData!.tenantFirstName ?? 'N/A'} ${property.tenantData!.tenantLastName ?? 'N/A'}');
        sheet
            .getRangeByIndex(rowIndex, 3)
            .setText(_transactionDate(property));
        sheet.getRangeByIndex(rowIndex, 4).setText(property.paymentType ?? '');
        sheet
            .getRangeByIndex(rowIndex, 5)
            .setText(property.transactionId ?? '');
        sheet.getRangeByIndex(rowIndex, 6).setText(property.paymentId ?? '');
        sheet.getRangeByIndex(rowIndex, 7).setText(property.ccType ?? '');
        sheet.getRangeByIndex(rowIndex, 8).setText(property.ccNumber ?? '');
        sheet
            .getRangeByIndex(rowIndex, 9)
            .setNumber(property.totalAmount ?? 0.0);
        sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
        rowIndex++;

        for (var payment in property.entry) {
          sheet.getRangeByIndex(rowIndex, 1).setText(payment.account ?? 'N/A');
          sheet.getRangeByIndex(rowIndex, 9).setNumber(payment.amount);
          sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
          rowIndex++;
        }

        // if (property.surcharge != 0.0) {
        //   sheet.getRangeByIndex(rowIndex, 1).setText('Surcharge');
        //   sheet.getRangeByIndex(rowIndex, 9).setNumber(property.surcharge);
        //   sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
        //   rowIndex++;
        // }
      }

      sheet
          .getRangeByIndex(rowIndex, 1)
          .setText('Subtotal - ${owner.rentalOwnerName}');
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(rowIndex, 9).setNumber(owner.subTotal ?? 0.0);
      sheet.getRangeByIndex(rowIndex, 9).cellStyle = boldAmountStyle;
      sheet.getRangeByName('A$rowIndex:H$rowIndex').merge();
      rowIndex++;

      grandTotal += owner.subTotal ?? 0.0;
    }

    sheet.getRangeByIndex(rowIndex, 1).setText('Grand Total');
    sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 9).setNumber(grandTotal);
    sheet.getRangeByIndex(rowIndex, 9).cellStyle = boldAmountStyle;
    sheet.getRangeByName('A$rowIndex:H$rowIndex').merge();

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'RentalOwnerReport_$formattedDate.xlsx';

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

  Future<void> generateRentalOwnerReportCsv(
      List<RentalOwnerReport> rentalOwnerReports) async {
    // Define headers for CSV
    final List<String> headers = [
      'Property',
      'Tenant',
      'Date',
      'Pmt Type',
      'Txn ID',
      'Reference',
      'Crd Type',
      'Crd No',
      'Total',
    ];

    // Create a buffer to store CSV data
    final StringBuffer csvBuffer = StringBuffer();

    // Add headers to the CSV file
    csvBuffer.writeln(headers.join(','));

    double grandTotal = 0.0;

    // Iterate through each rental owner report
    for (var owner in rentalOwnerReports) {
      // Add rental owner name as a row
      csvBuffer.writeln('${owner.rentalOwnerName ?? ''}');

      // Iterate through each property for the current rental owner
      for (var property in owner.payments) {
        // Replace commas in the rental address with spaces
        final String sanitizedAddress =
            (property.rentalData!.rentalAddress ?? 'N/A').replaceAll(',', ' ');

        // Add property and tenant details
        csvBuffer.writeln([
          sanitizedAddress,
          '${property.tenantData!.tenantFirstName ?? 'N/A'} ${property.tenantData!.tenantLastName ?? 'N/A'}',
          _transactionDate(property),
          property.paymentType ?? '',
          property.transactionId ?? '',
          property.paymentId ?? '',
          property.ccType ?? '',
          property.ccNumber ?? '',
          formatCurrency(property.totalAmount)
        ].join(','));

        // Iterate through payment entries for the current property
        for (var payment in property.entry) {
          csvBuffer.writeln([
            payment.account ?? 'N/A',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            formatCurrency(payment.amount)
          ].join(','));
        }

        // Add surcharge row if applicable
        // if (property.surcharge != 0.0) {
        //   csvBuffer.writeln([
        //     'Surcharge',
        //     '',
        //     '',
        //     '',
        //     '',
        //     '',
        //     '',
        //     '',
        //     '\$${property.surcharge.toStringAsFixed(2)}'
        //   ].join(','));
        // }
      }

      // Add subtotal row for the current rental owner
      csvBuffer.writeln([
        'Subtotal - ${owner.rentalOwnerName}',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        formatCurrency(owner.subTotal)
      ].join(','));

      // Accumulate grand total
      grandTotal += owner.subTotal ?? 0.0;
    }

    // Add grand total row at the end
    csvBuffer.writeln([
      'Grand Total',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      formatCurrency(grandTotal)
    ].join(','));

    // Convert buffer to list of bytes for CSV file
    final List<int> bytes = utf8.encode(csvBuffer.toString());

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'RentalOwnerReport_$formattedDate.csv';

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

  Future<void> generateDelinquentTenantsCsv(
      List<DelinquentTenantsData> delinquentTenantsData) async {
    setState(() {
      istenantDataLoading = true;
    });

    final globalDelinquentTenantsData =
        await fetchDelinquentTenantsGrandTotal();

    setState(() {
      istenantDataLoading = false;
    });
    List<List<dynamic>> rows = [
      [
        'Unit',
        'Tenant',
        'Total',
        '0-30 days',
        '31-60 days',
        '61-90 days',
        '91+ days'
      ]
    ];

    for (var item in delinquentTenantsData) {
      // Add main row with rental address
      rows.add([item.rentalAddress ?? '', '', '', '', '', '', '']);

      // Add tenant details in subsequent rows
      for (var tenant in item.tenants!) {
        rows.add([
          tenant.unitDetails ?? '',
          tenant.tenantName ?? '',
          tenant.pdfDelinquentTenantsData?.totalDaysAmount ?? '',
          tenant.pdfDelinquentTenantsData?.last30Days ?? '',
          tenant.pdfDelinquentTenantsData?.last31To60Days ?? '',
          tenant.pdfDelinquentTenantsData?.last61To90Days ?? '',
          tenant.pdfDelinquentTenantsData?.last91PlusDays ?? ''
        ]);
      }

      // Add total row for each property
      rows.add([
        'Total',
        '',
        item.alltotalamount?.totalDaysAmount ?? '',
        item.alltotalamount?.last30Days ?? '',
        item.alltotalamount?.last31To60Days ?? '',
        item.alltotalamount?.last61To90Days ?? '',
        item.alltotalamount?.last91PlusDays ?? ''
      ]);
    }

    // Add grand total row
    if (globalDelinquentTenantsData != null) {
      rows.add([
        'Grand Total of all Properties',
        '',
        globalDelinquentTenantsData!.totalDaysAmount ?? '',
        globalDelinquentTenantsData!.last30Days ?? '',
        globalDelinquentTenantsData!.last31To60Days ?? '',
        globalDelinquentTenantsData!.last61To90Days ?? '',
        globalDelinquentTenantsData!.last91PlusDays ?? ''
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'DelinquentTenantsReport_$formattedDate.csv';

    // Define file path
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    // Write file to the path
    final File file = File(path);
    await file.writeAsString(csv);
    Share.shareXFiles([XFile(path)]);
    // Show success toast message
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
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

        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        fromDate.text = dateProvider.formatCurrentDate(apiFormatDate);

        // _futureRentersInsurance =
        //     fetchDelinquentTenantsData(fromDate.text, toDate.text);
      });

      // Notify the FormField state of the change
    }
  }

  Future<void> _endDate(BuildContext context) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
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

        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        toDate.text = dateProvider.formatCurrentDate(apiFormatDate);
        // _futureRentersInsurance =
        //     fetchDelinquentTenantsData(fromDate.text, toDate.text);
      });

      // Notify the FormField state of the change
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
      "id": "CRM $id",
    });
    final jsonData = json.decode(response.body);
    if (response.statusCode == 200) {
      setState(() {
        rentalowners = (jsonDecode(response.body) as List)
            .map((e) => e as Map<String, dynamic>)!
            .toList();

        // Sort rental owners alphabetically by name (excluding "All" option)
        rentalowners.sort((a, b) {
          String nameA = a['rentalOwner_name']?.toString() ?? '';
          String nameB = b['rentalOwner_name']?.toString() ?? '';
          return nameA.toLowerCase().compareTo(nameB.toLowerCase());
        });

        // Insert "All" option at the beginning after sorting
        rentalowners.insert(0, {
          "rentalowner_id": "all",
          "rentalOwner_name": "All",
        });
      });
      log(rentalowners.toString());
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Future<void> fetchpdfrentalowner() async {
  //   print("calling");
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? id = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //   final response = await apiGet(
  //       Uri.parse(
  //           '${Api_url}/api/rental_owner/todayspaymentrentalownerpdf/$id'),
  //       headers: {
  //         "authorization": "CRM $token",
  //         "id": "CRM $id",
  //       });
  //   final jsonData = json.decode(response.body);
  //   print(jsonData);
  //   if (response.statusCode == 200) {
  //     setState(() {
  //       rentalowners = (jsonDecode(response.body) as List)
  //           .map((e) => e as Map<String, dynamic>)!
  //           .toList();
  //     });
  //     log(rentalowners.toString());
  //   } else {
  //     throw Exception('Failed to load data');
  //   }
  // }

  TextEditingController fromDate = TextEditingController();
  TextEditingController toDate = TextEditingController();
  /// Web's From/To check (null when the range is fine).
  String? get _dateRangeError =>
      reportDateRangeError(fromDate.text, toDate.text);
  String? daterange;
  String? chargeType;
  String? selectedrenatalownerid;
  bool showTableData = false;
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
                    title: "Rental Owner Report",
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width < 500)
                  FutureBuilder<List<RentalOwnerReport>>(
                    future: _futureRentersInsurance,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              filters(),
                              SizedBox(
                                height: 10,
                              ),
                              ColabShimmerLoadingWidget(),
                            ],
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              filters(),
                              _reportErrorState(onRetry: _retryFetch),
                            ],
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              filters(),
                              Container(
                                height: MediaQuery.of(context).size.height * .5,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                              ),
                            ],
                          ),
                        );
                      }

                      var data = snapshot.data!;

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
                              SizedBox(
                                height: 5,
                              ),
                              filters(data: data),
                              const SizedBox(height: 20),
                              _buildHeaders(),
                              const SizedBox(height: 10),
                              if (showTableData)
                                Padding(
                                  padding: EdgeInsets.only(
                                      left: MediaQuery.of(context).size.width >
                                              500
                                          ? 12
                                          : 0,
                                      right: MediaQuery.of(context).size.width >
                                              500
                                          ? 12
                                          : 0),
                                  child: Container(
                                    // decoration: BoxDecoration(
                                    //     border: Border.all(
                                    //         color: Color.fromRGBO(
                                    //             152, 162, 179, .5))),
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
                                        RentalOwnerReport rental = entry.value;

                                        return Container(
                                          // decoration: BoxDecoration(
                                          //   border: Border.all(color: blueColor),
                                          // ),
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
                                                        CrossAxisAlignment
                                                            .center,
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
                                                              // Initialize pagination when expanding
                                                              if (!paymentCurrentPage
                                                                  .containsKey(
                                                                      rowIndex)) {
                                                                paymentCurrentPage[
                                                                    rowIndex] = 0;
                                                                paymentItemsPerPage[
                                                                        rowIndex] =
                                                                    defaultPaymentItemsPerPage;
                                                              }
                                                            }
                                                          });
                                                        },
                                                        child: Container(
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 5,
                                                                  right: 5),
                                                          padding: !isRowExpanded
                                                              ? const EdgeInsets
                                                                  .only(
                                                                  bottom: 10)
                                                              : const EdgeInsets
                                                                  .only(
                                                                  top: 10),
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
                                                            '${item.rentalOwnerName ?? '-'}',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 20,
                                                      ),
                                                      // SizedBox(
                                                      //     width:
                                                      //     MediaQuery.of(context)
                                                      //         .size
                                                      //         .width *
                                                      //         .3),
                                                      Expanded(
                                                        flex: 2,
                                                        child: Text(
                                                          ' Record : ${item.payments.length ?? '-'}',
                                                          style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        width: 5,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (isRowExpanded)
                                                Builder(
                                                  builder: (context) {
                                                    // Initialize pagination for this rental owner if not exists
                                                    if (!paymentCurrentPage
                                                        .containsKey(
                                                            rowIndex)) {
                                                      paymentCurrentPage[
                                                          rowIndex] = 0;
                                                      paymentItemsPerPage[
                                                              rowIndex] =
                                                          defaultPaymentItemsPerPage;
                                                    }

                                                    final currentPaymentPage =
                                                        paymentCurrentPage[
                                                                rowIndex] ??
                                                            0;
                                                    final paymentItemsPerPageValue =
                                                        paymentItemsPerPage[
                                                                rowIndex] ??
                                                            defaultPaymentItemsPerPage;
                                                    final totalPayments =
                                                        item.payments!.length;
                                                    final totalPaymentPages =
                                                        (totalPayments /
                                                                paymentItemsPerPageValue)
                                                            .ceil();

                                                    // Get paginated payments
                                                    final paginatedPayments = item
                                                        .payments!
                                                        .skip(currentPaymentPage *
                                                            paymentItemsPerPageValue)
                                                        .take(
                                                            paymentItemsPerPageValue)
                                                        .toList();

                                                    return Column(
                                                      children: [
                                                        ...paginatedPayments
                                                            .asMap()
                                                            .entries
                                                            .map((tenantEntry) {
                                                          // Calculate actual index in full list
                                                          final actualIndex =
                                                              currentPaymentPage *
                                                                      paymentItemsPerPageValue +
                                                                  tenantEntry
                                                                      .key;
                                                          int tenantIndex =
                                                              actualIndex;
                                                          var tenant =
                                                              tenantEntry.value;
                                                          bool
                                                              isTenantExpanded =
                                                              expandedTenantIndex[
                                                                      rowIndex] ==
                                                                  tenantIndex;

                                                          return Column(
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  GestureDetector(
                                                                    onTap: () {
                                                                      setState(
                                                                          () {
                                                                        if (expandedTenantIndex[rowIndex] ==
                                                                            tenantIndex) {
                                                                          expandedTenantIndex[rowIndex] =
                                                                              null;
                                                                        } else {
                                                                          expandedTenantIndex[rowIndex] =
                                                                              tenantIndex;
                                                                        }
                                                                      });
                                                                    },
                                                                    child:
                                                                        Container(
                                                                      margin: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              5,
                                                                          right:
                                                                              5),
                                                                      padding: !isTenantExpanded
                                                                          ? const EdgeInsets
                                                                              .only(
                                                                              bottom:
                                                                                  10)
                                                                          : const EdgeInsets
                                                                              .only(
                                                                              top: 10),
                                                                      child:
                                                                          Padding(
                                                                        padding: const EdgeInsets
                                                                            .only(
                                                                            left:
                                                                                10),
                                                                        child:
                                                                            FaIcon(
                                                                          isTenantExpanded
                                                                              ? FontAwesomeIcons.sortUp
                                                                              : FontAwesomeIcons.sortDown,
                                                                          size:
                                                                              20,
                                                                          color: isTenantExpanded
                                                                              ? blueColor
                                                                              : blueColor,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  Expanded(
                                                                      child:
                                                                          GestureDetector(
                                                                    onTap: () {
                                                                      setState(
                                                                          () {
                                                                        if (expandedTenantIndex[rowIndex] ==
                                                                            tenantIndex) {
                                                                          expandedTenantIndex[rowIndex] =
                                                                              null;
                                                                        } else {
                                                                          expandedTenantIndex[rowIndex] =
                                                                              tenantIndex;
                                                                        }
                                                                      });
                                                                    },
                                                                    child: Text(
                                                                      "${tenant.rentalData!.rentalAddress}",
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          color:
                                                                              blueColor),
                                                                    ),
                                                                  )),
                                                                  Expanded(
                                                                      child:
                                                                          Text(
                                                                    _transactionDate(
                                                                        tenant),
                                                                    // "${formatDate(tenant.createdAt.toString())}",
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color:
                                                                            blueColor),
                                                                  ))
                                                                ],
                                                              ),
                                                              if (isTenantExpanded)
                                                                Column(
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        SizedBox(
                                                                          width:
                                                                              20,
                                                                        ),
                                                                        Expanded(
                                                                          child:
                                                                              Table(
                                                                            columnWidths: {
                                                                              // 0: FixedColumnWidth(150.0), // Adjust width as needed
                                                                              // 1: FlexColumnWidth(),
                                                                              0: FlexColumnWidth(), // Distribute columns equally
                                                                              1: FlexColumnWidth(),
                                                                            },
                                                                            children: [
                                                                              _buildTableRow('Rental Owners Name:', _getDisplayValue(item.rentalOwnerName), 'Property:', _getDisplayValue(tenant.rentalData!.rentalAddress)),
                                                                              _buildTableRow('Tenant Name:', _getDisplayValue("${tenant.tenantData!.tenantFirstName} ${tenant.tenantData!.tenantLastName}"), 'Transaction Id', _getDisplayValue(tenant.transactionId)),
                                                                              _buildTableRow(
                                                                                  'Transaction Date:',
                                                                                  _getDisplayValue(
                                                                                    _transactionDate(tenant),
                                                                                    // formatDate(tenant
                                                                                    //     .createdAt
                                                                                    //     .toString())
                                                                                  ),
                                                                                  'Transaction Type:',
                                                                                  _getDisplayValue(tenant.paymentType)),
                                                                              _buildTableRow('Payment Details:', _getDisplayValue(_paymentDetails(tenant.ccType, tenant.ccNumber)), 'Payment Amount:', _getDisplayValue(formatCurrency(tenant.totalAmount))),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                    if (tenant
                                                                        .entry
                                                                        .isNotEmpty)
                                                                      Row(
                                                                        children: [
                                                                          const SizedBox(
                                                                            width:
                                                                                27,
                                                                          ),
                                                                          Text.rich(
                                                                            TextSpan(
                                                                              children: [
                                                                                TextSpan(
                                                                                  text: 'Details Line : ',
                                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    if (tenant
                                                                            .entry
                                                                            .isNotEmpty &&
                                                                        tenant.response !=
                                                                            "FAILURE")
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                    if (tenant
                                                                            .entry
                                                                            .isNotEmpty &&
                                                                        tenant.response !=
                                                                            "FAILURE")
                                                                      Padding(
                                                                        padding: const EdgeInsets
                                                                            .only(
                                                                            left:
                                                                                15,
                                                                            top:
                                                                                0),
                                                                        child:
                                                                            Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.start,
                                                                          children: [
                                                                            FaIcon(
                                                                              isTenantExpanded ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                              size: 20,
                                                                              color: Colors.transparent,
                                                                            ),
                                                                            Expanded(
                                                                              flex: 2,
                                                                              child: Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: <Widget>[
                                                                                  Text.rich(
                                                                                    TextSpan(
                                                                                      children: [
                                                                                        TextSpan(
                                                                                          text: 'Account : ',
                                                                                          style: TextStyle(
                                                                                            fontWeight: FontWeight.bold,
                                                                                            color: blueColor,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                            Expanded(
                                                                              flex: 2,
                                                                              child: Column(
                                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                                children: <Widget>[
                                                                                  Text.rich(
                                                                                    TextSpan(
                                                                                      children: [
                                                                                        TextSpan(
                                                                                          text: '  Amount : ',
                                                                                          style: TextStyle(
                                                                                            fontWeight: FontWeight.bold,
                                                                                            color: blueColor,
                                                                                          ),
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    if (tenant
                                                                            .entry
                                                                            .isNotEmpty &&
                                                                        tenant.response !=
                                                                            "FAILURE")
                                                                      Column(
                                                                        children: tenant
                                                                            .entry
                                                                            .map((entry) {
                                                                          return Padding(
                                                                            padding:
                                                                                const EdgeInsets.only(left: 15.0, bottom: 0),
                                                                            child:
                                                                                Row(
                                                                              mainAxisAlignment: MainAxisAlignment.start,
                                                                              children: [
                                                                                FaIcon(
                                                                                  isTenantExpanded ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                                  size: 20,
                                                                                  color: Colors.transparent,
                                                                                ),
                                                                                Expanded(
                                                                                  flex: 2,
                                                                                  child: Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: <Widget>[
                                                                                      Text.rich(
                                                                                        TextSpan(
                                                                                          children: [
                                                                                            TextSpan(
                                                                                              text: '${entry.account ?? "N/A"}',
                                                                                              style: TextStyle(
                                                                                                fontWeight: FontWeight.w700,
                                                                                                color: grey,
                                                                                              ),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                                SizedBox(
                                                                                  width: 15,
                                                                                ),
                                                                                Expanded(
                                                                                  flex: 2,
                                                                                  child: Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: <Widget>[
                                                                                      Text.rich(
                                                                                        TextSpan(
                                                                                          children: [
                                                                                            TextSpan(
                                                                                              text: ' ${formatCurrency(entry.amount)}',
                                                                                              style: TextStyle(
                                                                                                fontWeight: FontWeight.w700,
                                                                                                color: grey,
                                                                                              ),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                      // Add additional fields if needed
                                                                                    ],
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          );
                                                                        }).toList(),
                                                                      ),
                                                                    if (tenant
                                                                            .response ==
                                                                        "FAILURE")
                                                                      Text.rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Failed : Reason(${tenant.responseText}) ',
                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                  ],
                                                                ),
                                                              SizedBox(
                                                                height: 8,
                                                              ),
                                                              if (actualIndex <
                                                                  totalPayments -
                                                                      1)
                                                                Divider(
                                                                  thickness: 2,
                                                                )
                                                            ],
                                                          );
                                                        }).toList(),
                                                        // Pagination controls for payments
                                                        if (totalPayments >
                                                            paymentItemsPerPageValue)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        10,
                                                                    horizontal:
                                                                        16),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Row(
                                                                  children: [
                                                                    Material(
                                                                      elevation:
                                                                          2,
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                8.0),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          border:
                                                                              Border.all(color: Colors.grey),
                                                                          borderRadius:
                                                                              BorderRadius.circular(4.0),
                                                                        ),
                                                                        child:
                                                                            DropdownButtonHideUnderline(
                                                                          child:
                                                                              DropdownButton<int>(
                                                                            value:
                                                                                paymentItemsPerPageValue,
                                                                            items:
                                                                                [
                                                                              5,
                                                                              10,
                                                                              25,
                                                                              50,
                                                                              100
                                                                            ].map((int value) {
                                                                              return DropdownMenuItem<int>(
                                                                                value: value,
                                                                                child: Text(value.toString()),
                                                                              );
                                                                            }).toList(),
                                                                            onChanged:
                                                                                (newValue) {
                                                                              if (newValue != null) {
                                                                                setState(() {
                                                                                  paymentItemsPerPage[rowIndex] = newValue;
                                                                                  paymentCurrentPage[rowIndex] = 0; // Reset to first page
                                                                                });
                                                                              }
                                                                            },
                                                                            icon:
                                                                                const Icon(
                                                                              Icons.arrow_drop_down,
                                                                              size: 20,
                                                                            ),
                                                                            style:
                                                                                const TextStyle(color: Colors.black, fontSize: 14),
                                                                            dropdownColor:
                                                                                Colors.white,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            10),
                                                                    IconButton(
                                                                      icon:
                                                                          FaIcon(
                                                                        FontAwesomeIcons
                                                                            .circleChevronLeft,
                                                                        size:
                                                                            24,
                                                                        color: currentPaymentPage ==
                                                                                0
                                                                            ? Colors.grey
                                                                            : blueColor,
                                                                      ),
                                                                      onPressed: currentPaymentPage ==
                                                                              0
                                                                          ? null
                                                                          : () {
                                                                              setState(() {
                                                                                paymentCurrentPage[rowIndex] = currentPaymentPage - 1;
                                                                              });
                                                                            },
                                                                    ),
                                                                    Text(
                                                                      'Page ${currentPaymentPage + 1} of $totalPaymentPages',
                                                                      style: const TextStyle(
                                                                          fontSize:
                                                                              14),
                                                                    ),
                                                                    IconButton(
                                                                      icon:
                                                                          FaIcon(
                                                                        FontAwesomeIcons
                                                                            .circleChevronRight,
                                                                        size:
                                                                            24,
                                                                        color: currentPaymentPage >=
                                                                                totalPaymentPages - 1
                                                                            ? Colors.grey
                                                                            : blueColor,
                                                                      ),
                                                                      onPressed: currentPaymentPage >=
                                                                              totalPaymentPages - 1
                                                                          ? null
                                                                          : () {
                                                                              setState(() {
                                                                                paymentCurrentPage[rowIndex] = currentPaymentPage + 1;
                                                                              });
                                                                            },
                                                                    ),
                                                                  ],
                                                                ),
                                                                // Text(
                                                                //   ' ${(currentPaymentPage * paymentItemsPerPageValue) + 1}-${(currentPaymentPage * paymentItemsPerPageValue + paginatedPayments.length)} of $totalPayments',
                                                                //   style: TextStyle(
                                                                //       fontSize:
                                                                //           12,
                                                                //       color: Colors
                                                                //               .grey[
                                                                //           600]),
                                                                // ),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
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
                                  child: Material(
                                    elevation: 3,
                                    borderRadius: BorderRadius.circular(2),
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
                                          hintStyle: TextStyle(
                                              color: Color(0xFF8A95A8)),
                                        ),
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

  /// Single source for the Transaction Date column across every output —
  /// screen, PDF, Excel and CSV. Web does the same with one `formatDateTime`
  /// helper (Client/src/views/source/Rentalownerreport.js), which is why its
  /// four outputs agree. Here the exports each formatted the raw DateTime
  /// themselves, so the same payment read four different ways and ignored the
  /// account's chosen date format.
  String _transactionDate(Payment payment) {
    // Web parity (Rentalownerreport.js formatDateTime): a record with no date
    // reads "N/A" rather than borrowing today's date.
    final DateTime? raw = payment.createdAt;
    if (raw == null) return 'N/A';
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final String formatted = dateProvider.formatCurrentDate(raw.toString());
    return formatted.trim().isEmpty ? 'N/A' : formatted;
  }
  String _getDisplayValue(String? value) {
    // Return 'N/A' if the value is null or empty, otherwise return the value
    return (value == null || value.trim().isEmpty) ? 'N/A' : value;
  }

  /// Card type + masked number as one label. The model already substitutes
  /// 'N/A' for each field individually, so joining them blindly produced
  /// "N/A N/A" on non-card payments (cash, check). Only real values are
  /// joined; when neither is present this returns empty so the caller's
  /// _getDisplayValue renders a single 'N/A'.
  String _paymentDetails(String? ccType, String? ccNumber) {
    bool hasValue(String? v) =>
        v != null && v.trim().isNotEmpty && v.trim() != 'N/A';
    final parts = [ccType, ccNumber].where(hasValue).map((v) => v!.trim());
    return parts.join(' ');
  }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                SizedBox(height: 4.0), // Space between label and value
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
            padding: EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rightLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                SizedBox(height: 4.0), // Space between label and value
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

  List<String> selectedRentalOwnerIds = [];
  final ValueNotifier<List<String>> _selectedOwnersNotifier =
      ValueNotifier<List<String>>([]);
  final GlobalKey _dropdownButtonKey = GlobalKey();

  // Multi-select dropdown widget
  Widget _buildMultiSelectDropdown() {
    // Use selectedRentalOwnerIds directly for display text
    String displayText = selectedRentalOwnerIds.isEmpty
        ? 'Select Rental Owners'
        : selectedRentalOwnerIds.length == 1
            ? rentalowners.firstWhere(
                (owner) =>
                    owner['rentalowner_id'] == selectedRentalOwnerIds.first,
                orElse: () => {'rentalOwner_name': 'Unknown'},
              )['rentalOwner_name']
            : '${selectedRentalOwnerIds.length} owners selected';

    return ValueListenableBuilder<List<String>>(
      valueListenable: _selectedOwnersNotifier,
      builder: (context, currentSelected, _) {
        return Container(
          key: _dropdownButtonKey,
          width: MediaQuery.of(context).size.width > 500 ? 200 : 150,
          child: DropdownButtonHideUnderline(
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(8),
              child: DropdownButton2<String>(
                isExpanded: true,
                hint: Text(
                  displayText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                value: null, // Always null for multi-select
                items: rentalowners.map((owner) {
                  final ownerId = owner['rentalowner_id'];
                  final ownerName = owner['rentalOwner_name'];

                  return DropdownMenuItem<String>(
                    value: ownerId,
                    enabled: false,
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: _selectedOwnersNotifier,
                      builder: (context, currentSelectedList, _) {
                        // For "all" option, check if all individual owners are selected
                        final isCurrentlySelected = ownerId == "all"
                            ? rentalowners
                                .where((o) => o['rentalowner_id'] != "all")
                                .every((o) => currentSelectedList
                                    .contains(o['rentalowner_id']))
                            : currentSelectedList.contains(ownerId);

                        return InkWell(
                          onTap: () {
                            if (ownerId == "all") {
                              if (isCurrentlySelected) {
                                selectedRentalOwnerIds.clear();
                              } else {
                                // Select all owners (excluding "all" option)
                                selectedRentalOwnerIds = rentalowners
                                    .where((o) => o['rentalowner_id'] != "all")
                                    .map((o) => o['rentalowner_id'] as String)
                                    .toList();
                              }
                            } else {
                              selectedRentalOwnerIds.remove("all");
                              if (isCurrentlySelected) {
                                selectedRentalOwnerIds.remove(ownerId);
                              } else {
                                selectedRentalOwnerIds.add(ownerId);
                              }
                            }
                            _selectedOwnersNotifier.value =
                                List.from(selectedRentalOwnerIds);
                            setState(() {});
                          },
                          child: Row(
                            children: [
                              Checkbox(
                                value: isCurrentlySelected,
                                onChanged: (bool? value) {
                                  if (ownerId == "all") {
                                    if (value == true) {
                                      // Select all owners (excluding "all" option)
                                      selectedRentalOwnerIds = rentalowners
                                          .where((o) =>
                                              o['rentalowner_id'] != "all")
                                          .map((o) =>
                                              o['rentalowner_id'] as String)
                                          .toList();
                                    } else {
                                      selectedRentalOwnerIds.clear();
                                    }
                                  } else {
                                    selectedRentalOwnerIds.remove("all");
                                    if (value == true) {
                                      selectedRentalOwnerIds.add(ownerId);
                                    } else {
                                      selectedRentalOwnerIds.remove(ownerId);
                                    }
                                  }
                                  _selectedOwnersNotifier.value =
                                      List.from(selectedRentalOwnerIds);
                                  setState(() {});
                                },
                                activeColor: blueColor,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              Expanded(
                                child: Text(
                                  ownerName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isCurrentlySelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  // Do nothing - selection handled in item's InkWell
                },
                buttonStyleData: ButtonStyleData(
                  height: 45,
                  width: double.infinity,
                  padding: const EdgeInsets.only(left: 14, right: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8A95A8),
                    ),
                    color: Colors.white,
                  ),
                  elevation: 0,
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 250,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  offset: const Offset(0, 0),
                  scrollbarTheme: ScrollbarThemeData(
                    radius: const Radius.circular(20),
                    thickness: MaterialStateProperty.all(6),
                    thumbVisibility: MaterialStateProperty.all(true),
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  height: 40,
                  padding: EdgeInsets.only(left: 14, right: 14),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  filters({List<RentalOwnerReport>? data}) {
    return Padding(
      padding: EdgeInsets.only(
          left: MediaQuery.of(context).size.width > 500 ? 12 : 0,
          right: MediaQuery.of(context).size.width > 500 ? 12 : 0),
      child: Column(
        children: [
          SizedBox(
            height: 10,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildMultiSelectDropdown(),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    // width: 170,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.grey)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: chargeType,
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        hint: Text(
                          "Charge type",
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: "All",
                            child: Text('All'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'ACH',
                            child: Text('ACH'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Card',
                            child: Text('Card'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Cash',
                            child: Text('Cash'),
                          ),
                          DropdownMenuItem<String>(
                            value: "Cashier's Check",
                            child: Text("Cashier's Check"),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Check',
                            child: Text('Check'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Manual',
                            child: Text('Manual'),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Money Order',
                            child: Text('Money Order'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            chargeType = value;
                            // _futureRentersInsurance = fetchDelinquentTenantsData(
                            //     fromDate.text, toDate.text,
                            //     charge: value);
                          });
                          // Handle the selected charge type
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
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
                              Provider.of<DateProvider>(context, listen: false);
                          setState(() {
                            daterange = value;
                            DateTime now = DateTime.now();
                            customdate = false;

                            if (value == "Today") {
                              String todayApiFormat = DateFormat('yyyy-MM-dd')
                                  .format(DateTime.now());
                              fromDate.text = dateProvider
                                  .formatCurrentDate(todayApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(todayApiFormat);
                            } else if (value == "Yesterday") {
                              DateTime yesterday =
                                  now.subtract(Duration(days: 1));
                              String yesterdayApiFormat =
                                  DateFormat('yyyy-MM-dd').format(yesterday);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(yesterdayApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(yesterdayApiFormat);
                            } else if (value == "Last 7 Days") {
                              // Last 7 Days including today: subtract 6 days (not 7)
                              DateTime startDate =
                                  now.subtract(Duration(days: 6));
                              String startApiFormat =
                                  DateFormat('yyyy-MM-dd').format(startDate);
                              String endApiFormat =
                                  DateFormat('yyyy-MM-dd').format(now);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startApiFormat);
                              toDate.text =
                                  dateProvider.formatCurrentDate(endApiFormat);
                            } else if (value == "Last 14 Days") {
                              // Last 14 Days including today: subtract 13 days (not 14)
                              DateTime startDate =
                                  now.subtract(Duration(days: 13));
                              String startApiFormat =
                                  DateFormat('yyyy-MM-dd').format(startDate);
                              String endApiFormat =
                                  DateFormat('yyyy-MM-dd').format(now);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startApiFormat);
                              toDate.text =
                                  dateProvider.formatCurrentDate(endApiFormat);
                            } else if (value == "Last 30 Days") {
                              // Last 30 Days including today: subtract 29 days (not 30)
                              DateTime startDate =
                                  now.subtract(Duration(days: 29));
                              String startApiFormat =
                                  DateFormat('yyyy-MM-dd').format(startDate);
                              String endApiFormat =
                                  DateFormat('yyyy-MM-dd').format(now);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startApiFormat);
                              toDate.text =
                                  dateProvider.formatCurrentDate(endApiFormat);
                            } else if (value == "This Week") {
                              // Start of current week (Monday)
                              DateTime startOfWeek =
                                  now.subtract(Duration(days: now.weekday - 1));
                              // End of current week (Sunday)
                              DateTime endOfWeek =
                                  startOfWeek.add(Duration(days: 6));
                              String weekStartApiFormat =
                                  DateFormat('yyyy-MM-dd').format(startOfWeek);
                              String weekEndApiFormat =
                                  DateFormat('yyyy-MM-dd').format(endOfWeek);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(weekStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(weekEndApiFormat);
                            } else if (value == "Last Week") {
                              // Start of current week (Monday)
                              DateTime startOfCurrentWeek =
                                  now.subtract(Duration(days: now.weekday - 1));
                              // Start of last week (Monday of last week) - subtract 7 days from current week start
                              DateTime startOfLastWeek = startOfCurrentWeek
                                  .subtract(Duration(days: 7));
                              // End of last week (Sunday of last week)
                              DateTime endOfLastWeek =
                                  startOfLastWeek.add(Duration(days: 6));
                              String weekStartApiFormat =
                                  DateFormat('yyyy-MM-dd')
                                      .format(startOfLastWeek);
                              String weekEndApiFormat = DateFormat('yyyy-MM-dd')
                                  .format(endOfLastWeek);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(weekStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(weekEndApiFormat);
                            } else if (value == "This Month") {
                              String monthStartApiFormat =
                                  DateFormat('yyyy-MM-dd')
                                      .format(DateTime(now.year, now.month, 1));
                              String monthEndApiFormat =
                                  DateFormat('yyyy-MM-dd').format(
                                      DateTime(now.year, now.month + 1, 0));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(monthStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(monthEndApiFormat);
                            } else if (value == "Last Month") {
                              DateTime lastMonth =
                                  DateTime(now.year, now.month - 1, 1);
                              String monthStartApiFormat =
                                  DateFormat('yyyy-MM-dd').format(DateTime(
                                      lastMonth.year, lastMonth.month, 1));
                              String monthEndApiFormat =
                                  DateFormat('yyyy-MM-dd').format(DateTime(
                                      lastMonth.year, lastMonth.month + 1, 0));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(monthStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(monthEndApiFormat);
                            } else if (value == "This Quarter") {
                              int currentQuarter = ((now.month - 1) ~/ 3) + 1;
                              int quarterStartMonth =
                                  (currentQuarter - 1) * 3 + 1;
                              int quarterEndMonth = currentQuarter * 3;
                              String quarterStartApiFormat =
                                  DateFormat('yyyy-MM-dd').format(
                                      DateTime(now.year, quarterStartMonth, 1));
                              String quarterEndApiFormat =
                                  DateFormat('yyyy-MM-dd').format(DateTime(
                                      now.year, quarterEndMonth + 1, 0));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(quarterStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(quarterEndApiFormat);
                            } else if (value == "Last Quarter") {
                              int currentQuarter = ((now.month - 1) ~/ 3) + 1;
                              int lastQuarter =
                                  currentQuarter == 1 ? 4 : currentQuarter - 1;
                              int lastQuarterYear =
                                  currentQuarter == 1 ? now.year - 1 : now.year;
                              int quarterStartMonth = (lastQuarter - 1) * 3 + 1;
                              int quarterEndMonth = lastQuarter * 3;
                              String quarterStartApiFormat =
                                  DateFormat('yyyy-MM-dd').format(DateTime(
                                      lastQuarterYear, quarterStartMonth, 1));
                              String quarterEndApiFormat =
                                  DateFormat('yyyy-MM-dd').format(DateTime(
                                      lastQuarterYear, quarterEndMonth + 1, 0));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(quarterStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(quarterEndApiFormat);
                            } else if (value == "Year to Date") {
                              String yearStartApiFormat =
                                  DateFormat('yyyy-MM-dd')
                                      .format(DateTime(now.year, 1, 1));
                              String yearEndApiFormat =
                                  DateFormat('yyyy-MM-dd').format(now);
                              fromDate.text = dateProvider
                                  .formatCurrentDate(yearStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(yearEndApiFormat);
                            } else if (value == "Last Year") {
                              String yearStartApiFormat =
                                  DateFormat('yyyy-MM-dd')
                                      .format(DateTime(now.year - 1, 1, 1));
                              String yearEndApiFormat = DateFormat('yyyy-MM-dd')
                                  .format(DateTime(now.year - 1, 12, 31));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(yearStartApiFormat);
                              toDate.text = dateProvider
                                  .formatCurrentDate(yearEndApiFormat);
                            } else if (value == "Custom") {
                              customdate = true;
                            }

                            if (value != "Custom" && customdate == true) {
                              customdate = false;
                              fromDate.text = "";
                              toDate.text = "";
                            }
                            if (value != "Custom") {
                              // _futureRentersInsurance =
                              //     fetchDelinquentTenantsData(
                              //         fromDate.text, toDate.text);
                            }
                          });
                          // Handle the selected charge type
                        },
                        buttonStyleData: ButtonStyleData(
                          height: 42,
                          padding: const EdgeInsets.only(left: 14, right: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.white,
                          ),
                          elevation: 0,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 250,
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          offset: const Offset(-20, 0),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(40),
                            thickness: MaterialStateProperty.all(6),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 40,
                          padding: EdgeInsets.only(left: 14, right: 14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              //mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    // width: 110,
                    child: TextFormField(
                      controller: fromDate,
                      // enabled: customdate,
                      onTap: customdate
                          ? () {
                              _pickDate(context);
                            }
                          : null,
                      readOnly: true,
                      style: TextStyle(fontSize: 14, color: Colors.black),
                      textInputAction: TextInputAction.next,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10), //Imp Line
                        isDense: true,

                        hintText: "From",

                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: const BorderSide(
                              width: 1,
                            )),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Container(
                    // width: 110,
                    child: TextFormField(
                      controller: toDate,
                      // enabled: customdate,
                      style: TextStyle(fontSize: 14, color: Colors.black),
                      onTap: customdate
                          ? () {
                              _endDate(context);
                            }
                          : null,
                      readOnly: true,
                      textInputAction: TextInputAction.next,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10), //Imp Line
                        isDense: true,
                        hintText: "To",

                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(5),
                            borderSide: const BorderSide(
                              width: 0.5,
                            )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          if (_dateRangeError != null)
            ReportDateRangeErrorText(_dateRangeError!),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (showTableData)
                  Expanded(
                    child: SizedBox(
                      //  width: 100,
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                        ),
                        onPressed: () {},
                        child: PopupMenuButton<String>(
                          onSelected: (value) async {
                            // Export logic
                            if (value == 'PDF' && data != null) {
                              generateDelinquentTenantsPdf(data);
                            } else if (value == 'XLSX' && data != null) {
                              generateRentalOwnerReportExcel(data);
                              //generateDelinquentTenantsExcel(data);
                            } else if (value == 'CSV' && data != null) {
                              generateRentalOwnerReportCsv(data);
                              //  generateDelinquentTenantsCsv(data);
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
                                  : Text('Export'),
                              Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!showTableData) Spacer(),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    //  width: 100,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        disabledBackgroundColor: blueColor.withOpacity(0.6),
                        disabledForegroundColor: Colors.white,
                      ),
                      onPressed: _dateRangeError != null ? null : () async {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        setState(() {
                          showTableData =
                              true; // Set to true when the button is pressed
                        });

                        // Convert formatted dates back to API format (yyyy-MM-dd)
                        String apiFromDate = formatDate(fromDate.text);
                        String apiToDate = formatDate(toDate.text);

                        _futureRentersInsurance = fetchDelinquentTenantsData(
                            apiFromDate, apiToDate); // Call the API
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          isAddLoading
                              ? const Center(
                                  child: SpinKitFadingCircle(
                                    color: Colors.white,
                                    size: 21.0,
                                  ),
                                )
                              : Text('Run'),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
