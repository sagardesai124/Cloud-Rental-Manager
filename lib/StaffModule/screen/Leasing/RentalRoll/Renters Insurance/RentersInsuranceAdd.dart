import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:provider/provider.dart';

import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';

import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../../model/LeaseSummary.dart';
import '../../../../repository/lease.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

class LeaseAddRentersInsurance extends StatefulWidget {
  final String tenantid;
  final String leaseId;
  const LeaseAddRentersInsurance(
      {required this.tenantid, required this.leaseId});

  @override
  State<LeaseAddRentersInsurance> createState() =>
      _LeaseAddRentersInsuranceState();
}

class _LeaseAddRentersInsuranceState extends State<LeaseAddRentersInsurance> {
  TextEditingController company = TextEditingController();
  TextEditingController number = TextEditingController();
  TextEditingController policy = TextEditingController();
  TextEditingController effective = TextEditingController();
  TextEditingController expiration = TextEditingController();
  TextEditingController liablity = TextEditingController();
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    fetchTenants();
  }

  bool isLoading = false;
  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      List<File> files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      if (files.length > 10) {
        Fluttertoast.showToast(msg: 'You can only select up to 10 files.');
        return; // Exit the method if more than 10 files are selected
      }

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
      logError('PDF upload failed: $e');
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

  DateTime? effectiveDate;
  DateTime? expirationDate;

  Future<void> _selectDate(BuildContext context) async {
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
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        effective.text = dateProvider.formatCurrentDate(apiFormatDate);
      });
    }
  }

  Future<void> _selectDateexpiration(BuildContext context) async {
    DateTime minExpirationDate = effectiveDate != null
        ? effectiveDate!.add(const Duration(days: 1))
        : DateTime.now();
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: (expirationDate != null &&
              !expirationDate!.isBefore(minExpirationDate))
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
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        expiration.text = dateProvider.formatCurrentDate(apiFormatDate);
      });
    }
  }

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();

  List<Map<String, String>> tenants = [];
  List<String> selectedTenants = [];

  // Helper function to convert display format back to API format (yyyy-MM-dd)
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
        'yyyy-MMM-dd',
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
      }
      return displayDate;
    } catch (e) {
      return displayDate;
    }
  }

  Future<void> fetchTenants() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('$Api_url/api/leases/lease_tenant/${widget.leaseId}'),
      headers: {"id": "CRM ${prefs.getString('staff_id') ?? id}", "authorization": "CRM $token"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<Map<String, String>> fetchedTenants = [];
      //print(firstName.text = data['tenant_firstName'] ?? "");
      for (var tenant in data['data']['tenants']) {
        fetchedTenants.add({
          'tenant_id': tenant['tenant_id'],
          'tenant_name':
              '${tenant['tenant_firstName']} ${tenant['tenant_lastName']}',
          'tenant_firstname': '${tenant['tenant_firstName']}',
          'tenant_lastName': '${tenant['tenant_lastName']}',
          'tenant_email': '${tenant['tenant_email']}',
          'tenant_phoneNumber': '${tenant['tenant_phoneNumber']}',
          'rental_adress': "${data['data']['rental_adress']}",
          'rental_city': "${data['data']['rental_city']}",
          'rental_state': "${data['data']['rental_state']}",
          'rental_country': "${data['data']['rental_country']}",
          'rental_zip': "${data['data']['rental_zip']}",
          'tenant_firstName': '${tenant['tenant_firstName']}',
          'tenant_lastName': '${tenant['tenant_lastName']}',
          'tenant_email': '${tenant['tenant_email']}',
          'tenant_phoneNumber':
              formatPhoneNumberedit('${tenant['tenant_phoneNumber']}'),
          'rental_adress': "${data['data']['rental_adress']}",
          'rental_city': "${data['data']['rental_city']}",
          'rental_state': "${data['data']['rental_state']}",
          'rental_country': "${data['data']['rental_country']}",
          'rental_zip': "${data['data']['rental_zip']}",
        });
      }
      final rentalAddress = {
        'rental_adress': data['data']['rental_adress'] ?? "",
      };
      setState(() {
        // Web parity (and Admin parity): Covered Tenants start unchecked and
        // the user picks who the policy covers. The old pre-check-all here
        // silently attached every tenant on the lease to the policy.
        tenants = fetchedTenants;
      });
    } else {
      throw Exception('Failed to load tenants');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: widget_302_Staff.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: CustomDrawerStaff(
          currentpage: "Rent Roll",
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
                    title: 'Add New Policy',
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
                              controller: company,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              //   label: "",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter insurance company';
                                }
                                return null;
                              },
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Insurance Company Phone Number *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              keyboardType: TextInputType.text,
                              hintText: 'Enter phone number',
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                                PhoneNumberFormatter(),
                              ],
                              phone: true,
                              controller: number,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              //   label: "",
                              validator: (value) {
                                final digits = (value ?? '')
                                    .replaceAll(RegExp(r'[^\d]'), '');
                                if (digits.length != 10) {
                                  return 'Please enter a valid 10-digit phone number.';
                                }
                                return null;
                              },
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
                                  return 'Please enter policy ID';
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
                              onTap: () {
                                _selectDate(context);
                              },
                              keyboardType: TextInputType.text,
                              hintText: Provider.of<DateProvider>(context,
                                      listen: false)
                                  .dateFormat
                                  .toUpperCase(),
                              controller: effective,
                              readOnnly: true,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select effective date';
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
                              onTap: () {
                                _selectDateexpiration(context);
                              },
                              keyboardType: TextInputType.text,
                              hintText: Provider.of<DateProvider>(context,
                                      listen: false)
                                  .dateFormat
                                  .toUpperCase(),
                              controller: expiration,
                              readOnnly: true,
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select expiration date';
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
                            CustomTextField(
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              hintText: '\$0.00',
                              controller: liablity,
                              suffixIcon: IconButton(icon: const Icon(Icons.check), color: blueColor, tooltip: 'Done', onPressed: () => FocusScope.of(context).unfocus()),
                              showElevation: false,
                              borderColor: const Color(0xFFCED4DA),
                              borderWidth: 1.5,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]')),
                              ],
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter liability coverage';
                                }
                                if (double.tryParse(value.trim()) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                            SizedBox(
                              height: 10,
                            ),
                            Text('Covered Tenants: *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: blueColor)),
                            SizedBox(
                              height: 10,
                            ),
                            Column(
                              children: tenants.map((tenant) {
                                return Row(
                                  children: [
                                    Checkbox(
                                      activeColor: blueColor,
                                      value: selectedTenants
                                          .contains(tenant['tenant_id']),
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true) {
                                            selectedTenants
                                                .add(tenant['tenant_id']!);
                                          } else {
                                            selectedTenants
                                                .remove(tenant['tenant_id']);
                                          }
                                        });
                                      },
                                    ),
                                    Text(tenant['tenant_name'] ?? ""),
                                  ],
                                );
                              }).toList(),
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
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      const Text(
                                        'Supported File Types are .png, .jpeg, .pdf, .csv',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
                                  final dateError = validateInsuranceDateRange(
                                      effectiveDate, expirationDate);
                                  if (dateError != null) {
                                    Fluttertoast.showToast(msg: dateError);
                                    return;
                                  }
                                  if (selectedTenants.isEmpty) {
                                    Fluttertoast.showToast(
                                        msg:
                                            'Please select at least one tenant');
                                    return;
                                  }
                                  addinsurance();
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
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600),
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
                                side: const BorderSide(
                                    color: Color(0xFFCED4DA), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                    color: Color(0xFF748097),
                                    fontWeight: FontWeight.w600),
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

  // addinsurance() async {
  //   print('entry');
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? adminId = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //   print('${adminId}  ${token}');
  //
  //   List<Map<String, String>> selectedTenantsList = selectedTenants.map((tenantId) {
  //     return {"tenant_id": tenantId};
  //   }).toList();
  //
  //   Map<String, dynamic> values = {
  //     "lease_id": widget.leaseId,
  //     "admin_id": adminId!,
  //     "insurance_company": company.text.trim(),
  //     "insurance_company_phone_number": number.text.trim(),
  //     "policy_id": policy.text.trim(),
  //     "effective_date": reverseFormatDate(effective.text.trim()),
  //     "expiration_date": reverseFormatDate(expiration.text.trim()),
  //     "liability_coverage": num.tryParse(liablity.text.trim()) ?? liablity.text.trim(),
  //     "tenants": selectedTenantsList,
  //     "insurance_policy_document": _uploadedFileNames.length > 0 ? _uploadedFileNames.first : "",
  //   };
  //   print(values);
  //   print('entry');
  //
  //   final http.Response response = await apiPost(
  //     Uri.parse(
  //         '$Api_url/api/renter-insurance/add-policy'),
  //     headers: <String, String>{
  //       'authorization': 'CRM $token',
  //       'id': 'CRM ${prefs.getString("staff_id") ?? adminId}',
  //
  //       //'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: values,
  //   );
  //
  //   var responseData = json.decode(response.body);
  //   print('response body ${response.body}');
  //   if (responseData["statusCode"] == 200) {
  //     Fluttertoast.showToast(msg: responseData["message"]);
  //     Navigator.pop(context, true);
  //     return responseData;
  //   } else {
  //     Fluttertoast.showToast(msg: responseData["message"]);
  //     throw Exception('Failed to Insurance');
  //   }
  // }
  addinsurance() async {
    // Second layer: the button is disabled while isLoading, but this stops
    // any other caller (or a tap that lands in the same frame) from starting
    // a second concurrent submit.
    if (isLoading) return;
    setState(() {
      isLoading = true; // Start loading
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString("adminId");
      String? id = prefs.getString("staff_id");
      String? token = prefs.getString('token');

      // Convert selected tenants to a list of maps
      List<String> selectedTenantsList =
          selectedTenants.map((tenantId) => tenantId.toString()).toList();

      Map<String, dynamic> values = {
        "lease_id": widget.leaseId,
        "insurance_company": company.text.trim(),
        "insurance_company_phone_number": number.text.trim(),
        "policy_id": policy.text.trim(),
        "effective_date": _convertToApiFormat(effective.text.trim()),
        "expiration_date": _convertToApiFormat(expiration.text.trim()),
        // Web parity: web submits this field as the raw string, so "0"
        // reaches the server truthy and is accepted. Sending a numeric 0
        // tripped the server's required-field check (!0 is true in JS) and
        // surfaced "Missing required fields". Mongoose casts to Number on
        // save either way, so stored data is unchanged.
        "liability_coverage": liablity.text.trim(),
        "tenants": selectedTenantsList, // Ensure it's properly formatted
        "insurance_policy_document":
            _uploadedFileNames.isNotEmpty ? _uploadedFileNames.first : "",
      };


      final http.Response response = await apiPost(
        Uri.parse('$Api_url/api/renter-insurance/add-policy'),
        headers: <String, String>{
          'authorization': 'CRM $token',
          'id': 'CRM $id',
          'Content-Type': 'application/json', // Ensure JSON format is specified
        },
        body: jsonEncode(values), // Encode JSON properly
      );

      var responseData = json.decode(response.body);
      if (responseData["savedPolicy"] == 200) {
        Fluttertoast.showToast(msg: responseData["message"]);
        Navigator.pop(context, true);
        return responseData;
      } else {
        Fluttertoast.showToast(msg: responseData["message"]);
        throw Exception('Failed to Insurance');
      }
    } catch (error) {
      logError('Error: $error');
      Fluttertoast.showToast(msg: 'Something went wrong');
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }
}
