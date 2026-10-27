import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:three_zero_two_property/Model/LivePropertyModel.dart';
import 'package:three_zero_two_property/repository/LivePropertyRepo.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:io';
import 'dart:convert';

class LivePropertyReport extends StatefulWidget {
  @override
  _LivePropertyReportState createState() => _LivePropertyReportState();
}

class _LivePropertyReportState extends State<LivePropertyReport>
    with NetworkRetryState {
  List<LivePropertyData> propertyData = [];
  List<LivePropertyData> filteredData = [];
  bool isDataLoading = false;
  String? searchQuery;
  String? selectedStatus;
  String? selectedCity;
  String? selectedState;
  int? expandedRowIndex;

  // New filter variables
  String? selectedTaxBillYear;
  String? selectedInsuredValueYear;
  DateTime? fromDate;
  DateTime? toDate;
  List<String> taxYears = [];
  List<String> insuredYears = [];

  String formatCurrency(dynamic value) {
    if (value == null) return '\$0.00';
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(value);
  }

  // Fetch tax years from dedicated API endpoint
  Future<void> _fetchTaxYears() async {
    try {
      // TODO: Implement actual API call
      // API Endpoint: GET /taxes/years
      // Example implementation:
      List<int> apiYears = [];
      final response = await apiGet(Uri.parse('${Api_url}/api/taxes/years'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          apiYears = List<int>.from(data['years'] ?? []);
          // Process the years...
        }
      }

      // For now, simulating API call with the data you provided

      // Filter out invalid years (like 222) and convert to strings

      // Remove duplicates and sort descending
      apiYears = apiYears.toSet().toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        taxYears = apiYears.map((year) => year.toString()).toList();
      });

    } catch (e) {
      logError('Error fetching tax years: $e');
      setState(() {
        taxYears = [DateTime.now().year.toString()];
      });
    }
  }

  // Get tax years for dropdown
  List<String> get taxBillYearOptions {
    return taxYears.isNotEmpty ? taxYears : [DateTime.now().year.toString()];
  }

  // Fetch insured years from dedicated API endpoint
  Future<void> _fetchInsuredYears() async {
    try {
      // TODO: Implement actual API call
      // API Endpoint: GET /rentals/insured-years/{adminId}
      // Example implementation:
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString('adminId');
      String? token = prefs.getString('token');
      List<int> apiYears = [];
      final response = await apiGet(
          Uri.parse('${Api_url}/api/rentals/insured-years/$adminId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $adminId",
          });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          apiYears = List<int>.from(data['years'] ?? []);
          // Process the years...
        }
      }

      // For now, simulating API call with the data you provided
      // Replace this with actual API call
      // List<int> apiYears = [
      //   2025,
      //   2024,
      //   2023,
      //   2018,
      //   1979,
      //   1975,
      //   222
      // ]; // Including invalid data to test filtering

      // // Filter out invalid years (like 222) and convert to strings
      // List<String> validYears = apiYears
      //     .where((year) => year >= 1900 && year <= DateTime.now().year + 5)
      //     .map((year) => year.toString())
      //     .toList();

      // Remove duplicates and sort descending
      apiYears = apiYears.toSet().toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        insuredYears = apiYears.map((year) => year.toString()).toList();
      });

    } catch (e) {
      logError('Error fetching insured years: $e');
      setState(() {
        insuredYears = [DateTime.now().year.toString()];
      });
    }
  }

  // Get insured years for dropdown
  List<String> get insuredValueYearOptions {
    return insuredYears.isNotEmpty
        ? insuredYears
        : [DateTime.now().year.toString()];
  }

  Future<void> _selectFromDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != fromDate) {
      setState(() {
        fromDate = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _selectToDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: fromDate ?? DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != toDate) {
      setState(() {
        toDate = picked;
      });
      _applyFilters();
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
        LivePropertyRepository repo = LivePropertyRepository();
        LivePropertyResponse response =
            await repo.fetchLivePropertyReport(adminId);

        if (response.statusCode == 200 && response.data != null) {
          setState(() {
            propertyData = response.data!;
            filteredData = List.from(propertyData);
            isDataLoading = false;
          });
          // Reset filter selections when new data is loaded
          selectedTaxBillYear = null;
          selectedInsuredValueYear = null;

          // Fetch years from dedicated API endpoints
          await _fetchTaxYears();
          await _fetchInsuredYears();
        } else {
          Fluttertoast.showToast(msg: 'Failed to load property data');
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

  void _applyFilters() {
    setState(() {
      filteredData = propertyData.where((property) {
        bool matchesSearch = searchQuery == null ||
            searchQuery!.isEmpty ||
            (property.property?.address
                    ?.toLowerCase()
                    .contains(searchQuery!.toLowerCase()) ??
                false) ||
            (property.property?.city
                    ?.toLowerCase()
                    .contains(searchQuery!.toLowerCase()) ??
                false) ||
            (property.rentalOwner?.name
                    ?.toLowerCase()
                    .contains(searchQuery!.toLowerCase()) ??
                false);

        bool matchesStatus = selectedStatus == null ||
            selectedStatus!.isEmpty ||
            property.status == selectedStatus;

        bool matchesCity = selectedCity == null ||
            selectedCity!.isEmpty ||
            property.property?.city == selectedCity;

        bool matchesState = selectedState == null ||
            selectedState!.isEmpty ||
            property.property?.state == selectedState;

        // New filter criteria
        bool matchesTaxBillYear = selectedTaxBillYear == null ||
            selectedTaxBillYear!.isEmpty ||
            property.insuredYear?.toString() == selectedTaxBillYear;

        bool matchesInsuredValueYear = selectedInsuredValueYear == null ||
            selectedInsuredValueYear!.isEmpty ||
            property.insuredYear?.toString() == selectedInsuredValueYear;

        bool matchesDateRange = true;
        if (fromDate != null &&
            toDate != null &&
            property.lastUpdateDate != null) {
          try {
            DateTime propertyDate = DateTime.parse(property.lastUpdateDate!);
            matchesDateRange =
                propertyDate.isAfter(fromDate!.subtract(Duration(days: 1))) &&
                    propertyDate.isBefore(toDate!.add(Duration(days: 1)));
          } catch (e) {
            matchesDateRange = true;
          }
        }

        return matchesSearch &&
            matchesStatus &&
            matchesCity &&
            matchesState &&
            matchesTaxBillYear &&
            matchesInsuredValueYear &&
            matchesDateRange;
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
            child: Text("Property Address",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(LivePropertyData property, int index) {
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
                    child: Row(
                      children: [
                        Text(
                          property.property?.address ?? 'N/A',
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
                            _buildDetailRow('Property Address',
                                property.property?.address ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'City', property.property?.city ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'State', property.property?.state ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Zipcode', property.property?.zipcode ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Subdivision',
                                property.property?.subdivision ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Rental Owner',
                                property.rentalOwner?.name ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Parcel Number',
                                property.purchaseInfo?.parcelNumber ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Purchase Price',
                                formatCurrency(
                                    property.purchaseInfo?.purchasePrice)),
                            SizedBox(height: 12),
                            _buildDetailRow('Placed in Service',
                                property.placedInService ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Insured Year',
                                property.insuredYear?.toString() ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Insured Value',
                                formatCurrency(property.insuredValue)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('Monthly Rent',
                                formatCurrency(property.monthlyRent)),
                            SizedBox(height: 12),
                            _buildDetailRow('2025 Tax Bill',
                                formatCurrency(property.taxBill)),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Update Date',
                                property.lastUpdateDate != null
                                    ? DateFormat('yyyy-MM-dd').format(
                                        DateTime.parse(
                                            property.lastUpdateDate!))
                                    : 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Mortgaged',
                                property.hasMortgage == true ? 'Yes' : 'No'),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Bank Name', property.bankName ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Mortgage Number',
                                property.mortgageNumber ?? 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Remaining Balance',
                                formatCurrency(property.remainingBalance)),
                            SizedBox(height: 12),
                            _buildDetailRow('Principal',
                                formatCurrency(property.principal)),
                            SizedBox(height: 12),
                            _buildDetailRow('Monthly Payment',
                                formatCurrency(property.monthlyPayment)),
                            SizedBox(height: 12),
                            _buildDetailRow(
                                'Interest Percentage',
                                property.interestPercentage != null
                                    ? '${property.interestPercentage}%'
                                    : 'N/A'),
                            SizedBox(height: 12),
                            _buildDetailRow('Status', property.status ?? 'N/A'),
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
      padding: EdgeInsets.all(16),
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
          // First Row: Tax Bill Year and Insured Value Year
          Row(
            children: [
              // Tax Bill Year
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Bill Year',
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
                        value: selectedTaxBillYear,
                        decoration: InputDecoration(
                          hintText: 'Select year',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Select year'),
                          ),
                          ...taxBillYearOptions.map((year) {
                            return DropdownMenuItem<String>(
                              value: year,
                              child: Text(year),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedTaxBillYear = value;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 16),

              // Insured Value Year
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insured Value Year',
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
                        value: selectedInsuredValueYear,
                        decoration: InputDecoration(
                          hintText: 'Select year',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Select year'),
                          ),
                          ...insuredValueYearOptions.map((year) {
                            return DropdownMenuItem<String>(
                              value: year,
                              child: Text(year),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedInsuredValueYear = value;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Second Row: From and To Date
          Row(
            children: [
              // From Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _selectFromDate(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                fromDate != null
                                    ? DateFormat('yyyy-MMM-dd')
                                        .format(fromDate!)
                                    : '2025-Oct-01',
                                style: TextStyle(
                                  color: fromDate != null
                                      ? Colors.black
                                      : Colors.grey[500],
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: 16),

              // To Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _selectToDate(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                toDate != null
                                    ? DateFormat('yyyy-MMM-dd').format(toDate!)
                                    : '2025-Oct-31',
                                style: TextStyle(
                                  color: toDate != null
                                      ? Colors.black
                                      : Colors.grey[500],
                                ),
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Third Row: Run and Export Buttons
          Row(
            children: [
              // Run Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Filters applied successfully'),
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

              // Export Button — greyed out and not tappable until the report
              // has rows.
              Expanded(
                child: ElevatedButton(
                  onPressed: filteredData.isEmpty
                      ? null
                      : () {
                    if (filteredData.isNotEmpty) {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => Container(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Export Options',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                ),
                              ),
                              SizedBox(height: 16),
                              ListTile(
                                leading: Icon(Icons.picture_as_pdf,
                                    color: blueColor),
                                title: Text('Export as PDF'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _exportToPDF();
                                },
                              ),
                              ListTile(
                                leading:
                                    Icon(Icons.table_chart, color: blueColor),
                                title: Text('Export as Excel'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _exportToExcel();
                                },
                              ),
                              ListTile(
                                leading:
                                    Icon(Icons.description, color: blueColor),
                                title: Text('Export as CSV'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _shareReport();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No data to export'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                    disabledBackgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Export',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                      ),
                    ],
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

      // Add logo
      final image = await rootBundle.load('assets/images/newlogo.png');
      final imageBytes = image.buffer.asUint8List();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a3.landscape,
          header: (pw.Context context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Image(pw.MemoryImage(imageBytes), width: 50, height: 50),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Live Property Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Monthly rent as of ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('keybrainstech', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('99', style: pw.TextStyle(fontSize: 12)),
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
                  0: pw.FlexColumnWidth(1.2), // Property
                  1: pw.FlexColumnWidth(0.8), // City
                  2: pw.FlexColumnWidth(0.8), // State
                  3: pw.FlexColumnWidth(0.8), // Zipcode
                  4: pw.FlexColumnWidth(1.0), // Subdivision
                  5: pw.FlexColumnWidth(1.2), // Rental Owner
                  6: pw.FlexColumnWidth(0.8), // Parcel #
                  7: pw.FlexColumnWidth(1.0), // Purchase Price
                  8: pw.FlexColumnWidth(1.0), // Placed in Service
                  9: pw.FlexColumnWidth(0.8), // Insured Year
                  10: pw.FlexColumnWidth(1.0), // Insured Value
                  11: pw.FlexColumnWidth(1.0), // Monthly Rent
                  12: pw.FlexColumnWidth(1.0), // Tax Bill
                  13: pw.FlexColumnWidth(1.0), // Update Date
                  14: pw.FlexColumnWidth(0.8), // Mortgaged
                  15: pw.FlexColumnWidth(1.0), // Bank
                  16: pw.FlexColumnWidth(1.0), // Mortgage #
                  17: pw.FlexColumnWidth(1.0), // Balance
                  18: pw.FlexColumnWidth(1.0), // Principal
                  19: pw.FlexColumnWidth(1.0), // Payment
                  20: pw.FlexColumnWidth(0.8), // Interest %
                  21: pw.FlexColumnWidth(0.8), // Type
                },
                children: [
                  // Header row with blue background
                  pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex("#5A86D5")),
                    children: [
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Property',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('City',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('State',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Zipcode',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Subdivision',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Rental Owner',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Parcel #',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Purchase Price',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Placed in Service',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Insured Year',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Insured Value',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Monthly Rent',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('2025 Tax Bill',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Update Date',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Mortgaged',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Bank',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Mortgage #',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Balance',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Principal',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Payment',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Interest %',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                      pw.Padding(
                          padding: pw.EdgeInsets.all(4),
                          child: pw.Text('Type',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white))),
                    ],
                  ),
                  // Data rows
                  ...filteredData.map((property) => pw.TableRow(
                        children: [
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.property?.address ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(property.property?.city ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(property.property?.state ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.property?.zipcode ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.property?.subdivision ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.rentalOwner?.name ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.purchaseInfo?.parcelNumber ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  formatCurrency(
                                      property.purchaseInfo?.purchasePrice),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(property.placedInService ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.insuredYear?.toString() ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  formatCurrency(property.insuredValue),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  formatCurrency(property.monthlyRent),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(formatCurrency(property.taxBill),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.lastUpdateDate != null
                                      ? DateFormat('yyyy-MM-dd').format(
                                          DateTime.parse(
                                              property.lastUpdateDate!))
                                      : 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.hasMortgage == true ? 'Yes' : 'No',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(property.bankName ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(property.mortgageNumber ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  formatCurrency(property.remainingBalance),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(formatCurrency(property.principal),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  formatCurrency(property.monthlyPayment),
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(
                                  property.interestPercentage != null
                                      ? '${property.interestPercentage}%'
                                      : 'N/A',
                                  style: pw.TextStyle(fontSize: 7),
                                  textAlign: pw.TextAlign.right)),
                          pw.Padding(
                              padding: pw.EdgeInsets.all(4),
                              child: pw.Text(property.status ?? 'N/A',
                                  style: pw.TextStyle(fontSize: 7))),
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
          bytes: await pdf.save(), filename: 'Live_Property_Report.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'Live_Property_Report',
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
      sheet.name = 'Live Property Report';

      // Add headers
      List<String> headers = [
        'Property',
        'City',
        'State',
        'Zipcode',
        'Subdivision',
        'Rental Owner',
        'Parcel #',
        'Purchase Price',
        'Placed in Service',
        'Insured Year',
        'Insured Value',
        'Monthly Rent',
        '2025 Tax Bill',
        'Update Date',
        'Mortgaged',
        'Bank',
        'Mortgage #',
        'Balance',
        'Principal',
        'Payment',
        'Interest %',
        'Type'
      ];

      for (int i = 0; i < headers.length; i++) {
        sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
        sheet.getRangeByIndex(1, i + 1).cellStyle.bold = true;
      }

      // Add data
      for (int i = 0; i < filteredData.length; i++) {
        final property = filteredData[i];
        int row = i + 2;

        sheet.getRangeByIndex(row, 1).setText(property.property?.address ?? '');
        sheet.getRangeByIndex(row, 2).setText(property.property?.city ?? '');
        sheet.getRangeByIndex(row, 3).setText(property.property?.state ?? '');
        sheet.getRangeByIndex(row, 4).setText(property.property?.zipcode ?? '');
        sheet
            .getRangeByIndex(row, 5)
            .setText(property.property?.subdivision ?? '');
        sheet.getRangeByIndex(row, 6).setText(property.rentalOwner?.name ?? '');
        sheet
            .getRangeByIndex(row, 7)
            .setText(property.purchaseInfo?.parcelNumber ?? '');
        sheet
            .getRangeByIndex(row, 8)
            .setText(formatCurrency(property.purchaseInfo?.purchasePrice));
        sheet.getRangeByIndex(row, 9).setText(property.placedInService ?? '');
        sheet
            .getRangeByIndex(row, 10)
            .setText(property.insuredYear?.toString() ?? '');
        sheet
            .getRangeByIndex(row, 11)
            .setText(formatCurrency(property.insuredValue));
        sheet
            .getRangeByIndex(row, 12)
            .setText(formatCurrency(property.monthlyRent));
        sheet
            .getRangeByIndex(row, 13)
            .setText(formatCurrency(property.taxBill));
        sheet.getRangeByIndex(row, 14).setText(property.lastUpdateDate != null
            ? DateFormat('yyyy-MM-dd')
                .format(DateTime.parse(property.lastUpdateDate!))
            : '');
        sheet
            .getRangeByIndex(row, 15)
            .setText(property.hasMortgage == true ? 'Yes' : 'No');
        sheet.getRangeByIndex(row, 16).setText(property.bankName ?? '');
        sheet.getRangeByIndex(row, 17).setText(property.mortgageNumber ?? '');
        sheet
            .getRangeByIndex(row, 18)
            .setText(formatCurrency(property.remainingBalance));
        sheet
            .getRangeByIndex(row, 19)
            .setText(formatCurrency(property.principal));
        sheet
            .getRangeByIndex(row, 20)
            .setText(formatCurrency(property.monthlyPayment));
        sheet.getRangeByIndex(row, 21).setText(
            property.interestPercentage != null
                ? '${property.interestPercentage}%'
                : '');
        sheet.getRangeByIndex(row, 22).setText(property.status ?? '');
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
          '${directory.path}/Live_Property_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
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
          'Property,City,State,Zipcode,Subdivision,Rental Owner,Parcel #,Purchase Price,Placed in Service,Insured Year,Insured Value,Monthly Rent,2025 Tax Bill,Update Date,Mortgaged,Bank,Mortgage #,Balance,Principal,Payment,Interest %,Type');

      for (final property in filteredData) {
        // Quoted like web's CSV, so addresses and amounts with commas stay
        // in their column.
        csv.writeln(csvRow([
          property.property?.address ?? '',
          property.property?.city ?? '',
          property.property?.state ?? '',
          property.property?.zipcode ?? '',
          property.property?.subdivision ?? '',
          property.rentalOwner?.name ?? '',
          property.purchaseInfo?.parcelNumber ?? '',
          formatCurrency(property.purchaseInfo?.purchasePrice),
          property.placedInService ?? '',
          property.insuredYear ?? '',
          formatCurrency(property.insuredValue),
          formatCurrency(property.monthlyRent),
          formatCurrency(property.taxBill),
          property.lastUpdateDate != null
              ? DateFormat('yyyy-MM-dd')
                  .format(DateTime.parse(property.lastUpdateDate!))
              : '',
          property.hasMortgage == true ? 'Yes' : 'No',
          property.bankName ?? '',
          property.mortgageNumber ?? '',
          formatCurrency(property.remainingBalance),
          formatCurrency(property.principal),
          formatCurrency(property.monthlyPayment),
          property.interestPercentage != null
              ? '${property.interestPercentage}%'
              : '',
          property.status ?? '',
        ]));
      }

      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/Live_Property_Report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv.toString());

      // Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Live Property Report');

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
            title: 'Live Property Report',
            width: MediaQuery.of(context).size.width * .95,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  filters(),
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
                            Icons.home_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No property data found',
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
