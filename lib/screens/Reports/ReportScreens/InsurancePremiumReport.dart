import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:three_zero_two_property/Model/InsurancePremiumReportModel.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/repository/InsurancePremiumReportService.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../widgets/report_header.dart';
import 'package:three_zero_two_property/widgets/pdf_report_header.dart';

class InsurancePremiumReport extends StatefulWidget {
  const InsurancePremiumReport({super.key});

  @override
  State<InsurancePremiumReport> createState() => _InsurancePremiumReportState();
}

class _InsurancePremiumReportState extends State<InsurancePremiumReport>
    with NetworkRetryState {
  final InsurancePremiumReportService _service =
      InsurancePremiumReportService();

  List<String> availableYears = [];
  List<String> selectedYears = [];
  InsurancePremiumReportModel? reportData;
  bool isLoading = false;
  bool isLoadingYears = false;
  String? errorMessage;
  String? adminId;

  // Track which property is expanded
  int? expandedPropertyIndex;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _initializeData();
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    adminId = prefs.getString('adminId');
    if (adminId != null) {
      _fetchAvailableYears();
    }
  }

  Future<void> _fetchAvailableYears() async {
    if (adminId == null) return;

    setState(() {
      isLoadingYears = true;
      errorMessage = null;
    });

    try {
      final years = await _service.fetchInsurancePremiumYears(adminId!);
      setState(() {
        availableYears = years;
        isLoadingYears = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load years: ${friendlyErrorMessage(e)}';
        isLoadingYears = false;
      });
      // A network failure already flips this screen to its offline state; a
      // toast on top of it just repeats the same news.
      if (!isNetworkError(e)) {
        Fluttertoast.showToast(msg: 'Failed to load years');
      }
    }
  }

  Future<void> _runReport() async {
    if (selectedYears.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Please select at least one year',
        toastLength: Toast.LENGTH_SHORT,
      );
      return;
    }

    if (adminId == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      expandedPropertyIndex = null;
    });

    try {
      final data = await _service.fetchInsurancePremiumReport(
        adminId: adminId!,
        years: selectedYears,
      );
      setState(() {
        reportData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load report: $e';
        isLoading = false;
      });
      Fluttertoast.showToast(msg: 'Failed to load report');
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'N/A';
    if (value is num) {
      return NumberFormat.currency(symbol: '\$', decimalDigits: 2)
          .format(value);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(currentpage: "Reports", dropdown: true),
      // This screen had no offline state at all; a failed request used to
      // leave it blank or showing an error string with no way to retry.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : Column(
        children: [
          ReportHeader(title: 'Insurance Premium Report'),
          Expanded(
            child: SingleChildScrollView(
              // padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Controls Row
                  SizedBox(height: 10),
                  _buildControlsRow(),
                  SizedBox(height: 20),

                  // Property Address Header
                  // if (reportData != null && reportData!.rows.isNotEmpty)
                  _buildPropertyAddressHeader(),

                  SizedBox(height: 10),

                  // Report Content
                  _buildReportContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Select Years/Spans Dropdown
          Expanded(
            flex: 2,
            child: _buildYearDropdown(),
          ),
          SizedBox(width: 12),

          // Run Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: blueColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:() {
                  _runReport();
                },
                child: Text(
                  'Run',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),

          // Download Button
          // Greyed out and not tappable until the report has rows.
          Container(
            width: 50,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Color(0xFF8A95A8)),
            ),
            child: PopupMenuButton<String>(
              enabled: reportData != null && reportData!.rows.isNotEmpty,
              offset: Offset(0, 45),
              onSelected: (value) async {
                if (reportData == null || reportData!.rows.isEmpty) {
                  Fluttertoast.showToast(
                    msg: 'No data to export',
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  return;
                }
                if (value == 'PDF') {
                  await _generatePdf();
                } else if (value == 'XLSX') {
                  await _generateExcel();
                } else if (value == 'CSV') {
                  await _generateCsv();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'PDF',
                  child: Text('PDF'),
                ),
                const PopupMenuItem<String>(
                  value: 'XLSX',
                  child: Text('XLSX'),
                ),
                const PopupMenuItem<String>(
                  value: 'CSV',
                  child: Text('CSV'),
                ),
              ],
              child: Center(
                child: FaIcon(FontAwesomeIcons.download,
                    color: reportData != null && reportData!.rows.isNotEmpty
                        ? blueColor
                        : Colors.grey.shade400,
                    size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    String displayText = selectedYears.isEmpty
        ? 'Select Years/Spans'
        : selectedYears.length == 1
            ? selectedYears.first
            : selectedYears.join(', ');

    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        hint: Text(
          displayText,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          overflow: TextOverflow.ellipsis,
        ),
        value: null, // Always null for multi-select
        items: availableYears.map((year) {
          return DropdownMenuItem<String>(
            value: year,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                final isSelected = selectedYears.contains(year);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selectedYears.remove(year);
                      } else {
                        selectedYears.add(year);
                      }
                    });
                    this.setState(() {});
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    color: Colors.white,
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (!selectedYears.contains(year)) {
                                  selectedYears.add(year);
                                }
                              } else {
                                selectedYears.remove(year);
                              }
                            });
                            this.setState(() {});
                          },
                          activeColor: blueColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Expanded(
                          child: Text(
                            year,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? blueColor : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
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
        iconStyleData: IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down),
          iconSize: 20,
          iconEnabledColor: Colors.grey[700],
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
          ),
          offset: const Offset(0, 0),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: MaterialStateProperty.all(6),
            thumbVisibility: MaterialStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 40,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildPropertyAddressHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFF7F9FC),
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Property Address',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: blueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    if (isLoadingYears) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(
                color: blueColor,
                size: 45,
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null && reportData == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              SizedBox(height: 16),
              Text(
                'Error Loading Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpinKitFadingCircle(
                color: blueColor,
                size: 45,
              ),
            ],
          ),
        ),
      );
    }

    // Only show "No Data Available" if Run button was clicked (reportData was attempted to be fetched)
    // If reportData is null and not loading, don't show anything (initial state)
    if (reportData == null) {
      return Center(
          child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/no_data_transparent.png",
              height: 200,
              width: 200,
            ),
            SizedBox(height: 10),
            Text(
              "No Data Available",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
            ),
          ],
        ),
      )); // Don't show anything until Run is clicked
    }

    if (reportData!.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/no_data_transparent.png",
                height: 200,
                width: 200,
              ),
              SizedBox(height: 10),
              Text(
                "No Data Available",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: reportData!.rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return _buildExpandablePropertyCard(row, index);
      }).toList(),
    );
  }

  Widget _buildExpandablePropertyCard(InsurancePremiumRow row, int index) {
    final isExpanded = expandedPropertyIndex == index;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: index % 2 != 0 ? Color(0xFFF4F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFDBE0E5)),
      ),
      child: Column(
        children: [
          // Collapsed Header
          InkWell(
            onTap: () {
              setState(() {
                expandedPropertyIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.address,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: blueColor,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          // Expanded Content
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: index % 2 != 0 ? Color(0xFFF4F8FF) : Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                children: reportData!.years.map((year) {
                  final value = row.getValueForYear(year);
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          year,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          _formatCurrency(value),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: blueColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCurrencyForExport(dynamic value) {
    if (value == null) return '-';
    if (value is num) {
      return NumberFormat.currency(symbol: '\$', decimalDigits: 2)
          .format(value);
    }
    return value.toString();
  }

  Future<void> _generatePdf() async {
    if (reportData == null || reportData!.rows.isEmpty) return;

    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;

    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      logError("Error fetching profile data: $e");
    }

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
                    'Insurance Premium Report',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Years: ${reportData!.years.join(', ')}',
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
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20)
        ]),
        build: (pw.Context context) {
          // Build headers: Property Address + dynamic years
          final headers = ['Property Address', ...reportData!.years];

          // Build table data
          final tableData = reportData!.rows.map((row) {
            final rowData = [row.address];
            for (var year in reportData!.years) {
              final value = row.getValueForYear(year);
              rowData.add(_formatCurrencyForExport(value));
            }
            return rowData;
          }).toList();

          return [
            pw.Table.fromTextArray(
              headers: headers,
              data: tableData,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex("#5A86D5"),
              ),
              cellStyle: pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                for (int i = 0; i < headers.length; i++)
                  i: i == 0 ? pw.FlexColumnWidth(3) : pw.FlexColumnWidth(1.5),
              },
              border: null,
            ),
          ];
        },
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'Insurance_Premium_Report.pdf');
    } else {
      await Printing.layoutPdf(
      name: 'Insurance_Premium_Report',
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> _generateExcel() async {
    if (reportData == null || reportData!.rows.isEmpty) return;

    try {
      final syncXlsx.Workbook workbook = syncXlsx.Workbook();
      final syncXlsx.Worksheet sheet = workbook.worksheets[0];

      // Title
      sheet.getRangeByIndex(1, 1).setText('Insurance Premium Report');
      final titleStyle = workbook.styles.add('titleStyle');
      titleStyle.bold = true;
      titleStyle.fontSize = 16;
      sheet.getRangeByIndex(1, 1).cellStyle = titleStyle;

      // Calculate last column letter
      final lastCol = String.fromCharCode(64 + reportData!.years.length + 1);
      sheet.getRangeByName('A1:${lastCol}1').merge();

      // Generated date
      sheet.getRangeByIndex(3, 1).setText(
          'Generated on: ${DateFormat('MM/dd/yyyy').format(DateTime.now())}');
      sheet.getRangeByName('A3:${lastCol}3').merge();

      // Years
      sheet
          .getRangeByIndex(5, 1)
          .setText('Years: ${reportData!.years.join(', ')}');
      sheet.getRangeByName('A5:${lastCol}5').merge();

      // Headers
      sheet.getRangeByIndex(6, 1).setText('Property Address');
      for (int i = 0; i < reportData!.years.length; i++) {
        sheet.getRangeByIndex(6, i + 2).setText(reportData!.years[i]);
      }

      // Style headers
      final syncXlsx.Style headerStyle = workbook.styles.add('headerStyle');
      headerStyle.backColor = '#5A86D5';
      headerStyle.fontColor = '#FFFFFF';
      headerStyle.bold = true;
      headerStyle.hAlign = syncXlsx.HAlignType.center;
      headerStyle.fontSize = 12;
      sheet.getRangeByIndex(6, 1, 6, reportData!.years.length + 1).cellStyle =
          headerStyle;

      // Currency style
      final syncXlsx.Style currencyStyle = workbook.styles.add('currencyStyle');
      currencyStyle.numberFormat = '\$#,##0.00';
      currencyStyle.hAlign = syncXlsx.HAlignType.right;

      // Data rows
      int rowIndex = 7;
      for (var row in reportData!.rows) {
        sheet.getRangeByIndex(rowIndex, 1).setText(row.address);
        for (int i = 0; i < reportData!.years.length; i++) {
          final year = reportData!.years[i];
          final value = row.getValueForYear(year);
          if (value == null) {
            sheet.getRangeByIndex(rowIndex, i + 2).setText('-');
          } else if (value is num) {
            sheet.getRangeByIndex(rowIndex, i + 2).setNumber(value.toDouble());
            sheet.getRangeByIndex(rowIndex, i + 2).cellStyle = currencyStyle;
          } else {
            sheet.getRangeByIndex(rowIndex, i + 2).setText(value.toString());
          }
        }
        rowIndex++;
      }

      // Auto-fit columns
      for (int i = 1; i <= reportData!.years.length + 1; i++) {
        sheet.autoFitColumn(i);
      }

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final DateTime now = DateTime.now();
      final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
      final String fileName = 'Insurance_Premium_Report_$formattedDate.xlsx';

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
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      logError('Error generating Excel: $e');
      Fluttertoast.showToast(
        msg: 'Error generating Excel',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  Future<void> _generateCsv() async {
    if (reportData == null || reportData!.rows.isEmpty) return;

    try {
      final StringBuffer csvBuffer = StringBuffer();

      // Title
      csvBuffer.writeln('Insurance Premium Report');
      csvBuffer.writeln('');
      csvBuffer.writeln(
          'Generated on: ${DateFormat('MM/dd/yyyy').format(DateTime.now())}');
      csvBuffer.writeln('');
      csvBuffer.writeln('Years: ${reportData!.years.join(', ')}');
      csvBuffer.writeln('');

      // Headers
      final headers = ['Property Address', ...reportData!.years];
      csvBuffer.writeln(csvRow(headers));

      // Data rows
      for (var row in reportData!.rows) {
        final sanitizedAddress = row.address;
        final rowData = [sanitizedAddress];
        for (var year in reportData!.years) {
          final value = row.getValueForYear(year);
          if (value == null) {
            rowData.add('-');
          } else if (value is num) {
            rowData.add(NumberFormat('#,##0.00').format(value));
          } else {
            rowData.add(value.toString());
          }
        }
        csvBuffer.writeln(csvRow(rowData));
      }

      final DateTime now = DateTime.now();
      final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
      final String fileName = 'Insurance_Premium_Report_$formattedDate.csv';

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
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      logError('Error generating CSV: $e');
      Fluttertoast.showToast(
        msg: 'Error generating CSV',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }
}
