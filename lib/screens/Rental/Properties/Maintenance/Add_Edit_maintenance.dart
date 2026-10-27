import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/widgets/appbar.dart' as admin_bar;
import 'package:three_zero_two_property/widgets/custom_drawer.dart' as admin_drawer;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart' as staff_bar;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    as staff_drawer;

/// Add or edit a property maintenance-by-year entry. Same screen for admin and
/// staff; [useStaffModule] selects app bar, drawer, and `id` header value.
class Add_Edit_maintenance extends StatefulWidget {
  const Add_Edit_maintenance({
    super.key,
    required this.propertyId,
    this.useStaffModule = false,
    this.entryId,
    this.maintenanceData,
  });

  final String propertyId;
  final bool useStaffModule;
  final String? entryId;
  final Map<String, dynamic>? maintenanceData;

  @override
  State<Add_Edit_maintenance> createState() => _Add_Edit_maintenanceState();
}

class _Add_Edit_maintenanceState extends State<Add_Edit_maintenance> {
  final _amountController = TextEditingController();

  String? _selectedYear;
  bool _isLoading = false;
  bool _hasValidated = false;

  String? _initialYear;
  double? _initialAmount;

  List<String> get _yearChoices {
    final int maxY = DateTime.now().year;
    final Set<String> set = {};
    for (int y = maxY; y >= 2020; y--) {
      set.add(y.toString());
    }
    if (_initialYear != null && _initialYear!.isNotEmpty) {
      set.add(_initialYear!);
    }
    final list = set.toList();
    list.sort((a, b) => int.parse(b).compareTo(int.parse(a)));
    return list;
  }

  @override
  void initState() {
    super.initState();
    if (widget.maintenanceData != null) {
      final m = widget.maintenanceData!;
      _initialYear = m['year']?.toString();
      _selectedYear = _initialYear;
      final amt = m['amount'];
      if (amt != null) {
        final d = amt is num ? amt.toDouble() : double.tryParse(amt.toString());
        _initialAmount = d;
        if (d != null) {
          if (d == d.roundToDouble()) {
            _amountController.text = d.toInt().toString();
          } else {
            _amountController.text = d.toString();
          }
        }
      }
    }
    // Add starts with no year ("Select Year"), like web's
    // handleAddMaintenance (`year: ""`).
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final id = widget.useStaffModule
        ? (prefs.getString('staff_id') ?? '')
        : (prefs.getString('adminId') ?? '');
    return {
      'Content-Type': 'application/json',
      'authorization': 'CRM $token',
      'id': 'CRM $id',
    };
  }

  bool _hasChanges() {
    if (widget.entryId == null) return true;
    final y = _selectedYear ?? '';
    final cur = double.tryParse(_amountController.text.trim());
    final init = _initialAmount ?? 0;
    final sameYear = y == (_initialYear ?? '');
    final sameAmt =
        cur != null && (cur - init).abs() < 0.000001;
    return !(sameYear && sameAmt);
  }

