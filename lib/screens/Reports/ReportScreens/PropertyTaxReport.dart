import 'package:flutter/material.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:intl/intl.dart';

class PropertyTaxReport extends StatefulWidget {
  @override
  _PropertyTaxReportState createState() => _PropertyTaxReportState();
}

class _PropertyTaxReportState extends State<PropertyTaxReport>
    with NetworkRetryState {
  List<Map<String, dynamic>> taxData = [];
  List<Map<String, dynamic>> filteredData = [];
  bool isDataLoading = false;
  String? selectedYear;
  Map<String, dynamic>? summaryData;
  int? expandedRowIndex;

  // Generate year options (current year ± 5 years)
  List<String> get yearOptions {
    int currentYear = DateTime.now().year;
    List<String> years = [];
    for (int i = currentYear - 5; i <= currentYear + 5; i++) {
      years.add(i.toString());
    }
    return years;
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
    selectedYear = DateTime.now().year.toString();
    _loadData();
  }

  Future<void> _loadData() async {
    if (selectedYear == null) return;

    setState(() {
      isDataLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString('adminId');
      String? token = prefs.getString('token');

      if (adminId != null && token != null) {
        final response = await apiGet(
          Uri.parse('${Api_url}/api/taxes/report/$adminId/$selectedYear'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $adminId",
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            setState(() {
              taxData = List<Map<String, dynamic>>.from(data['data'] ?? []);
              filteredData = List.from(taxData);
              summaryData = data['summary'];
              isDataLoading = false;
            });
          } else {
            Fluttertoast.showToast(msg: 'Failed to load tax data');
            setState(() {
              isDataLoading = false;
            });
          }
        } else {
          Fluttertoast.showToast(msg: 'Failed to load tax data');
          setState(() {
            isDataLoading = false;
          });
        }
      } else {
        Fluttertoast.showToast(msg: 'Admin ID not found');
        setState(() {
          isDataLoading = false;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Error loading data: ${friendlyErrorMessage(e)}');
      setState(() {
        isDataLoading = false;
      });
    }
  }

  Widget _buildStatusBadge(Map<String, dynamic> property) {
    List<dynamic> taxes = property['taxes'] ?? [];

    if (taxes.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          'NO TAXES',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Determine overall status based on tax statuses
    bool hasPaid = taxes.any((tax) => tax['status']?.toLowerCase() == 'paid');
    bool hasPending =
        taxes.any((tax) => tax['status']?.toLowerCase() == 'pending');
    bool hasOverdue =
        taxes.any((tax) => tax['status']?.toLowerCase() == 'overdue');
    bool hasUnpaid =
        taxes.any((tax) => tax['status']?.toLowerCase() == 'unpaid');

    String status;
    Color statusColor;

    if (hasOverdue) {
      status = 'OVERDUE';
      statusColor = Colors.red;
    } else if (hasUnpaid) {
      status = 'UNPAID';
      statusColor = Colors.grey;
    } else if (hasPending) {
      status = 'PENDING';
      statusColor = Colors.orange;
    } else if (hasPaid) {
      status = 'PAID';
      statusColor = Colors.green;
    } else {
      status = 'UNKNOWN';
      statusColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
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

  Widget _buildDataRow(Map<String, dynamic> property, int index) {
    bool isExpanded = expandedRowIndex == index;
    List<dynamic> taxes = property['taxes'] ?? [];

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
                          property['address'] ?? 'N/A',
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
                  // Status column
                  Expanded(
                    flex: 1,
                    child: _buildStatusBadge(property),
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
                  // Tax details table - showing only fields from reference image
                  if (taxes.isEmpty)
                    _buildNoTaxDetails(property)
                  else
                    _buildTaxDetailsTable(taxes),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaxDetail(Map<String, dynamic> tax) {
    String status = tax['status'] ?? 'Unknown';
    Color statusColor;

    switch (status.toLowerCase()) {
      case 'paid':
        statusColor = Colors.green;
        break;
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'overdue':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tax Authority
          Text(
            'Tax Authority',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 4),
          Text(
            tax['taxAuthority'] ?? 'N/A',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),

          // Tax Amount and Assessment Value in a row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Amount',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      formatMoney(tax['taxAmount']?.toString() ?? '0.00'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: blueColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assessment Value',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      formatMoney(tax['assessmentValue']?.toString() ?? '0.00'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Due Date and Paid Date in a row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Due Date',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tax['dueDate'] != null
                          ? DateFormat('MM/dd/yyyy')
                              .format(DateTime.parse(tax['dueDate']))
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paid Date',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tax['paidDate'] != null
                          ? DateFormat('MM/dd/yyyy')
                              .format(DateTime.parse(tax['paidDate']))
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          // Status and Notes in a row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      tax['notes'] ?? 'No notes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

  Widget _buildNoTaxDetails(Map<String, dynamic> property) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tax Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow('Total Tax Amount',
                    formatMoney(property['totalTaxAmount']?.toString() ?? '0.00')),
              ),
              Expanded(
                child: _buildDetailRow('Total Assessment Value',
                    formatMoney(property['totalAssessmentValue']?.toString() ?? '0.00')),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                    'Tax Count', property['taxCount']?.toString() ?? '0'),
              ),
              Expanded(
                child: _buildDetailRow('Status', 'No taxes recorded'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxDetailsTable(List<dynamic> taxes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tax Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: blueColor,
          ),
        ),
        SizedBox(height: 12),
        ...taxes.map((tax) => _buildTaxDetail(tax)).toList(),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      decoration: BoxDecoration(
        // color: Colors.white,
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
          // First Row: Tax Year
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Year',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration: InputDecoration(
                          hintText: 'Select year',
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: yearOptions.map((year) {
                          return DropdownMenuItem<String>(
                            value: year,
                            child: Text(year),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedYear = value;
                          });
                          _loadData();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Second Row: Run and Export Buttons
          Row(
            children: [
              // Run Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Data refreshed successfully'),
                        backgroundColor: blueColor,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Run',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              // Export Button
              // Greyed out and not tappable until the report has rows.
              Expanded(
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8A95A8)),
                    ),
                    child: PopupMenuButton<String>(
                      enabled: filteredData.isNotEmpty,
                      onSelected: (value) async {
                        if (value == 'PDF' && filteredData.isNotEmpty) {
                          _exportToPDF();
                        } else if (value == 'XLSX' && filteredData.isNotEmpty) {
                          _exportToExcel();
                        } else if (value == 'CSV' && filteredData.isNotEmpty) {
                          _shareReport();
                        } else if (filteredData.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No data to export'),
                              backgroundColor: Colors.orange,
                            ),
                          );
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Export',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: filteredData.isNotEmpty
                                    ? Colors.grey[800]
                                    : Colors.grey.shade400,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: filteredData.isNotEmpty
                                  ? Colors.grey[600]
                                  : Colors.grey.shade400,
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

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          header: (pw.Context context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Property Tax Report - $selectedYear',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Generated: ${DateTime.now().toString().split(' ')[0]}',
                style: pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
          build: (pw.Context context) => [
            pw.Text(
              'Property Tax Details',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(2),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
                4: pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Property Address',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('City, State',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Tax Amount',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Assessment',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(8),
                      child: pw.Text('Status',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...filteredData.map((property) {
                  List<dynamic> taxes = property['taxes'] ?? [];
                  if (taxes.isEmpty) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(property['address'] ?? 'N/A'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                              '${property['city'] ?? 'N/A'}, ${property['state'] ?? 'N/A'}'),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                              formatMoney(property['totalTaxAmount']?.toString() ?? '0')),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text(
                              formatMoney(property['totalAssessmentValue']?.toString() ?? '0')),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(8),
                          child: pw.Text('No Taxes'),
                        ),
                      ],
                    );
                  }

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(property['address'] ?? 'N/A'),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                            '${property['city'] ?? 'N/A'}, ${property['state'] ?? 'N/A'}'),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                            formatMoney(property['totalTaxAmount']?.toString() ?? '0')),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                            formatMoney(property['totalAssessmentValue']?.toString() ?? '0')),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text('Multiple Taxes'),
                      ),
                    ],
                  );
                }).toList(),
              ],
            ),
          ],
        ),
      );

      // Save and share PDF
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/Property_Tax_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (Platform.isAndroid) {
        if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Property_Tax_Report.pdf');
    } else {
      await Printing.layoutPdf(
          name: 'Property_Tax_Report',
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
    }
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Property Tax Report - $selectedYear',
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

      final xlsio.Workbook workbook = xlsio.Workbook();
      final xlsio.Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Property Tax Report';

      // Add headers
      List<String> headers = [
        'Property Address',
        'City',
        'State',
        'Tax Amount',
        'Assessment Value',
        'Status',
        'Tax Authority',
        'Notes',
        'Due Date',
        'Paid Date'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
      }

      // Add data
      int row = 2;
      for (final property in filteredData) {
        List<dynamic> taxes = property['taxes'] ?? [];
        if (taxes.isEmpty) {
          sheet.getRangeByIndex(row, 1).setText(property['address'] ?? '');
          sheet.getRangeByIndex(row, 2).setText(property['city'] ?? '');
          sheet.getRangeByIndex(row, 3).setText(property['state'] ?? '');
          sheet
              .getRangeByIndex(row, 4)
              .setText(property['totalTaxAmount']?.toString() ?? '0');
          sheet
              .getRangeByIndex(row, 5)
              .setText(property['totalAssessmentValue']?.toString() ?? '0');
          sheet.getRangeByIndex(row, 6).setText('No Taxes');
          row++;
        } else {
          for (final tax in taxes) {
            sheet.getRangeByIndex(row, 1).setText(property['address'] ?? '');
            sheet.getRangeByIndex(row, 2).setText(property['city'] ?? '');
            sheet.getRangeByIndex(row, 3).setText(property['state'] ?? '');
            sheet
                .getRangeByIndex(row, 4)
                .setText(tax['taxAmount']?.toString() ?? '0');
            sheet
                .getRangeByIndex(row, 5)
                .setText(tax['assessmentValue']?.toString() ?? '0');
            sheet.getRangeByIndex(row, 6).setText(tax['status'] ?? '');
            sheet.getRangeByIndex(row, 7).setText(tax['taxAuthority'] ?? '');
            sheet.getRangeByIndex(row, 8).setText(tax['notes'] ?? '');
            sheet.getRangeByIndex(row, 9).setText(tax['dueDate'] ?? '');
            sheet.getRangeByIndex(row, 10).setText(tax['paidDate'] ?? '');
            row++;
          }
        }
      }

      // Auto-fit columns
      for (int i = 1; i <= headers.length; i++) {
        sheet.autoFitColumn(i);
      }

      // Save file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/Property_Tax_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Property Tax Report - $selectedYear',
      );

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

      final StringBuffer csv = StringBuffer();
      csv.writeln(
          'Property Address,City,State,Tax Amount,Assessment Value,Status,Tax Authority,Notes,Due Date,Paid Date');

      for (final property in filteredData) {
        List<dynamic> taxes = property['taxes'] ?? [];
        if (taxes.isEmpty) {
          // Quoted like web's CSV, so values with commas stay in their
          // column.
          csv.writeln(csvRow([
            property['address'] ?? '',
            property['city'] ?? '',
            property['state'] ?? '',
            property['totalTaxAmount']?.toString() ?? '0',
            property['totalAssessmentValue']?.toString() ?? '0',
            'No Taxes',
            '',
            '',
            '',
            '',
          ]));
        } else {
          for (final tax in taxes) {
            csv.writeln(csvRow([
              property['address'] ?? '',
              property['city'] ?? '',
              property['state'] ?? '',
              tax['taxAmount']?.toString() ?? '0',
              tax['assessmentValue']?.toString() ?? '0',
              tax['status'] ?? '',
              tax['taxAuthority'] ?? '',
              tax['notes'] ?? '',
              tax['dueDate'] ?? '',
              tax['paidDate'] ?? '',
            ]));
          }
        }
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/Property_Tax_Report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsBytes(csv.toString().codeUnits);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Property Tax Report - $selectedYear',
      );

      setState(() {
        isDataLoading = false;
      });

      Fluttertoast.showToast(msg: 'CSV file exported successfully');
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
            title: 'Property Tax Report',
            width: MediaQuery.of(context).size.width * .95,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(),
                  const SizedBox(height: 16),
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
                            Icons.receipt_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No tax data found for $selectedYear',
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
                      children: [
                        _buildHeaders(),
                        SizedBox(height: 10),
                        ...filteredData
                            .asMap()
                            .entries
                            .map((entry) =>
                                _buildDataRow(entry.value, entry.key))
                            .toList(),
                      ],
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
