import 'package:three_zero_two_property/services/app_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/widgets/clearable_date_picker.dart';
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';

// Custom Phone Number Formatter
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    // Limit to 10 digits
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    // Format as (XXX) XXX-XXXX
    String formatted = '';
    if (digitsOnly.length >= 1) {
      formatted =
          '(${digitsOnly.substring(0, digitsOnly.length > 3 ? 3 : digitsOnly.length)}';
    }
    if (digitsOnly.length >= 4) {
      formatted +=
          ') ${digitsOnly.substring(3, digitsOnly.length > 6 ? 6 : digitsOnly.length)}';
    }
    if (digitsOnly.length >= 7) {
      formatted += '-${digitsOnly.substring(6)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AddMortgageScreen extends StatefulWidget {
  // pass the mortgage data to this screen from the previous screen
  final Map<String, dynamic>? mortgageData;
  final String? mortgageId; // For editing existing mortgages
  final String?
      propertyId; // Property ID from context (when adding from property page)
  /// Which drawer item to highlight: "Mortgage" when opened from main Mortgage list, "Properties" when from property summary.
  final String? drawerCurrentPage;

  const AddMortgageScreen({
    Key? key,
    this.mortgageId,
    this.mortgageData,
    this.propertyId,
    this.drawerCurrentPage,
  }) : super(key: key);

  @override
  State<AddMortgageScreen> createState() => _AddMortgageScreenState();
}

