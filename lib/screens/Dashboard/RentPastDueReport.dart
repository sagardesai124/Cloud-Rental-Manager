import 'dart:async';
import 'dart:developer';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/DelinquentTenantsModel.dart';
import 'package:three_zero_two_property/Model/RentPastDueModel.dart';
import 'package:three_zero_two_property/Model/RentarsInsuranceModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/repository/DelinquentTenantsService.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/RentPastDue.dart';
import 'package:three_zero_two_property/repository/RentersInsuranceService.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as staff_appbar;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/summery_page.dart';
import '../../../model/properties.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';

import '../../../repository/rentalownerreport.dart';
import '../../../widgets/custom_drawer.dart';
import '../Leasing/RentalRoll/SummeryPageLease.dart' as admin_lease;
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart'
    as staff_lease;

class RentPastDueReports extends StatefulWidget {
  bool? isRentdue;
  String? title;
  /// Staff dashboard: same logo app bar + staff drawer with Dashboard highlighted (not Reports).
  final bool fromStaffModule;

  RentPastDueReports({
    super.key,
    this.isRentdue,
    this.title,
    this.fromStaffModule = false,
  });

  @override
  State<RentPastDueReports> createState() => _RentPastDueReportsState();
}

class _RentPastDueReportsState extends State<RentPastDueReports>
    with NetworkRetryState {
  late Future<RentPastDue> futurePastRentDue;
  List<RentPastDue> DelinquentTenantsModel = [];
  bool isLoading = true;
  String? errorMessage;
  int? expandedRowIndex;
  Map<int, int?> expandedTenantIndex = {};

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    fromDate.dispose();
    toDate.dispose();
    super.dispose();
  }
  /// Required by [NetworkRetryState]: re-issue this screen's own load,
  /// called by the Retry button and when the connection comes back.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    // The same three loads initState issues; chargeType and the date fields
    // are left untouched so a reload keeps the user's current view.
    fetchRentalOwners();
    fetchReport();
    setState(() {
      futurePastRentDue = fetchRentPastDueData(report: true);
    });
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
    fetchRentalOwners();
    // fetchpdfrentalowner(); // this for pdf
    fetchReport();
    chargeType = widget.isRentdue == true ? "Payment" : "Charges";
    // Initialize future with pagination parameters
    futurePastRentDue = fetchRentPastDueData(report: true);
  }

  bool _hasSetInitialValues = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasSetInitialValues) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          monthType = args['monthType'] ?? monthType;
          chargeType = args['chargeType'] ?? chargeType;
        });
      }
      _hasSetInitialValues = true;
    }
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back (reliably so on the
    // iOS simulator), which made this screen declare itself offline
    // while requests actually succeed. Confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  fetchReport() async {
    setState(() {
      daterange = "Today";
      fromDate.text = formatDate(DateTime.now().toString());
      toDate.text = formatDate(DateTime.now().toString());
    });
    DateTime time = DateTime.now();
    DateTime date = DateFormat('yyyy-MM-dd').parse(time.toString());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Reset to page 1 when fetching report
    currentPage = 1;
    futurePastRentDue = fetchRentPastDueData(report: true);
  }

  Future<RentPastDue> fetchRentPastDueData(
      {String? adminid, bool report = false}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      // Map chargeType to API type parameter
      String? apiType;
      if (chargeType == 'Payment') {
        apiType = 'Payments';
      } else if (chargeType == 'Charges') {
        apiType = 'Charges';
      }

      // Map monthType to API month parameter
      String? apiMonth;
      if (monthType == 'Current Month') {
        apiMonth = 'Current Month';
      } else if (monthType == 'Last Month') {
        apiMonth = 'Last Month';
      } else if (monthType == 'All') {
        apiMonth = 'All';
      }

      RentPastDue data = await AdminBalanceRepository().fetchAdminBalance(
        report: true,
        type: apiType,
        month: apiMonth,
        page: currentPage,
        limit: itemsPerPage,
        // The report is paginated server-side, so the search has to go with
        // it. Filtering the page the server had already returned could only
        // ever match rows the user was standing on, and left the pager and
        // the total reading the unfiltered figures.
        search: searchvalue,
        sortKey: sortKey,
        sortOrder: sortOrder,
      );

      setState(() {
        isLoading = false;
        errorMessage = null; // Reset error message on successful data fetch
      });
      return data;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Failed to load rent past due data. Please try again later.';
      });
      return RentPastDue();
    }
  }

  // Method to refresh data when filters change
  void refreshData() {
    setState(() {
      isLoading = true;
      currentPage = 1; // Reset to first page when filters change
    });
    // Fetch new data with current pagination parameters
    futurePastRentDue = fetchRentPastDueData(report: true);
  }

  double grandtotal = 0.0;
  List<DelinquentTenantsData> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String searchvalue = "";
  // Without a controller the field could not be cleared in code, so resetting
  // `searchvalue` when a filter changed left the typed word on screen while
  // every row was showing.
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  /// Search now round-trips to the server, so hold off until typing settles.
  void _onSearchChanged(String value) {
    setState(() {
      searchvalue = value;
    });
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        currentPage = 1; // a new search starts from the first page
      });
      refreshData();
    });
  }

  /// Clears the box as well as the value — used when a filter dropdown changes.
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    searchvalue = "";
  }
  String? selectedValue;

  int totalrecords = 0;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 1; // Changed to 1 for backend pagination (1-indexed)
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [10, 25, 50, 100];
  String? sortKey = 'property'; // Default sort key
  String? sortOrder = 'asc'; // Default sort order

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
                size: 15,
              ),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    // Toggle sort order: if already sorting by property, toggle asc/desc
                    if (sortKey == 'property') {
                      sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
                    } else {
                      // Set sort key to property and default to asc
                      sortKey = 'property';
                      sortOrder = 'asc';
                    }
                    // Reset to first page when sorting changes
                    currentPage = 1;
                    isLoading = true;
                  });
                  // Fetch new data with updated sort parameters
                  refreshData();
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
                    const SizedBox(width: 3),
                    // Show sort indicator if sorting by property
                    if (sortKey == 'property')
                      sortOrder == 'asc'
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
              flex: 2,
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
                    // SizedBox(width: 28),
                    Text("Tenant",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
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
                    SizedBox(width: 12),
                    Text("Amount",
                    
                      style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    // SizedBox(width: 5),
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
    //print'Fetching delinquent tenants');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? staffId = prefs.getString("staff_id");
    String? headerId = staffId ?? adminId;
    String? token = prefs.getString('token');

    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/charge/delinquent/$adminId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $headerId",
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
      //print'Error fetching data: $e');
      return null;
    }
  }

  bool istenantDataLoading = false;
  bool customdate = false;

  bool _profileFieldNonEmpty(String? s) =>
      s != null && s.trim().isNotEmpty;

  /// Rent Due / past-due PDF header (top-right): only non-empty fields — no N/A lines.
  List<pw.Widget> _buildPdfCompanyHeaderWidgets(profile? p) {
    if (p == null) return [];
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final children = <pw.Widget>[];
    if (_profileFieldNonEmpty(p.companyName)) {
      children.add(pw.Text(p.companyName!.trim(), style: style));
    }
    if (_profileFieldNonEmpty(p.companyAddress)) {
      children.add(pw.Text(p.companyAddress!.trim(), style: style));
    }
    final cityStateCountry = <String>[];
    if (_profileFieldNonEmpty(p.companyCity)) {
      cityStateCountry.add(p.companyCity!.trim());
    }
    if (_profileFieldNonEmpty(p.companyState)) {
      cityStateCountry.add(p.companyState!.trim());
    }
    if (_profileFieldNonEmpty(p.companyCountry)) {
      cityStateCountry.add(p.companyCountry!.trim());
    }
    if (cityStateCountry.isNotEmpty) {
      children.add(pw.Text(cityStateCountry.join(', '), style: style));
    }
    if (_profileFieldNonEmpty(p.companyPostalCode)) {
      children.add(pw.Text(p.companyPostalCode!.trim(), style: style));
    }
    return children;
  }

  Future<void> generateDelinquentTenantsPdf(
      List<Transaction>? delinquentTenantsData) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    // Get DateProvider for date formatting
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      // Handle error
      //print"Error fetching profile data: $e");
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
                    '${widget.title} Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Date : - ${dateProvider.formatCurrentDate(fromDate.text)}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: _buildPdfCompanyHeaderWidgets(profileData),
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
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Amount',
                      style: pw.TextStyle(color: PdfColors.white),
                    ),
                  ),
                ],
                data: _generateTableData(
                    delinquentTenantsData as List<Transaction>),
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
            pw.Divider(thickness: 3),
            pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 5),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Grand Total',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(formatMoney(grandtotal),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
                    ])),
          ];
        },
      ),
    );

    // ✅ Platform-based print handling
    if (Platform.isIOS) {
      // iOS: share instead of direct print (AirPrint forces Letter)
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'RentPastDueReport_A4.pdf',
      );
    } else {
      // Android, macOS, Web — direct print
      await Printing.layoutPdf(
        name: 'RentPastDueReport',
        format: PdfPageFormat.a4.landscape,
        dynamicLayout: false,
        usePrinterSettings: false,
        onLayout: (_) async => pdf.save(),
      );
    }
  }

  List<List<dynamic>> _generateTableData(List<Transaction> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];
    double total = 0.0;

    for (var owner in rentalOwnerReports) {
      // Main row for the rental owner name
      tableData.add([
        pw.Text(
            owner.rentalData != null ? owner.rentalData!.address! : "N/A" ?? "",
            style: pw.TextStyle(fontSize: 12)),
        pw.Text(
          (owner.tenantData != null
              ? '${owner.tenantData!.tenantFirstName ?? ""} ${owner.tenantData!.tenantLastName ?? ""}'
              : "N/A"),
          style: pw.TextStyle(fontSize: 12),
        ),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(formatMoney(owner.total?.toStringAsFixed(2) ?? "0.00"),
              style: pw.TextStyle(fontSize: 12)),
        ),
      ]);

      total += owner.total!.toDouble();
    }

    setState(() {
      grandtotal = total;
    });

    return tableData;
  }

  Future<void> generateDelinquentTenantsExcel(
      List<Transaction> delinquentTenantsData, double grandTotal) async {
    // Create a new workbook
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    // Set column widths
    sheet.getRangeByName('A1:C1').columnWidth = 20;

    // Define headers
    final List<String> headers = ['Property', 'Tenant', 'Total'];

    // Header style
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('HeaderCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#5A86D5';
    headerCellStyle.fontColor = '#FFFFFF';
    headerCellStyle.fontSize = 12;
    headerCellStyle.hAlign = syncXlsx.HAlignType.center;

    // Currency style for amounts
    final syncXlsx.Style currencyCellStyle =
        workbook.styles.add('CurrencyCellStyle');
    currencyCellStyle.numberFormat = '\$#,##0.00'; // Currency format
    currencyCellStyle.hAlign = syncXlsx.HAlignType.right; // Right-align amounts

    // Add headers to the Excel sheet
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    // Populate rows with delinquent tenant data
    int rowIndex = 2; // Start from row 2 (below headers)
    for (var tenant in delinquentTenantsData) {
      sheet.getRangeByIndex(rowIndex, 1).setText(tenant.rentalData != null
          ? tenant.rentalData!.address!
          : "N/A" ?? 'N/A');
      sheet.getRangeByIndex(rowIndex, 2).setText(tenant.tenantData != null
          ? '${tenant.tenantData!.tenantFirstName!} ${tenant.tenantData!.tenantLastName!}'
          : "N/A" ?? "");

      sheet
          .getRangeByIndex(rowIndex, 3)
          .setNumber(tenant.total!.toDouble() ?? 0.0);
      sheet.getRangeByIndex(rowIndex, 3).cellStyle = currencyCellStyle;
      grandTotal += tenant.total!.toDouble();

      rowIndex++;
    }

    // Add Grand Total row
    sheet.getRangeByIndex(rowIndex, 2).setText('Grand Total');
    sheet.getRangeByIndex(rowIndex, 2).cellStyle.bold = true;
    sheet.getRangeByIndex(rowIndex, 3).setNumber(grandTotal);
    sheet.getRangeByIndex(rowIndex, 3).cellStyle = currencyCellStyle;
    sheet.getRangeByIndex(rowIndex, 3).cellStyle.bold = true;

    // Save the workbook
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    // Save to file
    final DateTime now = DateTime.now();
    // Format date using DateProvider - use format that's safe for filenames
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Rent_past_due_report_$formattedDate.xlsx';

    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

  // Future<void> generateRentalOwnerReportCsv(
  //     List<RentPastDue> rentalOwnerReports) async {
  //   // Define headers for CSV
  //   final List<String> headers = [
  //     'Property',
  //     'Tenant',
  //     'Date',
  //     'Pmt Type',
  //     'Txn ID',
  //     'Reference',
  //     'Crd Type',
  //     'Crd No',
  //     'Total',
  //   ];
  //
  //   // Create a buffer to store CSV data
  //   final StringBuffer csvBuffer = StringBuffer();
  //
  //   // Add headers to the CSV file
  //   csvBuffer.writeln(headers.join(','));
  //
  //   double grandTotal = 0.0;
  //
  //   // Iterate through each rental owner report
  //   for (var owner in rentalOwnerReports) {
  //     // Add rental owner name as a row
  //     csvBuffer.writeln('${owner.rentalOwnerName ?? ''}');
  //
  //     // Iterate through each property for the current rental owner
  //     for (var property in owner.payments) {
  //       // Replace commas in the rental address with spaces
  //       final String sanitizedAddress =
  //       (property.rentalData.rentalAddress ?? 'N/A').replaceAll(',', ' ');
  //
  //       // Add property and tenant details
  //       csvBuffer.writeln([
  //         sanitizedAddress,
  //         '${property.tenantData.tenantFirstName ?? 'N/A'} ${property.tenantData.tenantLastName ?? 'N/A'}',
  //         property.createdAt.toString(),
  //         property.paymentType ?? '',
  //         property.transactionId ?? '',
  //         property.paymentId ?? '',
  //         property.ccType ?? '',
  //         property.ccNumber ?? '',
  //         '\$${property.totalAmount?.toStringAsFixed(2) ?? '0.00'}'
  //       ].join(','));
  //
  //       // Iterate through payment entries for the current property
  //       for (var payment in property.entry) {
  //         csvBuffer.writeln([
  //           payment.account ?? 'N/A',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '\$${payment.amount.toStringAsFixed(2)}'
  //         ].join(','));
  //       }
  //
  //       // Add surcharge row if applicable
  //       // if (property.surcharge != 0.0) {
  //       //   csvBuffer.writeln([
  //       //     'Surcharge',
  //       //     '',
  //       //     '',
  //       //     '',
  //       //     '',
  //       //     '',
  //       //     '',
  //       //     '',
  //       //     '\$${property.surcharge.toStringAsFixed(2)}'
  //       //   ].join(','));
  //       // }
  //     }
  //
  //     // Add subtotal row for the current rental owner
  //     csvBuffer.writeln([
  //       'Subtotal - ${owner.rentalOwnerName}',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '\$${(owner.subTotal ?? 0.0).toStringAsFixed(2)}'
  //     ].join(','));
  //
  //     // Accumulate grand total
  //     grandTotal += owner.subTotal ?? 0.0;
  //   }
  //
  //   // Add grand total row at the end
  //   csvBuffer.writeln([
  //     'Grand Total',
  //     '',
  //     '',
  //     '',
  //     '',
  //     '',
  //     '',
  //     '',
  //     '\$${grandTotal.toStringAsFixed(2)}'
  //   ].join(','));
  //
  //   // Convert buffer to list of bytes for CSV file
  //   final List<int> bytes = utf8.encode(csvBuffer.toString());
  //
  //   // Define file name with current date and time
  //   final DateTime now = DateTime.now();
  //   final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
  //   final String fileName = 'RentalOwnerReport_$formattedDate.csv';
  //
  //   // Define file path
  //   final Directory directory = Platform.isIOS
  //       ? await getApplicationDocumentsDirectory()
  //       : Directory('/storage/emulated/0/Download');
  //
  //   final path = '${directory.path}/$fileName';
  //
  //   // Create directory if it doesn't exist (for Android)
  //   if (!await directory.exists() && !Platform.isIOS) {
  //     await directory.create(recursive: true);
  //   }
  //
  //   // Write CSV file to the path
  //   final File file = File(path);
  //   await file.writeAsBytes(bytes, flush: true);
  //
  //   // Show success toast message
  //   Fluttertoast.showToast(
  //     msg: 'CSV file saved to $path',
  //   );
  // }

  Future<void> generateDelinquentTenantsCsv(
      List<Transaction> delinquentTenantsData, double grandTotal) async {
    // Define headers
    final List<List<String>> csvData = [
      ['Property', 'Tenant', 'Total'] // CSV headers
    ];

    // Populate rows with delinquent tenant data
    for (var tenant in delinquentTenantsData) {
      csvData.add([
        tenant.rentalData?.address ?? 'N/A',
        '${tenant.tenantData?.tenantFirstName ?? 'N / A'} ${tenant.tenantData?.tenantLastName ?? 'N / A'}',
        formatMoney(tenant.total) ?? '0.00',
      ]);

      grandTotal += tenant.total?.toDouble() ?? 0.0;
    }

    // Add Grand Total row
    csvData.add(['', 'Grand Total', "\$${grandTotal.toStringAsFixed(2)}"]);

    // Convert data to CSV format
    final String csvString = const ListToCsvConverter().convert(csvData);

    // Save CSV file
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Rent_past_due_report_$formattedDate.csv';

    final Directory directory = await getApplicationDocumentsDirectory();

    final String path = '${directory.path}/$fileName';

    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsString(csvString);

    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  List<Map<String, dynamic>> rentalowners = [];
  Future<void> fetchRentalOwners() async {
    //print"calling");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? staffId = prefs.getString("staff_id");
    String? headerId = staffId ?? adminId;
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('${Api_url}/api/rentals/rental-owners/$adminId'),
            headers: {
      "authorization": "CRM $token",
      "id": "CRM $headerId",
    });
    final jsonData = json.decode(response.body);
    //printjsonData);
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

  TextEditingController fromDate = TextEditingController();
  TextEditingController toDate = TextEditingController();
  String? daterange;
  String? chargeType = 'Charges'; // Initialize with default value

  String? monthType = 'Current Month'; // Set default value
  //String? monthType;
  String? selectedrenatalownerid;
  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget.fromStaffModule
          ? staff_appbar.widget_302_Staff.App_Bar(context: context)
          : widget_302.App_Bar(context: context),
      drawer: widget.fromStaffModule
          ? CustomDrawerStaff(
              currentpage: "Dashboard",
              dropdown: false,
            )
          : CustomDrawer(
              currentpage: "Report",
              dropdown: false,
            ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  titleBar(
                    title: '${widget.title} Report',
                    width: MediaQuery.of(context).size.width * .91,
                  ),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(height: 16),
                  if (MediaQuery.of(context).size.width < 500)
                    FutureBuilder<RentPastDue>(
                      future: futurePastRentDue,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: Column(
                              children: [
                                filters(),
                                SizedBox(
                                  height: 20,
                                ),
                                SpinKitFadingCircle(
                                  size: 50,
                                  color: blueColor,
                                )
                              ],
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error: \\n${snapshot.error}',
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                          );
                        } else if (!snapshot.hasData || snapshot.data == null) {
                          return Center(
                            child: Text(
                              'No data available',
                              style: TextStyle(fontSize: 16),
                            ),
                          );
                        } else {
                          var rentPastDue = snapshot.data!;
                          List<Transaction> filteredCharges = [];

                          // Debugging: Print the rental data and tenant data
                          rentPastDue.dueRentCharges?.charges
                              ?.forEach((charge) {
                            //print'Rental Data: ${charge.rentalData}');
                            //print'Tenant Data: ${charge.tenantData}');
                          });
                          // Apply filtering based on charge type and month type
                          if (chargeType == 'Charges') {
                            if (monthType == 'All') {
                              filteredCharges = snapshot
                                      .data!.dueRentCharges?.charges
                                      ?.where((charge) {
                                    var address =
                                        charge.rentalData?.address ?? '';
                                    var tenantName =
                                        charge.tenantData?.tenantFirstName ??
                                            '';
                                    return address.toLowerCase().contains(
                                            searchvalue.toLowerCase()) ||
                                        tenantName.toLowerCase().contains(
                                            searchvalue.toLowerCase());
                                  }).toList() ??
                                  [];
                            } else if (monthType == 'Current Month') {
                              filteredCharges = snapshot
                                      .data!.currentDueRentCharges?.charges
                                      ?.where((charge) {
                                    var address =
                                        charge.rentalData?.address ?? '';
                                    var tenantName =
                                        charge.tenantData?.tenantFirstName ??
                                            '';
                                    return address.toLowerCase().contains(
                                            searchvalue.toLowerCase()) ||
                                        tenantName.toLowerCase().contains(
                                            searchvalue.toLowerCase());
                                  }).toList() ??
                                  [];
                            } else if (monthType == 'Last Month') {
                              filteredCharges = snapshot
                                      .data!.lastDueRentCharges?.charges
                                      ?.where((charge) {
                                    var address =
                                        charge.rentalData?.address ?? '';
                                    var tenantName =
                                        charge.tenantData?.tenantFirstName ??
                                            '';
                                    return address.toLowerCase().contains(
                                            searchvalue.toLowerCase()) ||
                                        tenantName.toLowerCase().contains(
                                            searchvalue.toLowerCase());
                                  }).toList() ??
                                  [];
                            }
                          } else if (chargeType == "Payment") {
                            if (monthType == "Current Month") {
                              filteredCharges = snapshot
                                      .data!.currentPayments?.payments
                                      ?.where((payment) {
                                    var address =
                                        payment.rentalData?.address ?? '';
                                    var tenantName =
                                        payment.tenantData?.tenantFirstName ??
                                            '';
                                    return address.toLowerCase().contains(
                                            searchvalue.toLowerCase()) ||
                                        tenantName.toLowerCase().contains(
                                            searchvalue.toLowerCase());
                                  }).toList() ??
                                  [];
                            } else if (monthType == "Last Month") {
                              filteredCharges = snapshot
                                      .data!.lastPayments?.payments
                                      ?.where((payment) {
                                    var address =
                                        payment.rentalData?.address ?? '';
                                    var tenantName =
                                        payment.tenantData?.tenantFirstName ??
                                            '';
                                    return address.toLowerCase().contains(
                                            searchvalue.toLowerCase()) ||
                                        tenantName.toLowerCase().contains(
                                            searchvalue.toLowerCase());
                                  }).toList() ??
                                  [];
                            }
                          } else {
                            filteredCharges = [];
                          }

                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Column(
                                children: [
                                  // Show label only for Rent Past Due, All months
                                  // if (chargeType == 'Charges' && (monthType == 'All' || monthType == null))
                                  //   Padding(
                                  //     padding: const EdgeInsets.only(bottom: 8.0),
                                  //     child: Text(
                                  //       'Showing all Rent Past Due for all months',
                                  //       style: TextStyle(fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
                                  //     ),
                                  //   ),
                                  const SizedBox(height: 15),
                                  if (chargeType == 'Charges' && monthType == 'All')
                                    chargeTable(
                                        snapshot.data!.dueRentCharges?.charges ?? [], snapshot.data!.dueRentCharges?.total?.toDouble() ?? 0.0,
                                        pagination: snapshot.data!.pagination)
                                  else if (chargeType == 'Charges' &&
                                      monthType == 'Current Month')
                                    // Web parity (Report.jsx:773 reads
                                    // tableData.total): the bucket's own total
                                    // follows the search, whereas the
                                    // dashboard-level currentMonthRentDue is a
                                    // separate unfiltered metric — it kept
                                    // showing the full amount while the table
                                    // was filtered down or empty.
                                    chargeTable(snapshot.data!.currentDueRentCharges?.charges ?? [],
                                        snapshot.data!.currentDueRentCharges?.total?.toDouble() ?? 0.0,
                                        pagination: snapshot.data!.pagination)
                                  else if (chargeType == 'Charges' &&
                                      monthType == 'Last Month')
                                    chargeTable(
                                        snapshot.data!.lastDueRentCharges?.charges ?? [],
                                        snapshot.data!.lastDueRentCharges?.total?.toDouble() ?? 0.0,
                                        pagination: snapshot.data!.pagination)
                                  else if (chargeType == "Payment" &&
                                      monthType == "Current Month")
                                    chargeTable(snapshot.data!.currentPayments?.payments ?? [],
                                        snapshot.data!.currentPayments?.total?.toDouble() ?? 0.0,
                                        pagination: snapshot.data!.pagination)
                                  else if (chargeType == "Payment" &&
                                      monthType == "Last Month")
                                    chargeTable(
                                        snapshot.data!.lastPayments?.payments ?? [],
                                        snapshot.data!.lastPayments?.total?.toDouble() ?? 0.0,
                                        pagination: snapshot.data!.pagination)
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }

  chargeTable(List<Transaction> chargedata, double total,
      {Pagination? pagination}) {
    // Use backend pagination data
    int totalPages = pagination?.totalPages ?? 1;

    // Backend already returns paginated data, so use chargedata directly
    List<Transaction> currentPageData = chargedata;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 3,
        ),
        child: Column(
          children: [
            SizedBox(height: 2),
            filters(data: chargedata),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 5,
                ),
                Text(
                  "${widget.title}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: blueColor),
                ),
                Spacer(),
                Text(
                  formatCurrency(total),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: blueColor),
                ),
                SizedBox(
                  width: 5,
                ),
              ],
            ),
            const SizedBox(height: 5),
            _buildHeaders(),
            if (currentPageData.length == 0)
              // An empty page during a search means "nothing matched", which
              // reads differently from a report with no data at all.
              searchvalue.trim().isNotEmpty
                  ? kNoSearchResults(context)
                  : const Padding(
                      padding: EdgeInsets.all(15.0),
                      child: Text("No data available"),
                    ),
            if (currentPageData.length > 0)
              Container(
                // decoration: BoxDecoration(
                //     border:
                //         Border.all(color: Color.fromRGBO(152, 162, 179, .5))),
                child: Column(
                  // The server applies the search now, so the rows it returns
                  // are already the matches. Filtering them again here is what
                  // produced the blank body: `isEmpty` was checked before the
                  // filter ran, so ten rows with zero matches drew nothing at
                  // all and the "no results" message could never appear.
                  children: currentPageData.asMap().entries.map((entry) {
                    int rowIndex = entry.key;
                    Transaction item = entry.value;
                    bool isRowExpanded = expandedRowIndex == rowIndex;
                    //printitem.rentalData.toString());
                    //print'${item.rentalData?.address}');
                    //show the charge data
                    //  Charge rental = entry.value;
                    //for the payment data
                    // Payment rental = entry.value;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: rowIndex % 2 != 0
                            ? const Color(0xFFF4F8FF)
                            : Colors.white,
                        border: Border.all(color: const Color(0xFFDBE0E5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (expandedRowIndex == rowIndex) {
                                          expandedRowIndex = null;
                                        } else {
                                          expandedRowIndex = rowIndex;
                                        }
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                          left: 5, right: 5),
                                      padding: !isRowExpanded
                                          ? const EdgeInsets.only(bottom: 10)
                                          : const EdgeInsets.only(top: 10),
                                      child: FaIcon(
                                        isRowExpanded
                                            ? FontAwesomeIcons.sortUp
                                            : FontAwesomeIcons.sortDown,
                                        size: 0,
                                        color: isRowExpanded
                                            ? Colors.transparent
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (expandedRowIndex == rowIndex) {
                                            expandedRowIndex = null;
                                          } else {
                                            expandedRowIndex = rowIndex;
                                          }
                                        });
                                      },
                                      child: InkWell(
                                        onTap: () {
                                          if (item.rentalData != null) {
                                            if (item.leaseId != null &&
                                                item.leaseId!.isNotEmpty) {
                                              final leaseId = item.leaseId!;
                                              final next = widget.fromStaffModule
                                                  ? staff_lease.SummeryPageLease(
                                                      leaseId: leaseId,
                                                    )
                                                  : admin_lease.SummeryPageLease(
                                                      leaseId: leaseId,
                                                    );
                                              Navigator.of(context)
                                                  .pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) => next,
                                                ),
                                              );
                                            } else {
                                              Fluttertoast.showToast(
                                                msg:
                                                    "Could not find lease details",
                                                toastLength: Toast.LENGTH_SHORT,
                                              );
                                            }
                                          }
                                        },
                                        child: Text(
                                          '${item.rentalData != null ? item.rentalData!.address : "N/A" ?? '-'} ',
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: MediaQuery.of(context).size.width * .06),
                                  Expanded(
                                    flex: 2,
                                    child: Text('${item.tenantData != null ? item.tenantData!.tenantFirstName : "N/A" ?? '-'} ${item.tenantData != null ? item.tenantData!.tenantLastName : "N/A" ?? '-'}',
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                SizedBox(width: MediaQuery.of(context).size.width * .06),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      formatCurrency(item.total),
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: itemsPerPage,
                            items: itemsPerPageOptions.map((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(value.toString()),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() {
                                  itemsPerPage = newValue;
                                  currentPage =
                                      1; // Reset to first page when items per page change (1-indexed)
                                  isLoading = true;
                                });
                                // Fetch new data with updated limit
                                futurePastRentDue =
                                    fetchRentPastDueData(report: true);
                              }
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
                        color: currentPage <= 1 ? Colors.grey : blueColor,
                      ),
                      onPressed: currentPage <= 1
                          ? null
                          : () {
                              setState(() {
                                currentPage--;
                                isLoading = true;
                              });
                              // Fetch previous page data from backend
                              futurePastRentDue =
                                  fetchRentPastDueData(report: true);
                            },
                    ),
                    // A search that matches nothing returns totalPages 0 while
                    // currentPage is still 1, which read as "Page 1 of 0".
                    Text(totalPages < 1
                        ? 'Page 0 of 0'
                        : 'Page $currentPage of $totalPages'),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.circleChevronRight,
                        color:
                            currentPage >= totalPages ? Colors.grey : blueColor,
                      ),
                      onPressed: currentPage >= totalPages
                          ? null
                          : () {
                              setState(() {
                                currentPage++;
                                isLoading = true;
                              });
                              // Fetch next page data from backend
                              futurePastRentDue =
                                  fetchRentPastDueData(report: true);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  filters({List<Transaction>? data}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          "Charge Type",
                          style: TextStyle(
                              fontSize: 14,
                              color: blueColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            // width: 170,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: chargeType,style: TextStyle(
                           
                                 color: Colors.black,
                                  fontSize:14,
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                hint: Text(
                                  "Charge type",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black),
                                ),
                                items: const [
                                  DropdownMenuItem<String>(
                                    value: 'Charges',
                                    child: Text('Charges'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'Payment',
                                    child: Text('Payment'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    chargeType = value;
                                    // If Payment is selected and month is "All", change to "Current Month"
                                    if (value == "Payment" &&
                                        monthType == "All") {
                                      monthType = "Current Month";
                                    }
                                    // Reset search when filters change
                                    _clearSearch();
                                  });
                                  // Refresh data when charge type changes
                                  refreshData();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          "Select Month",
                          style: TextStyle(
                              fontSize: 14,
                              color: blueColor,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            // width: 170,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                key: ValueKey(
                                    'month_dropdown_$monthType'), // Unique key
                                value: monthType,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                hint: Text(
                                  "Select Month",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black),
                                ),
                                isExpanded:
                                    true, // Ensure proper dropdown behavior
                                items: [
                                  if (chargeType != "Payment")
                                    DropdownMenuItem<String>(
                                      value: 'All',
                                      child: Text('All'),
                                    ),
                                  DropdownMenuItem<String>(
                                    value: 'Current Month',
                                    child: Text('Current Month'),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'Last Month',
                                    child: Text('Last Month'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (mounted) {
                                    setState(() {
                                      monthType = value;
                                      // Reset search when filters change
                                      _clearSearch();
                                    });
                                    // Refresh data when month type changes
                                    refreshData();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 10,
        ),
        Row(
          children: [
            Text(
              "Search",
              style: TextStyle(
                  fontSize: 14, color: blueColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Material(
                  // elevation: 3,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    // height: 40,
                    height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
                    width: MediaQuery.of(context).size.width < 500
                        ? MediaQuery.of(context).size.width * .52
                        : MediaQuery.of(context).size.width * .49,
                    decoration: BoxDecoration(
                        // color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        // border: Border.all(color: Colors.grey),
                        border: Border.all(color: Color(0xFF8A95A8))),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TextField(
                            style: TextStyle(
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 12
                                        : 14),
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            cursorColor: blueColor,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Search here...",
                              hintStyle: TextStyle(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              contentPadding: (EdgeInsets.only(
                                  left: 5, bottom: 10, top: 5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
                          //print'pdf');
                          generateDelinquentTenantsPdf(data);
                        } else if (value == 'XLSX' && data != null) {
                          //print'XLSX');
                          generateDelinquentTenantsExcel(data, 0);
                          //generateRentalOwnerReportExcel(data);
                          //generateDelinquentTenantsExcel(data);
                        } else if (value == 'CSV' && data != null) {
                          //print'CSV');
                          generateDelinquentTenantsCsv(data, 0.0);
                          //  generateRentalOwnerReportCsv(data);
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
              )
            ],
          ),
        ),
      ],
    );
  }
}
