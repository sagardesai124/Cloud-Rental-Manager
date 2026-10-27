import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/report_date_range.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

import '../../../Model/profile.dart';
import '../../../repository/GetAdminAddressPdf.dart';
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:three_zero_two_property/widgets/report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';

import '../../../repository/daily_transaction_report.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

// // Sample data model class
//
// // Create a function to generate PDF
//
// List<List<dynamic>> _generateTableData(
//     List<Transaction> delinquentTenantsData) {
//   final List<List<dynamic>> tableData = [];
//
//   for (var item in delinquentTenantsData) {
//     // Main row
//     tableData.add([
//       pw.Text(
//         item.property ?? '',
//         style: pw.TextStyle(
//             fontSize: 10, fontWeight: pw.FontWeight.bold), // Bold style applied
//       ),
//       pw.Text(
//         item.tenantFirstName ?? '',
//         style: pw.TextStyle(
//             fontSize: 10, fontWeight: pw.FontWeight.bold), // Bold style applied
//       ),
//       pw.Text(
//         formatDate(item.createdAt.toString()) ?? '',
//         style: pw.TextStyle(
//             fontSize: 10, fontWeight: pw.FontWeight.bold), // Bold style applied
//       ),
//       pw.Text(
//         item.transactionId ?? '',
//         style: pw.TextStyle(
//             fontSize: 10, fontWeight: pw.FontWeight.bold), // Bold style applied
//       ),
//       pw.Text(
//         item.paymentType ?? '',
//         style: pw.TextStyle(
//             fontSize: 10, fontWeight: pw.FontWeight.bold), // Bold style applied
//       ),
//       pw.Text(
//         item.ccNumber ?? '',
//         style: pw.TextStyle(
//             fontSize: 10, fontWeight: pw.FontWeight.bold), // Bold style applied
//       ),
//       pw.Align(
//         alignment:
//             pw.Alignment.centerRight, // Aligns the total amount to the right
//         child: pw.Text(
//           "\$${item.totalAmount.toString()}" ?? '',
//           style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//         ),
//       ),
//     ]);
// // Subrow with concatenated data in a single row
//     String subrowDescriptions = '';
//     String subrowAmounts = '';
//
//     for (var tenant in item.entries!) {
//       subrowDescriptions +=
//           '${tenant.description ?? ''}\n'; // Concatenate descriptions
//       subrowAmounts +=
//           '\$${tenant.amount?.toString() ?? '0'}\n'; // Concatenate amounts
//     }
//
//     // Remove trailing commas and spaces
//     subrowDescriptions =
//         subrowDescriptions.trim().replaceAll(RegExp(r',$'), '');
//     subrowAmounts = subrowAmounts.trim().replaceAll(RegExp(r',$'), '');
//
//     tableData.add([
//       pw.Column(
//         crossAxisAlignment: pw.CrossAxisAlignment.end,
//         mainAxisAlignment: pw.MainAxisAlignment.end,
//         children: [
//           pw.Text(
//             subrowDescriptions,
//             style: pw.TextStyle(fontSize: 10),
//           ),
//         ],
//       ),
//       '',
//       '',
//       '',
//       '',
//       '',
//       pw.Align(
//         alignment:
//             pw.Alignment.centerRight, // Aligns the total amount to the right
//         child: pw.Text(
//           subrowAmounts,
//           textAlign: pw.TextAlign.right,
//           style: pw.TextStyle(fontSize: 10),
//         ),
//       ),
//     ]);
//     // Subrow with colspan (simulated by creating a container)
//     /*  for (var tenant in item.entries!) {
//       tableData.add([
//         pw.Column(
//           children: [
//             pw.Container(
//               //color: PdfColors.cyan,
//               width: 320, // Adjust width to span multiple columns
//               padding: pw.EdgeInsets.symmetric(vertical: 5,horizontal: 5),
//               child: pw.Text(tenant.description ?? '',
//                   style: pw.TextStyle(fontSize: 10)),
//             ),
//           ],
//         ),
//         '',
//         '',
//         '',
//         '',
//         '',
//         "\$${tenant.amount.toString()}" ?? '',
//       ]);
//     }*/
//   }
//
//   return tableData;
// }
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatefulWidget {
//   @override
//   State<MyApp> createState() => _MyAppState();
// }
//
// class _MyAppState extends State<MyApp> {
//   double grandTotals = 0;
//   Future<void> generateWorkOrderPdf(List<Transaction> workOrderData) async {
//     final GetAddressAdminPdfService service = GetAddressAdminPdfService();
//     profile? profileData;
//
//     try {
//       profileData = await service.fetchAdminAddress();
//     } catch (e) {
//       // Handle error
//       print("Error fetching profile data: $e");
//       return;
//     }
//     final pdf = pw.Document();
//     final image = pw.MemoryImage(
//       (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
//     );
//     final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
//
//     pdf.addPage(
//       pw.MultiPage(
//         pageFormat: PdfPageFormat.a4.landscape,
//         margin: const pw.EdgeInsets.all(30),
//         header: (pw.Context context) => pw.Row(
//           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//           children: [
//             pw.Image(image, width: 50, height: 50),
//             pw.SizedBox(width: 10),
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               mainAxisAlignment: pw.MainAxisAlignment.start,
//               children: [
//                 pw.Text(
//                   'Daily Transactions',
//                   style: pw.TextStyle(
//                     fontSize: 18,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.SizedBox(height: 10),
//                 pw.Text('As of $currentDate'),
//               ],
//             ),
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.end,
//               children: [
//                 pw.Text(
//                   profileData?.companyName?.isNotEmpty == true
//                       ? profileData!.companyName!
//                       : 'N/A',
//                   style: pw.TextStyle(
//                     fontSize: 10,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.Text(
//                   profileData?.companyAddress?.isNotEmpty == true
//                       ? profileData!.companyAddress!
//                       : 'N/A',
//                   style: pw.TextStyle(
//                     fontSize: 10,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.Text(
//                   '${profileData?.companyCity?.isNotEmpty == true ? profileData!.companyCity! : 'N/A'}, '
//                   '${profileData?.companyState?.isNotEmpty == true ? profileData!.companyState! : 'N/A'}, '
//                   '${profileData?.companyCountry?.isNotEmpty == true ? profileData!.companyCountry! : 'N/A'}',
//                   style: pw.TextStyle(
//                     fontSize: 10,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.Text(
//                   profileData?.companyPostalCode?.isNotEmpty == true
//                       ? profileData!.companyPostalCode!
//                       : 'N/A',
//                   style: pw.TextStyle(
//                     fontSize: 10,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.SizedBox(height: 30)
//               ],
//             ),
//           ],
//         ),
//         footer: (pw.Context context) {
//           return pw.Container(
//             alignment: pw.Alignment.centerRight,
//             margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
//             child: pw.Text(
//               'Page ${context.pageNumber} of ${context.pagesCount}',
//               style: pw.TextStyle(color: PdfColors.grey),
//             ),
//           );
//         },
//         build: (pw.Context context) => [
//           pw.Table.fromTextArray(
//             headers: [
//               'Property',
//               'Tenant',
//               'Date',
//               'Transaction ID',
//               'Type',
//               'Reference',
//               'Total'
//             ],
//             data: _generateTableData(workOrderData),
//             border: null,
//             headerAlignment: pw.Alignment.centerLeft,
//             // cellAlignment: pw.Alignment.center,
//             headerDecoration: pw.BoxDecoration(
//               color: PdfColors.blue400,
//             ),
//             headerStyle: pw.TextStyle(
//               fontWeight: pw.FontWeight.bold,
//               fontSize: 12,
//             ),
//             cellStyle: pw.TextStyle(
//               fontSize: 10,
//             ),
//             cellHeight: 20,
//             columnWidths: {
//               0: pw.FlexColumnWidth(2), // Date
//               1: pw.FlexColumnWidth(1.5), // Address
//               2: pw.FlexColumnWidth(1), // Work
//               3: pw.FlexColumnWidth(1.5), // Performed
//               4: pw.FlexColumnWidth(1), // Performed
//               5: pw.FlexColumnWidth(1.5), // Performed
//               6: pw.FlexColumnWidth(.8), // Performed
//             },
//           ),
//           pw.SizedBox(height: 50),
//           pw.Divider(),
//           pw.SizedBox(height: 10),
//           pw.Divider(),
//           pw.SizedBox(height: 20),
//           pw.Align(
//               alignment: pw.Alignment.centerRight,
//               child: pw.Text("Total :-  \$${grandTotals}",
//                   style: pw.TextStyle(
//                       fontSize: 20, fontWeight: pw.FontWeight.bold)))
//         ],
//       ),
//     );
//
//     await Printing.layoutPdf(
//       format: PdfPageFormat.a4.landscape,
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//     );
//   }
//
//   Future<List<Transaction>> fetchTransactions(String date) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     String? id = prefs.getString("adminId");
//     String? token = prefs.getString('token');
//
//     final response = await http.get(
//       Uri.parse(
//           'https://saas.cloudrentalmanager.com/api/payment/todayspayment/1716391492591?selectedDate=$date'),
//       headers: {
//         'Content-Type': 'application/json',
//         "authorization": "CRM $token",
//         "id": "CRM $id",
//       },
//     );
//     print(response.body);
//
//     if (response.statusCode == 200) {
//       final List<dynamic> jsonData = json.decode(response.body)["data"];
//       return parseTransactions(jsonData);
//     } else {
//       throw Exception('Failed to load transactions');
//     }
//   }
//
//   List<List<dynamic>> _generateTableData(
//       List<Transaction> delinquentTenantsData) {
//     final List<List<dynamic>> tableData = [];
//     double grandTotal = 0;
//     for (var item in delinquentTenantsData) {
//       // Main row
//
//       grandTotal += item.totalAmount ?? 0;
//
//       tableData.add([
//         pw.Text(
//           item.property ?? '',
//           style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold), // Bold style applied
//         ),
//         pw.Text(
//           "${item.tenantFirstName} ${item.tenantLastName}" ?? '',
//           style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold), // Bold style applied
//         ),
//         pw.Text(
//           formatDate(item.createdAt.toString()) ?? '',
//           style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold), // Bold style applied
//         ),
//         pw.Text(
//           item.transactionId ?? '',
//           style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold), // Bold style applied
//         ),
//         pw.Text(
//           item.paymentType ?? '',
//           style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold), // Bold style applied
//         ),
//         pw.Text(
//           "${item.cctype} ${item.ccNumber}" ?? '',
//           style: pw.TextStyle(
//               fontSize: 10,
//               fontWeight: pw.FontWeight.bold), // Bold style applied
//         ),
//         pw.Align(
//           alignment:
//               pw.Alignment.centerRight, // Aligns the total amount to the right
//           child: pw.Text(
//             "\$${item.totalAmount.toString()}" ?? '',
//             style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
//           ),
//         ),
//       ]);
// // Subrow with concatenated data in a single row
//       String subrowDescriptions = '';
//       String subrowAmounts = '';
//
//       for (var tenant in item.entries!) {
//         subrowDescriptions +=
//             '${tenant.description ?? ''}\n'; // Concatenate descriptions
//         subrowAmounts +=
//             '\$${tenant.amount?.toString() ?? '0'}\n'; // Concatenate amounts
//       }
//
//       // Remove trailing commas and spaces
//       subrowDescriptions =
//           subrowDescriptions.trim().replaceAll(RegExp(r',$'), '');
//       subrowAmounts = subrowAmounts.trim().replaceAll(RegExp(r',$'), '');
//
//       tableData.add([
//         pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.end,
//           mainAxisAlignment: pw.MainAxisAlignment.end,
//           children: [
//             pw.Text(
//               subrowDescriptions,
//               style: pw.TextStyle(fontSize: 10),
//             ),
//           ],
//         ),
//         '',
//         '',
//         '',
//         '',
//         '',
//         pw.Align(
//           alignment:
//               pw.Alignment.centerRight, // Aligns the total amount to the right
//           child: pw.Text(
//             subrowAmounts,
//             textAlign: pw.TextAlign.right,
//             style: pw.TextStyle(fontSize: 10),
//           ),
//         ),
//       ]);
//       // Subrow with colspan (simulated by creating a container)
//       /*  for (var tenant in item.entries!) {
//       tableData.add([
//         pw.Column(
//           children: [
//             pw.Container(
//               //color: PdfColors.cyan,
//               width: 320, // Adjust width to span multiple columns
//               padding: pw.EdgeInsets.symmetric(vertical: 5,horizontal: 5),
//               child: pw.Text(tenant.description ?? '',
//                   style: pw.TextStyle(fontSize: 10)),
//             ),
//           ],
//         ),
//         '',
//         '',
//         '',
//         '',
//         '',
//         "\$${tenant.amount.toString()}" ?? '',
//       ]);
//     }*/
//     }
//     setState(() {
//       grandTotals = grandTotal;
//     });
//     return tableData;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: Text('Generate PDFs')),
//         body: Center(
//           child: ElevatedButton(
//             onPressed: () async {
//               List<Transaction> transactions = [
//                 Transaction(
//                   property: 'Address 1',
//                   tenantFirstName: 'John',
//                   tenantLastName: 'Doe',
//                   createdAt: DateTime.now(),
//                   transactionId: 'TX123456',
//                   paymentType: 'Card',
//                   ccNumber: '**** 1234',
//                   cctype: "",
//                   totalAmount: 1000,
//                   entries: [
//                     Entry(description: 'Rent Income', amount: 400),
//                     Entry(description: 'Security Deposit', amount: 500),
//                     Entry(description: 'Pre-payments', amount: 100),
//                   ],
//                 ),
//                 Transaction(
//                   property: 'Address 2',
//                   tenantFirstName: 'Jane',
//                   tenantLastName: 'Smith',
//                   createdAt: DateTime.now(),
//                   transactionId: 'TX654321',
//                   paymentType: 'Cash',
//                   ccNumber: '**** 4321',
//                   totalAmount: 500,
//                   cctype: "",
//                   entries: [
//                     Entry(description: 'Rent Income', amount: 250),
//                     Entry(description: 'Security Deposit', amount: 250),
//                   ],
//                 ),
//                 // Add more transactions as needed
//               ];
//
//               final transaction = await fetchTransactions('2024-09-04');
//
//               generateWorkOrderPdf(transaction);
//             },
//             child: Text('Generate PDF'),
//           ),
//         ),
//       ),
//     );
//   }
// }
class DailyTransactions extends StatefulWidget {
  const DailyTransactions({super.key});

  @override
  State<DailyTransactions> createState() => _DailyTransactionsState();
}

class _DailyTransactionsState extends State<DailyTransactions>
    with NetworkRetryState {
  late Future<DailyTransactionReportData> _futureDailytrnsaction;
  DailyTransactionReportData? DelinquentTenantsModel;
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
    setState(() {
      daterange = "Today";
      // Use DateProvider to format dates for display
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String todayApiFormat = DateFormat('yyyy-MM-dd').format(DateTime.now());
        fromDate.text = dateProvider.formatCurrentDate(todayApiFormat);
        toDate.text = dateProvider.formatCurrentDate(todayApiFormat);
      });
    });
    DateTime time = DateTime.now();
    String todayApiFormat = DateFormat('yyyy-MM-dd').format(time);
    _futureDailytrnsaction =
        fetchDelinquentTenantsData(todayApiFormat, todayApiFormat);
    // If data is available, show the table automatically
    setState(() {
      showTableData = true;
    });
  }

  Future<DailyTransactionReportData> fetchDelinquentTenantsData(
      String fromDate, String toDate,
      {String? charge}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");

      String? chargedata = chargeType == "All" ? null : chargeType;

      DailyTransactionReportData data = await DailyTrasactionReport()
          .fetchDailyTransactions(id!, fromDate, toDate,
              chargetype: chargedata);

      setState(() {
        DelinquentTenantsModel = data;
        isLoading = false;
        errorMessage = null; // Reset error message on successful data fetch
      });
      return data;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Failed to load renters insurance data. Please try again later.';
      });
      return DelinquentTenantsModel!;
    }
  }

  double grandtotal = 0.0;
  List<DailyTransactionReport> _tableData = [];
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
  bool customdate = false;
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
      Comparable<T> Function(DailyTransactionReport d)? getField) {
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

  void _sort<T>(Comparable<T> Function(DailyTransactionReport d) getField,
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
        // decoration: BoxDecoration(
        //   color: blueColor,
        //   borderRadius: const BorderRadius.only(
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
                            ? Text("   Date",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))
                            : Text("   Date",
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                        // Text("Property", style: TextStyle(color: Colors.white)),
                        // const SizedBox(width: 3),
                        // ascending1
                        //     ? const Padding(
                        //         padding: EdgeInsets.only(top: 7, left: 2),
                        //         child: FaIcon(
                        //           FontAwesomeIcons.sortUp,
                        //           size: 20,
                        //           color: Colors.white,
                        //         ),
                        //       )
                        //     : const Padding(
                        //         padding: EdgeInsets.only(bottom: 7, left: 2),
                        //         child: FaIcon(
                        //           FontAwesomeIcons.sortDown,
                        //           size: 20,
                        //           color: Colors.white,
                        //         ),
                        //       ),
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
                      Text("   Subtotal",
                          style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
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
                      Text("     Record",
                          style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
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

  bool istenantDataLoading = false;
  bool isAddLoading = false;
//  bool customdate = false;
  Future<void> generateDelinquentTenantsPdf(
      List<DailyTransactionReport> delinquentTenantsData) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      // Handle error
      logError("Error fetching profile data: $e");
      // Continue and still generate the PDF (header falls back to N/A)
    }
    setState(() {
      istenantDataLoading = true;
    });

    setState(() {
      istenantDataLoading = false;
    });
    try {
    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        // Year-to-date (and other large ranges) exceed the default 20-page
        // limit and throw TooManyPagesException — PDF never opens.
        maxPages: 1000,
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
                    'Daily Transaction Report',
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
                  0: pw.FlexColumnWidth(2), // Date
                  1: pw.FlexColumnWidth(1.5), // Address
                  2: pw.FlexColumnWidth(1), // Work
                  3: pw.FlexColumnWidth(.8), // Performed
                  4: pw.FlexColumnWidth(1.3), // Performed
                  5: pw.FlexColumnWidth(1.5), // Performed
                  6: pw.FlexColumnWidth(.8), // Performed
                  7: pw.FlexColumnWidth(1.5), // Performed
                  8: pw.FlexColumnWidth(1), // Performed
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

    // iOS: share sheet (layoutPdf often won't present on iOS); Android: layout/print.
    // Matches the working Rent Roll PDF pattern.
    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Daily_transaction_report.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'Daily_transaction_report',
        format: PdfPageFormat.a4.landscape,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
    } catch (e, st) {
      logError('PDF export error: $e\n$st');
      Fluttertoast.showToast(msg: 'Could not generate PDF: ${friendlyErrorMessage(e)}');
      if (mounted) setState(() => istenantDataLoading = false);
    }
  }

  List<List<dynamic>> _generateTableData(
      List<DailyTransactionReport> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];
    double total = 0.0;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    for (var owner in rentalOwnerReports) {
      // Main row for the rental owner name
      tableData.add([
        pw.Text(dateProvider.formatCurrentDate(owner.date ?? ''),
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

      for (var property in owner.charges!) {
        tableData.add([
          pw.Padding(
              child: pw.Text(
                '${property.rentalData?.rentalAddress ?? 'N/A'}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              padding: pw.EdgeInsets.only(left: 15)), // Property Name
          pw.Text(
            '${property.tenantData?.tenantFirstName ?? 'N/A'} ${property.tenantData?.tenantLastName ?? 'N/A'}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Property Name
          // Tenant Name
          pw.Text(
            dateProvider.formatCurrentDate(owner.date ?? ''),
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
            property.transactionId ?? 'N/A',
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
            property.cc_type ?? 'N/A',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ), // Card Type
          pw.Text(
            property.cc_number ?? 'N/A',
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
        if (property.response != "FAILURE" && !property.isDelete!)
          for (var payment in property.entry!) {
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
                      style: pw.TextStyle(
                        fontSize: 10,
                      ),
                      textAlign: pw.TextAlign.right // Align text to the right
                      ))
            ]);
          }
        // if (property.response == "FAILURE")
        //   tableData.add([
        //     pw.Padding(
        //         child: pw.Text(
        //             'Failed (reason:${property.responseText ?? 'N/A'})',
        //             style: pw.TextStyle(fontSize: 10)),
        //         padding: pw.EdgeInsets.only(left: 15)), // Account Name
        //     '', // Account Amount
        //     '', '', '', '', '', '',
        //     ''
        //   ]);

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
        '', // Label for rental owner subtotal
        '',
        '',
        '',
        '',
        '',
        '',
        pw.Padding(
            child: pw.Text('Subtotal :-',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            padding: pw.EdgeInsets.only(left: 15)),
        pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(formatCurrency(owner.subtotal),
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                textAlign: pw.TextAlign.right // Align text to the right
                ))
      ]);

      total += owner.subtotal!;
    }

    setState(() {
      grandtotal = total;
    });

    return tableData;
  }

  Future<void> generateRentalOwnerReportExcel(
      List<DailyTransactionReport> rentalOwnerReports) async {
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
    AmountTitleStyle.bold = true;
    AmountTitleStyle.numberFormat = '\$#,##0.00';

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    int rowIndex = 2;
    double grandTotal = 0.0;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    for (var owner in rentalOwnerReports) {
      final rentalOwnerCell = sheet.getRangeByIndex(rowIndex, 1);
      rentalOwnerCell.setText(dateProvider.formatCurrentDate(owner.date ?? ''));
      rentalOwnerCell.cellStyle.bold = true;
      sheet.getRangeByName('A$rowIndex:I$rowIndex').merge();
      rowIndex++;

      for (var property in owner.charges!) {
        sheet
            .getRangeByIndex(rowIndex, 1)
            .setText(property.rentalData?.rentalAddress ?? 'N/A');
        sheet.getRangeByIndex(rowIndex, 2).setText(
            '${property.tenantData?.tenantFirstName ?? 'N/A'} ${property.tenantData?.tenantLastName ?? 'N/A'}');
        sheet
            .getRangeByIndex(rowIndex, 3)
            .setText(dateProvider.formatCurrentDate(owner.date ?? ''));
        sheet
            .getRangeByIndex(rowIndex, 4)
            .setText(property.paymentType ?? 'N/A');
        sheet
            .getRangeByIndex(rowIndex, 5)
            .setText(property.transactionId ?? 'N/A');
        sheet.getRangeByIndex(rowIndex, 6).setText(property.paymentId ?? 'N/A');
        sheet.getRangeByIndex(rowIndex, 7).setText(property.cc_type ?? 'N/A');
        sheet.getRangeByIndex(rowIndex, 8).setText(property.cc_number ?? 'N/A');
        sheet
            .getRangeByIndex(rowIndex, 9)
            .setNumber(property.totalAmount ?? 0.0);
        sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
        rowIndex++;

        if (property.response != "FAILURE" && property.isDelete != true)
          for (var payment in property.entry!) {
            sheet
                .getRangeByIndex(rowIndex, 1)
                .setText(payment.account ?? 'N/A');
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

      sheet.getRangeByIndex(rowIndex, 1).setText('Subtotal - ${owner.date}');
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(rowIndex, 9).setNumber(owner.subtotal ?? 0.0);
      sheet.getRangeByIndex(rowIndex, 9).cellStyle = boldAmountStyle;
      sheet.getRangeByName('A$rowIndex:H$rowIndex').merge();
      rowIndex++;

      grandTotal += owner.subtotal ?? 0.0;
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
    final String fileName = 'Daily_transaction_report_$formattedDate.xlsx';

    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    // Create directory if it doesn't exist (for Android)
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    Share.shareXFiles([XFile(path)]);
  }

  Future<void> generateRentalOwnerReportCsv(
      List<DailyTransactionReport> rentalOwnerReports) async {
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
    csvBuffer.writeln(csvRow(headers));

    double grandTotal = 0.0;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    // Iterate through each rental owner report
    for (var owner in rentalOwnerReports) {
      // Add rental owner name as a row
      csvBuffer.writeln('${dateProvider.formatCurrentDate(owner.date ?? '')}');

      // Iterate through each property for the current rental owner
      for (var property in owner.charges!) {
        // Replace commas in the rental address with spaces
        final String sanitizedAddress =
            (property.rentalData?.rentalAddress ?? 'N/A');

        // Add property and tenant details
        csvBuffer.writeln(csvRow([
          sanitizedAddress,
          '${property.tenantData?.tenantFirstName ?? 'N/A'} ${property.tenantData?.tenantLastName ?? 'N/A'}',
          dateProvider.formatCurrentDate(owner.date ?? ''),
          property.paymentType ?? 'N/A',
          property.transactionId ?? 'N/A',
          property.paymentId ?? 'N/A',
          property.cc_type ?? 'N/A',
          property.cc_number ?? 'N/A',
          formatCurrency(property.totalAmount)
        ]));

        // Iterate through payment entries for the current property
        for (var payment in property.entry!) {
          csvBuffer.writeln(csvRow([
            payment.account ?? 'N/A',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            formatCurrency(payment.amount)
          ]));
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
      csvBuffer.writeln(csvRow([
        'Subtotal - ${owner.date}',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        formatCurrency(owner.subtotal)
      ]));

      // Accumulate grand total
      grandTotal += owner.subtotal ?? 0.0;
    }

    // Add grand total row at the end
    csvBuffer.writeln(csvRow([
      'Grand Total',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      formatCurrency(grandTotal)
    ]));

    // Convert buffer to list of bytes for CSV file
    final List<int> bytes = utf8.encode(csvBuffer.toString());

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Daily_transaction_report_$formattedDate.csv';

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
  }

  // Future<void> generateDelinquentTenantsCsv(
  //     List<DelinquentTenantsData> delinquentTenantsData) async {
  //   setState(() {
  //     istenantDataLoading = true;
  //   });
  //
  //   final globalDelinquentTenantsData =
  //   await fetchDelinquentTenantsGrandTotal();
  //
  //   setState(() {
  //     istenantDataLoading = false;
  //   });
  //   List<List<dynamic>> rows = [
  //     [
  //       'Unit',
  //       'Tenant',
  //       'Total',
  //       '0-30 days',
  //       '31-60 days',
  //       '61-90 days',
  //       '91+ days'
  //     ]
  //   ];
  //
  //   for (var item in delinquentTenantsData) {
  //     // Add main row with rental address
  //     rows.add([item.rentalAddress ?? '', '', '', '', '', '', '']);
  //
  //     // Add tenant details in subsequent rows
  //     for (var tenant in item.tenants!) {
  //       rows.add([
  //         tenant.unitDetails ?? '',
  //         tenant.tenantName ?? '',
  //         tenant.pdfDelinquentTenantsData?.totalDaysAmount ?? '',
  //         tenant.pdfDelinquentTenantsData?.last30Days ?? '',
  //         tenant.pdfDelinquentTenantsData?.last31To60Days ?? '',
  //         tenant.pdfDelinquentTenantsData?.last61To90Days ?? '',
  //         tenant.pdfDelinquentTenantsData?.last91PlusDays ?? ''
  //       ]);
  //     }
  //
  //     // Add total row for each property
  //     rows.add([
  //       'Total',
  //       '',
  //       item.alltotalamount?.totalDaysAmount ?? '',
  //       item.alltotalamount?.last30Days ?? '',
  //       item.alltotalamount?.last31To60Days ?? '',
  //       item.alltotalamount?.last61To90Days ?? '',
  //       item.alltotalamount?.last91PlusDays ?? ''
  //     ]);
  //   }
  //
  //   // Add grand total row
  //   if (globalDelinquentTenantsData != null) {
  //     rows.add([
  //       'Grand Total of all Properties',
  //       '',
  //       globalDelinquentTenantsData!.totalDaysAmount ?? '',
  //       globalDelinquentTenantsData!.last30Days ?? '',
  //       globalDelinquentTenantsData!.last31To60Days ?? '',
  //       globalDelinquentTenantsData!.last61To90Days ?? '',
  //       globalDelinquentTenantsData!.last91PlusDays ?? ''
  //     ]);
  //   }
  //
  //   String csv = const ListToCsvConverter().convert(rows);
  //
  //   // Define file name with current date and time
  //   final DateTime now = DateTime.now();
  //   final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
  //   final String fileName = 'DelinquentTenantsReport_$formattedDate.csv';
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
  //   // Write file to the path
  //   final File file = File(path);
  //   await file.writeAsString(csv);
  //   Share.shareXFiles([XFile(path)]);
  //   // Show success toast message
  //   Fluttertoast.showToast(
  //     msg: 'CSV file exported successfully',
  //   );
  // }

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
      });

      // Notify the FormField state of the change
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
  bool showTableData = false;

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      drawer: CustomDrawer(
        currentpage: "Report",
        dropdown: false,
      ),
      body: !isOffline
          ? Column(
              children: [
                ReportHeader(title: "Daily Transaction Report"),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // if (MediaQuery.of(context).size.width > 500)
                        //   const SizedBox(height: 16),
                        // if (MediaQuery.of(context).size.width < 500)
                        FutureBuilder<DailyTransactionReportData>(
                          future: _futureDailytrnsaction,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
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
                            } else if (!snapshot.hasData ||
                                snapshot.data!.data.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0),
                                child: Column(
                                  children: [
                                    filters(),
                                    Container(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              .5,
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

                            var data = snapshot.data!.data;

                            // Pagination logic
                            final totalPages =
                                (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
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
                                    Padding(
                                      padding: EdgeInsets.only(
                                          left: MediaQuery.of(context)
                                                      .size
                                                      .width >
                                                  500
                                              ? 12
                                              : 0,
                                          right: MediaQuery.of(context)
                                                      .size
                                                      .width >
                                                  500
                                              ? 12
                                              : 0),
                                      child: Row(
                                        children: [
                                          Text(
                                            "Grand total ",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: blueColor),
                                          ),
                                          Spacer(),
                                          Text(
                                            formatCurrency(
                                                snapshot.data?.grandTotal),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: blueColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    _buildHeaders(),
                                    const SizedBox(height: 20),
                                    if (showTableData)
                                      Padding(
                                        padding: EdgeInsets.only(
                                            left: MediaQuery.of(context)
                                                        .size
                                                        .width >
                                                    500
                                                ? 12
                                                : 0,
                                            right: MediaQuery.of(context)
                                                        .size
                                                        .width >
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
                                              DailyTransactionReport rental =
                                                  entry.value;

                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: rowIndex % 2 != 0
                                                      ? const Color(0xFFF4F8FF)
                                                      : Colors.white,
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFDBE0E5)),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Column(
                                                  children: <Widget>[
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
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left: 5,
                                                                        right:
                                                                            5),
                                                                padding: !isRowExpanded
                                                                    ? const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            10)
                                                                    : const EdgeInsets
                                                                        .only(
                                                                        top:
                                                                            10),
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
                                                              flex: 3,
                                                              child:
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
                                                                child: Text(
                                                                  dateProvider
                                                                      .formatCurrentDate(
                                                                          '${rental.date ?? '-'}'),
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
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width: 2,
                                                            ),
                                                            Expanded(
                                                              flex: 2,
                                                              child: Text(
                                                                formatCurrency(
                                                                    item.subtotal),
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
                                                            ),
                                                            SizedBox(
                                                                width: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    .07),
                                                            Expanded(
                                                              flex: 2,
                                                              child: Text(
                                                                ' Record : ${rental.charges?.length ?? '-'} ',
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
                                                            ),
                                                            SizedBox(
                                                              width: 10,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if (isRowExpanded)
                                                      Column(
                                                        children: [
                                                          Column(
                                                            children: item
                                                                .charges!
                                                                .asMap()
                                                                .entries
                                                                .map(
                                                                    (tenantEntry) {
                                                              int tenantIndex =
                                                                  tenantEntry
                                                                      .key;
                                                              var tenant =
                                                                  tenantEntry
                                                                      .value;
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
                                                                        onTap:
                                                                            () {
                                                                          setState(
                                                                              () {
                                                                            if (expandedTenantIndex[rowIndex] ==
                                                                                tenantIndex) {
                                                                              expandedTenantIndex[rowIndex] = null;
                                                                            } else {
                                                                              expandedTenantIndex[rowIndex] = tenantIndex;
                                                                            }
                                                                          });
                                                                        },
                                                                        child:
                                                                            Container(
                                                                          margin: const EdgeInsets
                                                                              .only(
                                                                              left: 5,
                                                                              right: 5),
                                                                          padding: !isTenantExpanded
                                                                              ? const EdgeInsets.only(bottom: 10)
                                                                              : const EdgeInsets.only(top: 10),
                                                                          child:
                                                                              Padding(
                                                                            padding:
                                                                                const EdgeInsets.only(left: 10),
                                                                            child:
                                                                                FaIcon(
                                                                              isTenantExpanded ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                              size: 20,
                                                                              color: isTenantExpanded ? blueColor : blueColor,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Expanded(
                                                                          child:
                                                                              GestureDetector(
                                                                        onTap:
                                                                            () {
                                                                          setState(
                                                                              () {
                                                                            if (expandedTenantIndex[rowIndex] ==
                                                                                tenantIndex) {
                                                                              expandedTenantIndex[rowIndex] = null;
                                                                            } else {
                                                                              expandedTenantIndex[rowIndex] = tenantIndex;
                                                                            }
                                                                          });
                                                                        },
                                                                        child:
                                                                            Text(
                                                                          "${tenant.rentalData!.rentalAddress}",
                                                                          style: TextStyle(
                                                                              fontWeight: FontWeight.bold,
                                                                              color: blueColor),
                                                                        ),
                                                                      )),
                                                                      Expanded(
                                                                          child:
                                                                              Text(
                                                                        '${tenant.tenantData?.tenantFirstName} ${tenant.tenantData?.tenantLastName}',
                                                                        // "${formatDate(tenant.createdAt.toString())}",
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor),
                                                                      ))
                                                                    ],
                                                                  ),
                                                                  if (isTenantExpanded)
                                                                    Column(
                                                                      children: [
                                                                        Row(
                                                                          children: [
                                                                            SizedBox(
                                                                              width: 20,
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
                                                                                  _buildTableRow('Type:', _getDisplayValue(tenant.paymentType), 'Txn Date:', _getDisplayValue(tenant.entry != null && tenant.entry!.isNotEmpty ? dateProvider.formatCurrentDate('${tenant.entry!.first.date}') : 'N/A')),
                                                                                  _buildTableRow(
                                                                                    'Payment Details:',
                                                                                    _getDisplayValue((tenant.cc_type != null && tenant.cc_number != null && tenant.cc_type!.isNotEmpty && tenant.cc_number!.isNotEmpty) ? "${tenant.cc_type} ${tenant.cc_number}" : "N/A"),
                                                                                    'Total:',
                                                                                    _getDisplayValue(formatCurrency(tenant.totalAmount)),
                                                                                  )
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        if (tenant
                                                                            .entry!
                                                                            .isNotEmpty)
                                                                          Row(
                                                                            children: [
                                                                              const SizedBox(
                                                                                width: 27,
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
                                                                        if (tenant.entry!.isNotEmpty &&
                                                                            tenant.response !=
                                                                                "FAILURE")
                                                                          const SizedBox(
                                                                            height:
                                                                                4,
                                                                          ),
                                                                        if (tenant.entry!.isNotEmpty &&
                                                                            tenant.response !=
                                                                                "FAILURE" &&
                                                                            tenant.isDelete !=
                                                                                true)
                                                                          Padding(
                                                                            padding:
                                                                                const EdgeInsets.only(left: 15, top: 0),
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
                                                                        if (tenant.entry!.isNotEmpty &&
                                                                            tenant.response !=
                                                                                "FAILURE" &&
                                                                            tenant.isDelete !=
                                                                                true)
                                                                          Column(
                                                                            children:
                                                                                tenant.entry!.map((entry) {
                                                                              return Padding(
                                                                                padding: const EdgeInsets.only(left: 15.0, bottom: 0),
                                                                                child: Row(
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
                                                                        if (tenant.response ==
                                                                            "FAILURE")
                                                                          Text.rich(
                                                                            TextSpan(
                                                                              children: [
                                                                                TextSpan(
                                                                                  text: 'Failed : Reason(${tenant.reason}) ',
                                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                        if (tenant
                                                                            .isDelete!)
                                                                          Padding(
                                                                            padding:
                                                                                const EdgeInsets.only(left: 30.0),
                                                                            child:
                                                                                Align(
                                                                              alignment: Alignment.centerLeft,
                                                                              child: Text.rich(
                                                                                TextSpan(
                                                                                  children: [
                                                                                    TextSpan(
                                                                                      text: 'Void (Reason :- ${tenant.reason})',
                                                                                      style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  SizedBox(
                                                                    height: 8,
                                                                  ),
                                                                  if (item.charges!
                                                                              .length -
                                                                          1 !=
                                                                      tenantIndex)
                                                                    Divider(
                                                                      thickness:
                                                                          2,
                                                                    )
                                                                ],
                                                              );
                                                            }).toList(),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12.0),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                ),
                                                child:
                                                    DropdownButtonHideUnderline(
                                                  child: DropdownButton<int>(
                                                    value: itemsPerPage,
                                                    items: itemsPerPageOptions
                                                        .map((int value) {
                                                      return DropdownMenuItem<
                                                          int>(
                                                        value: value,
                                                        child: Text(
                                                            value.toString()),
                                                      );
                                                    }).toList(),
                                                    onChanged: (newValue) {
                                                      setState(() {
                                                        itemsPerPage =
                                                            newValue!;
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
                                                FontAwesomeIcons
                                                    .circleChevronLeft,
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
                                              'Page ${currentPage + 1} of $totalPages',
                                              style:
                                                  const TextStyle(fontSize: 18),
                                            ),
                                            IconButton(
                                              icon: FaIcon(
                                                FontAwesomeIcons
                                                    .circleChevronRight,
                                                color:
                                                    currentPage < totalPages - 1
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
                future: _futureDailytrnsaction,
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
                  ),
                ),
              ],
            )
          : Column(
              children: [
                ReportHeader(title: "Daily Transaction Report"),
                Expanded(
                  child: NoInternetView(onRetry: retryNow),
                ),
              ],
            ),
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

  // List<TableRow> _buildExpandableRows(
  //     int rowIndex, DailyTransactionReport item) {
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
  //         _buildDataCell(item.rentalData?.rentalAddress ?? '-'),
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
  //               '${tenantEntry.value.pdfDelinquentTenantsData!.last30Days ?? '-'}'),
  //           _buildDataCell(
  //               ' ${tenantEntry.value.pdfDelinquentTenantsData!.last30Days ?? '-'}\n'),
  //           _buildDataCell(
  //               ' ${tenantEntry.value.pdfDelinquentTenantsData!.last30Days ?? '-'}\n'),
  //         ],
  //       ),
  //   ];
  // }

  filters({List<DailyTransactionReport>? data}) {
    return Padding(
      padding: EdgeInsets.only(
          left: MediaQuery.of(context).size.width > 500 ? 12 : 0,
          right: MediaQuery.of(context).size.width > 500 ? 12 : 0),
      child: Column(
        children: [
          SizedBox(
            height: 10,
          ),
          // Charge dropdown and Date Range dropdown side by side
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Colors.grey)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: chargeType,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        hint: const Text(
                          "Charge type",
                          style: TextStyle(fontSize: 14, color: Colors.black),
                        ),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'All',
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
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                            // Auto-fetch data only for "Today" selection
                            if (value == "Today") {
                              _futureDailytrnsaction =
                                  fetchDelinquentTenantsData(
                                      formatDate(fromDate.text),
                                      formatDate(toDate.text));
                            }
                            // For other date ranges, user must click "Run" button
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
              ],
            ),
          ),
          const SizedBox(height: 10),
          // From Date and To Date fields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    child: TextFormField(
                      controller: fromDate,
                      onTap: customdate
                          ? () {
                              _pickDate(context);
                            }
                          : null,
                      readOnly: true,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                      textInputAction: TextInputAction.next,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 10),
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
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    child: TextFormField(
                      controller: toDate,
                      style: const TextStyle(fontSize: 14, color: Colors.black),
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
                            vertical: 10, horizontal: 10),
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
              ],
            ),
          ),
          if (_dateRangeError != null)
            ReportDateRangeErrorText(_dateRangeError!),
          const SizedBox(height: 10),
          // Export and Run Report buttons side by side
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              children: [
                if (showTableData)
                  Expanded(
                    // No rows yet: Export stays in place, greyed and disabled.
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          disabledBackgroundColor: Colors.grey.shade400,
                          disabledForegroundColor: Colors.white,
                        ),
                        onPressed: (data?.isNotEmpty ?? false) ? () {} : null,
                        child: PopupMenuButton<String>(
                          enabled: data?.isNotEmpty ?? false,
                          onSelected: (value) async {
                            // Export logic
                            if (value == 'PDF' && data != null) {
                              generateDelinquentTenantsPdf(data);
                            } else if (value == 'XLSX' && data != null) {
                              generateRentalOwnerReportExcel(data);
                            } else if (value == 'CSV' && data != null) {
                              generateRentalOwnerReportCsv(data);
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Export'),
                              Icon(Icons.arrow_drop_down),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showTableData) const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        disabledBackgroundColor: blueColor.withOpacity(0.6),
                        disabledForegroundColor: Colors.white,
                      ),
                      onPressed: _dateRangeError != null ? null : () async {
                        setState(() {
                          showTableData =
                              true; // Set to true when the button is pressed
                        });
                        _futureDailytrnsaction = fetchDelinquentTenantsData(
                            formatDate(fromDate.text), formatDate(toDate.text),
                            charge: chargeType);
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Run Report'),
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
