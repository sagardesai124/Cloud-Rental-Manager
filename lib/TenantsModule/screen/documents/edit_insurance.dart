import 'package:three_zero_two_property/widgets/insurance_document_viewer.dart';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/TenantsModule/model/insurance.dart';

import '../../../constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import '../../../widgets/titleBar.dart';
import '../../widgets/appbar.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/drawer_tiles.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:provider/provider.dart';
import '../../../provider/dateProvider.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

class edit_insurance extends StatefulWidget {
  Insurance_data data;
  edit_insurance({super.key, required this.data});

  @override
  State<edit_insurance> createState() => _edit_insuranceState();
}

class _edit_insuranceState extends State<edit_insurance> {
  TextEditingController provider = TextEditingController();
  TextEditingController policy = TextEditingController();
  TextEditingController effective = TextEditingController();
  TextEditingController expiration = TextEditingController();
  TextEditingController liablity = TextEditingController();
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  bool isLoading = false;
  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

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

  // Gallery can't show pdf/csv, so we let the user pick the source:
  // Photo Gallery (images) or Browse Files (png/jpeg/pdf/csv).
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
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color.fromRGBO(21, 43, 81, 1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
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
                const Text(
                  'Upload Insurance Document',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(21, 43, 81, 1),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose where to pick your document from',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                ),
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
      // A success status with no file entries would otherwise crash on
      // .first (or on the null list itself) after the toast already fired.
      final List files = responseBody['files'] ?? [];
      if (files.isEmpty) {
        throw Exception('Upload succeeded but no file was returned');
      }
      // Reflect the actual uploaded file type in the toast (was always "PDF",
      // so a JPEG/PNG wrongly said "PDF added successfully").
      final String ext = pdfFile.path.split('.').last.toLowerCase();
      final String typeLabel = ext == 'pdf'
          ? 'PDF'
          : (['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp'].contains(ext)
              ? 'Image'
              : 'File');
      Fluttertoast.showToast(msg: '$typeLabel added successfully');
      return files.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: effectiveDate ?? DateTime.now(),
      firstDate: DateTime(1900),
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

  late String initialProvider;
  late String initialPolicy;
  late String initialEffective;
  late String initialExpiration;
  late String initialLiability;
  late List<String> initialUploadedFileNames;

  @override
  initState() {
    provider.text = widget.data.provider!;
    policy.text = widget.data.policyId!;

    // Parse and set DateTime variables from existing data
    try {
      effectiveDate = DateTime.parse(widget.data.effectiveDate!);
      expirationDate = DateTime.parse(widget.data.expirationDate!);
    } catch (e) {
    }

    // Use DateProvider to format dates for display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      effective.text =
          dateProvider.formatCurrentDate(widget.data.effectiveDate!);
      expiration.text =
          dateProvider.formatCurrentDate(widget.data.expirationDate!);
    });

    liablity.text = widget.data.liabilityCoverage.toString();
    // `policy` is nullable (model reads json['Policy'] with no fallback), and
    // `null != ""` is true — so the old check fell through to the force-unwrap
    // and threw whenever a record had no document attached. Same guard the
    // Admin copy uses (editAdminTenantInsurance.dart).
    if (widget.data.policy != null && widget.data.policy!.isNotEmpty)
      _uploadedFileNames.add(widget.data.policy!);

    initialProvider = provider.text;
    initialPolicy = policy.text;
    initialEffective = effective.text;
    initialExpiration = expiration.text;
    initialLiability = liablity.text;
    initialUploadedFileNames = List.from(_uploadedFileNames);

    super.initState();
  }

