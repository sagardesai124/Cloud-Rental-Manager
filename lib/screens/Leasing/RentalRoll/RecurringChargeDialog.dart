import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/Model/setting.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

/// Recurring Charge popup: Frequency (static), Start Date, Account (API), Amount (numeric), Memo (optional).
/// Use from both screens and StaffModule SummeryPageLease.
void showRecurringChargeDialog({
  required BuildContext context,
  required String leaseId,
  VoidCallback? onSuccess,
  bool isStaff = false,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _RecurringChargeDialogContent(
      leaseId: leaseId,
      isStaff: isStaff,
      onSuccess: () {
        Navigator.of(ctx).pop();
        onSuccess?.call();
      },
      onCancel: () => Navigator.of(ctx).pop(),
    ),
  );
}

class _RecurringChargeDialogContent extends StatefulWidget {
  final String leaseId;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;
  final bool isStaff;

  const _RecurringChargeDialogContent({
    required this.leaseId,
    required this.onSuccess,
    required this.onCancel,
    this.isStaff = false,
  });

  @override
  State<_RecurringChargeDialogContent> createState() =>
      _RecurringChargeDialogContentState();
}

class _RecurringChargeDialogContentState
    extends State<_RecurringChargeDialogContent> {
  static const List<String> _frequencyOptions = ['Weekly', 'Monthly'];
  String? _selectedFrequency = 'Monthly';
  DateTime _startDate = DateTime.now();
  List<Setting4> _accounts = [];
  Setting4? _selectedAccount;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController =
      TextEditingController(text: 'Recurring Charge');
  bool _loadingAccounts = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    if (adminId == null || token == null) return;
    // Staff must send its OWN id in the `id` header (web parity); the company
    // adminId stays in the URL for scoping.
    final String headerId =
        widget.isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
    try {
      final response = await apiGet(
        Uri.parse('$Api_url/api/accounts/accounts/$adminId'),
        headers: {
          'authorization': 'CRM $token',
          'id': 'CRM $headerId',
        },
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final List? data = body['data'] as List?;
        if (data != null) {
          setState(() {
            _accounts =
                data.map((e) => Setting4.fromJson(Map<String, dynamic>.from(e))).toList();
            _loadingAccounts = false;
          });
        } else {
          setState(() => _loadingAccounts = false);
        }
      } else {
        setState(() => _loadingAccounts = false);
      }
    } catch (e) {
      setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _pickStartDate() async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A5F),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  String get _startDateApi => DateFormat('yyyy-MM-dd').format(_startDate);

  bool _validate() {
    if (_selectedFrequency == null || _selectedFrequency!.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select Frequency');
      return false;
    }
    if (_selectedAccount == null || _selectedAccount!.account == null) {
      Fluttertoast.showToast(msg: 'Please select Account');
      return false;
    }
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter Amount');
      return false;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      Fluttertoast.showToast(msg: 'Please enter a valid numeric amount');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate() || _submitting) return;
    setState(() => _submitting = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    if (token == null || adminId == null) {
      setState(() => _submitting = false);
      Fluttertoast.showToast(msg: 'Session expired');
      return;
    }
    // Staff must send its OWN id in the `id` header (web parity).
    final String headerId =
        widget.isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
    final memo =
        _memoController.text.trim().isEmpty ? 'Recurring Charge' : _memoController.text.trim();
    final body = {
      'amount': _amountController.text.trim(),
      'memo': memo,
      'charge_type': 'Recurring Charge',
      'account': _selectedAccount!.account,
      'date': _startDateApi,
      'charge_start': _startDateApi,
      'rent_cycle': _selectedFrequency,
    };
    try {
      final response = await apiPost(
        Uri.parse('$Api_url/api/leases/${widget.leaseId}/add-recurring-charge'),
        headers: {
          'authorization': 'CRM $token',
          'id': 'CRM $headerId',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      final decoded = json.decode(response.body);
      if (response.statusCode == 200 &&
          (decoded['statusCode'] == 200 || decoded['statusCode'] == null)) {
        // Wording matches Add/Edit Lease exactly ('Recurring Charge Added
        // Successfully'), so the same action reads the same wherever it is
        // done. The server's success message is not used here - it is only a
        // confirmation and its phrasing differs from the rest of the app.
        Fluttertoast.showToast(msg: 'Recurring Charge Added Successfully');
        widget.onSuccess();
      } else {
        // Failure keeps the server's message: unlike the success case it
        // carries the reason, which exists nowhere else.
        Fluttertoast.showToast(
            msg: decoded['message']?.toString() ??
                'Failed to Add Recurring Charge');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Network error. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    final displayDate = dateProvider.formatCurrentDate(_startDateApi);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Recurring Charge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A5F),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Frequency *
              const Text('Frequency *', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  isExpanded: true,
                  value: _selectedFrequency,
                  hint: const Text('Select'),
                  items: _frequencyOptions
                      .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedFrequency = v),
                  buttonStyleData: ButtonStyleData(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Start Date *
              const Text('Start Date *', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickStartDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(displayDate)),
                      Icon(Icons.calendar_today, size: 20, color: Colors.grey.shade600),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Account *
              const Text('Account *', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              DropdownButtonHideUnderline(
                child: DropdownButton2<Setting4>(
                  isExpanded: true,
                  value: _selectedAccount,
                  hint: const Text('Select'),
                  items: _loadingAccounts
                      ? []
                      : _accounts
                          .map((e) => DropdownMenuItem<Setting4>(
                                value: e,
                                child: Text(e.account ?? ''),
                              ))
                          .toList(),
                  onChanged: _loadingAccounts
                      ? null
                      : (v) => setState(() => _selectedAccount = v),
                  buttonStyleData: ButtonStyleData(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Amount *
              const Text('Amount *', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              // Memo (optional)
              const Text('Memo', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _memoController,
                decoration: InputDecoration(
                  hintText: 'Recurring Charge',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _submitting
                            ? const Center(
                                child: SpinKitFadingCircle(
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                            : const Text('Add'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(  
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _submitting ? null : widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
