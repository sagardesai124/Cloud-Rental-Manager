import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../../../Model/Scheduled_Payment_model.dart';
import '../../../../Model/profile.dart';
import '../../../../constant/constant.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../repository/GetAdminAddressPdf.dart';
import '../../../../repository/Scheduled_Payment_repo.dart';
import '../../../../widgets/CustomTableShimmer.dart';
import '../../../../widgets/titleBar.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import '../RentalRoll/SummeryPageLease.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

// ignore: camel_case_types
class Scheduled_Payments_table extends StatefulWidget {
  const Scheduled_Payments_table({super.key});

  @override
  State<Scheduled_Payments_table> createState() =>
      _Scheduled_Payments_tableState();
}

class _Scheduled_Payments_tableState extends State<Scheduled_Payments_table>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<List<Scheduled_Payment>> futurescheduledpayment;
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
  ]; // Options for items per page

  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;

  void sortData(List<Scheduled_Payment> data) {
    // Apply user-selected sorting only if explicitly chosen
    if (sorting1 && !sorting2 && !sorting3) {
      data.sort((a, b) {
        final dateA = a.date ?? '';
        final dateB = b.date ?? '';
        if (dateA.isEmpty && dateB.isEmpty) return 0;
        if (dateA.isEmpty) return 1;
        if (dateB.isEmpty) return -1;
        return ascending1 ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      });
    } else if (sorting2 && !sorting1 && !sorting3) {
      data.sort((a, b) => ascending2
          ? (a.tenant?.tenantName ?? '').compareTo(b.tenant?.tenantName ?? '')
          : (b.tenant?.tenantName ?? '').compareTo(a.tenant?.tenantName ?? ''));
    } else if (sorting3 && !sorting1 && !sorting2) {
      data.sort((a, b) => ascending3
          ? (a.totalAmount ?? 0).compareTo(b.totalAmount ?? 0)
          : (b.totalAmount ?? 0).compareTo(a.totalAmount ?? 0));
    }
  }

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
              flex: 3,
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
                    Text("Date",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 3),
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
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
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
              flex: 4,
              child: Text("Property",
                  style:
                      TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> items = ['Residential', "Commercial", "All"];
  String? selectedValue;
  String searchvalue = "";
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futurescheduledpayment = Scheduled_Payment_repo().fetchScheduled_Payment();;
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
    futurescheduledpayment = Scheduled_Payment_repo().fetchScheduled_Payment();
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

  void _showAlert(BuildContext context, String id, Scheduled_Payment payment) {
    TextEditingController reason = TextEditingController();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same record.
    bool deleting = false;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF8A95A8)),
                ),
              ),
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE0A33E), width: 3),
                ),
                child: const Icon(Icons.priority_high,
                    color: Color(0xFFE0A33E), size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                "Are you sure?",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: blueColor),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: grey, height: 1.4),
                  children: [
                    const TextSpan(
                        text:
                            "You want to delete this scheduled payment for "),
                    TextSpan(
                        text: payment.tenant?.tenantName ?? 'N/A',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: blueColor)),
                    TextSpan(
                        text: " at ${payment.rentalAddress ?? ''} in the "
                            "amount of "),
                    TextSpan(
                        text: formatCurrency(payment.totalAmount),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: blueColor)),
                    TextSpan(
                        text: " on "
                            "${payment.date?.isNotEmpty == true ? dateProvider.formatCurrentDate('${payment.date}') : 'N/A'}?"),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  hintText: 'Enter reason for deletion',
                  hintStyle: const TextStyle(color: Color(0xFF8A95A8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: blueColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (deleting) return;
                        deleting = true;
                        // The repository toasts the server's own reason and
                        // then throws when the delete is rejected. Nothing
                        // caught it, so Navigator.pop was never reached — the
                        // dialog stayed open with no explanation and the
                        // exception escaped into the framework. Close the
                        // dialog either way; the message has already been
                        // shown.
                        try {
                          var data = await Scheduled_Payment_repo()
                              .DeleteScheduled_Payment(
                                  pro_id: id, reason: reason.text);
                          if (!mounted) return;
                          // Only refresh when the delete actually succeeded.
                          if (data != null)
                            setState(() {
                              futurescheduledpayment =
                                  Scheduled_Payment_repo()
                                      .fetchScheduled_Payment();
                            });
                          Navigator.pop(context);
                        } catch (_) {
                          deleting = false;
                          if (!mounted) return;
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: blueColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: blueColor, width: 1.5),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                              color: blueColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPDF(List<Scheduled_Payment> data) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );
    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      return;
    }
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final pdf = pw.Document();
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 50, height: 50),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Scheduled Payments',
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
                      if (profileData?.companyName != null &&
                          profileData!.companyName!.isNotEmpty)
                        pw.Text(
                          profileData!.companyName!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (profileData?.companyAddress != null &&
                          profileData!.companyAddress!.isNotEmpty)
                        pw.Text(
                          profileData!.companyAddress!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if ((profileData?.companyCity != null &&
                              profileData!.companyCity!.isNotEmpty) ||
                          (profileData?.companyState != null &&
                              profileData!.companyState!.isNotEmpty) ||
                          (profileData?.companyCountry != null &&
                              profileData!.companyCountry!.isNotEmpty))
                        pw.Text(
                          [
                            if (profileData?.companyCity != null &&
                                profileData!.companyCity!.isNotEmpty)
                              profileData!.companyCity!,
                            if (profileData?.companyState != null &&
                                profileData!.companyState!.isNotEmpty)
                              profileData!.companyState!,
                            if (profileData?.companyCountry != null &&
                                profileData!.companyCountry!.isNotEmpty)
                              profileData!.companyCountry!,
                          ].join(', '),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (profileData?.companyPostalCode != null &&
                          profileData!.companyPostalCode!.isNotEmpty)
                        pw.Text(
                          profileData!.companyPostalCode!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: null,
              columnWidths: {
                0: const pw.FlexColumnWidth(2), // Date
                1: const pw.FlexColumnWidth(3), // Property
                2: const pw.FlexColumnWidth(3), // Tenant
                3: const pw.FlexColumnWidth(2), // Account
                4: const pw.FlexColumnWidth(2), // Amount
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex("#5A86D5"),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Align(
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                                color: PdfColors.white)),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Property',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Tenant',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Align(
                        child: pw.Text('Account',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                                color: PdfColors.white)),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Amount',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                                color: PdfColors.white)),
                      ),
                    ),
                  ],
                ),
                ...data.map((charge) => pw.TableRow(
                      decoration: const pw.BoxDecoration(),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            child: pw.Text(charge.date != null
                                ? dateProvider.formatCurrentDate(charge.date!)
                                : ''),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(charge.rentalAddress ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(charge.tenant?.tenantName ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            child: pw.Text(charge.account ?? ''),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: pw.Text(charge.totalAmount != null
                                ? formatCurrency(charge.totalAmount)
                                : formatCurrency(0.0)),
                          ),
                        ),
                      ],
                    )),
              ],
            ),
          ];
        },
      ),
    );
    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Scheduled_Payments_table.pdf');
    } else {
      await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
    }
  }

  Future<void> _exportExcel(List<Scheduled_Payment> data) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final workbook = syncXlsx.Workbook();
    final sheet = workbook.worksheets[0];
    final headers = ['Date', 'Property', 'Tenant', 'Account', 'Amount'];
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    for (int row = 0; row < data.length; row++) {
      final charge = data[row];
      sheet.getRangeByIndex(row + 2, 1).setText(charge.date != null
          ? dateProvider.formatCurrentDate(charge.date!)
          : '');
      sheet.getRangeByIndex(row + 2, 2).setText(charge.rentalAddress ?? '');
      sheet
          .getRangeByIndex(row + 2, 3)
          .setText(charge.tenant?.tenantName ?? '');
      sheet.getRangeByIndex(row + 2, 4).setText(charge.account ?? '');
      sheet.getRangeByIndex(row + 2, 5).setText(
          charge.totalAmount != null ? charge.totalAmount.toString() : '0.0');
    }
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'ScheduledPayments_$formattedDate.xlsx';
    final Directory directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _exportCSV(List<Scheduled_Payment> data) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('Date,Property,Tenant,Account,Amount');
    for (final charge in data) {
      csvBuffer.writeln([
        charge.date != null ? dateProvider.formatCurrentDate(charge.date!) : '',
        charge.rentalAddress ?? '',
        charge.tenant?.tenantName ?? '',
        charge.account ?? '',
        charge.totalAmount != null ? charge.totalAmount.toString() : ''
      ].map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','));
    }
    final List<int> bytes = utf8.encode(csvBuffer.toString());
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'ScheduledPayments_$formattedDate.csv';
    final Directory directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)]);
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Scheduled Payments",
        dropdown: true,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(
                    height: 20,
                  ),
                  // Header Section with Title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Padding(
                      padding: EdgeInsets.only(
                          left:
                              MediaQuery.of(context).size.width > 500 ? 12 : 0,
                          right:
                              MediaQuery.of(context).size.width > 500 ? 12 : 0),
                      child: titleBar(
                        width: double.infinity,
                        title: 'Scheduled Payments',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  //search
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width > 500 ? 28 : 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            elevation: 0,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              height: MediaQuery.of(context).size.width < 500
                                  ? 45
                                  : 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                // border: Border.all(color: Colors.grey),
                                border:
                                    Border.all(color: const Color(0xFF8A95A8))),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    color: Color(0xFF8A95A8), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 15
                                                : 14),
                                    onChanged: (value) {
                                      setState(() {
                                        searchvalue = value;
                                        if (currentPage != 0) currentPage = 0;
                                      });
                                    },
                                    cursorColor: blueColor,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isCollapsed: true,
                                      hintText: "Search here...",
                                      hintStyle: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF8A95A8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Export disabled/greyed when there is no data to
                        // export (QA CRM: no Export on empty list).
                        FutureBuilder<List<Scheduled_Payment>>(
                          future: futurescheduledpayment,
                          builder: (context, exportSnap) {
                            final bool hasExportData = exportSnap.connectionState != ConnectionState.done ||
                                (exportSnap.hasData && exportSnap.data!.isNotEmpty);
                            return SizedBox(
                              height: 45,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasExportData
                                      ? blueColor
                                      : Colors.grey.shade400,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                onPressed: !hasExportData
                                    ? null
                                    : () async {
                                        final data =
                                            await futurescheduledpayment;
                                        await _exportPDF(data);
                                      },
                                child: PopupMenuButton(
                                  enabled: hasExportData,
                                  onSelected: (value) async {
                                    final data = await futurescheduledpayment;
                                    if (value == 'Export PDF') {
                                      await _exportPDF(data);
                                    }
                                    if (value == 'Export Excel') {
                                      await _exportExcel(data);
                                    }
                                    if (value == 'Export CSV') {
                                      await _exportCSV(data);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'Export PDF',
                                      child: Text('Export PDF'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Export Excel',
                                      child: Text('Export Excel'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Export CSV',
                                      child: Text('Export CSV'),
                                    ),
                                  ],
                                  child: const Row(
                                    children: [
                                      Text('Export'),
                                      Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 25),
                  // if (MediaQuery.of(context).size.width < 500)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width < 500 ? 16 : 28,
                        vertical:
                            MediaQuery.of(context).size.width < 500 ? 11 : 28),
                    child: FutureBuilder<List<Scheduled_Payment>>(
                      future: futurescheduledpayment,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ColabShimmerLoadingWidget();
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
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
                        } else {
                          var data = snapshot.data!;
                          if (selectedValue == null && searchvalue.isEmpty) {
                            data = snapshot.data!;
                          } else if (selectedValue == "All") {
                            data = snapshot.data!;
                          } else if (searchvalue.isNotEmpty) {
                            data = snapshot.data!
                                .where((applicant) =>
                                    (applicant.rentalAddress ?? '')
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    (applicant.tenant?.tenantName ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    applicant.totalAmount
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()) ||
                                    applicant.date
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchvalue.toLowerCase()))
                                .toList();
                          } else {
                            data = snapshot.data!
                                .where((applicant) =>
                                    applicant.rentalAddress == selectedValue)
                                .toList();
                          }
                          if (data.isEmpty) {
                            return Center(
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
                            );
                          }
                          /* if (selectedValue == null && searchvalue!.isEmpty) {
                        data = snapshot.data!;
                      } else if (selectedValue == "All") {
                        data = snapshot.data!;
                      } else if (searchvalue!.isNotEmpty) {
                        data = snapshot.data!
                            .where((property) =>
                        (property.propertyType ?? '')
                            .toLowerCase()
                            .contains(searchvalue!.toLowerCase()) ||
                            (property.propertysubType ?? '')
                                .toLowerCase()
                                .contains(searchvalue!.toLowerCase()))
                            .toList();
                      } else {
                        data = snapshot.data!
                            .where((property) =>
                        property.propertyType == selectedValue)
                            .toList();
                      }*/
                          sortData(data);
                          final totalPages =
                              (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                          final currentPageData = data
                              .skip(currentPage * itemsPerPage)
                              .take(itemsPerPage)
                              .toList();
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 10),
                                _buildHeaders(),
                                const SizedBox(height: 10),
                                Container(
                                  // decoration: BoxDecoration(border: Border.all(color: Color.fromRGBO(152, 162, 179, .5))),
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
                                      Scheduled_Payment Propertytype =
                                          entry.value;

                                      //return CustomExpansionTile(data: Propertytype, index: index);
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
                                                        // setState(() {
                                                        //    isExpanded = !isExpanded;
                                                        // //  expandedIndex = !expandedIndex;
                                                        //
                                                        // });
                                                        // setState(() {
                                                        //   if (isExpanded) {
                                                        //     expandedIndex = null;
                                                        //     isExpanded = !isExpanded;
                                                        //   } else {
                                                        //     expandedIndex = index;
                                                        //   }
                                                        // });
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
                                                        margin: const EdgeInsets
                                                            .only(
                                                            left: 5, right: 5),
                                                        padding: !isExpanded
                                                            ? const EdgeInsets
                                                                .only(
                                                                bottom: 10)
                                                            : const EdgeInsets
                                                                .only(top: 10),
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
                                                      flex: 3,
                                                      child: InkWell(
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
                                                        child: Text(
                                                          Propertytype.date
                                                                      ?.isNotEmpty ==
                                                                  true
                                                              ? dateProvider
                                                                  .formatCurrentDate(
                                                                      '${Propertytype.date}')
                                                              : 'N/A',
                                                          style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .03),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        '${Propertytype.rentalAddress}',
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
                                                            .02),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isExpanded)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 2.0),
                                                margin: const EdgeInsets.only(
                                                    bottom: 2),
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // if (Propertytype
                                                      //     .isRenewing !=
                                                      //     false)

                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 18.0),
                                                        child: Text.rich(
                                                          TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    'Tenant : ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        blueColor),
                                                              ),
                                                              TextSpan(
                                                                text: Propertytype
                                                                        .tenant
                                                                        ?.tenantName ??
                                                                    'N/A',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color:
                                                                        grey),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 18.0),
                                                        child: Text.rich(
                                                          TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    'Amount : ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        blueColor),
                                                              ),
                                                              TextSpan(
                                                                text: formatCurrency(
                                                                    Propertytype
                                                                        .totalAmount),
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color:
                                                                        grey),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 15,
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          GestureDetector(
                                                            onTap: () async {
                                                              Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder: (context) =>
                                                                          SummeryPageLease(
                                                                            leaseId: Propertytype.leaseId!,
                                                                            enddate: Propertytype.date,
                                                                            isredirectpayment: true,
                                                                          )));
                                                            },
                                                            child: Container(
                                                              height: 35,
                                                              width: 35,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  color: const Color(
                                                                      0xFFEFF1F5)),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  FaIcon(
                                                                    FontAwesomeIcons
                                                                        .eye,
                                                                    size: 16,
                                                                    color:
                                                                        blueColor,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          GestureDetector(
                                                            onTap: () async {
                                                              _showAlert(
                                                                  context,
                                                                  Propertytype
                                                                      .sId!,
                                                                  Propertytype);
                                                            },
                                                            child: Container(
                                                              height: 35,
                                                              width: 35,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  color: Colors
                                                                      .red
                                                                      .shade50),
                                                              child: const Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  FaIcon(
                                                                    FontAwesomeIcons
                                                                        .trashCan,
                                                                    size: 15,
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            //SizedBox(height: 13,),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                if (totalPages > 1) const SizedBox(height: 20),
                                if (totalPages > 1)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        // Text('Rows per page:'),
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
                                                onChanged: data.length >
                                                        itemsPerPageOptions
                                                            .first // Condition to check if dropdown should be enabled
                                                    ? (newValue) {
                                                        setState(() {
                                                          itemsPerPage =
                                                              newValue!;
                                                          currentPage =
                                                              0; // Reset to first page when items per page change
                                                        });
                                                      }
                                                    : null,
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
                                        // IconButton(
                                        //   icon: Icon(Icons.arrow_back),
                                        //   onPressed: currentPage > 0
                                        //       ? () {
                                        //     setState(() {
                                        //       currentPage--;
                                        //     });
                                        //   }
                                        //       : null,
                                        // ),
                                        Text(
                                            'Page ${currentPage + 1} of $totalPages'),
                                        // IconButton(
                                        //   icon: Icon(Icons.arrow_forward),
                                        //   onPressed: currentPage < totalPages - 1
                                        //       ? () {
                                        //     setState(() {
                                        //       currentPage++;
                                        //     });
                                        //   }
                                        //       : null,
                                        // ),
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
                          );
                        }
                      },
                    ),
                  ),
                  /* if (MediaQuery.of(context).size.width > 500)
              FutureBuilder<List<propertytype>>(
                future: futurePropertyTypes,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ShimmerTabletTable();
                  } else if (snapshot.hasError) {
                    return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                  } else {
                    _tableData = snapshot.data!;
                    if (selectedValue == null && searchvalue.isEmpty) {
                      _tableData = snapshot.data!;
                    } else if (selectedValue == "All") {
                      _tableData = snapshot.data!;
                    } else if (searchvalue.isNotEmpty) {
                      _tableData = snapshot.data!
                          .where((property) =>
                      (property.propertyType ?? '')
                          .toLowerCase()
                          .contains(searchvalue.toLowerCase()) ||
                          (property.propertysubType ?? '')
                              .toLowerCase()
                              .contains(searchvalue.toLowerCase()))
                          .toList();
                    } else {
                      _tableData = snapshot.data!
                          .where((property) =>
                      property.propertyType == selectedValue)
                          .toList();
                    }
                    totalrecords = _tableData.length;
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 5),
                              child: Column(
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          .91,
                                      child: Table(
                                        defaultColumnWidth:
                                        IntrinsicColumnWidth(),
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                // color: blueColor
                                              ),
                                            ),
                                            children: [

                                              _buildHeader(
                                                  'Main Type',
                                                  0,
                                                      (property) =>
                                                  property.propertyType!),
                                              _buildHeader(
                                                  'Subtype',
                                                  1,
                                                      (property) => property
                                                      .propertysubType!),
                                              _buildHeader(
                                                  'Created At', 2, null),
                                              _buildHeader(
                                                  'Updated At', 3, null),
                                              _buildHeader('Actions', 4, null),
                                            ],
                                          ),
                                          TableRow(
                                            decoration: BoxDecoration(
                                              border: Border.symmetric(
                                                  horizontal: BorderSide.none),
                                            ),
                                            children: List.generate(
                                                5,
                                                    (index) => TableCell(
                                                    child:
                                                    Container(height: 20))),
                                          ),
                                          for (var i = 0;
                                          i < _pagedData.length;
                                          i++)
                                            TableRow(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                      color: blueColor


),
                                                  right: BorderSide(
                                                      color: blueColor


),
                                                  top: BorderSide(
                                                      color: blueColor


),
                                                  bottom: i ==
                                                      _pagedData.length - 1
                                                      ? BorderSide(
                                                      color: blueColor


)
                                                      : BorderSide.none,
                                                ),
                                              ),
                                              children: [

                                                // Text(
                                                //     '${_pagedData[i].propertyType!}'),
                                                // Text(
                                                //     '${_pagedData[i].propertysubType!}'),
                                                // Text(
                                                //     '${formatDate(_pagedData[i].createdAt!)}'),
                                                // Text(
                                                //     '${formatDate(_pagedData[i].updatedAt!)}'),
                                                _buildDataCell(_pagedData[i]
                                                    .propertyType!),

                                                _buildDataCell(_pagedData[i]
                                                    .propertysubType!),

                                                _buildDataCell(
                                                  formatDate(
                                                      _pagedData[i].createdAt!),
                                                ),

                                                _buildDataCell(
                                                  formatDate(
                                                      _pagedData[i].updatedAt!),
                                                ),
                                                _buildActionsCell(
                                                    _pagedData[i]),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 25),
                                  _buildPaginationControls(),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 25),
                        ],
                      ),
                    );
                  }
                },
              ),*/
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