  Future<void> _selectDateexpiration(BuildContext context) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    // Floor the picker at the day AFTER the effective date, matching the Admin
    // insurance screens. `firstDate: effectiveDate` let the user select the
    // effective date itself, which the strictly-after rule then rejected — so
    // the invalid pick was offered and only warned about afterwards.
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
    // Shared rule from constant.dart, same as the Admin/Staff insurance
    // screens — replaces this screen's hand-rolled copy of it.
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
        key: key,
        appBar: widget_302.App_Bar(
          context: context,
          onDrawerIconPressed: () {
            key.currentState!.openDrawer();
          },
        ),
        backgroundColor: const Color(0xFFF4F6F9),
        drawer: CustomDrawer(
          currentpage: 'Documents',
        ),
        body: Form(
          key: _formkey,
          child: Container(
            color: const Color(0xFFF4F6F9),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 12,
                  ),
                  titleBar(
                    width: MediaQuery.of(context).size.width * .91,
                    title: 'Edit Insurance Policy',
                    // size: 18,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: const Color(0xFFDBE0E5),
                          )),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Provider *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(21, 43, 81, 1))),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              showElevation: false,
                              borderColor: const Color(0xFFDBE0E5),
                              keyboardType: TextInputType.text,
                              hintText: 'Enter provider name',
                              controller: provider,
                              //   label: "",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the subject';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text('Policy Id *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(21, 43, 81, 1))),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              showElevation: false,
                              borderColor: const Color(0xFFDBE0E5),
                              keyboardType: TextInputType.text,
                              hintText: 'Enter policy id',
                              controller: policy,
                              // inputFormatters: [
                              //   // Only allow alphanumeric characters (letters and digits)
                              //   FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9]*$')),
                              // ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the subject';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Text('Effective Date *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(21, 43, 81, 1))),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              showElevation: false,
                              borderColor: const Color(0xFFDBE0E5),
                              onTap: () {
                                _selectDate(context);
                              },
                              keyboardType: TextInputType.text,
                              hintText: Provider.of<DateProvider>(context,
                                  listen: false)
                                  .dateFormat
                                  .toUpperCase(),
                              label: "Enter effective date",
                              controller: effective,
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
                            const SizedBox(
                              height: 10,
                            ),
                            const Text('Expiration Date *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(21, 43, 81, 1))),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                              showElevation: false,
                              borderColor: const Color(0xFFDBE0E5),
                              onTap: () {
                                _selectDateexpiration(context);
                              },
                              keyboardType: TextInputType.text,
                              hintText: Provider.of<DateProvider>(context,
                                  listen: false)
                                  .dateFormat
                                  .toUpperCase(),
                              label: "Enter expiration date",
                              controller: expiration,
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
                            const SizedBox(
                              height: 10,
                            ),
                            const Text('Liability Coverage *',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(21, 43, 81, 1))),
                            const SizedBox(
                              height: 10,
                            ),
                            // CustomTextField(
                            //   keyboardType: TextInputType.number,
                            //   hintText: '\$0.0',
                            //    label: "Enter Liability Coverage",
                            //    controller: liablity,
                            //
                            //   validator: (value) {
                            //     if (value == null || value.isEmpty) {
                            //       return 'please enter the subject';
                            //     }
                            //     return null;
                            //   },
                            // ),
                            CustomTextField(
                              showElevation: false,
                              borderColor: const Color(0xFFDBE0E5),
                              keyboardType: TextInputType.number,
                              hintText: '\$0.0',
                              controller: liablity,
                              suffixIcon: IconButton(icon: const Icon(Icons.check), color: blueColor, tooltip: 'Done', onPressed: () => FocusScope.of(context).unfocus()),
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
                            const SizedBox(
                              height: 10,
                            ),
                            const Text('Upload Insurance Document',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(21, 43, 81, 1))),
                            const SizedBox(
                              height: 10,
                            ),
                            // Empty state: tap-to-upload card (matches the
                            // work order / appliance upload cards).
                            if (_uploadedFileNames.isEmpty)
                              GestureDetector(
                                onTap: _showUploadOptions,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/icons/Upload.png',
                                        height: 50,
                                        width: 50,
                                      ),
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
                            // Filled state: show the uploaded file with a remove (X).
                            if (_uploadedFileNames.isNotEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file,
                                        color: Color(0xFF748097), size: 20),
                                    const SizedBox(width: 10),
                                    // Tapping the filename opens the document
                                    // (web parity: the filename is the tap
                                    // target there too). Kept separate from the
                                    // remove button so the X still clears it.
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => viewInsuranceDocument(
                                            context, _uploadedFileNames.first),
                                        child: Text(
                                          _uploadedFileNames.first,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF152B51),
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
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
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 30.0),
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
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                              ),
                              // onPressed: (){
                              //   //print("calling 111");
                              //   if(_formkey.currentState!.validate()){
                              //   //  print("calling 22");
                              //     editinsurance(widget.data.tenantInsuranceId!);
                              //   }
                              // },
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (!_formkey.currentState!
                                          .validate()) return;
                                      if (!_validateDates()) return;

                                      // Check if any field has changed
                                      final hasChanges = provider.text !=
                                              initialProvider ||
                                          policy.text != initialPolicy ||
                                          _convertToApiFormat(
                                                  effective.text.trim()) !=
                                              _convertToApiFormat(
                                                  initialEffective.trim()) ||
                                          _convertToApiFormat(
                                                  expiration.text.trim()) !=
                                              _convertToApiFormat(
                                                  initialExpiration.trim()) ||
                                          liablity.text != initialLiability ||
                                          !listEquals(_uploadedFileNames,
                                              initialUploadedFileNames);

                                      if (!hasChanges) {
                                        Navigator.of(context).pop(true);
                                        return;
                                      }

                                      setState(() => isLoading = true);
                                      try {
                                        await editinsurance(
                                            widget.data.tenantInsuranceId!);
                                      } catch (_) {
                                        // editinsurance already toasts the reason
                                      } finally {
                                        if (mounted) {
                                          setState(() => isLoading = false);
                                        }
                                      }
                                    },
                              child: isLoading
                                  ? Center(
                                      child: SpinKitFadingCircle(
                                        color: Colors.white,
                                        size: 30.0,
                                      ),
                                    )
                                  : const Text(
                                      'Save',
                                      style: TextStyle(
                                          color: Color(0xFFf7f8f9),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 12,
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFffffff),
                                    elevation: 0,
                                    side: const BorderSide(
                                        color: Color(0xFFDBE0E5)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10.0))),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: Color(0xFF748097),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                )),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }

  editinsurance(String TenantInsurance_id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    Map<String, dynamic> values = {
      "admin_id": admin_id!,
      "Provider": provider.text.trim(),
      "policy_id": policy.text.trim(),
      "EffectiveDate": _convertToApiFormat(effective.text.trim()),
      "ExpirationDate": _convertToApiFormat(expiration.text.trim()),
      // Web parity: LiabilityCoverage is sent as a number (the web sends 100,
      // not "100"). Falls back to the raw string only if parsing ever fails.
      "LiabilityCoverage": num.tryParse(liablity.text.trim()) ?? liablity.text.trim(),
      "Policy": _uploadedFileNames.length > 0 ? _uploadedFileNames.first : "",
    };

    final http.Response response = await apiPut(
      Uri.parse(
          '$Api_url/api/tenantinsurance/tenantinsurance/$TenantInsurance_id'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(values),
    );

    var responseData = json.decode(response.body);

    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      Navigator.of(context).pop(true);
      return responseData;
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to Insurance');
    }
  }
}
