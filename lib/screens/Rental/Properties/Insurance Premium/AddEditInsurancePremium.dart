import 'package:three_zero_two_property/services/app_log.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/services/insurance_edit_changes.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../constant/constant.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/custom_drawer.dart';

class AddEditInsurancePremium extends StatefulWidget {
  final String propertyId;
  final String? premiumId; // For editing existing premium
  final Map<String, dynamic>? premiumData; // For editing existing premium

  const AddEditInsurancePremium({
    Key? key,
    required this.propertyId,
    this.premiumId,
    this.premiumData,
  }) : super(key: key);

  @override
  State<AddEditInsurancePremium> createState() =>
      _AddEditInsurancePremiumState();
}

class _AddEditInsurancePremiumState extends State<AddEditInsurancePremium> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  String? _selectedYear;

  // Form controllers
  final _carrierController = TextEditingController();
  final _premiumAmountController = TextEditingController();

  bool _isLoading = false;
  // Like web: what an edited premium was opened with, so Update stays
  // greyed out until something changes.
  String? _originalYear;
  String _originalCarrier = '';
  String _originalPremium = '';
  bool _hasValidated = false;
  String? _generalError;
  List<Map<String, dynamic>> _existingPremiums = [];

  List<String> get _yearChoices {
    final int maxY = DateTime.now().year;
    final Set<String> set = {};
    for (int y = maxY; y >= 2020; y--) {
      set.add(y.toString());
    }
    if (_selectedYear != null && _selectedYear!.isNotEmpty) {
      set.add(_selectedYear!);
    }
    final list = set.toList();
    list.sort((a, b) => int.parse(b).compareTo(int.parse(a)));
    return list;
  }

  @override
  void initState() {
    super.initState();
    if (widget.premiumId != null && widget.premiumData != null) {
      _populateFormWithData(widget.premiumData!);
      _hasValidated = false;
    } else {
      _selectedYear = DateTime.now().year.toString();
    }
    _loadExistingPremiums();
    // Typing in a box re-checks whether Update can be used.
    _carrierController.addListener(_refreshUpdateButton);
    _premiumAmountController.addListener(_refreshUpdateButton);
  }

  void _refreshUpdateButton() {
    if (mounted) setState(() {});
  }

  /// Like web: adding can always be saved; editing only once something
  /// differs from what was opened.
  bool get _hasChanges =>
      widget.premiumId == null ||
      insurancePremiumChanged(
        year: _selectedYear,
        carrier: _carrierController.text,
        premium: _premiumAmountController.text,
        originalYear: _originalYear,
        originalCarrier: _originalCarrier,
        originalPremium: _originalPremium,
      );

  @override
  void dispose() {
    _carrierController.dispose();
    _premiumAmountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showFieldError(String field, String error) {
    setState(() {
      if (field == 'general') {
        _generalError = error;
      }
      _hasValidated = true;
    });
    // Scroll to top to show general error
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadExistingPremiums() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');

      final response = await apiGet(
        Uri.parse(
            '${Api_url}/api/rentals/insurance-premiums/${widget.propertyId}'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM $id',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data']['insurance_premiums'] != null) {
          setState(() {
            _existingPremiums = List<Map<String, dynamic>>.from(
                data['data']['insurance_premiums']);
          });
        }
      }
    } catch (e) {
      logError('Error loading existing premiums: $e');
    }
  }

  void _populateFormWithData(Map<String, dynamic> premiumData) {
    setState(() {
      _selectedYear = premiumData['year']?.toString();
      _carrierController.text = premiumData['carrier']?.toString() ?? '';
      // The saved premium, shown like web: rounded to cents with no
      // trailing zeros (2 as "2", not "2.00").
      String premium = premiumData['insurance_premium']?.toString() ?? '';
      if (premium.isEmpty && premiumData['formatted_premium'] != null) {
        premium = premiumData['formatted_premium']
            .toString()
            .replaceAll('\$', '')
            .replaceAll(',', '');
      }
      _premiumAmountController.text = insurancePremiumBoxText(premium);
      _originalYear = _selectedYear;
      _originalCarrier = _carrierController.text;
      // The stored amount, like web: a sub-cent premium shown rounded
      // counts as a change.
      _originalPremium =
          premiumData['insurance_premium']?.toString() ?? premium;
    });
  }

  Future<void> _saveForm() async {

    setState(() {
      _hasValidated = true;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      // Scroll to first error
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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

      String amountStr = _premiumAmountController.text
          .replaceAll('\$', '')
          .replaceAll(',', '');
      double premiumAmount = double.tryParse(amountStr) ?? 0.0;

      if (widget.premiumId != null) {
        // Edit mode - PUT request

        final response = await http
            .put(
              Uri.parse(
                  '${Api_url}/api/rentals/insurance-premiums/${widget.propertyId}/${widget.premiumId}'),
              headers: {
                'Content-Type': 'application/json',
                'authorization': 'CRM $token',
                'id': 'CRM $id',
              },
              body: json.encode({
                'year': _selectedYear?.trim() ?? '',
                'carrier': _carrierController.text.trim(),
                'insurance_premium': premiumAmount,
              }),
            )
            .timeout(const Duration(seconds: 30));


        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              Navigator.pop(context, true); // Return true to indicate success
            }
          } else {
            String errorMessage =
                data['message'] ?? 'Failed to update insurance premium';
            _showFieldError('general', errorMessage);
          }
        } else {
          final errorData = json.decode(response.body);
          String errorMessage =
              errorData['message'] ?? 'Failed to update insurance premium';
          _showFieldError('general', errorMessage);
        }
      } else {
        // Add mode - POST request to /api/rentals/insurance-premiums/{propertyId}

        final response = await http
            .post(
              Uri.parse(
                  '${Api_url}/api/rentals/insurance-premiums/${widget.propertyId}'),
              headers: {
                'Content-Type': 'application/json',
                'authorization': 'CRM $token',
                'id': 'CRM $id',
              },
              body: json.encode({
                'year': _selectedYear?.trim() ?? '',
                'carrier': _carrierController.text.trim(),
                'insurance_premium': premiumAmount,
              }),
            )
            .timeout(const Duration(seconds: 30));


        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              Navigator.pop(context, true); // Return true to indicate success
            }
          } else {
            String errorMessage =
                data['message'] ?? 'Failed to create insurance premium';
            _showFieldError('general', errorMessage);
          }
        } else {
          final errorData = json.decode(response.body);
          String errorMessage =
              errorData['message'] ?? 'Failed to create insurance premium';
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

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.premiumId != null;

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
                  child: Text(
                    isEditMode
                        ? 'Edit Insurance Premium'
                        : 'Add Insurance Premium',
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
                    Text(
                      isEditMode
                          ? 'Update insurance premium details'
                          : 'Add new insurance premium for this property',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),

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

                    // Year Field
                    Text(
                      'Year *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FormField<String>(
                      initialValue: _selectedYear ?? '',
                      validator: (value) {
                        if (_hasValidated &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Year is required';
                        }
                        if (_hasValidated &&
                            value != null &&
                            value.trim().isNotEmpty) {
                          String yearValue = value.trim();
                          bool isDuplicate = _existingPremiums.any((premium) {
                            String existingYear =
                                premium['year']?.toString().trim() ?? '';
                            if (widget.premiumId != null &&
                                premium['_id'] == widget.premiumId) {
                              return false;
                            }
                            return existingYear == yearValue;
                          });

                          if (isDuplicate) {
                            return 'A premium for this year already exists. Only one premium per year is allowed.';
                          }
                        }
                        return null;
                      },
                      builder: (FormFieldState<String> state) {
                        final yearError = state.hasError;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButton2<String>(
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              value: _selectedYear != null &&
                                      _yearChoices.contains(_selectedYear)
                                  ? _selectedYear
                                  : null,
                              hint: Text(
                                'Select Year',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                ),
                              ),
                              items: _yearChoices
                                  .map(
                                    (y) => DropdownMenuItem<String>(
                                      value: y,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        y,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() => _selectedYear = v);
                                state.didChange(v ?? '');
                                if (_hasValidated) {
                                  state.validate();
                                }
                                if (_hasValidated &&
                                    (v ?? '').trim().isNotEmpty) {
                                  setState(() => _generalError = null);
                                }
                              },
                              buttonStyleData: ButtonStyleData(
                                height: 48,
                                padding:
                                    const EdgeInsets.only(left: 12, right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: yearError
                                        ? Colors.red
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              iconStyleData: IconStyleData(
                                icon: Icon(Icons.keyboard_arrow_down,
                                    color: blueColor),
                                openMenuIcon: Icon(Icons.keyboard_arrow_up,
                                    color: blueColor),
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 280,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFDBE0E5)),
                                ),
                                offset: const Offset(0, 4),
                                elevation: 2,
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 4.0, left: 4, right: 16),
                                child: Text(
                                  state.errorText ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    height: 1.0,
                                  ),
                                  maxLines: 3,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Carrier Field
                    Text(
                      'Carrier *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FormField<String>(
                      initialValue: _carrierController.text,
                      validator: (value) {
                        if (_hasValidated &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Carrier is required';
                        }
                        return null;
                      },
                      builder: (FormFieldState<String> state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _carrierController,
                              onChanged: (value) {
                                state.didChange(value);
                                if (_hasValidated) {
                                  state.validate();
                                }
                                if (_hasValidated && value.trim().isNotEmpty) {
                                  setState(() {
                                    _generalError = null;
                                  });
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'e.g., ABC Insurance',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
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
                    const SizedBox(height: 20),

                    // Premium Amount Field
                    Text(
                      'Premium Amount *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    FormField<String>(
                      initialValue: _premiumAmountController.text,
                      validator: (value) {
                        if (_hasValidated &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Premium amount is required';
                        }
                        if (_hasValidated &&
                            value != null &&
                            value.isNotEmpty) {
                          String amountStr =
                              value.replaceAll('\$', '').replaceAll(',', '');
                          double? amount = double.tryParse(amountStr);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }
                        }
                        return null;
                      },
                      builder: (FormFieldState<String> state) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _premiumAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              // Commas while typing, like web ("1,500").
                              inputFormatters: const [
                                InsuranceAmountInputFormatter(
                                    max: insurancePremiumMaxAmount),
                              ],
                              onChanged: (value) {
                                state.didChange(value);
                                if (_hasValidated) {
                                  state.validate();
                                }
                              },
                              decoration: InputDecoration(
                                hintText: 'e.g., 1200.00',
                                prefixText: '\$ ',
                                prefixStyle: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
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
                    const SizedBox(height: 40),

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
                          onPressed: (_isLoading || !_hasChanges) ? null : _saveForm,
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
                              : Text(
                                  isEditMode ? 'Update' : 'Save',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
