import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart' as intl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:provider/provider.dart';
import '../../../provider/dateProvider.dart';
import 'package:three_zero_two_property/repository/lease.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';

import '../../../model/EnterChargeModel.dart';
import '../../../widgets/custom_drawer.dart';

class Chargedata {
  String? id;
  String? chargeId;
  String? adminId;
  String? tenantId;
  String? leaseId;
  List<Entrydata>? entry;
  double? totalAmount;
  bool? isLeaseAdded;
  String? type;
  List<dynamic>? uploadedFile;
  DateTime? createdAt;
  DateTime? updatedAt;
  bool? isDelete;
  TenantData? tenantData;

  Chargedata({
    this.id,
    this.chargeId,
    this.adminId,
    this.tenantId,
    this.leaseId,
    this.entry,
    this.totalAmount,
    this.isLeaseAdded,
    this.type,
    this.uploadedFile,
    this.createdAt,
    this.updatedAt,
    this.isDelete,
    this.tenantData,
  });

  factory Chargedata.fromJson(Map<String, dynamic> json) {
    return Chargedata(
      id: json['_id'],
      chargeId: json['charge_id'],
      adminId: json['admin_id'],
      tenantId: json['tenant_id'],
      leaseId: json['lease_id'],
      entry: json['entry'] != null
          ? List<Entrydata>.from(
              json['entry'].map((x) => Entrydata.fromJson(x)))
          : [],
      totalAmount:
          json['total_amount'] != null ? json['total_amount'].toDouble() : 0.0,
      isLeaseAdded: json['is_leaseAdded'],
      type: json['type'],
      uploadedFile: json['uploaded_file'] ?? [],
      tenantData: json['tenantData'] != null
          ? TenantData.fromJson(json['tenantData'])
          : null,
    );
  }
}

class Entrydata {
  String? entryId;
  String? memo;
  String? account;
  double? amount;
  double? dueAmount;
  DateTime? date;
  bool? isPaid;
  bool? isLateFee;
  bool? isRepeatable;
  String? chargeType;
  String? id;

  Entrydata({
    this.entryId,
    this.memo,
    this.account,
    this.amount,
    this.dueAmount,
    this.date,
    this.isPaid,
    this.isLateFee,
    this.isRepeatable,
    this.chargeType,
    this.id,
  });

  factory Entrydata.fromJson(Map<String, dynamic> json) {
    return Entrydata(
      entryId: json['entry_id'],
      memo: json['memo'],
      account: json['account'],
      // Same guard due_amount already has: `.toDouble()` on a missing or
      // string amount threw NoSuchMethodError, and DateTime.parse on a
      // missing/odd date threw FormatException — either one during the list
      // parse failed the whole charge screen. Both fields are nullable.
      amount: asDoubleN(json['amount']),
      dueAmount:
          json['due_amount'] != null ? json['due_amount'].toDouble() : 0.0,
      date: json['date'] == null ? null : DateTime.tryParse(json['date'].toString()),
      isPaid: json['is_paid'],
      isLateFee: json['is_lateFee'],
      isRepeatable: json['is_repeatable'],
      chargeType: json['charge_type'],
      id: json['_id'],
    );
  }
}

class TenantData {
  EmergencyContact? emergencyContact;
  String? tenantId;
  String? adminId;
  String? tenantFirstName;
  String? tenantLastName;
  String? tenantPhoneNumber;
  String? tenantAlternativeNumber;
  String? tenantEmail;
  String? tenantAlternativeEmail;
  String? tenantBirthDate;
  String? taxPayerId;
  String? comments;
  bool? enableOverrideFee;

  TenantData({
    this.emergencyContact,
    this.tenantId,
    this.adminId,
    this.tenantFirstName,
    this.tenantLastName,
    this.tenantPhoneNumber,
    this.tenantAlternativeNumber,
    this.tenantEmail,
    this.tenantAlternativeEmail,
    this.tenantBirthDate,
    this.taxPayerId,
    this.comments,
    this.enableOverrideFee,
  });

  factory TenantData.fromJson(Map<String, dynamic> json) {
    return TenantData(
      emergencyContact: json['emergency_contact'] != null
          ? EmergencyContact.fromJson(json['emergency_contact'])
          : null,
      tenantId: json['tenant_id'],
      adminId: json['admin_id'],
      tenantFirstName: json['tenant_firstName'],
      tenantLastName: json['tenant_lastName'],
      tenantPhoneNumber: json['tenant_phoneNumber'],
      tenantAlternativeNumber: json['tenant_alternativeNumber'],
      tenantEmail: json['tenant_email'],
      tenantAlternativeEmail: json['tenant_alternativeEmail'],
      tenantBirthDate: json['tenant_birthDate'],
      taxPayerId: json['taxPayer_id'],
      comments: json['comments'],
      enableOverrideFee: json['enable_override_fee'],
    );
  }
}

class EmergencyContact {
  String? name;
  String? relation;
  String? email;
  String? phoneNumber;

  EmergencyContact({
    this.name,
    this.relation,
    this.email,
    this.phoneNumber,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'],
      relation: json['relation'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
    );
  }
}

class enterCharge extends StatefulWidget {
  final String leaseId;
  String? chargeid;

  enterCharge({required this.leaseId, this.chargeid});

