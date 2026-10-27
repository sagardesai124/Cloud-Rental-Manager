import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/widgets/staff_report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../../Model/Rent_collection_model.dart';
import 'package:three_zero_two_property/StaffModule/repository/Rent_colllection_repository.dart';
import '../../../repository/daily_transaction_report.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:pdf/pdf.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class Rent_collection extends StatefulWidget {
  const Rent_collection({super.key});

  @override
  State<Rent_collection> createState() => _Rent_collectionState();
}

class _Rent_collectionState extends State<Rent_collection>
    with NetworkRetryState {
  late Future<Rentcollection_model> _futureRentcollection;
  Rentcollection_model? DelinquentTenantsModel;
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
  final List<String> months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  List<String> years = [];

  String selectedMonth = '';
  String selectedYear = '';
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
    initDropdowns();
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

  void initDropdowns() {
    DateTime now = DateTime.now();

    // Set current month/year as default
    selectedMonth = months[now.month - 1];
    selectedYear = now.year.toString();

    // Initialize filter defaults
    selectedRentalOwner = 'All';
    selectedBalanceFilter = 'All';

    // Clear the years list first to avoid duplicates
    years.clear();

    // Populate years list from 2000 up to the current year
    int currentYear = now.year;
    for (int i = 2000; i <= currentYear; i++) {
      years.add(i.toString());
    }
  }

  fetchReport() {
    setState(() {
      daterange = "Today";
      fromDate.text = formatDate(DateTime.now().toString());
      toDate.text = formatDate(DateTime.now().toString());
    });

    DateTime time = DateTime.now();
    DateTime date = DateFormat('yyyy-MM-dd').parse(time.toString());

    int monthNumber = months.indexOf(selectedMonth) + 1;

    // Assign the new Future to _futureRentcollection
    setState(() {
      _futureRentcollection = fetchDelinquentTenantsData(
        monthNumber.toString(),
        selectedYear,
      );
    });
  }

  Future<Rentcollection_model> fetchDelinquentTenantsData(
      String fromDate, String toDate,
      {String? charge}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      String? chargedata = chargeType == "All" ? null : chargeType;

      Rentcollection_model data = await RentColllectionReport()
          .FetchRentColllection(id!, fromDate, toDate, chargetype: chargedata);

      // Debug: Print API response structure

      // Debug: Print summary data as received from API
      if (data.summary != null) {
        for (int i = 0; i < data.summary!.length; i++) {
        }
      }

      setState(() {
        DelinquentTenantsModel = data;
        isLoading = false;
        errorMessage = null; // Reset error message on successful data fetch

        // Extract unique rental owners for filter
        Set<String> ownerSet = {'All'};
        if (data.leases != null) {
          for (var lease in data.leases!) {
            if (lease.rentalOwnerData?.rentalOwnerCompanyName != null) {
              ownerSet.add(lease.rentalOwnerData!.rentalOwnerCompanyName!);
            }
          }
        }
        rentalOwners = ownerSet.toList();
        // Sort rental owners alphabetically, keeping 'All' at the beginning
        rentalOwners.sort((a, b) {
          if (a == 'All') return -1;
          if (b == 'All') return 1;
          return a.toLowerCase().compareTo(b.toLowerCase());
        });
      });
      return data;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Failed to load rent collection data. Please try again later.';
      });
      rethrow;
    }
  }

  Future<void> generateDelinquentTenantsPdf(
      List<Rentcollection_model> delinquentTenantsData,
      DateProvider dateProvider) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      logError("Error fetching profile data: $e");
      return;
    }

    setState(() {
      istenantDataLoading = true;
    });

    setState(() {
      istenantDataLoading = false;
    });

    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );

    final summaryTableData = _generateSummaryTableData(delinquentTenantsData);
    final detailsTableData =
        _generateDetailsTableData(delinquentTenantsData, dateProvider);
    final delinquentLeasesTableData =
        _generateDelinquentLeasesTableData(delinquentTenantsData, dateProvider);
    if (summaryTableData.isNotEmpty) {
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
                  children: [
                    pw.Text(
                      'Rent Collection Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${selectedMonth} - ${selectedYear}',
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
                    if (profileData?.companyName?.isNotEmpty == true)
                      pw.Text(
                        profileData!.companyName!,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    if (profileData?.companyAddress?.isNotEmpty == true)
                      pw.Text(
                        profileData!.companyAddress!,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    if (profileData?.companyCity?.isNotEmpty == true ||
                        profileData?.companyState?.isNotEmpty == true ||
                        profileData?.companyCountry?.isNotEmpty == true)
                      pw.Text(
                        '${profileData?.companyCity ?? ''}${profileData?.companyCity?.isNotEmpty == true ? ', ' : ''}'
                        '${profileData?.companyState ?? ''}${profileData?.companyState?.isNotEmpty == true ? ', ' : ''}'
                        '${profileData?.companyCountry ?? ''}',
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    if (profileData?.companyPostalCode?.isNotEmpty == true)
                      pw.Text(
                        profileData!.companyPostalCode!,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
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
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rental Owner',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Charged',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Total Pending',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Collected %',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ],
                data: _generateSummaryTableData(delinquentTenantsData),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    pw.BoxDecoration(color: PdfColor.fromHex("#5A86D5")),
                cellStyle: const pw.TextStyle(fontSize: 13),
                cellAlignment: pw.Alignment.centerLeft,
                border: null,
              ),
            ];
          },
        ),
      );
    }
    // DETAILS PAGE
    if (detailsTableData.isNotEmpty) {
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
          header: (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Details',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20)
              ]),
          build: (pw.Context context) {
            return [
              pw.Table.fromTextArray(
                headers: [
                  'Street',
                  'City, State, Zip',
                  'Entity',
                  'Move-in Date',
                  'Monthly Rent',
                  'Balance',
                  'Auto-Pay',
                  'Notes',
                ],
                data: _generateDetailsTableData(
                    delinquentTenantsData, dateProvider),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    pw.BoxDecoration(color: PdfColor.fromHex("#5A86D5")),
                cellStyle: const pw.TextStyle(fontSize: 13),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
                border: null,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.0), // Street (Wider)
                  1: const pw.FlexColumnWidth(2.0), // City, State, Zip (Wider)
                  2: const pw.FlexColumnWidth(1.5), // Entity (Normal)
                  3: const pw.FlexColumnWidth(1.5), // Move-in Date (Normal)
                  4: const pw.FlexColumnWidth(1.0), // Monthly Rent (Normal)
                  5: const pw.FlexColumnWidth(1.0), // Balance (Normal)
                  6: const pw.FlexColumnWidth(1.5), // Auto-Pay (Normal)
                  7: const pw.FlexColumnWidth(1.5), // Notes (Normal)
                },
              ),
            ];
          },
        ),
      );
    }

    // DELINQUENT LEASES PAGE
    if (delinquentLeasesTableData.isNotEmpty) {
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
          header: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Delinquent Leases',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20)
            ],
          ),
          build: (pw.Context context) {
            return [
              pw.Table.fromTextArray(
                headers: [
                  'Street',
                  'City, State, Zip',
                  'Entity',
                  'Move-in Date',
                  'Monthly Rent',
                  'Balance',
                  'Auto-Pay',
                  'Notes',
                ],
                headerAlignment: pw.Alignment.centerLeft,
                data: _generateDelinquentLeasesTableData(
                    delinquentTenantsData, dateProvider),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    pw.BoxDecoration(color: PdfColor.fromHex("#5A86D5")),
                cellStyle: const pw.TextStyle(fontSize: 13),
                cellAlignment: pw.Alignment.centerLeft,
                border: null,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.0), // Street (Wider)
                  1: const pw.FlexColumnWidth(2.0), // City, State, Zip (Wider)
                  2: const pw.FlexColumnWidth(1.5), // Entity (Normal)
                  3: const pw.FlexColumnWidth(1.5), // Move-in Date (Normal)
                  4: const pw.FlexColumnWidth(1.0), // Monthly Rent (Normal)
                  5: const pw.FlexColumnWidth(1.0), // Balance (Normal)
                  6: const pw.FlexColumnWidth(1.5), // Auto-Pay (Normal)
                  7: const pw.FlexColumnWidth(1.5), // Notes (Normal)
                },
              ),
            ];
          },
        ),
      );
    }
    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'RentCollection_Report.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'RentCollection_Report',
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  List<List<dynamic>> _generateSummaryTableData(
      List<Rentcollection_model> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];

    for (var owner in rentalOwnerReports) {
      for (var property in owner.summary!) {
        tableData.add([
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(property.rentalOwnerCompany ?? '-'),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(formatCurrency(property.totalCharged) ?? '-'),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(formatCurrency(property.totalPending) ?? '-'),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(property.collectedPercentage?.toString() ?? '-'),
          ),
        ]);
      }

      // Add Overall row with bold text
      tableData.add([
        pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Overall',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            formatCurrency(owner.totalSummary?.totalCharged) ?? '-',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            formatCurrency(owner.totalSummary?.totalPending) ?? '-',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            owner.totalSummary?.averageCollectedPercentage?.toString() ?? '-',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ]);
    }

    return tableData;
  }

  List<List<String>> _generateDetailsTableData(
      List<Rentcollection_model> rentalOwnerReports,
      DateProvider dateProvider) {
    final List<List<String>> tableData = [];

    for (var owner in rentalOwnerReports) {
      for (var detail in owner.leases!) {
        // Handle Auto-Pay mapping
        String autoPay;
        if (detail.recurringCards != null &&
            detail.recurringCards!.isNotEmpty) {
          autoPay = detail.recurringCards!.map((card) {
            final tenantName = card.tenantName ?? '-';
            final date = card.date != null
                ? dateProvider.formatCurrentDate(card.date!)
                : '-';
            return '$tenantName - $date';
          }).join('\n');
        } else {
          autoPay = '-';
        }

        // Handle Notes mapping
        String notes;
        if (detail.notes != null && detail.notes!.isNotEmpty) {
          notes = detail.notes!
              .map((note) {
                final date = note.date != null
                    ? dateProvider.formatCurrentDate(note.date!)
                    : '-';
                final content = note.content ?? '';
                return '$date: $content';
              })
              .where((content) => content.isNotEmpty)
              .join('\n');
        } else {
          notes = '-';
        }

        // Add the row
        tableData.add([
          detail.rentalData?.rentalAdress ?? '-',
          '${detail.rentalData?.rentalCity ?? '-'}, '
              '${detail.rentalData?.rentalState ?? '-'}, '
              '${detail.rentalData?.rentalPostcode ?? '-'}',
          detail.rentalOwnerData?.rentalOwnerCompanyName ?? '-',
          detail.leaseData?.startDate != null
              ? dateProvider.formatCurrentDate(detail.leaseData!.startDate!)
              : '-',
          formatCurrency(detail.leaseData?.leaseAmount),
          formatCurrency(detail.leaseData?.balance),
          autoPay,
          notes,
        ]);
      }
    }

    return tableData;
  }

  List<List<dynamic>> _generateDelinquentLeasesTableData(
      List<Rentcollection_model> rentalOwnerReports,
      DateProvider dateProvider) {
    final List<List<dynamic>> tableData = [];

    for (var owner in rentalOwnerReports) {
      final List<List<dynamic>> ownerTableData = [];

      for (var detail in owner.deadBeats!) {
        final balance = detail.leaseData?.balance ?? 0;

        if (balance > 0) {
          String autoPay;
          if (detail.recurringCards != null &&
              detail.recurringCards!.isNotEmpty) {
            autoPay = detail.recurringCards!.map((card) {
              final tenantName = card.tenantName ?? '-';
              final date = card.date != null
                  ? dateProvider.formatCurrentDate(card.date!)
                  : '-';
              return '$date : $tenantName';
            }).join('\n');
          } else {
            autoPay = '-';
          }

          String notes;
          if (detail.notes != null && detail.notes!.isNotEmpty) {
            notes = detail.notes!
                .map((note) {
                  final date = note.date != null
                      ? dateProvider.formatCurrentDate(note.date!)
                      : '-';
                  final content = note.content ?? '';
                  return '$date: $content';
                })
                .where((content) => content.isNotEmpty)
                .join('\n');
          } else {
            notes = '-';
          }

          ownerTableData.add([
            detail.rentalData?.rentalAdress ?? '-',
            '${detail.rentalData?.rentalCity ?? '-'}, '
                '${detail.rentalData?.rentalState ?? '-'}, '
                '${detail.rentalData?.rentalPostcode ?? '-'}',
            detail.rentalOwnerData?.rentalOwnerCompanyName ?? '-',
            detail.leaseData?.startDate != null
                ? dateProvider.formatCurrentDate(detail.leaseData!.startDate!)
                : '-',
            formatCurrency(detail.leaseData?.leaseAmount),
            formatCurrency(balance),
            autoPay,
            notes,
          ]);
        }
      }

      if (ownerTableData.isNotEmpty) {
        ownerTableData.add([
          pw.Text(
            'Overall',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(
            formatMoney(owner.deadBeatsSummary?.totalBalance?.toStringAsFixed(2) ?? '-'),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ]);
      }

      tableData.addAll(ownerTableData); // Add owner's data to full table
    }

    return tableData;
  }

  List<List<dynamic>> _generateSummaryTableDataExcel(
      List<Rentcollection_model> rentalOwnerReports) {
    final List<List<dynamic>> tableData = [];

    for (var owner in rentalOwnerReports) {
      for (var property in owner.summary!) {
        tableData.add([
          property.rentalOwnerCompany ?? '-',
          formatCurrency(property.totalCharged) ?? '-',
          formatCurrency(property.totalPending) ?? '-',
          property.collectedPercentage?.toString() ?? '-',
        ]);
      }

      // Add Overall row
      tableData.add([
        'Overall',
        formatCurrency(owner.totalSummary?.totalCharged) ?? '-',
        formatCurrency(owner.totalSummary?.totalPending) ?? '-',
        owner.totalSummary?.averageCollectedPercentage?.toString() ?? '-',
      ]);
    }

    return tableData;
  }

  List<List<dynamic>> _generateDetailsTableDataExcel(
      List<Rentcollection_model> rentalOwnerReports,
      DateProvider dateProvider) {
    final List<List<dynamic>> tableData = [];

    for (var owner in rentalOwnerReports) {
      for (var detail in owner.leases!) {
        // Handle Auto-Pay mapping
        String autoPay;
        if (detail.recurringCards != null &&
            detail.recurringCards!.isNotEmpty) {
          autoPay = detail.recurringCards!.map((card) {
            final tenantName = card.tenantName ?? '-';
            final date = card.date ?? '-';
            return '$tenantName - $date';
          }).join('\n');
        } else {
          autoPay = '-';
        }

        // Handle Notes mapping
        String notes;
        if (detail.notes != null && detail.notes!.isNotEmpty) {
          notes = detail.notes!
              .map((note) {
                final date = note.date ?? '-';
                final content = note.content ?? '';
                return '$date: $content';
              })
              .where((content) => content.isNotEmpty)
              .join('\n');
        } else {
          notes = '-';
        }

        // Add the row
        tableData.add([
          detail.rentalData?.rentalAdress ?? '-',
          '${detail.rentalData?.rentalCity ?? '-'}, '
              '${detail.rentalData?.rentalState ?? '-'}, '
              '${detail.rentalData?.rentalPostcode ?? '-'}',
          detail.rentalOwnerData?.rentalOwnerCompanyName ?? '-',
          detail.leaseData?.startDate != null
              ? dateProvider.formatCurrentDate(detail.leaseData!.startDate!)
              : '-',
          formatCurrency(detail.leaseData?.leaseAmount),
          formatCurrency(detail.leaseData?.balance),
          autoPay,
          notes,
        ]);
      }
    }

    return tableData;
  }

  List<List<dynamic>> _generateDelinquentLeasesTableDataExcel(
      List<Rentcollection_model> rentalOwnerReports,
      DateProvider dateProvider) {
    final List<List<dynamic>> tableData = [];

    for (var owner in rentalOwnerReports) {
      final List<List<dynamic>> ownerTableData = [];

      for (var detail in owner.deadBeats!) {
        final balance = detail.leaseData?.balance ?? 0;

        if (balance > 0) {
          String autoPay;
          if (detail.recurringCards != null &&
              detail.recurringCards!.isNotEmpty) {
            autoPay = detail.recurringCards!.map((card) {
              final tenantName = card.tenantName ?? '-';
              final date = card.date != null
                  ? dateProvider.formatCurrentDate(card.date!)
                  : '-';
              return '$date : $tenantName';
            }).join('\n');
          } else {
            autoPay = '-';
          }

          String notes;
          if (detail.notes != null && detail.notes!.isNotEmpty) {
            notes = detail.notes!
                .map((note) {
                  final date = note.date != null
                      ? dateProvider.formatCurrentDate(note.date!)
                      : '-';
                  final content = note.content ?? '';
                  return '$date: $content';
                })
                .where((content) => content.isNotEmpty)
                .join('\n');
          } else {
            notes = '-';
          }

          ownerTableData.add([
            detail.rentalData?.rentalAdress ?? '-',
            '${detail.rentalData?.rentalCity ?? '-'}, '
                '${detail.rentalData?.rentalState ?? '-'}, '
                '${detail.rentalData?.rentalPostcode ?? '-'}',
            detail.rentalOwnerData?.rentalOwnerCompanyName ?? '-',
            detail.leaseData?.startDate != null
                ? dateProvider.formatCurrentDate(detail.leaseData!.startDate!)
                : '-',
            formatCurrency(detail.leaseData?.leaseAmount),
            formatCurrency(balance),
            autoPay,
            notes,
          ]);
        }
      }

      if (ownerTableData.isNotEmpty) {
        ownerTableData.add([
          'Overall',
          '',
          '',
          '',
          '',
          formatMoney(owner.deadBeatsSummary?.totalBalance?.toStringAsFixed(2) ?? '-'),
          '',
          '',
        ]);
      }

      tableData.addAll(ownerTableData);
    }

    return tableData;
  }

  Future<void> generateDelinquentTenantsExcel(
      List<Rentcollection_model> delinquentTenantsData,
      DateProvider dateProvider) async {
    setState(() {
      istenantDataLoading = true;
    });

    // Create a new Excel document
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet mainSheet = workbook.worksheets[0];
    mainSheet.name = 'Delinquent Tenants Report';

    int rowIndex = 1;

    // Add SUMMARY TABLE
    mainSheet.getRangeByName('A$rowIndex').setText('Summary');
    mainSheet.getRangeByName('A$rowIndex').cellStyle.bold = true;
    mainSheet.getRangeByName('A$rowIndex').cellStyle.fontSize = 18;
    rowIndex += 2;

    mainSheet.getRangeByName('A$rowIndex').setText('Rental Owner');
    mainSheet.getRangeByName('B$rowIndex').setText('Total Charged');
    mainSheet.getRangeByName('C$rowIndex').setText('Total Pending');
    mainSheet.getRangeByName('D$rowIndex').setText('Collected %');

    final syncXlsx.Range summaryHeaderRange =
        mainSheet.getRangeByName('A$rowIndex:D$rowIndex');
    summaryHeaderRange.cellStyle.bold = true;
    summaryHeaderRange.cellStyle.fontColor = '#FFFFFF';
    summaryHeaderRange.cellStyle.backColor = '#5A86D5';
    rowIndex++;

    final summaryTableData =
        _generateSummaryTableDataExcel(delinquentTenantsData);
    for (int i = 0; i < summaryTableData.length; i++) {
      for (int j = 0; j < summaryTableData[i].length; j++) {
        mainSheet
            .getRangeByIndex(rowIndex, 1 + j)
            .setText(summaryTableData[i][j]);
      }
      rowIndex++;
    }

    rowIndex += 2;

    // Add DETAILS TABLE
    mainSheet.getRangeByName('A$rowIndex').setText('Details');
    mainSheet.getRangeByName('A$rowIndex').cellStyle.bold = true;
    mainSheet.getRangeByName('A$rowIndex').cellStyle.fontSize = 18;
    rowIndex += 2;

    mainSheet.getRangeByName('A$rowIndex').setText('Street');
    mainSheet.getRangeByName('B$rowIndex').setText('City, State, Zip');
    mainSheet.getRangeByName('C$rowIndex').setText('Entity');
    mainSheet.getRangeByName('D$rowIndex').setText('Move-in Date');
    mainSheet.getRangeByName('E$rowIndex').setText('Monthly Rent');
    mainSheet.getRangeByName('F$rowIndex').setText('Balance');
    mainSheet.getRangeByName('G$rowIndex').setText('Auto-Pay');
    mainSheet.getRangeByName('H$rowIndex').setText('Notes');

    final syncXlsx.Range detailsHeaderRange =
        mainSheet.getRangeByName('A$rowIndex:H$rowIndex');
    detailsHeaderRange.cellStyle.bold = true;
    detailsHeaderRange.cellStyle.fontColor = '#FFFFFF';
    detailsHeaderRange.cellStyle.backColor = '#5A86D5';
    rowIndex++;

    final detailsTableData =
        _generateDetailsTableDataExcel(delinquentTenantsData, dateProvider);
    for (int i = 0; i < detailsTableData.length; i++) {
      for (int j = 0; j < detailsTableData[i].length; j++) {
        mainSheet
            .getRangeByIndex(rowIndex, 1 + j)
            .setText(detailsTableData[i][j]);
      }
      rowIndex++;
    }

    rowIndex += 2;

    // Add DELINQUENT LEASES TABLE
    mainSheet.getRangeByName('A$rowIndex').setText('Delinquent Leases');
    mainSheet.getRangeByName('A$rowIndex').cellStyle.bold = true;
    mainSheet.getRangeByName('A$rowIndex').cellStyle.fontSize = 18;
    rowIndex += 2;

    mainSheet.getRangeByName('A$rowIndex').setText('Street');
    mainSheet.getRangeByName('B$rowIndex').setText('City, State, Zip');
    mainSheet.getRangeByName('C$rowIndex').setText('Entity');
    mainSheet.getRangeByName('D$rowIndex').setText('Move-in Date');
    mainSheet.getRangeByName('E$rowIndex').setText('Monthly Rent');
    mainSheet.getRangeByName('F$rowIndex').setText('Balance');
    mainSheet.getRangeByName('G$rowIndex').setText('Auto-Pay');
    mainSheet.getRangeByName('H$rowIndex').setText('Notes');

    final syncXlsx.Range delinquentHeaderRange =
        mainSheet.getRangeByName('A$rowIndex:H$rowIndex');
    delinquentHeaderRange.cellStyle.bold = true;
    delinquentHeaderRange.cellStyle.fontColor = '#FFFFFF';
    delinquentHeaderRange.cellStyle.backColor = '#5A86D5';
    rowIndex++;

    final delinquentLeasesTableData = _generateDelinquentLeasesTableDataExcel(
        delinquentTenantsData, dateProvider);
    for (int i = 0; i < delinquentLeasesTableData.length; i++) {
      for (int j = 0; j < delinquentLeasesTableData[i].length; j++) {
        mainSheet
            .getRangeByIndex(rowIndex, 1 + j)
            .setText(delinquentLeasesTableData[i][j]);
      }
      rowIndex++;
    }

    setState(() {
      istenantDataLoading = false;
    });

    // Save and launch the Excel file
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Rent_collection_report_$formattedDate.xlsx';

    // /storage/emulated/0/Pictures is blocked by Android scoped storage; use
    // the app documents dir on both platforms (file is shared via Share sheet)
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

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

  Future<void> generateDelinquentTenantsCSV(
      List<Rentcollection_model> delinquentTenantsData,
      DateProvider dateProvider) async {
    setState(() {
      istenantDataLoading = true;
    });

    // Prepare the CSV content
    final StringBuffer csvBuffer = StringBuffer();

    // Same layout as web's Rent Collection CSV (RentCollectionReport.jsx):
    // the Details first, then the Summary under padded columns, then the
    // Delinquent Leases.
    csvBuffer.writeln(csvRow(const [
      'Address',
      'City, State, Zip',
      'Entity',
      'Move-in Date',
      'Monthly Rent',
      'Balance',
      'Auto-Pay',
      'Notes',
    ]));
    final detailsTableData =
        _generateDetailsTableDataExcel(delinquentTenantsData, dateProvider);
    for (var row in detailsTableData) {
      csvBuffer.writeln(csvRow(row));
    }
    csvBuffer.writeln();
    csvBuffer.writeln();

    csvBuffer.writeln(csvRow(const [
      '',
      '',
      'Entity',
      '',
      'Total Charged',
      'Total Outstanding',
      'Collected %',
    ]));
    final summaryTableData =
        _generateSummaryTableDataExcel(delinquentTenantsData);
    for (var row in summaryTableData) {
      csvBuffer.writeln(csvRow(['', '', row[0], '', row[1], row[2], row[3]]));
    }
    csvBuffer.writeln();
    csvBuffer.writeln();

    csvBuffer.writeln(csvRow(const ['', '', '', 'Delinquent Leases', '', '', '']));
    final delinquentLeasesTableData = _generateDelinquentLeasesTableDataExcel(
        delinquentTenantsData, dateProvider);
    for (var row in delinquentLeasesTableData) {
      csvBuffer.writeln(csvRow(row));
    }

    // Save the CSV file
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Rent_collection_report_$formattedDate.csv';
    // /storage/emulated/0/Pictures is blocked by Android scoped storage; use
    // the app documents dir on both platforms (file is shared via Share sheet)
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    if (!await directory.exists() && !Platform.isIOS) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsString(csvBuffer.toString(), flush: true);

    Share.shareXFiles([XFile(path)]);
    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );

    setState(() {
      istenantDataLoading = false;
    });
  }

  // Future<void> generateRentalOwnerReportExcel(
  //     List<Rentcollection_model> rentalOwnerReports) async
  // {
  //   final syncXlsx.Workbook workbook = syncXlsx.Workbook();
  //   final syncXlsx.Worksheet sheet = workbook.worksheets[0];
  //
  //   sheet.getRangeByName('A1:I1').columnWidth = 20;
  //
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
  //   final syncXlsx.Style headerCellStyle =
  //   workbook.styles.add('headerCellStyle');
  //   headerCellStyle.bold = true;
  //   headerCellStyle.backColor = '#5A86D5';
  //   headerCellStyle.fontColor = '#FFFFFF';
  //   headerCellStyle.fontSize = 16;
  //   headerCellStyle.hAlign = syncXlsx.HAlignType.center;
  //
  //   final syncXlsx.Style currencyCellStyle =
  //   workbook.styles.add('currencyCellStyle');
  //   currencyCellStyle.numberFormat = '\$#,##0.00'; // Currency format
  //   currencyCellStyle.hAlign = syncXlsx.HAlignType.right; // Right-align amounts
  //
  //   final syncXlsx.Style boldAmountStyle =
  //   workbook.styles.add('boldAmountStyle');
  //   boldAmountStyle.bold = true;
  //   boldAmountStyle.numberFormat = '\$#,##0.00';
  //   boldAmountStyle.hAlign = syncXlsx.HAlignType.right;
  //   final syncXlsx.Style AmountTitleStyle =
  //   workbook.styles.add('AmountTitleStyle');
  //   boldAmountStyle.bold = true;
  //   boldAmountStyle.numberFormat = '\$#,##0.00';
  //
  //   for (int i = 0; i < headers.length; i++) {
  //     final cell = sheet.getRangeByIndex(1, i + 1);
  //     cell.setText(headers[i]);
  //     cell.cellStyle = headerCellStyle;
  //   }
  //
  //   int rowIndex = 2;
  //   double grandTotal = 0.0;
  //
  //   for (var owner in rentalOwnerReports) {
  //     final rentalOwnerCell = sheet.getRangeByIndex(rowIndex, 1);
  //     rentalOwnerCell.setText(owner.date ?? '');
  //     rentalOwnerCell.cellStyle.bold = true;
  //     sheet.getRangeByName('A$rowIndex:I$rowIndex').merge();
  //     rowIndex++;
  //
  //     for (var property in owner.charges!) {
  //       sheet
  //           .getRangeByIndex(rowIndex, 1)
  //           .setText(property.rentalData!.rentalAddress ?? 'N/A');
  //       sheet.getRangeByIndex(rowIndex, 2).setText(
  //           '${property.tenantData?.tenantFirstName ?? 'N/A'} ${property.tenantData?.tenantLastName ?? 'N/A'}');
  //       sheet
  //           .getRangeByIndex(rowIndex, 3)
  //           .setText(property.updatedAt.toString());
  //       sheet.getRangeByIndex(rowIndex, 4).setText(property.paymentType ?? 'N/A');
  //       sheet
  //           .getRangeByIndex(rowIndex, 5)
  //           .setText(property.transactionId ?? 'N/A');
  //       sheet.getRangeByIndex(rowIndex, 6).setText(property.paymentId ?? 'N/A');
  //       sheet.getRangeByIndex(rowIndex, 7).setText(property.cc_type ?? 'N/A');
  //       sheet.getRangeByIndex(rowIndex, 8).setText(property.cc_number ?? 'N/A');
  //       sheet
  //           .getRangeByIndex(rowIndex, 9)
  //           .setNumber(property.totalAmount ?? 0.0);
  //       sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
  //       rowIndex++;
  //
  //       if(property.response != "FAILURE" && property.isDelete!=true)
  //         for (var payment in property.entry!) {
  //           sheet.getRangeByIndex(rowIndex, 1).setText(payment.account ?? 'N/A');
  //           sheet.getRangeByIndex(rowIndex, 9).setNumber(payment.amount);
  //           sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
  //           rowIndex++;
  //         }
  //
  //       // if (property.surcharge != 0.0) {
  //       //   sheet.getRangeByIndex(rowIndex, 1).setText('Surcharge');
  //       //   sheet.getRangeByIndex(rowIndex, 9).setNumber(property.surcharge);
  //       //   sheet.getRangeByIndex(rowIndex, 9).cellStyle = currencyCellStyle;
  //       //   rowIndex++;
  //       // }
  //     }
  //
  //     sheet
  //         .getRangeByIndex(rowIndex, 1)
  //         .setText('Subtotal - ${owner.date}');
  //     sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
  //     sheet.getRangeByIndex(rowIndex, 9).setNumber(owner.subtotal ?? 0.0);
  //     sheet.getRangeByIndex(rowIndex, 9).cellStyle = boldAmountStyle;
  //     sheet.getRangeByName('A$rowIndex:H$rowIndex').merge();
  //     rowIndex++;
  //
  //     grandTotal += owner.subtotal ?? 0.0;
  //   }
  //
  //   sheet.getRangeByIndex(rowIndex, 1).setText('Grand Total');
  //   sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
  //   sheet.getRangeByIndex(rowIndex, 9).setNumber(grandTotal);
  //   sheet.getRangeByIndex(rowIndex, 9).cellStyle = boldAmountStyle;
  //   sheet.getRangeByName('A$rowIndex:H$rowIndex').merge();
  //
  //   final List<int> bytes = workbook.saveAsStream();
  //   workbook.dispose();
  //
  //   final DateTime now = DateTime.now();
  //   final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
  //   final String fileName = 'Daily_transaction_report_$formattedDate.xlsx';
  //
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
  //   final File file = File(path);
  //   await file.writeAsBytes(bytes, flush: true);
  //   Share.shareXFiles([XFile(path)]);
  //   Fluttertoast.showToast(
  //     msg: 'Excel file saved to $path',
  //   );
  // }
  //
  // Future<void> generateRentalOwnerReportCsv(
  //     List<Rentcollection_model> rentalOwnerReports) async
  // {
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
  //     csvBuffer.writeln('${owner.date ?? ''}');
  //
  //     // Iterate through each property for the current rental owner
  //     for (var property in owner.charges!) {
  //       // Replace commas in the rental address with spaces
  //       final String sanitizedAddress =
  //       (property.rentalData!.rentalAddress ?? 'N/A').replaceAll(',', ' ');
  //
  //       // Add property and tenant details
  //       csvBuffer.writeln([
  //         sanitizedAddress,
  //         '${property.tenantData!.tenantFirstName ?? 'N/A'} ${property.tenantData!.tenantLastName ?? 'N/A'}',
  //         property.updatedAt.toString(),
  //         property.paymentType ?? 'N/A',
  //         property.transactionId ?? 'N/A',
  //         property.paymentId ?? 'N/A',
  //         property.cc_type ?? 'N/A',
  //         property.cc_number ?? 'N/A',
  //         '\$${property.totalAmount?.toStringAsFixed(2) ?? '0.00'}'
  //       ].join(','));
  //
  //       // Iterate through payment entries for the current property
  //       for (var payment in property.entry!) {
  //         csvBuffer.writeln([
  //           payment.account ?? 'N/A',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '',
  //           '\$${payment.amount!.toStringAsFixed(2)}'
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
  //       'Subtotal - ${owner.date}',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '',
  //       '\$${(owner.subtotal ?? 0.0).toStringAsFixed(2)}'
  //     ].join(','));
  //
  //     // Accumulate grand total
  //     grandTotal += owner.subtotal ?? 0.0;
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
  //   final String fileName = 'Daily_transaction_report_$formattedDate.csv';
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
  //   Share.shareXFiles([XFile(path)]);
  //   // Show success toast message
  //   Fluttertoast.showToast(
  //     msg: 'CSV file saved to $path',
  //   );
  // }

  double grandtotal = 0.0;

  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  String searchvalue = "";
  String? selectedValue;
  String? selectedRentalOwner;
  String? selectedBalanceFilter;
  List<String> rentalOwners = ['All'];
  List<String> balanceFilters = ['All', 'Has Balance', 'No Balance'];

  int totalrecords = 0;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [10, 25, 50, 100];
  bool customdate = false;

  int? nestedExpandedIndex;

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
              margin: const EdgeInsets.only(left: 5),
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
                size: 20,
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
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text("Entity",
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text("Total Outstanding",
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(width: 25),
                  ],
                ),
              ),
            ),
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
            //
            //         // Sorting logic here
            //       });
            //     },
            //     child: Row(
            //       children: [
            //         Text("     Record", style: TextStyle(color: Colors.white)),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadersDetails() {
    var width = MediaQuery.of(context).size.width;
    bool isSmallScreen = width < 536;
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
              margin: const EdgeInsets.only(left: 5),
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
                size: 20,
              ),
            ),
            SizedBox(width: isSmallScreen ? 2 : 3),
            Expanded(
              flex: isSmallScreen ? 4 : 3,
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
                      Flexible(
                        child: Text("Address",
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      // Text("Property", style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 3),
                      ascending1
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10, left: 2),
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
            ),
            SizedBox(width: isSmallScreen ? 4 : 8),
            Expanded(
              flex: isSmallScreen ? 3 : 2,
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
                    Flexible(
                      child: Text("Entity",
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: isSmallScreen ? 4 : 8),
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Balance",
                          style:
                              TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 3),
                      ascending3
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortUp,
                                size: 16,
                                color: blueColor,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 7, left: 2),
                              child: FaIcon(
                                FontAwesomeIcons.sortDown,
                                size: 16,
                                color: blueColor,
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: isSmallScreen ? 10 : 16),
          ],
        ),
      ),
    );
  }

  bool istenantDataLoading = false;
  bool isAddLoading = false;
