import 'package:flutter/material.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:three_zero_two_property/Model/PropertyInsuranceModel.dart';
import 'package:three_zero_two_property/repository/PropertyInsuranceRepo.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class PropertyInsuranceSummary extends StatefulWidget {
  @override
  _PropertyInsuranceSummaryState createState() =>
      _PropertyInsuranceSummaryState();
}

class _PropertyInsuranceSummaryState extends State<PropertyInsuranceSummary>
    with NetworkRetryState {
  List<PropertyInsuranceData> insuranceData = [];
  List<PropertyInsuranceData> filteredData = [];
  bool isDataLoading = false;
  String? searchQuery;
  String? selectedStatus;
  int? expandedRowIndex;

  String getInsuranceStatus(String? expirationDate) {
    if (expirationDate == null || expirationDate.isEmpty) return "Active";

    try {
      final today = DateTime.now();
      final expDate = DateTime.parse(expirationDate);
      final diffTime = expDate.difference(today);
      final diffDays = diffTime.inDays;

      if (diffDays <= 0) return "Expired";
      if (diffDays <= 14) return "Expiring Soon";
      if (diffDays <= 30) return "Renewal Due";
      return "Active";
    } catch (e) {
      return "Active";
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Active":
        return Colors.green[100]!;
      case "Expiring Soon":
        return Colors.orange[100]!;
      case "Renewal Due":
        return Colors.yellow[100]!;
      case "Expired":
        return Colors.red[100]!;
      default:
        return Colors.grey[100]!;
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case "Active":
        return Colors.green[800]!;
      case "Expiring Soon":
        return Colors.orange[800]!;
      case "Renewal Due":
        return Colors.yellow[800]!;
      case "Expired":
        return Colors.red[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadData();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isDataLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString('adminId');

      if (adminId != null) {
        PropertyInsuranceRepository repo = PropertyInsuranceRepository();
        PropertyInsuranceResponse response =
            await repo.fetchPropertyInsuranceSummary(adminId);
        if (response.success == true && response.data != null) {
          setState(() {
            insuranceData = response.data!;
            filteredData = List.from(insuranceData);
            isDataLoading = false;
          });
        } else {
          Fluttertoast.showToast(msg: 'Failed to load insurance data');
        }
      } else {
        Fluttertoast.showToast(msg: 'Admin ID not found');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error loading data: ${friendlyErrorMessage(e)}');
    } finally {
      setState(() {
        isDataLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      filteredData = insuranceData.where((insurance) {
        bool matchesSearch = searchQuery == null ||
            searchQuery!.isEmpty ||
            (insurance.insuranceCompanyName
                    ?.toLowerCase()
                    .contains(searchQuery!.toLowerCase()) ??
                false) ||
            (insurance.policyNumber
                    ?.toLowerCase()
                    .contains(searchQuery!.toLowerCase()) ??
                false) ||
            (insurance.propertyAddress
                    ?.toLowerCase()
                    .contains(searchQuery!.toLowerCase()) ??
                false);

        bool matchesStatus = selectedStatus == null ||
            selectedStatus!.isEmpty ||
            getInsuranceStatus(insurance.expirationDate) == selectedStatus;

        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Widget _buildHeaders() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text("Property Address",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[800])),
          ),
          Expanded(
            flex: 1,
            child: Text("Status",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(PropertyInsuranceData insurance, int index) {
    bool isExpanded = expandedRowIndex == index;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expandedRowIndex == index) {
                  expandedRowIndex = null;
                } else {
                  expandedRowIndex = index;
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Property Address with expand icon
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Text(
                          insurance.mailingAddress ?? 'N/A',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  // Status
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                            getInsuranceStatus(insurance.expirationDate)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        getInsuranceStatus(insurance.expirationDate),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getStatusTextColor(
                              getInsuranceStatus(insurance.expirationDate)),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  // Two column layout for main details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Company',
                                insurance.insuranceCompanyName ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Policy Number',
                                insurance.policyNumber ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Named Insured',
                                insurance.namedInsured ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Policy Type', insurance.policyType ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Effective Date',
                                insurance.effectiveDate != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(
                                            insurance.effectiveDate!))
                                    : 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Premium Amount',
                                insurance.premiumAmount != null
                                    ? formatMoney(insurance.premiumAmount)
                                    : 'N/A'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Payment Terms',
                                insurance.paymentTerms ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Expiration Date',
                                insurance.expirationDate != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(
                                            insurance.expirationDate!))
                                    : 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Deductible',
                                insurance.deductible != null
                                    ? formatMoney(insurance.deductible)
                                    : 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Agent Name', insurance.agentName ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Agent Phone', insurance.agentPhone ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Notes', insurance.notes ?? 'N/A'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.normal,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget filters() {
    return Container(
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by company, policy number, or address...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8A95A8)),
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'PDF' && filteredData.isNotEmpty) {
                          _exportToPDF();
                        } else if (value == 'XLSX' && filteredData.isNotEmpty) {
                          _exportToExcel();
                        } else if (value == 'CSV' && filteredData.isNotEmpty) {
                          _shareReport();
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download,
                              color: blueColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '',
                              style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'Expiring Soon', child: Text('Expiring Soon')),
                    DropdownMenuItem(
                        value: 'Renewal Due', child: Text('Renewal Due')),
                    DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportToPDF() async {
    try {
      setState(() {
        isDataLoading = true;
      });

      final pdf = pw.Document();

      // Add logo
      final image = await rootBundle.load('assets/images/newlogo.png');
      final imageBytes = image.buffer.asUint8List();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          header: (pw.Context context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(pw.MemoryImage(imageBytes), width: 50, height: 50),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Property Insurance Summary Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Generated on: ${DateFormat('yyyy-MMM-dd').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('keybrainstech', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('gg', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          build: (pw.Context context) {
            return [
              pw.SizedBox(height: 20),
              pw.Table(
                border: null,
                columnWidths: {
                  0: pw.FlexColumnWidth(1.5), // Company
                  1: pw.FlexColumnWidth(1.5), // Policy Number
                  2: pw.FlexColumnWidth(1.3), // Property Address
                  3: pw.FlexColumnWidth(1.3), // Status
                  4: pw.FlexColumnWidth(1.3), // Named Insured
                  5: pw.FlexColumnWidth(1.1), // Effective Date
                  6: pw.FlexColumnWidth(1.1), // Expiration Date
                  7: pw.FlexColumnWidth(1.3), // Premium
                  8: pw.FlexColumnWidth(1.0), // Payment Terms
                },
                children: [
                  // Header row with blue background
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex("#5A86D5")),
                    children: [
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Location',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Policy Number',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Insurer',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Coverage Type',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Coverage Amount',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Deductible',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Premium',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Expiration Date',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('Status',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                    ],
                  ),
                  // Data rows
                  ...filteredData.map((insurance) => pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(insurance.mailingAddress ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(insurance.policyNumber ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  insurance.insuranceCompanyName ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(insurance.policyType ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  insurance.premiumAmount != null
                                      ? '${formatCurrency(insurance.premiumAmount)}'
                                      : 'N/A',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  insurance.deductible != null
                                      ? '${formatCurrency(insurance.deductible)}'
                                      : '-',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  insurance.premiumAmount != null
                                      ? '${formatCurrency(insurance.premiumAmount)}'
                                      : 'N/A',
                                  style: pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  insurance.expirationDate != null
                                      ? DateFormat('yyyy-MM-dd').format(
                                          DateTime.parse(
                                              insurance.expirationDate!))
                                      : 'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(8),
                              child: pw.Text(
                                  getInsuranceStatus(
                                          insurance.expirationDate) ??
                                      'N/A',
                                  style: pw.TextStyle(fontSize: 10))),
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
          bytes: await pdf.save(), filename: 'Property-Insurance-Summary-Report.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'Property-Insurance-Summary-Report',
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }

      setState(() {
        isDataLoading = false;
      });

      Fluttertoast.showToast(msg: 'PDF exported successfully');
    } catch (e) {
      setState(() {
        isDataLoading = false;
      });
      Fluttertoast.showToast(msg: 'Error exporting PDF: ${friendlyErrorMessage(e)}');
    }
  }

  void _exportToExcel() async {
    try {
      setState(() {
        isDataLoading = true;
      });

      // Create Excel workbook
      final xls.Workbook workbook = xls.Workbook();
      final xls.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Property Insurance Summary';

      // Add headers
      List<String> headers = [
        'Company',
        'Policy Number',
        'Property Address',
        'Status',
        'Named Insured',
        'Policy Type',
        'Effective Date',
        'Expiration Date',
        'Premium Amount',
        'Payment Terms',
        'Deductible',
        'Agent Name',
        'Agent Phone',
        'Notes'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
      }

      // Add data
      for (int i = 0; i < filteredData.length; i++) {
        final insurance = filteredData[i];
        int row = i + 2;

        sheet
            .getRangeByIndex(row, 1)
            .setText(insurance.insuranceCompanyName ?? '');
        sheet.getRangeByIndex(row, 2).setText(insurance.policyNumber ?? '');
        sheet.getRangeByIndex(row, 3).setText(insurance.propertyAddress ?? '');
        sheet
            .getRangeByIndex(row, 4)
            .setText(getInsuranceStatus(insurance.expirationDate));
        sheet.getRangeByIndex(row, 5).setText(insurance.namedInsured ?? '');
        sheet.getRangeByIndex(row, 6).setText(insurance.policyType ?? '');
        sheet.getRangeByIndex(row, 7).setText(insurance.effectiveDate ?? '');
        sheet.getRangeByIndex(row, 8).setText(insurance.expirationDate ?? '');
        sheet
            .getRangeByIndex(row, 9)
            .setText(insurance.premiumAmount?.toString() ?? '');
        sheet.getRangeByIndex(row, 10).setText(insurance.paymentTerms ?? '');
        sheet
            .getRangeByIndex(row, 11)
            .setText(insurance.deductible?.toString() ?? '');
        sheet.getRangeByIndex(row, 12).setText(insurance.agentName ?? '');
        sheet.getRangeByIndex(row, 13).setText(insurance.agentPhone ?? '');
        sheet.getRangeByIndex(row, 14).setText(insurance.notes ?? '');
      }

      // Auto-fit columns
      for (int i = 1; i <= headers.length; i++) {
        sheet.autoFitColumn(i);
      }

      // Save file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
          '${directory.path}/Property_Insurance_Summary_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);

      setState(() {
        isDataLoading = false;
      });

      Fluttertoast.showToast(msg: 'Excel file exported successfully');
    } catch (e) {
      setState(() {
        isDataLoading = false;
      });
      Fluttertoast.showToast(msg: 'Error exporting Excel: ${friendlyErrorMessage(e)}');
    }
  }

  void _shareReport() async {
    try {
      setState(() {
        isDataLoading = true;
      });

      // Create CSV content
      StringBuffer csv = StringBuffer();
      csv.writeln(
          'Company,Policy Number,Property Address,Status,Named Insured,Policy Type,Effective Date,Expiration Date,Premium Amount,Payment Terms,Deductible,Agent Name,Agent Phone,Notes');

      for (final insurance in filteredData) {
        // Quoted like web's CSV, so addresses, amounts and notes with commas
        // stay in their column.
        csv.writeln(csvRow([
          insurance.insuranceCompanyName ?? '',
          insurance.policyNumber ?? '',
          insurance.propertyAddress ?? '',
          getInsuranceStatus(insurance.expirationDate),
          insurance.namedInsured ?? '',
          insurance.policyType ?? '',
          insurance.effectiveDate ?? '',
          insurance.expirationDate ?? '',
          insurance.premiumAmount ?? '',
          insurance.paymentTerms ?? '',
          insurance.deductible ?? '',
          insurance.agentName ?? '',
          insurance.agentPhone ?? '',
          insurance.notes ?? '',
        ]));
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/Property_Insurance_Summary_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv.toString());

      // Share the file
      await Share.shareXFiles([XFile(file.path)],
          text: 'Property Insurance Summary Report');

      setState(() {
        isDataLoading = false;
      });

      Fluttertoast.showToast(msg: 'Report shared successfully');
    } catch (e) {
      setState(() {
        isDataLoading = false;
      });
      Fluttertoast.showToast(msg: 'Error sharing report: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: CustomDrawer(
        currentpage: "Reports",
        dropdown: false,
      ),
      appBar: widget_302.App_Bar(context: context),
      // This screen had no offline state at all; a failed request used to
      // leave it blank or showing an error string with no way to retry.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : Column(
        children: [
          titleBar(
            title: 'Property Insurance Summary Report',
            width: MediaQuery.of(context).size.width * .95,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  filters(),
                  const SizedBox(height: 10),
                  _buildHeaders(),
                  const SizedBox(height: 10),
                  if (isDataLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: blueColor,
                      ),
                    )
                  else if (filteredData.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          SizedBox(height: 50),
                          Icon(
                            Icons.security,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No insurance data found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: filteredData
                          .asMap()
                          .entries
                          .map((entry) => _buildDataRow(entry.value, entry.key))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