  @override
  State<enterCharge> createState() => _enterChargeState();
}

class _enterChargeState extends State<enterCharge> {
  bool _isLoading = false;
  final TextEditingController _startDate = TextEditingController();
  final TextEditingController Amount = TextEditingController();
  final TextEditingController Memo = TextEditingController();
  late Future<Map<String, List<String>>> futureDropdownData;
  String? validationMessage;
  Map<String, List<String>> categorizedData = {};
  String? selectedAccount;
  bool isLoading = true;
  bool hasError = false;
  List<FocusNode> focusNodes = [];
  List<Map<String, String>> tenants = [];
  String? selectedTenantId;
  bool isChecked = false;

  // Web parity (CRM-2682): Save stays disabled on an existing charge until
  // something actually changes. Snapshot of the charge exactly as loaded.
  Map<String, dynamic>? _initialSnapshot;

  Map<String, dynamic> _formSnapshot() => {
        'date': _startDate.text.trim(),
        'total_amount': double.tryParse(Amount.text.trim()) ?? 0,
        'memo': Memo.text.trim(),
        'rows': rows
            .map((r) => {
                  'account': r['account'] ?? '',
                  'charge_type': r['charge_type'] ?? '',
                  'amount': double.tryParse('${r['amount'] ?? 0}') ?? 0,
                })
            .toList(),
        'files': List<String>.from(_uploadedFileNames),
      };

  // Mirrors hasFormChanged() in AddCharge.js: date, total, memo, every row's
  // account/amount/charge_type, and the attached files.
  bool _hasFormChanged() {
    if (widget.chargeid == null || _initialSnapshot == null) return true;
    return jsonEncode(_formSnapshot()) != jsonEncode(_initialSnapshot);
  }

  @override
  void initState() {
    super.initState();
    // Web parity: AddCharge.js still fetches the lease tenants on load even
    // though its "Received From" selector is gone, so this stays too.
    fetchTenants();
    fetchDropdownData();
    // if (widget.chargeid != null) {
    //   fetchchargeData();
    // }
  }

  // Web parity: Add Charge opens with today's date and one empty charge row
  // (AddCharge.js initialValues). Edit Charge is untouched - it keeps whatever
  // fetchchargeData loaded from the server.
  bool _addDefaultsSeeded = false;
  String? _seededDateFormat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.chargeid != null) return;

    final String format = Provider.of<DateProvider>(context).dateFormat;

    if (!_addDefaultsSeeded) {
      _addDefaultsSeeded = true;
      _seededDateFormat = format;
      // No setState here: didChangeDependencies already runs right before
      // build, and the controller notifies its own field.
      _startDate.text = intl.DateFormat(format).format(DateTime.now());
      if (rows.isEmpty) {
        rows.add(_blankRow());
        focusNodes.add(FocusNode());
      }
      return;
    }