//  bool customdate = false;

  TextEditingController fromDate = TextEditingController();
  TextEditingController toDate = TextEditingController();
  String? daterange;
  String? chargeType;
  String? selectedrenatalownerid;
  bool showTableData = false;
  int _selectedIndex = 0;
  final List<String> downloadOptions = ['PDF', 'Excel', 'CSV'];
  void handleDownload(String format) {
    // Replace with your download logic
  }

  List<Leases> getSortedLeases(List<Leases> data) {
    List<Leases> sortedData = List<Leases>.from(data);
    if (sorting1) {
      sortedData.sort((a, b) {
        final aAddress = a.rentalData?.rentalAdress ?? '';
        final bAddress = b.rentalData?.rentalAdress ?? '';
        return ascending1
            ? aAddress.compareTo(bAddress)
            : bAddress.compareTo(aAddress);
      });
    } else if (sorting3) {
      sortedData.sort((a, b) {
        final aBalance = a.leaseData?.balance ?? 0.0;
        final bBalance = b.leaseData?.balance ?? 0.0;
        return ascending3
            ? aBalance.compareTo(bBalance)
            : bBalance.compareTo(aBalance);
      });
    }
    return sortedData;
  }

  // Method to sort summary data for consistent ordering
  List<Summary> _getSortedSummaryData(List<Summary> data) {
    List<Summary> sortedData = List<Summary>.from(data);

    // Sort by rental owner company name alphabetically (you can change this logic)
    sortedData.sort((a, b) {
      final aCompany = a.rentalOwnerCompany ?? '';
      final bCompany = b.rentalOwnerCompany ?? '';
      return aCompany.toLowerCase().compareTo(bCompany.toLowerCase());
    });

    // Alternative sorting options (uncomment as needed):

    // Sort by total pending amount (highest to lowest)
    // sortedData.sort((a, b) {
    //   final aPending = a.totalPending ?? 0.0;
    //   final bPending = b.totalPending ?? 0.0;
    //   return bPending.compareTo(aPending);
    // });

    // Sort by total charged amount (highest to lowest)
    // sortedData.sort((a, b) {
    //   final aCharged = a.totalCharged ?? 0.0;
    //   final bCharged = b.totalCharged ?? 0.0;
    //   return bCharged.compareTo(aCharged);
    // });

    return sortedData;
  }

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
                    title: "Rent Collection Report",
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 16),
                  // if (MediaQuery.of(context).size.width < 500)
                  Column(
                    children: [
                      const SizedBox(height: 10),
                      // Always show filters
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                              // Month Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonHideUnderline(
                                  child: Material(
                                    elevation: 0,
                                    borderRadius: BorderRadius.circular(8),
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: const Text(
                                        'Month',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8A95A8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      items: months.map((String month) {
                                        return DropdownMenuItem<String>(
                                          value: month,
                                          child: Text(
                                            month,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: selectedMonth.isNotEmpty
                                          ? selectedMonth
                                          : null,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedMonth = value!;
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 45,
                                        width: double.infinity,
                                        padding: const EdgeInsets.only(
                                            left: 8, right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        offset: const Offset(0, 0),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(20),
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
                                            left: 8, right: 8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Year Dropdown
                              Expanded(
                                flex: 2,
                                child: DropdownButtonHideUnderline(
                                  child: Material(
                                    elevation: 0,
                                    borderRadius: BorderRadius.circular(8),
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: const Text(
                                        'Year',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF8A95A8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      items: years.map((String year) {
                                        return DropdownMenuItem<String>(
                                          value: year,
                                          child: Text(
                                            year,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: selectedYear.isNotEmpty
                                          ? selectedYear
                                          : null,
                                      onChanged: (value) {
                                        setState(() {
                                          selectedYear = value!;
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 45,
                                        width: double.infinity,
                                        padding: const EdgeInsets.only(
                                            left: 8, right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        offset: const Offset(0, 0),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(20),
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
                                            left: 8, right: 8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Run Report Button
                              Container(
                                height: 45,
                                width: 45,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color.fromRGBO(
                                          206, 212, 218, 1)),
                                  borderRadius: BorderRadius.circular(0),
                                  color: Colors.white,
                                ),
                                child: IconButton(
                                  icon: const FaIcon(
                                      FontAwesomeIcons.circlePlay,
                                      size: 18),
                                  onPressed: () {
                                    setState(() {
                                      isLoading = true;
                                      int monthNumber =
                                          months.indexOf(selectedMonth) + 1;
                                      _futureRentcollection =
                                          fetchDelinquentTenantsData(
                                        monthNumber.toString(),
                                        selectedYear,
                                      );
                                    });
                                  },
                                  tooltip: "Run Report",
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Download Button
                              // No rows yet: Export stays in place, greyed and disabled.
                              Container(
                                height: 45,
                                width: 60,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color.fromRGBO(
                                          206, 212, 218, 1)),
                                  borderRadius: BorderRadius.circular(0),
                                  color: Colors.white,
                                ),
                                child: FutureBuilder<Rentcollection_model>(
                                  future: _futureRentcollection,
                                  builder: (context, snapshot) {
                                    final bool hasExportData =
                                        DelinquentTenantsModel
                                                ?.leases?.isNotEmpty ??
                                            false;
                                    return PopupMenuButton<String>(
                                      enabled: hasExportData,
                                      offset: const Offset(0, 45),
                                      onSelected: handleDownload,
                                      icon: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FaIcon(FontAwesomeIcons.download,
                                              size: 16,
                                              color: hasExportData
                                                  ? null
                                                  : Colors.grey.shade400),
                                          const SizedBox(width: 2),
                                          Icon(Icons.arrow_drop_down,
                                              size: 16,
                                              color: hasExportData
                                                  ? null
                                                  : Colors.grey.shade400),
                                        ],
                                      ),
                                      tooltip: "Download",
                                      itemBuilder: (BuildContext context) {
                                        if (!snapshot.hasData ||
                                            snapshot.data!.summary!.isEmpty) {
                                          return <PopupMenuEntry<String>>[];
                                        }
                                        return downloadOptions
                                            .map((String option) {
                                          return PopupMenuItem<String>(
                                            value: option,
                                            onTap: () async {
                                              if (option == "PDF")
                                                generateDelinquentTenantsPdf(
                                                    [snapshot.data!],
                                                    dateProvider);
                                              if (option == "Excel")
                                                generateDelinquentTenantsExcel(
                                                    [snapshot.data!],
                                                    dateProvider);
                                              if (option == "CSV")
                                                generateDelinquentTenantsCSV(
                                                    [snapshot.data!],
                                                    dateProvider);
                                            },
                                            child: Text("Download as $option"),
                                          );
                                        }).toList();
                                      },
                                    );
                                  },
                                ),
                              ),
                              ],
                            ),
                      ),
                      const SizedBox(height: 10),
                      // Content based on state
                      FutureBuilder<Rentcollection_model>(
                        future: _futureRentcollection,
                        builder: (context, snapshot) {
                          if (isLoading) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: ColabShimmerLoadingWidget(),
                            );
                          } else if (snapshot.hasError) {
                            return Container(
                              height: MediaQuery.of(context).size.height * .5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 64, color: Colors.red),
                                    const SizedBox(height: 10),
                                    Text(
                                      errorMessage ??
                                          'Failed to load report. Please try again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data?.summary == null ||
                              snapshot.data!.summary!.isEmpty) {
                            return Container(
                              height: MediaQuery.of(context).size.height * .5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      "assets/images/no_data_transparent.png",
                                      height: 200,
                                      width: 200,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "No Data Available",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      "Try selecting a different month or year",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          var data = snapshot.data!.summary!;
                          var dataall = snapshot.data!;
                          // final currentPageData = data;
                          var dataa = snapshot.data!.leases!;
                          var totaldata = snapshot.data;
                          var delinquentdata = snapshot.data?.deadBeats;

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // // Search and Filter Controls
                                // if (_selectedIndex ==
                                //     1) // Show filters only for Details tab
                                //   Padding(
                                //     padding: const EdgeInsets.symmetric(
                                //         horizontal: 16, vertical: 8),
                                //     child: Column(
                                //       children: [
                                //         // Search Bar
                                //         Container(
                                //           height: 45,
                                //           child: TextField(
                                //             onChanged: (value) {
                                //               setState(() {
                                //                 searchvalue = value;
                                //               });
                                //             },
                                //             decoration: InputDecoration(
                                //               hintText:
                                //                   'Search by address or company...',
                                //               prefixIcon:
                                //                   const Icon(Icons.search),
                                //               border: OutlineInputBorder(
                                //                 borderRadius:
                                //                     BorderRadius.circular(8),
                                //               ),
                                //               contentPadding:
                                //                   const EdgeInsets.symmetric(
                                //                       horizontal: 16,
                                //                       vertical: 12),
                                //             ),
                                //           ),
                                //         ),
                                //         const SizedBox(height: 8),
                                //         // Filter Row - Responsive Layout
                                //         LayoutBuilder(
                                //           builder: (context, constraints) {
                                //             if (constraints.maxWidth < 600) {
                                //               // Stack filters vertically on small screens
                                //               return Column(
                                //                 children: [
                                //                   DropdownButtonFormField<
                                //                       String>(
                                //                     value: selectedRentalOwner,
                                //                     decoration: InputDecoration(
                                //                       labelText: 'Rental Owner',
                                //                       border:
                                //                           OutlineInputBorder(
                                //                         borderRadius:
                                //                             BorderRadius
                                //                                 .circular(8),
                                //                       ),
                                //                       contentPadding:
                                //                           const EdgeInsets
                                //                               .symmetric(
                                //                               horizontal: 12,
                                //                               vertical: 8),
                                //                     ),
                                //                     items: rentalOwners
                                //                         .map((owner) {
                                //                       return DropdownMenuItem(
                                //                         value: owner,
                                //                         child: Text(
                                //                           owner,
                                //                           overflow: TextOverflow
                                //                               .ellipsis,
                                //                         ),
                                //                       );
                                //                     }).toList(),
                                //                     onChanged: (value) {
                                //                       setState(() {
                                //                         selectedRentalOwner =
                                //                             value;
                                //                       });
                                //                     },
                                //                   ),
                                //                   const SizedBox(height: 10),
                                //                   DropdownButtonFormField<
                                //                       String>(
                                //                     value:
                                //                         selectedBalanceFilter,
                                //                     decoration: InputDecoration(
                                //                       labelText:
                                //                           'Balance Filter',
                                //                       border:
                                //                           OutlineInputBorder(
                                //                         borderRadius:
                                //                             BorderRadius
                                //                                 .circular(8),
                                //                       ),
                                //                       contentPadding:
                                //                           const EdgeInsets
                                //                               .symmetric(
                                //                               horizontal: 12,
                                //                               vertical: 8),
                                //                     ),
                                //                     items: balanceFilters
                                //                         .map((filter) {
                                //                       return DropdownMenuItem(
                                //                         value: filter,
                                //                         child: Text(
                                //                           filter,
                                //                           overflow: TextOverflow
                                //                               .ellipsis,
                                //                         ),
                                //                       );
                                //                     }).toList(),
                                //                     onChanged: (value) {
                                //                       setState(() {
                                //                         selectedBalanceFilter =
                                //                             value;
                                //                       });
                                //                     },
                                //                   ),
                                //                 ],
                                //               );
                                //             } else {
                                //               // Keep horizontal layout for larger screens
                                //               return Row(
                                //                 children: [
                                //                   Expanded(
                                //                     child:
                                //                         DropdownButtonFormField<
                                //                             String>(
                                //                       value:
                                //                           selectedRentalOwner,
                                //                       decoration:
                                //                           InputDecoration(
                                //                         labelText:
                                //                             'Rental Owner',
                                //                         border:
                                //                             OutlineInputBorder(
                                //                           borderRadius:
                                //                               BorderRadius
                                //                                   .circular(8),
                                //                         ),
                                //                         contentPadding:
                                //                             const EdgeInsets
                                //                                 .symmetric(
                                //                                 horizontal: 12,
                                //                                 vertical: 8),
                                //                       ),
                                //                       items: rentalOwners
                                //                           .map((owner) {
                                //                         return DropdownMenuItem(
                                //                           value: owner,
                                //                           child: Text(
                                //                             owner,
                                //                             overflow:
                                //                                 TextOverflow
                                //                                     .ellipsis,
                                //                           ),
                                //                         );
                                //                       }).toList(),
                                //                       onChanged: (value) {
                                //                         setState(() {
                                //                           selectedRentalOwner =
                                //                               value;
                                //                         });
                                //                       },
                                //                     ),
                                //                   ),
                                //                   const SizedBox(width: 10),
                                //                   Expanded(
                                //                     child:
                                //                         DropdownButtonFormField<
                                //                             String>(
                                //                       value:
                                //                           selectedBalanceFilter,
                                //                       decoration:
                                //                           InputDecoration(
                                //                         labelText:
                                //                             'Balance Filter',
                                //                         border:
                                //                             OutlineInputBorder(
                                //                           borderRadius:
                                //                               BorderRadius
                                //                                   .circular(8),
                                //                         ),
                                //                         contentPadding:
                                //                             const EdgeInsets
                                //                                 .symmetric(
                                //                                 horizontal: 12,
                                //                                 vertical: 8),
                                //                       ),
                                //                       items: balanceFilters
                                //                           .map((filter) {
                                //                         return DropdownMenuItem(
                                //                           value: filter,
                                //                           child: Text(
                                //                             filter,
                                //                             overflow:
                                //                                 TextOverflow
                                //                                     .ellipsis,
                                //                           ),
                                //                         );
                                //                       }).toList(),
                                //                       onChanged: (value) {
                                //                         setState(() {
                                //                           selectedBalanceFilter =
                                //                               value;
                                //                         });
                                //                       },
                                //                     ),
                                //                   ),
                                //                 ],
                                //               );
                                //             }
                                //           },
                                //         ),
                                //         const SizedBox(height: 8),
                                //         // Clear Filters Button
                                //         Row(
                                //           children: [
                                //             const Spacer(),
                                //             TextButton.icon(
                                //               onPressed: () {
                                //                 setState(() {
                                //                   searchvalue = '';
                                //                   selectedRentalOwner = 'All';
                                //                   selectedBalanceFilter = 'All';
                                //                   currentPage = 0;
                                //                 });
                                //               },
                                //               icon: const Icon(Icons.clear,
                                //                   size: 16),
                                //               label:
                                //                   const Text('Clear Filters'),
                                //               style: TextButton.styleFrom(
                                //                 foregroundColor:
                                //                     Colors.grey[600],
                                //               ),
                                //             ),
                                //           ],
                                //         ),
                                //       ],
                                //     ),
                                //   ),
                                // Tab Row
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0E0E0),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildTabButton("Summary", 0),
                                        _buildTabButton("Details", 1),
                                        _buildTabButton("Delinquent Lease", 2),
                                      ],
                                    ),
                                  ),
                                ),
                                // Conditional Screens
                                if (_selectedIndex == 0)
                                  SummeryScreen(data, totaldata!),
                                if (_selectedIndex == 1)
                                  DetailScreen(dataa, dateProvider),
                                if (_selectedIndex == 2)
                                  DelinquentLease(delinquentdata!, totaldata!,
                                      dateProvider),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            //    _tabController.index = index;
            _selectedIndex = index;
          });
        },
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 0),
          decoration: BoxDecoration(
            color: isSelected ? blueColor : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  TableRow buildTableRows(
      String leftLabel,
      String leftValue,
      String centerLabel,
      String centerValue,
      String rightLabel,
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
                  centerLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                const SizedBox(height: 4.0), // Space between label and value
                Text(
                  centerValue,
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

  SummeryScreen(List<Summary> currentPageData, Rentcollection_model data) {
    // Debug: Print the original data order
    for (int i = 0; i < currentPageData.length; i++) {
    }

    // Apply sorting to ensure consistent order
    List<Summary> sortedData = _getSortedSummaryData(currentPageData);

    // Debug: Print the sorted data order
    for (int i = 0; i < sortedData.length; i++) {
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaders(),
            const SizedBox(height: 20),
            Container(
              child: Column(
                children: [
                  ...sortedData.asMap().entries.map((entry) {
                    int rowIndex = entry.key;
                    var item = entry.value;
                    bool isRowExpanded = expandedRowIndex == rowIndex;
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
                          // Row header
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (expandedRowIndex == rowIndex) {
                                          expandedRowIndex = null;
                                        } else {
                                          expandedRowIndex = rowIndex;
                                          nestedExpandedIndex = null;
                                        }
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 5),
                                      padding: !isRowExpanded
                                          ? const EdgeInsets.only(bottom: 10)
                                          : const EdgeInsets.only(top: 10),
                                      child: FaIcon(
                                        isRowExpanded
                                            ? FontAwesomeIcons.sortUp
                                            : FontAwesomeIcons.sortDown,
                                        size: 20,
                                        color: blueColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.rentalOwnerName ?? '-'} (${item.rentalOwnerCompany ?? '-'})',
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        ' ${formatCurrency(item.totalPending)}',
                                        style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 25),
                                ],
                              ),
                            ),
                          ),
                          if (isRowExpanded)
                            Container(
                                margin: const EdgeInsets.symmetric(vertical: 0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const SizedBox(width: 25),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Total Charged',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 4,
                                              ),
                                              Text(
                                                formatCurrency(item.totalCharged),
                                                style: TextStyle(
                                                  color: grey,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Collected %',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(
                                                height: 4,
                                              ),
                                              Text(
                                                '${item.collectedPercentage ?? '-'}',
                                                style: TextStyle(
                                                  color: grey,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                  ],
                                )),
                        ],
                      ),
                    );
                  }).toList(),
                  Container(
                    decoration: BoxDecoration(
                      color: (sortedData.length % 2 == 0)
                          ? blueColor.withOpacity(0.09)
                          : Colors.white,
                      border: Border.all(
                          color: const Color.fromRGBO(152, 162, 179, .5)),
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
                                // This Overall row can optionally be expandable too
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (expandedRowIndex ==
                                          sortedData.length) {
                                        expandedRowIndex = null;
                                      } else {
                                        expandedRowIndex = sortedData.length;
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 5),
                                    padding:
                                        expandedRowIndex != sortedData.length
                                            ? const EdgeInsets.only(bottom: 10)
                                            : const EdgeInsets.only(top: 10),
                                    child: FaIcon(
                                      expandedRowIndex == sortedData.length
                                          ? FontAwesomeIcons.sortUp
                                          : FontAwesomeIcons.sortDown,
                                      size: 20,
                                      color: blueColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Overall',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      formatCurrency(
                                          data.totalSummary?.totalPending),
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 25),
                              ],
                            ),
                          ),
                        ),
                        if (expandedRowIndex == sortedData.length)
                          Container(
                              alignment: Alignment.centerLeft,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 25),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Total Charged',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              formatCurrency(data.totalSummary?.totalCharged),
                                              style: TextStyle(
                                                color: grey,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Collected %',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Text(
                                              '${data.totalSummary?.averageCollectedPercentage ?? '-'}',
                                              style: TextStyle(
                                                color: grey,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 15,
                                  ),
                                ],
                              )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DetailScreen(List<Leases> currentPageData, DateProvider dateProvider) {
    // Apply filters first
    List<Leases> filteredData = currentPageData.where((lease) {
      // Search filter
      bool matchesSearch = searchvalue.isEmpty ||
          lease.rentalData?.rentalAdress
                  ?.toLowerCase()
                  .contains(searchvalue.toLowerCase()) ==
              true ||
          lease.rentalOwnerData?.rentalOwnerCompanyName
                  ?.toLowerCase()
                  .contains(searchvalue.toLowerCase()) ==
              true;

      // Rental owner filter
      bool matchesRentalOwner = selectedRentalOwner == null ||
          selectedRentalOwner == 'All' ||
          lease.rentalOwnerData?.rentalOwnerCompanyName == selectedRentalOwner;

      // Balance filter
      bool matchesBalance = selectedBalanceFilter == null ||
          selectedBalanceFilter == 'All' ||
          (selectedBalanceFilter == 'Has Balance' &&
              (lease.leaseData?.balance ?? 0.0) > 0) ||
          (selectedBalanceFilter == 'No Balance' &&
              (lease.leaseData?.balance ?? 0.0) == 0);

      return matchesSearch && matchesRentalOwner && matchesBalance;
    }).toList();

    // Apply sorting (default to reverse chronological order by start date)
    List<Leases> sortedData = List<Leases>.from(filteredData);
    if (sorting1) {
      sortedData.sort((a, b) {
        final aAddress = a.rentalData?.rentalAdress ?? '';
        final bAddress = b.rentalData?.rentalAdress ?? '';
        return ascending1
            ? aAddress.compareTo(bAddress)
            : bAddress.compareTo(aAddress);
      });
    } else if (sorting3) {
      sortedData.sort((a, b) {
        final aBalance = a.leaseData?.balance ?? 0.0;
        final bBalance = b.leaseData?.balance ?? 0.0;
        return ascending3
            ? aBalance.compareTo(bBalance)
            : bBalance.compareTo(aBalance);
      });
    }

    // Apply pagination
    int totalItems = sortedData.length;
    int startIndex = currentPage * itemsPerPage;
    int endIndex = (startIndex + itemsPerPage > totalItems)
        ? totalItems
        : startIndex + itemsPerPage;
    List<Leases> paginatedData = sortedData.sublist(startIndex, endIndex);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeadersDetails(),
            const SizedBox(height: 20),
            Container(
              child: Column(
                children: [
                  // Show empty state if no data after filtering
                  if (filteredData.isEmpty &&
                      (searchvalue.isNotEmpty ||
                          selectedRentalOwner != 'All' ||
                          selectedBalanceFilter != 'All'))
                    // Same search/filter empty state as the other reports.
                    kNoSearchResults(context),
                  ...paginatedData.asMap().entries.map((entry) {
                    int rowIndex = entry.key;
                    var item = entry.value;
                    bool isRowExpanded = expandedRowIndex == rowIndex;
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
                          // Row header
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  bool isSmallScreen =
                                      constraints.maxWidth < 500;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: <Widget>[
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (expandedRowIndex == rowIndex) {
                                              expandedRowIndex = null;
                                            } else {
                                              expandedRowIndex = rowIndex;
                                              nestedExpandedIndex = null;
                                            }
                                          });
                                        },
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(left: 5),
                                          padding: !isRowExpanded
                                              ? const EdgeInsets.only(
                                                  bottom: 10)
                                              : const EdgeInsets.only(top: 10),
                                          child: FaIcon(
                                            isRowExpanded
                                                ? FontAwesomeIcons.sortUp
                                                : FontAwesomeIcons.sortDown,
                                            size: 20,
                                            color: blueColor,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 2 : 3),
                                      Expanded(
                                        flex: isSmallScreen ? 4 : 3,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (expandedRowIndex ==
                                                  rowIndex) {
                                                expandedRowIndex = null;
                                              } else {
                                                expandedRowIndex = rowIndex;
                                              }
                                            });
                                          },
                                          child: Text(
                                            '${item.rentalData?.rentalAdress ?? '-'}',
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: isSmallScreen ? 12 : 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 4 : 8),
                                      Expanded(
                                        flex: isSmallScreen ? 3 : 2,
                                        child: Text(
                                          '${item.rentalOwnerData?.rentalOwnerCompanyName ?? '-'}',
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 4 : 8),
                                      Expanded(
                                        flex: isSmallScreen ? 2 : 2,
                                        child: Text(
                                          item.leaseData?.balance != null
                                              ? formatCurrency(item.leaseData!.balance)
                                              : '-',
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 10 : 16),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          if (isRowExpanded)
                            Container(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Move-in Date and Monthly Rent Row - Responsive
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      bool isSmallScreen =
                                          constraints.maxWidth < 400;
                                      if (isSmallScreen) {
                                        // Stack vertically on very small screens
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 25),
                                          child: Column(
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Move-in Date',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.leaseData?.startDate !=
                                                            null
                                                        ? dateProvider
                                                            .formatCurrentDate(
                                                                item.leaseData!
                                                                    .startDate!)
                                                        : 'N/A',
                                                    style: TextStyle(
                                                      color: grey,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Monthly Rent',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatCurrency(item.leaseData?.leaseAmount),
                                                    style: TextStyle(
                                                      color: grey,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        // Keep horizontal layout for larger screens
                                        return Row(
                                          children: [
                                            const SizedBox(width: 25),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Move-in Date',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.leaseData?.startDate !=
                                                            null
                                                        ? dateProvider
                                                            .formatCurrentDate(
                                                                item.leaseData!
                                                                    .startDate!)
                                                        : 'N/A',
                                                    style: TextStyle(
                                                      color: grey,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Monthly Rent',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    formatCurrency(item.leaseData?.leaseAmount),
                                                    style: TextStyle(
                                                      color: grey,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 20),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                  Divider(
                                      color: Colors.grey.withOpacity(0.3),
                                      thickness:
                                          1), // Add divider between sections
                                  const SizedBox(height: 8),

                                  // Balance Row
                                  Row(
                                    children: [
                                      const SizedBox(width: 25),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Note',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              (item.notes?.isNotEmpty == true &&
                                                      item.notes?.first.date !=
                                                          null &&
                                                      item.notes!.first.date!
                                                          .isNotEmpty)
                                                  ? '${item.notes!.first.date!}\n${item.notes!.first.content ?? '-'}'
                                                  : '-',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                  Divider(
                                      color: Colors.grey.withOpacity(0.3),
                                      thickness: 1),
                                  const SizedBox(height: 8),

                                  // Auto-Pay Section - Responsive
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 25),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auto-Pay',
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Display recurring cards if available
                                        if (item.recurringCards != null &&
                                            item.recurringCards!.isNotEmpty)
                                          ...item.recurringCards!.map((card) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: LayoutBuilder(
                                                builder:
                                                    (context, constraints) {
                                                  bool isSmallScreen =
                                                      constraints.maxWidth <
                                                          300;
                                                  if (isSmallScreen) {
                                                    // Stack vertically on very small screens
                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          card.date != null
                                                              ? dateProvider
                                                                  .formatCurrentDate(
                                                                      card.date!)
                                                              : '-',
                                                          style: TextStyle(
                                                            color: grey,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 2),
                                                        Text(
                                                          '${card.tenantName ?? '-'}',
                                                          style: TextStyle(
                                                            color: grey,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    // Keep horizontal layout for larger screens
                                                    return Row(
                                                      children: [
                                                        Text(
                                                          card.date != null
                                                              ? dateProvider
                                                                  .formatCurrentDate(
                                                                      card.date!)
                                                              : '-',
                                                          style: TextStyle(
                                                            color: grey,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 15),
                                                        Expanded(
                                                          child: Text(
                                                            '${card.tenantName ?? '-'}',
                                                            style: TextStyle(
                                                              color: grey,
                                                              fontSize: 13,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            maxLines: 1,
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                },
                                              ),
                                            );
                                          }).toList()
                                        else
                                          Text(
                                            '-', // fallback if no data
                                            style: TextStyle(
                                              color: grey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  // Pagination bar - matches app-standard table pagination
                  if (filteredData.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          int totalPages = (totalItems / itemsPerPage).ceil();
                          bool isSmallScreen = constraints.maxWidth < 400;
                          Widget recordsInfo = Text(
                            'Showing ${startIndex + 1}-${endIndex} of ${totalItems} records',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          );
                          Widget pageControls = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFDBE0E5)),
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: itemsPerPage,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: blueColor),
                                    items: itemsPerPageOptions.map((option) {
                                      return DropdownMenuItem(
                                        value: option,
                                        child: Text(option.toString()),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        itemsPerPage = value!;
                                        currentPage =
                                            0; // Reset to first page
                                      });
                                    },
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: FaIcon(
                                  FontAwesomeIcons.circleChevronLeft,
                                  color: currentPage > 0
                                      ? blueColor
                                      : Colors.grey,
                                ),
                                onPressed: currentPage > 0
                                    ? () {
                                        setState(() {
                                          currentPage--;
                                        });
                                      }
                                    : null,
                              ),
                              Text(
                                'Page ${currentPage + 1} of $totalPages',
                                style: TextStyle(
                                  color: totalPages > 1
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
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
                          );
                          if (isSmallScreen) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                recordsInfo,
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: pageControls,
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(child: recordsInfo),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: pageControls,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  DelinquentLease(List<DeadBeats> currentPageData, Rentcollection_model data,
      DateProvider dateProvider) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (currentPageData.isNotEmpty) _buildHeadersDetails(),
            if (currentPageData.isNotEmpty) const SizedBox(height: 20),
            if (currentPageData.isNotEmpty)
              Container(
                child: Column(
                  children: [
                    ...currentPageData.asMap().entries.map((entry) {
                      int rowIndex = entry.key;
                      var item = entry.value;
                      bool isRowExpanded = expandedRowIndex == rowIndex;
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
                            // Row header
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (expandedRowIndex == rowIndex) {
                                            expandedRowIndex = null;
                                          } else {
                                            expandedRowIndex = rowIndex;
                                            nestedExpandedIndex = null;
                                          }
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        padding: !isRowExpanded
                                            ? const EdgeInsets.only(bottom: 10)
                                            : const EdgeInsets.only(top: 10),
                                        child: FaIcon(
                                          isRowExpanded
                                              ? FontAwesomeIcons.sortUp
                                              : FontAwesomeIcons.sortDown,
                                          size: 20,
                                          color: blueColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 3,
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
                                        child: Text(
                                          '${item.rentalData?.rentalAdress ?? '-'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '${item.rentalOwnerData?.rentalOwnerCompanyName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item.leaseData?.balance != null
                                            ? formatCurrency(
                                                item.leaseData!.balance)
                                            : '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isRowExpanded)
                              Container(
                                child: Column(
                                  children: [
                                    // Move-in Date and Monthly Rent Row
                                    Row(
                                      children: [
                                        const SizedBox(width: 25),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Move-in Date',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.leaseData?.startDate ?? '-'}',
                                                style: TextStyle(
                                                  color: grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Monthly Rent',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formatCurrency(item.leaseData?.leaseAmount),
                                                style: TextStyle(
                                                  color: grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                    ),
                                    Divider(
                                        color: Colors.grey.withOpacity(0.3),
                                        thickness:
                                            1), // Add divider between sections
                                    const SizedBox(height: 8),

                                    // Balance Row
                                    Row(
                                      children: [
                                        const SizedBox(width: 25),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Balance',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                formatCurrency(
                                                    item.leaseData?.balance),
                                                style: TextStyle(
                                                  color: grey,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                    ),

                                    const SizedBox(height: 15),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    if (data.deadBeatsSummary?.totalBalance != null &&
                        data.deadBeatsSummary!.totalBalance != 0)
                      Container(
                        decoration: BoxDecoration(
                          color: (currentPageData.length % 2 == 0)
                              ? blueColor.withOpacity(0.09)
                              : Colors.white,
                          border: Border.all(
                              color: const Color.fromRGBO(152, 162, 179, .5)),
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
                                    // This Overall row can optionally be expandable too
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (expandedRowIndex ==
                                              currentPageData.length) {
                                            expandedRowIndex = null;
                                          } else {
                                            expandedRowIndex =
                                                currentPageData.length;
                                          }
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        padding: expandedRowIndex !=
                                                currentPageData.length
                                            ? const EdgeInsets.only(bottom: 10)
                                            : const EdgeInsets.only(top: 10),
                                        child: FaIcon(
                                          expandedRowIndex ==
                                                  currentPageData.length
                                              ? FontAwesomeIcons.sortUp
                                              : FontAwesomeIcons.sortDown,
                                          size: 20,
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Overall',
                                        style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const SizedBox(width: 30),
                                    Expanded(
                                      child: Text(
                                        formatCurrency(
                                            data.deadBeatsSummary?.totalBalance),
                                        style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    // SizedBox(width: 50),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (currentPageData.isEmpty)
              Container(
                height: MediaQuery.of(context).size.height * .5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        "assets/images/no_data_transparent.png",
                        height: 200,
                        width: 200,
                      ),
                      const SizedBox(height: 10),
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
      ),
    );
  }
}
