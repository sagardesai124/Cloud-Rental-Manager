import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:three_zero_two_property/Model/RentarsInsuranceModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/getAdminAddress.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/RentersInsuranceService.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Renters%20Insurance/ViewRentersDetails.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/insurance_document_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class RentersInsurance extends StatefulWidget {
  @override
  State<RentersInsurance> createState() => _RentersInsuranceState();
}

class _RentersInsuranceState extends State<RentersInsurance>
    with NetworkRetryState {
  late Future<List<RentersInsuranceData>> _futureRentersInsurance;
  List<RentersInsuranceData> rentersInsuranceModel = [];
  bool isLoading = true;
  String? errorMessage;
  int? expandedRowIndex;
  Map<int, int?> expandedTenantIndex = {};
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // Web parity: "Show Deleted Policies" checkbox state, persisted like the
  // web app's localStorage key "rentersInsurance:list:showDeleted".
  static const String _showDeletedPrefKey = 'rentersInsurance:list:showDeleted';
  bool _showDeleted = false;

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
    _futureRentersInsurance = _loadShowDeletedPrefAndFetch();
  }

  // Read the persisted "Show Deleted Policies" preference first so the
  // initial fetch already includes deleted policies when it was left ON.
  Future<List<RentersInsuranceData>> _loadShowDeletedPrefAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _showDeleted = prefs.getBool(_showDeletedPrefKey) ?? false;
    return fetchRentersInsuranceData();
  }

  Future<void> _onShowDeletedChanged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDeletedPrefKey, value);
    if (!mounted) return;
    setState(() {
      _showDeleted = value;
      isLoading = true;
      currentPage = 0;
      _futureRentersInsurance = fetchRentersInsuranceData();
    });
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

  Future<List<RentersInsuranceData>> fetchRentersInsuranceData() async {
    RentersInsuranceService service = RentersInsuranceService();
    try {
      List<RentersInsuranceData> data =
          await service.fetchRentersInsurance(includeDeleted: _showDeleted);
      setState(() {
        rentersInsuranceModel = data;
        isLoading = false;
        errorMessage = null; // Reset error message on successful data fetch
      });
      return data;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = friendlyErrorMessage(e,
            fallbackMessage:
                'Failed to load renters insurance data. Please try again later.');
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
      _futureRentersInsurance = fetchRentersInsuranceData();
    });
  }

  List<RentersInsuranceData> _tableData = [];
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
      Comparable<T> Function(RentersInsuranceData d)? getField) {
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

  void sortData(List<RentersInsuranceData> data) {
    if (sorting1) {
      // Sort by Tenant Name - Lowercase first, then uppercase
      data.sort((a, b) {
        String nameA = (a.tenantName ?? '');
        String nameB = (b.tenantName ?? '');

        // Check if first character is lowercase or uppercase
        bool aIsLowercase =
            nameA.isNotEmpty && nameA[0] != nameA[0].toUpperCase();
        bool bIsLowercase =
            nameB.isNotEmpty && nameB[0] != nameB[0].toUpperCase();

        // If one is lowercase and other is uppercase, lowercase comes first
        if (aIsLowercase && !bIsLowercase) {
          return ascending1 ? -1 : 1;
        } else if (!aIsLowercase && bIsLowercase) {
          return ascending1 ? 1 : -1;
        }

        // If both have same case type, sort alphabetically (case-insensitive)
        int result = nameA.toLowerCase().compareTo(nameB.toLowerCase());
        return ascending1 ? result : -result;
      });
    } else if (sorting2) {
      // Sort by Insurance Provider - Lowercase first, then uppercase
      data.sort((a, b) {
        String providerA = (a.rentersInsurance?.insuranceCompany ?? '');
        String providerB = (b.rentersInsurance?.insuranceCompany ?? '');

        // Check if first character is lowercase or uppercase
        bool aIsLowercase =
            providerA.isNotEmpty && providerA[0] != providerA[0].toUpperCase();
        bool bIsLowercase =
            providerB.isNotEmpty && providerB[0] != providerB[0].toUpperCase();

        // If one is lowercase and other is uppercase, lowercase comes first
        if (aIsLowercase && !bIsLowercase) {
          return ascending2 ? -1 : 1;
        } else if (!aIsLowercase && bIsLowercase) {
          return ascending2 ? 1 : -1;
        }

        // If both have same case type, sort alphabetically (case-insensitive)
        int result = providerA.toLowerCase().compareTo(providerB.toLowerCase());
        return ascending2 ? result : -result;
      });
    } else if (sorting3) {
      // Sort by Policy ID - Lowercase first, then uppercase
      data.sort((a, b) {
        String policyA = (a.rentersInsurance?.policyId ?? '');
        String policyB = (b.rentersInsurance?.policyId ?? '');

        // Check if first character is lowercase or uppercase
        bool aIsLowercase =
            policyA.isNotEmpty && policyA[0] != policyA[0].toUpperCase();
        bool bIsLowercase =
            policyB.isNotEmpty && policyB[0] != policyB[0].toUpperCase();

        // If one is lowercase and other is uppercase, lowercase comes first
        if (aIsLowercase && !bIsLowercase) {
          return ascending3 ? -1 : 1;
        } else if (!aIsLowercase && bIsLowercase) {
          return ascending3 ? 1 : -1;
        }

        // If both have same case type, sort alphabetically (case-insensitive)
        int result = policyA.toLowerCase().compareTo(policyB.toLowerCase());
        return ascending3 ? result : -result;
      });
    }
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
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (sorting1 == true) {
                        // Already sorting by this column, just toggle the order
                        ascending1 = !ascending1;
                      } else {
                        // Start sorting by this column
                        sorting1 = true;
                        sorting2 = false;
                        sorting3 = false;
                        ascending1 = true; // Start with A-Z
                        ascending2 = false;
                        ascending3 = false;
                      }
                      // Apply sorting immediately
                      sortData(rentersInsuranceModel);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0),
                    child: Row(
                      children: [
                        width < 400
                            ? Text("   Tenant",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))
                            : Text("   Tenant",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
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
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (sorting2 == true) {
                        // Already sorting by this column, just toggle the order
                        ascending2 = !ascending2;
                      } else {
                        // Start sorting by this column
                        sorting1 = false;
                        sorting2 = true;
                        sorting3 = false;
                        ascending1 = false;
                        ascending2 = true; // Start with A-Z
                        ascending3 = false;
                      }
                      // Apply sorting immediately
                      sortData(rentersInsuranceModel);
                    });
                  },
                  child: Row(
                    children: [
                      Text("Insurance\nProvider",
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
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (sorting3 == true) {
                        // Already sorting by this column, just toggle the order
                        ascending3 = !ascending3;
                      } else {
                        // Start sorting by this column
                        sorting1 = false;
                        sorting2 = false;
                        sorting3 = true;
                        ascending1 = false;
                        ascending2 = false;
                        ascending3 = true; // Start with A-Z
                      }
                      // Apply sorting immediately
                      sortData(rentersInsuranceModel);
                    });
                  },
                  child: Row(
                    children: [
                      Text("     Policy Id",
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
      ),
    );
  }

  Future<void> generaterentersInsurancePdf(
      List<RentersInsuranceData> rentersInsurance) async {
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
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              padding: pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 50, height: 50),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        "Renter's Insurance",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('As of $currentDate'),
                    ],
                  ),
                  pw.SizedBox(width: 50),
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
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#152B53')),
              columnWidths: {
                0: const pw.FixedColumnWidth(80), // Unit
                1: const pw.FixedColumnWidth(80), // Tenant Name
                2: const pw.FixedColumnWidth(80), // Insurance Provider
                3: const pw.FixedColumnWidth(80), // Policy ID
                4: const pw.FixedColumnWidth(80), // Liability Coverage
                5: const pw.FixedColumnWidth(80), // Effective Date
                6: const pw.FixedColumnWidth(80), // Expiration Date
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey300,
                    border:
                        pw.TableBorder.all(color: PdfColor.fromHex('#152B53')),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Unit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Tenant Name',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Insurance Provider',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Policy ID',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Liability Coverage',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Effective Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8.0),
                      child: pw.Text('Expiration Date',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data rows
                ..._generateTableData(rentersInsurance).map(
                  (row) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                      border: pw.TableBorder.all(
                          color: PdfColor.fromHex('#152B53')),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child:
                            pw.Text(row[0], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child:
                            pw.Text(row[1], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child:
                            pw.Text(row[2], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child:
                            pw.Text(row[3], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(row[4],
                              style: pw.TextStyle(fontSize: 10)),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child:
                            pw.Text(row[5], style: pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8.0),
                        child:
                            pw.Text(row[6], style: pw.TextStyle(fontSize: 10)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Renters-insurance.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Renters-insurance',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  String formateDates(String date) {
    return DateFormat("yyyy-MM-dd").format(DateTime.parse(date)).toString();
  }

  List<List<String>> _generateTableData(
      List<RentersInsuranceData> rentersInsurance) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final List<List<String>> tableData = [];

    for (var item in rentersInsurance) {
      tableData.add([
        item.unitDetails ?? '',
        item.tenantName ?? '',
        item.rentersInsurance!.insuranceCompany ?? '',
        item.rentersInsurance!.policyId ?? '',
        formatCurrency(item.rentersInsurance!.liabilityCoverage.toDouble()),
        item.rentersInsurance!.effectiveDate != null
            ? dateProvider
                .formatCurrentDate(item.rentersInsurance!.effectiveDate!)
            : '',
        item.rentersInsurance!.expirationDate != null
            ? dateProvider
                .formatCurrentDate(item.rentersInsurance!.expirationDate!)
            : '',
      ]);

      // for (var tenant in item.tenants!) {
      //   tableData.add([
      //     '',
      //     tenant.tenantName ?? '',
      //     tenant.tenantInsurance?.provider ?? '',
      //     tenant.tenantInsurance?.policyId ?? '',
      //     tenant.tenantInsurance!.liabilityCoverage.toString() ?? '',
      //     tenant.tenantInsurance?.effectiveDate ?? '',
      //     tenant.tenantInsurance?.expirationDate ?? '',
      //   ]);
      // }
    }

    return tableData;
  }

  Future<void> generateRentersInsuranceExcel(
      List<RentersInsuranceData> rentersInsurance) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    // Set column widths
    sheet.getRangeByName('A1:G1').columnWidth = 30;

    // Define headers
    final List<String> headers = [
      'Unit',
      'Tenant Name',
      'Insurance Provider',
      'Policy ID',
      'Liability Coverage',
      'Effective Date',
      'Expiration Date',
    ];

    // Style for headers
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#D3D3D3';
    headerCellStyle.hAlign = syncXlsx.HAlignType.left;

    // Add headers to the first row
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    int rowIndex = 2; // Start from the second row
    // for (var item in rentersInsurance) {
    //   // Add main row with rental address
    //   sheet.getRangeByIndex(rowIndex, 1).setText(item.unitDetails ?? '');
    //   for (int col = 2; col <= 7; col++) {
    //     sheet.getRangeByIndex(rowIndex, col).setText('');
    //   }
    //
    //   rowIndex++; // Move to the next row for tenant details
    //
    //   // Add tenant details in subsequent rows
    //   // for (var tenant in item.tenants!) {
    //   //   sheet
    //   //       .getRangeByIndex(rowIndex, 1)
    //   //       .setText(item.tenants!.first.unitDetails ?? '');
    //   //   sheet.getRangeByIndex(rowIndex, 2).setText(tenant.tenantName ?? '');
    //   //   sheet
    //   //       .getRangeByIndex(rowIndex, 3)
    //   //       .setText(tenant.tenantInsurance?.provider ?? '');
    //   //   sheet
    //   //       .getRangeByIndex(rowIndex, 4)
    //   //       .setText(tenant.tenantInsurance?.policyId ?? '');
    //   //   sheet.getRangeByIndex(rowIndex, 5).setText(
    //   //       tenant.tenantInsurance!.liabilityCoverage.toString() ?? '');
    //   //   sheet
    //   //       .getRangeByIndex(rowIndex, 6)
    //   //       .setText(tenant.tenantInsurance?.effectiveDate ?? '');
    //   //   sheet
    //   //       .getRangeByIndex(rowIndex, 7)
    //   //       .setText(tenant.tenantInsurance?.expirationDate ?? '');
    //   //   rowIndex++; // Move to the next row
    //   // }
    // }

    // Save workbook as a byte stream
    for (var item in rentersInsurance) {
      if (item.rentersInsurance != null) {
        sheet.getRangeByIndex(rowIndex, 1).setText(item.unitDetails ?? '');
        sheet.getRangeByIndex(rowIndex, 2).setText(item.tenantName ?? '');
        sheet
            .getRangeByIndex(rowIndex, 3)
            .setText(item.rentersInsurance!.insuranceCompany ?? '');
        sheet
            .getRangeByIndex(rowIndex, 4)
            .setText(item.rentersInsurance!.policyId ?? '');
        sheet.getRangeByIndex(rowIndex, 5).setText(
            item.rentersInsurance!.liabilityCoverage != null
                ? formatCurrency(
                    item.rentersInsurance!.liabilityCoverage.toDouble())
                : '');
        sheet.getRangeByIndex(rowIndex, 6).setText(
            item.rentersInsurance!.effectiveDate != null
                ? dateProvider
                    .formatCurrentDate(item.rentersInsurance!.effectiveDate!)
                : '');
        sheet.getRangeByIndex(rowIndex, 7).setText(
            item.rentersInsurance!.expirationDate != null
                ? dateProvider
                    .formatCurrentDate(item.rentersInsurance!.expirationDate!)
                : '');
        rowIndex++; // Move to the next row
      }
    }
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'RentersInsuranceReport_$formattedDate.xlsx';
    final Directory directory = await getApplicationDocumentsDirectory();

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }
    final path = '${directory.path}/$fileName';
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(path)]);

    // Show success toast message
    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

  Future<void> generateRentersInsuranceCsv(
      List<RentersInsuranceData> rentersInsurance) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final StringBuffer csvBuffer = StringBuffer();
    List<List<dynamic>> rows = [
      [
        'Unit',
        'Tenant Name',
        'Insurance Provider',
        'Policy ID',
        'Liability Coverage',
        'Effective Date',
        'Expiration Date'
      ]
    ];

    for (var item in rentersInsurance) {
      // Add main row with rental address
      rows.add([
        item.unitDetails ?? '',
        item.tenantName ?? '',
        item.rentersInsurance!.insuranceCompany ?? '',
        item.rentersInsurance!.policyId ?? '',
        formatCurrency(item.rentersInsurance!.liabilityCoverage.toDouble()),
        item.rentersInsurance!.effectiveDate != null
            ? dateProvider
                .formatCurrentDate(item.rentersInsurance!.effectiveDate!)
            : '',
        item.rentersInsurance!.expirationDate != null
            ? dateProvider
                .formatCurrentDate(item.rentersInsurance!.expirationDate!)
            : '',
      ]);

      // Add tenant details in subsequent rows
      // for (var tenant in item.tenants!) {
      //   rows.add([
      //     '',
      //     tenant.tenantName ?? '',
      //     tenant.tenantInsurance?.provider ?? '',
      //     tenant.tenantInsurance?.policyId ?? '',
      //     tenant.tenantInsurance?.liabilityCoverage ?? '',
      //     tenant.tenantInsurance?.effectiveDate ?? '',
      //     tenant.tenantInsurance?.expirationDate ?? ''
      //   ]);
      // }
    }

    String csv = const ListToCsvConverter().convert(rows);
    final List<int> bytes = utf8.encode(csvBuffer.toString());
    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'RentersInsuranceReport_$formattedDate.csv';

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

  /// Search box and Export, shown in every state of the report. Export is
  /// greyed out and not tappable while the report has no data, like every
  /// other report.
  Widget _buildToolbar(List<RentersInsuranceData> data) {
    final bool hasData = data.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
          left:
              MediaQuery.of(context).size.width > 500
                  ? 10
                  : 0,
          right:
              MediaQuery.of(context).size.width > 500
                  ? 10
                  : 0),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10),
                height: MediaQuery.of(context)
                            .size
                            .width <
                        500
                    ? 48
                    : 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(8),
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
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(
                  0,
                  MediaQuery.of(context).size.width <
                          500
                      ? 48
                      : 50),
              maximumSize: Size(
                  double.infinity,
                  MediaQuery.of(context).size.width <
                          500
                      ? 48
                      : 50),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16),
              tapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: hasData ? () {} : null,
            child: PopupMenuButton<String>(
              enabled: hasData,
              onSelected: (value) async {
                // Export logic
                if (value == 'PDF') {
                  generaterentersInsurancePdf(data);
                } else if (value == 'XLSX') {
                  generateRentersInsuranceExcel(data);
                } else if (value == 'CSV') {
                  generateRentersInsuranceCsv(data);
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                    value: 'PDF', child: Text('PDF')),
                const PopupMenuItem<String>(
                    value: 'XLSX',
                    child: Text('XLSX')),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
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
                    title: "Renter's Insurance",
                  ),
                  // Web parity: "Show Deleted Policies" checkbox above the
                  // list; toggling refetches with ?include_deleted=1 and the
                  // choice persists across screen opens.
                  Padding(
                    padding: EdgeInsets.only(
                        top: 8,
                        left: MediaQuery.of(context).size.width > 500 ? 26 : 16,
                        right:
                            MediaQuery.of(context).size.width > 500 ? 26 : 16),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _showDeleted,
                            activeColor: blueColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (value) {
                              if (value != null) {
                                _onShowDeletedChanged(value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _onShowDeletedChanged(!_showDeleted),
                          child: Text(
                            'Show Deleted Policies',
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
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width < 500)
                  FutureBuilder<List<RentersInsuranceData>>(
                    future: _futureRentersInsurance,
                    builder: (context, snapshot) {
                      if (isLoading) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _buildToolbar(const []),
                            ),
                            Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ColabShimmerLoadingWidget(),
                        ),
                          ],
                        );
                      } else if (snapshot.hasError) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _buildToolbar(const []),
                            ),
                            _reportErrorState(onRetry: _retryFetch),
                          ],
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: _buildToolbar(const []),
                            ),
                            Container(
                          height: MediaQuery.of(context).size.height * .5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
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
                        );
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
                                (item.tenantName ?? '')
                                    .toLowerCase()
                                    .contains(searchvalue.toLowerCase()))
                            .toList();
                      } else {
                        data = snapshot.data!
                            .where(
                                (item) => item.rentalAddress == selectedValue)
                            .toList();
                      }

                      // Apply sorting
                      sortData(data);
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
                              _buildToolbar(data),
                              const SizedBox(height: 20),
                              _buildHeaders(),
                              const SizedBox(height: 20),
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
                                      int rowIndex = entry.key;
                                      var item = entry.value;
                                      bool isRowExpanded =
                                          expandedRowIndex == rowIndex;
                                      // Web parity: soft-deleted policies are
                                      // faded + struck through.
                                      final bool isDeleted =
                                          item.rentersInsurance?.isDelete ==
                                              true;
                                      final TextDecoration? rowDecoration =
                                          isDeleted
                                              ? TextDecoration.lineThrough
                                              : null;

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
                                                    InkWell(
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
                                                            .only(left: 5),
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
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      // flex:
                                                      // 4, // Larger size for the first field
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 8.0),
                                                        child: InkWell(
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
                                                          child: Text.rich(
                                                            TextSpan(
                                                              children: [
                                                                TextSpan(
                                                                  text:
                                                                      '${item.tenantName ?? '-'}',
                                                                  style:
                                                                      TextStyle(
                                                                    color: isDeleted
                                                                        ? Colors
                                                                            .grey
                                                                        : blueColor,
                                                                    decoration:
                                                                        rowDecoration,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                                if (item.tenantName
                                                                        ?.isNotEmpty ??
                                                                    false)
                                                                  TextSpan(
                                                                    text:
                                                                        "\n${item.unitDetails ?? '-'}",
                                                                    style:
                                                                        TextStyle(
                                                                      color: isDeleted
                                                                          ? Colors
                                                                              .grey
                                                                          : Colors
                                                                              .lightBlue, // Light blue color for tenant names
                                                                      decoration:
                                                                          rowDecoration,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 15),
                                                    Expanded(
                                                      child: Text(
                                                        '${item.rentersInsurance!.insuranceCompany ?? '-'}',
                                                        style: TextStyle(
                                                          color: isDeleted
                                                              ? Colors.grey
                                                              : blueColor,
                                                          decoration:
                                                              rowDecoration,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        '  ${item.rentersInsurance!.policyId ?? '-'}',
                                                        style: TextStyle(
                                                          color: isDeleted
                                                              ? Colors.grey
                                                              : blueColor,
                                                          decoration:
                                                              rowDecoration,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            if (isRowExpanded)
                                              Container(
                                                padding: EdgeInsets.only(
                                                    left: 2, right: 2),
                                                margin:
                                                    EdgeInsets.only(bottom: 2),
                                                child: SingleChildScrollView(
                                                  child: Container(
                                                    //color: Colors.blue,
                                                    child: Column(
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          children: [
                                                            FaIcon(
                                                              isRowExpanded
                                                                  ? FontAwesomeIcons
                                                                      .sortUp
                                                                  : FontAwesomeIcons
                                                                      .sortDown,
                                                              size: 50,
                                                              color: Colors
                                                                  .transparent,
                                                            ),
                                                            Expanded(
                                                              child: Table(
                                                                columnWidths: {
                                                                  // 0: FixedColumnWidth(150.0), // Adjust width as needed
                                                                  // 1: FlexColumnWidth(),
                                                                  0: FlexColumnWidth(), // Distribute columns equally
                                                                  1: FlexColumnWidth(),
                                                                },
                                                                children: [
                                                                  buildTableRow(
                                                                    'Effective Date :',
                                                                    getDisplayValue(item.rentersInsurance?.effectiveDate?.isNotEmpty ==
                                                                            true
                                                                        ? dateProvider
                                                                            .formatCurrentDate('${item.rentersInsurance?.effectiveDate?.split('T').first}')
                                                                        : 'N/A'),
                                                                    'Expiration Date :',
                                                                    getDisplayValue(item.rentersInsurance?.expirationDate?.isNotEmpty ==
                                                                            true
                                                                        ? dateProvider
                                                                            .formatCurrentDate('${item.rentersInsurance?.expirationDate?.split('T').first}')
                                                                        : 'N/A'),
                                                                  ),
                                                                  buildTableRow(
                                                                      'Liability Coverage :',
                                                                      // formatMoney renders null/zero as "$0.00", so no
                                                                      // "N/A" placeholder is needed for this figure.
                                                                      getDisplayValue(formatMoney(item
                                                                          .rentersInsurance
                                                                          ?.liabilityCoverage)),
                                                                      '',
                                                                      '')
                                                                ],
                                                              ),
                                                            ),
                                                            /* Container(
                                                          width: 40,
                                                          child: Column(
                                                            children: [
                                                              IconButton(
                                                                icon: FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 20,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      83,
                                                                      1),
                                                                ),
                                                                onPressed:
                                                                    () async {
                                                                  // handleEdit(Propertytype);

                                                                  // var check = await Navigator.push(
                                                                  //     context,
                                                                  //     MaterialPageRoute(
                                                                  //         builder: (context) => Edit_property_type(
                                                                  //           property: Propertytype,
                                                                  //         )));
                                                                  // if (check ==
                                                                  //     true) {
                                                                  //   setState(
                                                                  //           () {});
                                                                  // }
                                                                },
                                                              ),
                                                              IconButton(
                                                                icon: FaIcon(
                                                                  FontAwesomeIcons
                                                                      .trashCan,
                                                                  size: 20,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      83,
                                                                      1),
                                                                ),
                                                                onPressed: () {
                                                                  //handleDelete(Propertytype);
                                                                  // _showAlert(
                                                                  //     context,
                                                                  //     Propertytype
                                                                  //         .propertyId!);
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),*/
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 10),
                                                        // Expanded-row actions —
                                                        // View Policy + View
                                                        // Documents (same button
                                                        // style as the Renters
                                                        // Insurance table).
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 8,
                                                                  bottom: 6),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .end,
                                                            children: [
                                                              GestureDetector(
                                                                onTap: () {
                                                                  Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                          builder: (context) => ViewRentersDetails(
                                                                                tenantid: item.tenantId ?? '',
                                                                                leaseId: item.leaseId ?? '',
                                                                                renters_insurance_id: item.rentersInsurance?.rentersInsuranceId ?? '',
                                                                                includeDeleted: item.rentersInsurance?.isDelete == true,
                                                                              )));
                                                                },
                                                                child:
                                                                    Container(
                                                                  height: 35,
                                                                  width: 35,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade200,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child:
                                                                      const Center(
                                                                    child:
                                                                        FaIcon(
                                                                      FontAwesomeIcons
                                                                          .eye,
                                                                      size: 15,
                                                                      color: Colors
                                                                          .black,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 5),
                                                              GestureDetector(
                                                                onTap: () {
                                                                  final hasDoc = (item.rentersInsurance?.insurancePolicyDocument ??
                                                                          '')
                                                                      .isNotEmpty;
                                                                  if (hasDoc) {
                                                                    viewInsuranceDocument(
                                                                        context,
                                                                        item.rentersInsurance
                                                                            ?.insurancePolicyDocument);
                                                                  } else {
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(
                                                                      const SnackBar(
                                                                        content:
                                                                            Text('No document attached'),
                                                                        behavior:
                                                                            SnackBarBehavior.floating,
                                                                      ),
                                                                    );
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  height: 35,
                                                                  width: 35,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: (item.rentersInsurance?.insurancePolicyDocument ?? '')
                                                                            .isNotEmpty
                                                                        ? const Color(0xFFE8F0FA)
                                                                        : Colors.grey.shade100,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child: Center(
                                                                    child:
                                                                        FaIcon(
                                                                      FontAwesomeIcons
                                                                          .fileLines,
                                                                      size: 15,
                                                                      color: (item.rentersInsurance?.insurancePolicyDocument ?? '')
                                                                              .isNotEmpty
                                                                          ? blueColor
                                                                          : Colors.grey.shade400,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        // Row(
                                                        //   mainAxisAlignment:
                                                        //       MainAxisAlignment
                                                        //           .start,
                                                        //   children: [
                                                        //     Row(
                                                        //       mainAxisAlignment:
                                                        //           MainAxisAlignment
                                                        //               .start,
                                                        //       children: [
                                                        //         FaIcon(
                                                        //           isRowExpanded
                                                        //               ? FontAwesomeIcons
                                                        //                   .sortUp
                                                        //               : FontAwesomeIcons
                                                        //                   .sortDown,
                                                        //           size: 50,
                                                        //           color: Colors
                                                        //               .transparent,
                                                        //         ),
                                                        //       ],
                                                        //     ),
                                                        //     Column(
                                                        //       mainAxisAlignment:
                                                        //           MainAxisAlignment
                                                        //               .start,
                                                        //       crossAxisAlignment:
                                                        //           CrossAxisAlignment
                                                        //               .start,
                                                        //       children: [
                                                        //         Text.rich(
                                                        //           TextSpan(
                                                        //             children: [
                                                        //               TextSpan(
                                                        //                 text:
                                                        //                     'Effective Date : ',
                                                        //                 style: TextStyle(
                                                        //                     fontWeight:
                                                        //                         FontWeight.bold,
                                                        //                     color: blueColor), // Bold and black
                                                        //               ),
                                                        //               TextSpan(
                                                        //                 text: item.rentersInsurance?.effectiveDate?.isNotEmpty ==
                                                        //                         true
                                                        //                     ? item.rentersInsurance?.effectiveDate?.split('T').first
                                                        //                     : 'N/A',
                                                        //                 style: TextStyle(
                                                        //                     fontWeight:
                                                        //                         FontWeight.w700,
                                                        //                     color: grey), // Light and grey
                                                        //               ),
                                                        //             ],
                                                        //           ),
                                                        //         ),
                                                        //         SizedBox(
                                                        //             height: 5),
                                                        //         Text.rich(
                                                        //           TextSpan(
                                                        //             children: [
                                                        //               TextSpan(
                                                        //                 text:
                                                        //                     'Expiration Date : ',
                                                        //                 style: TextStyle(
                                                        //                     fontWeight:
                                                        //                         FontWeight.bold,
                                                        //                     color: blueColor), // Bold and black
                                                        //               ),
                                                        //               TextSpan(
                                                        //                 // text: formatDate(
                                                        //                 //     '${Propertytype.updatedAt}'),
                                                        //                 text: item.rentersInsurance?.expirationDate?.isNotEmpty ==
                                                        //                         true
                                                        //                     ? item.rentersInsurance?.expirationDate?.split('T').first
                                                        //                     : 'N/A',
                                                        //                 style: TextStyle(
                                                        //                     fontWeight:
                                                        //                         FontWeight.w700,
                                                        //                     color: grey), // Light and grey
                                                        //               ),
                                                        //             ],
                                                        //           ),
                                                        //         ),
                                                        //         SizedBox(
                                                        //             height: 5),
                                                        //         Text.rich(
                                                        //           TextSpan(
                                                        //             children: [
                                                        //               TextSpan(
                                                        //                 text:
                                                        //                     'Liability Coverage : ',
                                                        //                 style: TextStyle(
                                                        //                     fontWeight:
                                                        //                         FontWeight.bold,
                                                        //                     color: blueColor), // Bold and black
                                                        //               ),
                                                        //               TextSpan(
                                                        //                 // text: formatDate(
                                                        //                 //     '${Propertytype.updatedAt}'),
                                                        //                 text: item.rentersInsurance?.liabilityCoverage.toString().isNotEmpty ==
                                                        //                         true
                                                        //                     ? item.rentersInsurance?.liabilityCoverage.toString()
                                                        //                     : 'N/A',
                                                        //                 style: TextStyle(
                                                        //                     fontWeight:
                                                        //                         FontWeight.w700,
                                                        //                     color: grey), // Light and grey
                                                        //               ),
                                                        //             ],
                                                        //           ),
                                                        //         ),
                                                        //       ],
                                                        //     ),
                                                        //     Spacer(),
                                                        //     SizedBox(width: 5),
                                                        //   ],
                                                        // ),
                                                        SizedBox(
                                                          height: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                            //   Column(
                                            //     children: item.tenants!
                                            //         .asMap()
                                            //         .entries
                                            //         .map((tenantEntry) {
                                            //       int tenantIndex =
                                            //           tenantEntry.key;
                                            //       var tenant =
                                            //           tenantEntry.value;
                                            //       bool isTenantExpanded =
                                            //           expandedTenantIndex[
                                            //                   rowIndex] ==
                                            //               tenantIndex;
                                            //
                                            //       return Column(
                                            //         children: <Widget>[
                                            //           Divider(
                                            //             color: blueColor,
                                            //           ),
                                            //           ListTile(
                                            //             contentPadding:
                                            //                 EdgeInsets.zero,
                                            //             title: Padding(
                                            //               padding:
                                            //                   const EdgeInsets
                                            //                       .all(2.0),
                                            //               child: Row(
                                            //                 mainAxisAlignment:
                                            //                     MainAxisAlignment
                                            //                         .start,
                                            //                 crossAxisAlignment:
                                            //                     CrossAxisAlignment
                                            //                         .center,
                                            //                 children: <Widget>[
                                            //                   InkWell(
                                            //                     onTap: () {
                                            //                       setState(() {
                                            //                         if (expandedTenantIndex[
                                            //                                 rowIndex] ==
                                            //                             tenantIndex) {
                                            //                           expandedTenantIndex[
                                            //                                   rowIndex] =
                                            //                               null;
                                            //                         } else {
                                            //                           expandedTenantIndex[
                                            //                                   rowIndex] =
                                            //                               tenantIndex;
                                            //                         }
                                            //                       });
                                            //                     },
                                            //                     child:
                                            //                         Container(
                                            //                       margin:
                                            //                           const EdgeInsets
                                            //                               .only(
                                            //                               left:
                                            //                                   5),
                                            //                       padding: !isTenantExpanded
                                            //                           ? const EdgeInsets
                                            //                               .only(
                                            //                               bottom:
                                            //                                   10)
                                            //                           : const EdgeInsets
                                            //                               .only(
                                            //                               top:
                                            //                                   10),
                                            //                       child:
                                            //                           Padding(
                                            //                         padding: const EdgeInsets
                                            //                             .only(
                                            //                             left:
                                            //                                 24),
                                            //                         child:
                                            //                             FaIcon(
                                            //                           isTenantExpanded
                                            //                               ? FontAwesomeIcons
                                            //                                   .sortUp
                                            //                               : FontAwesomeIcons
                                            //                                   .sortDown,
                                            //                           size: 20,
                                            //                           color:
                                            //                               blueColor,
                                            //                         ),
                                            //                       ),
                                            //                     ),
                                            //                   ),
                                            //                   SizedBox(
                                            //                       width: MediaQuery.of(
                                            //                                   context)
                                            //                               .size
                                            //                               .width *
                                            //                           .02),
                                            //                   Expanded(
                                            //                     child: RichText(
                                            //                         text: TextSpan(
                                            //                             children: [
                                            //                           TextSpan(
                                            //                             text:
                                            //                                 'Tenant ${tenantIndex + 1} ',
                                            //                             style:
                                            //                                 TextStyle(
                                            //                               color:
                                            //                                   grey,
                                            //                               fontWeight:
                                            //                                   FontWeight.w500,
                                            //                               fontSize:
                                            //                                   14,
                                            //                             ),
                                            //                           ),
                                            //                           TextSpan(
                                            //                             text:
                                            //                                 ': ${tenant.tenantName ?? '-'}',
                                            //                             style:
                                            //                                 TextStyle(
                                            //                               color:
                                            //                                   blueColor,
                                            //                               fontWeight:
                                            //                                   FontWeight.bold,
                                            //                               fontSize:
                                            //                                   14,
                                            //                             ),
                                            //                           ),
                                            //                         ])),
                                            //                   ),
                                            //                 ],
                                            //               ),
                                            //             ),
                                            //           ),
                                            //           if (isTenantExpanded)
                                            //             Container(
                                            //               width:
                                            //                   double.infinity,
                                            //               child: Column(
                                            //                 crossAxisAlignment:
                                            //                     CrossAxisAlignment
                                            //                         .start,
                                            //                 children: [
                                            //                   Padding(
                                            //                     padding:
                                            //                         const EdgeInsets
                                            //                             .only(
                                            //                             left:
                                            //                                 36.0),
                                            //                     child: Column(
                                            //                       crossAxisAlignment:
                                            //                           CrossAxisAlignment
                                            //                               .start,
                                            //                       children: [
                                            //                         Padding(
                                            //                           padding: const EdgeInsets
                                            //                               .only(
                                            //                               left:
                                            //                                   0),
                                            //                           child: Text
                                            //                               .rich(
                                            //                             TextSpan(
                                            //                               children: [
                                            //                                 TextSpan(
                                            //                                   text: 'Insurance Provider: ',
                                            //                                   style: TextStyle(
                                            //                                     color: blueColor,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 14,
                                            //                                   ),
                                            //                                 ),
                                            //                                 TextSpan(
                                            //                                   text: '${tenant.tenantInsurance?.policyId ?? '-'}',
                                            //                                   style: TextStyle(
                                            //                                     color: grey,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 15,
                                            //                                   ),
                                            //                                 ),
                                            //                               ],
                                            //                             ),
                                            //                           ),
                                            //                         ),
                                            //                         const SizedBox(
                                            //                           height:
                                            //                               10,
                                            //                         ),
                                            //                         Padding(
                                            //                           padding: const EdgeInsets
                                            //                               .only(
                                            //                               left:
                                            //                                   0),
                                            //                           child: Text
                                            //                               .rich(
                                            //                             TextSpan(
                                            //                               children: [
                                            //                                 TextSpan(
                                            //                                   text: 'Policy: ',
                                            //                                   style: TextStyle(
                                            //                                     color: blueColor,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 14,
                                            //                                   ),
                                            //                                 ),
                                            //                                 TextSpan(
                                            //                                   text: '${tenant.tenantInsurance?.policyId ?? '-'}',
                                            //                                   style: TextStyle(
                                            //                                     color: grey,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 15,
                                            //                                   ),
                                            //                                 ),
                                            //                               ],
                                            //                             ),
                                            //                           ),
                                            //                         ),
                                            //                         const SizedBox(
                                            //                           height:
                                            //                               10,
                                            //                         ),
                                            //                         Padding(
                                            //                           padding: const EdgeInsets
                                            //                               .only(
                                            //                               left:
                                            //                                   0),
                                            //                           child: Text
                                            //                               .rich(
                                            //                             TextSpan(
                                            //                               children: [
                                            //                                 TextSpan(
                                            //                                   text: 'Liability Coverage: ',
                                            //                                   style: TextStyle(
                                            //                                     color: blueColor,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 14,
                                            //                                   ),
                                            //                                 ),
                                            //                                 TextSpan(
                                            //                                   text: '${tenant.tenantInsurance?.liabilityCoverage ?? '-'}',
                                            //                                   style: TextStyle(
                                            //                                     color: grey,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 15,
                                            //                                   ),
                                            //                                 ),
                                            //                               ],
                                            //                             ),
                                            //                           ),
                                            //                         ),
                                            //                         const SizedBox(
                                            //                           height:
                                            //                               10,
                                            //                         ),
                                            //                         Padding(
                                            //                           padding: const EdgeInsets
                                            //                               .only(
                                            //                               left:
                                            //                                   0),
                                            //                           child: Text
                                            //                               .rich(
                                            //                             TextSpan(
                                            //                               children: [
                                            //                                 TextSpan(
                                            //                                   text: 'Effective Date: ',
                                            //                                   style: TextStyle(
                                            //                                     color: blueColor,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 14,
                                            //                                   ),
                                            //                                 ),
                                            //                                 TextSpan(
                                            //                                   text: '${dateProvider.formatCurrentDate(tenant.tenantInsurance?.effectiveDate ?? '-')}',
                                            //                                   style: TextStyle(
                                            //                                     color: grey,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 15,
                                            //                                   ),
                                            //                                 ),
                                            //                               ],
                                            //                             ),
                                            //                           ),
                                            //                         ),
                                            //                         const SizedBox(
                                            //                           height:
                                            //                               10,
                                            //                         ),
                                            //                         Padding(
                                            //                           padding: const EdgeInsets
                                            //                               .only(
                                            //                               left:
                                            //                                   0),
                                            //                           child: Text
                                            //                               .rich(
                                            //                             TextSpan(
                                            //                               children: [
                                            //                                 TextSpan(
                                            //                                   text: 'Expiration Date: ',
                                            //                                   style: TextStyle(
                                            //                                     color: blueColor,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 14,
                                            //                                   ),
                                            //                                 ),
                                            //                                 TextSpan(
                                            //                                   text: '${dateProvider.formatCurrentDate(tenant.tenantInsurance?.expirationDate ?? '-')}',
                                            //                                   style: TextStyle(
                                            //                                     color: grey,
                                            //                                     fontWeight: FontWeight.bold,
                                            //                                     fontSize: 15,
                                            //                                   ),
                                            //                                 ),
                                            //                               ],
                                            //                             ),
                                            //                           ),
                                            //                         ),
                                            //                         const SizedBox(
                                            //                             height:
                                            //                                 8),
                                            //                       ],
                                            //                     ),
                                            //                   ),
                                            //                 ],
                                            //               ),
                                            //             ),
                                            //         ],
                                            //       );
                                            //     }).toList(),
                                            //   ),
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

                  // if (MediaQuery.of(context).size.width > 500)
                  //   FutureBuilder<List<RentersInsuranceData>>(
                  //     future: _futureRentersInsurance,
                  //     builder: (context, snapshot) {
                  //       if (isLoading) {
                  //         return ShimmerTabletTable();
                  //       } else if (snapshot.hasError) {
                  //         return Center(
                  //             child: Text(errorMessage ?? 'Unknown error'));
                  //       } else if (!snapshot.hasData ||
                  //           snapshot.data!.isEmpty) {
                  //         return const Center(child: Text('No data available'));
                  //       }
                  //
                  //       var data = snapshot.data!;
                  //
                  //       // Apply filtering based on selectedValue and searchValue
                  //       if (selectedValue == null && searchvalue.isEmpty) {
                  //         data = snapshot.data!;
                  //       } else if (selectedValue == "All") {
                  //         data = snapshot.data!;
                  //       } else if (searchvalue.isNotEmpty) {
                  //         data = snapshot.data!
                  //             .where((item) => item.rentalAddress!
                  //                 .toLowerCase()
                  //                 .contains(searchvalue.toLowerCase()))
                  //             .toList();
                  //       } else {
                  //         data = snapshot.data!
                  //             .where(
                  //                 (item) => item.rentalAddress == selectedValue)
                  //             .toList();
                  //       }
                  //       // Apply sorting
                  //       sortData(data);
                  //       // Pagination logic
                  //       final totalPages = (data.length / itemsPerPage).ceil();
                  //       final currentPageData = data
                  //           .skip(currentPage * itemsPerPage)
                  //           .take(itemsPerPage)
                  //           .toList();
                  //
                  //       return SingleChildScrollView(
                  //         child: Padding(
                  //           padding: const EdgeInsets.all(16.0),
                  //           child: Column(
                  //             children: [
                  //               Padding(
                  //                 padding: const EdgeInsets.symmetric(
                  //                     horizontal: 16.0),
                  //                 child: Row(
                  //                   mainAxisAlignment:
                  //                       MainAxisAlignment.spaceBetween,
                  //                   children: [
                  //                     Expanded(
                  //                       child: Material(
                  //                         elevation: 3,
                  //                         borderRadius:
                  //                             BorderRadius.circular(2),
                  //                         child: Container(
                  //                           padding: const EdgeInsets.symmetric(
                  //                               horizontal: 10),
                  //                           height: MediaQuery.of(context)
                  //                                       .size
                  //                                       .width <
                  //                                   500
                  //                               ? 40
                  //                               : 50,
                  //                           decoration: BoxDecoration(
                  //                             color: Colors.white,
                  //                             borderRadius:
                  //                                 BorderRadius.circular(2),
                  //                             border: Border.all(
                  //                                 color:
                  //                                     const Color(0xFF8A95A8)),
                  //                           ),
                  //                           child: TextField(
                  //                             onChanged: (value) {
                  //                               setState(() {
                  //                                 searchvalue = value;
                  //                               });
                  //                             },
                  //                             decoration: const InputDecoration(
                  //                               border: InputBorder.none,
                  //                               hintText: "Search here...",
                  //                               hintStyle: TextStyle(
                  //                                   color: Color(0xFF8A95A8)),
                  //                             ),
                  //                           ),
                  //                         ),
                  //                       ),
                  //                     ),
                  //                     const SizedBox(width: 16),
                  //                     ElevatedButton(
                  //                       style: ElevatedButton.styleFrom(
                  //                         backgroundColor: blueColor,
                  //                       ),
                  //                       onPressed: () {},
                  //                       child: PopupMenuButton<String>(
                  //                         onSelected: (value) async {
                  //                           // Export logic
                  //                           if (value == 'PDF') {
                  //                             print('pdf');
                  //                             generaterentersInsurancePdf(data);
                  //                           } else if (value == 'XLSX') {
                  //                             print('XLSX');
                  //                             generateRentersInsuranceExcel(
                  //                                 data);
                  //                           } else if (value == 'CSV') {
                  //                             print('CSV');
                  //                             generateRentersInsuranceCsv(data);
                  //                           }
                  //                         },
                  //                         itemBuilder: (BuildContext context) =>
                  //                             <PopupMenuEntry<String>>[
                  //                           const PopupMenuItem<String>(
                  //                               value: 'PDF',
                  //                               child: Text('PDF')),
                  //                           const PopupMenuItem<String>(
                  //                               value: 'XLSX',
                  //                               child: Text('XLSX')),
                  //                           const PopupMenuItem<String>(
                  //                               value: 'CSV',
                  //                               child: Text('CSV')),
                  //                         ],
                  //                         child: const Row(
                  //                           mainAxisSize: MainAxisSize.min,
                  //                           children: [
                  //                             Text('Export'),
                  //                             Icon(Icons.arrow_drop_down),
                  //                           ],
                  //                         ),
                  //                       ),
                  //                     )
                  //                   ],
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 20),
                  //               _buildHeaders(),
                  //               const SizedBox(height: 20),
                  //               Container(
                  //                 decoration: BoxDecoration(
                  //                     border: Border.all(color: blueColor)),
                  //                 child: Column(
                  //                   children: currentPageData
                  //                       .asMap()
                  //                       .entries
                  //                       .map((entry) {
                  //                     int rowIndex = entry.key;
                  //                     var item = entry.value;
                  //                     bool isRowExpanded =
                  //                         expandedRowIndex == rowIndex;
                  //
                  //                     return Container(
                  //                       decoration: BoxDecoration(
                  //                         border: Border.all(color: blueColor),
                  //                       ),
                  //                       child: Column(
                  //                         children: <Widget>[
                  //                           ListTile(
                  //                             contentPadding: EdgeInsets.zero,
                  //                             title: Padding(
                  //                               padding:
                  //                                   const EdgeInsets.all(2.0),
                  //                               child: Row(
                  //                                 mainAxisAlignment:
                  //                                     MainAxisAlignment.start,
                  //                                 crossAxisAlignment:
                  //                                     CrossAxisAlignment.center,
                  //                                 children: <Widget>[
                  //                                   InkWell(
                  //                                     onTap: () {
                  //                                       setState(() {
                  //                                         if (expandedRowIndex ==
                  //                                             rowIndex) {
                  //                                           expandedRowIndex =
                  //                                               null;
                  //                                         } else {
                  //                                           expandedRowIndex =
                  //                                               rowIndex;
                  //                                         }
                  //                                       });
                  //                                     },
                  //                                     child: Container(
                  //                                       margin: const EdgeInsets
                  //                                           .only(left: 5),
                  //                                       padding: !isRowExpanded
                  //                                           ? const EdgeInsets
                  //                                               .only(
                  //                                               bottom: 10)
                  //                                           : const EdgeInsets
                  //                                               .only(top: 10),
                  //                                       child: FaIcon(
                  //                                         isRowExpanded
                  //                                             ? FontAwesomeIcons
                  //                                                 .sortUp
                  //                                             : FontAwesomeIcons
                  //                                                 .sortDown,
                  //                                         size: 20,
                  //                                         color: blueColor,
                  //                                       ),
                  //                                     ),
                  //                                   ),
                  //                                   SizedBox(
                  //                                       width: MediaQuery.of(
                  //                                                   context)
                  //                                               .size
                  //                                               .width *
                  //                                           .04),
                  //                                   Expanded(
                  //                                     child: Text(
                  //                                       '${item.rentalAddress ?? '-'}',
                  //                                       style: TextStyle(
                  //                                         color: blueColor,
                  //                                         fontWeight:
                  //                                             FontWeight.bold,
                  //                                         fontSize: 14,
                  //                                       ),
                  //                                     ),
                  //                                   ),
                  //                                 ],
                  //                               ),
                  //                             ),
                  //                           ),
                  //                           // if (isRowExpanded)
                  //                           //   Column(
                  //                           //     children: item.tenants!
                  //                           //         .asMap()
                  //                           //         .entries
                  //                           //         .map((tenantEntry) {
                  //                           //       int tenantIndex =
                  //                           //           tenantEntry.key;
                  //                           //       var tenant =
                  //                           //           tenantEntry.value;
                  //                           //       bool isTenantExpanded =
                  //                           //           expandedTenantIndex[
                  //                           //                   rowIndex] ==
                  //                           //               tenantIndex;
                  //                           //
                  //                           //       return Column(
                  //                           //         children: <Widget>[
                  //                           //           Divider(
                  //                           //             color: blueColor,
                  //                           //           ),
                  //                           //           ListTile(
                  //                           //             contentPadding:
                  //                           //                 EdgeInsets.zero,
                  //                           //             title: Padding(
                  //                           //               padding:
                  //                           //                   const EdgeInsets
                  //                           //                       .all(2.0),
                  //                           //               child: Row(
                  //                           //                 mainAxisAlignment:
                  //                           //                     MainAxisAlignment
                  //                           //                         .start,
                  //                           //                 crossAxisAlignment:
                  //                           //                     CrossAxisAlignment
                  //                           //                         .center,
                  //                           //                 children: <Widget>[
                  //                           //                   InkWell(
                  //                           //                     onTap: () {
                  //                           //                       setState(() {
                  //                           //                         if (expandedTenantIndex[
                  //                           //                                 rowIndex] ==
                  //                           //                             tenantIndex) {
                  //                           //                           expandedTenantIndex[
                  //                           //                                   rowIndex] =
                  //                           //                               null;
                  //                           //                         } else {
                  //                           //                           expandedTenantIndex[
                  //                           //                                   rowIndex] =
                  //                           //                               tenantIndex;
                  //                           //                         }
                  //                           //                       });
                  //                           //                     },
                  //                           //                     child:
                  //                           //                         Container(
                  //                           //                       margin:
                  //                           //                           const EdgeInsets
                  //                           //                               .only(
                  //                           //                               left:
                  //                           //                                   5),
                  //                           //                       padding: !isTenantExpanded
                  //                           //                           ? const EdgeInsets
                  //                           //                               .only(
                  //                           //                               bottom:
                  //                           //                                   10)
                  //                           //                           : const EdgeInsets
                  //                           //                               .only(
                  //                           //                               top:
                  //                           //                                   10),
                  //                           //                       child:
                  //                           //                           Padding(
                  //                           //                         padding: const EdgeInsets
                  //                           //                             .only(
                  //                           //                             left:
                  //                           //                                 24),
                  //                           //                         child:
                  //                           //                             FaIcon(
                  //                           //                           isTenantExpanded
                  //                           //                               ? FontAwesomeIcons
                  //                           //                                   .sortUp
                  //                           //                               : FontAwesomeIcons
                  //                           //                                   .sortDown,
                  //                           //                           size: 20,
                  //                           //                           color:
                  //                           //                               blueColor,
                  //                           //                         ),
                  //                           //                       ),
                  //                           //                     ),
                  //                           //                   ),
                  //                           //                   SizedBox(
                  //                           //                       width: MediaQuery.of(
                  //                           //                                   context)
                  //                           //                               .size
                  //                           //                               .width *
                  //                           //                           .02),
                  //                           //                   Expanded(
                  //                           //                     child: Text(
                  //                           //                       'Tenant ${tenantIndex + 1} : ${tenant.tenantName ?? '-'}',
                  //                           //                       style:
                  //                           //                           TextStyle(
                  //                           //                         color:
                  //                           //                             blueColor,
                  //                           //                         fontWeight:
                  //                           //                             FontWeight
                  //                           //                                 .bold,
                  //                           //                         fontSize:
                  //                           //                             16,
                  //                           //                       ),
                  //                           //                     ),
                  //                           //                   ),
                  //                           //                 ],
                  //                           //               ),
                  //                           //             ),
                  //                           //           ),
                  //                           //           if (isTenantExpanded)
                  //                           //             Container(
                  //                           //               width:
                  //                           //                   double.infinity,
                  //                           //               // color: Colors.amber,
                  //                           //               child: Padding(
                  //                           //                 padding:
                  //                           //                     const EdgeInsets
                  //                           //                         .all(16.0),
                  //                           //                 child: Column(
                  //                           //                   crossAxisAlignment:
                  //                           //                       CrossAxisAlignment
                  //                           //                           .start,
                  //                           //                   children: [
                  //                           //                     Column(
                  //                           //                       crossAxisAlignment:
                  //                           //                           CrossAxisAlignment
                  //                           //                               .start,
                  //                           //                       children: [
                  //                           //                         Row(
                  //                           //                           children: [
                  //                           //                             SizedBox(
                  //                           //                                 width:
                  //                           //                                     MediaQuery.of(context).size.width * .01),
                  //                           //                             Column(
                  //                           //                               crossAxisAlignment:
                  //                           //                                   CrossAxisAlignment.start,
                  //                           //                               children: [
                  //                           //                                 Text(
                  //                           //                                   'Insurance Provider',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: blueColor,
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                                 Text(
                  //                           //                                   '${tenant.tenantInsurance?.policyId ?? '-'}',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: Colors.grey[500],
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                               ],
                  //                           //                             ),
                  //                           //                             SizedBox(
                  //                           //                                 width:
                  //                           //                                     MediaQuery.of(context).size.width * .04),
                  //                           //                             Column(
                  //                           //                               crossAxisAlignment:
                  //                           //                                   CrossAxisAlignment.start,
                  //                           //                               children: [
                  //                           //                                 Text(
                  //                           //                                   'Policy',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: blueColor,
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                                 Text(
                  //                           //                                   '${tenant.tenantInsurance?.policyId ?? '-'}',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: Colors.grey[500],
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                               ],
                  //                           //                             ),
                  //                           //                             SizedBox(
                  //                           //                                 width:
                  //                           //                                     MediaQuery.of(context).size.width * .04),
                  //                           //                             Column(
                  //                           //                               crossAxisAlignment:
                  //                           //                                   CrossAxisAlignment.start,
                  //                           //                               children: [
                  //                           //                                 Text(
                  //                           //                                   'Liability Coverage',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: blueColor,
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                                 Text(
                  //                           //                                   '${tenant.tenantInsurance?.liabilityCoverage ?? '-'}',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: Colors.grey[500],
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                               ],
                  //                           //                             ),
                  //                           //                             SizedBox(
                  //                           //                                 width:
                  //                           //                                     MediaQuery.of(context).size.width * .04),
                  //                           //                             Column(
                  //                           //                               crossAxisAlignment:
                  //                           //                                   CrossAxisAlignment.start,
                  //                           //                               children: [
                  //                           //                                 Text(
                  //                           //                                   'Effective Date',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: blueColor,
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                                 Text(
                  //                           //                                   '${tenant.tenantInsurance?.effectiveDate ?? '-'}',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: Colors.grey[500],
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                               ],
                  //                           //                             ),
                  //                           //                             SizedBox(
                  //                           //                                 width:
                  //                           //                                     MediaQuery.of(context).size.width * .04),
                  //                           //                             Column(
                  //                           //                               crossAxisAlignment:
                  //                           //                                   CrossAxisAlignment.start,
                  //                           //                               children: [
                  //                           //                                 Text(
                  //                           //                                   'Expiration Date',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: blueColor,
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                                 Text(
                  //                           //                                   '${tenant.tenantInsurance?.expirationDate ?? '-'}',
                  //                           //                                   style: TextStyle(
                  //                           //                                     color: Colors.grey[500],
                  //                           //                                     fontWeight: FontWeight.bold,
                  //                           //                                     fontSize: 16,
                  //                           //                                   ),
                  //                           //                                 ),
                  //                           //                               ],
                  //                           //                             ),
                  //                           //                           ],
                  //                           //                         ),
                  //                           //                         const SizedBox(
                  //                           //                           height:
                  //                           //                               10,
                  //                           //                         ),
                  //                           //                       ],
                  //                           //                     ),
                  //                           //                   ],
                  //                           //                 ),
                  //                           //               ),
                  //                           //             ),
                  //                           //         ],
                  //                           //       );
                  //                           //     }).toList(),
                  //                           //   ),
                  //                         ],
                  //                       ),
                  //                     );
                  //                   }).toList(),
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 20),
                  //               Row(
                  //                 mainAxisAlignment: MainAxisAlignment.end,
                  //                 children: [
                  //                   Row(
                  //                     children: [
                  //                       const SizedBox(width: 10),
                  //                       Material(
                  //                         elevation: 3,
                  //                         child: Container(
                  //                           height: 40,
                  //                           padding: const EdgeInsets.symmetric(
                  //                               horizontal: 12.0),
                  //                           decoration: BoxDecoration(
                  //                             border: Border.all(
                  //                                 color: Colors.grey),
                  //                           ),
                  //                           child: DropdownButtonHideUnderline(
                  //                             child: DropdownButton<int>(
                  //                               value: itemsPerPage,
                  //                               items: itemsPerPageOptions
                  //                                   .map((int value) {
                  //                                 return DropdownMenuItem<int>(
                  //                                   value: value,
                  //                                   child:
                  //                                       Text(value.toString()),
                  //                                 );
                  //                               }).toList(),
                  //                               onChanged: (newValue) {
                  //                                 setState(() {
                  //                                   itemsPerPage = newValue!;
                  //                                   currentPage =
                  //                                       0; // Reset to first page when items per page change
                  //                                 });
                  //                               },
                  //                             ),
                  //                           ),
                  //                         ),
                  //                       ),
                  //                     ],
                  //                   ),
                  //                   Row(
                  //                     children: [
                  //                       IconButton(
                  //                         icon: FaIcon(
                  //                           FontAwesomeIcons.circleChevronLeft,
                  //                           color: currentPage == 0
                  //                               ? Colors.grey
                  //                               : blueColor,
                  //                         ),
                  //                         onPressed: currentPage == 0
                  //                             ? null
                  //                             : () {
                  //                                 setState(() {
                  //                                   currentPage--;
                  //                                 });
                  //                               },
                  //                       ),
                  //                       Text(
                  //                           'Page ${currentPage + 1} of $totalPages'),
                  //                       IconButton(
                  //                         icon: FaIcon(
                  //                           FontAwesomeIcons.circleChevronRight,
                  //                           color: currentPage < totalPages - 1
                  //                               ? blueColor
                  //                               : Colors.grey,
                  //                         ),
                  //                         onPressed:
                  //                             currentPage < totalPages - 1
                  //                                 ? () {
                  //                                     setState(() {
                  //                                       currentPage++;
                  //                                     });
                  //                                   }
                  //                                 : null,
                  //                       ),
                  //                     ],
                  //                   ),
                  //                 ],
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       );
                  //     },
                  //   ),

                  //   FutureBuilder<List<RentersInsuranceData>>(
                  //     future: _futureRentersInsurance,
                  //     builder: (context, snapshot) {
                  //       if (isLoading) {
                  //         return Center(
                  //           child: SpinKitFadingCircle(
                  //             color: Colors.black,
                  //             size: 40.0,
                  //           ),
                  //         );
                  //       } else if (snapshot.hasError) {
                  //         return Center(child: Text(errorMessage ?? 'Unknown error'));
                  //       } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  //        return Container(
                  //             height: MediaQuery.of(context).size.height * .5,
                  //             child: Center(
                  //               child: Column(
                  //                 mainAxisAlignment: MainAxisAlignment.center,
                  //                 crossAxisAlignment: CrossAxisAlignment.center,
                  //                 children: [
                  //                   Image.asset("assets/images/no_data_transparent.png",height: 200,width: 200,),
                  //                   SizedBox(height: 10,),
                  //                   Text("No Data Available",style: TextStyle(fontWeight: FontWeight.bold,color:blueColor,fontSize: 16),)
                  //                 ],
                  //               ),
                  //             ),
                  //           );
                  //       }

                  //       var data = snapshot.data!;
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
                  //                   columnWidths: const {
                  //                     0: FlexColumnWidth(),
                  //                     1: FlexColumnWidth(),
                  //                     2: FlexColumnWidth(),
                  //                     3: FlexColumnWidth(),
                  //                   },
                  //                   children: [
                  //                     TableRow(
                  //                       decoration: BoxDecoration(
                  //                         border: Border.all(color: blueColor),
                  //                       ),
                  //                       children: [
                  //                         _buildHeader('Unit', 0,
                  //                             (item) => item.rentalAddress!),
                  //                         _buildHeader('Ten.. Name', 1,
                  //                             (tenant) => tenant.rentalAddress!),
                  //                         _buildHeader(
                  //                             'Provider',
                  //                             2,
                  //                             (tenant) =>
                  //                                 tenant.rentalAddress ?? '-'),
                  //                         _buildHeader('Policy Id', 3,
                  //                             (item) => item.rentalAddress!),
                  //                         _buildHeader('Liability Coverage', 3,
                  //                             (item) => item.rentalAddress!),
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
                  //                     for (var entry in data.asMap().entries)
                  //                       ..._buildExpandableRows(
                  //                           entry.key, entry.value),
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

// List<TableRow> _buildExpandableRows(int rowIndex, RentersInsuranceData item) {
//   return [
//     TableRow(
//       decoration: BoxDecoration(
//         border: Border(
//           left: BorderSide(color: blueColor),
//           right: BorderSide(color: blueColor),
//           top: BorderSide(color: blueColor),
//           bottom: item.tenants!.isEmpty
//               ? BorderSide(color: blueColor)
//               : BorderSide.none,
//         ),
//       ),
//       children: [
//         _buildDataCell(item.rentalAddress ?? '-'),
//         _buildDataCell(''),
//         _buildDataCell(''),
//         _buildDataCell(''),
//         _buildDataCell(''),
//       ],
//     ),
//     for (var tenantEntry in item.tenants!.asMap().entries)
//       TableRow(
//         decoration: BoxDecoration(
//           border: Border(
//             left: BorderSide(color: blueColor),
//             right: BorderSide(color: blueColor),
//             bottom: tenantEntry.key == item.tenants!.length - 1
//                 ? BorderSide(color: blueColor)
//                 : BorderSide.none,
//           ),
//         ),
//         children: [
//           _buildDataCell('${item.tenants!.first.unitDetails ?? '-'}'),
//           _buildDataCell('${tenantEntry.value.tenantName ?? '-'}'),
//           _buildDataCell(
//               '${tenantEntry.value.tenantInsurance?.provider ?? '-'}'),
//           _buildDataCell(
//               ' ${tenantEntry.value.tenantInsurance?.policyId ?? '-'}\n'),
//           _buildDataCell(
//               ' ${tenantEntry.value.tenantInsurance?.liabilityCoverage ?? '-'}\n'),
//         ],
//       ),
//   ];
// }
}
