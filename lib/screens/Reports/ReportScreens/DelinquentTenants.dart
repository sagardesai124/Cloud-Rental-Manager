import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:three_zero_two_property/constant/constant.dart';
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
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class DelinquentTenants extends StatefulWidget {
  @override
  State<DelinquentTenants> createState() => _DelinquentTenantsState();
}

class _DelinquentTenantsState extends State<DelinquentTenants>
    with NetworkRetryState {
  late Future<List<DelinquentTenantsData>> _futureRentersInsurance;
  List<DelinquentTenantsData> DelinquentTenantsModel = [];
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
    _futureRentersInsurance = fetchDelinquentTenantsData();
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

  Future<List<DelinquentTenantsData>> fetchDelinquentTenantsData() async {
    try {
      List<DelinquentTenantsData> data =
          await DelinquentTenantsSerivce().fetchDelinquentTenants();
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
                'Failed to load delinquent tenants data. Please try again later.');
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
      _futureRentersInsurance = fetchDelinquentTenantsData();
    });
  }

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
                child: const Icon(
                  Icons.expand_less,
                  color: Colors.transparent,
                ),
              ),
              // Web parity: the web Delinquent Tenants report has no column
              // sorting, so this header is a plain label. The sort arrow that
              // used to sit here flipped on tap but never reordered anything —
              // its handler ended in a "// Sorting logic here" placeholder —
              // which read as a broken filter. The label itself is unchanged.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text("Leases",
                      style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
              // Expanded(
              //   child: InkWell(
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
              //   child: InkWell(
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
      // apiGet, not a raw http.get: this call used to bypass the shared
      // network layer, so when it failed the app never learned about it. The
      // table still rendered and the screen looked healthy while the report
      // totals were quietly missing — the only symptom was a broken export.
      final response = await apiGet(
          Uri.parse('$Api_url/api/charge/delinquent/$adminId'),
          headers: {
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

  Future<void> generateDelinquentTenantsPdf(
      List<DelinquentTenantsData> delinquentTenantsData) async {
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
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 50, height: 50),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Delinquent Tenants',
                        style: pw.TextStyle(
                          fontSize: 18,
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
            ),
            pw.Table.fromTextArray(
              headers: [
                'Unit',
                'Tenant',
                'Total',
                '0-30 days',
                '31-60 days',
                '61-90 days',
                '91+ days',
              ],
              data: _generateTableData(delinquentTenantsData),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Delinquent_tenants.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Delinquent_tenants',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  List<List<String>> _generateTableData(
      List<DelinquentTenantsData> delinquentTenantsData) {
    final List<List<String>> tableData = [];

    for (var item in delinquentTenantsData) {
      tableData.add([
        item.rentalAddress ?? '',
        '',
        '',
        '',
        '',
        '',
        '',
      ]);
      for (var tenant in item.tenants!) {
        tableData.add([
          '${tenant.unitDetails}',
          tenant.tenantName ?? '',
          formatCurrency(double.tryParse(
              tenant.pdfDelinquentTenantsData!.totalDaysAmount ?? '0')),
          '\$${tenant.pdfDelinquentTenantsData!.last30Days}',
          '\$${tenant.pdfDelinquentTenantsData!.last31To60Days}',
          '\$${tenant.pdfDelinquentTenantsData!.last61To90Days}',
          '\$${tenant.pdfDelinquentTenantsData!.last91PlusDays}',
        ]);
      }
      tableData.add([
        'Total ',
        '',
        formatCurrency(
            double.tryParse(item.alltotalamount!.totalDaysAmount ?? '0')),
        formatMoney(item.alltotalamount!.last30Days),
        formatMoney(item.alltotalamount!.last31To60Days),
        formatMoney(item.alltotalamount!.last61To90Days),
        formatMoney(item.alltotalamount!.last91PlusDays),
      ]);
    }
    // The totals fetch returns null when that request fails (its catch
    // swallows the error and the table still renders), so this used to throw
    // "Null check operator used on a null value" mid-export — no file and no
    // message. Omit just the grand-total row instead; the per-property totals
    // above are still worth exporting. Matches how the Staff CSV already
    // handles it.
    final grandTotal = globalDelinquentTenantsData;
    if (grandTotal != null) {
      tableData.add([
        'Grand Total of all Properties',
        '',
        formatCurrency(double.tryParse(grandTotal.totalDaysAmount ?? '0')),
        formatMoney(grandTotal.last30Days),
        formatMoney(grandTotal.last31To60Days),
        formatMoney(grandTotal.last61To90Days),
        formatMoney(grandTotal.last91PlusDays),
      ]);
    }

    return tableData;
  }

  Future<void> generateDelinquentTenantsExcel(
      List<DelinquentTenantsData> delinquentTenantsData) async {
    // Fetch grand total data
    setState(() {
      istenantDataLoading = true;
    });

    final globalDelinquentTenantsData =
        await fetchDelinquentTenantsGrandTotal();

    setState(() {
      istenantDataLoading = false;
    });

    // Create a new workbook
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];

    // Set column widths
    sheet.getRangeByName('A1:G1').columnWidth = 25;

    // Define headers
    final List<String> headers = [
      'Unit',
      'Tenant',
      'Total',
      '0-30 days',
      '31-60 days',
      '61-90 days',
      '91+ days',
    ];

    // Style for headers
    final syncXlsx.Style headerCellStyle =
        workbook.styles.add('headerCellStyle');
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#D3D3D3';
    headerCellStyle.hAlign = syncXlsx.HAlignType.center;

    // Add headers to the first row
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    int rowIndex = 2; // Start from the second row
    for (var item in delinquentTenantsData) {
      // Add main row with rental address
      sheet.getRangeByIndex(rowIndex, 1).setText(item.rentalAddress ?? '');
      for (int col = 2; col <= 7; col++) {
        sheet.getRangeByIndex(rowIndex, col).setText('');
      }

      rowIndex++; // Move to the next row for tenant details

      // Add tenant details in subsequent rows
      for (var tenant in item.tenants!) {
        sheet.getRangeByIndex(rowIndex, 1).setText(tenant.unitDetails ?? '');
        sheet.getRangeByIndex(rowIndex, 2).setText(tenant.tenantName ?? '');
        sheet.getRangeByIndex(rowIndex, 3).setText(formatCurrency(
            double.tryParse(
                tenant.pdfDelinquentTenantsData!.totalDaysAmount ?? '0')));
        sheet
            .getRangeByIndex(rowIndex, 4)
            .setText('\$${tenant.pdfDelinquentTenantsData!.last30Days}');
        sheet
            .getRangeByIndex(rowIndex, 5)
            .setText('\$${tenant.pdfDelinquentTenantsData!.last31To60Days}');
        sheet
            .getRangeByIndex(rowIndex, 6)
            .setText('\$${tenant.pdfDelinquentTenantsData!.last61To90Days}');
        sheet
            .getRangeByIndex(rowIndex, 7)
            .setText('\$${tenant.pdfDelinquentTenantsData!.last91PlusDays}');
        rowIndex++; // Move to the next row
      }

      // Add totals row
      sheet.getRangeByIndex(rowIndex, 1).setText('Total');
      sheet.getRangeByIndex(rowIndex, 2).setText('');
      sheet.getRangeByIndex(rowIndex, 3).setText(formatCurrency(
          double.tryParse(item.alltotalamount!.totalDaysAmount ?? '0')));
      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(formatMoney(item.alltotalamount!.last30Days));
      sheet
          .getRangeByIndex(rowIndex, 5)
          .setText(formatMoney(item.alltotalamount!.last31To60Days));
      sheet
          .getRangeByIndex(rowIndex, 6)
          .setText(formatMoney(item.alltotalamount!.last61To90Days));
      sheet
          .getRangeByIndex(rowIndex, 7)
          .setText(formatMoney(item.alltotalamount!.last91PlusDays));
      rowIndex++; // Move to the next row
    }

    // Add grand total row — only when the totals fetch actually returned.
    // Force-unwrapping it threw mid-export when that request had failed,
    // leaving no file and no message.
    final grandTotal = globalDelinquentTenantsData;
    if (grandTotal != null) {
      sheet
          .getRangeByIndex(rowIndex, 1)
          .setText('Grand Total of all Properties');
      sheet.getRangeByIndex(rowIndex, 2).setText('');
      sheet.getRangeByIndex(rowIndex, 3).setText(
          formatCurrency(double.tryParse(grandTotal.totalDaysAmount ?? '0')));
      sheet
          .getRangeByIndex(rowIndex, 4)
          .setText(formatMoney(grandTotal.last30Days));
      sheet
          .getRangeByIndex(rowIndex, 5)
          .setText(formatMoney(grandTotal.last31To60Days));
      sheet
          .getRangeByIndex(rowIndex, 6)
          .setText(formatMoney(grandTotal.last61To90Days));
      sheet
          .getRangeByIndex(rowIndex, 7)
          .setText(formatMoney(grandTotal.last91PlusDays));
    }

    // Save workbook as a byte stream
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'DelinquentTenantsReport_$formattedDate.xlsx';

    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    // Write file to the path
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(path)]);
    // Show success toast message
    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
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

  /// Search box and Export, shown in every state of the report. Export is
  /// greyed out and not tappable while the report has no data, like every
  /// other report.
  Widget _buildToolbar(List<DelinquentTenantsData> data) {
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
              // Flat: the elevation-3 shadow made the search field
              // sit proud of the flat Export button beside it.
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
          SizedBox(
            // Same height as the search field beside
            // it (48 narrow / 50 wide).
            height: MediaQuery.of(context)
                        .size
                        .width <
                    500
                ? 48
                : 50,
            child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blueColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white,
            ),
            onPressed: hasData ? () {} : null,
            child: PopupMenuButton<String>(
              enabled: hasData,
              onSelected: (value) async {
                // Export logic
                if (value == 'PDF') {
                  generateDelinquentTenantsPdf(data);
                } else if (value == 'XLSX') {
                  generateDelinquentTenantsExcel(
                      data);
                } else if (value == 'CSV') {
                  generateDelinquentTenantsCsv(data);
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
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      drawer: CustomDrawer(
        currentpage: "Report",
        dropdown: false,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  ReportHeader(
                    title: "Delinquent Tenants",
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width < 500)
                  FutureBuilder<List<DelinquentTenantsData>>(
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
                        // Every field here is nullable: rental_address is a
                        // derived lease -> unit -> rental value, `tenants` is
                        // left null by the model when the key is absent, and
                        // tenant_name can be missing. Force-unwrapping them
                        // threw inside .where() during build, which took the
                        // whole report down instead of skipping one row.
                        final String query = searchvalue.toLowerCase();
                        data = snapshot.data!.where((item) {
                          final bool matchesAddress =
                              (item.rentalAddress ?? '')
                                  .toLowerCase()
                                  .contains(query);
                          final bool matchesTenant =
                              (item.tenants ?? const []).any((tenant) =>
                                  (tenant.tenantName ?? '')
                                      .toLowerCase()
                                      .contains(query));
                          return matchesAddress || matchesTenant;
                        }).toList();
                      } else {
                        data = snapshot.data!
                            .where(
                                (item) => item.rentalAddress == selectedValue)
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
                              _buildToolbar(data),
                              const SizedBox(height: 20),
                              _buildHeaders(),
                              const SizedBox(height: 10),
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
                                      int rowIndex = entry.key;
                                      var item = entry.value;
                                      bool isRowExpanded =
                                          expandedRowIndex == rowIndex;

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
                                                          color: isRowExpanded
                                                              ? blueColor
                                                              : blueColor,
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
                                                        '${item.rentalAddress ?? '-'}',
                                                        style: TextStyle(
                                                          color: blueColor,
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
                                              Column(
                                                children: item.tenants!
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
                                                    children: <Widget>[
                                                      Divider(
                                                        color: blueColor,
                                                      ),
                                                      ListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(2.0),
                                                          child: Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: <Widget>[
                                                              InkWell(
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
                                                                child:
                                                                    Container(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              5),
                                                                  padding: !isTenantExpanded
                                                                      ? const EdgeInsets
                                                                          .only(
                                                                          bottom:
                                                                              10)
                                                                      : const EdgeInsets
                                                                          .only(
                                                                          top:
                                                                              10),
                                                                  child:
                                                                      Padding(
                                                                    padding: const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            24),
                                                                    child:
                                                                        FaIcon(
                                                                      isTenantExpanded
                                                                          ? FontAwesomeIcons
                                                                              .sortUp
                                                                          : FontAwesomeIcons
                                                                              .sortDown,
                                                                      size: 20,
                                                                      color: isTenantExpanded
                                                                          ? blueColor
                                                                          : blueColor,
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
                                                                          color:
                                                                              Colors.grey[600],
                                                                          fontWeight:
                                                                              FontWeight.w500,
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
                                                                              FontWeight.bold,
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
                                                          width:
                                                              double.infinity,
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            36.0),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0),
                                                                      child: Text
                                                                          .rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Total Amount',
                                                                              style: TextStyle(
                                                                                color: blueColor,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 14,
                                                                              ),
                                                                            ),
                                                                            TextSpan(
                                                                              text: ' :  ${formatCurrency(double.tryParse(tenant.pdfDelinquentTenantsData!.totalDaysAmount ?? '0'))}',
                                                                              style: TextStyle(
                                                                                color: Colors.grey[500],
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 15,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          10,
                                                                    ),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0),
                                                                      child: Text
                                                                          .rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Last 30 Days',
                                                                              style: TextStyle(
                                                                                color: blueColor,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 14,
                                                                              ),
                                                                            ),
                                                                            TextSpan(
                                                                              text: ' :  \$${tenant.pdfDelinquentTenantsData!.last30Days ?? '-'}',
                                                                              style: TextStyle(
                                                                                color: Colors.grey[500],
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 15,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          10,
                                                                    ),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0),
                                                                      child: Text
                                                                          .rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Last 31 to 60 days',
                                                                              style: TextStyle(
                                                                                color: blueColor,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 14,
                                                                              ),
                                                                            ),
                                                                            TextSpan(
                                                                              text: ' :  \$${tenant.pdfDelinquentTenantsData!.last31To60Days ?? '-'}',
                                                                              style: TextStyle(
                                                                                color: Colors.grey[500],
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 15,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          10,
                                                                    ),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0),
                                                                      child: Text
                                                                          .rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Last 61 to 90 Days',
                                                                              style: TextStyle(
                                                                                color: blueColor,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 14,
                                                                              ),
                                                                            ),
                                                                            TextSpan(
                                                                              text: ' :  \$${tenant.pdfDelinquentTenantsData!.last61To90Days ?? '-'}',
                                                                              style: TextStyle(
                                                                                color: Colors.grey[500],
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 15,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          10,
                                                                    ),
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0),
                                                                      child: Text
                                                                          .rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Last 91+ Days',
                                                                              style: TextStyle(
                                                                                color: blueColor,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 14,
                                                                              ),
                                                                            ),
                                                                            TextSpan(
                                                                              text: ' :  \$${tenant.pdfDelinquentTenantsData!.last91PlusDays ?? '-'}',
                                                                              style: TextStyle(
                                                                                color: Colors.grey[500],
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 15,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
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
                  //   FutureBuilder<List<DelinquentTenantsData>>(
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
                  //             .where((item) =>
                  //                 item.rentalAddress!
                  //                     .toLowerCase()
                  //                     .contains(searchvalue.toLowerCase()) ||
                  //                 item.tenants!.any((tenant) => tenant
                  //                     .tenantName!
                  //                     .toLowerCase()
                  //                     .contains(searchvalue.toLowerCase())))
                  //             .toList();
                  //       } else {
                  //         data = snapshot.data!
                  //             .where(
                  //                 (item) => item.rentalAddress == selectedValue)
                  //             .toList();
                  //       }
                  //
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
                  //                     horizontal: 0.0),
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
                  //                               ? 48
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
                  //                             generateDelinquentTenantsPdf(
                  //                                 data);
                  //                           } else if (value == 'XLSX') {
                  //                             print('XLSX');
                  //                             generateDelinquentTenantsExcel(
                  //                                 data);
                  //                           } else if (value == 'CSV') {
                  //                             print('CSV');
                  //                             generateDelinquentTenantsCsv(
                  //                                 data);
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
                  //                 // decoration: BoxDecoration(
                  //                 //     border: Border.all(color: blueColor)),
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
                  //                         color: rowIndex % 2 != 0
                  //                             ? Colors.white
                  //                             : blueColor.withOpacity(0.09),
                  //                         border: Border.all(color: blueColor),
                  //                       ),
                  //                       // decoration: BoxDecoration(
                  //                       //   border: Border.all(color: blueColor),
                  //                       // ),
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
                  //                                         color: isRowExpanded
                  //                                             ? blueColor
                  //                                             : blueColor,
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
                  //                                         fontSize: 16,
                  //                                       ),
                  //                                     ),
                  //                                   ),
                  //                                 ],
                  //                               ),
                  //                             ),
                  //                           ),
                  //                           if (isRowExpanded)
                  //                             Column(
                  //                               children: item.tenants!
                  //                                   .asMap()
                  //                                   .entries
                  //                                   .map((tenantEntry) {
                  //                                 int tenantIndex =
                  //                                     tenantEntry.key;
                  //                                 var tenant =
                  //                                     tenantEntry.value;
                  //                                 bool isTenantExpanded =
                  //                                     expandedTenantIndex[
                  //                                             rowIndex] ==
                  //                                         tenantIndex;
                  //
                  //                                 return Column(
                  //                                   children: <Widget>[
                  //                                     Divider(
                  //                                       color: blueColor,
                  //                                     ),
                  //                                     ListTile(
                  //                                       contentPadding:
                  //                                           EdgeInsets.zero,
                  //                                       title: Padding(
                  //                                         padding:
                  //                                             const EdgeInsets
                  //                                                 .all(2.0),
                  //                                         child: Row(
                  //                                           mainAxisAlignment:
                  //                                               MainAxisAlignment
                  //                                                   .start,
                  //                                           crossAxisAlignment:
                  //                                               CrossAxisAlignment
                  //                                                   .center,
                  //                                           children: <Widget>[
                  //                                             InkWell(
                  //                                               onTap: () {
                  //                                                 setState(() {
                  //                                                   if (expandedTenantIndex[
                  //                                                           rowIndex] ==
                  //                                                       tenantIndex) {
                  //                                                     expandedTenantIndex[
                  //                                                             rowIndex] =
                  //                                                         null;
                  //                                                   } else {
                  //                                                     expandedTenantIndex[
                  //                                                             rowIndex] =
                  //                                                         tenantIndex;
                  //                                                   }
                  //                                                 });
                  //                                               },
                  //                                               child:
                  //                                                   Container(
                  //                                                 margin:
                  //                                                     const EdgeInsets
                  //                                                         .only(
                  //                                                         left:
                  //                                                             5),
                  //                                                 padding: !isTenantExpanded
                  //                                                     ? const EdgeInsets
                  //                                                         .only(
                  //                                                         bottom:
                  //                                                             10)
                  //                                                     : const EdgeInsets
                  //                                                         .only(
                  //                                                         top:
                  //                                                             10),
                  //                                                 child:
                  //                                                     Padding(
                  //                                                   padding: const EdgeInsets
                  //                                                       .only(
                  //                                                       left:
                  //                                                           24),
                  //                                                   child:
                  //                                                       FaIcon(
                  //                                                     isTenantExpanded
                  //                                                         ? FontAwesomeIcons
                  //                                                             .sortUp
                  //                                                         : FontAwesomeIcons
                  //                                                             .sortDown,
                  //                                                     size: 20,
                  //                                                     color: isTenantExpanded
                  //                                                         ? blueColor
                  //                                                         : blueColor,
                  //                                                   ),
                  //                                                 ),
                  //                                               ),
                  //                                             ),
                  //                                             SizedBox(
                  //                                                 width: MediaQuery.of(
                  //                                                             context)
                  //                                                         .size
                  //                                                         .width *
                  //                                                     .02),
                  //                                             Expanded(
                  //                                               child: RichText(
                  //                                                   text: TextSpan(
                  //                                                       children: [
                  //                                                     TextSpan(
                  //                                                       text:
                  //                                                           'Tenant ${tenantIndex + 1} ',
                  //                                                       style:
                  //                                                           TextStyle(
                  //                                                         color:
                  //                                                             Colors.grey[600],
                  //                                                         fontWeight:
                  //                                                             FontWeight.w500,
                  //                                                         fontSize:
                  //                                                             14,
                  //                                                       ),
                  //                                                     ),
                  //                                                     TextSpan(
                  //                                                       text:
                  //                                                           ': ${tenant.tenantName ?? '-'}',
                  //                                                       style:
                  //                                                           TextStyle(
                  //                                                         color:
                  //                                                             blueColor,
                  //                                                         fontWeight:
                  //                                                             FontWeight.bold,
                  //                                                         fontSize:
                  //                                                             14,
                  //                                                       ),
                  //                                                     ),
                  //                                                   ])),
                  //                                             ),
                  //                                           ],
                  //                                         ),
                  //                                       ),
                  //                                     ),
                  //                                     if (isTenantExpanded)
                  //                                       Container(
                  //                                         width:
                  //                                             double.infinity,
                  //                                         // color: Colors.amber,
                  //                                         child: Padding(
                  //                                           padding:
                  //                                               const EdgeInsets
                  //                                                   .all(16.0),
                  //                                           child: Column(
                  //                                             crossAxisAlignment:
                  //                                                 CrossAxisAlignment
                  //                                                     .start,
                  //                                             children: [
                  //                                               Column(
                  //                                                 crossAxisAlignment:
                  //                                                     CrossAxisAlignment
                  //                                                         .start,
                  //                                                 children: [
                  //                                                   SingleChildScrollView(
                  //                                                     scrollDirection:
                  //                                                         Axis.horizontal,
                  //                                                     child:
                  //                                                         Row(
                  //                                                       children: [
                  //                                                         SizedBox(
                  //                                                             width: MediaQuery.of(context).size.width * .06),
                  //                                                         Column(
                  //                                                           crossAxisAlignment:
                  //                                                               CrossAxisAlignment.start,
                  //                                                           children: [
                  //                                                             Text(
                  //                                                               'Total Amount',
                  //                                                               style: TextStyle(
                  //                                                                 color: blueColor,
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                             Text(
                  //                                                               formatCurrency(double.tryParse(tenant.pdfDelinquentTenantsData!.totalDaysAmount ?? '0')),
                  //                                                               style: TextStyle(
                  //                                                                 color: Colors.grey[500],
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                           ],
                  //                                                         ),
                  //                                                         SizedBox(
                  //                                                             width: MediaQuery.of(context).size.width * .04),
                  //                                                         Column(
                  //                                                           crossAxisAlignment:
                  //                                                               CrossAxisAlignment.start,
                  //                                                           children: [
                  //                                                             Text(
                  //                                                               'Last 30 Days',
                  //                                                               style: TextStyle(
                  //                                                                 color: blueColor,
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                             Text(
                  //                                                               '${tenant.pdfDelinquentTenantsData!.last30Days ?? '-'}',
                  //                                                               style: TextStyle(
                  //                                                                 color: Colors.grey[500],
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                           ],
                  //                                                         ),
                  //                                                         SizedBox(
                  //                                                             width: MediaQuery.of(context).size.width * .04),
                  //                                                         Column(
                  //                                                           crossAxisAlignment:
                  //                                                               CrossAxisAlignment.start,
                  //                                                           children: [
                  //                                                             Text(
                  //                                                               'Last 31 to 60 days',
                  //                                                               style: TextStyle(
                  //                                                                 color: blueColor,
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                             Text(
                  //                                                               '${tenant.pdfDelinquentTenantsData!.last31To60Days ?? '-'}',
                  //                                                               style: TextStyle(
                  //                                                                 color: Colors.grey[500],
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                           ],
                  //                                                         ),
                  //                                                         SizedBox(
                  //                                                             width: MediaQuery.of(context).size.width * .04),
                  //                                                         Column(
                  //                                                           crossAxisAlignment:
                  //                                                               CrossAxisAlignment.start,
                  //                                                           children: [
                  //                                                             Text(
                  //                                                               'Last 61 to 90 Days',
                  //                                                               style: TextStyle(
                  //                                                                 color: blueColor,
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                             Text(
                  //                                                               '${tenant.pdfDelinquentTenantsData!.last61To90Days ?? '-'}',
                  //                                                               style: TextStyle(
                  //                                                                 color: Colors.grey[500],
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                           ],
                  //                                                         ),
                  //                                                         SizedBox(
                  //                                                             width: MediaQuery.of(context).size.width * .04),
                  //                                                         Column(
                  //                                                           crossAxisAlignment:
                  //                                                               CrossAxisAlignment.start,
                  //                                                           children: [
                  //                                                             Text(
                  //                                                               'Last 91+ Days',
                  //                                                               style: TextStyle(
                  //                                                                 color: blueColor,
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                             Text(
                  //                                                               '${tenant.pdfDelinquentTenantsData!.last91PlusDays ?? '-'}',
                  //                                                               style: TextStyle(
                  //                                                                 color: Colors.grey[500],
                  //                                                                 fontWeight: FontWeight.bold,
                  //                                                                 fontSize: 16,
                  //                                                               ),
                  //                                                             ),
                  //                                                           ],
                  //                                                         ),
                  //                                                       ],
                  //                                                     ),
                  //                                                   ),
                  //                                                   const SizedBox(
                  //                                                     height:
                  //                                                         10,
                  //                                                   ),
                  //                                                 ],
                  //                                               ),
                  //                                             ],
                  //                                           ),
                  //                                         ),
                  //                                       ),
                  //                                   ],
                  //                                 );
                  //                               }).toList(),
                  //                             ),
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
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
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
}
