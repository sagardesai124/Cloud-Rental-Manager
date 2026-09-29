import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

import '../../../Model/Scheduled_Payment_model.dart';
import '../../../Model/schduled_charge.dart';
import '../../../Model/charge_history_entry.dart';
import '../../../constant/constant.dart';
import '../../../provider/dateProvider.dart';
import '../../../repository/GetAdminAddressPdf.dart';
import '../../../repository/ScheduledChargesRepository.dart';
import '../../../repository/Scheduled_Payment_repo.dart';
import '../../../widgets/CustomTableShimmer.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../widgets/titleBar.dart';
import '../RentalRoll/SummeryPageLease.dart';
import '../RentalRoll/enterCharge.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../../Model/profile.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class ScheduledChargeTable extends StatefulWidget {
  String? leaseID;
  // Property address of the lease this screen was opened from. The
  // lease-scoped endpoint (/charge/lease-scheduled-charges/{id}) does not
  // return rental_address, so rows would otherwise render "N/A" — every row
  // in a lease-scoped list belongs to this one property anyway.
  final String? leaseRentalAddress;
  ScheduledChargeTable({super.key, this.leaseID, this.leaseRentalAddress});

  @override
  State<ScheduledChargeTable> createState() => _ScheduledChargeTableState();
}

class _ScheduledChargeTableState extends State<ScheduledChargeTable>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<List<ScheduledCharges>> futurescheduledpayment;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [
    10,
    25,
    50,
    100,
  ]; // Options for items per page

  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  // Per-charge change-history (audit log) panel state.
  String? _historyOpenTaskId;
  final Map<String, List<ChargeHistoryEntry>> _historyByTask = {};
  final Set<String> _historyLoadingTaskIds = {};
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;

  String _displayOrNA(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty) return 'N/A';
    return t;
  }

  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
          color: Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        // leading: Container(
        //   child: Icon(
        //     Icons.expand_less,
        //     color: Colors.transparent,
        //   ),
        // ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              child: Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  setState(() {
                    // Reset other sorting states first
                    sorting2 = false;
                    sorting3 = false;
                    ascending2 = false;
                    ascending3 = false;

                    if (sorting1 == true) {
                      // Already sorting by date, toggle direction
                      ascending1 = !ascending1;
                    } else {
                      // Start sorting by date in descending order (latest dates first)
                      sorting1 = true;
                      ascending1 = false;
                    }
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? Text("Date ",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Date",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    SizedBox(width: 3),
                    ascending1
                        ? Padding(
                            padding: EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 16,
                              color: blueColor,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 16,
                              color: blueColor,
                            ),
                          ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Text("Property",
                  style:
                      TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> items = ['Residential', "Commercial", "All"];
  String? selectedValue;
  String? selectedChargeType;
  String searchvalue = "";
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    amountController.dispose();
    memoController.dispose();
    dateController.dispose();
    super.dispose();
  }
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      fetchDropdownData();;
      futurescheduledpayment = _fetchCharges();;
    });
  }

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    fetchDropdownData();
    futurescheduledpayment = _fetchCharges();
  }

  /// Fetches the charges and backfills the property address on rows the
  /// lease-scoped endpoint returns without one (display, search and exports
  /// all read charge.rentalAddress, so one backfill covers them all).
  Future<List<ScheduledCharges>> _fetchCharges() async {
    final charges = await ScheduledChargesRepository()
        .fetchScheduledCharges(leaseid: widget.leaseID);
    final fallback = widget.leaseRentalAddress?.trim() ?? '';
    if (fallback.isNotEmpty) {
      for (final c in charges) {
        if ((c.rentalAddress ?? '').trim().isEmpty ||
            c.rentalAddress == 'N/A') {
          c.rentalAddress = fallback;
        }
      }
    }
    return charges;
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back (reliably so on the
    // iOS simulator), which made this screen declare itself offline
    // while requests actually succeed. Confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  Future<void> _toggleHistory(String taskId) async {
    if (taskId.isEmpty) return;
    if (_historyOpenTaskId == taskId) {
      setState(() => _historyOpenTaskId = null);
      return;
    }
    setState(() => _historyOpenTaskId = taskId);
    if (!_historyByTask.containsKey(taskId)) {
      setState(() => _historyLoadingTaskIds.add(taskId));
      final list = await ScheduledChargesRepository().fetchChargeHistory(taskId);
      if (!mounted) return;
      setState(() {
        _historyByTask[taskId] = list;
        _historyLoadingTaskIds.remove(taskId);
      });
    }
  }

  String _formatHistoryAt(String iso) {
    try {
      return DateFormat('yyyy-MM-dd hh:mm a')
          .format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  Widget _historyEntryRow(ChargeHistoryEntry e) {
    final bool isDelete = e.action.toUpperCase() == 'DELETE';
    final Color actionColor = isDelete ? const Color(0xFFB42318) : blueColor;
    final String actionLabel =
        (e.action.isEmpty ? 'UPDATE' : e.action).toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(left: 10),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF3F6AD8), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: '$actionLabel ',
                    style: TextStyle(
                        color: actionColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                TextSpan(
                    text: e.description,
                    style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                if (e.reason.isNotEmpty)
                  TextSpan(
                      text: ' — reason: ${e.reason}',
                      style: TextStyle(color: grey, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text('${e.by} · ${_formatHistoryAt(e.at)}',
              style: TextStyle(color: grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildChangeHistoryPanel(String taskId) {
    final bool loading = _historyLoadingTaskIds.contains(taskId);
    final List<ChargeHistoryEntry>? entries = _historyByTask[taskId];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 8, 8, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Change history',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: blueColor, fontSize: 15)),
          const SizedBox(height: 10),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (entries == null || entries.isEmpty)
            Text('No changes recorded yet.',
                style: TextStyle(color: grey, fontSize: 13))
          else
            ...entries.map(_historyEntryRow),
        ],
      ),
    );
  }


  void _showAlert(BuildContext context, String id, ScheduledCharges payment) {
    TextEditingController reason = TextEditingController();
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final String dateText = payment.actionDate?.isNotEmpty == true
        ? dateProvider.formatCurrentDate('${payment.actionDate}')
        : 'N/A';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Color(0xFF8A95A8)),
                ),
              ),
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0A33E), width: 3),
                ),
                child: const Icon(Icons.priority_high,
                    color: Color(0xFFE0A33E), size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                "Are you sure?",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: blueColor),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 16, color: grey, height: 1.4),
                  children: widget.leaseID == null
                      ? [
                          const TextSpan(
                              text:
                                  "You want to delete this scheduled charge for "),
                          TextSpan(
                              text: payment.rentalAddress ?? '',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          const TextSpan(text: " in the amount of "),
                          TextSpan(
                              text: formatMoney(payment.amount),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          TextSpan(text: " on $dateText?"),
                        ]
                      : [
                          const TextSpan(
                              text:
                                  "You want to delete this scheduled charge for the amount of "),
                          TextSpan(
                              text: formatMoney(payment.amount),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor)),
                          TextSpan(text: " on $dateText?"),
                        ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: reason,
                decoration: InputDecoration(
                  hintText: 'Enter reason for deletion',
                  hintStyle: const TextStyle(color: Color(0xFF8A95A8)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDBE0E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: blueColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (reason.text.trim().isEmpty) {
                          Fluttertoast.showToast(
                              msg: "Please enter reason for deletion");
                          return;
                        }
                        try {
                          var data = await ScheduledChargesRepository()
                              .deleteNote(noteid: id, reason: reason.text);
                          if (data != null) {
                            setState(() {
                              futurescheduledpayment =
                                  ScheduledChargesRepository()
                                      .fetchScheduledCharges(
                                          leaseid: widget.leaseID);
                            });
                          }
                        } catch (_) {}
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: blueColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: blueColor, width: 1.5),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                              color: blueColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
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

  List<Map<String, dynamic>> accountOptions = [];
  Future<void> fetchDropdownData() async {
    // try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String adminId = prefs.getString('adminId') ?? '';
    String? token = prefs.getString('token');
    //   print('lease ${widget.leaseId}');
    String? id = prefs.getString("adminId");
    final response = await apiGet(
      Uri.parse('$Api_url/api/accounts/accounts/$adminId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = json.decode(response.body)['data'];
      //  log("accounts data $jsonResponse");
      Map<String, List<String>> fetchedData = {};
      // Adding static items to the "LIABILITY ACCOUNT" category

      for (var item in jsonResponse) {
        String chargeType = item['charge_type'] ?? "One Time Charge";
        String account = item['account'];
        setState(() {
          accountOptions.add({
            "account": account,
            "charge_type": chargeType,
          });
        });
      }
    } else {
      setState(() {});
    }
    // } catch (e) {
    //   print(e);
    //   setState(() {
    //     hasError = true;
    //     isLoading = false;
    //   });
    // }
  }

  EditCharge() {
    OutlineInputBorder _border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c),
        );
    InputDecoration _fieldDecoration(
            {String? hint, Widget? suffixIcon, String? prefixText}) =>
        InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFb0b6c3), fontSize: 14),
          prefixText: prefixText,
          prefixStyle: TextStyle(
              color: blueColor, fontSize: 15, fontWeight: FontWeight.w500),
          suffixIcon: suffixIcon,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: _border(const Color(0xFFDBE0E5)),
          enabledBorder: _border(const Color(0xFFDBE0E5)),
          focusedBorder: _border(blueColor),
          errorBorder: _border(Colors.red),
          focusedErrorBorder: _border(Colors.red),
        );
    Widget _label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: text,
                    style: TextStyle(
                        color: blueColor, fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: ' *',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
    bool editIsRecurring = (selectedChargeType ?? '').toLowerCase().contains('recurring') ||
        (selectedChargeType ?? '').toLowerCase().contains('rent');
    String editRentCycle = 'Monthly';
    bool editSaving = false;
    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => AlertDialog(
        backgroundColor: Colors.white,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        contentPadding:
            const EdgeInsets.fromLTRB(20, 16, 20, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Scheduled Charge',
            style: TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
            key: _editChargeFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label("Date"),
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  cursorColor: blueColor,
                  decoration: _fieldDecoration(
                    hint: 'YYYY-MM-DD',
                    suffixIcon: const Icon(Icons.calendar_today_outlined,
                        color: Color(0xFF8A95A8), size: 20),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please select date'
                      : null,
                ),
                const SizedBox(height: 14),
                _label("Account"),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: _fieldDecoration(),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF8A95A8)),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  style: TextStyle(color: blueColor, fontSize: 16),
                  hint: const Text('Select Account',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFFb0b6c3))),
                  items: accountOptions
                      .map((account) => '${account["account"]}')
                      .toSet()
                      .map((acc) => DropdownMenuItem<String>(
                            value: acc,
                            child: Text(acc),
                          ))
                      .toList(),
                  value: selectedAccount != null &&
                          accountOptions.any((account) =>
                              account["account"] == selectedAccount)
                      ? selectedAccount
                      : null,
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please select account'
                      : null,
                  onChanged: (value) {
                    setState(() {
                      var selectedOption = accountOptions.firstWhere(
                        (account) => account["account"] == value,
                        orElse: () => {},
                      );
                      String chargeType =
                          selectedOption["charge_type"] ?? "One Time Charge";
                      selectedChargeType = chargeType;
                      selectedAccount = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                _label("Amount"),
                TextFormField(
                  controller: amountController,
                  cursorColor: blueColor,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: _fieldDecoration(hint: '0.00', prefixText: '\$ '),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter amount';
                    }
                    final parsedAmount = double.tryParse(value);
                    if (parsedAmount == null) {
                      return 'Enter a valid amount';
                    }
                    if (parsedAmount <= 0) {
                      return 'Amount must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _label("Memo"),
                TextFormField(
                  controller: memoController,
                  cursorColor: blueColor,
                  maxLines: 3,
                  decoration: _fieldDecoration(hint: 'Enter memo'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter memo'
                      : null,
                ),
                const SizedBox(height: 14),
                _label("Type"),
                DropdownButtonFormField<bool>(
                  isExpanded: true,
                  value: editIsRecurring,
                  decoration: _fieldDecoration(),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8A95A8)),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  style: TextStyle(color: blueColor, fontSize: 16),
                  items: const [
                    DropdownMenuItem(value: false, child: Text('One-time')),
                    DropdownMenuItem(value: true, child: Text('Recurring')),
                  ],
                  onChanged: (v) => setSheetState(() => editIsRecurring = v ?? false),
                ),
                if (editIsRecurring) ...[
                  const SizedBox(height: 14),
                  _label("Frequency"),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: editRentCycle,
                    decoration: _fieldDecoration(),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8A95A8)),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    style: TextStyle(color: blueColor, fontSize: 16),
                    items: const [
                      DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    ],
                    onChanged: (v) => setSheetState(() => editRentCycle = v ?? 'Monthly'),
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 12, left: 16),
        actions: [
          TextButton(
            child: Text('Cancel',
                style:
                    TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blueColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            child: editSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: editSaving
                ? null
                : () async {
              if (!(_editChargeFormKey.currentState?.validate() ?? false)) {
                return;
              }
              setSheetState(() => editSaving = true);
              try {
                var response =
                    await ScheduledChargesRepository().submitCharge(
                        amount: amountController.text,
                        account: selectedAccount,
                        chargeType: editIsRecurring
                            ? "Recurring Charge"
                            : selectedChargeType,
                        action_date: _apiActionDate,
                        description: memoController.text,
                        charge_id: charge_id,
                        isRecurring: editIsRecurring,
                        rentCycle: editIsRecurring ? editRentCycle : null);
                if (response != null) {
                  Fluttertoast.showToast(msg: "Charge updated successfully");
                  setState(() {
                    futurescheduledpayment = _fetchCharges();
                  });
                  Navigator.of(context).pop();
                  return;
                } else {
                  Fluttertoast.showToast(msg: "Failed to update charge");
                }
              } catch (e) {
                Fluttertoast.showToast(msg: "Failed to update charge");
              }
              setSheetState(() => editSaving = false);
            },
          ),
        ],
      ),
    ),
    );
  }

  void _showCannotEditRentCharge() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 90,
                width: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE0A33E), width: 3),
                ),
                child: const Icon(Icons.priority_high,
                    color: Color(0xFFE0A33E), size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                "Cannot Edit Rent Charge",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: blueColor),
              ),
              const SizedBox(height: 14),
              Text(
                "This rent charge is automatically generated as part of "
                "the lease schedule and cannot be manually edited.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: grey, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: blueColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "OK",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickDate() async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final DateTime today = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        selectedDate = pickedDate;
        _apiActionDate = DateFormat("yyyy-MM-dd").format(selectedDate!);
        dateController.text = dateProvider.formatCurrentDate(_apiActionDate!);
      });
    }
  }

  DateTime? selectedDate;
  final GlobalKey<FormState> _editChargeFormKey = GlobalKey<FormState>();
  String? _apiActionDate;
  String? selectedAccount;
  String? charge_id;
  TextEditingController amountController = TextEditingController();
  TextEditingController memoController = TextEditingController();
  TextEditingController dateController = TextEditingController();

  final headerStyle = pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
    fontSize: 9,
    color: PdfColors.white,
  );

  final headerDecoration = pw.BoxDecoration(
    color: PdfColor.fromHex("#5A86D5"), // a nice blue shade
    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
  );

  Future<void> _exportPDF(List<ScheduledCharges> data) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;
    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      return;
    }
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              padding: pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(image, width: 50, height: 50),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Scheduled Charges',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text('As of $currentDate'),
                    ],
                  ),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (profileData?.companyName != null &&
                          profileData!.companyName!.isNotEmpty)
                        pw.Text(
                          profileData!.companyName!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (profileData?.companyAddress != null &&
                          profileData!.companyAddress!.isNotEmpty)
                        pw.Text(
                          profileData!.companyAddress!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if ((profileData?.companyCity != null &&
                              profileData!.companyCity!.isNotEmpty) ||
                          (profileData?.companyState != null &&
                              profileData!.companyState!.isNotEmpty) ||
                          (profileData?.companyCountry != null &&
                              profileData!.companyCountry!.isNotEmpty))
                        pw.Text(
                          [
                            if (profileData?.companyCity != null &&
                                profileData!.companyCity!.isNotEmpty)
                              profileData!.companyCity!,
                            if (profileData?.companyState != null &&
                                profileData!.companyState!.isNotEmpty)
                              profileData!.companyState!,
                            if (profileData?.companyCountry != null &&
                                profileData!.companyCountry!.isNotEmpty)
                              profileData!.companyCountry!,
                          ].join(', '),
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      if (profileData?.companyPostalCode != null &&
                          profileData!.companyPostalCode!.isNotEmpty)
                        pw.Text(
                          profileData!.companyPostalCode!,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  )
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              child: pw.Table(
                border: null, // No border
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Date
                  1: const pw.FlexColumnWidth(3), // Address
                  2: const pw.FlexColumnWidth(3), // Memo
                  3: const pw.FlexColumnWidth(3), // Account
                  4: const pw.FlexColumnWidth(2), // Amount
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: headerDecoration,
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Date', style: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Address', style: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Memo', style: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Account', style: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text('Amount', style: headerStyle),
                        ),
                      ),
                    ],
                  ),
                  // Data rows
                  ...data.map((charge) => pw.TableRow(
                        decoration: const pw.BoxDecoration(),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(charge.actionDate != null
                                ? dateProvider
                                    .formatCurrentDate(charge.actionDate!)
                                : ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(charge.rentalAddress ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_displayOrNA(charge.description)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(_displayOrNA(charge.account)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: pw.Text(charge.amount != null
                                  ? formatMoney(charge.amount)
                                  : ''),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ];
        },
      ),
    );
    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'ScheduledCharge.pdf');
    } else {
      await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> _exportCSV(List<ScheduledCharges> data) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final StringBuffer csvBuffer = StringBuffer();

    // Add header
    csvBuffer.writeln('Date,Address,Memo,Account,Amount');

    // Add data rows
    for (final charge in data) {
      csvBuffer.writeln([
        charge.actionDate != null
            ? dateProvider.formatCurrentDate(charge.actionDate!)
            : '',
        charge.rentalAddress ?? '',
        _displayOrNA(charge.description),
        _displayOrNA(charge.account),
        formatMoney(charge.amount)
      ].map((e) => '"${e.replaceAll('"', '""')}"').join(','));
    }

    final List<int> bytes = utf8.encode(csvBuffer.toString());

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'ScheduledCharges_$formattedDate.csv';

    // Define file path
    // App sandbox dir is writable on BOTH Android & iOS. The old hardcoded
    // /storage/emulated/0/Pictures path is blocked by Android scoped storage
    // (Android 10+), which silently broke Excel/CSV export. The Share sheet
    // below still lets the user save/download the file.
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)]);
  }

  Future<void> _exportExcel(List<ScheduledCharges> data) async {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final workbook = syncXlsx.Workbook();
    final sheet = workbook.worksheets[0];

    // Add header row
    final headers = ['Date', 'Address', 'Memo', 'Account', 'Amount'];
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    // Right-align the "Amount" header to match its right-aligned values.
    sheet.getRangeByIndex(1, headers.length).cellStyle.hAlign =
        syncXlsx.HAlignType.right;

    // Add data rows
    for (int row = 0; row < data.length; row++) {
      final charge = data[row];
      sheet.getRangeByIndex(row + 2, 1).setText(charge.actionDate != null
          ? dateProvider.formatCurrentDate(charge.actionDate!)
          : '');
      sheet.getRangeByIndex(row + 2, 2).setText(charge.rentalAddress ?? '');
      sheet.getRangeByIndex(row + 2, 3).setText(_displayOrNA(charge.description));
      sheet.getRangeByIndex(row + 2, 4).setText(_displayOrNA(charge.account));
      // Amount as a real number with currency format -> right-aligned in Excel.
      final amountCell = sheet.getRangeByIndex(row + 2, 5);
      amountCell.setNumber(charge.amount);
      amountCell.numberFormat = r'$#,##0.00';
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    // Define file name with current date and time
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'ScheduledCharges_$formattedDate.xlsx';

    // Define file path
    // App sandbox dir is writable on BOTH Android & iOS. The old hardcoded
    // /storage/emulated/0/Pictures path is blocked by Android scoped storage
    // (Android 10+), which silently broke Excel/CSV export. The Share sheet
    // below still lets the user save/download the file.
    final Directory directory = await getApplicationDocumentsDirectory();

    final path = '${directory.path}/$fileName';

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path)]);
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Scheduled Charges",
        dropdown: true,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 20,
                  ),
                  // Header Section with Title
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width > 500 ? 28 : 16,
                        vertical: 8.0),
                    child: titleBar(
                      width: double.infinity,
                      title: 'Scheduled Charges',
                    ),
                  ),
                  SizedBox(height: 10),
                  //search
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width > 500 ? 28 : 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Material(
                            elevation: 0,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              height: MediaQuery.of(context).size.width < 500
                                  ? 45
                                  : 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                // border: Border.all(color: Colors.grey),
                                border: Border.all(color: Color(0xFF8A95A8))),
                              child: Row(
                                children: [
                                  const Icon(Icons.search,
                                      color: Color(0xFF8A95A8), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 15
                                              : 14),
                                      onChanged: (value) {
                                        setState(() {
                                          searchvalue = value;
                                          if (currentPage != 0) currentPage = 0;
                                        });
                                      },
                                      cursorColor: blueColor,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isCollapsed: true,
                                        hintText: "Search here...",
                                        hintStyle: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF8A95A8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Export disabled/greyed when there is no data to
                        // export (QA CRM: no Export on empty list).
                        FutureBuilder<List<ScheduledCharges>>(
                          future: futurescheduledpayment,
                          builder: (context, exportSnap) {
                            final bool hasExportData = exportSnap.connectionState != ConnectionState.done ||
                                (exportSnap.hasData && exportSnap.data!.isNotEmpty);
                            return Container(
                              height: 45,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hasExportData
                                      ? blueColor
                                      : Colors.grey.shade400,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                onPressed: () {},
                                child: PopupMenuButton(
                                  enabled: hasExportData,
                                  onSelected: (value) async {
                                    if (value == 'Export PDF') {
                                      final data = await futurescheduledpayment;
                                      _exportPDF(data);
                                    }
                                    if (value == 'Export Excel') {
                                      final data = await futurescheduledpayment;
                                      _exportExcel(data);
                                    }
                                    if (value == 'Export CSV') {
                                      final data = await futurescheduledpayment;
                                      _exportCSV(data);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'Export PDF',
                                      child: Text('Export PDF'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Export Excel',
                                      child: Text('Export Excel'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Export CSV',
                                      child: Text('Export CSV'),
                                    ),
                                  ],
                                  child: Row(
                                    children: [
                                      Text('Export'),
                                      Icon(Icons.arrow_drop_down),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (widget.leaseID != null) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => enterCharge(leaseId: widget.leaseID!),
                                  ),
                                );
                                if (!mounted) return;
                                setState(() {
                                  futurescheduledpayment = _fetchCharges();
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   SizedBox(height: 25),
                  // if (MediaQuery.of(context).size.width < 500)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.of(context).size.width < 500 ? 16 : 28,
                        vertical:
                            MediaQuery.of(context).size.width < 500 ? 12 : 28),
                    child: FutureBuilder<List<ScheduledCharges>>(
                      future: futurescheduledpayment,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ColabShimmerLoadingWidget();
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Container(
                            height: MediaQuery.of(context).size.height * .5,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    "assets/images/no_data.jpg",
                                    height: 200,
                                    width: 200,
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    "No Data Available",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize: 16),
                                  )
                                ],
                              ),
                            ),
                          );
                        } else {
                          var data = snapshot.data!;
                          if (searchvalue.isNotEmpty) {
                            final searchLower = searchvalue.toLowerCase();
                            data = data.where((charge) {
                              return (charge.actionDate
                                          ?.toLowerCase()
                                          .contains(searchLower) ??
                                      false) ||
                                  (charge.account
                                          ?.toLowerCase()
                                          .contains(searchLower) ??
                                      false) ||
                                  (charge.amount
                                          ?.toString()
                                          .contains(searchLower) ??
                                      false) ||
                                  (charge.description
                                          ?.toLowerCase()
                                          .contains(searchLower) ??
                                      false) ||
                                  (charge.rentalAddress
                                          ?.toLowerCase()
                                          .contains(searchLower) ??
                                      false) ||
                                  (charge.chargeType
                                          ?.toLowerCase()
                                          .contains(searchLower) ??
                                      false);
                            }).toList();
                          }
                          if (data.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    "assets/images/no_data.jpg",
                                    height: 200,
                                    width: 200,
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  Text(
                                    "No Data Available",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize: 16),
                                  )
                                ],
                              ),
                            );
                          }
                          /* if (selectedValue == null && searchvalue!.isEmpty) {
                        data = snapshot.data!;
                      } else if (selectedValue == "All") {
                        data = snapshot.data!;
                      } else if (searchvalue!.isNotEmpty) {
                        data = snapshot.data!
                            .where((property) =>
                        (property.propertyType ?? '')
                            .toLowerCase()
                            .contains(searchvalue!.toLowerCase()) ||
                            (property.propertysubType ?? '')
                                .toLowerCase()
                                .contains(searchvalue!.toLowerCase()))
                            .toList();
                      } else {
                        data = snapshot.data!
                            .where((property) =>
                        property.propertyType == selectedValue)
                            .toList();
                      }*/
                          // Apply sorting
                          if (sorting1) {
                            // Sort by Date
                            data.sort((a, b) {
                              String dateA = a.actionDate ?? '';
                              String dateB = b.actionDate ?? '';

                              if (dateA.isEmpty && dateB.isEmpty) return 0;
                              if (dateA.isEmpty) return 1;
                              if (dateB.isEmpty) return -1;

                              if (ascending1) {
                                return dateA.compareTo(dateB);
                              } else {
                                return dateB.compareTo(dateA);
                              }
                            });
                          } else if (sorting2) {
                            // Sort by Account
                            data.sort((a, b) {
                              String accountA = a.account ?? '';
                              String accountB = b.account ?? '';

                              if (ascending2) {
                                return accountA.compareTo(accountB);
                              } else {
                                return accountB.compareTo(accountA);
                              }
                            });
                          } else if (sorting3) {
                            // Sort by Amount
                            data.sort((a, b) {
                              double amountA = a.amount ?? 0.0;
                              double amountB = b.amount ?? 0.0;

                              if (ascending3) {
                                return amountA.compareTo(amountB);
                              } else {
                                return amountB.compareTo(amountA);
                              }
                            });
                          }

                          final totalPages =
                              (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                          final currentPageData = data
                              .skip(currentPage * itemsPerPage)
                              .take(itemsPerPage)
                              .toList();
                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 5, right: 5),
                              child: Column(
                                children: [
                                  SizedBox(height: 10),
                                  _buildHeaders(),
                                  SizedBox(height: 10),
                                  Container(
                                    child: Column(
                                      children: currentPageData.isEmpty
                                          ? [kNoSearchResults(context)]
                                          : currentPageData
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        int index = entry.key;
                                        bool isExpanded =
                                            expandedIndex == index;
                                        ScheduledCharges Propertytype =
                                            entry.value;

                                        //return CustomExpansionTile(data: Propertytype, index: index);
                                        return Container(
                                          margin:
                                              EdgeInsets.symmetric(vertical: 6),
                                          decoration: BoxDecoration(
                                            color: index % 2 != 0
                                                ? Color(0xFFF4F8FF)
                                                : Colors.white,
                                            border: Border.all(
                                                color: Color(0xFFDBE0E5)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Column(children: <Widget>[
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Padding(
                                                padding:
                                                    const EdgeInsets.all(2.0),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.start,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: <Widget>[
                                                    InkWell(
                                                      onTap: () {
                                                        // setState(() {
                                                        //    isExpanded = !isExpanded;
                                                        // //  expandedIndex = !expandedIndex;
                                                        //
                                                        // });
                                                        // setState(() {
                                                        //   if (isExpanded) {
                                                        //     expandedIndex = null;
                                                        //     isExpanded = !isExpanded;
                                                        //   } else {
                                                        //     expandedIndex = index;
                                                        //   }
                                                        // });
                                                        setState(() {
                                                          if (expandedIndex ==
                                                              index) {
                                                            expandedIndex =
                                                                null;
                                                          } else {
                                                            expandedIndex =
                                                                index;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: EdgeInsets.only(
                                                            left: 5, right: 5),
                                                        padding: !isExpanded
                                                            ? EdgeInsets.only(
                                                                bottom: 10)
                                                            : EdgeInsets.only(
                                                                top: 10),
                                                        child: FaIcon(
                                                          isExpanded
                                                              ? FontAwesomeIcons
                                                                  .sortUp
                                                              : FontAwesomeIcons
                                                                  .sortDown,
                                                          size: 20,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      flex: 3,
                                                      child: InkWell(
                                                        onTap: () {
                                                          setState(() {
                                                            if (expandedIndex ==
                                                                index) {
                                                              expandedIndex =
                                                                  null;
                                                            } else {
                                                              expandedIndex =
                                                                  index;
                                                            }
                                                          });
                                                        },
                                                        child: Text(
                                                          dateProvider
                                                              .formatCurrentDate(
                                                                  '${Propertytype.actionDate}'),
                                                          style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .03),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        _displayOrNA(
                                                            Propertytype
                                                                .rentalAddress),
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .02),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (isExpanded)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 2.0),
                                                margin:
                                                    EdgeInsets.only(bottom: 2),
                                                child: SingleChildScrollView(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // if (Propertytype
                                                      //     .isRenewing !=
                                                      //     false)

                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 18.0),
                                                        child: Text.rich(
                                                          TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    'Account : ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        blueColor),
                                                              ),
                                                              TextSpan(
                                                                text: _displayOrNA(
                                                                    Propertytype
                                                                        .account),
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: grey),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(height: 10),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 18.0),
                                                        child: Text.rich(
                                                          TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text:
                                                                    'Amount : ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        blueColor),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    formatMoney(Propertytype.amount),
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: grey),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(height: 10),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 18.0),
                                                        child: Text.rich(
                                                          TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text: 'Memo : ',
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        blueColor),
                                                              ),
                                                              TextSpan(
                                                                text: _displayOrNA(
                                                                    Propertytype
                                                                        .description),
                                                                style: TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: grey),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      if (widget.leaseID != null)
                                                        Padding(
                                                          padding: const EdgeInsets.only(left: 18.0, top: 10.0),
                                                          child: Row(
                                                            children: [
                                                              Text('Type : ',
                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: blueColor)),
                                                              Builder(builder: (_) {
                                                                final String t = (Propertytype.chargeType ?? '').toLowerCase();
                                                                final bool recurring = t.contains('recurring') || t.contains('rent');
                                                                return Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                                  decoration: BoxDecoration(
                                                                    color: recurring ? const Color(0xFFE7EEFB) : const Color(0xFFEEF1F5),
                                                                    borderRadius: BorderRadius.circular(20),
                                                                  ),
                                                                  child: Text(
                                                                    recurring ? 'Recurring' : 'One-time',
                                                                    style: TextStyle(
                                                                      color: recurring ? blueColor : const Color(0xFF6B7A90),
                                                                      fontWeight: FontWeight.w600,
                                                                      fontSize: 13,
                                                                    ),
                                                                  ),
                                                                );
                                                              }),
                                                            ],
                                                          ),
                                                        ),
                                                      SizedBox(
                                                        height: 15,
                                                      ),
                                                      Row(
                                                        //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          if (widget.leaseID != null) ...[GestureDetector(
                                                            onTap: () => _toggleHistory(Propertytype.taskId ?? ''),
                                                            child: Container(
                                                              height: 35,
                                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                                              decoration: BoxDecoration(
                                                                borderRadius: BorderRadius.circular(8),
                                                                color: const Color(0xFFEFF3FA),
                                                              ),
                                                              child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                  Icon(Icons.access_time, size: 15, color: blueColor),
                                                                  const SizedBox(width: 6),
                                                                  Text('History',
                                                                      style: TextStyle(
                                                                          color: blueColor, fontWeight: FontWeight.w600, fontSize: 13)),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 5),],
                                                          GestureDetector(
                                                                                                                            onTap:
                                                              () async {
                                                            if (Propertytype
                                                                    .taskType ==
                                                                "RENT_CHARGE") {
                                                              _showCannotEditRentCharge();
                                                              return;
                                                            }
                                                            setState(() {
                                                              _apiActionDate =
                                                                  Propertytype
                                                                      .actionDate;
                                                              dateController.text = (Propertytype
                                                                          .actionDate
                                                                          ?.isNotEmpty ==
                                                                      true)
                                                                  ? dateProvider
                                                                      .formatCurrentDate(
                                                                          '${Propertytype.actionDate}')
                                                                  : '';
                                                              amountController
                                                                      .text =
                                                                  Propertytype
                                                                      .amount
                                                                      .toStringAsFixed(
                                                                          2);
                                                              memoController
                                                                      .text =
                                                                  Propertytype.description ??
                                                                      "";
                                                              selectedAccount = (Propertytype
                                                                          .account
                                                                          ?.trim()
                                                                          .isNotEmpty ==
                                                                      true)
                                                                  ? Propertytype
                                                                      .account
                                                                  : null;
                                                              selectedChargeType =
                                                                  Propertytype
                                                                      .chargeType;
                                                              if (selectedAccount !=
                                                                      null &&
                                                                  !accountOptions.any((account) =>
                                                                      account["account"] ==
                                                                      selectedAccount)) {
                                                                accountOptions
                                                                    .add({
                                                                  "account":
                                                                      selectedAccount,
                                                                  "charge_type":
                                                                      Propertytype
                                                                          .chargeType,
                                                                });
                                                              }
                                                              charge_id =
                                                                  Propertytype
                                                                      .taskId;
                                                            });
                                                            
                                                            EditCharge();
                                                            // Navigator.push(
                                                            //     context,
                                                            //     MaterialPageRoute(
                                                            //         builder: (context) => SummeryPageLease(
                                                            //           leaseId: Propertytype.leaseId!,
                                                            //           enddate: Propertytype.date,
                                                            //           isredirectpayment: true,
                                                            //         )));
                                                                                                                            },
                                                                                                                            child: 
                                                                                                                             Container(
                                                                                                                            height: 35,
                                                                                                                            width: 35,
                                                                                                                            decoration: BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              color: Colors
                                                                  .green
                                                                  .shade50), // color:Colors.grey[100],
                                                                                                                            child:
                                                              const Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              FaIcon(
                                                                FontAwesomeIcons
                                                                    .edit,
                                                                size: 15,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                            ],
                                                                                                                            ),
                                                                                                                          ),
                                                                                                                         
                                                                                                                          ),

                                                          SizedBox(
                                                              width: 5,
                                                            ),
                                                          GestureDetector(
                                                                                                                        onTap: () async {
                                                          _showAlert(
                                                              context,
                                                              Propertytype
                                                                  .taskId!,
                                                              Propertytype);
                                                                                                                        },
                                                                                                                        child: 
                                                                                                                        Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(8),
                                                              color: Colors.red.shade50),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              FaIcon(FontAwesomeIcons.trashCan, size: 16, color: Colors.red),
                                                            ],
                                                          ),
                                                                                                                        ),
                                                                                                                      ),
                                                          SizedBox(width: 15),
                                                        ],
                                                      ),
                                                      if (widget.leaseID != null && _historyOpenTaskId == Propertytype.taskId)
                                                        _buildChangeHistoryPanel(Propertytype.taskId ?? ''),
                                                      SizedBox(height: 10),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            //SizedBox(height: 13,),
                                          ]),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  if (totalPages > 1) SizedBox(height: 20),
                                  if (totalPages > 1)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          // Text('Rows per page:'),
                                          SizedBox(width: 10),
                                          Material(
                                            elevation: 3,
                                            child: Container(
                                              height: 40,
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12.0),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.grey),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton<int>(
                                                  value: itemsPerPage,
                                                  items: itemsPerPageOptions
                                                      .map((int value) {
                                                    return DropdownMenuItem<
                                                        int>(
                                                      value: value,
                                                      child: Text(
                                                          value.toString()),
                                                    );
                                                  }).toList(),
                                                  onChanged: data.length >
                                                          itemsPerPageOptions
                                                              .first // Condition to check if dropdown should be enabled
                                                      ? (newValue) {
                                                          setState(() {
                                                            itemsPerPage =
                                                                newValue!;
                                                            currentPage =
                                                                0; // Reset to first page when items per page change
                                                          });
                                                        }
                                                      : null,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: FaIcon(
                                              FontAwesomeIcons
                                                  .circleChevronLeft,
                                              color: currentPage == 0
                                                  ? Colors.grey
                                                  : blueColor,
                                            ),
                                            onPressed: currentPage == 0
                                                ? null
                                                : () {
                                                    setState(() {
                                                      currentPage--;
                                                    });
                                                  },
                                          ),
                                          // IconButton(
                                          //   icon: Icon(Icons.arrow_back),
                                          //   onPressed: currentPage > 0
                                          //       ? () {
                                          //     setState(() {
                                          //       currentPage--;
                                          //     });
                                          //   }
                                          //       : null,
                                          // ),
                                          Text(
                                              'Page ${currentPage + 1} of $totalPages'),
                                          // IconButton(
                                          //   icon: Icon(Icons.arrow_forward),
                                          //   onPressed: currentPage < totalPages - 1
                                          //       ? () {
                                          //     setState(() {
                                          //       currentPage++;
                                          //     });
                                          //   }
                                          //       : null,
                                          // ),
                                          IconButton(
                                            icon: FaIcon(
                                              FontAwesomeIcons
                                                  .circleChevronRight,
                                              color:
                                                  currentPage < totalPages - 1
                                                      ? blueColor
                                                      : Colors.grey,
                                            ),
                                            onPressed:
                                                currentPage < totalPages - 1
                                                    ? () {
                                                        setState(() {
                                                          currentPage++;
                                                        });
                                                      }
                                                    : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),

                  // Export PDF Button
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
