import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:io';
import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:email_validator/email_validator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../constant/constant.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/appbar.dart';
import 'package:three_zero_two_property/VendorModule/widgets/appbar.dart'
    as vendor_ui;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as staff_ui;
import 'package:three_zero_two_property/TenantsModule/widgets/appbar.dart'
    as tenant_ui;
import '../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    as staff_drawer;
import 'package:three_zero_two_property/TenantsModule/widgets/custom_drawer.dart'
    as tenant_drawer;
import '../../repository/ContactRepository.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // This screen is shared by all roles. Only Admin may show the Admin
  // appbar/drawer — other roles (Vendor/Tenant/Staff) get a plain scoped
  // AppBar so Admin-level menus/navigation never leak (CRM: vendor avatar
  // menu leak after Contact Us).
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _role = prefs.getString('role'));
    }
  }

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Form state
  String? _selectedCategory;
  String? _selectedPriority;
  List<File> _attachments = [];
  List<String> _uploadedFileNames = [];
  bool _isSubmitting = false;
  String? _categoryError;
  String? _priorityError;
  String? _nameError;
  String? _emailError;
  String? _subjectError;
  String? _descriptionError;

  // Dropdown options
  final List<String> _categories = [
    'Bug',
    'Question',
    'Feature Request',
    'Billing',
    'Other'
  ];

  final List<String> _priorities = ['Low', 'Normal', 'High', 'Urgent'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Validation methods
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    // Web parity: ContactSupport.jsx only requires the name (yup.required),
    // no character rule — so apostrophes, hyphens and accented letters pass.
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    if (!EmailValidator.validate(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateSubject(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a subject';
    }
    if (value.trim().length < 5) {
      return 'Subject must be at least 5 characters';
    }
    if (value.trim().length > 100) {
      return 'Subject must be less than 100 characters';
    }
    return null;
  }

  String? _validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a description';
    }
    if (value.trim().length < 10) {
      return 'Description must be at least 10 characters';
    }
    if (value.trim().length > 1000) {
      return 'Description must be less than 1000 characters';
    }
    return null;
  }

  String? _validateCategory(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a category';
    }
    return null;
  }

  String? _validatePriority(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a priority';
    }
    return null;
  }

  // Upload image function (similar to work order)
  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(uploadUrl),
    );
    request.files.add(
      await http.MultipartFile.fromPath('files', imageFile.path),
    );

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

  // Upload file and add to uploaded names
  Future<void> _uploadFile(File file) async {
    try {
      String? fileName = await uploadImage(file);
      if (fileName != null) {
        setState(() {
          _uploadedFileNames.add(fileName);
        });
      }
    } catch (e) {
      logError('File upload failed: $e');
      Fluttertoast.showToast(
        msg: 'Failed to upload file: ${file.path.split('/').last}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  // File handling methods
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'pdf',
          'doc',
          'docx',
          'txt'
        ],
      );

      if (result != null) {
        List<File> newFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();

        // Check file count limit
        if (_attachments.length + newFiles.length > 5) {
          Fluttertoast.showToast(
            msg: 'Maximum 5 files allowed',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          return;
        }

        // Check file size limit (10MB per file)
        List<File> validFiles = [];
        for (File file in newFiles) {
          try {
            if (await file.exists()) {
              int fileSizeInBytes = await file.length();
              double fileSizeInMB = fileSizeInBytes / (1024 * 1024);

              if (fileSizeInMB > 10) {
                Fluttertoast.showToast(
                  msg:
                      'File ${file.path.split('/').last} is too large. Maximum size is 10MB.',
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.BOTTOM,
                );
                continue; // Skip this file but continue with others
              }
              validFiles.add(file);
            }
          } catch (e) {
            logError('Error checking file size: $e');
            // Continue with other files
          }
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _attachments.addAll(validFiles);
          });

          // Upload each file
          for (File file in validFiles) {
            await _uploadFile(file);
          }

          Fluttertoast.showToast(
            msg: '${validFiles.length} file(s) added successfully',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error picking files: ${friendlyErrorMessage(e)}',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      if (index < _uploadedFileNames.length) {
        _uploadedFileNames.removeAt(index);
      }
    });
  }

  // Form submission
  Future<void> _submitForm() async {
    // Clear previous errors
    setState(() {
      _nameError = null;
      _emailError = null;
      _subjectError = null;
      _descriptionError = null;
      _categoryError = null;
      _priorityError = null;
    });

    // Validate each field
    String? nameError = _validateName(_nameController.text);
    String? emailError = _validateEmail(_emailController.text);
    String? subjectError = _validateSubject(_subjectController.text);
    String? descriptionError =
        _validateDescription(_descriptionController.text);

    // Check if any field has errors
    bool hasErrors = false;
    setState(() {
      if (nameError != null) {
        _nameError = nameError;
        hasErrors = true;
      }
      if (emailError != null) {
        _emailError = emailError;
        hasErrors = true;
      }
      if (subjectError != null) {
        _subjectError = subjectError;
        hasErrors = true;
      }
      if (descriptionError != null) {
        _descriptionError = descriptionError;
        hasErrors = true;
      }
      if (_selectedCategory == null) {
        _categoryError = 'Please select a category';
        hasErrors = true;
      }
      if (_selectedPriority == null) {
        _priorityError = 'Please select a priority';
        hasErrors = true;
      }
    });

    if (hasErrors) {
      return;
    }

    // All validations passed, submit form
    await submitContactForm();
  }

  // API function to submit contact form
  Future<void> submitContactForm() async {
    setState(() {
      _isSubmitting = true;
    });

    ContactRepository()
        .submitContactForm(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      subject: _subjectController.text.trim(),
      category: _selectedCategory!,
      priority: _selectedPriority!,
      description: _descriptionController.text.trim(),
      attachments: _uploadedFileNames.isNotEmpty ? _uploadedFileNames : null,
    )
        .then((value) {
      setState(() {
        _isSubmitting = false;
      });
      // Clear form
      _clearForm();
    }).catchError((e) {
      setState(() {
        _isSubmitting = false;
      });
      Fluttertoast.showToast(
        msg: 'Failed to submit ticket. Please try again.',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    });
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedPriority = null;
      _attachments.clear();
      _uploadedFileNames.clear();
      _categoryError = null;
      _priorityError = null;
      _nameError = null;
      _emailError = null;
      _subjectError = null;
      _descriptionError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = _role == 'Admin';
    final bool isVendor = _role == 'Vendor';
    final bool isStaff = _role == 'Staffmember';
    final bool isTenant = _role == 'Tenant';
    return Scaffold(
      backgroundColor: Colors.white,
      // Admin keeps the full Admin appbar + drawer (unchanged behaviour).
      // Vendor/Tenant/Staff get a plain back-arrow AppBar with no drawer and
      // no avatar menu, so Admin navigation cannot leak into their session.
      // Each role gets its OWN navigation drawer (opened by the app bar's
      // hamburger). Vendor's app bar has no hamburger, so it needs none.
      drawer: isAdmin
          ? CustomDrawer(
              currentpage: "Contact Support",
              dropdown: false,
            )
          : isStaff
              ? staff_drawer.CustomDrawerStaff(
                  currentpage: "Contact Support",
                  dropdown: false,
                )
              : isTenant
                  ? tenant_drawer.CustomDrawer(
                      currentpage: "Contact Support",
                    )
                  : null,
      // Each role shows its OWN real app bar (so its avatar/menu is correct and
      // nothing from another role can leak). Back navigation is provided by the
      // back button beside "Contact Support" in the body below.
      appBar: isAdmin
          ? widget_302.App_Bar(context: context)
          : isVendor
              ? vendor_ui.widget_302.App_Bar(
                  context: context,
                  onDrawerIconPressed: () {},
                )
              : isStaff
                  ? staff_ui.widget_302_Staff.App_Bar(context: context)
                  : isTenant
                      ? tenant_ui.widget_302.App_Bar(
                          context: context,
                          onDrawerIconPressed: () {},
                        )
                      : AppBar(
                          // Fallback for an unknown role: plain branded bar.
                          backgroundColor: blueColor,
                          elevation: 1,
                          centerTitle: false,
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () =>
                                Navigator.of(context).maybePop(),
                          ),
                          title: const Text(
                            'Contact Us',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: report-screen style back button beside the title.
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.black87,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: blueColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tell us what\'s going on. We\'ll get back to you shortly.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 20),

              // Name Field
              Text(
                'Name *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              CustomTextField(
                controller: _nameController,
                hintText: 'Your name',
                keyboardType: TextInputType.name,
                showErrorInTooltip: false,
                hasError: _nameError != null,
                errorMessage: _nameError ?? '',
                onChanged: (value) {
                  if (_nameError != null) {
                    setState(() {
                      _nameError = null;
                    });
                  }
                },
              ),
              SizedBox(height: 20),

              // Email Field
              Text(
                'Email *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              CustomTextField(
                controller: _emailController,
                hintText: 'you@company.com',
                keyboardType: TextInputType.emailAddress,
                showErrorInTooltip: false,
                hasError: _emailError != null,
                errorMessage: _emailError ?? '',
                onChanged: (value) {
                  if (_emailError != null) {
                    setState(() {
                      _emailError = null;
                    });
                  }
                },
              ),
              SizedBox(height: 20),

              // Subject Field
              Text(
                'Subject *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              CustomTextField(
                controller: _subjectController,
                hintText: 'Brief summary',
                keyboardType: TextInputType.text,
                showErrorInTooltip: false,
                hasError: _subjectError != null,
                errorMessage: _subjectError ?? '',
                onChanged: (value) {
                  if (_subjectError != null) {
                    setState(() {
                      _subjectError = null;
                    });
                  }
                },
              ),
              SizedBox(height: 20),

              // Category Dropdown
              Text(
                'Category *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _categoryError != null
                        ? Colors.red.shade300
                        : Color(0xFF8A95A8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: DropdownButtonFormField2<String>(
                  isExpanded: false,
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  hint: Text(
                    'Select category',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                  ),
                  buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 5), // ✅ FIX
                  ),
                  items: _categories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                      _categoryError =
                          null; // Clear error when selection is made
                    });
                  },
                  validator: _validateCategory,
                ),
              ),
              if (_categoryError != null) ...[
                SizedBox(height: 8),
                Text(
                  _categoryError!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
              SizedBox(height: 20),

              // Priority Dropdown
              Text(
                'Priority *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _priorityError != null
                        ? Colors.red.shade300
                        : Color(0xFF8A95A8),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: DropdownButtonFormField2<String>(
                  value: _selectedPriority,
                  isExpanded: false,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  hint: Text(
                    'Select priority',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                  ),
                  buttonStyleData: const ButtonStyleData(
                    padding: EdgeInsets.symmetric(horizontal: 5), // ✅ FIX
                  ),
                  iconStyleData: IconStyleData(
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  items: _priorities.map((String priority) {
                    return DropdownMenuItem<String>(
                      value: priority,
                      child: Text(
                        priority,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 14,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedPriority = newValue;
                      _priorityError =
                          null; // Clear error when selection is made
                    });
                  },
                  validator: _validatePriority,
                ),
              ),
              if (_priorityError != null) ...[
                SizedBox(height: 8),
                Text(
                  _priorityError!,
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
              SizedBox(height: 20),

              // Description Field
              Text(
                'Description *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              CustomTextField(
                controller: _descriptionController,
                hintText: 'Describe the issue in detail',
                keyboardType: TextInputType.multiline,
                maxLines: 5,
                showErrorInTooltip: false,
                hasError: _descriptionError != null,
                errorMessage: _descriptionError ?? '',
                onChanged: (value) {
                  if (_descriptionError != null) {
                    setState(() {
                      _descriptionError = null;
                    });
                  }
                },
              ),
              SizedBox(height: 20),
              if (_attachments.isEmpty) ...[
                // Attachments Section
                Text(
                  'Attachments (Maximum of 5)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),

                // File Upload Button
                GestureDetector(
                  onTap: _pickFiles,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color(0xFF8A95A8)!,
                        style: BorderStyle.solid,
                        width: 2,
                      ),
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 40,
                          color: blueColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Click to upload files',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: blueColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Each file must be 10 MB or less. Supported: images, PDF, documents',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              // Attached Files List
              if (_attachments.isNotEmpty) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Attached Files:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    Spacer(),
                    if (_attachments.length < 10)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        // crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                              onTap: () {
                                _pickFiles();
                              },
                              child: Container(
                                  height: 20,
                                  width: 20,
                                  decoration: BoxDecoration(
                                    color: blueColor,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 15,
                                  ))),
                        ],
                      ),
                  ],
                ),
                SizedBox(height: 10),
                ..._attachments.asMap().entries.map((entry) {
                  int index = entry.key;
                  File file = entry.value;
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF8A95A8)!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_file,
                              color: blueColor,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.path.split('/').last,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeAttachment(index),
                              child: Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: _isSubmitting
                      ? SpinKitFadingCircle(
                          color: Colors.white,
                          size: 25.0,
                        )
                      : Text(
                          "Submit Ticket",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 15
                                  : 15.5),
                        ),
                ),
              ),

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
