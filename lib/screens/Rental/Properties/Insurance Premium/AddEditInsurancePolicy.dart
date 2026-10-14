import 'package:email_validator/email_validator.dart';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../../../../constant/constant.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/clearable_date_picker.dart';
import '../../../../widgets/clearable_date_suffix.dart';
import '../../../../widgets/custom_drawer.dart';
import '../../../../Model/PropertyInsuranceModel.dart';

class AddEditInsurancePolicy extends StatefulWidget {
  final String propertyId;
  final String? policyId; // For editing existing policy
  final PropertyInsuranceData? policyData; // For editing existing policy

  const AddEditInsurancePolicy({
    Key? key,
    required this.propertyId,
    this.policyId,
    this.policyData,
  }) : super(key: key);

  @override
  State<AddEditInsurancePolicy> createState() => _AddEditInsurancePolicyState();
}

class _AddEditInsurancePolicyState extends State<AddEditInsurancePolicy> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Section 1: Policy Identification Information
  final _insuranceCompanyNameController = TextEditingController();
  final _policyNumberController = TextEditingController();
  String? _selectedPolicyType;
  String? _selectedFormNumber;

  // Section 2: Insured Party Details
  final _namedInsuredController = TextEditingController();
  final _mailingAddressController = TextEditingController();
  final _additionalInsuredController = TextEditingController();
  final _premiumAmountController = TextEditingController();

  // Section 3: Coverage Dates
  final _effectiveDateController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _cancellationNoticeDateController = TextEditingController();
  DateTime? _effectiveDate;
  DateTime? _expirationDate;
  DateTime? _cancellationNoticeDate;

  // Section 4: Financial Information
  final _deductibleController = TextEditingController();
  String? _selectedPaymentTerms;

  // Section 5: Claims and Customer Service Information
  final _agentNameController = TextEditingController();
  final _agentPhoneController = TextEditingController();
  final _agentEmailController = TextEditingController();
  final _brokerNameController = TextEditingController();
  final _claimsContactInfoController = TextEditingController();
  final _underwritingOfficeController = TextEditingController();
  String? _selectedStatus;
  final _notesController = TextEditingController();

  // Policy Type options (common insurance types)
  final List<String> _policyTypeOptions = [
    'Homeowners Insurance (HO Policies)',
    'Landlord or Dwelling Policies (DP Policies)',
    'Specialty Property Insurance',
    'Commercial Property Insurance',
  ];

  // Form Number options (will be populated based on policy type)
  List<String> _formNumberOptions = [];

  // Method to populate form number options based on policy type
  void _updateFormNumberOptions(String? policyType) {
    setState(() {
      _formNumberOptions = [];
      if (policyType == null) {
        return;
      }

      if (policyType == 'Homeowners Insurance (HO Policies)') {
        _formNumberOptions = [
          'HO-1 (Basic Form)',
          'HO-2 (Broad Form)',
          'HO-3 (Special Form)',
          'HO-4 (Contents Broad Form)',
          'HO-5 (Comprehensive Form)',
          'HO-6 (Unit-Owners Form)',
          'HO-8 (Modified Coverage Form)',
        ];
      } else if (policyType == 'Landlord or Dwelling Policies (DP Policies)') {
        _formNumberOptions = [
          'DP-1 (Basic Form)',
          'DP-2 (Broad Form)',
          'DP-3 (Special Form)',
          'DP-4 (Contents Broad Form)',
          'DP-5 (Comprehensive Form)',
        ];
      } else if (policyType == 'Specialty Property Insurance') {
        _formNumberOptions = [
          'SP-1 (Basic Specialty)',
          'SP-2 (Broad Specialty)',
          'SP-3 (Special Specialty)',
          'SP-4 (Comprehensive Specialty)',
        ];
      } else if (policyType == 'Commercial Property Insurance') {
        _formNumberOptions = [
          'CP-1 (Basic Commercial)',
          'CP-2 (Broad Commercial)',
          'CP-3 (Special Commercial)',
          'CP-4 (Comprehensive Commercial)',
          'CP-5 (Commercial Package)',
        ];
      }
    });
  }

  // Payment Terms options
  final List<String> _paymentTermsOptions = [
    'Monthly',
    'Quarterly',
    'Semi-Annual',
    'Annual',
  ];

  // Status options
  final List<String> _statusOptions = [
    'Active',
    'Expired',
    'Cancelled',
    'Pending',
  ];

  bool _isLoading = false;
  bool _hasValidated = false;
  String? _generalError;

  String _convertToApiFormat(String displayDate) {
    if (displayDate.isEmpty) return "";
    try {
      DateTime? parsedDate;

      // Try to parse the date using common formats
      List<String> dateFormats = [
        'yyyy-MM-dd',
        'yyyy-MMM-dd',
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'dd/MM/yyyy',
        'dd-MM-yyyy',
        'dd/MMM/yyyy'
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
        // Convert to ISO format with time: "2026-01-15T00:00:00.000Z"
        String dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
        return '${dateStr}T00:00:00.000Z';
      } else {
        return displayDate;
      }
    } catch (e) {
      return displayDate;
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.policyId != null && widget.policyData != null) {
      _populateFormWithData(widget.policyData!);
      _hasValidated = false;
    }
    // Initialize form number options if policy type is already set
    if (_selectedPolicyType != null) {
      _updateFormNumberOptions(_selectedPolicyType);
    }
  }

  @override
  void dispose() {
    _insuranceCompanyNameController.dispose();
    _policyNumberController.dispose();
    _namedInsuredController.dispose();
    _mailingAddressController.dispose();
    _additionalInsuredController.dispose();
    _premiumAmountController.dispose();
    _effectiveDateController.dispose();
    _expirationDateController.dispose();
    _cancellationNoticeDateController.dispose();
    _deductibleController.dispose();
    _agentNameController.dispose();
    _agentPhoneController.dispose();
    _agentEmailController.dispose();
    _brokerNameController.dispose();
    _claimsContactInfoController.dispose();
    _underwritingOfficeController.dispose();
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _populateFormWithData(PropertyInsuranceData policy) {
    setState(() {
      _insuranceCompanyNameController.text = policy.insuranceCompanyName ?? '';
      _policyNumberController.text = policy.policyNumber ?? '';
      // Validate that policy type exists in options before setting it
      if (policy.policyType != null && 
          _policyTypeOptions.contains(policy.policyType)) {
        _selectedPolicyType = policy.policyType;
      } else {
        _selectedPolicyType = null;
      }
      // Update form number options based on policy type (directly update since we're in setState)
      _formNumberOptions = [];
      if (_selectedPolicyType != null) {
        if (_selectedPolicyType == 'Homeowners Insurance (HO Policies)') {
          _formNumberOptions = [
            'HO-1 (Basic Form)',
            'HO-2 (Broad Form)',
            'HO-3 (Special Form)',
            'HO-4 (Contents Broad Form)',
            'HO-5 (Comprehensive Form)',
            'HO-6 (Unit-Owners Form)',
            'HO-8 (Modified Coverage Form)',
          ];
        } else if (_selectedPolicyType == 'Landlord or Dwelling Policies (DP Policies)') {
          _formNumberOptions = [
            'DP-1 (Basic Form)',
            'DP-2 (Broad Form)',
            'DP-3 (Special Form)',
            'DP-4 (Contents Broad Form)',
            'DP-5 (Comprehensive Form)',
          ];
        } else if (_selectedPolicyType == 'Specialty Property Insurance') {
          _formNumberOptions = [
            'SP-1 (Basic Specialty)',
            'SP-2 (Broad Specialty)',
            'SP-3 (Special Specialty)',
            'SP-4 (Comprehensive Specialty)',
          ];
        } else if (_selectedPolicyType == 'Commercial Property Insurance') {
          _formNumberOptions = [
            'CP-1 (Basic Commercial)',
            'CP-2 (Broad Commercial)',
            'CP-3 (Special Commercial)',
            'CP-4 (Comprehensive Commercial)',
            'CP-5 (Commercial Package)',
          ];
        }
        // Validate that form number exists in options before setting it
        if (policy.formNumber != null && 
            _formNumberOptions.contains(policy.formNumber)) {
          _selectedFormNumber = policy.formNumber;
        } else {
          _selectedFormNumber = null;
        }
      } else {
        _selectedFormNumber = null;
      }
      _namedInsuredController.text = policy.namedInsured ?? '';
      _mailingAddressController.text = policy.mailingAddress ?? '';
      _additionalInsuredController.text = policy.additionalInsured ?? '';
      _premiumAmountController.text = policy.premiumAmount?.toString() ?? '';
      _deductibleController.text = policy.deductible?.toString() ?? '';
      // Validate that payment terms exists in options before setting it
      if (policy.paymentTerms != null && 
          _paymentTermsOptions.contains(policy.paymentTerms)) {
        _selectedPaymentTerms = policy.paymentTerms;
      } else {
        _selectedPaymentTerms = null;
      }
      _agentNameController.text = policy.agentName ?? '';
      _agentPhoneController.text = policy.agentPhone ?? '';
      _agentEmailController.text = policy.agentEmail ?? '';
      _brokerNameController.text = policy.brokerName ?? '';
      _claimsContactInfoController.text = policy.claimsContactInfo ?? '';
      _underwritingOfficeController.text = policy.underwritingOffice ?? '';
      // Validate that status exists in options before setting it
      if (policy.status != null && 
          _statusOptions.contains(policy.status)) {
        _selectedStatus = policy.status;
      } else {
        _selectedStatus = 'Active'; // Default to Active if not found
      }
      _notesController.text = policy.notes ?? '';

      // Parse dates
      if (policy.effectiveDate != null && policy.effectiveDate!.isNotEmpty) {
        try {
          _effectiveDate = DateTime.parse(policy.effectiveDate!);
          final dateProvider =
              Provider.of<DateProvider>(context, listen: false);
          _effectiveDateController.text =
              dateProvider.formatCurrentDate(policy.effectiveDate!);
        } catch (e) {
          logError('Error parsing effective date: $e');
        }
      }
      if (policy.expirationDate != null && policy.expirationDate!.isNotEmpty) {
        try {
          _expirationDate = DateTime.parse(policy.expirationDate!);
          final dateProvider =
              Provider.of<DateProvider>(context, listen: false);
          _expirationDateController.text =
              dateProvider.formatCurrentDate(policy.expirationDate!);
        } catch (e) {
          logError('Error parsing expiration date: $e');
        }
      }
      if (policy.cancellationNoticeDate != null &&
          policy.cancellationNoticeDate!.isNotEmpty) {
        try {
          _cancellationNoticeDate =
              DateTime.parse(policy.cancellationNoticeDate!);
          final dateProvider =
              Provider.of<DateProvider>(context, listen: false);
          _cancellationNoticeDateController.text =
              dateProvider.formatCurrentDate(policy.cancellationNoticeDate!);
        } catch (e) {
          logError('Error parsing cancellation date: $e');
        }
      }
    });
  }

  /// Blanks an OPTIONAL date field (and its backing DateTime).
  void _clearDateField(TextEditingController controller) {
    setState(() {
      controller.clear();
      if (controller == _effectiveDateController) {
        _effectiveDate = null;
      } else if (controller == _expirationDateController) {
        _expirationDate = null;
      } else if (controller == _cancellationNoticeDateController) {
        _cancellationNoticeDate = null;
      }
    });
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, DateTime? initialDate,
      {Function(DateTime)? onDateSelected,
      bool isExpiration = false,
      bool allowClear = false,
      VoidCallback? onCleared}) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final DateTime minExpiration = _effectiveDate != null
        ? _effectiveDate!.add(const Duration(days: 1))
        : DateTime.now();
    DateTime resolvedInitial = initialDate ?? DateTime.now();
    if (isExpiration && resolvedInitial.isBefore(minExpiration)) {
      resolvedInitial = minExpiration;
    }
    final DateTime firstDate = isExpiration ? minExpiration : DateTime(2000);

    DateTime? picked;
    if (allowClear) {
      // Optional field: offer a "Clear" action inside the picker (web parity).
      final ClearableDatePickerResult? result = await showClearableDatePicker(
        context: context,
        initialDate: resolvedInitial,
        firstDate: firstDate,
        lastDate: DateTime(2100),
      );
      if (result == null) return; // cancelled — keep the current value
      if (result.cleared) {
        _clearDateField(controller);
        onCleared?.call();
        return;
      }
      picked = result.date!;
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: resolvedInitial,
        firstDate: firstDate,
        lastDate: DateTime(2100),
        initialDatePickerMode: DatePickerMode.day,
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: blueColor,
                onPrimary: Colors.white,
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: blueColor,
                ),
              ),
            ),
            child: child!,
          );
        },
      );
    }

    if (picked != null) {
      final DateTime pickedDate = picked;
      setState(() {
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(pickedDate);
        controller.text = dateProvider.formatCurrentDate(apiFormatDate);

        // Update the DateTime objects
        if (controller == _effectiveDateController) {
          _effectiveDate = pickedDate;
          // If effective date is after expiration date, clear expiration date
          if (_expirationDate != null &&
              _effectiveDate!.isAfter(_expirationDate!)) {
            _expirationDate = null;
            _expirationDateController.text = '';
          }
        } else if (controller == _expirationDateController) {
          _expirationDate = pickedDate;
          // Validate expiration date is strictly after effective date
          if (_effectiveDate != null &&
              !_expirationDate!.isAfter(_effectiveDate!)) {
            // Show warning but don't clear
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Expiration Date must be after Effective Date'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else if (controller == _cancellationNoticeDateController) {
          _cancellationNoticeDate = pickedDate;
        }

        if (onDateSelected != null) {
          onDateSelected(pickedDate);
        }
      });
    }
  }

  void _showFieldError(String field, String error) {
    setState(() {
      if (field == 'general') {
        _generalError = error;
      }
      _hasValidated = true;
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _saveForm() async {

    setState(() {
      _hasValidated = true;
    });

    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }

    final dateError = validateInsuranceDateRange(_effectiveDate, _expirationDate);
    if (dateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(dateError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');

      // Prepare data
      Map<String, dynamic> requestData = {
        'propertyId': widget.propertyId,
        'insurance_company_name': _insuranceCompanyNameController.text.trim(),
        'policy_number': _policyNumberController.text.trim(),
        'policy_type': _selectedPolicyType ?? '',
        'form_number': _selectedFormNumber ?? '',
        'named_insured': _namedInsuredController.text.trim(),
        'mailing_address': _mailingAddressController.text.trim(),
        'additional_insured': _additionalInsuredController.text.trim(),
        'effective_date': _effectiveDate != null
            ? '${DateFormat('yyyy-MM-dd').format(_effectiveDate!)}T00:00:00.000Z'
            : (_effectiveDateController.text.isNotEmpty
                ? _convertToApiFormat(_effectiveDateController.text)
                : ''),
        'expiration_date': _expirationDate != null
            ? '${DateFormat('yyyy-MM-dd').format(_expirationDate!)}T00:00:00.000Z'
            : (_expirationDateController.text.isNotEmpty
                ? _convertToApiFormat(_expirationDateController.text)
                : ''),
        'cancellation_notice_date': _cancellationNoticeDate != null
            ? '${DateFormat('yyyy-MM-dd').format(_cancellationNoticeDate!)}T00:00:00.000Z'
            : (_cancellationNoticeDateController.text.isNotEmpty
                ? _convertToApiFormat(_cancellationNoticeDateController.text)
                : null),
        'premium_amount': _premiumAmountController.text.isNotEmpty
            ? double.tryParse(_premiumAmountController.text
                .replaceAll('\$', '')
                .replaceAll(',', ''))
            : null,
        'deductible': _deductibleController.text.isNotEmpty
            ? double.tryParse(_deductibleController.text
                .replaceAll('\$', '')
                .replaceAll(',', ''))
            : null,
        'payment_terms': _selectedPaymentTerms ?? '',
        'claims_contact_info': _claimsContactInfoController.text.trim(),
        'agent_name': _agentNameController.text.trim(),
        'agent_phone': _agentPhoneController.text.trim(),
        'agent_email': _agentEmailController.text.trim(),
        'broker_name': _brokerNameController.text.trim(),
        'underwriting_office': _underwritingOfficeController.text.trim(),
        'status': _selectedStatus ?? 'Active',
        'notes': _notesController.text.trim(),
      };

      if (widget.policyId != null) {
        // Edit mode - PUT request

        final response = await http
            .put(
              Uri.parse('${Api_url}/api/property-insurance/${widget.policyId}'),
              headers: {
                'Content-Type': 'application/json',
                'authorization': 'CRM $token',
                'id': 'CRM $id',
              },
              body: json.encode(requestData),
            )
            .timeout(const Duration(seconds: 30));


        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              Navigator.pop(context, true);
            }
          } else {
            String errorMessage =
                data['message'] ?? 'Failed to update insurance policy';
            _showFieldError('general', errorMessage);
          }
        } else {
          final errorData = json.decode(response.body);
          String errorMessage =
              errorData['message'] ?? 'Failed to update insurance policy';
          _showFieldError('general', errorMessage);
        }
      } else {
        // Add mode - POST request

        final response = await http
            .post(
              Uri.parse('${Api_url}/api/property-insurance'),
              headers: {
                'Content-Type': 'application/json',
                'authorization': 'CRM $token',
                'id': 'CRM $id',
              },
              body: json.encode(requestData),
            )
            .timeout(const Duration(seconds: 30));


        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              Navigator.pop(context, true);
            }
          } else {
            String errorMessage =
                data['message'] ?? 'Failed to create insurance policy';
            _showFieldError('general', errorMessage);
          }
        } else {
          final errorData = json.decode(response.body);
          String errorMessage =
              errorData['message'] ?? 'Failed to create insurance policy';
          _showFieldError('general', errorMessage);
        }
      }
    } catch (e) {
      logError('=== EXCEPTION ===');
      logError('Exception occurred: $e');
      if (mounted) {
        _showFieldError('general', 'Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSectionHeader(int number, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: blueColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                children: required
                    ? [
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        )
                      ]
                    : [],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: controller.text,
          validator: validator ??
              (value) {
                if (required &&
                    _hasValidated &&
                    (value == null || value.trim().isEmpty)) {
                  return '$label is required';
                }
                return null;
              },
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLines: maxLines ?? 1,
                  cursorColor: blueColor,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) {
                    state.didChange(value);
                    if (_hasValidated) {
                      state.validate();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: prefixText != null
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16, right: 8),
                            child: Text(
                              prefixText,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : null,
                    prefixIconConstraints: prefixText != null
                        ? const BoxConstraints(minWidth: 0, minHeight: 0)
                        : null,
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: state.hasError ? Colors.red : Colors.grey[300]!),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: state.hasError ? Colors.red : Colors.grey[300]!),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: prefixText != null ? 8 : 16,
                      vertical: 14,
                    ),
                    errorStyle: const TextStyle(
                      fontSize: 0,
                      height: 0,
                    ),
                    isDense: true,
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 16, right: 16),
                    child: Text(
                      state.errorText ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        height: 1.0,
                      ),
                      maxLines: 2,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required DateTime? selectedDate,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                children: required
                    ? [
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        )
                      ]
                    : [],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: controller.text,
          validator: (value) {
            if (required &&
                _hasValidated &&
                (value == null || value.trim().isEmpty)) {
              return '$label is required';
            }
            return null;
          },
          builder: (FormFieldState<String> state) {
            void openPicker() {
              _selectDate(
                context,
                controller,
                selectedDate,
                isExpiration: label.contains('Expiration'),
                // Only OPTIONAL date fields may be cleared.
                allowClear: !required,
                onCleared: () {
                  state.didChange('');
                  state.validate();
                },
                onDateSelected: (date) {
                  setState(() {
                    if (label.contains('Effective')) {
                      _effectiveDate = date;
                    } else if (label.contains('Expiration')) {
                      _expirationDate = date;
                    } else if (label.contains('Cancellation')) {
                      _cancellationNoticeDate = date;
                    }
                  });
                  state.didChange(controller.text);
                  state.validate();
                },
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: required ? openPicker : null,
                  child: AbsorbPointer(
                    absorbing: required,
                    child: Builder(
                      builder: (context) {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        // Convert date format to hint format (e.g., MM/dd/yyyy -> MM/DD/YYYY, dd/MMM/yyyy -> DD/MMM/YYYY)
                        String dateFormatHint = dateProvider.dateFormat
                            .replaceAll('dd', 'DD')
                            .replaceAll('d', 'DD')
                            .replaceAll('MMM', 'MMM')
                            .replaceAll('MM', 'MM')
                            .replaceAll('M', 'MM')
                            .replaceAll('yyyy', 'YYYY')
                            .replaceAll('yy', 'YY');

                        return TextFormField(
                          controller: controller,
                          readOnly: true,
                          onTap: required ? null : openPicker,
                          onChanged: (value) {
                            state.didChange(value);
                            if (_hasValidated) {
                              state.validate();
                            }
                          },
                          decoration: InputDecoration(
                            hintText: dateFormatHint,
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            suffixIcon: required
                                ? Icon(
                                    Icons.calendar_today,
                                    color: blueColor,
                                  )
                                : ClearableDateSuffix(
                                    controller: controller,
                                    onPick: openPicker,
                                    onClear: () {
                                      _clearDateField(controller);
                                      state.didChange('');
                                      state.validate();
                                    },
                                    icon: Icons.calendar_today,
                                    iconColor: blueColor,
                                    iconSize: 20,
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
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: state.hasError ? Colors.red : Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            errorStyle: const TextStyle(
                              fontSize: 0,
                              height: 0,
                            ),
                            isDense: true,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 16, right: 16),
                    child: Text(
                      state.errorText ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        height: 1.0,
                      ),
                      maxLines: 2,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?)? onChanged,
    bool required = false,
    String? hint,
    bool disabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: Align(
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                children: required
                    ? [
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        )
                      ]
                    : [],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: disabled ? null : value,
          validator: required
              ? (val) {
                  if (_hasValidated && (val == null || val.isEmpty)) {
                    return '$label is required';
                  }
                  return null;
                }
              : null,
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    isExpanded: true,
                    hint: Text(
                      hint ??
                          'Select ${label.replaceAll(' (Optional)', '')}',
                      style: TextStyle(
                        fontSize: 14,
                        color: disabled
                            ? Colors.grey[300]
                            : Colors.grey[400],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: disabled ? null : (value != null && items.contains(value) ? value : null),
                    selectedItemBuilder: (BuildContext context) {
                      return items.map<Widget>((String item) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    items: items.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: disabled
                        ? null
                        : (newValue) {
                            state.didChange(newValue);
                            if (onChanged != null) {
                              onChanged(newValue);
                            }
                            // Trigger validation after change
                            if (_hasValidated) {
                              _formKey.currentState?.validate();
                            }
                          },
                    buttonStyleData: ButtonStyleData(
                      height: 50,
                     // padding: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[300]!,
                        ),
                        color: disabled ? Colors.grey[100] : Colors.white,
                      ),
                      elevation: 0,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      offset: const Offset(0, -5),
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
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 16,right: 16),
                    child: Text(
                      state.errorText ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        height: 1.0,
                      ),
                      maxLines: 2,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.policyId != null;

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Colors.blue.withOpacity(0.3),
          selectionHandleColor: Colors.blue,
        ),
      ),
      child: Scaffold(
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
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(
                    left: 16.0, right: 16.0, top: 8, bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Container(
                    height: 45,
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
                    child: Text(
                      isEditMode
                          ? 'Edit Insurance Policy'
                          : 'Add Insurance Policy',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.only(left: 18.0, right: 18.0, top: 8),
                  child: 
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditMode
                            ? 'Update insurance policy details'
                            : 'Add new insurance policy for this property',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),

                      // General Error Message
                      if (_generalError != null && _hasValidated)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _generalError!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    color: Colors.red.shade700, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _generalError = null;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                      // Section 1: Policy Identification Information
                      _buildSectionHeader(
                        1,
                        'Policy Identification Information',
                        'Basic policy details and identification',
                      ),
                      _buildTextField(
                        label: 'Insurance Company Name',
                        controller: _insuranceCompanyNameController,
                        hint: 'Enter insurance company name',
                        required: true,
                      ),
                      _buildTextField(
                        label: 'Policy Number',
                        controller: _policyNumberController,
                        hint: 'Enter policy number',
                        required: true,
                        validator: (value) {
                          // Same rules and messages as web (PropDetails.jsx).
                          if (_hasValidated &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Policy number is required';
                          }
                          if (_hasValidated &&
                              value != null &&
                              value.trim().length < 2) {
                            return 'Policy number must be at least 2 characters';
                          }
                          if (_hasValidated &&
                              value != null &&
                              value.trim().length > 50) {
                            return 'Policy number cannot exceed 50 characters';
                          }
                          if (_hasValidated &&
                              value != null &&
                              !RegExp(r'^[A-Za-z0-9\-/]+$')
                                  .hasMatch(value.trim())) {
                            return 'Policy number can only contain letters, numbers, hyphens (-), and forward slashes (/)';
                          }
                          return null;
                        },
                      ),
                      _buildDropdown(
                        label: 'Policy Type',
                        value: _selectedPolicyType,
                        items: _policyTypeOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedPolicyType = value;
                            _selectedFormNumber = null; // Reset form number
                            _updateFormNumberOptions(
                                value); // Update form number options
                          });
                        },
                        hint: 'Select Policy Type',
                      ),
                      _buildDropdown(
                        label: 'Form Number',
                        value: _selectedPolicyType == null
                            ? null
                            : _selectedFormNumber,
                        items: _formNumberOptions,
                        onChanged: _selectedPolicyType == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedFormNumber = value;
                                });
                              },
                        hint: _selectedPolicyType == null
                            ? 'Select Policy Type First'
                            : 'Select Form Number',
                        disabled: _selectedPolicyType == null,
                      ),

                      // Section 2: Insured Party Details
                      _buildSectionHeader(
                        2,
                        'Insured Party Details',
                        'Information about the policyholder and property',
                      ),
                      _buildTextField(
                        label: 'Named Insured',
                        controller: _namedInsuredController,
                        hint: 'Enter named insured',
                        required: true,
                      ),
                      _buildTextField(
                        label: 'Premium Amount',
                        controller: _premiumAmountController,
                        hint: 'Enter premium amount',
                        required: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        prefixText: '\$ ',
                      ),
                      _buildTextField(
                        label: 'Mailing Address',
                        controller: _mailingAddressController,
                        hint: 'Enter mailing address',
                        required: true,
                        maxLines: 2,
                      ),
                      _buildTextField(
                        label: 'Additional Insured or Interest',
                        controller: _additionalInsuredController,
                        hint: 'Enter additional insured or interest',
                        maxLines: 2,
                      ),

                      // Section 3: Coverage Dates
                      _buildSectionHeader(
                        3,
                        'Coverage Dates',
                        'Policy effective and expiration dates',
                      ),
                      _buildDateField(
                        label: 'Policy Effective Date',
                        controller: _effectiveDateController,
                        selectedDate: _effectiveDate,
                        required: true,
                      ),
                      _buildDateField(
                        label: 'Policy Expiration Date',
                        controller: _expirationDateController,
                        selectedDate: _expirationDate,
                        required: true,
                      ),
                      _buildDateField(
                        label: 'Cancellation/Non-Renewal Notice Date',
                        controller: _cancellationNoticeDateController,
                        selectedDate: _cancellationNoticeDate,
                      ),

                      // Section 4: Financial Information
                      _buildSectionHeader(
                        4,
                        'Financial Information',
                        'Premium amounts, deductibles, and payment terms',
                      ),
                      _buildTextField(
                        label: 'Deductible',
                        controller: _deductibleController,
                        hint: 'Enter deductible amount',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        prefixText: '\$ ',
                      ),
                      _buildDropdown(
                        label: 'Payment Terms',
                        value: _selectedPaymentTerms,
                        items: _paymentTermsOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedPaymentTerms = value;
                          });
                        },
                        required: true,
                        hint: 'Select Payment Terms',
                      ),

                      // Section 5: Claims and Customer Service Information
                      _buildSectionHeader(
                        5,
                        'Claims and Customer Service Information',
                        'Contact information for claims and policy management',
                      ),
                      _buildTextField(
                        label: 'Agent or Broker Name',
                        controller: _agentNameController,
                        hint: 'Enter agent or broker name',
                      ),
                      _buildTextField(
                        label: 'Agent Phone',
                        controller: _agentPhoneController,
                        hint: '(xxx) xxx-xxxx',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [PhoneNumberFormatter()],
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            // Remove formatting to check digit count
                            String digitsOnly =
                                value.replaceAll(RegExp(r'[^\d]'), '');
                            if (digitsOnly.length != 10) {
                              return 'Phone number must be exactly 10 digits';
                            }
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        label: 'Agent Email',
                        controller: _agentEmailController,
                        hint: 'Enter agent email',
                        keyboardType: TextInputType.emailAddress,
                        // Optional, but must be a real address when filled (web parity).
                        validator: (value) => (value != null &&
                                value.trim().isNotEmpty &&
                                !EmailValidator.validate(value.trim()))
                            ? 'Agent email must be a valid email address'
                            : null,
                      ),
                      _buildTextField(
                        label: 'Broker Name',
                        controller: _brokerNameController,
                        hint: 'Enter broker name',
                      ),
                      _buildTextField(
                        label: 'Claims Contact Information',
                        controller: _claimsContactInfoController,
                        hint: 'Phone numbers or websites for filing claims',
                        maxLines: 2,
                      ),
                      _buildTextField(
                        label: 'Underwriting Office',
                        controller: _underwritingOfficeController,
                        hint: 'Enter underwriting office',
                      ),
                      _buildDropdown(
                        label: 'Status',
                        value: _selectedStatus,
                        items: _statusOptions,
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value;
                          });
                        },
                        required: true,
                        hint: 'Select Status',
                      ),
                      _buildTextField(
                        label: 'Notes',
                        controller: _notesController,
                        hint: 'Enter any additional notes or comments',
                        maxLines: 4,
                      ),

                      const SizedBox(height: 10),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Cancel Button
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.pop(context);
                                  },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Save Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blueColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                   
                    const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
