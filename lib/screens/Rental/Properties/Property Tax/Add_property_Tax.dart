import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/clearable_date_picker.dart';
import '../../../../widgets/clearable_date_suffix.dart';
import '../../../../widgets/custom_drawer.dart';

class Add_property_Tax extends StatefulWidget {
  // pass the mortgage data to this screen from the previous screen
  final Map<String, dynamic>? taxData;
  final String? taxId; // For editing existing mortgages
  final String? propertyId; // Property ID for creating new tax records

  const Add_property_Tax({Key? key, this.taxId, this.taxData, this.propertyId})
      : super(key: key);

  @override
  State<Add_property_Tax> createState() => _Add_property_TaxState();
}

class _Add_property_TaxState extends State<Add_property_Tax> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _taxAuthorityController = TextEditingController();
  final _taxAmountController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _paidDateController = TextEditingController();
  final _statusController = TextEditingController();
  final _taxYearController = TextEditingController();
  final _notesController = TextEditingController();

  // Selected dates
  DateTime? _dueDate;
  DateTime? _paidDate;

  // Status options
  final List<String> _statusOptions = ['Paid', 'Overdue', 'Due'];

  // Year options (2000 to current year)
  List<String> _yearOptions = [];

  bool _isLoading = false;
  bool _hasValidated = false; // Track if validation has been attempted

  String? _getApiFormatDate(TextEditingController controller,
      DateTime? storedDate, DateProvider dateProvider) {
    // If we have the stored DateTime object, use it directly
    if (storedDate != null) {
      return DateFormat('yyyy-MM-dd').format(storedDate);
    }

    // Otherwise, parse from the controller text using DateProvider
    if (controller.text.isEmpty) return null;

    try {
      String displayDate = controller.text.trim();

      // Try to parse using DateProvider's dateFormat
      try {
        // Parse using the current date format from DateProvider
        DateTime parsedDate =
            DateFormat(dateProvider.dateFormat).parse(displayDate);
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      } catch (e) {
        // If that fails, try common formats
        List<String> dateFormats = [
          'yyyy-MM-dd',
          'MM/dd/yyyy',
          'MM-dd-yyyy',
          'dd/MM/yyyy',
          'dd-MM-yyyy',
        ];

        for (String format in dateFormats) {
          try {
            DateTime parsedDate = DateFormat(format).parse(displayDate);
            return DateFormat('yyyy-MM-dd').format(parsedDate);
          } catch (e) {
            continue;
          }
        }
      }

      return null; // Return null if parsing fails
    } catch (e) {
      logError('Error parsing date: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _generateYearOptions();

    if (widget.taxId != null && widget.taxData != null) {
      _populateFormWithData(widget.taxData!);
      // Don't show validation errors for pre-populated data
      _hasValidated = false;
    }
  }

  void dispose() {
    _taxAuthorityController.dispose();
    _taxAmountController.dispose();
    _assessmentController.dispose();
    _dueDateController.dispose();
    _paidDateController.dispose();
    _statusController.dispose();
    _taxYearController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _generateYearOptions() {
    int currentYear = DateTime.now().year;
    // Same range as web (TaxesInsuranceTab.jsx): current year back to 2020,
    // most recent first.
    _yearOptions = List.generate(
      currentYear - 2019,
      (index) => (currentYear - index).toString(),
    );
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, DateTime? initialDate) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final ClearableDatePickerResult? result = await showClearableDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result == null) return; // cancelled — keep the current value
    if (result.cleared) {
      _clearDate(controller);
      return;
    }
    final DateTime picked = result.date!;
    setState(() {
      String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
      if (controller == _dueDateController) {
        _dueDate = picked;
        controller.text = dateProvider.formatCurrentDate(apiFormatDate);
      } else if (controller == _paidDateController) {
        _paidDate = picked;
        controller.text = dateProvider.formatCurrentDate(apiFormatDate);
      }
    });
  }

  void _clearDate(TextEditingController controller) {
    setState(() {
      controller.clear();
      if (controller == _dueDateController) {
        _dueDate = null;
      } else if (controller == _paidDateController) {
        _paidDate = null;
      }
    });
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    final amountRegex = RegExp(r'^\$?\d+(\.\d{1,2})?$');
    if (!amountRegex.hasMatch(value)) {
      return 'Please enter a valid amount';
    }
    final amount = double.tryParse(value.replaceAll('\$', ''));
    if (amount == null || amount <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  void _populateFormWithData(Map<String, dynamic> taxData) {
    try {
      setState(() {
        // Tax Information
        _taxAuthorityController.text = taxData['tax_authority'] ?? '';
        _taxAmountController.text = taxData['tax_amount']?.toString() ?? '';
        _assessmentController.text =
            taxData['assessment_value']?.toString() ?? '';
        _taxYearController.text = taxData['tax_year']?.toString() ?? '';

        // Handle status - add to options if not present (for old data compatibility)
        String status = taxData['status'] ?? '';
        if (status.isNotEmpty && !_statusOptions.contains(status)) {
          _statusOptions.add(status);
        }
        _statusController.text = status;

        _notesController.text = taxData['notes'] ?? '';

        // Handle existing receipt
        _existingReceipt = taxData['receipt'];
        if (_existingReceipt != null && _existingReceipt!.isNotEmpty) {
          _uploadedFileNames.add(_existingReceipt!);
        }

        // Handle dates using DateProvider
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final dateProvider =
              Provider.of<DateProvider>(context, listen: false);
          if (taxData['due_date'] != null) {
            try {
              _dueDate = DateTime.parse(taxData['due_date']);
              _dueDateController.text =
                  dateProvider.formatCurrentDate(taxData['due_date']);
            } catch (e) {
              // Handle invalid date format
            }
          }
          if (taxData['paid_date'] != null) {
            try {
              _paidDate = DateTime.parse(taxData['paid_date']);
              _paidDateController.text =
                  dateProvider.formatCurrentDate(taxData['paid_date']);
            } catch (e) {
              // Handle invalid date format
            }
          }

          // Store initial values AFTER dates are set, using the same format as comparison
          String? normalizeDateForStorage(dynamic dateValue) {
            if (dateValue == null || dateValue.toString().isEmpty) return null;
            try {
              // If it's already in yyyy-MM-dd format, return as is
              if (dateValue.toString().length == 10 &&
                  dateValue.toString().contains('-')) {
                return dateValue.toString().substring(0, 10);
              }
              // Otherwise parse and format
              final date = DateTime.parse(dateValue.toString());
              return DateFormat('yyyy-MM-dd').format(date);
            } catch (e) {
              return null;
            }
          }

          // Store initial values in the same format as we'll compare
          _initialValues = {
            'tax_authority': _taxAuthorityController.text.trim(),
            'tax_amount': _taxAmountController.text.replaceAll('\$', '').trim(),
            'assessment_value':
                _assessmentController.text.replaceAll('\$', '').trim(),
            'tax_year': _taxYearController.text.trim(),
            'status': _statusController.text.trim(),
            'notes': _notesController.text.trim(),
            'due_date': normalizeDateForStorage(taxData['due_date']),
            'paid_date': normalizeDateForStorage(taxData['paid_date']),
            'receipt': _existingReceipt,
          };

        });
      });
    } catch (e) {
      logError('Error populating form: $e');
    }
  }

  void _saveForm() async {

    // Set validation flag to show error messages
    setState(() {
      _hasValidated = true;
    });

    // Validate required fields only (Tax Year and Tax Amount)
    bool isValid = true;

    // Validate Tax Year (required)
    if (_taxYearController.text.trim().isEmpty) {
      isValid = false;
    }

    // Validate Tax Amount (required)
    if (_taxAmountController.text.trim().isEmpty) {
      isValid = false;
    } else {
      final amountRegex = RegExp(r'^\$?\d+(\.\d{1,2})?$');
      if (!amountRegex.hasMatch(_taxAmountController.text)) {
        isValid = false;
      } else {
        final amount =
            double.tryParse(_taxAmountController.text.replaceAll('\$', ''));
        if (amount == null || amount <= 0) {
          isValid = false;
        }
      }
    }

    if (!isValid) {
      return;
    }


    // Get DateProvider for date conversion
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    // Check if in edit mode and no changes were made
    if (widget.taxId != null && _initialValues != null) {
      final currentDueDate =
          _getApiFormatDate(_dueDateController, _dueDate, dateProvider);
      final currentPaidDate =
          _getApiFormatDate(_paidDateController, _paidDate, dateProvider);
      final currentReceipt =
          _uploadedFileNames.isNotEmpty ? _uploadedFileNames.first : null;

      final currentValues = {
        'tax_authority': _taxAuthorityController.text.trim(),
        'tax_amount': _taxAmountController.text.replaceAll('\$', ''),
        'assessment_value': _assessmentController.text.replaceAll('\$', ''),
        'tax_year': _taxYearController.text.trim(),
        'status': _statusController.text.trim(),
        'notes': _notesController.text.trim(),
        'due_date': currentDueDate,
        'paid_date': currentPaidDate,
        'receipt': currentReceipt,
      };

      // Compare values (normalize amounts for comparison)
      bool hasChanges = false;

      // Helper function to normalize strings (handle null/empty)
      String normalizeString(dynamic value) {
        if (value == null) return '';
        return value.toString().trim();
      }

      // Helper function to normalize amounts (compare as doubles)
      bool compareAmounts(dynamic initial, String? current) {
        if (current == null) current = '';
        if (initial == null &&
            (current.isEmpty || current == '0' || current == '0.0'))
          return true;
        if (initial == null) return false;

        final initialStr = initial.toString().replaceAll('\$', '').trim();
        final currentStr = current.replaceAll('\$', '').trim();

        if (initialStr.isEmpty &&
            (currentStr.isEmpty || currentStr == '0' || currentStr == '0.0'))
          return true;
        if (initialStr.isEmpty || currentStr.isEmpty) return false;

        final initialAmount = double.tryParse(initialStr) ?? 0.0;
        final currentAmount = double.tryParse(currentStr) ?? 0.0;

        return initialAmount == currentAmount;
      }

      // Helper function to normalize dates (handle null and format)
      String? normalizeDate(dynamic value) {
        if (value == null || value.toString().isEmpty) return null;
        try {
          String dateStr = value.toString().trim();
          // If it's already in yyyy-MM-dd format, return as is
          if (dateStr.length >= 10 && dateStr.contains('-')) {
            return dateStr.substring(0, 10);
          }
          // Try to parse and format
          final date = DateTime.parse(dateStr);
          return DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          return null;
        }
      }

      // Compare each field independently (not using else if to check all fields)
      String initialAuth = normalizeString(_initialValues!['tax_authority']);
      String currentAuth = normalizeString(currentValues['tax_authority']);
      if (initialAuth != currentAuth) {
        hasChanges = true;
      }

      if (!compareAmounts(
          _initialValues!['tax_amount'], currentValues['tax_amount'])) {
        hasChanges = true;
      }

      if (!compareAmounts(_initialValues!['assessment_value'],
          currentValues['assessment_value'])) {
        hasChanges = true;
      }

      String initialYear = normalizeString(_initialValues!['tax_year']);
      String currentYear = normalizeString(currentValues['tax_year']);
      if (initialYear != currentYear) {
        hasChanges = true;
      }

      String initialStatus = normalizeString(_initialValues!['status']);
      String currentStatus = normalizeString(currentValues['status']);
      if (initialStatus != currentStatus) {
        hasChanges = true;
      }

      String initialNotes = normalizeString(_initialValues!['notes']);
      String currentNotes = normalizeString(currentValues['notes']);
      if (initialNotes != currentNotes) {
        hasChanges = true;
      }

      String? initialDueDate = normalizeDate(_initialValues!['due_date']);
      String? currentDueDateNormalized =
          normalizeDate(currentValues['due_date']);
      if (initialDueDate != currentDueDateNormalized) {
        hasChanges = true;
      }

      String? initialPaidDate = normalizeDate(_initialValues!['paid_date']);
      String? currentPaidDateNormalized =
          normalizeDate(currentValues['paid_date']);
      if (initialPaidDate != currentPaidDateNormalized) {
        hasChanges = true;
      }

      String initialReceipt = normalizeString(_initialValues!['receipt']);
      String currentReceiptNormalized =
          normalizeString(currentValues['receipt']);
      if (initialReceipt != currentReceiptNormalized) {
        hasChanges = true;
      }


      if (!hasChanges) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: "No changes were made",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 2,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
        // Explicitly return to prevent API call
        return;
      } else {
      }
    }

    // Only reach here if creating new record OR if changes were detected in edit mode
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');


      // Prepare the tax data according to your API structure
      final taxData = {
        'propertyId': widget.propertyId, // Include property ID
        'admin_id': id, // Add admin_id field
        'tax_authority': _taxAuthorityController.text.trim(),
        'tax_amount':
            double.tryParse(_taxAmountController.text.replaceAll('\$', '')) ??
                0.0,
        'assessment_value':
            double.tryParse(_assessmentController.text.replaceAll('\$', '')) ??
                0.0,
        'tax_year': _taxYearController.text.trim(),
        'due_date':
            _getApiFormatDate(_dueDateController, _dueDate, dateProvider),
        'paid_date':
            _getApiFormatDate(_paidDateController, _paidDate, dateProvider),
        'status': _statusController.text.trim(), // Keep original capitalization
        'notes': _notesController.text.trim(),
        'receipt':
            _uploadedFileNames.isNotEmpty ? _uploadedFileNames.first : null,
      };


      http.Response response;
      String apiUrl = '$Api_url/api/taxes';


      if (widget.taxId != null) {
        // Update existing tax (PUT)
        response = await http
            .put(
              Uri.parse('$apiUrl/${widget.taxId}'),
              headers: {
                'Content-Type': 'application/json',
                'authorization': 'CRM $token',
                'id': 'CRM $id',
              },
              body: json.encode(taxData),
            )
            .timeout(const Duration(seconds: 30));
      } else {
        // Create new tax (POST)
        response = await http
            .post(
              Uri.parse(apiUrl),
              headers: {
                'Content-Type': 'application/json',
                'authorization': 'CRM $token',
                'id': 'CRM $id',
              },
              body: json.encode(taxData),
            )
            .timeout(const Duration(seconds: 30));
      }


      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.taxId != null
                  ? 'Tax record updated successfully!'
                  : 'Tax record created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        // Reset validation flag if form submission fails
        setState(() {
          _hasValidated = false;
        });
        if (mounted) {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['message'] ?? 'Failed to save tax record';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      logError('=== EXCEPTION ===');
      logError('Exception occurred: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving tax record: ${friendlyErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  //for image
  File? _image;
  bool isLoading = false;
  List<File> _images = [];
  String? _uploadedFileName;
  List<String> _uploadedFileNames = [];
  List<String> _imageUrls = [];
  String? _existingReceipt; // Store existing receipt filename from API

  // Store initial values for change detection in edit mode
  Map<String, dynamic>? _initialValues;

  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';
    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          uploadUrl,
        ));
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _images.add(File(image.path));
      });
      _uploadImage(File(image.path));
    }
  }

  Future<void> _pickFile() async {
    try {
      // Open file picker directly with all supported file types
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'gif',
          'bmp',
          'tiff',
          'webp'
        ],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        setState(() {
          _images.add(file);
        });
        _uploadImage(file);
      }
    } catch (e) {
      logError('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: ${friendlyErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isValidFileType(String fileName) {
    final supportedExtensions = [
      '.pdf',
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.tiff',
      '.webp'
    ];
    final extension =
        fileName.toLowerCase().substring(fileName.lastIndexOf('.'));
    return supportedExtensions.contains(extension);
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      // Validate file type
      if (!_isValidFileType(imageFile.path)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unsupported file type. Please select PDF, JPG, PNG, GIF, BMP, TIFF, or WEBP files.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String? fileName = await uploadImage(imageFile);
      if (fileName != null) {
        setState(() {
          _uploadedFileNames.add(fileName);
          _uploadedFileName = fileName;
          _imageUrls.add(fileName);
        });
      }
    } catch (e) {
      logError('Image upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File upload failed: ${friendlyErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5.0),
                child: Container(
                  height: 50.0,
                  width: double.infinity,
                  padding: EdgeInsets.only(top: 10, left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0),
                    color: blueColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, 1.0),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                  //if appliance is not null then show edit else show add
                  child: Text(
                    widget.taxId != null ? 'Edit Tax Record' : 'Add Tax Record',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(widget.taxId != null
                        ? 'Update tax record details'
                        : 'Add new tax record for this property'),
                    const SizedBox(height: 16),
                    // Web parity: Tax Year is a dropdown of valid years (no free
                    // text), so an oversized/garbled value can't be entered.
                    _buildDropdownField(
                      controller: _taxYearController,
                      label: 'Tax Year *',
                      hint: 'Select tax year',
                      items: _yearOptions,
                      validator: (value) =>
                          _validateRequired(value, 'Tax year'),
                    ),

                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _taxAmountController,
                      label: 'Tax Amount *',
                      hint: '\$ Enter Tax amount',
                      keyboardType: TextInputType.number,
                      validator: _validateAmount,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    _buildTextField(
                      controller: _taxAuthorityController,
                      label: 'Tax Authority',
                      hint: 'Enter tax authority',
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    _buildTextField(
                      controller: _assessmentController,
                      label: 'Assessment Value',
                      hint: '\$ Enter assessment value',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      controller: _dueDateController,
                      label: 'Due Date',
                      hint: Provider.of<DateProvider>(context, listen: false)
                          .dateFormat
                          .toUpperCase(),
                      onTap: () =>
                          _selectDate(context, _dueDateController, _dueDate),
                      onClear: () => _clearDate(_dueDateController),
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                      controller: _paidDateController,
                      label: 'Paid Date',
                      hint: Provider.of<DateProvider>(context, listen: false)
                          .dateFormat
                          .toUpperCase(),
                      onTap: () =>
                          _selectDate(context, _paidDateController, _paidDate),
                      onClear: () => _clearDate(_paidDateController),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      controller: _statusController,
                      label: 'Status',
                      hint: 'Select status',
                      items: _statusOptions,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes',
                      hint: 'Enter any additional notes (optional)',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Text("Receipt (Optional)"),
                    const SizedBox(height: 8),
                    if (_images.isEmpty && _existingReceipt == null)
                      GestureDetector(
                        onTap: () {
                          _pickFile().then((_) {
                            setState(() {});
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey.shade300,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Icon(Icons.upload,
                              //     size: 40, color: Colors.grey[600]),
                              Image.asset(
                                'assets/icons/Upload.png',
                                height: 50,
                                width: 50,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Click to upload receipt',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Supported File Types: PDF, JPG, PNG, GIF, BMP, TIFF, WEBP',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_images.isEmpty && _existingReceipt == null)
                      SizedBox(height: 16),
                    if (_images.isNotEmpty || _existingReceipt != null) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 15,
                            ),
                            // Show receipt filenames as text
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show existing receipt filename
                                if (_existingReceipt != null)
                                  Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _existingReceipt!,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _existingReceipt = null;
                                              _uploadedFileNames.removeWhere(
                                                  (name) =>
                                                      name == _existingReceipt);
                                            });
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Show newly uploaded file names
                                ...List.generate(_images.length, (index) {
                                  String fileName =
                                      _uploadedFileNames.length > index
                                          ? _uploadedFileNames[index]
                                          : 'File ${index + 1}';
                                  return Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                      border:
                                          Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            fileName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _images.removeAt(index);
                                              if (index <
                                                  _uploadedFileNames.length) {
                                                _uploadedFileNames
                                                    .removeAt(index);
                                              }
                                            });
                                          },
                                          child: Icon(
                                            Icons.close,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 32),
                    Container(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: blueColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: blueColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: _isLoading
                                  ? SpinKitFadingCircle(
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : Text(
                                      widget.taxId != null ? 'Update' : 'Save',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Action Buttons
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: blueColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: null, // Remove built-in validation
          inputFormatters: inputFormatters ?? [],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: suffix,
          ),
        ),
        if (validator != null && _hasValidated)
          Builder(
            builder: (context) {
              final errorText = validator(controller.text);
              if (errorText != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          validator: null, // Remove built-in validation
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: ClearableDateSuffix(
              controller: controller,
              onPick: onTap,
              onClear: onClear ?? controller.clear,
              icon: Icons.calendar_today,
              iconColor: blueColor,
            ),
          ),
        ),
        if (validator != null && _hasValidated)
          Builder(
            builder: (context) {
              final errorText = validator(controller.text);
              if (errorText != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Widget _buildDropdownField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required List<String> items,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonHideUnderline(
          child: Material(
            // elevation: 3,
            borderRadius: BorderRadius.circular(8),
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: Row(
                children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8A95A8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              value: controller.text.isEmpty
                  ? null
                  : (items.contains(controller.text) ? controller.text : null),
              onChanged: (String? newValue) {
                setState(() {
                  controller.text = newValue ?? '';
                });
              },
              buttonStyleData: ButtonStyleData(
                height: 50,
                padding: const EdgeInsets.only(left: 14, right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                  ),
                  color: Colors.white,
                ),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
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
                padding: EdgeInsets.only(left: 14, right: 14),
              ),
            ),
          ),
        ),
        if (validator != null && _hasValidated)
          Builder(
            builder: (context) {
              final errorText = validator(controller.text);
              if (errorText != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    errorText,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