    // The admin's format can load after the first build. Restamp today's date
    // then, the way AddCharge.js does when accessType.themes arrives - but
    // only while the field still holds the untouched default.
    if (_seededDateFormat != format) {
      final String previousDefault =
          intl.DateFormat(_seededDateFormat!).format(DateTime.now());
      _seededDateFormat = format;
      if (_startDate.text == previousDefault) {
        _startDate.text = intl.DateFormat(format).format(DateTime.now());
      }
    }
  }

  Future<void> fetchchargeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString("adminId");
    final response = await apiGet(
      Uri.parse('$Api_url/api/charge/charge/${widget.chargeid}'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body)["data"];

      Chargedata fetchedCharge = Chargedata.fromJson(data);

      setState(() {
        selectedTenantId = fetchedCharge!.tenantId;
        Amount.text = fetchedCharge.totalAmount.toString();
        // Display follows the admin's configured format (DateProvider);
        // the payload is converted back to yyyy-MM-dd on submit.
        _startDate.text = intl.DateFormat(
                Provider.of<DateProvider>(context, listen: false).dateFormat)
            .format(fetchedCharge.entry!.first!.date!);
        Memo.text = fetchedCharge.entry!.first.memo!;
        double total = 0;

        //  Memo.text = fetchedCharge["entry"]![0]["memo"];
        // Utility fee Libality Charge
        // Utility fee as One time charge .....  Utility fee_One charge
        for (var i = 0; i < fetchedCharge.entry!.length; i++) {
          String chargeType = categorizedData.entries
              .firstWhere(
                (entryData) =>
                    entryData.value.contains(fetchedCharge.entry![i].account),
                orElse: () => MapEntry("Unknown", []), // Default if not found
              )
              .key;
          rows.add({
            'row_uid': _rowUid++,
            'entry_id': fetchedCharge.entry![i].entryId,
            'account': fetchedCharge.entry![i].account,
            // 'charge_type': fetchedCharge.entry![i].chargeType,
            'amount': fetchedCharge.entry![i].amount,
            'memo': Memo.text,
            // Preserve each entry's own original date so an edit never mutates
            // it (web keeps item.date per entry).
            'date': fetchedCharge.entry![i].date != null
                ? intl.DateFormat('yyyy-MM-dd')
                    .format(fetchedCharge.entry![i].date!)
                : _startDate.text,
            'charge_type': chargeType, // Set matched charge type
            'sub_charge_type':
                fetchedCharge.entry![i].chargeType, // Set original charge type
          });
          total += fetchedCharge.entry![i].amount!;
          totalAmount = total;
          focusNodes.add(FocusNode());
        }
        // Baseline for the "no changes detected" guard.
        _initialSnapshot = _formSnapshot();
      });
      /*setState(() {
        tenants = fetchedTenants;
      });*/
    } else {
      throw Exception('Failed to load tenants');
    }
  }

  Future<void> fetchTenants() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString("adminId");
    final response = await apiGet(
      Uri.parse('$Api_url/api/leases/lease_tenant/${widget.leaseId}'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<Map<String, String>> fetchedTenants = [];

      for (var tenant in data['data']['tenants']) {
        fetchedTenants.add({
          'tenant_id': tenant['tenant_id'],
          'tenant_name':
              '${tenant['tenant_firstName']} ${tenant['tenant_lastName']}',
        });
      }

      setState(() {
        tenants = fetchedTenants;
      });
    } else {
      throw Exception('Failed to load tenants');
    }
  }

  Future<void> fetchDropdownData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String adminId = prefs.getString('adminId') ?? '';
      String? token = prefs.getString('token');
      String? id = prefs.getString("adminId");
      final response = await apiGet(
        Uri.parse('$Api_url/api/accounts/accounts/$adminId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body)['data'];
        Map<String, List<String>> fetchedData = {};
        // Adding static items to the "LIABILITY ACCOUNT" category
        // Adding static items to the "LIABILITY ACCOUNT" category
        fetchedData["Rent"] = ["Rent Income"];
        fetchedData["Late Fee Income"] = ["Late Fee Income"];
        fetchedData["Pre-payments"] = ["Pre-payments"];
        fetchedData["Security Deposit"] = ["Security Deposit"];

        for (var item in jsonResponse) {
          String chargeType = item['charge_type'] ?? "One Time Charge";
          String account = item['account'];

          if (!fetchedData.containsKey(chargeType)) {
            fetchedData[chargeType] = [];
          }
          fetchedData[chargeType]!.add(account);
        }

        setState(() {
          categorizedData = fetchedData;
          isLoading = false;
        });
        if (widget.chargeid != null) {
          fetchchargeData();
        }
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> rows = [];
  double totalAmount = 0.0;
  // Live "Amount cannot exceed $999,999.99" inline error (web parity); the
  // submit-time bounds toast stays as a backstop.
  String? _amountLimitError;
  // Stable per-row identity. The row list is rendered without keys otherwise,
  // so deleting a middle row made Flutter reuse the element above it and the
  // next row's amount text stayed in the wrong box.
  int _rowUid = 0;

  Map<String, dynamic> _blankRow() => {
        'row_uid': _rowUid++,
        'account': null,
        'charge_type': null,
        'amount': 0.0,
        'memo': Memo.text,
        'date': _startDate.text,
        'is_recurring': false,
        'rent_cycle': 'Monthly',
      };

  void addRow() {
    setState(() {
      rows.add(_blankRow());
      focusNodes.add(FocusNode());
    });
  }

  void deleteRow(int index) {
    setState(() {
      totalAmount -= rows[index]['amount'];
      rows.removeAt(index);
      focusNodes.removeAt(index);
    });

    validateAmounts();
  }

  void updateAmount(int index, String value) {
    setState(() {
      double amount = double.tryParse(value) ?? 0.0;
      totalAmount -= rows[index]['amount'];
      rows[index]['amount'] = amount;
      totalAmount += amount;
    });
    validateAmounts();
  }

  void validateAmounts() {
    double enteredAmount = double.tryParse(Amount.text) ?? 0.0;
    double roundedEntered = double.parse(enteredAmount.toStringAsFixed(2));
    double roundedTotal = double.parse(totalAmount.toStringAsFixed(2));
    if (roundedEntered != roundedTotal) {
      setState(() {
        validationMessage =
            "The charge's amount must match the total applied to balance. The difference is ${intl.NumberFormat('#,##0.00', 'en_US').format((roundedEntered - roundedTotal).abs())}";
      });
    } else {
      setState(() {
        validationMessage = null;
      });
    }
  }

  // Web parity: MAX_CHARGE_AMOUNT = 999999.99, and each amount must be
  // between $0.01 and that max (server rejects amt <= 0 || amt > max).
  static const num _minChargeAmount = 0.01;
  static const num _maxChargeAmount = 999999.99;

  // Returns an error message if any row amount (or the total) is out of the
  // web-allowed bounds, otherwise null. Matches AddCharge.jsx validation.
  String? _validateChargeBounds(List<num> amounts, num total) {
    // Web wording (AddCharge.jsx / RentRollDetail.js yup schema) for the
    // zero/negative case, so mobile explains the block the same way web does.
    for (final amt in amounts) {
      if (amt < _minChargeAmount) {
        return 'Amount must be greater than zero.';
      }
      if (amt > _maxChargeAmount) {
        return 'Each charge amount must be between \$0.01 and \$999,999.99.';
      }
    }
    if (total < _minChargeAmount) {
      return 'Amount must be greater than zero.';
    }
    if (total > _maxChargeAmount) {
      return 'Amount must be between \$0.01 and \$999,999.99.';
    }
    return null;
  }

  // Derives the charge_type for an entry. Prefer the row's real charge type
  // (the account category resolved from the accounts API); fall back to the
  // legacy account-name / "One Time Charge" derivation so nothing regresses.
  String _resolveChargeType(Map<String, dynamic> row) {
    final rowType = row['charge_type'];
    if (rowType != null && '$rowType'.isNotEmpty) {
      return '$rowType';
    }
    final account = row['account'];
    if (account == "" ||
        account == "Rent Income" ||
        account == "Security Deposit" ||
        account == "Late Fee Income" ||
        account == "Pre-payments") {
      return account;
    }
    return "One Time Charge";
  }

  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      // Web parity: AddCharge.js uploads with accept="*", so any file type is
      // allowed here too (the old pdf/jpg/jpeg/png whitelist was mobile-only).
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null) {
      List<File> files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      // Web parity: the cap is on the running total, not on one selection
      // (AddCharge.js checks selectedFiles.length + file.length > 10), so
      // picking several batches can no longer push the charge past 10 files.
      if (files.length + _uploadedFileNames.length > 10) {
        Fluttertoast.showToast(msg: 'You can only upload 10 files');
        return;
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
          _uploadedFileNames.add(fileName);
        }
      });
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to attach the file. Please try again.');
    }
  }

  Future<String?> uploadPdf(File pdfFile) async {
    //final String uploadUrl = '${Api_url}/api/images/upload';
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('files', pdfFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      //Fluttertoast.showToast(msg: 'PDF added successfully');
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  final _formKey = GlobalKey<FormState>();
  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.grey[200],
      nextFocus: true,
      actions: [
        KeyboardActionsItem(
          focusNode: _nodeText1,
        ),
      ],
    );
  }

  final FocusNode _nodeText1 = FocusNode();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: pageBg,
      drawer: CustomDrawer(
        currentpage: "Rent Roll",
        dropdown: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBar(
                    width: double.infinity,
                    radius: 14,
                    title:
                        widget.chargeid != null ? 'Edit Charge' : 'Add Charge',
                  ),
                  const SizedBox(height: 20),
                  _chargeHeaderCard(),
                  const SizedBox(height: 16),
                  _chargeDetailsCard(),
                  const SizedBox(height: 16),
                  _uploadCard(),
                  const SizedBox(height: 20),
                  _bottomActionBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Redesign helpers. Presentation only - every callback, validator and
  // controller below is the one this screen already used.
  // ------------------------------------------------------------------

  Widget _sectionCard({
    String? title,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderClr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: navyClr,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: navyClr,
          ),
          children: required
              ? [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: redClr,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : const [],
        ),
      ),
    );
  }

  // Date / Amount / Memo. Web parity: AddCharge.js no longer renders a
  // "Received From" selector - the charge belongs to the lease and the
  // tenant link rides along in the payload.
  Widget _chargeHeaderCard() {
    return _sectionCard(
      children: [
        _fieldLabel('Date', required: true),
        CustomTextField(
          onTap: () async {
            // Web keeps the date editable while editing a charge
            // (AddCharge.js passes no `disabled` to its DatePicker), and the
            // chosen date is applied to every entry on save.
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2101),
              locale: const Locale('en', 'US'),
              builder: (BuildContext context, Widget? child) {
                return Theme(
                  data: ThemeData.light().copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color.fromRGBO(
                          21, 43, 83, 1), // header background color
                      onPrimary: Colors.white, // header text color
                      onSurface:
                          Color.fromRGBO(21, 43, 83, 1), // body text color
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color.fromRGBO(
                            21, 43, 83, 1), // button text color
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (pickedDate != null) {
              // Show the date in the admin's configured format; the API
              // payload is converted back to yyyy-MM-dd on submit.
              final String formattedDate = intl.DateFormat(
                      Provider.of<DateProvider>(context, listen: false)
                          .dateFormat)
                  .format(pickedDate);
              setState(() {
                _startDate.text = formattedDate;
              });
            }
          },
          readOnnly: true,
          showElevation: false,
          borderColor: outlineClr,
          borderWidth: 1,
          suffixIcon:
              Icon(Icons.calendar_today_outlined, size: 18, color: mutedClr),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select start date';
            }
            return null;
          },
          keyboardType: TextInputType.text,
          hintText: Provider.of<DateProvider>(context)
              .fixDateFormat(Provider.of<DateProvider>(context).dateFormat)
              .toUpperCase(),
          controller: _startDate,
        ),
        const SizedBox(height: 16),
        _fieldLabel('Amount', required: true),
        CustomTextField(
          showElevation: false,
          borderColor: outlineClr,
          borderWidth: 1,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter amount';
            }
            if (double.tryParse(value.trim()) == null) {
              return 'Please enter a valid amount';
            }
            return null;
          },
          keyboardType: TextInputType.number,
          hintText: '\$0.00',
          controller: Amount,
          onChanged: (value) {
            validateAmounts();
            final v = double.tryParse(value.trim());
            setState(() {
              _amountLimitError = (v != null && v > 999999.99)
                  ? 'Amount cannot exceed \$999,999.99'
                  : null;
            });
          },
        ),
        if (_amountLimitError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              _amountLimitError!,
              style: TextStyle(color: redClr, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        _fieldLabel('Memo'),
        CustomTextField(
          optional: true,
          showElevation: false,
          borderColor: outlineClr,
          borderWidth: 1,
          validator: (value) => null,
          keyboardType: TextInputType.text,
          hintText: 'If blank, includes all account names',
          controller: Memo,
          // Keeps the Save button's enabled state in step with the memo
          // (web re-renders on every keystroke).
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // Charge rows + Add Row + Total.
  Widget _chargeDetailsCard() {
    return _sectionCard(
      title: 'Charge Details',
      trailing: Text(
        rows.length == 1 ? '1 row' : '${rows.length} rows',
        style: TextStyle(
            fontSize: 13, color: mutedClr, fontWeight: FontWeight.w500),
      ),
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: SpinKitFadingCircle(color: Colors.black, size: 40.0),
            ),
          )
        else if (hasError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Failed to load data',
                  style: TextStyle(color: mutedClr, fontSize: 13)),
            ),
          )
        else ...[
          if (rows.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: pageBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderClr),
              ),
              child: Center(
                child: Text(
                  widget.chargeid == null
                      ? 'No charge rows yet. Tap "Add Row" to begin.'
                      : 'This charge has no rows.',
                  style: TextStyle(fontSize: 13, color: mutedClr),
                ),
              ),
            ),
          ...rows
              .asMap()
              .entries
              .map((entry) => _chargeRowCard(entry.key, entry.value))
              .toList(),
          // Web parity: the entry list is frozen while editing an existing
          // charge - AddCharge.js renders the Add Row footer only when
          // !charge_id, so rows can be added on create only.
          if (widget.chargeid == null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: addRow,
                icon: Icon(Icons.add, size: 20, color: navyClr),
                label: Text(
                  'Add Row',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: navyClr,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: outlineClr),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: navyClr,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  // NumberFormat never falls back to scientific
                  // notation (toStringAsFixed does for >= 1e21).
                  formatMoney(totalAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (validationMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              validationMessage!,
              style: TextStyle(color: redClr, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _chargeRowCard(int index, Map<String, dynamic> row) {
    return Container(
      // Identity follows the row, not its position, so a delete cannot leave
      // the next row's amount behind. Falls back to the index if a row was
      // built without an id.
      key: ValueKey(row['row_uid'] ?? index),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderClr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            decoration: BoxDecoration(
              color: tintBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ROW ${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                      color: navyClr,
                    ),
                  ),
                ),
                // Web parity: rows can only be removed while creating the
                // charge (AddCharge.js wraps the delete cell in !charge_id).
                if (widget.chargeid == null)
                  Material(
                    color: const Color(0xFFFCE8E6),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => deleteRow(index),
                      child: const Padding(
                        padding: EdgeInsets.all(7),
                        child:
                            Icon(Icons.close_rounded, size: 18, color: redClr),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Account', required: true),
                DropdownButtonHideUnderline(
                  child: FormField<String>(
                    validator: (value) {
                      if (rows[index]['account'] == null) {
                        return 'Please select account';
                      }
                      return null;
                    },
                    builder: (FormFieldState<String> state) {
                      String? selectedAccount = row['account'];

                      String? selectedCharge = row['charge_type'];
                      // List of all dropdown items, including missing ones
                      Map<String, List<String>> categorizedDataCopy =
                          Map.from(categorizedData);

                      // Ensure the selected value is present in the list
                      if (selectedAccount != null &&
                          !categorizedData.values
                              .expand((list) => list)
                              .contains(selectedAccount)) {
                        if (categorizedDataCopy['Other'] == null) {
                          categorizedDataCopy['Other'] = [];
                        }
                        categorizedDataCopy['Other']!.add(selectedAccount);
                      }

                      List<String> liabilityAccounts = [
                        "Late Fee Income",
                        "Pre-payments",
                        // "Security Deposit",
                        // 'Rent Income'
                      ];
                      String? surchargetype;
                      if (selectedCharge == "Surcharge") {
                        for (var entry in categorizedData.entries) {
                          if (entry.value.contains(selectedAccount)) {
                            surchargetype = entry.key;
                            break;
                          }
                        }
                      }
                      bool nosurcharge = false;
                      if (row["charge_type"] == "Surcharge") {

                        for (var entry in categorizedData.entries) {
                          if (entry.value.contains(row['account'])) {
                            surchargetype = entry.key;
                          }
                        }
                        if (surchargetype == "") {
                          nosurcharge = true;
                        }
                      }

                      // Prepare the dropdown items
                      List<DropdownMenuItem<String>> dropdownItems = [
                        ...categorizedDataCopy.entries.expand((entry) {
                          return [
                            // DropdownMenuItem<String>(
                            //   enabled: false,
                            //   child: Text(
                            //     entry.key,
                            //     style: const TextStyle(
                            //       fontWeight:
                            //           FontWeight.bold,
                            //       color: Color.fromRGBO(
                            //           21, 43, 81, 1),
                            //     ),
                            //   ),
                            // ),
                            ...entry.value.map((item) {
                              return DropdownMenuItem<String>(
                                value: "${item}_${entry.key}",
                                child: Padding(
                                  // Open-list spacing only — the closed button is
                                  // drawn by selectedItemBuilder, so this cannot
                                  // shift the button's text.
                                  padding: const EdgeInsets.only(
                                      left: 14, bottom: 1),
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ];
                        }).toList(),
                        if (row['account'] != null &&
                            !categorizedData.values
                                .expand((v) => v)
                                .contains(row['account']))
                          DropdownMenuItem<String>(
                            value: "${row['account']}_${row['charge_type']}",
                            child: Padding(
                              padding: const EdgeInsets.only(left: 0.0),
                              child: Text(
                                row['account']!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                      ];

                      // Ensure the currently-selected account has a
                      // matching dropdown item so DropdownButton2's
                      // value maps to exactly one item. On edit, a
                      // charge's stored charge_type can differ from the
                      // account's category in the accounts list (e.g.
                      // legacy data), which otherwise crashes with the
                      // "exactly one item" assertion.
                      final String? currentValue = row['account'] != null
                          ? (row['charge_type'] == "Surcharge" &&
                                  surchargetype != null
                              ? "${row['account']}_$surchargetype"
                              : "${row['account']}_${row['charge_type']}")
                          : null;
                      if (currentValue != null &&
                          !dropdownItems.any((i) => i.value == currentValue)) {
                        dropdownItems.add(DropdownMenuItem<String>(
                          value: currentValue,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 0.0),
                            child: Text(
                              row['account'] ?? '',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ));
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButton2<String>(
                            isExpanded: true,
                            // value: (row['account'] !=
                            //             null &&
                            //         row['charge_type'] !=
                            //             null)
                            //     ? (liabilityAccounts
                            //             .contains(row[
                            //                 'account'])
                            //         ? "${row['account']}_Liability Account"
                            //         : "${row['account']}_${row['charge_type']}")
                            //     : null,
                            // value: row['account'] != null ? liabilityAccounts.contains(row['account']) ?
                            //  "${row['account']}_Liability Account" : row['charge_type'] == "Surcharge" ?
                            //  "${row['account']}_$surchargetype" :  "${row['account']}_${row['charge_type']}":null,
                            value: currentValue,
                            items: dropdownItems,
                            // The closed button otherwise inherits the package's
                            // default 16pt menu-item padding on top of the
                            // button's own 14pt, starting the account text ~30pt
                            // in while the Amount field beside it starts at 14pt.
                            // Rendering the selected value here keeps the button
                            // at 14pt and leaves the open list's spacing alone.
                            selectedItemBuilder: (context) => dropdownItems
                                .map(
                                  (_) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      row['account'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              dynamic? chargeType;
                              for (var entry in categorizedData.entries) {
                                if (entry.value.contains(value)) {
                                  chargeType = entry.key;
                                  break;
                                }
                              }
                              setState(() {
                                final parts = value!.split('_');
                                final selectedChargeType = parts[0];
                                final selectedValue =
                                    parts.sublist(1).join('_');
                                rows[index]['account'] = selectedChargeType;
                                rows[index]['charge_type'] = selectedValue;
                                state.didChange(
                                    value); // Update the FormField state
                              });
                              state.reset();
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              // 14pt both sides, matching the Amount field's
                              // contentPadding (horizontal: 14) so the two
                              // controls align on the right as well as the left.
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: state.hasError ? redClr : outlineClr,
                                    width: 1),
                              ),
                              elevation: 0,
                            ),
                            iconStyleData: IconStyleData(
                              icon:
                                  const Icon(Icons.keyboard_arrow_down_rounded),
                              iconSize: 22,
                              iconEnabledColor: mutedClr,
                              iconDisabledColor: Colors.grey,
                            ),
                            // Zero here so the closed button cannot inherit the
                            // package's default 16pt menu-item padding on top of
                            // buttonStyleData's 14pt. The open list gets its own
                            // inset from each item's Padding instead.
                            menuItemStyleData: const MenuItemStyleData(
                              padding: EdgeInsets.zero,
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 350,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              scrollbarTheme: ScrollbarThemeData(
                                radius: const Radius.circular(6),
                                thickness: MaterialStateProperty.all(6),
                                thumbVisibility:
                                    MaterialStateProperty.all(true),
                              ),
                            ),
                            hint: Text(
                              'Select',
                              style: TextStyle(
                                  fontSize: 13, color: const Color(0xFFb0b6c3)),
                            ),
                          ),
                          if (state.hasError &&
                              (state.errorText ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 2),
                              child: Text(
                                state.errorText ?? '',
                                style: TextStyle(color: redClr, fontSize: 12),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _fieldLabel('Amount'),
                SizedBox(
                  height: 50,
                  child: KeyboardActions(
                    config: _buildConfig(context),
                    child: TextFormField(
                      initialValue: widget.chargeid != null
                          ? rows[index]["amount"].toString()
                          : "0", // Make sure 0 is a string,
                      focusNode: focusNodes[index],
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      onChanged: (value) => updateAmount(index, value),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: '\$0.00',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFFb0b6c3)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: outlineClr),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: outlineClr),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: navyClr, width: 1.3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _fieldLabel('Recurring'),
                    const Spacer(),
                    Switch(
                      value: rows[index]['is_recurring'] == true,
                      activeColor: navyClr,
                      onChanged: (v) {
                        setState(() {
                          rows[index]['is_recurring'] = v;
                        });
                      },
                    ),
                  ],
                ),
                if (rows[index]['is_recurring'] == true) ...[
                  const SizedBox(height: 8),
                  _fieldLabel('Frequency'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: outlineClr),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: (rows[index]['rent_cycle'] ?? 'Monthly') as String,
                        items: const [
                          DropdownMenuItem(
                              value: 'Monthly', child: Text('Monthly')),
                          DropdownMenuItem(
                              value: 'Weekly', child: Text('Weekly')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            rows[index]['rent_cycle'] = v ?? 'Monthly';
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    return _sectionCard(
      title: 'Upload Files',
      trailing: Text(
        'Max 10',
        style: TextStyle(
            fontSize: 13, color: mutedClr, fontWeight: FontWeight.w500),
      ),
      children: [
        GestureDetector(
          onTap: _pickPdfFiles,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCED4DA), width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Image.asset(
                  'assets/icons/Upload.png',
                  height: 50,
                  width: 50,
                ),
                const SizedBox(height: 10),
                Text(
                  'Add attachment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'image, receipt, PDF...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A6)),
                ),
              ],
            ),
          ),
        ),
        if (_uploadedFileNames.isNotEmpty)
          ...List.generate(_uploadedFileNames.length, (index) {
            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: pageBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderClr),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined,
                      size: 18, color: mutedClr),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _uploadedFileNames[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: navyClr,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _uploadedFileNames.removeAt(index);
                      });
                    },
                    icon: Icon(Icons.close_rounded, size: 18, color: redClr),
                    splashRadius: 18,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                  ),
                ],
              ),
            );
          }),
        if (widget.chargeid == null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (value) {
                    setState(() {
                      isChecked = value ?? false;
                    });
                  },
                  activeColor: navyClr,
                  checkColor: Colors.white,
                  side: BorderSide(color: checkOffClr, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Add Another Charge',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: navyClr,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bottomActionBar() {
    // Web parity: on an existing charge the primary button is disabled until
    // at least one field changes (AddCharge.js: disabled={charge_id &&
    // !hasFormChanged()}).
    final bool blockUnchanged = widget.chargeid != null && !_hasFormChanged();
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: outlineClr),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: mutedClr,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: (isLoading || blockUnchanged)
                ? null
                : () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      setState(() {
                        _isLoading = true;
                      });


                      if (validationMessage == null) {
                        if (widget.chargeid != null) {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          String adminId =
                              prefs.getString('adminId').toString();

                          // Decimal-preserving amounts (web
                          // sends Number(item.amount), not int).
                          final List<num> rowAmounts = rows
                              .map((row) =>
                                  num.tryParse('${row['amount'] ?? 0}') ?? 0)
                              .toList();
                          num totalAmount =
                              num.tryParse(Amount.text.trim()) ?? 0;

                          // Web parity: enforce per-row and
                          // total amount bounds before submit.
                          final String? boundsError =
                              _validateChargeBounds(rowAmounts, totalAmount);
                          if (boundsError != null) {
                            // Web parity: show WHY the submit
                            // was blocked instead of failing
                            // silently.
                            setState(() {
                              _isLoading = false;
                              validationMessage = boundsError;
                            });
                            return;
                          }

                          List<Entry> entryList = [];
                          for (int i = 0; i < rows.length; i++) {
                            final row = rows[i];
                            // Web parity: the single Date field is applied
                            // to every entry (values.date), rather than the
                            // copy taken when the row was created.
                            String formattedDate = _startDate.text;
                            final num amount = rowAmounts[i];
                            entryList.add(Entry(
                              account: row['account'],
                              amount: amount,
                              // Web sends due_amount = amount.
                              dueAmount: amount,
                              // Web parity: read the memo from the field at save
                              // time (AddCharge.js sends values.charges_memo ||
                              // item.account). It used to be snapshotted into the
                              // row when Add Row was tapped, so a memo typed
                              // after adding the rows was silently dropped.
                              memo: Memo.text.trim().isEmpty
                                  ? row['account']
                                  : Memo.text,
                              // API always receives yyyy-MM-dd, whatever
                              // the on-screen display format is.
                              date: reverseFormatDate(formattedDate),
                              chargeType: _resolveChargeType(row),
                              isRepeatable: false,
                              entryId: row['entry_id'],
                            ));
                          }

                          Charge charge = Charge(
                            adminId: adminId,
                            isLeaseAdded: false,
                            leaseId: widget.leaseId,
                            tenantId: selectedTenantId ?? "",
                            totalAmount: totalAmount,
                            uploadedFile: _uploadedFileNames,
                            entry: entryList,
                          );

                          LeaseRepository apiService = LeaseRepository();
                          final response = await apiService.EditCharge(
                              charge, widget.chargeid!);
                          final int statusCode = response.statusCode;
                          Map<String, dynamic> respBody = {};
                          try {
                            final decoded = jsonDecode(response.body);
                            if (decoded is Map<String, dynamic>) {
                              respBody = decoded;
                            }
                          } catch (_) {}

                          if (statusCode == 200) {
                            setState(() {
                              _isLoading = false;
                            });
                            // Show the server's real message
                            // when present (e.g. scheduled),
                            // else the default success toast.
                            final bool isScheduled =
                                respBody['scheduled'] == true;
                            final String? serverMessage =
                                respBody['message']?.toString();
                            Fluttertoast.showToast(
                              msg: (isScheduled ||
                                      (serverMessage != null &&
                                          serverMessage.isNotEmpty))
                                  ? (serverMessage ?? "Charge scheduled")
                                  : "Charge Edited successfully",
                            );
                            Navigator.pop(context, true);
                          } else {
                            setState(() {
                              _isLoading = false;
                            });
                            final String? serverMessage =
                                respBody['message']?.toString();
                            Fluttertoast.showToast(
                              msg: (serverMessage != null &&
                                      serverMessage.isNotEmpty)
                                  ? serverMessage
                                  : "Failed to post charge",
                            );
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        } else {
                          SharedPreferences prefs =
                              await SharedPreferences.getInstance();
                          String adminId =
                              prefs.getString('adminId').toString();

                          // Decimal-preserving amounts (web
                          // sends Number(item.amount), not int).
                          final List<num> rowAmounts = rows
                              .map((row) =>
                                  num.tryParse('${row['amount'] ?? 0}') ?? 0)
                              .toList();
                          num totalAmount =
                              num.tryParse(Amount.text.trim()) ?? 0;

                          // Web parity: enforce per-row and
                          // total amount bounds before submit.
                          final String? boundsError =
                              _validateChargeBounds(rowAmounts, totalAmount);
                          if (boundsError != null) {
                            // Web parity: show WHY the submit
                            // was blocked instead of failing
                            // silently.
                            setState(() {
                              _isLoading = false;
                              validationMessage = boundsError;
                            });
                            return;
                          }

                          // Web parity (LeaseSummaryTab.jsx): a row flagged
                          // Recurring is posted to add-recurring-charge; the
                          // rest go in a single one-time /charge/charge POST.
                          final List<int> oneTimeIndexes = [];
                          final List<int> recurringIndexes = [];
                          for (int i = 0; i < rows.length; i++) {
                            if (rows[i]['is_recurring'] == true) {
                              recurringIndexes.add(i);
                            } else {
                              oneTimeIndexes.add(i);
                            }
                          }

                          LeaseRepository apiService = LeaseRepository();
                          bool allSucceeded = true;
                          http.Response? oneTimeResponse;

                          // One-time rows -> a single charge, as before.
                          if (oneTimeIndexes.isNotEmpty) {
                            List<Entry> entryList = [];
                            for (final i in oneTimeIndexes) {
                              final row = rows[i];
                              // Web parity: the single Date field is applied
                              // to every entry (values.date), rather than the
                              // copy taken when the row was created.
                              String formattedDate = _startDate.text;
                              final num amount = rowAmounts[i];
                              entryList.add(Entry(
                                account: row['account'],
                                amount: amount,
                                // Web sends due_amount = amount.
                                dueAmount: amount,
                                // Web parity: read the memo from the field at save
                                // time (AddCharge.js sends values.charges_memo ||
                                // item.account). It used to be snapshotted into the
                                // row when Add Row was tapped, so a memo typed
                                // after adding the rows was silently dropped.
                                memo: Memo.text.trim().isEmpty
                                    ? row['account']
                                    : Memo.text,
                                // API always receives yyyy-MM-dd, whatever
                                // the on-screen display format is.
                                date: reverseFormatDate(formattedDate),
                                chargeType: _resolveChargeType(row),
                                isRepeatable: false,
                                entryId: row['entry_id'],
                              ));
                            }

                            Charge charge = Charge(
                              adminId: adminId,
                              isLeaseAdded: false,
                              leaseId: widget.leaseId,
                              // Send the selected lease tenant
                              // when available (web sends the
                              // chosen tenant_id).
                              tenantId: selectedTenantId ?? "",
                              totalAmount: totalAmount,
                              uploadedFile: _uploadedFileNames,
                              entry: entryList,
                            );

                            oneTimeResponse =
                                await apiService.postCharge(charge);
                            if (oneTimeResponse.statusCode != 200) {
                              allSucceeded = false;
                            }
                          }

                          // Recurring rows -> one add-recurring-charge each.
                          if (allSucceeded) {
                            for (final i in recurringIndexes) {
                              final recurringResponse =
                                  await apiService.addRecurringCharge(
                                leaseId: widget.leaseId,
                                amount: rowAmounts[i],
                                account: rows[i]['account'],
                                memo: Memo.text.trim().isEmpty
                                    ? rows[i]['account']
                                    : Memo.text,
                                rentCycle: (rows[i]['rent_cycle'] ?? 'Monthly'),
                                chargeStart:
                                    reverseFormatDate(_startDate.text),
                              );
                              if (recurringResponse.statusCode != 200 &&
                                  recurringResponse.statusCode != 201) {
                                allSucceeded = false;
                                break;
                              }
                            }
                          }

                          // Prefer the one-time charge's server message (e.g.
                          // scheduled) when that call was made.
                          Map<String, dynamic> respBody = {};
                          if (oneTimeResponse != null) {
                            try {
                              final decoded =
                                  jsonDecode(oneTimeResponse.body);
                              if (decoded is Map<String, dynamic>) {
                                respBody = decoded;
                              }
                            } catch (_) {}
                          }

                          if (allSucceeded) {
                            setState(() {
                              _isLoading = false;
                            });
                            // A future-dated charge is not
                            // posted; the server returns a
                            // scheduled message. Show the
                            // server's real message when
                            // present, else the default toast.
                            final bool isScheduled =
                                respBody['scheduled'] == true;
                            final String? serverMessage =
                                respBody['message']?.toString();
                            Fluttertoast.showToast(
                              msg: (isScheduled ||
                                      (serverMessage != null &&
                                          serverMessage.isNotEmpty))
                                  ? (serverMessage ?? "Charge scheduled")
                                  : (oneTimeResponse != null
                                      ? "Charge posted successfully"
                                      : "Charge added successfully"),
                            );
                            if (isChecked == true) {
                              resetFields();
                            } else {
                              Navigator.pop(context, true);
                            }
                          } else {
                            setState(() {
                              _isLoading = false;
                            });
                            final String? serverMessage =
                                respBody['message']?.toString();
                            Fluttertoast.showToast(
                              msg: (serverMessage != null &&
                                      serverMessage.isNotEmpty)
                                  ? serverMessage
                                  : "Failed to post charge",
                            );
                            setState(() {
                              _isLoading = false;
                            });
                          }
                        }
                      }

                      //charges
                    } else {
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: navyClr,
              disabledBackgroundColor: navyClr.withOpacity(0.5),
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: SpinKitFadingCircle(color: Colors.white, size: 22),
                  )
                : Text(
                    widget.chargeid != null ? 'Edit Charge' : 'Add Charge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // Web parity: with "Add Another Charge" ticked, a successful save clears the
  // form and stays on the screen instead of navigating back (resetForm() +
  // setFile([]) in the web screen). The selected tenant is deliberately kept,
  // since the next charge is normally for the same resident.
  void resetFields() {
    setState(() {
      Memo.clear();
      selectedAccount = null;
      Amount.clear();
      rows.clear();
      // focusNodes is indexed alongside rows - clear it together or the two
      // lists drift apart.
      focusNodes.clear();
      totalAmount = 0.0;
      validationMessage = null;
      _uploadedFileNames.clear();
      _pdfFiles.clear();
      isChecked = false;
    });
    // Re-seed the single empty row on the NEXT frame. Adding it in the same
    // setState would let Flutter reuse the old amount field's element (no keys
    // on the row list), so the previous amount would linger on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && rows.isEmpty) addRow();
    });
  }
}