class _AddMortgageScreenState extends State<AddMortgageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  final _propertyController = TextEditingController();
  final List<Map<String, dynamic>> _selectedProperties = [];
  final _bankNameController = TextEditingController();
  final _bankAddressController = TextEditingController();
  final _bankContactController = TextEditingController();
  final _bankEmailController = TextEditingController();
  final _managerFirstNameController = TextEditingController();
  final _managerLastNameController = TextEditingController();
  final _managerPhoneController = TextEditingController();
  final _managerEmailController = TextEditingController();
  final _mortgageNumberController = TextEditingController();
  final _loanAmountController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _statusController = TextEditingController();
  final _remainingBalanceController = TextEditingController();
  final _lastPaymentDateController = TextEditingController();
  final _nextPaymentDateController = TextEditingController();
  final _borrowerFirstNameController = TextEditingController();
  final _borrowerLastNameController = TextEditingController();
  final _borrowerCompanyNameController = TextEditingController();
  final _borrowerAddressController = TextEditingController();
  final _borrowerPhoneController = TextEditingController();
  final _borrowerEmailController = TextEditingController();
  final _typeController = TextEditingController();
  final _amortizationPeriodController = TextEditingController();
  // Principal, Interest, Monthly Payment (monthly payment = principal + interest, read-only)
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _monthlyPaymentDisplayController = TextEditingController();
  // Conditional fields for Fixed Rate Mortgage
  final _fixedInterestPeriodController = TextEditingController();
  final _fixedInterestExpirationDateController = TextEditingController();
  DateTime? _fixedInterestExpirationDate;
  // Conditional fields for Floating Rate Mortgage
  final _spreadController = TextEditingController();
  // Conditional field for Fixed Rate Mortgage
  final _spreadOnFloatingRateController = TextEditingController();
  // Selected dates
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _lastPaymentDate;
  DateTime? _nextPaymentDate;

  // Payoff History
  List<Map<String, dynamic>> _payoffs = [];
  final TextEditingController _newPayoffAmountController =
      TextEditingController();
  final TextEditingController _newPayoffDateController =
      TextEditingController();
  DateTime? _newPayoffDate;
  int? _editingPayoffIndex;
  final TextEditingController _editingPayoffAmountController =
      TextEditingController();
  final TextEditingController _editingPayoffDateController =
      TextEditingController();
  DateTime? _editingPayoffDate;
  bool _showAddPayoffForm = false;

  // Status options
  final List<String> _statusOptions = [
    'Active',
    'Paid Off',
    'Defaulted',
    'Refinanced'
  ];
  final List<String> _typeOptions = [
    'Floating Rate Mortgage',
    'Fixed Rate Mortgage',
  ];
  String _selectedMortgageType =
      ''; // Track selected mortgage type for reactive UI
  List<Map<String, dynamic>> _propertyOptions = [];
  bool _isLoadingProperties = false;

  bool _isLoading = false;

  // Store original mortgage data for comparison
  Map<String, dynamic>? _originalMortgageData;

  void _updateMonthlyPaymentDisplay() {
    final p = double.tryParse(_principalController.text.trim()) ?? 0.0;
    final i = double.tryParse(_interestController.text.trim()) ?? 0.0;
    final sum = p + i;
    _monthlyPaymentDisplayController.text =
        sum == sum.truncate() ? sum.toInt().toString() : sum.toStringAsFixed(2);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadProperties();
    _principalController.addListener(_updateMonthlyPaymentDisplay);
    _interestController.addListener(_updateMonthlyPaymentDisplay);
    if (widget.mortgageId != null) {}
  }

  void dispose() {
    _propertyController.dispose();
    _bankNameController.dispose();
    _bankAddressController.dispose();
    _bankContactController.dispose();
    _bankEmailController.dispose();
    _managerFirstNameController.dispose();
    _managerLastNameController.dispose();
    _managerPhoneController.dispose();
    _managerEmailController.dispose();
    _mortgageNumberController.dispose();
    _loanAmountController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _monthlyPaymentDisplayController.dispose();
    _interestRateController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _statusController.dispose();
    _remainingBalanceController.dispose();
    _lastPaymentDateController.dispose();
    _nextPaymentDateController.dispose();
    _borrowerFirstNameController.dispose();
    _borrowerLastNameController.dispose();
    _borrowerCompanyNameController.dispose();
    _borrowerAddressController.dispose();
    _borrowerPhoneController.dispose();
    _borrowerEmailController.dispose();
    _newPayoffAmountController.dispose();
    _newPayoffDateController.dispose();
    _editingPayoffAmountController.dispose();
    _editingPayoffDateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper function to convert date format pattern to readable hint text
  // Example: "MM/dd/yyyy" -> "mm/dd/yyyy", "dd-MM-yyyy" -> "dd-mm-yyyy", "yyyy-MM-dd" -> "yyyy-mm-dd"
  String _getDateHintText(DateProvider dateProvider) {
    String format = dateProvider.dateFormat;
    // Convert format pattern to lowercase while preserving separators (/, -, etc.)
    String hint =
        format.replaceAll('M', 'm').replaceAll('d', 'd').replaceAll('y', 'y');
    return hint;
  }

  /// Blanks an OPTIONAL date field (controller + its backing DateTime).
  void _clearDate(TextEditingController controller) {
    setState(() {
      controller.text = '';
      if (controller == _lastPaymentDateController) {
        _lastPaymentDate = null;
      } else if (controller == _nextPaymentDateController) {
        _nextPaymentDate = null;
      } else if (controller == _fixedInterestExpirationDateController) {
        _fixedInterestExpirationDate = null;
      }
    });
  }

  Future<void> _selectDate(BuildContext context,
      TextEditingController controller, DateTime? initialDate,
      {DateTime? firstDate, DateTime? lastDate, bool clearable = false}) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Determine the actual firstDate and lastDate
    final actualFirstDate = firstDate ?? DateTime(2000);
    final actualLastDate = lastDate ?? DateTime(2100);

    // Ensure initialDate is within the valid range
    DateTime actualInitialDate;
    if (initialDate != null) {
      if (initialDate.isBefore(actualFirstDate)) {
        actualInitialDate = actualFirstDate;
      } else if (initialDate.isAfter(actualLastDate)) {
        actualInitialDate = actualLastDate;
      } else {
        actualInitialDate = initialDate;
      }
    } else {
      // If no initial date, use firstDate if it's valid, otherwise today (but ensure it's within range)
      if (actualFirstDate.isBefore(today) ||
          actualFirstDate.isAtSameMomentAs(today)) {
        actualInitialDate =
            actualFirstDate.isAfter(today) ? actualFirstDate : today;
        if (actualInitialDate.isAfter(actualLastDate)) {
          actualInitialDate = actualLastDate;
        }
      } else {
        actualInitialDate = actualFirstDate;
      }
    }

    DateTime? pickedResult;
    if (clearable) {
      // Optional date field — offer a Clear action (web parity).
      final ClearableDatePickerResult? result = await showClearableDatePicker(
        context: context,
        initialDate: actualInitialDate,
        firstDate: actualFirstDate,
        lastDate: actualLastDate,
      );
      if (result == null) return; // cancelled — keep the current value
      if (result.cleared) {
        _clearDate(controller);
        return;
      }
      pickedResult = result.date!;
    } else {
      pickedResult = await showDatePicker(
        context: context,
        initialDate: actualInitialDate,
        firstDate: actualFirstDate,
        lastDate: actualLastDate,
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
    }
    final DateTime? picked = pickedResult;
    if (picked != null) {
      setState(() {
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        String displayFormat = dateProvider.formatCurrentDate(apiFormatDate);

        if (controller == _startDateController) {
          _startDate = picked;
          controller.text = displayFormat;
          // Clear maturity date if it's before or equal to origination date
          if (_endDate != null &&
              (_endDate!.isBefore(_startDate!) ||
                  _endDate!.isAtSameMomentAs(_startDate!))) {
            _endDate = null;
            _endDateController.text = '';
          }
          // Clear fixed interest expiration date if it's invalid
          if (_fixedInterestExpirationDate != null && _endDate != null) {
            if (_fixedInterestExpirationDate!.isBefore(_startDate!) ||
                _fixedInterestExpirationDate!.isAfter(_endDate!)) {
              _fixedInterestExpirationDate = null;
              _fixedInterestExpirationDateController.text = '';
            }
          } else if (_fixedInterestExpirationDate != null && _endDate == null) {
            // If end date is cleared, clear fixed interest expiration date too
            _fixedInterestExpirationDate = null;
            _fixedInterestExpirationDateController.text = '';
          }
        } else if (controller == _endDateController) {
          _endDate = picked;
          controller.text = displayFormat;
          // Clear fixed interest expiration date if it's invalid (must be strictly between)
          if (_fixedInterestExpirationDate != null && _startDate != null) {
            final startDateOnly =
                DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            final endDateOnly =
                DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
            final expirationDateOnly = DateTime(
                _fixedInterestExpirationDate!.year,
                _fixedInterestExpirationDate!.month,
                _fixedInterestExpirationDate!.day);

            if (expirationDateOnly.isBefore(startDateOnly) ||
                expirationDateOnly.isAtSameMomentAs(startDateOnly) ||
                expirationDateOnly.isAfter(endDateOnly) ||
                expirationDateOnly.isAtSameMomentAs(endDateOnly)) {
              _fixedInterestExpirationDate = null;
              _fixedInterestExpirationDateController.text = '';
            }
          }
        } else if (controller == _lastPaymentDateController) {
          _lastPaymentDate = picked;
          controller.text = displayFormat;
        } else if (controller == _nextPaymentDateController) {
          _nextPaymentDate = picked;
          controller.text = displayFormat;
        } else if (controller == _fixedInterestExpirationDateController) {
          _fixedInterestExpirationDate = picked;
          controller.text = displayFormat;
        }
      });
    }
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Empty is valid; if filled, must be a non-negative integer.
  String? _validateOptionalNonNegativeInt(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;
    final n = int.tryParse(value.trim());
    if (n == null || n < 0) {
      return 'Enter a valid $fieldName';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value != null && value.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return 'Please enter a valid email address';
      }
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value != null && value.isNotEmpty) {
      // Remove all non-digit characters to check length
      String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

      if (digitsOnly.length != 10) {
        return 'Phone number must be exactly 10 digits';
      }

      // Optional: Check if it's a valid US phone number format
      final phoneRegex = RegExp(r'^\(\d{3}\) \d{3}-\d{4}$');
      if (!phoneRegex.hasMatch(value)) {
        return 'Please enter a valid phone number format';
      }
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (value != null && value.isNotEmpty) {
      final amountRegex = RegExp(r'^\$?\d+(\.\d{1,2})?$');
      if (!amountRegex.hasMatch(value)) {
        return 'Please enter a valid amount';
      }
      final amount = double.tryParse(value.replaceAll('\$', ''));
      if (amount == null || amount <= 0) {
        return 'Amount must be greater than 0';
      }
    }
    return null;
  }

  String? _validateInterestRate(String? value) {
    final trimmed = value?.trim() ?? '';
    // Spread fields are optional (match Admin) — empty is valid, so an
    // untouched Spread on Floating Rate field never blocks Save.
    if (trimmed.isEmpty) return null;
    final rate = double.tryParse(trimmed.replaceAll('%', ''));
    if (rate == null || rate < 0 || rate > 100) {
      return 'Interest rate must be between 0 to 100';
    }
    return null;
  }


  /// Returns true if another mortgage already uses this loan number (excluding current when editing).
  Future<bool> _isDuplicateMortgageNo(String mortgageNo) async {
    if (mortgageNo.isEmpty) return false;
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');
      final response = await apiGet(
        Uri.parse('$Api_url/api/mortgage/'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM ${prefs.getString("staff_id") ?? id}',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final data = json.decode(response.body);
      final list = data['data'] as List?;
      if (list == null) return false;
      final currentId = widget.mortgageId;
      for (final m in list) {
        final no = (m['mortgage_no'] ?? '').toString().trim();
        if (no.isEmpty) continue;
        if (no != mortgageNo) continue;
        if (currentId != null && m['_id']?.toString() == currentId) continue;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String? _validateSSN(String? value) {
    if (value != null && value.isNotEmpty) {
      final ssnRegex = RegExp(r'^\d{3}-?\d{2}-?\d{4}$');
      if (!ssnRegex.hasMatch(value)) {
        return 'Please enter a valid SSN (XXX-XX-XXXX)';
      }
    }
    return null;
  }

  String? _validateMortgageNumber(String? value) {
    if (value != null && value.isNotEmpty) {
      // Remove all non-digit characters to check length
      String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

      if (value.length < 2) {
        return 'Loan number must be at least 2 digits';
      }
    }
    return null;
  }

  String? _validateProperties() {
    // Property selection is now optional - no validation needed
    // This function always returns null to allow mortgages without properties
    return null;
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoadingProperties = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    try {
      final response = await apiGet(
        Uri.parse('${Api_url}/api/mortgage/properties/list'),
        headers: {
          'Content-Type': 'application/json',
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
          // Add your authentication headers here if needed
          // 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null) {
          setState(() {
            _propertyOptions = List<Map<String, dynamic>>.from(data['data']);
          });
        } else {
          // Handle empty data response
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No properties found in the response.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (response.statusCode == 401) {
        // Handle authentication error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please login again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        // Load fallback properties for development/testing
        _loadFallbackProperties();
      } else {
        // Handle other errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to load properties: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Load fallback properties for development/testing
        _loadFallbackProperties();
      }
      if (widget.mortgageId != null) {
        _loadMortgageData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading properties: ${friendlyErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Load fallback properties for development/testing
      _loadFallbackProperties();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProperties = false;
        });
      }
    }
  }

  void _loadFallbackProperties() {
    // Fallback properties for development/testing when API is not accessible
    setState(() {
      _propertyOptions = [
        {
          'rental_id': '1755846103111',
          'address': '024 Evergreen Lane',
          'city': 'Portland',
          'state': 'Oregon',
          'zipcode': '97205',
          'subdivision': 'Riverbend Estates',
          'full_address': '024 Evergreen Lane Portland Oregon 97205'
        },
        {
          'rental_id': '1748925551064',
          'address': '1200 Commerce Blvd',
          'city': 'Denverr',
          'state': 'CO',
          'zipcode': '80202',
          'subdivision': 'N/A',
          'full_address': '1200 Commerce Blvd Denverr CO 80202'
        },
        {
          'rental_id': '1748925551065',
          'address': '123 Elm Street',
          'city': 'Austin',
          'state': 'Texas',
          'zipcode': '73301',
          'subdivision': 'Downtown District',
          'full_address': '123 Elm Street Austin Texas 73301'
        },
      ];
    });
  }

  Future<void> _loadMortgageData() async {
    if (widget.mortgageId == null) return;

    // assign the data from widget.mortgageData to the form
    _populateFormWithData(widget.mortgageData!);
    try {
      // SharedPreferences prefs = await SharedPreferences.getInstance();
      // String? token = prefs.getString('token');
      // String? id = prefs.getString('adminId');
      //
      // final response = await apiGet(
      //   Uri.parse('$Api_url/api/mortgage/${widget.mortgageId}'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'authorization': 'CRM $token',
      //     'id': 'CRM ${prefs.getString("staff_id") ?? id}',
      //   },
      // ).timeout(const Duration(seconds: 30));

      // if (response.statusCode == 200) {
      //   print(response.body);
      //   final data = json.decode(response.body);

      //   if (data['data'] != null) {
      //     _populateFormWithData(data['data']);
      //   }
      // } else {
      //   if (mounted) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         content: Text('Failed to load mortgage: ${response.statusCode}'),
      //         backgroundColor: Colors.red,
      //       ),
      //     );
      //   }
      // }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading mortgage: ${friendlyErrorMessage(e)}'),
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
  // populate the form with the data from the widget.mortgageData

  void _populateFormWithData(Map<String, dynamic> mortgageData) {
    try {
      // Store original data for comparison
      _originalMortgageData = Map<String, dynamic>.from(mortgageData);
      setState(() {
        // Bank Information
        _bankNameController.text = mortgageData['bank_name'] ?? '';
        _bankAddressController.text = mortgageData['bank_address'] ?? '';
        _bankContactController.text = mortgageData['bank_contact_no'] ?? '';
        _bankEmailController.text = mortgageData['bank_email'] ?? '';

        // Relationship Manager Information
        _managerFirstNameController.text =
            mortgageData['relationship_manager_first_name'] ?? '';
        _managerLastNameController.text =
            mortgageData['relationship_manager_last_name'] ?? '';
        _managerPhoneController.text =
            mortgageData['relationship_manager_phone'] ?? '';
        _managerEmailController.text =
            mortgageData['relationship_manager_email'] ?? '';

        // Mortgage Details
        // Set mortgage type - map API values to dropdown options
        final mortgageType = mortgageData['mortgage_type']?.toString() ?? '';
        if (mortgageType.isNotEmpty) {
          // Map API values to dropdown display values
          if (mortgageType == 'floating_rate' ||
              mortgageType == 'Floating Rate Mortgage') {
            _typeController.text = 'Floating Rate Mortgage';
          } else if (mortgageType == 'fixed_rate' ||
              mortgageType == 'Fixed Rate Mortgage') {
            _typeController.text = 'Fixed Rate Mortgage';
          } else {
            // Try to match by partial string
            if (mortgageType.toLowerCase().contains('floating')) {
              _typeController.text = 'Floating Rate Mortgage';
            } else if (mortgageType.toLowerCase().contains('fixed')) {
              _typeController.text = 'Fixed Rate Mortgage';
            }
          }
        }
        _mortgageNumberController.text = mortgageData['mortgage_no'] ?? '';
        _loanAmountController.text =
            mortgageData['loan_amount']?.toString() ?? '';
        _interestRateController.text =
            mortgageData['interest_rate']?.toString() ?? '';

        // Format dates properly for display using DateProvider
        if (mortgageData['start_date'] != null &&
            mortgageData['start_date'].toString().isNotEmpty) {
          try {
            _startDate = DateTime.parse(mortgageData['start_date']);
            // Use DateProvider to format according to user's preference
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            String apiFormatDate = DateFormat('yyyy-MM-dd').format(_startDate!);
            _startDateController.text =
                dateProvider.formatCurrentDate(apiFormatDate);
          } catch (e) {
            _startDateController.text = '';
          }
        } else {
          _startDateController.text = '';
        }

        if (mortgageData['end_date'] != null &&
            mortgageData['end_date'].toString().isNotEmpty) {
          try {
            _endDate = DateTime.parse(mortgageData['end_date']);
            // Use DateProvider to format according to user's preference
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            String apiFormatDate = DateFormat('yyyy-MM-dd').format(_endDate!);
            _endDateController.text =
                dateProvider.formatCurrentDate(apiFormatDate);
          } catch (e) {
            _endDateController.text = '';
          }
        } else {
          _endDateController.text = '';
        }

        // mortgageData['status'] first letter make a so that.. because active is not match with Active
        // if mortgageData['status'] is I/flutter ( 4495): mortgageData['status'] paid_off then make it Paid Off detecct the "_" and make the first letter uppercase
        final status = mortgageData['status'].toString();
        final formattedStatus = status
            .split('_') // split into ['paid', 'off']
            // An empty or underscore-edged status splits to an empty segment,
            // and `word[0]` on it threw RangeError, breaking the Edit Mortgage
            // prefill before the form could render.
            .where((word) => word.isNotEmpty)
            .map((word) =>
                word[0].toUpperCase() + word.substring(1)) // capitalize each
            .join(' '); // join back with space

        _statusController.text = formattedStatus;

        //_statusController.text = mortgageData['status'] ?? '';
        _amortizationPeriodController.text =
            mortgageData['amortization_period']?.toString() ?? '';
        _remainingBalanceController.text =
            mortgageData['remaining_balance']?.toString() ?? '0';

        // Principal, Interest, Monthly Payment (from API or recalc)
        _principalController.text =
            mortgageData['monthly_principal']?.toString() ?? '';
        _interestController.text =
            mortgageData['monthly_interest']?.toString() ?? '';
        _updateMonthlyPaymentDisplay();
        // When API returns monthly_payment (e.g. create had only total, no principal/interest), show it in edit
        if (mortgageData['monthly_payment'] != null) {
          final v = mortgageData['monthly_payment'];
          if (v is num) {
            _monthlyPaymentDisplayController.text = v is int
                ? v.toString()
                : (v as double).toStringAsFixed(2);
          } else {
            _monthlyPaymentDisplayController.text = v.toString();
          }
        }

        // Set selected mortgage type for reactive UI
        _selectedMortgageType = _typeController.text;

        // Populate conditional fields based on mortgage type
        if (_typeController.text == 'Fixed Rate Mortgage') {
          _fixedInterestPeriodController.text =
              mortgageData['fixed_interest_period']?.toString() ?? '';

          if (mortgageData['fixed_interest_expiration_date'] != null &&
              mortgageData['fixed_interest_expiration_date']
                  .toString()
                  .isNotEmpty) {
            try {
              _fixedInterestExpirationDate = DateTime.parse(
                  mortgageData['fixed_interest_expiration_date']);
              final dateProvider =
                  Provider.of<DateProvider>(context, listen: false);
              String apiFormatDate = DateFormat('yyyy-MM-dd')
                  .format(_fixedInterestExpirationDate!);
              _fixedInterestExpirationDateController.text =
                  dateProvider.formatCurrentDate(apiFormatDate);
            } catch (e) {
              _fixedInterestExpirationDateController.text = '';
            }
          }

          _spreadOnFloatingRateController.text =
              mortgageData['spread_on_floating_rate']?.toString() ?? '';
        } else if (_typeController.text == 'Floating Rate Mortgage') {
          _spreadController.text = mortgageData['spread']?.toString() ?? '';
        }

        // Format payment dates properly for display using DateProvider
        if (mortgageData['last_payment_date'] != null &&
            mortgageData['last_payment_date'].toString().isNotEmpty) {
          try {
            _lastPaymentDate =
                DateTime.parse(mortgageData['last_payment_date']);
            // Use DateProvider to format according to user's preference
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            String apiFormatDate =
                DateFormat('yyyy-MM-dd').format(_lastPaymentDate!);
            _lastPaymentDateController.text =
                dateProvider.formatCurrentDate(apiFormatDate);
          } catch (e) {
            _lastPaymentDateController.text = '';
          }
        } else {
          _lastPaymentDateController.text = '';
        }

        if (mortgageData['next_payment_date'] != null &&
            mortgageData['next_payment_date'].toString().isNotEmpty) {
          try {
            _nextPaymentDate =
                DateTime.parse(mortgageData['next_payment_date']);
            // Use DateProvider to format according to user's preference
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            String apiFormatDate =
                DateFormat('yyyy-MM-dd').format(_nextPaymentDate!);
            _nextPaymentDateController.text =
                dateProvider.formatCurrentDate(apiFormatDate);
          } catch (e) {
            _nextPaymentDateController.text = '';
          }
        } else {
          _nextPaymentDateController.text = '';
        }

        // Borrower Information
        _borrowerFirstNameController.text =
            mortgageData['borrower_first_name'] ?? '';
        _borrowerLastNameController.text =
            mortgageData['borrower_last_name'] ?? '';
        _borrowerCompanyNameController.text =
            mortgageData['borrower_company_name'] ?? '';
        _borrowerAddressController.text =
            mortgageData['borrower_address'] ?? '';
        _borrowerPhoneController.text = mortgageData['borrower_phone'] ?? '';
        _borrowerEmailController.text = mortgageData['borrower_email'] ?? '';


        // Handle properties selection
        if (mortgageData['properties'] != null &&
            mortgageData['properties'] is List) {
          _selectedProperties.clear();
          for (var propertyId in mortgageData['properties']) {
            // Find the property in _propertyOptions by rental_id
            final property = _propertyOptions.firstWhere(
              (p) => p['rental_id'] == propertyId,
              orElse: () => <String, dynamic>{},
            );
            if (property.isNotEmpty) {
              _selectedProperties.add(property);
            }
          }
        }

        // Handle payoffs
        if (mortgageData['payoffs'] != null &&
            mortgageData['payoffs'] is List) {
          _payoffs.clear();
          for (var payoff in mortgageData['payoffs']) {
            _payoffs.add({
              'amount': payoff['amount'],
              'date': DateTime.parse(payoff['date']),
              '_id': payoff['_id'],
              'created_at': payoff['created_at'] != null
                  ? DateTime.parse(payoff['created_at'])
                  : null,
            });
          }
        }
      });
    } catch (e) {
      logError(e);
    }
  }

  // Compare current form data with original data
  bool _hasChanges() {
    if (_originalMortgageData == null || widget.mortgageId == null) {
      // If no original data or not in edit mode, consider it as having changes (for new records)
      return widget.mortgageId == null;
    }

    try {
      // We'll build the current data similar to _saveForm
      List<String> propertyIds = _selectedProperties
          .map((p) => p['rental_id'].toString())
          .toList()
          .cast<String>();
      if (propertyIds.isEmpty &&
          widget.propertyId != null &&
          widget.propertyId!.isNotEmpty) {
        propertyIds = [widget.propertyId!];
      }

      final mortgageType = _selectedMortgageType.isNotEmpty
          ? _selectedMortgageType
          : _typeController.text.trim();
      final isFixedRate = mortgageType == 'Fixed Rate Mortgage';

      // Build current mortgage data
      final currentData = <String, dynamic>{
        'properties': propertyIds,
        'bank_name': _bankNameController.text.trim(),
        'bank_address': _bankAddressController.text.trim(),
        'bank_contact_no': _bankContactController.text.trim(),
        'bank_email': _bankEmailController.text.trim(),
        'relationship_manager_first_name':
            _managerFirstNameController.text.trim(),
        'relationship_manager_last_name':
            _managerLastNameController.text.trim(),
        'relationship_manager_phone': _managerPhoneController.text.trim(),
        'relationship_manager_email': _managerEmailController.text.trim(),
        'mortgage_no': _mortgageNumberController.text.trim(),
        'mortgage_type': isFixedRate ? 'fixed_rate' : 'floating_rate',
        'loan_amount': _loanAmountController.text.trim(),
        'interest_rate': _interestRateController.text.trim(),
        'start_date': _startDate != null ? _startDate!.toIso8601String() : '',
        'end_date': _endDate != null ? _endDate!.toIso8601String() : '',
        'amortization_period': _amortizationPeriodController.text.trim(),
        'status':
            _statusController.text.trim().toLowerCase().replaceAll(' ', '_'),
        'remaining_balance': _remainingBalanceController.text.trim(),
        'monthly_principal':
            double.tryParse(_principalController.text.trim()) ?? 0,
        'monthly_interest':
            double.tryParse(_interestController.text.trim()) ?? 0,
        'monthly_payment': double.tryParse(
                _monthlyPaymentDisplayController.text.trim()) ??
            0,
        'last_payment_date':
            _lastPaymentDate != null ? _lastPaymentDate!.toIso8601String() : '',
        'next_payment_date':
            _nextPaymentDate != null ? _nextPaymentDate!.toIso8601String() : '',
        'borrower_first_name': _borrowerFirstNameController.text.trim(),
        'borrower_last_name': _borrowerLastNameController.text.trim(),
        'borrower_company_name': _borrowerCompanyNameController.text.trim(),
        'borrower_address': _borrowerAddressController.text.trim(),
        'borrower_phone': _borrowerPhoneController.text.trim(),
        'borrower_email': _borrowerEmailController.text.trim(),
        'payoffs': _payoffs
            .map((payoff) => {
                  'amount': payoff['amount'],
                  'date': (payoff['date'] as DateTime).toIso8601String(),
                  if (payoff['_id'] != null) '_id': payoff['_id'],
                })
            .toList(),
      };

      // Add conditional fields based on mortgage type
      if (isFixedRate) {
        currentData['fixed_interest_period'] =
            _fixedInterestPeriodController.text.trim();
        currentData['fixed_interest_expiration_date'] =
            _fixedInterestExpirationDate != null
                ? _fixedInterestExpirationDate!.toIso8601String()
                : '';
        currentData['spread_on_floating_rate'] =
            _spreadOnFloatingRateController.text.trim();
      } else {
        currentData['spread'] = _spreadController.text.trim();
      }

      // Normalize original data for comparison
      final originalData = <String, dynamic>{};
      originalData['properties'] =
          List<String>.from(_originalMortgageData!['properties'] ?? []);
      originalData['bank_name'] = _originalMortgageData!['bank_name'] ?? '';
      originalData['bank_address'] =
          _originalMortgageData!['bank_address'] ?? '';
      originalData['bank_contact_no'] =
          _originalMortgageData!['bank_contact_no'] ?? '';
      originalData['bank_email'] = _originalMortgageData!['bank_email'] ?? '';
      originalData['relationship_manager_first_name'] =
          _originalMortgageData!['relationship_manager_first_name'] ?? '';
      originalData['relationship_manager_last_name'] =
          _originalMortgageData!['relationship_manager_last_name'] ?? '';
      originalData['relationship_manager_phone'] =
          _originalMortgageData!['relationship_manager_phone'] ?? '';
      originalData['relationship_manager_email'] =
          _originalMortgageData!['relationship_manager_email'] ?? '';
      originalData['mortgage_no'] = _originalMortgageData!['mortgage_no'] ?? '';
      originalData['mortgage_type'] =
          _originalMortgageData!['mortgage_type'] ?? '';
      originalData['loan_amount'] =
          _originalMortgageData!['loan_amount']?.toString() ?? '';
      originalData['interest_rate'] =
          _originalMortgageData!['interest_rate']?.toString() ?? '';
      originalData['start_date'] =
          _originalMortgageData!['start_date']?.toString() ?? '';
      originalData['end_date'] =
          _originalMortgageData!['end_date']?.toString() ?? '';
      originalData['amortization_period'] =
          _originalMortgageData!['amortization_period']?.toString() ?? '';
      originalData['status'] =
          _originalMortgageData!['status']?.toString() ?? '';
      originalData['remaining_balance'] =
          _originalMortgageData!['remaining_balance']?.toString() ?? '';
      originalData['monthly_principal'] =
          _originalMortgageData!['monthly_principal']?.toString() ?? '';
      originalData['monthly_interest'] =
          _originalMortgageData!['monthly_interest']?.toString() ?? '';
      originalData['monthly_payment'] =
          _originalMortgageData!['monthly_payment']?.toString() ?? '';
      originalData['last_payment_date'] =
          _originalMortgageData!['last_payment_date']?.toString() ?? '';
      originalData['next_payment_date'] =
          _originalMortgageData!['next_payment_date']?.toString() ?? '';
      originalData['borrower_first_name'] =
          _originalMortgageData!['borrower_first_name'] ?? '';
      originalData['borrower_last_name'] =
          _originalMortgageData!['borrower_last_name'] ?? '';
      originalData['borrower_company_name'] =
          _originalMortgageData!['borrower_company_name'] ?? '';
      originalData['borrower_address'] =
          _originalMortgageData!['borrower_address'] ?? '';
      originalData['borrower_phone'] =
          _originalMortgageData!['borrower_phone'] ?? '';
      originalData['borrower_email'] =
          _originalMortgageData!['borrower_email'] ?? '';

      // Handle payoffs - normalize dates to ISO8601 format for comparison
      if (_originalMortgageData!['payoffs'] != null &&
          _originalMortgageData!['payoffs'] is List) {
        originalData['payoffs'] =
            (_originalMortgageData!['payoffs'] as List).map((payoff) {
          String dateStr = '';
          if (payoff['date'] != null) {
            try {
              // If it's already a DateTime object, convert to ISO8601
              if (payoff['date'] is DateTime) {
                dateStr = (payoff['date'] as DateTime).toIso8601String();
              } else {
                // If it's a string, try to parse and convert to ISO8601
                dateStr =
                    DateTime.parse(payoff['date'].toString()).toIso8601String();
              }
            } catch (e) {
              dateStr = payoff['date']?.toString() ?? '';
            }
          }
          return {
            'amount': payoff['amount'],
            'date': dateStr,
            if (payoff['_id'] != null) '_id': payoff['_id'],
          };
        }).toList();
      } else {
        originalData['payoffs'] = [];
      }

      // Handle conditional fields
      if (isFixedRate) {
        originalData['fixed_interest_period'] =
            _originalMortgageData!['fixed_interest_period']?.toString() ?? '';
        originalData['fixed_interest_expiration_date'] =
            _originalMortgageData!['fixed_interest_expiration_date']
                    ?.toString() ??
                '';
        originalData['spread_on_floating_rate'] =
            _originalMortgageData!['spread_on_floating_rate']?.toString() ?? '';
      } else {
        originalData['spread'] =
            _originalMortgageData!['spread']?.toString() ?? '';
      }

      // Compare properties lists
      final currentProps = List<String>.from(currentData['properties'] ?? [])
        ..sort();
      final originalProps = List<String>.from(originalData['properties'] ?? [])
        ..sort();
      if (currentProps.toString() != originalProps.toString()) {
        return true;
      }

      // Compare payoffs
      final currentPayoffs = List.from(currentData['payoffs'] ?? []);
      final originalPayoffs = List.from(originalData['payoffs'] ?? []);
      if (currentPayoffs.length != originalPayoffs.length) {
        return true;
      }
      for (int i = 0; i < currentPayoffs.length; i++) {
        final currentPayoff = currentPayoffs[i];
        final originalPayoff = originalPayoffs[i];
        if (currentPayoff['amount'] != originalPayoff['amount'] ||
            currentPayoff['date'] != originalPayoff['date']) {
          return true;
        }
      }

      // Compare all other fields
      for (String key in currentData.keys) {
        if (key != 'properties' && key != 'payoffs') {
          if (currentData[key] != originalData[key]) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      logError('Error comparing data: $e');
      // If comparison fails, assume there are changes to be safe
      return true;
    }
  }

  void _saveForm() async {
    // Validate dates before form validation
    if (_startDate != null && _endDate != null) {
      if (_endDate!.isBefore(_startDate!) ||
          _endDate!.isAtSameMomentAs(_startDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maturity Date must be after Origination Date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Check if in edit mode and if there are any changes - do this before business logic validations
    if (widget.mortgageId != null && !_hasChanges()) {
      // No changes made, don't call API and skip business logic validations
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes detected. Nothing to update.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Validate Last Payment Date (if provided, cannot be in the future)
    if (_lastPaymentDate != null) {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final lastPaymentDateOnly = DateTime(_lastPaymentDate!.year,
          _lastPaymentDate!.month, _lastPaymentDate!.day);

      if (lastPaymentDateOnly.isAfter(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Last payment date cannot be in the future'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate Next Payment Date (if provided, cannot be in the past)
    if (_nextPaymentDate != null) {
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);
      final nextPaymentDateOnly = DateTime(_nextPaymentDate!.year,
          _nextPaymentDate!.month, _nextPaymentDate!.day);

      if (nextPaymentDateOnly.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Next payment date cannot be in the past'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (_formKey.currentState!.validate()) {
      final mortgageNo = _mortgageNumberController.text.trim();
      if (mortgageNo.isNotEmpty) {
        final isDuplicate = await _isDuplicateMortgageNo(mortgageNo);
        if (isDuplicate && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'This loan number is already in use. Please enter a unique loan number.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() {
        _isLoading = true;
      });

      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? token = prefs.getString('token');
        String? adminid = prefs.getString("adminId");
        String? id = prefs.getString("staff_id");

        // Prepare the data according to your API structure
        // If no properties selected but propertyId is available from context, use it
        List<String> propertyIds = _selectedProperties
            .map((p) => p['rental_id'].toString())
            .toList()
            .cast<String>();
        if (propertyIds.isEmpty &&
            widget.propertyId != null &&
            widget.propertyId!.isNotEmpty) {
          propertyIds = [widget.propertyId!];
        }

        // Determine mortgage type
        final mortgageType = _selectedMortgageType.isNotEmpty
            ? _selectedMortgageType
            : _typeController.text.trim();
        final isFixedRate = mortgageType == 'Fixed Rate Mortgage';

        // Build base mortgage data
        final mortgageData = <String, dynamic>{
          'properties': propertyIds,
          'bank_name': _bankNameController.text.trim(),
          'bank_address': _bankAddressController.text.trim(),
          'bank_contact_no': _bankContactController.text.trim(),
          'bank_email': _bankEmailController.text.trim(),
          'relationship_manager_first_name':
              _managerFirstNameController.text.trim(),
          'relationship_manager_last_name':
              _managerLastNameController.text.trim(),
          'relationship_manager_phone': _managerPhoneController.text.trim(),
          'relationship_manager_email': _managerEmailController.text.trim(),
          'mortgage_no': _mortgageNumberController.text.trim(),
          // Map dropdown values to API enum values
          'mortgage_type': isFixedRate ? 'fixed_rate' : 'floating_rate',
          'loan_amount': _loanAmountController.text.trim(),
          'interest_rate': _interestRateController.text.trim(),
          'start_date': _startDate != null ? _startDate!.toIso8601String() : '',
          'end_date': _endDate != null ? _endDate!.toIso8601String() : '',
          'amortization_period': _amortizationPeriodController.text.trim(),
          //  'status': _statusController.text.trim().toLowerCase(),
          'status':
              _statusController.text.trim().toLowerCase().replaceAll(' ', '_'),
          'remaining_balance': _remainingBalanceController.text.trim(),
          // Only declare a principal/interest breakdown when the user has
          // one. Sending 0/0 with payment_entry_mode set made the server
          // recompute monthly_payment as 0 + 0 and overwrite the stored value
          // on every Update, even with no edit (MortgageController.js:1344).
          // With these keys absent the server keeps the mode as 'total' and
          // persists the monthly_payment sent below unchanged.
          if (_principalController.text.trim().isNotEmpty ||
              _interestController.text.trim().isNotEmpty) ...{
            'payment_entry_mode': 'principal_interest',
            'monthly_principal':
                double.tryParse(_principalController.text.trim()) ?? 0,
            'monthly_interest':
                double.tryParse(_interestController.text.trim()) ?? 0,
          },
          'monthly_payment': double.tryParse(
                  _monthlyPaymentDisplayController.text.trim()) ??
              0,
          'last_payment_date': _lastPaymentDate != null
              ? _lastPaymentDate!.toIso8601String()
              : '',
          'next_payment_date': _nextPaymentDate != null
              ? _nextPaymentDate!.toIso8601String()
              : '',
          'borrower_first_name': _borrowerFirstNameController.text.trim(),
          'borrower_last_name': _borrowerLastNameController.text.trim(),
          'borrower_company_name': _borrowerCompanyNameController.text.trim(),
          'borrower_address': _borrowerAddressController.text.trim(),
          'borrower_phone': _borrowerPhoneController.text.trim(),
          'borrower_email': _borrowerEmailController.text.trim(),
          'payoffs': _payoffs
              .map((payoff) => {
                    'amount': payoff['amount'],
                    'date': (payoff['date'] as DateTime).toIso8601String(),
                    if (payoff['_id'] != null) '_id': payoff['_id'],
                  })
              .toList(),
        };

        // Add conditional fields based on mortgage type
        if (isFixedRate) {
          mortgageData['fixed_interest_period'] =
              _fixedInterestPeriodController.text.trim();
          mortgageData['fixed_interest_expiration_date'] =
              _fixedInterestExpirationDate != null
                  ? _fixedInterestExpirationDate!.toIso8601String()
                  : '';
          mortgageData['spread_on_floating_rate'] =
              _spreadOnFloatingRateController.text.trim();
        } else {
          mortgageData['spread'] = _spreadController.text.trim();
        }

        http.Response response;
        String apiUrl = '$Api_url/api/mortgage';

        if (widget.mortgageId != null) {
          // Update existing mortgage (PUT)
          response = await http
              .put(
                Uri.parse('$apiUrl/${widget.mortgageId}'),
                headers: {
                  'Content-Type': 'application/json',
                  'authorization': 'CRM $token',
                  'id': 'CRM $id',
                },
                body: json.encode(mortgageData),
              )
              .timeout(const Duration(seconds: 30));
        } else {
          // Create new mortgage (POST)
          response = await http
              .post(
                Uri.parse(apiUrl),
                headers: {
                  'Content-Type': 'application/json',
                  'authorization': 'CRM $token',
                  'id': 'CRM $id',
                },
                body: json.encode(mortgageData),
              )
              .timeout(const Duration(seconds: 30));
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(widget.mortgageId != null
                    ? 'Mortgage updated successfully!'
                    : 'Mortgage created successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            final errorData = json.decode(response.body);
            final errorMessage =
                errorData['message'] ?? 'Failed to save mortgage';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving mortgage: ${friendlyErrorMessage(e)}'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: widget.drawerCurrentPage ?? "Mortgage",
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
                  //if appliance is not null then show edit else show add
                  child: Text(
                    widget.mortgageId != null
                        ? 'Edit Mortgage Information'
                        : 'Add Mortgage Information',
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Property Selection Section

                    // if (_isLoadingProperties)
                    //   Container(
                    //     padding: const EdgeInsets.all(16),
                    //     child: Center(
                    //       child: Column(
                    //         children: [
                    //           SpinKitFadingCircle(
                    //             color: Colors.black,
                    //             size: 50.0,
                    //           ),
                    //           SizedBox(height: 8),
                    //           Text('Loading properties...'),
                    //         ],
                    //       ),
                    //     ),
                    //   )
                    // else if (_propertyOptions.isEmpty)
                    //   Container(
                    //     padding: const EdgeInsets.all(16),
                    //     child: Center(
                    //       child: Column(
                    //         children: [
                    //           Icon(Icons.home_outlined,
                    //               size: 48, color: Colors.grey[400]),
                    //           const SizedBox(height: 8),
                    //           Text(
                    //             'No properties available',
                    //             style: TextStyle(color: Colors.grey[600]),
                    //           ),
                    //           const SizedBox(height: 8),
                    //           ElevatedButton(
                    //             onPressed: _loadProperties,
                    //             child: const Text('Retry'),
                    //           ),
                    //         ],
                    //       ),
                    //     ),
                    //   )
                    // else
                    //   _buildMultiSelectField(
                    //     label: 'Select Properties *',
                    //     hint: 'Select properties...',
                    //     validator: _validateProperties,
                    //     items: _propertyOptions,
                    //     selectedItems: _selectedProperties,
                    //     onSelectionChanged:
                    //         (List<Map<String, dynamic>> selectedItems) {
                    //       setState(() {
                    //         _selectedProperties.clear();
                    //         _selectedProperties.addAll(selectedItems);
                    //       });
                    //     },
                    //   ),
                    // const SizedBox(height: 24),

                    // Bank (lender) section
                    _buildSectionHeader('Bank',
                        subtitle:
                            'Enter the Lender and contact details.'),
                    _buildTextField(
                      controller: _bankNameController,
                      label: 'Bank Name *',
                      hint: 'Enter Bank Name',
                      validator: (value) =>
                          _validateRequired(value, 'Bank name'),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bankAddressController,
                      label: 'Address',
                      hint: 'Enter Bank Address',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bankContactController,
                      label: 'Phone',
                      hint: '(xxx) xxx-xxxx',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneNumberFormatter()],
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bankEmailController,
                      label: 'Email',
                      hint: 'Enter Bank Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 24),

                    // Relationship Manager section
                    _buildSectionHeader('Relationship Manager',
                        subtitle:
                            'Optional point of contact for this loan.'),
                    _buildTextField(
                      controller: _managerFirstNameController,
                      label: 'First Name',
                      hint: 'Enter First Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _managerLastNameController,
                      label: 'Last Name',
                      hint: 'Enter Last Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _managerPhoneController,
                      label: 'Phone',
                      hint: '(xxx) xxx-xxxx',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneNumberFormatter()],
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _managerEmailController,
                      label: 'Email',
                      hint: 'Enter Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 24),

                    // Mortgage Details Section
                    _buildSectionHeader('Mortgage Details',
                        subtitle:
                            'Loan type, identifiers, and key terms.'),
                    _buildTextField(
                      controller: _mortgageNumberController,
                      label: 'Loan Number *',
                      hint: 'Enter Loan Number',
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        String? requiredError =
                            _validateRequired(value, 'Loan number');
                        if (requiredError != null) return requiredError;
                        return _validateMortgageNumber(value);
                      },
                    ),
                   
                   const SizedBox(height: 16),
                      Builder(
                      builder: (context) {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        final dateHint = _getDateHintText(dateProvider);
                        return _buildDateField(
                          controller: _startDateController,
                          label: 'Inception Date *',
                          hint: dateHint,
                          validator: (value) =>
                              _validateRequired(value, 'Inception Date'),
                          onTap: () {
                            final DateTime now = DateTime.now();
                            final DateTime today =
                                DateTime(now.year, now.month, now.day);
                            // Do not allow future dates for Origination Date
                            _selectDate(
                              context,
                              _startDateController,
                              _startDate,
                              firstDate: DateTime(2000),
                              lastDate: today,
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        final dateHint = _getDateHintText(dateProvider);
                        return _buildDateField(
                          controller: _endDateController,
                          label: 'Maturity Date *',
                          hint: dateHint,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Maturity Date is required';
                            }
                            if (_startDate != null && _endDate != null) {
                              if (_endDate!.isBefore(_startDate!) ||
                                  _endDate!.isAtSameMomentAs(_startDate!)) {
                                return 'Maturity Date must be after Origination Date';
                              }
                            }
                            return null;
                          },
                          onTap: () {
                            if (_startDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please select Origination Date first'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            // Maturity date must be after origination date
                            // Add 1 day to start date to ensure it's after
                            final minDate = DateTime(_startDate!.year,
                                    _startDate!.month, _startDate!.day)
                                .add(const Duration(days: 1));
                            _selectDate(context, _endDateController, _endDate,
                                firstDate: minDate);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                     _buildDropdownField(
                        controller: _typeController,
                        label: 'Term Type *',
                        hint: 'Select Term Type',
                        validator: (value) =>
                            _validateRequired(value, 'Term type'),
                        items: _typeOptions,
                        onChanged: (String? newValue) {
                          setState(() {
                            _typeController.text = newValue ?? '';
                            _selectedMortgageType = newValue ?? '';
                            // Clear conditional fields when type changes
                            if (newValue == 'Fixed Rate Mortgage') {
                              _spreadController.clear();
                            } else if (newValue == 'Floating Rate Mortgage') {
                              _fixedInterestPeriodController.clear();
                              _fixedInterestExpirationDateController.clear();
                              _fixedInterestExpirationDate = null;
                              _spreadOnFloatingRateController.clear();
                            }
                          });
                        }),
                    
                    const SizedBox(height: 16),
                   
                    _buildTextField(
                      controller: _amortizationPeriodController,
                      label: 'Amortization Period (Months)',
                      hint: 'Enter Amortization Period (Months)',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) =>
                          _validateOptionalNonNegativeInt(
                              value, 'amortization period'),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _interestRateController,
                      label: 'Interest Rate',
                      hint: 'Enter Interest Rate %',
                      // Web parity: decimal keyboard; digits + a single decimal point only.
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) =>
                            RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                ? newValue
                                : oldValue),
                      ],
                      validator: _validateInterestRate,
                    ),
                    const SizedBox(height: 16),
                   _buildTextField(
                      controller: _loanAmountController,
                      label: 'Loan Amount',
                      hint: 'Enter Loan Amount',
                      // Web parity: decimal keyboard; digits + a single decimal point only.
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) =>
                            RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                ? newValue
                                : oldValue),
                      ],
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _remainingBalanceController,
                      label: 'Current Balance',
                      hint: '\$ Enter current balance',
                      // Web parity: decimal keyboard; digits + a single decimal point only.
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) =>
                            RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                ? newValue
                                : oldValue),
                      ],
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _principalController,
                      label: 'Monthly Principal',
                      hint: 'Enter monthly principal',
                      // Web parity: digits + a single decimal point only.
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) =>
                            RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                ? newValue
                                : oldValue),
                      ],
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _interestController,
                      label: 'Monthly Interest',
                      hint: 'Enter monthly interest',
                      // Web parity: digits + a single decimal point only.
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) =>
                            RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                ? newValue
                                : oldValue),
                      ],
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _monthlyPaymentDisplayController,
                      label: 'Monthly Payment',
                      hint: '0.00',
                      readOnly: true,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    // Conditional fields based on mortgage type
                    if (_selectedMortgageType == 'Fixed Rate Mortgage' ||
                        (_selectedMortgageType.isEmpty &&
                            _typeController.text == 'Fixed Rate Mortgage')) ...[
                      _buildTextField(
                        controller: _fixedInterestPeriodController,
                        label: 'Fixed Interest Period (Months)',
                        hint: 'Enter fixed interest period in months',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) =>
                            _validateOptionalNonNegativeInt(
                                value, 'fixed interest period'),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final dateProvider =
                              Provider.of<DateProvider>(context, listen: false);
                          final dateHint = _getDateHintText(dateProvider);
                          return _buildDateField(
                            controller: _fixedInterestExpirationDateController,
                            label: 'Fixed Interest Expiration Date',
                            hint: dateHint,
                            onClear: () => _clearDate(
                                _fixedInterestExpirationDateController),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }
                              if (_startDate != null &&
                                  _endDate != null &&
                                  _fixedInterestExpirationDate != null) {
                                // Must be strictly between Origination and Maturity dates (exclusive)
                                final startDateOnly = DateTime(_startDate!.year,
                                    _startDate!.month, _startDate!.day);
                                final endDateOnly = DateTime(_endDate!.year,
                                    _endDate!.month, _endDate!.day);
                                final expirationDateOnly = DateTime(
                                    _fixedInterestExpirationDate!.year,
                                    _fixedInterestExpirationDate!.month,
                                    _fixedInterestExpirationDate!.day);

                                if (expirationDateOnly
                                        .isBefore(startDateOnly) ||
                                    expirationDateOnly
                                        .isAtSameMomentAs(startDateOnly) ||
                                    expirationDateOnly.isAfter(endDateOnly) ||
                                    expirationDateOnly
                                        .isAtSameMomentAs(endDateOnly)) {
                                  return 'Must be strictly between Origination and Maturity dates';
                                }
                              }
                              return null;
                            },
                            onTap: () {
                              if (_startDate == null || _endDate == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Please select Origination Date and Maturity Date first'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              // Fixed Interest Expiration Date must be strictly between start and end dates
                              // After origination date (at least 1 day after)
                              final minDate = DateTime(_startDate!.year,
                                      _startDate!.month, _startDate!.day)
                                  .add(const Duration(days: 1));
                              // Before maturity date (at least 1 day before)
                              final maxDate = DateTime(_endDate!.year,
                                      _endDate!.month, _endDate!.day)
                                  .subtract(const Duration(days: 1));

                              // Allow 2-day gap: if maturity is exactly 2 days after origination,
                              // there's still 1 day in between for expiration date
                              // Only show error if there's less than 2 days gap (i.e., maturity is same day or next day)
                              final daysDifference =
                                  _endDate!.difference(_startDate!).inDays;
                              if (daysDifference < 2) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Maturity Date must be at least 2 days after Origination Date for Fixed Interest Expiration Date'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              _selectDate(
                                context,
                                _fixedInterestExpirationDateController,
                                _fixedInterestExpirationDate,
                                firstDate: minDate,
                                lastDate: maxDate,
                                clearable: true,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _spreadOnFloatingRateController,
                        label: 'Spread on Floating Rate (%)',
                        hint: 'Enter spread on floating rate',
                        // Web parity: decimal % — digits + a single decimal point.
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          TextInputFormatter.withFunction((oldValue, newValue) =>
                              RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                  ? newValue
                                  : oldValue),
                        ],
                        validator: _validateInterestRate,
                      ),
                      const SizedBox(height: 16),
                    ] else if (_selectedMortgageType ==
                            'Floating Rate Mortgage' ||
                        (_selectedMortgageType.isEmpty &&
                            _typeController.text ==
                                'Floating Rate Mortgage')) ...[
                      _buildTextField(
                        controller: _spreadController,
                        label: 'Spread (%)',
                        hint: 'Enter spread',
                        // Web parity: decimal % — digits + a single decimal point.
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          TextInputFormatter.withFunction((oldValue, newValue) =>
                              RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                                  ? newValue
                                  : oldValue),
                        ],
                        validator: _validateInterestRate,
                      ),
                      const SizedBox(height: 16),
                    ],
                    // _buildDropdownField(
                    //   controller: _statusController,
                    //   label: 'Status *',
                    //   hint: 'Select status',
                    //   validator: (value) => _validateRequired(value, 'Status'),
                    //   items: _statusOptions,
                    // ),
                   
                    const SizedBox(height: 16),
              
                    Builder(
                      builder: (context) {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        final dateHint = _getDateHintText(dateProvider);
                        return _buildDateField(
                          controller: _lastPaymentDateController,
                          label: 'Last Payment Date',
                          hint: dateHint,
                          onClear: () =>
                              _clearDate(_lastPaymentDateController),
                          onTap: () {
                            final DateTime now = DateTime.now();
                            final DateTime today =
                                DateTime(now.year, now.month, now.day);
                            // Allow today and past dates, but not future dates
                            _selectDate(context, _lastPaymentDateController,
                                _lastPaymentDate,
                                firstDate: DateTime(2000),
                                lastDate: today,
                                clearable: true);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        final dateHint = _getDateHintText(dateProvider);
                        return _buildDateField(
                          controller: _nextPaymentDateController,
                          label: 'Next Payment Date',
                          hint: dateHint,
                          onClear: () =>
                              _clearDate(_nextPaymentDateController),
                          onTap: () {
                            final DateTime now = DateTime.now();
                            final DateTime today =
                                DateTime(now.year, now.month, now.day);
                            // Don't let select past dates, allow today and future dates
                            _selectDate(context, _nextPaymentDateController,
                                _nextPaymentDate,
                                firstDate: today,
                                lastDate: DateTime(2100),
                                clearable: true);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Not providing principal and interest amounts will prevent DSCR from being calculated.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Borrower Information Section
                    _buildSectionHeader('Borrower',
                        subtitle:
                            'Primary borrower contact and address.'),
                    _buildTextField(
                      controller: _borrowerFirstNameController,
                      label: 'First Name',
                      hint: 'First Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _borrowerLastNameController,
                      label: 'Last Name',
                      hint: 'Last Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _borrowerCompanyNameController,
                      label: 'Company Name',
                      hint: 'Company Name',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _borrowerPhoneController,
                      label: 'Phone',
                      hint: '(xxx) xxx-xxxx',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [PhoneNumberFormatter()],
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _borrowerEmailController,
                      label: 'Email',
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _borrowerAddressController,
                      label: 'Address',
                      hint: 'Enter Address',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    // _buildSectionHeader('Payoff History'),
                    // _buildPayoffHistorySection(),
                    // const SizedBox(height: 16),

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
                                      widget.mortgageId != null
                                          ? 'Update'
                                          : 'Save',
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
                    const SizedBox(height: 32),
                  ],


                  
                ),
              ),
            ),
            // Action Buttons
            // Container(
            //   padding: const EdgeInsets.all(16.0),
            //   decoration: BoxDecoration(
            //     color: Colors.white,
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.grey.withOpacity(0.2),
            //         spreadRadius: 1,
            //         blurRadius: 5,
            //         offset: const Offset(0, -2),
            //       ),
            //     ],
            //   ),
            //   child: Row(
            //     children: [
            //       Expanded(
            //         child: OutlinedButton(
            //           onPressed:
            //               _isLoading ? null : () => Navigator.pop(context),
            //           style: OutlinedButton.styleFrom(
            //             padding: const EdgeInsets.symmetric(vertical: 16),
            //             side: BorderSide(color: blueColor),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(8),
            //             ),
            //           ),
            //           child: Text(
            //             'Cancel',
            //             style: TextStyle(
            //               color: blueColor,
            //               fontSize: 16,
            //               fontWeight: FontWeight.w600,
            //             ),
            //           ),
            //         ),
            //       ),
            //       const SizedBox(width: 16),
            //       Expanded(
            //         child: ElevatedButton(
            //           onPressed: _isLoading ? null : _saveForm,
            //           style: ElevatedButton.styleFrom(
            //             backgroundColor: blueColor,
            //             padding: const EdgeInsets.symmetric(vertical: 16),
            //             shape: RoundedRectangleBorder(
            //               borderRadius: BorderRadius.circular(8),
            //             ),
            //           ),
            //           child: _isLoading
            //               ? const SizedBox(
            //                   height: 20,
            //                   width: 20,
            //                   child: CircularProgressIndicator(
            //                     strokeWidth: 2,
            //                     valueColor:
            //                         AlwaysStoppedAnimation<Color>(Colors.white),
            //                   ),
            //                 )
            //               : Text(
            //                   widget.mortgageId != null ? 'Update' : 'Save',
            //                   style: const TextStyle(
            //                     color: Colors.white,
            //                     fontSize: 16,
            //                     fontWeight: FontWeight.w600,
            //                   ),
            //                 ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
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
    bool readOnly = false,
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
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          inputFormatters: inputFormatters ?? [],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: readOnly,
            fillColor: readOnly ? Colors.grey[200] : null,
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
              borderSide: BorderSide(color: blueColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red[300]!),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red[500]!, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VoidCallback onTap,
    String? Function(String?)? validator,
    // Optional date fields pass this so the field gets a "clear" (X) action.
    VoidCallback? onClear,
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
        GestureDetector(
          // When the field is clearable the suffix holds its own tap targets,
          // so the taps must reach it instead of being absorbed here.
          onTap: onClear == null ? onTap : null,
          child: AbsorbPointer(
            absorbing: onClear == null,
            child: TextFormField(
              controller: controller,
              validator: validator,
              readOnly: onClear != null,
              onTap: onClear == null ? null : onTap,
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
                  borderSide: BorderSide(color: blueColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: onClear == null
                    ? Icon(
                        Icons.calendar_today,
                        color: blueColor,
                      )
                    : ClearableDateSuffix(
                        controller: controller,
                        onPick: onTap,
                        onClear: onClear,
                        icon: Icons.calendar_today,
                        iconColor: blueColor,
                        iconSize: 20,
                      ),
              ),
            ),
          ),
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
    Function(String?)? onChanged,
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
        DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
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
              borderSide: BorderSide(color: blueColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red[300]!),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red[500]!, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              controller.text = newValue ?? '';
            });
            if (onChanged != null) {
              onChanged(newValue);
            }
          },
          validator: validator,
          icon: Icon(Icons.arrow_drop_down, color: blueColor),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField({
    required String label,
    required String hint,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> selectedItems,
    required Function(List<Map<String, dynamic>>) onSelectionChanged,
    String? Function()? validator,
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Selected Properties Tags
              if (selectedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedItems.map((property) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: blueColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: blueColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              property['address'] ?? 'Unknown Property',
                              style: TextStyle(
                                color: blueColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                final newSelection =
                                    List<Map<String, dynamic>>.from(
                                        selectedItems);
                                newSelection.remove(property);
                                onSelectionChanged(newSelection);
                              },
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: blueColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Dropdown Button
              InkWell(
                onTap: () {
                  _showPropertySelectionDialog(
                      context, items, selectedItems, onSelectionChanged);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedItems.isEmpty
                              ? hint
                              : '${selectedItems.length} properties selected',
                          style: TextStyle(
                            color: selectedItems.isEmpty
                                ? Colors.grey[400]
                                : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: blueColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (validator != null)
          Builder(
            builder: (context) {
              final error = validator();
              if (error != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    error,
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

  void _showPropertySelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> selectedItems,
    Function(List<Map<String, dynamic>>) onSelectionChanged,
  ) {
    List<Map<String, dynamic>> tempSelection = List.from(selectedItems);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Properties'),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select All Checkbox
                    CheckboxListTile(
                      title: const Text(
                        'Select All',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: tempSelection.length == items.length,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelection = List.from(items);
                          } else {
                            tempSelection.clear();
                          }
                        });
                      },
                      activeColor: blueColor,
                    ),
                    const Divider(),
                    // Property List
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final property = items[index];
                          final isSelected = tempSelection.contains(property);
                          return CheckboxListTile(
                            title: Text(
                              property['address'] ?? 'Unknown Property',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              '${property['city'] ?? ''} ${property['state'] ?? ''} ${property['zipcode'] ?? ''}'
                                  .trim(),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  if (!tempSelection.contains(property)) {
                                    tempSelection.add(property);
                                  }
                                } else {
                                  tempSelection.remove(property);
                                }
                              });
                            },
                            activeColor: blueColor,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSelectionChanged(tempSelection);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPayoffHistorySection() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Payoff List - Card Based Design
        if (_payoffs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Center(
              child: Text(
                'No payoffs added yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          Column(
            children: _payoffs.asMap().entries.map((entry) {
              final index = entry.key;
              final payoff = entry.value;
              final bool isEditing = _editingPayoffIndex == index;

              DateTime payoffDate;
              if (payoff['date'] is DateTime) {
                payoffDate = payoff['date'];
              } else {
                payoffDate = DateTime.parse(payoff['date'].toString());
              }

              // Check 24-hour lock based on created_at, not date
              bool is24HoursOld = false;
              final bool isSaved = payoff['_id'] != null;
              if (isSaved && payoff['created_at'] != null) {
                DateTime createdAt;
                if (payoff['created_at'] is DateTime) {
                  createdAt = payoff['created_at'];
                } else {
                  createdAt = DateTime.parse(payoff['created_at'].toString());
                }
                final Duration difference = now.difference(createdAt);
                is24HoursOld = difference.inHours >= 24;
              }

              // Format date using DateProvider
              String apiFormatDate =
                  DateFormat('yyyy-MM-dd').format(payoffDate);

              return Container(
                margin: EdgeInsets.only(
                    bottom: index < _payoffs.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isEditing
                    ? _buildEditingPayoffCard(index, payoff)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Amount and Locked Status Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Amount - Simple text, no green badge
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payoff Amount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatMoney(payoff['amount']),
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[900],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // Locked Badge (if locked)
                              if (isSaved && is24HoursOld)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: Colors.orange[300]!),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 14,
                                        color: Colors.orange[800],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Locked (24h+)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange[800],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Date Row with Edit Button beside it
                          Builder(
                            builder: (context) {
                              final dateProvider = Provider.of<DateProvider>(
                                  context,
                                  listen: false);
                              String displayDate =
                                  dateProvider.formatCurrentDate(apiFormatDate);
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayDate,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Simple Edit Icon Button beside date
                                  IconButton(
                                    onPressed: isSaved && is24HoursOld
                                        ? null
                                        : () => _startEditingPayoff(index),
                                    icon: Icon(
                                      Icons.edit,
                                      size: 18,
                                      color: isSaved && is24HoursOld
                                          ? Colors.grey[400]
                                          : blueColor,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: isSaved && is24HoursOld
                                        ? 'Locked (24h+)'
                                        : 'Edit',
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
              );
            }).toList(),
          ),
        // Add Payoff Form (shown when button is clicked)
        if (_showAddPayoffForm) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+ Add New Payoff',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _newPayoffAmountController,
                            decoration: InputDecoration(
                              prefixText: '\$',
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _newPayoffDate ?? today,
                                firstDate: DateTime(2000),
                                lastDate: today,
                                builder: (BuildContext context, Widget? child) {
                                  return Theme(
                                    data: ThemeData.light().copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: blueColor,
                                        onPrimary: Colors.white,
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: blueColor,
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _newPayoffDate = picked;
                                  final dateProvider =
                                      Provider.of<DateProvider>(context,
                                          listen: false);
                                  String apiFormatDate =
                                      DateFormat('yyyy-MM-dd').format(picked);
                                  _newPayoffDateController.text = dateProvider
                                      .formatCurrentDate(apiFormatDate);
                                });
                              }
                            },
                            child: AbsorbPointer(
                              child: TextFormField(
                                controller: _newPayoffDateController,
                                decoration: InputDecoration(
                                  hintText: 'dd-mm-yyyy',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  suffixIcon: Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: blueColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveNewPayoff,
                        icon: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                        label: const Text(
                          'Save Payoff',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _newPayoffAmountController.clear();
                                  _newPayoffDateController.clear();
                                  _newPayoffDate = null;
                                  _showAddPayoffForm = false;
                                });
                              },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.red[300]!),
                          foregroundColor: Colors.red[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        // Add Payoff Button (Below the list) - Always shows "ADD PAYOFF"
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        if (_showAddPayoffForm) {
                          // If form is open, close it and clear fields
                          _newPayoffAmountController.clear();
                          _newPayoffDateController.clear();
                          _newPayoffDate = null;
                          _showAddPayoffForm = false;
                        } else {
                          // If form is closed, open it
                          _showAddPayoffForm = true;
                        }
                      });
                    },
              icon: Icon(
                Icons.add,
                color: blueColor,
                size: 18,
              ),
              label: Text(
                'ADD PAYOFF',
                style: TextStyle(
                  color: blueColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              // style: OutlinedButton.styleFrom(
              //   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              //   side: BorderSide(color: blueColor, width: 1.5),
              //   shape: RoundedRectangleBorder(
              //     borderRadius: BorderRadius.circular(6),
              //   ),
              // ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditingPayoffCard(int index, Map<String, dynamic> payoff) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _editingPayoffAmountController,
                    decoration: InputDecoration(
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final DateTime now = DateTime.now();
                      final DateTime today =
                          DateTime(now.year, now.month, now.day);
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _editingPayoffDate ?? today,
                        firstDate: DateTime(2000),
                        lastDate: today,
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: blueColor,
                                onPrimary: Colors.white,
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: blueColor,
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _editingPayoffDate = picked;
                          final dateProvider =
                              Provider.of<DateProvider>(context, listen: false);
                          String apiFormatDate =
                              DateFormat('yyyy-MM-dd').format(picked);
                          _editingPayoffDateController.text =
                              dateProvider.formatCurrentDate(apiFormatDate);
                        });
                      }
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _editingPayoffDateController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: blueColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _saveEditingPayoff(index),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _deletePayoff(index),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.red[300]!),
                  foregroundColor: Colors.red[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _saveNewPayoff() {
    if (_newPayoffAmountController.text.trim().isEmpty ||
        _newPayoffDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _payoffs.add({
        'amount': (double.tryParse(_newPayoffAmountController.text.trim()) ?? 0.0),
        'date': _newPayoffDate!,
      });
      _newPayoffAmountController.clear();
      _newPayoffDateController.clear();
      _newPayoffDate = null;
      _showAddPayoffForm = false;
    });
  }

  void _startEditingPayoff(int index) {
    final payoff = _payoffs[index];
    setState(() {
      _editingPayoffIndex = index;
      _editingPayoffAmountController.text = payoff['amount'].toString();
      DateTime? date;
      if (payoff['date'] is DateTime) {
        date = payoff['date'];
      } else {
        date = DateTime.parse(payoff['date'].toString());
      }
      _editingPayoffDate = date;
      if (date != null) {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(date);
        _editingPayoffDateController.text =
            dateProvider.formatCurrentDate(apiFormatDate);
      }
    });
  }

  void _saveEditingPayoff(int index) {
    if (_editingPayoffAmountController.text.trim().isEmpty ||
        _editingPayoffDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      _payoffs[index] = {
        'amount': (double.tryParse(_editingPayoffAmountController.text.trim()) ?? 0.0),
        'date': _editingPayoffDate!,
        '_id': _payoffs[index]['_id'],
      };
      _cancelEditingPayoff();
    });
  }

  void _cancelEditingPayoff() {
    setState(() {
      _editingPayoffIndex = null;
      _editingPayoffAmountController.clear();
      _editingPayoffDateController.clear();
      _editingPayoffDate = null;
    });
  }

  void _deletePayoff(int index) {
    // If currently editing this payoff, cancel editing first
    if (_editingPayoffIndex == index) {
      _cancelEditingPayoff();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Payoff'),
          content: const Text('Are you sure you want to delete this payoff?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _payoffs.removeAt(index);
                  // Reset editing index if needed
                  if (_editingPayoffIndex != null &&
                      _editingPayoffIndex! >= _payoffs.length) {
                    _editingPayoffIndex = null;
                  } else if (_editingPayoffIndex != null &&
                      _editingPayoffIndex! > index) {
                    _editingPayoffIndex = _editingPayoffIndex! - 1;
                  }
                });
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
