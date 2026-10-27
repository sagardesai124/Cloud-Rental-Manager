import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
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
import 'package:three_zero_two_property/Model/AccountTotalsReports.dart';
import 'package:three_zero_two_property/Model/DelinquentTenantsModel.dart';
import 'package:three_zero_two_property/Model/RentarsInsuranceModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/StaffModule/repository/AccountTotalsReports.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/repository/DelinquentTenantsService.dart';
import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/RentersInsuranceService.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';

import '../../../repository/rentalownerreport.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../widgets/staff_report_header.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class AccountTotalsReports extends StatefulWidget {
  const AccountTotalsReports({super.key});

  @override
  State<AccountTotalsReports> createState() => _AccountTotalsReportsState();
}

class _AccountTotalsReportsState extends State<AccountTotalsReports>
    with NetworkRetryState {
  late Future<List<AccountTotalsReport>> _futureAccountTotals;
  List<AccountTotalsReport> DelinquentTenantsModel = [];
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
    // Initialize notifier with empty list
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
    // fetchpdfrentalowner(); // this for pdf
    fetchReport();
  }

  Future<void> fetchpdfrentalowner() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiGet(
        Uri.parse('${Api_url}/api/rental_owner/accounts-report/$id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
        });
    final jsonData = json.decode(response.body);
    if (response.statusCode == 200) {
      setState(() {
        rentalowners = (jsonDecode(response.body) as List)
            .map((e) => e as Map<String, dynamic>)!
            .toList();
      });
      log(rentalowners.toString());
    } else {
      throw Exception('Failed to load data');
    }
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
      fromDate.text = dateProvider.formatCurrentDate(DateTime.now().toString());
      toDate.text = dateProvider.formatCurrentDate(DateTime.now().toString());
    });
    DateTime time = DateTime.now();
    DateTime date = DateFormat('yyyy-MM-dd').parse(time.toString());
    _futureAccountTotals = fetchAccountTotalsReportsData(
        formatDate(dateProvider.formatCurrentDate(date.toString())),
        formatDate(dateProvider.formatCurrentDate(date.toString())),
        rentalownerids: selectedOwners.isEmpty ? null : selectedOwners);
  }

  Future<List<AccountTotalsReport>> fetchAccountTotalsReportsData(
    String fromDate,
    String toDate, {
    String? rentalownerid,
    List<String>? rentalownerids,
  }) async {
    // Remember this exact call so Retry can replay it unchanged.
    _lastFetchCall = () => fetchAccountTotalsReportsData(fromDate, toDate,
        rentalownerid: rentalownerid, rentalownerids: rentalownerids);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      // String? chargedata = chargeType == "All" ? null : chargeType;

      // Handle multiple owner IDs - use first selected or null if all/empty
      String? ownerIdToUse;
      if (rentalownerids != null && rentalownerids.isNotEmpty) {
        // Check if "all" is selected by comparing count (all owners selected = all)
        // Get count of actual owners (excluding "all" option)
        int totalOwnersCount =
            rentalowners.where((o) => o['rentalowner_id'] != "all").length;


        // If all owners are selected or list contains "all", use null to get all data
        if (rentalownerids.contains("all") ||
            rentalownerids.length >= totalOwnersCount) {
          ownerIdToUse = null; // Get all owners' data
        } else {
          // Use first selected owner ID (or modify service to accept multiple)
          ownerIdToUse = rentalownerids.first;
        }
      } else {
        ownerIdToUse = rentalownerid;
      }

      String formattedFromDate = reverseFormatDate(fromDate);
      String formattedToDate = reverseFormatDate(toDate);

      List<AccountTotalsReport> data =
          await AccountTotalsReportsServices().fetchAccountTotalsReports(
        id!,
        formattedFromDate,
        formattedToDate,
        rentalownerid: ownerIdToUse,
      );

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
                'Failed to load account totals data. Please try again later.');
      });
      // Rethrow so the FutureBuilder reports hasError: a failed fetch must not
      // be presented as a report that legitimately has no rows.
      rethrow;
    }
  }

  // Remembers the exact fetch the screen last ran so Retry replays it with the
  // user's current filter selections rather than resetting them.
  Future<List<AccountTotalsReport>> Function()? _lastFetchCall;

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
      _futureAccountTotals = call();
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
      List<AccountTotalsReport> delinquentTenantsData) async {
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
                    'Account Totals Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date: ${fromDate.text} to ${toDate.text}',
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
                  'Rental Owner',
                  'Account',
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Amount',
                      style: pw.TextStyle(color: PdfColors.white),
                    ),
                  ),
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
                border: null),
            //pw.Divider(thickness: 3),
            // pw.Padding(
            //     padding: pw.EdgeInsets.symmetric(horizontal: 5),
            //     child: pw.Row(
            //         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            //         children: [
            //           pw.Text('Grand Total',
            //               style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            //           pw.Text('\$${grandtotal.toStringAsFixed(2)}',
            //               style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
            //         ])),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Account_totals_report.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Account_totals_report',
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> generateAccountTotalReportExcel(
      List<AccountTotalsReport> rentalOwnerReports) async {
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    // Set column widths
    sheet.getRangeByName('A1:C1').columnWidth = 20;

    final List<String> headers = ['Rental Owner', 'Account', 'Amount'];

    // Header cell style
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#5A86D5';
    headerCellStyle.fontColor = '#FFFFFF';
    headerCellStyle.fontSize = 16;
    headerCellStyle.hAlign = syncXlsx.HAlignType.center;

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

    for (var owner in rentalOwnerReports) {
      // Rental Owner Name
      final rentalOwnerCell = sheet.getRangeByIndex(rowIndex, 1);
      rentalOwnerCell.setText(owner.rentalOwnerName ?? '');
      rentalOwnerCell.cellStyle.bold = true;
      sheet.getRangeByName('A$rowIndex:C$rowIndex').merge();
      rowIndex++;

      for (var property in owner.payments) {
        // Account
        sheet.getRangeByIndex(rowIndex, 1).setText('');
        sheet.getRangeByIndex(rowIndex, 2).setText(property.account ?? 'N/A');
        sheet.getRangeByIndex(rowIndex, 3).setNumber(property.amount);
        sheet.getRangeByIndex(rowIndex, 3).cellStyle =
            currencyCellStyle; // Apply currency style
        rowIndex++;
      }

      // Subtotal
      if (owner.rentalOwnerName != 'Grand Totals') {
        sheet.getRangeByIndex(rowIndex, 1).setText('');
        sheet.getRangeByIndex(rowIndex, 2).setText('Subtotal');
        sheet.getRangeByIndex(rowIndex, 2).cellStyle.bold = true;
        // sheet.getRangeByIndex(rowIndex, 2).setText(''); // Empty for Account
        sheet.getRangeByIndex(rowIndex, 3).setNumber(owner.subTotal ?? 0.0);
        sheet.getRangeByIndex(rowIndex, 3).cellStyle =
            boldAmountStyle; // Apply bold amount style
        rowIndex++;
      }

      grandTotal += owner.subTotal ?? 0.0;
    }

    // Grand Total
    // sheet.getRangeByIndex(rowIndex, 1).setText('Grand Total');
    // sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
    // sheet.getRangeByIndex(rowIndex, 2).setText(''); // Empty for Account
    // sheet.getRangeByIndex(rowIndex, 3).setNumber(grandTotal);
    // sheet.getRangeByIndex(rowIndex, 3).cellStyle = boldAmountStyle; // Apply bold amount style

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Account_totals_report_$formattedDate.xlsx';

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
      List<AccountTotalsReport> rentalOwnerReports) async {
    // Define headers for CSV
    final List<String> headers = ['Rental Owner', 'Account', 'Amount'];

    // Create a buffer to store CSV data
    final StringBuffer csvBuffer = StringBuffer();

    // Add headers to the CSV file
    csvBuffer.writeln(csvRow(headers));

    double grandTotal = 0.0;

    // Iterate through each rental owner report
    for (var owner in rentalOwnerReports) {
      // Add rental owner name as a row
      csvBuffer.writeln('${owner.rentalOwnerName ?? ''}');

      // Iterate through each property for the current rental owner
      for (var property in owner.payments) {
        // Add property and tenant details
        csvBuffer.writeln(csvRow([
          '',
          property.account,
          property.amount ?? 0 / 0,
        ]));

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
      if (owner.rentalOwnerName != 'Grand Totals')
        csvBuffer.writeln(csvRow([
          '',
          'Subtotal ',
          '${(owner.subTotal ?? 0.0).toStringAsFixed(2)}'
        ]));

      // Accumulate grand total
      grandTotal += owner.subTotal ?? 0.0;
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
    Share.shareXFiles([XFile(path)]);
    // Show success toast message
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

//for table data of pdf
  List<List<dynamic>> _generateTableData(
      List<AccountTotalsReport> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];
    double total = 0.0;

    for (var owner in rentalOwnerReports) {
      // Main row for the rental owner name
      bool hasPayments = owner.payments.isNotEmpty;

      if (hasPayments) {
        // Add the first payment with the owner's name
        bool isJohnDoeAdded = false; // Flag to check if John Doe has been added
        for (var i = 0; i < owner.payments.length; i++) {
          var property = owner.payments[i];
          if (i == 0 &&
              owner.rentalOwnerName == 'John Doe' &&
              !isJohnDoeAdded) {
            // Add John Doe's name only for the first payment
            tableData.add([
              pw.Text(owner.rentalOwnerName,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.normal, fontSize: 10)),
              pw.Text(property.account,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.normal, fontSize: 10)),
              pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(formatCurrency(property.amount),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.normal, fontSize: 10))),
            ]);
            isJohnDoeAdded = true; // Set the flag to true after adding
          } else if (i == 0) {
            // Add the rental owner's name only for the first payment of other owners
            tableData.add([
              pw.Text(owner.rentalOwnerName,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.normal, fontSize: 10)),
              pw.Text(property.account,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.normal, fontSize: 10)),
              pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(formatCurrency(property.amount),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.normal, fontSize: 10))),
            ]);
          } else {
            // For subsequent payments, leave the owner's name empty
            tableData.add([
              pw.Text('',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.normal, fontSize: 10)),
              // Empty for Rental Owner Name
              pw.Text(property.account,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.normal, fontSize: 10)),
              pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(formatCurrency(property.amount),
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.normal, fontSize: 10))),
            ]);
          }
        }
      }

      // Subtotal row for the rental owner
      if (owner.rentalOwnerName != 'Grand Totals')
        tableData.add([
          pw.Text('',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text('Subtotal ',
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  formatMoney(owner.subTotal ?? 0.0), // Subtotal formatted to 2 decimal places
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10),
                  textAlign: pw.TextAlign.right // Align text to the right
                  )),
        ]);
      total += owner.subTotal;
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
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      setState(() {
        _selectedDate = picked;
        fromDate.text = dateProvider.formatCurrentDate(picked.toString());
        // Removed automatic data fetch - data will only load when Run button is clicked
        // _futureAccountTotals = fetchAccountTotalsReportsData(
        //     formatDate(fromDate.text), formatDate(toDate.text));
      });

      // Notify the FormField state of the change
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
            buttonTheme: ButtonThemeData(
              textTheme: ButtonTextTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      setState(() {
        _selectedDate = picked;
        toDate.text = dateProvider.formatCurrentDate(picked.toString());
        // Removed automatic data fetch - data will only load when Run button is clicked
        // _futureAccountTotals = fetchAccountTotalsReportsData(
        //     formatDate(fromDate.text), formatDate(toDate.text));
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

        // Sort rental owners alphabetically by name (excluding "All" option)
        rentalowners.sort((a, b) {
          String nameA = a['rentalOwner_name']?.toString().toLowerCase() ?? '';
          String nameB = b['rentalOwner_name']?.toString().toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });

        // Insert "All" option at the beginning after sorting
        rentalowners.insert(0, {
          "rentalowner_id": "all",
          "rentalOwner_name": "All",
        });
      });
      log(' rentalowners ${rentalowners.toString()}');
    } else {
      throw Exception('Failed to load data');
    }
  }

  TextEditingController fromDate = TextEditingController();
  TextEditingController toDate = TextEditingController();
  /// Web's From/To check (null when the range is fine).
  String? get _dateRangeError =>
      reportDateRangeError(fromDate.text, toDate.text);
  String? daterange;
  String? chargeType;
  String? selectedrenatalownerid;

  // Multi-select dropdown variables
  List<String> selectedOwners = [];
  final ValueNotifier<List<String>> _selectedOwnersNotifier =
      ValueNotifier<List<String>>([]);
  final GlobalKey _dropdownButtonKey = GlobalKey();
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
                    title: "Account Totals Reports",
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width < 500)
                  FutureBuilder<List<AccountTotalsReport>>(
                    future: _futureAccountTotals,
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
                                        "assets/images/no_data_transparent.png",
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
                              const SizedBox(height: 10),
                              _buildHeaders(),
                              const SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.only(
                                    left:
                                        MediaQuery.of(context).size.width > 500
                                            ? 12
                                            : 0,
                                    right:
                                        MediaQuery.of(context).size.width > 500
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
                                      AccountTotalsReport rental = entry.value;

                                      return Container(
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
                                                          '${item.rentalOwnerName ?? '-'}',
                                                          style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                              Column(
                                                children: [
                                                  Column(
                                                    children: item.payments!
                                                        .asMap()
                                                        .entries
                                                        .map((tenantEntry) {
                                                      int tenantIndex =
                                                          tenantEntry.key;
                                                      var tenant =
                                                          tenantEntry.value;
                                                      bool isTenantExpanded =
                                                          expandedTenantIndex[
                                                                  rowIndex] ==
                                                              tenantIndex;

                                                      return Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              SizedBox(
                                                                width: 25,
                                                              ),
                                                              Expanded(
                                                                  child:
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
                                                                child: Text(
                                                                  "${tenant.account}",
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          blueColor),
                                                                ),
                                                              )),
                                                              Expanded(
                                                                  child:
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
                                                                child: Text(
                                                                  formatCurrency(
                                                                      tenant
                                                                          .amount),
                                                                  style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          blueColor),
                                                                ),
                                                              )),
                                                            ],
                                                          ),
                                                          SizedBox(
                                                            height: 10,
                                                          ),
                                                        ],
                                                      );
                                                    }).toList(),
                                                  ),
                                                  if (item.rentalOwnerName !=
                                                      'Grand Totals')
                                                    Row(
                                                      children: [
                                                        SizedBox(
                                                          width: 25,
                                                        ),
                                                        Expanded(
                                                            child: Text(
                                                          "Sub Total",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: blueColor,
                                                            fontSize: 15,
                                                          ),
                                                        )),
                                                        Expanded(
                                                            child: Text(
                                                          formatCurrency(
                                                              item.subTotal),
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: blueColor,
                                                            fontSize: 15,
                                                          ),
                                                        )),
                                                      ],
                                                    ),
                                                  SizedBox(
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

  // Multi-select dropdown widget
  Widget _buildMultiSelectDropdown() {
    // Use selectedOwners directly for display text
    String displayText = selectedOwners.isEmpty
        ? 'Select Rental Owners'
        : selectedOwners.length == 1
            ? rentalowners.firstWhere(
                (owner) => owner['rentalowner_id'] == selectedOwners.first,
                orElse: () => {'rentalOwner_name': 'Unknown'},
              )['rentalOwner_name']
            : '${selectedOwners.length} owners selected';

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
                                selectedOwners.clear();
                              } else {
                                // Select all owners (excluding "all" option)
                                selectedOwners = rentalowners
                                    .where((o) => o['rentalowner_id'] != "all")
                                    .map((o) => o['rentalowner_id'] as String)
                                    .toList();
                              }
                            } else {
                              selectedOwners.remove("all");
                              if (isCurrentlySelected) {
                                selectedOwners.remove(ownerId);
                              } else {
                                selectedOwners.add(ownerId);
                              }
                            }
                            _selectedOwnersNotifier.value =
                                List.from(selectedOwners);
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
                                      selectedOwners = rentalowners
                                          .where((o) =>
                                              o['rentalowner_id'] != "all")
                                          .map((o) =>
                                              o['rentalowner_id'] as String)
                                          .toList();
                                    } else {
                                      selectedOwners.clear();
                                    }
                                  } else {
                                    selectedOwners.remove("all");
                                    if (value == true) {
                                      selectedOwners.add(ownerId);
                                    } else {
                                      selectedOwners.remove(ownerId);
                                    }
                                  }
                                  _selectedOwnersNotifier.value =
                                      List.from(selectedOwners);
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

  filters({List<AccountTotalsReport>? data}) {
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
                // Multi-select Dropdown for Rental Owners
                Expanded(
                  child: _buildMultiSelectDropdown(),
                ),
                // Expanded(
                //   child: Container(
                //     height: 42,
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(5),
                //       border: Border.all(color: Colors.grey),
                //     ),
                //     child: DropdownButtonHideUnderline(
                //       child: DropdownButton<String>(
                //         value: selectedrenatalownerid,
                //         padding: EdgeInsets.symmetric(horizontal: 5),
                //         hint: Text(
                //           "Rental Owner",
                //           style: TextStyle(fontSize: 14, color: Colors.black),
                //         ),
                //         items: rentalowners.isNotEmpty
                //             ? rentalowners.map((property) {
                //           return DropdownMenuItem<String>(
                //             value: property['rentalowner_id'] ?? '', // Handle null
                //             child: Container(
                //               width: MediaQuery.of(context).size.width * .34,
                //               child: Text(
                //                 property['rentalOwner_name'] ?? 'Unknown', // Handle null
                //                 style: const TextStyle(
                //                   fontSize: 14,
                //                   fontWeight: FontWeight.w400,
                //                   color: Colors.black87,
                //                 ),
                //                 overflow: TextOverflow.ellipsis,
                //               ),
                //             ),
                //           );
                //         }).toList()
                //             : [
                //           DropdownMenuItem<String>(
                //             value: null,
                //             child: Text(
                //               'No Rental Owners Available',
                //               style: TextStyle(color: Colors.grey),
                //             ),
                //           ),
                //         ],
                //         onChanged: (value) {
                //           setState(() {
                //             selectedrenatalownerid = value;
                //             _futureAccountTotals = fetchAccountTotalsReportsData(
                //               fromDate.text,
                //               toDate.text,
                //               rentalownerid: value,
                //             );
                //           });
                //           // Handle the selected rental owner
                //           print(value);
                //         },
                //       ),
                //     ),
                //   ),
                // ),
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
                              fromDate.text = dateProvider
                                  .formatCurrentDate(DateTime.now().toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(DateTime.now().toString());
                            } else if (value == "Yesterday") {
                              DateTime yesterday =
                                  now.subtract(Duration(days: 1));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(yesterday.toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(yesterday.toString());
                            } else if (value == "Last 7 Days") {
                              // Last 7 Days including today: subtract 6 days (not 7)
                              DateTime startDate =
                                  now.subtract(Duration(days: 6));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startDate.toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(now.toString());
                            } else if (value == "Last 14 Days") {
                              // Last 14 Days including today: subtract 13 days (not 14)
                              DateTime startDate =
                                  now.subtract(Duration(days: 13));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startDate.toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(now.toString());
                            } else if (value == "Last 30 Days") {
                              // Last 30 Days including today: subtract 29 days (not 30)
                              DateTime startDate =
                                  now.subtract(Duration(days: 29));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startDate.toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(now.toString());
                            } else if (value == "This Week") {
                              // Start of current week (Monday)
                              DateTime startOfWeek =
                                  now.subtract(Duration(days: now.weekday - 1));
                              // End of current week (Sunday)
                              DateTime endOfWeek =
                                  startOfWeek.add(Duration(days: 6));
                              fromDate.text = dateProvider
                                  .formatCurrentDate(startOfWeek.toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(endOfWeek.toString());
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
                              fromDate.text = dateProvider.formatCurrentDate(
                                  startOfLastWeek.toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(endOfLastWeek.toString());
                            } else if (value == "This Month") {
                              fromDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year, now.month, 1).toString());
                              toDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year, now.month + 1, 0)
                                      .toString());
                            } else if (value == "Last Month") {
                              DateTime lastMonth =
                                  DateTime(now.year, now.month - 1, 1);
                              fromDate.text = dateProvider.formatCurrentDate(
                                  DateTime(lastMonth.year, lastMonth.month, 1)
                                      .toString());
                              toDate.text = dateProvider.formatCurrentDate(
                                  DateTime(lastMonth.year, lastMonth.month + 1,
                                          0)
                                      .toString());
                            } else if (value == "This Quarter") {
                              int currentQuarter = ((now.month - 1) ~/ 3) + 1;
                              int quarterStartMonth =
                                  (currentQuarter - 1) * 3 + 1;
                              int quarterEndMonth = currentQuarter * 3;
                              fromDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year, quarterStartMonth, 1)
                                      .toString());
                              toDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year, quarterEndMonth + 1, 0)
                                      .toString());
                            } else if (value == "Last Quarter") {
                              int currentQuarter = ((now.month - 1) ~/ 3) + 1;
                              int lastQuarter =
                                  currentQuarter == 1 ? 4 : currentQuarter - 1;
                              int lastQuarterYear =
                                  currentQuarter == 1 ? now.year - 1 : now.year;
                              int quarterStartMonth = (lastQuarter - 1) * 3 + 1;
                              int quarterEndMonth = lastQuarter * 3;
                              fromDate.text = dateProvider.formatCurrentDate(
                                  DateTime(
                                          lastQuarterYear, quarterStartMonth, 1)
                                      .toString());
                              toDate.text = dateProvider.formatCurrentDate(
                                  DateTime(lastQuarterYear, quarterEndMonth + 1,
                                          0)
                                      .toString());
                            } else if (value == "Year to Date") {
                              fromDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year, 1, 1).toString());
                              toDate.text = dateProvider
                                  .formatCurrentDate(now.toString());
                            } else if (value == "Last Year") {
                              fromDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year - 1, 1, 1).toString());
                              toDate.text = dateProvider.formatCurrentDate(
                                  DateTime(now.year - 1, 12, 31).toString());
                            } else if (value == "Custom") {
                              customdate = true;
                            }

                            if (value != "Custom" && customdate == true) {
                              customdate = false;
                              fromDate.text = "";
                              toDate.text = "";
                            }
                            // Removed automatic data fetch - data will only load when Run button is clicked
                            // if (value != "Custom") {
                            //   _futureAccountTotals =
                            //       fetchAccountTotalsReportsData(
                            //           formatDate(fromDate.text),
                            //           formatDate(toDate.text),
                            //           rentalownerids: selectedOwners.isEmpty
                            //               ? null
                            //               : selectedOwners);
                            //   print('custom ${value}');
                            // }
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
                // Run Report Button
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    height: 42,
                    width: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white,
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.all(8.0),
                      icon: FaIcon(
                        FontAwesomeIcons.circlePlay,
                        // Greyed like the other reports' disabled Run.
                        color: _dateRangeError != null
                            ? blueColor.withOpacity(0.6)
                            : blueColor,
                      ),
                      onPressed: _dateRangeError != null ? null : () {
                        // Validate dates before fetching
                        if (fromDate.text.isEmpty || toDate.text.isEmpty) {
                          return;
                        }

                        setState(() {
                          _futureAccountTotals = fetchAccountTotalsReportsData(
                              formatDate(fromDate.text),
                              formatDate(toDate.text),
                              rentalownerids: selectedOwners.isEmpty
                                  ? null
                                  : selectedOwners);
                        });
                      },
                      tooltip: "Run Report",
                    ),
                  ),
                ),
                Expanded(
                  // No rows yet: Export stays in place, greyed and disabled.
                  child: SizedBox(
                    //  width: 100,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        disabledBackgroundColor: Colors.grey.shade400,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                      ),
                      onPressed: (data?.isNotEmpty ?? false) ? () {} : null,
                      child: PopupMenuButton<String>(
                        enabled: data?.isNotEmpty ?? false,
                        onSelected: (value) async {
                          // Export logic
                          if (value == 'PDF' && data != null) {
                            generateAccountTotalReportPdf(data);
                          } else if (value == 'XLSX' && data != null) {
                            generateAccountTotalReportExcel(data);
                          } else if (value == 'CSV' && data != null) {
                            generateAccountTotalReportCsv(data);
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
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