  String? _validateYear(String? v) {
    if (v == null || v.isEmpty) return 'Year is required';
    return null;
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Amount is required';
    final clean = v.trim();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) {
      return 'Use digits only (optional .xx for cents)';
    }
    final n = double.tryParse(clean);
    if (n == null || n < 0) return 'Enter a valid amount';
    // Web PropDetails.jsx MAX_ANNUAL_EXPENSE_AMOUNT / _MSG.
    if (n > 999999999.99) return 'Amount must be less than \$1,000,000,000';
    return null;
  }

  Future<void> _save() async {
    setState(() => _hasValidated = true);

    final yErr = _validateYear(_selectedYear);
    final aErr = _validateAmount(_amountController.text);
    if (yErr != null || aErr != null) {
      return;
    }

    if (widget.entryId != null && !_hasChanges()) {
      Fluttertoast.showToast(
        msg: 'No changes detected',
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      if (mounted) Navigator.pop(context, false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final headers = await _headers();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final body = json.encode({
        'year': _selectedYear,
        'amount': amount,
        'user_active_recently': true,
        'is_web': kIsWeb,
      });

      final base = '${Api_url}/api/rentals/maintenance/${widget.propertyId}';
      late http.Response response;
      if (widget.entryId != null) {
        response = await http
            .put(
              Uri.parse('$base/${widget.entryId}'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 30));
      } else {
        response = await http
            .post(
              Uri.parse(base),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Fluttertoast.showToast(
            // Web PropDetails.jsx wording.
            msg: widget.entryId != null
                ? 'Maintenance entry updated'
                : 'Maintenance entry added',
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          setState(() => _hasValidated = false);
          String msg = 'Request failed';
          try {
            final err = json.decode(response.body);
            msg = err['message']?.toString() ?? msg;
          } catch (_) {}
          Fluttertoast.showToast(
            msg: msg,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasValidated = false);
        Fluttertoast.showToast(
          msg: 'Error: ${friendlyErrorMessage(e)}',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _body() {
    final isEdit = widget.entryId != null;

    return Form(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 10),
            Row(
              children: [
               
                
                Material(color: Colors.transparent,
                child: InkWell(onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color:Colors.grey.shade200 ,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey.shade300,width: 1),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,size: 15,color: Colors.black,),
                ),
              ),
            ),
                
                
              SizedBox(width: 10),
                Text(
              isEdit ? 'Edit Maintenance' : 'Add Maintenance',
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.bold,
                fontSize: MediaQuery.of(context).size.width < 500 ? 18 : 22,
              ),
            ),
            ],
            ),
            SizedBox(height: 20),
            Text(
              'Enter year and amount for this property.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Year *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: blueColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
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
              onChanged: (v) => setState(() => _selectedYear = v),
              buttonStyleData: ButtonStyleData(
                height: 44,
                padding: const EdgeInsets.only(left: 12, right: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasValidated &&
                            _validateYear(_selectedYear) != null
                        ? Colors.red
                        : const Color(0xFFDBE0E5),
                  ),
                ),
              ),
              iconStyleData: IconStyleData(
                icon: Icon(Icons.keyboard_arrow_down, color: blueColor),
                openMenuIcon: Icon(Icons.keyboard_arrow_up, color: blueColor),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                ),
                offset: const Offset(0, 4),
                elevation: 2,
              ),
              menuItemStyleData: const MenuItemStyleData(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            if (_hasValidated && _validateYear(_selectedYear) != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _validateYear(_selectedYear)!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Amount *',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: blueColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(fontSize: 15, height: 1.2),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                hintText: 'e.g., 1500 or 1500.50',
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                prefixText: '\$ ',
                prefixStyle: const TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  color: Colors.black87,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _hasValidated &&
                            _validateAmount(_amountController.text) != null
                        ? Colors.red
                        : const Color(0xFFDBE0E5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _hasValidated &&
                            _validateAmount(_amountController.text) != null
                        ? Colors.red
                        : blueColor,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            if (_hasValidated &&
                _validateAmount(_amountController.text) != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _validateAmount(_amountController.text)!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blueColor,
                      side: BorderSide(color: blueColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel',style: TextStyle(fontSize: 15,fontWeight: FontWeight.w600),),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: BorderSide(color: blueColor, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(isEdit ? 'Update' : 'Save',style: TextStyle(fontSize: 15,fontWeight: FontWeight.w600),),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(child: SpinKitFadingCircle(color: Colors.black, size: 40))
        : _body();

    if (widget.useStaffModule) {
      return Scaffold(
        appBar: staff_bar.widget_302_Staff.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: staff_drawer.CustomDrawerStaff(
          currentpage: 'Properties',
          dropdown: true,
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: admin_bar.widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: admin_drawer.CustomDrawer(
        currentpage: 'Properties',
        dropdown: true,
      ),
      body: body,
    );
  }
}
