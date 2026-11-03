import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';

import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../../widgets/custom_drawer.dart';
import 'package:provider/provider.dart';
import '../../../../../provider/dateProvider.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

class AdminAddTenantInsurance extends StatefulWidget {
  final String tenantid;
  final String leaseId;
  final String? tenantName;
  const AdminAddTenantInsurance({required this.tenantid, required this.leaseId, this.tenantName});

  @override
  State<AdminAddTenantInsurance> createState() =>
      _AdminAddTenantInsuranceState();
}

class _AdminAddTenantInsuranceState extends State<AdminAddTenantInsurance> {
  TextEditingController provider = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController policy = TextEditingController();
  TextEditingController effective = TextEditingController();
  TextEditingController expiration = TextEditingController();
  TextEditingController liablity = TextEditingController();
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  bool isLoading = false;

  /// Web parity: on the tenant-scoped Add Policy form web lists the one tenant
  /// with the box UNCHECKED and marks Covered Tenants required, so the user
  /// selects deliberately. This screen previously showed a locked, always-
  /// checked box and sent the tenant regardless.
  bool _tenantSelected = false;
  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget sourceTile({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onPick,
        }) {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(sheetContext);
              onPick();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDBE0E5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: blueColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color.fromRGBO(21, 43, 81, 1))),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBE0E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Upload Insurance Document',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromRGBO(21, 43, 81, 1))),
                const SizedBox(height: 4),
                Text('Choose where to pick your document from',
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                const SizedBox(height: 18),
                sourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Photo Gallery',
                  subtitle: '.png, .jpeg',
                  onPick: () => _pickFiles(FileType.image, null),
                ),
                const SizedBox(height: 12),
                sourceTile(
                  icon: Icons.insert_drive_file_rounded,
                  title: 'Browse Files',
                  subtitle: '.png, .jpeg, .pdf, .csv',
                  onPick: () => _pickFiles(
                      FileType.custom, ['png', 'jpeg', 'jpg', 'pdf', 'csv']),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickFiles(
      FileType type, List<String>? allowedExtensions) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );

    if (result != null) {
      List<File> files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      setState(() {
        _pdfFiles = files;
      });

      for (var file in _pdfFiles) {
        await _uploadPdf(file);
      }
    }
  }

  Future<void> _uploadPdf(File pdfFile) async {
    try {
      String? fileName = await uploadPdf(pdfFile);
      setState(() {
        if (fileName != null) {
          if (_uploadedFileNames.isNotEmpty) {
            _uploadedFileNames.clear();
          }
          _uploadedFileNames.add(fileName);
        }
      });
    } catch (e) {
    }
  }

  Future<String?> uploadPdf(File pdfFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('files', pdfFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      // Reflect the actual uploaded file type in the toast (was always "PDF",
      // so a JPEG/PNG wrongly said "PDF added successfully").
      final String ext = pdfFile.path.split('.').last.toLowerCase();
      final String typeLabel = ext == 'pdf'
          ? 'PDF'
          : (['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp'].contains(ext)
              ? 'Image'
              : 'File');
      Fluttertoast.showToast(msg: '$typeLabel added successfully');
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  DateTime? effectiveDate;
  DateTime? expirationDate;

  String _convertToApiFormat(String displayDate) {
    if (displayDate.isEmpty) return "";
    // The company's own date format first (strict), like web, so a custom
    // format such as "DD/MMM/YYYY" reads back correctly (AppDateFormat).
    final inCompanyFormat = AppDateFormat.parseShownToApi(displayDate);
    if (inCompanyFormat != null) return inCompanyFormat;
    try {
      DateTime? parsedDate;

      // Try to parse the date using common formats
      List<String> dateFormats = [
        'yyyy-MM-dd',
        'yyyy-MMM-dd', // Added for API format like "2025-Aug-22"
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'dd/MM/yyyy',
        'dd-MM-yyyy'
      ];

      for (String format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(displayDate);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      } else {
        return displayDate; // Return original if parsing fails
      }
    } catch (e) {
      return displayDate; // Return original if parsing fails
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: effectiveDate ?? DateTime.now(),
      firstDate: DateTime(2015, 8),
      //  firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              // onSurface: Colors.blue, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        effectiveDate = selectedDate;
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        effective.text = dateProvider.formatCurrentDate(apiFormatDate);

        // If effective date is after expiration date, clear expiration date and show warning
        if (expirationDate != null && effectiveDate!.isAfter(expirationDate!)) {
          expirationDate = null;
          expiration.text = '';
          Fluttertoast.showToast(
              msg:
                  "Effective date cannot be after expiration date. Please select a new expiration date.");
        }
      });
    }
  }

  Future<void> _selectDateexpiration(BuildContext context) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    DateTime minExpirationDate = effectiveDate != null
        ? effectiveDate!.add(const Duration(days: 1))
        : DateTime.now();
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate:
          (expirationDate != null && !expirationDate!.isBefore(minExpirationDate))
              ? expirationDate!
              : minExpirationDate,
      firstDate: minExpirationDate,
      // firstDate: DateTime(1900),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              // onSurface: Colors.blue, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        expirationDate = selectedDate;
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        expiration.text = dateProvider.formatCurrentDate(apiFormatDate);

        // If expiration date is before or same as effective date, show warning
        if (effectiveDate != null &&
            (expirationDate!.isBefore(effectiveDate!) ||
                expirationDate!.isAtSameMomentAs(effectiveDate!))) {
          Fluttertoast.showToast(
              msg: "Expiration date must be after effective date.");
        }
      });
    }
  }

  bool _validateDates() {
    final error = validateInsuranceDateRange(effectiveDate, expirationDate);
    if (error != null) {
      Fluttertoast.showToast(msg: error);
      return false;
    }
    return true;
  }

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget_302_Staff.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: CustomDrawerStaff(
          currentpage: "Tenants",
          dropdown: true,
        ),
        body: Form(
          key: _formkey,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 25,
                  ),
                  titleBar(
                    width: MediaQuery.of(context).size.width * .91,
                    title: 'Add Insurance Policy',
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      width: double.infinity,
                      // height: !form_valid ? 860 : 830,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: const Color(0xFFCED4DA),
                          )),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Insurance Company *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              keyboardType: TextInputType.text,
                              hintText: 'Enter insurance company',
                              controller: provider,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the subject';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text('Insurance Company Phone Number *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(height: 10),
                            CustomTextField(
                              keyboardType: TextInputType.phone,
                              hintText: 'Insurance company phone number',
                              controller: phone,
                              phone: true,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(14),
                                PhoneNumberFormatter(),
                              ],
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Policy ID *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              keyboardType: TextInputType.text,
                              hintText: 'Policy id',
                              controller: policy,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the subject';
                                }
                                return null;
                              },
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Effective Date *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              readOnnly: true,
                              onTap: () {
                                _selectDate(context);
                              },
                              keyboardType: TextInputType.text,
                              hintText: Provider.of<DateProvider>(context,
                                      listen: false)
                                  .dateFormat
                                  .toUpperCase(),
                              controller: effective,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the subject';
                                }
                                return null;
                              },
                              suffixIcon: Icon(
                                Icons.date_range,
                                color: blueColor,
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Expiration Date *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              readOnnly: true,
                              onTap: () {
                                _selectDateexpiration(context);
                              },
                              keyboardType: TextInputType.text,
                              hintText: Provider.of<DateProvider>(context,
                                      listen: false)
                                  .dateFormat
                                  .toUpperCase(),
                              controller: expiration,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the subject';
                                }
                                return null;
                              },
                              suffixIcon: Icon(
                                Icons.date_range,
                                color: blueColor,
                              ),
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Liability Coverage (\$0.00) *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            // CustomTextField(
                            //   keyboardType: TextInputType.text,
                            //   hintText: '\$0.00',
                            //   controller: liablity,
                            //   validator: (value) {
                            //     if (value == null || value.isEmpty) {
                            //       return 'please enter the subject';
                            //     }
                            //     return null;
                            //   },
                            // ),
                            CustomTextField(
                              keyboardType: TextInputType.number,
                              hintText: '\$0.00',
                              controller: liablity,
                              suffixIcon: IconButton(icon: const Icon(Icons.check), color: blueColor, tooltip: 'Done', onPressed: () => FocusScope.of(context).unfocus()),
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r'^\d*\.?\d{0,2}')), // allows decimals
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter the liability coverage.';
                                }
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null) {
                                  return 'Liability Coverage must be a number. Please enter a valid numeric value.';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text('Covered Tenants: *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Checkbox(
                                    value: _tenantSelected,
                                    onChanged: (v) => setState(
                                        () => _tenantSelected = v ?? false),
                                    activeColor: blueColor,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    (widget.tenantName?.isNotEmpty == true)
                                        ? widget.tenantName!
                                        : widget.tenantid,
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Upload Insurance Document',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            if (_uploadedFileNames.isEmpty)
                              GestureDetector(
                                onTap: _showUploadOptions,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Image.asset('assets/icons/Upload.png',
                                          height: 50, width: 50),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Upload your document here',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Maximum File Size is 20MB',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                      const Text(
                                        'Supported File Types are .png, .jpeg, .pdf, .csv',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_uploadedFileNames.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file,
                                        color: Color(0xFF748097), size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _uploadedFileNames.first,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF748097),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _uploadedFileNames.clear();
                                        });
                                      },
                                      icon: const Icon(Icons.close,
                                          color: Color(0xFF748097), size: 20),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              // Web parity (CRM-2448): guard against double-tap
                              // creating duplicate policies — disable the button
                              // once a save is in flight, on top of the same
                              // check inside addinsurance() itself.
                              onPressed: isLoading ? null : () {
                                if (_formkey.currentState!.validate()) {
                                  // Covered Tenants is required (web parity).
                                  if (!_tenantSelected) {
                                    Fluttertoast.showToast(
                                        msg:
                                            'Please select at least one tenant');
                                    return;
                                  }
                                  if (_validateDates()) {
                                    addinsurance();
                                  }
                                }
                              },
                              child: isLoading
                                  ? const Center(
                                      child: SpinKitFadingCircle(
                                        color: Colors.white,
                                        size: 55.0,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCED4DA), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Color(0xFF748097), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  addinsurance() async {
    // Second layer: the button is disabled while isLoading, but this stops
    // any other caller (or a tap that lands in the same frame) from starting
    // a second concurrent submit. isLoading was declared here but never set,
    // so neither the guard nor the button spinner was doing anything.
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });
    try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');

    Map<String, dynamic> values = {
      "lease_id": widget.leaseId,
      "insurance_company": provider.text.trim(),
      "insurance_company_phone_number": phone.text.trim(),
      "policy_id": policy.text.trim(),
      "effective_date": _convertToApiFormat(effective.text.trim()),
      "expiration_date": _convertToApiFormat(expiration.text.trim()),
      // Web parity: web submits this field as the raw string, so "0"
      // reaches the server truthy and is accepted. Sending a numeric 0
      // tripped the server's required-field check (!0 is true in JS) and
      // surfaced "Missing required fields". Mongoose casts to Number on
      // save either way, so stored data is unchanged.
      "liability_coverage": liablity.text.trim(),
      "insurance_policy_document": _uploadedFileNames.isNotEmpty ? _uploadedFileNames.first : "",
      "tenants": [widget.tenantid],
    };

    final http.Response response = await apiPost(
      Uri.parse('$Api_url/api/renter-insurance/add-policy'),
      headers: <String, String>{
        'authorization': 'CRM $token',
        'id': 'CRM ${prefs.getString("staff_id") ?? adminId}',
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(values),
    );

    var responseData = json.decode(response.body);
    if (responseData["savedPolicy"] == 200 || responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      Navigator.pop(context, true);
      return responseData;
    } else {
      Fluttertoast.showToast(msg: responseData["message"] ?? 'Failed to save');
      throw Exception('Failed to add Insurance');
    }
    } finally {
      // Always release the guard so a failed save can be retried.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
