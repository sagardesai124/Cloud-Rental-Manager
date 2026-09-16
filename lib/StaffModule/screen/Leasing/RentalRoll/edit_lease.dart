import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:three_zero_two_property/StaffModule/repository/lease.dart';
import 'package:three_zero_two_property/StaffModule/repository/properties.dart';

import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/model/properties.dart';

import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import '../../../../Model/ApplicantModel.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/clearable_date_picker.dart';
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../../Model/tenants.dart';
import '../../../../model/cosigner.dart';
import '../../../../model/edit_lease.dart';
import '../../../../model/get_lease.dart';
import '../../../../model/lease.dart';

import '../../../../provider/lease_provider.dart';
import '../../../repository/tenants.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../../provider/dateProvider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/add_tenant_cosigner_screen.dart';

class Edit_lease extends StatefulWidget {
  Lease1? lease;
  final String leaseId;
  Edit_lease({super.key, this.lease, required this.leaseId});

  @override
  State<Edit_lease> createState() => _Edit_leaseState();
}

class _Edit_leaseState extends State<Edit_lease>
    with SingleTickerProviderStateMixin {
  late Future<List<Rentals>> futureRentalOwners;

  String? rent_entry_id;
  String? rent_security_id;
  String? initialRentAmount;
  String? initialRentMemo;
  String? initialRentNextDueDate;
  String? initialSelectedLeaseType;
  String? initialSelectedRent;
  String? initialSecurityDepositAmount;
  String? initialStartDate;
  String? initialEndDate;
  @override
  void initState() {
    super.initState();
    // print(widget.cosigner?.firstName);
    futureRentalOwners = PropertiesRepository().fetchProperties();
    _loadProperties();
    _tabController = TabController(length: 2, vsync: this);
    // _selectedProperty = widget.lease.rentalAddress;
    //   _selectedLeaseType = widget.lease.leaseType;
    //  _startDate.text = widget.lease.startDate!;
    //   _endDate.text = widget.lease.endDate!;
    // _selectedRent = widget.lease.rentCycle;
    // rentAmount.text = widget.lease.amount as String;
    //    rentNextDueDate.text = widget.lease.rentDueDate!;

    // Future.delayed(Duration.zero, () {
    //   final selectedTenantsProvider = Provider.of<SelectedTenantsProvider>(context, listen: false);
    //
    //   selectedTenantsProvider.setTenants([
    //     Tenant(tenantFirstName: 'John', tenantLastName: 'Doe'),
    //     Tenant(tenantFirstName: 'Jane', tenantLastName: 'Smith'),
    //    // Tenant(tenantFirstName: '${tenants.first.tenantFirstName}',tenantLastName: tenants.first.tenantLastName),
    //
    //   ]);
    //   setState(() {
    //
    //
    //   });
    // });
    fetchDetails(widget.leaseId);
  }

  Future<void> fetchDetails(String leaseId) async {
    //try {

    LeaseDetails fetchedDetails =
        await LeaseRepository().fetchLeaseDetails(leaseId);
    if (!mounted) return;
    setState(() {
      // print(fetchedDetails.rental.rentalAddress);
      initialRentAmount = fetchedDetails.rentCharges!.first.amount.toString();
      initialRentMemo = fetchedDetails.rentCharges?.first.memo ?? "";
      initialRentNextDueDate =
          formatDate(fetchedDetails.rentCharges!.first.date);
      initialSecurityDepositAmount = fetchedDetails.securityCharges!.isNotEmpty
          ? fetchedDetails.securityCharges!.first!.amount.toString()
          : '';
      initialStartDate = formatDate(fetchedDetails.lease.startDate);
      initialEndDate = formatDate(fetchedDetails.lease.endDate);
      initialSelectedLeaseType = fetchedDetails.lease.leaseType ?? "";
      initialSelectedRent = fetchedDetails.rentCharges!.first.rentCycle ?? "";

      _selectedProperty = fetchedDetails.rental.rentalId;
      renderId = fetchedDetails.rental.rentalId!;
      _leaseRentalAddress = fetchedDetails.rental.rentalAddress;

      _selectedLeaseType = fetchedDetails.lease.leaseType;
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      startDateController.text =
          dateProvider.formatCurrentDate(fetchedDetails.lease.startDate);
      endDateController.text =
          dateProvider.formatCurrentDate(fetchedDetails.lease.endDate);

      _selectedRent = fetchedDetails.rentCharges!.first!.rentCycle;
      rentMemo.text = fetchedDetails.rentCharges!.first!.memo;

      rent_entry_id = fetchedDetails.rentCharges!.first.entry_id;
      rentNextDueDate.text = Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(fetchedDetails.rentCharges!.first!.date);
      rentAmount.text = fetchedDetails.rentCharges!.first!.amount.toString();

      // if(fetchedDetails.lease.uploadedFile != "")
      //   _uploadedFileNames.add(fetchedDetails.lease.uploadedFile.first);

      if (fetchedDetails.lease.uploadedFile != null &&
          fetchedDetails.lease.uploadedFile.isNotEmpty) {
        _uploadedFileNames.add(fetchedDetails.lease.uploadedFile.first);
      }

      if (fetchedDetails.securityCharges != null &&
          fetchedDetails.securityCharges!.length > 0) {
        final depositAmount = fetchedDetails.securityCharges!.first!.amount;
        // Match web: show the saved amount only when there is a real deposit
        // (> 0); for 0 / missing, leave the field empty so the "Enter amount
        // here" placeholder shows. Whole amounts drop the trailing ".0".
        securityDepositeAmount.text = fetchedDetails
                    .securityCharges!.first!.chargeType ==
                'Security Deposit'
            ? ((depositAmount == null || depositAmount == 0)
                ? ''
                : (depositAmount % 1 == 0
                    ? depositAmount.toInt().toString()
                    : depositAmount.toString()))
            : '';
      } else
        // No security deposit charge — leave empty to match web's placeholder.
        securityDepositeAmount.text = '';
      // Payment Settings pre-fill (web parity) — from the lease's first tenant
      if (fetchedDetails.tenant != null && fetchedDetails.tenant!.isNotEmpty) {
        final firstTenant = fetchedDetails.tenant!.first;
        // Web parity: treat a 0% (or missing) fee as "no override" — only
        // check the box when there's a genuine non-zero override fee.
        _enableDebitCardFeeOverride = (firstTenant.enableoverrideFee ?? false) &&
            ((firstTenant.overRideFee ?? 0) > 0);
        _overrideFeeController.text = firstTenant.overRideFee == null
            ? ''
            : (firstTenant.overRideFee! % 1 == 0
                ? firstTenant.overRideFee!.toInt().toString()
                : firstTenant.overRideFee!.toString());
        _allowAch = firstTenant.allowAch ?? true;
        _allowCard = firstTenant.allowCard ?? true;
      }
      if (fetchedDetails.securityCharges != null &&
          fetchedDetails.securityCharges!.length > 0)
        rent_security_id = fetchedDetails.securityCharges!.first!.chargeType ==
                'Security Deposit'
            ? fetchedDetails.securityCharges!.first.entry_id
            : '';
      for (int i = 0; i < fetchedDetails.tenant!.length; i++) {
        Provider.of<SelectedTenantsProvider>(context, listen: false)
            .addTenant(fetchedDetails.tenant![i]);
        // Assuming fetchedDetails.tenant![i].rentShare contains the rent share data

        Provider.of<SelectedTenantsProvider>(context, listen: false)
            .rentShareControllers[i]
            .text = fetchedDetails.tenant![i].rentshare.toString();
      }
      for (int i = 0; i < fetchedDetails.cosigner!.length; i++) {
        Provider.of<SelectedCosignersProvider>(context, listen: false)
            .addCosigner(fetchedDetails.cosigner![i]);
      }
      if (fetchedDetails.one_charge_data != null &&
          fetchedDetails.one_charge_data!.isNotEmpty) {
        formDataOneTimeList = fetchedDetails.one_charge_data!.map((item) {
          // Ensure item is a Map and all keys and values are strings
          if (item is Map) {
            return item.map(
                (key, value) => MapEntry(key.toString(), value.toString()));
          }
          return <String, String>{};
        }).toList();
      }
      if (fetchedDetails.rec_charge_data != null &&
          fetchedDetails.rec_charge_data!.isNotEmpty) {
        formDataRecurringList = fetchedDetails.rec_charge_data!.map((item) {
          // Ensure item is a Map and all keys and values are strings
          if (item is Map) {
            return item.map(
                (key, value) => MapEntry(key.toString(), value.toString()));
          }
          return <String, String>{};
        }).toList();

        log(formDataRecurringList.toList().toString());
      }

      // Initialize payment settings from fetched lease data
      _leasePaymentSettings =
          fetchedDetails.lease.leasePaymentSettings ?? false;
      _creditCardAccepted = fetchedDetails.lease.creditCardAccepted ?? false;
      _debitCardAccepted = fetchedDetails.lease.debitCardAccepted ?? false;
      _achAccepted = fetchedDetails.lease.achAccepted ?? false;
      _achAcceptedDirty = false;
      _paymentSettingsLoaded = true;
    });

    _loadUnits(renderId);
    setState(() {
      _selectedUnit = fetchedDetails.lease.unitId;
    });

    //} catch (e) {
    //print('Failed to fetch lease details: $e');
    //}
  }

  TextEditingController rentShareControllers = TextEditingController();
//first container variable
  List<Tenant> selectedTenants = [];
  bool isChecked = false;
  bool isLoading = false;
  int? selectedIndex;
  List<Tenant> tenants = [];
  List<Tenant> filteredTenants = [];
  List<bool> selected = [];
  bool _isLoading = true;
  List<Map<String, String>> properties = [];
  // Search box inside the property dropdown. With the full rental list now
  // loaded (?limit=0) a plain scroll list is unusable, so this mirrors the
  // Bid Room property dropdown.
  final TextEditingController _propertySearchController =
      TextEditingController();
  List<Map<String, String>> units = [];
  String? _selectedProperty;
  /// From lease details when this rental is not returned by `/rentals` for the dropdown.
  String? _leaseRentalAddress;
  String? _selectedUnit;
  String? _selectedLeaseType;

  final TextEditingController startDateController = TextEditingController();
  DateTime? _startDate;
  final TextEditingController endDateController = TextEditingController();
  DateTime? _endDate;

  // second container variables
  String? _selectedRent;
  final TextEditingController rentAmount = TextEditingController();
  final TextEditingController rentNextDueDate = TextEditingController();
  final TextEditingController rentMemo = TextEditingController();

  //changes variables
  Future<void> _loadProperties() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(Uri.parse(
              // Web parity: the lease form requests `?limit=0` for this
              // list (RentRollLeasing.jsx / Staffaddrentroll.jsx).
              // `limit=0` is the server's own no-limit flag; omitting it
              // falls back to a page of 10 (Rentals.js).
              '${Api_url}/api/rentals/rentals/$id?limit=0'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $staffid",
      });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        List<Map<String, String>> addresses = jsonResponse.map((data) {
          return {
            'rental_id': data['rental_id'].toString(),
            'rental_adress': data['rental_adress'].toString(),
          };
        }).toList();

        // Sort properties alphabetically by address (A-Z)
        addresses.sort((a, b) => (a['rental_adress'] ?? '')
            .toLowerCase()
            .compareTo((b['rental_adress'] ?? '').toLowerCase()));

        setState(() {
          properties = addresses;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch properties: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  List<Map<String, String>> _propertyDropdownItems() {
    final list = List<Map<String, String>>.from(properties);
    final sel = _selectedProperty?.trim();
    if (sel == null || sel.isEmpty) return list;
    final exists = list.any(
        (p) => (p['rental_id'] ?? '').toString().trim() == sel);
    if (exists) return list;
    final addr = (_leaseRentalAddress != null &&
            _leaseRentalAddress!.trim().isNotEmpty)
        ? _leaseRentalAddress!.trim()
        : 'Unavailable property';
    list.add({
      'rental_id': sel,
      'rental_adress': addr,
    });
    list.sort((a, b) => (a['rental_adress'] ?? '')
        .toLowerCase()
        .compareTo((b['rental_adress'] ?? '').toLowerCase()));
    return list;
  }

  bool _showUnitDropdown = false;

  Future<void> _loadUnits(String rentalId) async {
    setState(() {
      _isLoading = true;
      _showUnitDropdown = false;
      // Clear units and selection when loading new units
      units = [];
      _selectedUnit = null;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('adminId');
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/unit/rental_unit/$rentalId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $staffid",
      });

      if (response.statusCode == 200) {
        Map<String, dynamic> responses = jsonDecode(response.body);
        if (responses["statusCode"] == 200) {
          List jsonResponse = json.decode(response.body)['data'];

          List<Map<String, String>> unitAddresses = jsonResponse.map((data) {
            return {
              'unit_id': data['unit_id'].toString(),
              'rental_unit': data['rental_unit'].toString(),
            };
          }).toList();

          // Filter out any null or empty unit names
          unitAddresses = unitAddresses.where((unit) {
            String unitId = unit['unit_id'] ?? '';
            String unitName = unit['rental_unit'] ?? '';
            return unitId.isNotEmpty && unitName.trim().isNotEmpty;
          }).toList();


          setState(() {
            units = unitAddresses;
            _isLoading = false;
            _showUnitDropdown = units.isNotEmpty;
          });
        } else {
          setState(() {
            _isLoading = false;
            _showUnitDropdown = false;
          });
        }
      } else {
        throw Exception('Failed to load units');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        units = [];
        _selectedUnit = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch units: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  List<String> accounts = [];

  Future<void> fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('adminId');
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('$Api_url/api/accounts/accounts/$id'), headers: {
      "authorization": "CRM $token",
      "id": "CRM ${prefs.getString('staff_id') ?? id}",
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        accounts = (data['data'] as List)
            .where((item) => item['charge_type'] == "One Time Charge")
            .map((item) => item['account'] as String)
            .toList();
        _isLoading = false;
      });
    } else {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch data')),
      );
    }
  }

  String companyName = '';
  Future<void> fetchCompany() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");

    if (adminId != null) {
      try {
        String fetchedCompanyName =
            await TenantsRepository().fetchCompanyName(adminId);
        setState(() {
          companyName = fetchedCompanyName;
        });
      } catch (e) {
        logError('Failed to fetch company name: $e');
        // Handle error state, e.g., show error message to user
      }
    }
  }

  bool InValid = false;

  bool isEnjoyNowSelected = true;
  bool isTenantSelected = true;

  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GlobalKey<FormState> _addRecurringFormKey = GlobalKey<FormState>();

  final TextEditingController Amount = TextEditingController();

  final TextEditingController securityDepositeAmount = TextEditingController();
  final TextEditingController recurringContentAmount = TextEditingController();
  final TextEditingController recurringContentMemo = TextEditingController();
  final TextEditingController oneTimeContentMemo = TextEditingController();
  final TextEditingController oneTimeContentAmount = TextEditingController();
  final TextEditingController signatureController = TextEditingController();
  GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey();

  bool _selectedResidentsEmail = false; // Initialize the boolean variable
  bool _leasePaymentSettings = false; // Enable payment settings
  bool _creditCardAccepted = false; // Credit card checkbox
  bool _debitCardAccepted = false;
  // Payment Settings section (web parity) — lease-level, applied to all tenants
  bool _enableDebitCardFeeOverride = false; // Enable Debit Card Fee Override
  final TextEditingController _overrideFeeController = TextEditingController();
  bool _allowAch = true; // Allowed Payment Methods: ACH
  bool _allowCard = true; // Allowed Payment Methods: Card
  bool _achAccepted = false; // Debit card checkbox
  bool _achAcceptedDirty = false;
  bool _isUpdatingAchSetting = false;
  bool _paymentSettingsLoaded = false; // true after fetchDetails sets ACH state

  Future<bool> _confirmReenableAch() async {
    final completer = Completer<bool>();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Re-enable ACH?",
      desc: "Are you sure you want to re-enable ACH for this lease?",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: Text(
            "Yes",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () {
            completer.complete(true);
            Navigator.pop(context);
          },
          color: blueColor,
        ),
        DialogButton(
          child: Text(
            "No",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            completer.complete(false);
            Navigator.pop(context);
          },
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(color: blueColor, width: 1.5),
        ),
      ],
    ).show();
    return completer.future;
  }

  Future<void> _updateAchSetting({required bool achAccepted}) async {
    if (_isUpdatingAchSetting) return;

    final prevAchAccepted = _achAccepted;
    final prevLeasePaymentSettings = _leasePaymentSettings;

    setState(() {
      _isUpdatingAchSetting = true;
      _achAccepted = achAccepted;
      _leasePaymentSettings = true;
    });

    final success = await LeaseRepository().updateLeasePaymentSettings(
      leaseId: widget.leaseId,
      leasePaymentSettings: _leasePaymentSettings,
      achAccepted: _achAccepted,
    );

    if (!mounted) return;

    if (!success) {
      setState(() {
        _achAccepted = prevAchAccepted;
        _leasePaymentSettings = prevLeasePaymentSettings;
        _isUpdatingAchSetting = false;
      });
      return;
    }

    setState(() {
      _achAcceptedDirty = false;
      _isUpdatingAchSetting = false;
    });
  }
  Widget _buildDataCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: Container(
        height: 50,
        // color: Colors.blue,
        child: TableCell(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child:
                Center(child: Text(text, style: const TextStyle(fontSize: 18))),
          ),
        ),
      ),
    );
  }

  final List<String> leaseTypeitems = [
    'Fixed',
    'Fixed w/rollover',
    'At-will(month to month)',
  ];
  final List<String> rentCycleitems = [
    'Daily',
    'Weekly',
    'Every two weeks',
    'Monthly',
    'Every two months',
    'Quarterly',
    'Yearly',
    'Semi Monthly',
  ];

  DateTime calculateNextDueDate(DateTime startDate, String rentCycle) {
    switch (rentCycle) {
      case 'Daily':
        return startDate.add(const Duration(days: 1));
      case 'Weekly':
        return startDate.add(const Duration(days: 7));
      case 'Every two weeks':
        return startDate.add(const Duration(days: 14));
      case 'Monthly':
        return DateTime(startDate.year, startDate.month + 1, startDate.day);
      case 'Every two months':
        return DateTime(startDate.year, startDate.month + 2, startDate.day);
      case 'Quarterly':
        return DateTime(startDate.year, startDate.month + 3, startDate.day);
      case 'Yearly':
        return DateTime(startDate.year + 1, startDate.month, startDate.day);
      default:
        return startDate;
    }
  }

  void _updateNextDueDate() {
    if (_startDate != null && _selectedRent != null) {
      DateTime nextDueDate = calculateNextDueDate(_startDate!, _selectedRent!);
      String formattedNextDueDate =
          "${nextDueDate.year}-${nextDueDate.month.toString().padLeft(2, '0')}-${nextDueDate.day.toString().padLeft(2, '0')}";

      setState(() {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        rentNextDueDate.text =
            dateProvider.formatCurrentDate(formattedNextDueDate);
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor, // Header background color
            colorScheme: ColorScheme.light(
              primary: blueColor, // Selection color
              onPrimary: Colors.white, // Text color
              surface: Colors.white, // Calendar background color
              onSurface: Colors.black, // Calendar text color
            ),
            dialogBackgroundColor: Colors.white, // Background color
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        startDateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);

        // Auto-set end date to one year later
        DateTime endDate = DateTime(picked.year + 1, picked.month, picked.day);
        _endDate = endDate;
        endDateController.text =
            DateFormat(dateProvider.dateFormat).format(endDate);
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final ClearableDatePickerResult? result = await showClearableDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (result == null) return; // cancelled — keep the current value
    if (result.cleared) {
      setState(() {
        endDateController.clear();
        _endDate = null;
      });
      return;
    }
    final DateTime picked = result.date!;
    if (picked != _endDate) {
      setState(() {
        _endDate = picked;
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        endDateController.text =
            DateFormat(dateProvider.dateFormat).format(picked);
      });
    }
  }

  Future<void> _selectNextDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: blueColor, // Header background color
            colorScheme: ColorScheme.light(
              primary: blueColor, // Selection color
              onPrimary: Colors.white, // Text color
              surface: Colors.white, // Calendar background color
              onSurface: Colors.black, // Calendar text color
            ),
            dialogBackgroundColor: Colors.white, // Background color
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        rentNextDueDate.text =
            DateFormat(dateProvider.dateFormat).format(picked);
      });
    }
  }

  String? selectedValue;

  late TabController _tabController;

  @override
  void dispose() {
    _propertySearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<bool> _validateSignature() async {
    if (isTenantSelected) {
      // Check if the signature pad has any strokes
      final image = await _signaturePadKey.currentState!.toImage();
      final byteData = await image.toByteData();
      final buffer = byteData!.buffer.asUint8List();
      bool isEmpty = buffer.every((byte) => byte == 0);
      return !isEmpty;
    } else {
      // Check if the typed signature is empty
      if (signatureController.text.isEmpty) {
        return false;
      }
    }
    return true;
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate() && await _validateSignature()) {
      // Proceed with submission
    } else {
      // Show validation error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide either a drawn or typed signature.')),
      );
    }
  }

  Map<String, String> _popupFormOneTimeData = {
    'property': '',
    'amount': '',
    'memo': ''
  };

  List<Map<String, dynamic>> formDataOneTimeList = [];

  void _showPopupForm(BuildContext context, String rent,
      {Map<String, dynamic>? initialData, int? index}) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          // title: Text(
          //   'Add One Time Fee',
          //   style: TextStyle(
          //     fontSize: 14,
          //     fontWeight: FontWeight.w500,
          //     color: blueColor,
          //   ),
          // ),
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: OneTimeChargePopUp(
              initialData: initialData,
              onSave: (data) {
                setState(() {
                  data['rent_cycle'] = rent; // Add Rent value to the data map
                  if (index != null) {
                    // Update existing item
                    formDataOneTimeList[index] = data;
                    Fluttertoast.showToast(
                        msg: 'One Time Charge Updated Successfully');
                    Navigator.pop(context);
                  } else {
                    // Add new item
                    formDataOneTimeList.add(data);

                    Fluttertoast.showToast(
                        msg: 'One Time Charge Added Successfully');
                    Navigator.pop(context);
                  }
                });
              },
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        result['rent_cycle'] = rent; // Add Rent value to the result map
        if (index != null) {
          formDataOneTimeList[index] = result;
          Fluttertoast.showToast(msg: 'One Time Charge Updated Successfully');
        } else {
          formDataOneTimeList.add(result);

          Fluttertoast.showToast(msg: 'One Time Charge Added Successfully');
        }
      });
    }
  }

  List<Map<String, String>> formDataRecurringList = [];

  void _showRecurringPopupForm(BuildContext context, String Rent,
      {Map<String, String>? initialData, int? index}) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
          content: Padding(
            padding: const EdgeInsets.all(8.0),
            child: RecurringChargePopUp(
              initialData: initialData,
              onSave: (data) {
                setState(() {
                  if (index != null) {
                    // Update existing item
                    formDataRecurringList[index] = data;
                    Fluttertoast.showToast(
                        msg: 'Recurring Charge Updated Successfully');
                    Navigator.pop(context);
                  } else {
                    // Add new item
                    formDataRecurringList.add(data);

                    Fluttertoast.showToast(
                        msg: 'Recurring Charge Added Successfully');
                    Navigator.pop(context);
                  }
                });
              },
            ),
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        if (index != null) {
          formDataRecurringList[index] = result;
          Fluttertoast.showToast(msg: 'Recurring Charge Updated Successfully');
        } else {
          formDataRecurringList.add(result);

          Fluttertoast.showToast(msg: 'Recurring Charge Added Successfully');
        }
      });
    }
  }

  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      //  allowedExtensions: ['pdf'],
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
          _uploadedFileNames.add(fileName);
        }
      });
    } catch (e) {
      logError('PDF upload failed: $e');
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
      Fluttertoast.showToast(msg: 'PDF added successfully');
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  String renderId = '';
  String unitId = '';
  String? _errorMessage;
  String convertToApiDate(String inputDate, BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    String userFormat =
        dateProvider.dateFormat; // e.g., "MM/dd/yyyy" or "dd/MM/yyyy"

    try {
      DateTime parsedDate = DateFormat(userFormat).parseStrict(inputDate);
      String apiDate = DateFormat("yyyy-MM-dd").format(parsedDate);
      return apiDate;
    } catch (e) {
      logError("Failed to parse date: $inputDate using format: $userFormat");
      return inputDate; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final cosigners = Provider.of<SelectedCosignersProvider>(context).cosigners;
    Map<int, Map<String, String>> cosignersMap =
        cosigners.asMap().map((index, cosigner) {
      return MapEntry(index, {
        'c_id': cosigner.c_id ?? '',
        'firstName': cosigner.firstName,
        'lastName': cosigner.lastName,
        'phoneNumber': cosigner.phoneNumber,
        'workNumber': cosigner.workNumber,
        'email': cosigner.email,
        'alterEmail': cosigner.alterEmail,
        'streetAddress': cosigner.streetAddress,
        'city': cosigner.city,
        'country': cosigner.country,
        'postalCode': cosigner.postalCode,
      });
    });

    final tenants =
        Provider.of<SelectedTenantsProvider>(context).selectedTenants;
    Map<int, Map<String, String>> tenantsMap =
        tenants.asMap().map((index, tenant) {
      return MapEntry(index, {
        'tenantId': tenant.tenantId ?? "",
        'ecArray': (tenant.emergencyContacts != null && tenant.emergencyContacts!.isNotEmpty)
            ? jsonEncode(tenant.emergencyContacts!.map((e) => {'name': e.name ?? '', 'relation': e.relation ?? '', 'email': e.email ?? '', 'phoneNumber': e.phoneNumber ?? ''}).toList())
            : '',
        'enableOverrideFee': tenant.enableoverrideFee != null ? tenant.enableoverrideFee.toString() : '',
        'overrideFee': tenant.overRideFee != null ? tenant.overRideFee.toString() : '',
        'allowAch': tenant.allowAch != null ? tenant.allowAch.toString() : '',
        'allowCard': tenant.allowCard != null ? tenant.allowCard.toString() : '',
        'applicantId': tenant.applicantId ?? "",
        'tenant_residentStatus': tenant.tenant_residentStatus.toString(),
        'firstName': tenant.tenantFirstName ?? "",
        'lastName': tenant.tenantLastName ?? "",
        'passWord': tenant.tenantPassword ?? '',
        if (tenant.rentalUnit != null) 'rental_unit': tenant.rentalUnit!,
        'phoneNumber': tenant.tenantPhoneNumber ?? "",
        'workNumber': tenant.tenantAlternativeNumber ?? "",
        'email': tenant.tenantEmail ?? "",
        'alterEmail': tenant.tenantAlternativeEmail ?? "",
        // 'streetAddress': tenant.rentalAddress ?? "",
        'rental_adress': tenant.rentalAddress ?? '',
        'comments': tenant.comments ?? '',
        'dob': tenant.tenantBirthDate ?? '',
        'taxPayerId': tenant.taxPayerId ?? '',
        'createdAt': tenant.createdAt ?? '',
        'emergencyContactName': tenant.emergencyContact?.name ?? '',
        'emergencyRelation': tenant.emergencyContact?.relation ?? '',
        'emergencyEmail': tenant.emergencyContact?.email ?? '',
        'emergencyPhoneNumber': tenant.emergencyContact?.phoneNumber ?? '',
        'city': '', // Add city if available
        'country': '', // Add country if available
        'postalCode': '', // Add postal code if available
      });
    });

    var selectedTenantsProvider =
        Provider.of<SelectedTenantsProvider>(context, listen: false);
    // var selectedCosignerProvider =
    // Provider.of<SelectedCosignersProvider>(context, listen: false);
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Leases",
        dropdown: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 10,
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Container(
                    height: 50.0,
                    padding: const EdgeInsets.only(top: 14, left: 10),
                    width: MediaQuery.of(context).size.width * .91,
                    margin: const EdgeInsets.only(bottom: 6.0),
                    //Same as `blurRadius` i guess
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5.0),
                      color: blueColor,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(0.0, 1.0), //(x,y)
                          blurRadius: 6.0,
                        ),
                      ],
                    ),
                    child: const Text(
                      "Edit Lease",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                    left: MediaQuery.of(context).size.width < 500 ? 15 : 35,
                    right: MediaQuery.of(context).size.width < 500 ? 15 : 35),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(TextSpan(text: 'Property ', style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                              const SizedBox(
                                height: 4,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FormField<String>(
                                    //initialValue: _selectedProperty,
                                    validator: (value) {
                                      if (_selectedProperty == null) {
                                        return 'Please select an option';
                                      }
                                      return null;
                                    },
                                    builder: (FormFieldState<String> state) {
                                      final propertyItems =
                                          _propertyDropdownItems();
                                      String? propertyValue;
                                      final selNorm =
                                          _selectedProperty?.trim();
                                      if (selNorm != null &&
                                          selNorm.isNotEmpty) {
                                        for (final p in propertyItems) {
                                          if ((p['rental_id'] ?? '')
                                                  .toString()
                                                  .trim() ==
                                              selNorm) {
                                            propertyValue = p['rental_id'];
                                            break;
                                          }
                                        }
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DropdownButtonHideUnderline(
                                            child: DropdownButtonFormField2<
                                                String>(
                                              decoration: const InputDecoration(
                                                isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0), border: InputBorder.none,
                                              ),
                                              isExpanded: true,
                                              hint: const Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Select Property',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color:
                                                            Color(0xFFb0b6c3),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              items: () {
                                                final seen = <String>{};
                                                return propertyItems
                                                    .where((p) => seen.add(p['rental_id'] ?? ''))
                                                    .map((property) => DropdownMenuItem<String>(
                                                          value: property['rental_id'],
                                                          child: Text(
                                                            property['rental_adress']!,
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w400,
                                                              color: Color(0xFF152B51),
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ))
                                                    .toList();
                                              }(),
                                              value: propertyValue,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedProperty = value;
                                                  _selectedUnit = null;
                                                  _showUnitDropdown = false;
                                                  state.didChange(value);
                                                  renderId = value.toString();
                                                  _loadUnits(value!);
                                                });
                                              },
                                              buttonStyleData: ButtonStyleData(
                                                height: 50,
                                                width: 160,
                                                padding: const EdgeInsets.only(
                                                    left: 14, right: 14),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  color: Colors.white,
                                                  border: Border.all(color: const Color(0xFFCED4DA)),
                                                ),
                                                elevation: 0,
                                              ),
                                              iconStyleData:
                                                  const IconStyleData(
                                                icon: Icon(
                                                  Icons.arrow_drop_down,
                                                ),
                                                iconSize: 24,
                                                iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                iconDisabledColor: Colors.grey,
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 300,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  color: Colors.white,
                                                ),
                                                scrollbarTheme:
                                                    ScrollbarThemeData(
                                                  radius:
                                                      const Radius.circular(6),
                                                  thickness:
                                                      MaterialStateProperty.all(
                                                          6),
                                                  thumbVisibility:
                                                      MaterialStateProperty.all(
                                                          true),
                                                ),
                                              ),
                                              menuItemStyleData:
                                                  const MenuItemStyleData(
                                                height: 40,
                                                padding: EdgeInsets.only(
                                                    left: 14, right: 14),
                                              ),
                                              dropdownSearchData: DropdownSearchData(
                                                searchController: _propertySearchController,
                                                searchInnerWidgetHeight: 60,
                                                searchInnerWidget: Padding(
                                                  padding: const EdgeInsets.only(
                                                      top: 8, bottom: 4, left: 8, right: 8),
                                                  child: TextFormField(
                                                    controller: _propertySearchController,
                                                    maxLines: 1,
                                                    cursorColor: blueColor,
                                                    style: const TextStyle(
                                                        fontSize: 14, color: Colors.black),
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      contentPadding: const EdgeInsets.symmetric(
                                                          horizontal: 10, vertical: 10),
                                                      hintText: 'Search property',
                                                      hintStyle: const TextStyle(
                                                          fontSize: 13, color: Color(0xFFb0b6c3)),
                                                      prefixIcon: const Icon(Icons.search, size: 20),
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                // Match on the address shown in the row, so typing any part of
                                                // it narrows the list.
                                                searchMatchFn: (item, searchValue) {
                                                  final Widget child = item.child;
                                                  final String address =
                                                      child is Text ? (child.data ?? '') : '';
                                                  return address
                                                      .toLowerCase()
                                                      .contains(searchValue.toLowerCase().trim());
                                                },
                                              ),
                                              // Leave the field clean for the next open.
                                              onMenuStateChange: (isOpen) {
                                                if (!isOpen) {
                                                  _propertySearchController.clear();
                                                }
                                              },
                                            ),
                                          ),
                                          if (state.hasError)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 14, top: 8),
                                              child: Text(
                                                state.errorText!,
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (units.isNotEmpty &&
                                      units.any((unit) =>
                                          (unit['rental_unit'] ?? '')
                                              .trim()
                                              .isNotEmpty))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 5.0),
                                      child: Text(
                                        'Unit',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  if (units.isNotEmpty &&
                                      units.any((unit) =>
                                          (unit['rental_unit'] ?? '')
                                              .trim()
                                              .isNotEmpty))
                                    FormField<String>(
                                      // initialValue: _selectedUnit,
                                      validator: (value) {
                                        if (_selectedUnit == null) {
                                          return 'Please select a unit';
                                        }
                                        return null;
                                      },
                                      builder: (FormFieldState<String> state) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            DropdownButtonHideUnderline(
                                              child: DropdownButtonFormField2<
                                                  String>(
                                                decoration:
                                                    const InputDecoration(
                                                  isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0), border: InputBorder.none,
                                                ),
                                                isExpanded: true,
                                                hint: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Select Unit',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Color(0xFFb0b6c3),
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                items: units
                                                    .map((unit) {
                                                      String? unitName =
                                                          unit['rental_unit']
                                                              ?.trim();
                                                      if (unitName
                                                              ?.isNotEmpty !=
                                                          true) return null;

                                                      return DropdownMenuItem<
                                                          String>(
                                                        value: unit['unit_id']!,
                                                        child: Text(
                                                          unitName!,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color:
                                                                Color(0xFF152B51),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      );
                                                    })
                                                    .whereType<
                                                        DropdownMenuItem<
                                                            String>>()
                                                    .toList(),
                                                value: _selectedUnit != null &&
                                                        _selectedUnit!
                                                            .isNotEmpty &&
                                                        units.any((unit) =>
                                                            unit['unit_id'] ==
                                                            _selectedUnit)
                                                    ? _selectedUnit
                                                    : null,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _selectedUnit = value;
                                                    state.didChange(value);
                                                  });
                                                  state.reset();
                                                },
                                                buttonStyleData:
                                                    ButtonStyleData(
                                                  height: 50,
                                                  width: 160,
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 14, right: 14),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                    border: Border.all(color: const Color(0xFFCED4DA)),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                iconStyleData:
                                                    const IconStyleData(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  iconSize: 24,
                                                  iconEnabledColor:
                                                      Color(0xFFb0b6c3),
                                                  iconDisabledColor:
                                                      Colors.grey,
                                                ),
                                                dropdownStyleData:
                                                    DropdownStyleData(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                    color: Colors.white,
                                                  ),
                                                  scrollbarTheme:
                                                      ScrollbarThemeData(
                                                    radius:
                                                        const Radius.circular(
                                                            6),
                                                    thickness:
                                                        MaterialStateProperty
                                                            .all(6),
                                                    thumbVisibility:
                                                        MaterialStateProperty
                                                            .all(true),
                                                  ),
                                                ),
                                                menuItemStyleData:
                                                    const MenuItemStyleData(
                                                  height: 40,
                                                  padding: EdgeInsets.only(
                                                      left: 14, right: 14),
                                                ),
                                              ),
                                            ),
                                            if (state.hasError)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 14, top: 8),
                                                child: Text(
                                                  state.errorText!,
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              Text.rich(TextSpan(text: 'Lease Type ', style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                              const SizedBox(
                                height: 8,
                              ),
                              FormField<String>(
                                initialValue: _selectedLeaseType,
                                builder: (FormFieldState<String> state) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton2<String>(
                                          isExpanded: true,
                                          hint: const Row(
                                            children: [
                                              SizedBox(
                                                width: 4,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Type',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF152B51),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          items: () {
                                            final seen = <String>{};
                                            final items = <DropdownMenuItem<String>>[];
                                            for (final item in leaseTypeitems) {
                                              if (seen.add(item)) {
                                                items.add(DropdownMenuItem<String>(
                                                  value: item,
                                                  child: Text(
                                                    item,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFF152B51),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ));
                                              }
                                            }
                                            final custom = _selectedLeaseType;
                                            if (custom != null &&
                                                custom.isNotEmpty &&
                                                seen.add(custom)) {
                                              items.add(DropdownMenuItem<String>(
                                                value: custom,
                                                child: Text(
                                                  custom,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF152B51),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ));
                                            }
                                            return items;
                                          }(),
                                          value: (_selectedLeaseType == null ||
                                                  _selectedLeaseType!.isEmpty)
                                              ? null
                                              : _selectedLeaseType,
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedLeaseType = value;
                                              state.didChange(value);
                                            });
                                          },
                                          buttonStyleData: ButtonStyleData(
                                            height: 50,
                                            padding: const EdgeInsets.only(
                                                left: 14, right: 14),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Color(0xFFCED4DA),
                                              ),
                                              color: Colors.white,
                                            ),
                                            elevation: 0,
                                          ),
                                          dropdownStyleData: DropdownStyleData(
                                            maxHeight: 200,
                                            width: 200,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            offset: const Offset(-20, 0),
                                            scrollbarTheme: ScrollbarThemeData(
                                              radius: const Radius.circular(40),
                                              thickness:
                                                  MaterialStateProperty.all(6),
                                              thumbVisibility:
                                                  MaterialStateProperty.all(
                                                      true),
                                            ),
                                          ),
                                          menuItemStyleData:
                                              const MenuItemStyleData(
                                            height: 40,
                                            padding: EdgeInsets.only(
                                                left: 14, right: 14),
                                          ),
                                        ),
                                      ),
                                      if (state.hasError)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 14, top: 8),
                                          child: Text(
                                            state.errorText!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                                validator: (value) {
                                  if (_selectedLeaseType == null) {
                                    return 'Please select a lease type';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              if (MediaQuery.of(context).size.width < 500)
                                Text.rich(TextSpan(text: 'Start Date ', style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                              if (MediaQuery.of(context).size.width < 500)
                                const SizedBox(
                                  height: 8,
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                  onTap: () {
                                    _selectStartDate(context);
                                  },
                                  readOnnly: true,
                                  suffixIcon: IconButton(
                                      onPressed: () {
                                        _selectStartDate(context);
                                      },
                                      icon:
                                          const Icon(Icons.date_range_rounded)),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select start date';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.text,
                                  hintText: Provider.of<DateProvider>(context,
                                          listen: false)
                                      .dateFormat
                                      .toUpperCase(),
                                  controller: startDateController,
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                const SizedBox(
                                  height: 8,
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                Text.rich(TextSpan(text: 'End Date ', style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                              if (MediaQuery.of(context).size.width < 500)
                                const SizedBox(
                                  height: 8,
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                  onTap: () async {
                                    final ClearableDatePickerResult? result =
                                        await showClearableDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(2101),
                                    );
                                    if (result == null) return;
                                    if (result.cleared) {
                                      setState(() {
                                        endDateController.clear();
                                        _endDate = null;
                                      });
                                      return;
                                    }
                                    final DateTime pickedDate = result.date!;
                                    // String formattedDate =
                                    //     "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                                    String formattedDate =
                                        "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                                    setState(() {
                                      endDateController.text = formattedDate;
                                    });
                                  },
                                  readOnnly: true,
                                  suffixIcon: ClearableDateSuffix(
                                      controller: endDateController,
                                      icon: Icons.date_range_rounded,
                                      iconSize: 24,
                                      onClear: () {
                                        setState(() {
                                          endDateController.clear();
                                          _endDate = null;
                                        });
                                      },
                                      onPick: () async {
                                        final ClearableDatePickerResult?
                                            result =
                                            await showClearableDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2101),
                                        );
                                        if (result == null) return;
                                        if (result.cleared) {
                                          setState(() {
                                            endDateController.clear();
                                            _endDate = null;
                                          });
                                          return;
                                        }
                                        final DateTime pickedDate =
                                            result.date!;
                                        // String formattedDate =
                                        //     "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                                        String formattedDate =
                                            "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                                        setState(() {
                                          endDateController.text =
                                              formattedDate;
                                        });
                                      }),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select end date';
                                    }
                                    return null;
                                  },
                                  optional: true,
                                  keyboardType: TextInputType.text,
                                  hintText: Provider.of<DateProvider>(context,
                                          listen: false)
                                      .dateFormat
                                      .toUpperCase(),
                                  controller: endDateController,
                                ),
                              if (MediaQuery.of(context).size.width > 500)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // First Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(TextSpan(text: 'Start Date ', style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                                            const SizedBox(height: 5),
                                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                              onTap: () {
                                                _selectStartDate(context);
                                              },
                                              readOnnly: true,
                                              suffixIcon: IconButton(
                                                onPressed: () {
                                                  _selectStartDate(context);
                                                },
                                                icon: const Icon(
                                                    Icons.date_range_rounded),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please select start date';
                                                }
                                                return null;
                                              },
                                              keyboardType: TextInputType.text,
                                              hintText:
                                                  Provider.of<DateProvider>(
                                                          context,
                                                          listen: false)
                                                      .dateFormat
                                                      .toUpperCase(),
                                              controller: startDateController,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Second Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(TextSpan(text: 'End Date ', style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                                            const SizedBox(height: 5),
                                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                              onTap: () {
                                                _selectEndDate(context);
                                              },
                                              readOnnly: true,
                                              optional: true,
                                              suffixIcon: ClearableDateSuffix(
                                                controller: endDateController,
                                                icon:
                                                    Icons.date_range_rounded,
                                                iconSize: 24,
                                                onPick: () {
                                                  _selectEndDate(context);
                                                },
                                                onClear: () {
                                                  setState(() {
                                                    endDateController.clear();
                                                    _endDate = null;
                                                  });
                                                },
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please select end date';
                                                }
                                                return null;
                                              },
                                              keyboardType: TextInputType.text,
                                              hintText:
                                                  Provider.of<DateProvider>(
                                                          context,
                                                          listen: false)
                                                      .dateFormat
                                                      .toUpperCase(),
                                              controller: endDateController,
                                            ),
                                            const SizedBox(height: 5),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      //add lease
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              RichText(
                                text: const TextSpan(
                                  text: 'Add Tenant ',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF152B51)),
                                  children: [
                                    TextSpan(
                                      text: '*',
                                      style:
                                          TextStyle(color: Color(0xFFDC3545)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              FormField<String>(
                                builder: (FormFieldState<String> state) {
                                  return InkWell(
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const AddTenantCosignerScreen(isStaff: true),
                                        ),
                                      );
                                      if (mounted) setState(() {});
                                    },
                                    child: const Text(
                                      '+ Add Tenant or Cosigner',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2ec433),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              const SizedBox(height: 8.0),
                              if (Provider.of<SelectedTenantsProvider>(context)
                                  .selectedTenants
                                  .isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 13),
                                  child: Text(
                                    'Tenants :',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              if (Provider.of<SelectedTenantsProvider>(context)
                                  .selectedTenants
                                  .isNotEmpty)
                                const SizedBox(
                                  height: 10,
                                ),
                              if (Provider.of<SelectedTenantsProvider>(context)
                                  .selectedTenants
                                  .isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 4, right: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: const Color(0xFFE4E8EF)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Header row: Tenant | Action
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 14),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEAF1FB),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(12),
                                                  topRight: Radius.circular(12),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: const [
                                                  Text('Tenant',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF152B51))),
                                                  Text('Action',
                                                      style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF152B51))),
                                                ],
                                              ),
                                            ),
                                            ...Provider.of<
                                                        SelectedTenantsProvider>(
                                                    context)
                                                .selectedTenants
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              final int index = entry.key;
                                              final tenant = entry.value;
                                              final bool isLast = index ==
                                                  Provider.of<SelectedTenantsProvider>(
                                                              context)
                                                          .selectedTenants
                                                          .length -
                                                      1;
                                              final String phoneDisplay = (tenant
                                                              .tenantPhoneNumber ==
                                                          null ||
                                                      tenant.tenantPhoneNumber!
                                                          .trim()
                                                          .isEmpty ||
                                                      tenant.tenantPhoneNumber ==
                                                          'null')
                                                  ? '-'
                                                  : tenant.tenantPhoneNumber!;
                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 14),
                                                decoration: BoxDecoration(
                                                  border: isLast
                                                      ? null
                                                      : const Border(
                                                          bottom: BorderSide(
                                                              color: Color(
                                                                  0xFFEAEEF4)),
                                                        ),
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '${tenant.tenantFirstName ?? ''} ${tenant.tenantLastName ?? ''}'
                                                                .trim(),
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF3D6FE1),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                  Icons.phone,
                                                                  size: 15,
                                                                  color: Color(
                                                                      0xFF6B7A90)),
                                                              const SizedBox(
                                                                  width: 6),
                                                              Text(
                                                                phoneDisplay,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color: Color(
                                                                      0xFF6B7A90),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () {
                                                        Provider.of<SelectedTenantsProvider>(
                                                                context,
                                                                listen: false)
                                                            .removeTenant(
                                                                tenant);
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                                9),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                              0xFFFDECE7),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        child: const Icon(
                                                            Icons.delete_outline,
                                                            size: 20,
                                                            color: Color(
                                                                0xFFE0573C)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (Provider.of<SelectedTenantsProvider>(context)
                                  .selectedTenants
                                  .isNotEmpty)
                                Column(
                                  children: [
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Consumer<SelectedTenantsProvider>(
                                      builder: (context,
                                          selectedTenantsProvider, child) {
                                        return selectedTenantsProvider
                                                    .validationMessage !=
                                                null
                                            ? Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 5),
                                                child: Text(
                                                  selectedTenantsProvider
                                                      .validationMessage!,
                                                  style: const TextStyle(
                                                      color: Colors.red,
                                                      fontSize: 16),
                                                ),
                                              )
                                            : const SizedBox.shrink();
                                      },
                                    ),
                                  ],
                                ),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 8.0),
                              if (Provider.of<SelectedCosignersProvider>(
                                      context)
                                  .cosigners
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 4, bottom: 12),
                                  child: Row(
                                    children: [
                                      const Text(
                                        'Cosigners ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF152B51),
                                        ),
                                      ),
                                      Text(
                                        '(${Provider.of<SelectedCosignersProvider>(context).cosigners.length})',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A1B4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ...Provider.of<SelectedCosignersProvider>(context)
                                  .cosigners
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                int index = entry.key;
                                Cosigner cosigner = entry.value;
                                String assignedTenant = '—';
                                final tenantsList = Provider.of<
                                            SelectedTenantsProvider>(context)
                                    .selectedTenants;
                                if (cosigner.tenantId != null &&
                                    cosigner.tenantId!.isNotEmpty) {
                                  final match = tenantsList.where((t) =>
                                      t.tenantId != null &&
                                      t.tenantId == cosigner.tenantId);
                                  if (match.isNotEmpty) {
                                    assignedTenant =
                                        '${match.first.tenantFirstName ?? ''} ${match.first.tenantLastName ?? ''}'
                                            .trim();
                                  }
                                }
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFE4E8EF)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F0FB),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${cosigner.firstName} ${cosigner.lastName}',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF152B51),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      isTenantSelected == true;
                                                      tenent_popup(
                                                          cosigner, index);
                                                    });
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(7),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE7F7EE),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Icon(
                                                        Icons.edit_outlined,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF1F9D55)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                InkWell(
                                                  onTap: () {
                                                    Provider.of<SelectedCosignersProvider>(
                                                            context,
                                                            listen: false)
                                                        .removeConsigner(
                                                            cosigner);
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(7),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFFDECE7),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                    child: const Icon(
                                                        Icons.delete_outline,
                                                        size: 18,
                                                        color:
                                                            Color(0xFFE0573C)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        child: Column(
                                          children: [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text('Phone',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color(
                                                              0xFF6B7A90))),
                                                  Text(
                                                      '${cosigner.phoneNumber}',
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF152B51))),
                                                ],
                                              ),
                                            ),
                                            const Divider(
                                                height: 1,
                                                color: Color(0xFFEAEEF4)),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text('Assigned Tenant',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color(
                                                              0xFF6B7A90))),
                                                  Text(assignedTenant,
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF152B51))),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      //rent
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Rent',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              if (MediaQuery.of(context).size.width > 500)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 2.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      // First Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text.rich(TextSpan(text: 'Rent Cycle ', style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                                            const SizedBox(height: 5),
                                            FormField<String>(
                                              initialValue: _selectedRent,
                                              builder: (FormFieldState<String>
                                                  state) {
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    DropdownButtonHideUnderline(
                                                      child: DropdownButton2<
                                                          String>(
                                                        isExpanded: true,
                                                        hint: const Row(
                                                          children: [
                                                            SizedBox(
                                                              width: 4,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                'Rent Cycle',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight.w400,
                                                                  color: Color(0xFF152B51),
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        items: rentCycleitems
                                                            .map(
                                                              (String item) =>
                                                                  DropdownMenuItem<
                                                                      String>(
                                                                value: item,
                                                                child: Text(
                                                                  item,
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight.w400,
                                                                    color: Color(0xFF152B51),
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            )
                                                            .toList(),
                                                        value: _selectedRent,
                                                        onChanged: (value) {
                                                          state.didChange(
                                                              value); // Update the FormField state
                                                          setState(() {
                                                            _selectedRent =
                                                                value;
                                                            state.didChange(
                                                                value);
                                                          });
                                                          state.reset();
                                                        },
                                                        buttonStyleData:
                                                            ButtonStyleData(
                                                          height: 50,
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 0,
                                                                  right: 14),
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .black26,
                                                            ),
                                                            color: Colors.white,
                                                          ),
                                                          elevation: 0,
                                                        ),
                                                        dropdownStyleData:
                                                            DropdownStyleData(
                                                          maxHeight: 200,
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        14),
                                                          ),
                                                          offset: const Offset(
                                                              -20, 0),
                                                          scrollbarTheme:
                                                              ScrollbarThemeData(
                                                            radius: const Radius
                                                                .circular(40),
                                                            thickness:
                                                                MaterialStateProperty
                                                                    .all(6),
                                                            thumbVisibility:
                                                                MaterialStateProperty
                                                                    .all(true),
                                                          ),
                                                        ),
                                                        menuItemStyleData:
                                                            const MenuItemStyleData(
                                                          height: 40,
                                                          padding:
                                                              EdgeInsets.only(
                                                                  left: 14,
                                                                  right: 14),
                                                        ),
                                                      ),
                                                    ),
                                                    if (state.hasError)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 14,
                                                                top: 8),
                                                        child: Text(
                                                          state.errorText!,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.red,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                              validator: (value) {
                                                if (_selectedRent == null) {
                                                  return 'Please select a rent cycle';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 5),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Second Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('Next Due Date',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey)),
                                            const SizedBox(height: 5),
                                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                              onTap: () {
                                                _selectNextDueDate(context);
                                              },
                                              optional: true,
                                              readOnnly: true,
                                              suffixIcon: IconButton(
                                                onPressed: () {
                                                  _selectNextDueDate(context);
                                                },
                                                icon: const Icon(
                                                    Icons.date_range_rounded),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Please select Next Due Date';
                                                }
                                                return null;
                                              },
                                              keyboardType: TextInputType.text,
                                              hintText:
                                                  Provider.of<DateProvider>(
                                                          context,
                                                          listen: false)
                                                      .dateFormat
                                                      .toUpperCase(),
                                              controller: rentNextDueDate,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                Text.rich(TextSpan(text: 'Rent Cycle ', style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                              if (MediaQuery.of(context).size.width < 500)
                                const SizedBox(
                                  height: 8,
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                FormField<String>(
                                  initialValue: _selectedRent,
                                  builder: (FormFieldState<String> state) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        DropdownButtonHideUnderline(
                                          child: DropdownButton2<String>(
                                            isExpanded: true,
                                            hint: const Row(
                                              children: [
                                                SizedBox(
                                                  width: 4,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Rent Cycle',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: Color(0xFF152B51),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            items: rentCycleitems
                                                .map(
                                                  (String item) =>
                                                      DropdownMenuItem<String>(
                                                    value: item,
                                                    child: Text(
                                                      item,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: Color(0xFF152B51),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            value: rentCycleitems
                                                    .contains(_selectedRent)
                                                ? _selectedRent
                                                : null,
                                            onChanged: (value) {
                                              state.didChange(
                                                  value); // Update the FormField state
                                              setState(() {
                                                _selectedRent = value;
                                                state.didChange(value);
                                              });
                                              state.reset();
                                            },
                                            buttonStyleData: ButtonStyleData(
                                              height: 50,
                                              padding: const EdgeInsets.only(
                                                  left: 0, right: 14),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Color(0xFFCED4DA),
                                                ),
                                                color: Colors.white,
                                              ),
                                              elevation: 0,
                                            ),
                                            dropdownStyleData:
                                                DropdownStyleData(
                                              maxHeight: 200,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              offset: const Offset(-20, 0),
                                              scrollbarTheme:
                                                  ScrollbarThemeData(
                                                radius:
                                                    const Radius.circular(40),
                                                thickness:
                                                    MaterialStateProperty.all(
                                                        6),
                                                thumbVisibility:
                                                    MaterialStateProperty.all(
                                                        true),
                                              ),
                                            ),
                                            menuItemStyleData:
                                                const MenuItemStyleData(
                                              height: 40,
                                              padding: EdgeInsets.only(
                                                  left: 14, right: 14),
                                            ),
                                          ),
                                        ),
                                        if (state.hasError)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                left: 14, top: 8),
                                            child: Text(
                                              state.errorText!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                  validator: (value) {
                                    if (_selectedRent == null) {
                                      return 'Please select a rent cycle';
                                    }
                                    return null;
                                  },
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                const SizedBox(
                                  height: 8,
                                ),
                              Text.rich(TextSpan(text: 'Amount ', style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                              const SizedBox(
                                height: 8,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter amount';
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.number,
                                hintText: 'Enter Amount',
                                controller: rentAmount,
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              if (MediaQuery.of(context).size.width < 500)
                                const Text('Next Due Date',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                              if (MediaQuery.of(context).size.width < 500)
                                const SizedBox(
                                  height: 8,
                                ),
                              if (MediaQuery.of(context).size.width < 500)
                                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                  onTap: () {
                                    _selectNextDueDate(context);
                                  },
                                  optional: true,
                                  readOnnly: true,
                                  suffixIcon: IconButton(
                                      onPressed: () {
                                        _selectNextDueDate(context);
                                      },
                                      icon:
                                          const Icon(Icons.date_range_rounded)),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select Next Due Date';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.text,
                                  hintText: Provider.of<DateProvider>(context,
                                          listen: false)
                                      .dateFormat
                                      .toUpperCase(),
                                  controller: rentNextDueDate,
                                ),
                              const SizedBox(
                                height: 8,
                              ),
                              const Text('Memo',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(
                                height: 8,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter memo';
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.text,
                                hintText: 'Enter Memo',
                                controller: rentMemo,
                                optional: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      //charges
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text(
                                'Fees (Optional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: blueColor,
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              const Text(
                                'Add Fees',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (MediaQuery.of(context).size.width < 500)
                                    InkWell(
                                      onTap: () {
                                        _showRecurringPopupForm(
                                            context, _selectedRent.toString());
                                      },
                                      child: const Text(
                                        ' + Add Recurring Fee',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2ec433),
                                        ),
                                      ),
                                    ),
                                  if (MediaQuery.of(context).size.width < 500)
                                    const SizedBox(
                                      height: 20,
                                    ),
                                  if (MediaQuery.of(context).size.width < 500)
                                    InkWell(
                                      onTap: () {
                                        _showPopupForm(
                                            context, _selectedRent.toString());
                                      },
                                      child: const Text(
                                        ' + Add One Time Fee',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2ec433),
                                        ),
                                      ),
                                    ),
                                  if (MediaQuery.of(context).size.width > 500)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // First Column
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    _showRecurringPopupForm(
                                                        context,
                                                        _selectedRent
                                                            .toString());
                                                  },
                                                  child: const Text(
                                                    ' + Add Recurring Fee',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF2ec433),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Second Column
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                InkWell(
                                                  onTap: () {
                                                    _showPopupForm(
                                                        context,
                                                        _selectedRent
                                                            .toString());
                                                  },
                                                  child: const Text(
                                                    ' + Add One Time Fee',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF2ec433),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (formDataRecurringList.isNotEmpty)
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  if (formDataRecurringList.isNotEmpty)
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  if (formDataRecurringList.isNotEmpty)
                                    Text(
                                      'Recurring Information',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                      ),
                                    ),
                                  if (formDataRecurringList.isNotEmpty)
                                    const SizedBox(
                                      height: 5,
                                    ),
                                  if (formDataRecurringList.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFE4E8EF)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEAF1FB),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                topRight: Radius.circular(12),
                                              ),
                                            ),
                                            child: Row(
                                              children: const [
                                                Expanded(
                                                    flex: 2,
                                                    child: Text('Account',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF152B51)))),
                                                Expanded(
                                                    flex: 2,
                                                    child: Text('Amount',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF152B51)))),
                                                SizedBox(
                                                    width: 74,
                                                    child: Text('Actions',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF152B51)))),
                                              ],
                                            ),
                                          ),
                                          ...formDataRecurringList
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int index = entry.key;
                                            var item = entry.value;
                                            final bool isLast = index ==
                                                formDataRecurringList.length -
                                                    1;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12),
                                              decoration: BoxDecoration(
                                                border: isLast
                                                    ? null
                                                    : const Border(
                                                        bottom: BorderSide(
                                                            color: Color(
                                                                0xFFEAEEF4)),
                                                      ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                          '${item['account']}',
                                                          style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF3D6FE1)))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                          '${item['amount']}',
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                  0xFF6B7A90)))),
                                                  SizedBox(
                                                    width: 74,
                                                    child: Row(
                                                      children: [
                                                        InkWell(
                                                          onTap: () {
                                                            _showRecurringPopupForm(
                                                                context,
                                                                _selectedRent
                                                                    .toString(),
                                                                initialData:
                                                                    item,
                                                                index: index);
                                                          },
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(7),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFFE7F7EE),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 18,
                                                                color: Color(
                                                                    0xFF1F9D55)),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              formDataRecurringList
                                                                  .removeAt(
                                                                      index);
                                                            });
                                                          },
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(7),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFFFDECE7),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color: Color(
                                                                    0xFFE0573C)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  if (formDataOneTimeList.isNotEmpty)
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  if (formDataOneTimeList.isNotEmpty)
                                    const SizedBox(
                                      height: 5,
                                    ),
                                  if (formDataOneTimeList.isNotEmpty)
                                    Text(
                                      'One Time Information',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                      ),
                                    ),
                                  if (formDataOneTimeList.isNotEmpty)
                                    const SizedBox(
                                      height: 5,
                                    ),
                                  if (formDataOneTimeList.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFE4E8EF)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEAF1FB),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                topRight: Radius.circular(12),
                                              ),
                                            ),
                                            child: Row(
                                              children: const [
                                                Expanded(
                                                    flex: 2,
                                                    child: Text('Account',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF152B51)))),
                                                Expanded(
                                                    flex: 2,
                                                    child: Text('Amount',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF152B51)))),
                                                SizedBox(
                                                    width: 74,
                                                    child: Text('Actions',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: Color(
                                                                0xFF152B51)))),
                                              ],
                                            ),
                                          ),
                                          ...formDataOneTimeList
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int index = entry.key;
                                            var item = entry.value;
                                            final bool isLast = index ==
                                                formDataOneTimeList.length -
                                                    1;
                                            return Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12),
                                              decoration: BoxDecoration(
                                                border: isLast
                                                    ? null
                                                    : const Border(
                                                        bottom: BorderSide(
                                                            color: Color(
                                                                0xFFEAEEF4)),
                                                      ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                          '${item['account']}',
                                                          style: const TextStyle(
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: Color(
                                                                  0xFF3D6FE1)))),
                                                  Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                          '${item['amount']}',
                                                          style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Color(
                                                                  0xFF6B7A90)))),
                                                  SizedBox(
                                                    width: 74,
                                                    child: Row(
                                                      children: [
                                                        InkWell(
                                                          onTap: () {
                                                            _showPopupForm(
                                                                context,
                                                                _selectedRent
                                                                    .toString(),
                                                                initialData:
                                                                    item,
                                                                index: index);
                                                          },
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(7),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFFE7F7EE),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: const Icon(
                                                                Icons
                                                                    .edit_outlined,
                                                                size: 18,
                                                                color: Color(
                                                                    0xFF1F9D55)),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        InkWell(
                                                          onTap: () {
                                                            setState(() {
                                                              formDataOneTimeList
                                                                  .removeAt(
                                                                      index);
                                                            });
                                                          },
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(7),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFFFDECE7),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                                size: 18,
                                                                color: Color(
                                                                    0xFFE0573C)),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Security Deposit',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              RichText(
                                text: const TextSpan(
                                  text: 'Amount ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey),
                                  children: [
                                    TextSpan(
                                      text: '*',
                                      style: TextStyle(color: Color(0xFFDC3545)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter amount';
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.number,
                                hintText: 'Enter amount here',
                                controller: securityDepositeAmount,
                                optional: true,
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 6.0),
                                child: Text(
                                    'Enter 0 if no security deposit is required.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF748097))),
                              ),
                              const SizedBox(
                                height: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                     // lease payment setting — commented out to match web (achAccepted pre-fill + payload kept below)
                      /*
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Lease Payment Settings',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: blueColor)),
                              //     .toList(),
                              const SizedBox(height: 5),
                              Text(
                                  "When enabled, these payment settings will override the rental owner's payment settings for this specific lease.  If disabled, the lease will automatically apply the rental owner's default payment settings.",
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w300,
                                      color: Color(0xFF748097))),
                    
                              const SizedBox(
                                height: 10,
                              ),
                              if (!_paymentSettingsLoaded)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.0),
                                  child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Checkbox(
                                      activeColor: blueColor,
                                      value: !_achAccepted, // UI is "Disable ACH"
                                      onChanged: _isUpdatingAchSetting
                                          ? null
                                          : (newValue) async {
                                              final disableAch =
                                                  newValue ?? false;
                                              final nextAchAccepted = !disableAch;
                    
                                              // If currently disabled and user wants to re-enable, confirm first.
                                              if (_achAccepted == false &&
                                                  nextAchAccepted == true) {
                                                final ok =
                                                    await _confirmReenableAch();
                                                if (!ok) return;
                                              }
                    
                                              setState(() {
                                                _achAcceptedDirty = true;
                                              });
                                              await _updateAchSetting(
                                                  achAccepted: nextAchAccepted);
                                            },
                                    ),
                                    Text('Disable ACH',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor)),
                                  ],
                                ),
                    
                              // Row(
                              //   children: [
                              //     Checkbox(
                              //       activeColor: blueColor,
                              //       value: _leasePaymentSettings,
                              //       onChanged: (newValue) {
                              //         setState(() {
                              //           _leasePaymentSettings =
                              //               newValue ?? false;
                              //           if (!_leasePaymentSettings) {
                              //             _creditCardAccepted = false;
                              //             _debitCardAccepted = false;
                              //           }
                              //         });
                              //       },
                              //     ),
                              //     Text('Enable Lease Payment Settings',
                              //         style: TextStyle(
                              //             fontSize: 14,
                              //             fontWeight: FontWeight.w500,
                              //             color: blueColor)),
                              //   ],
                              // ),
                              // if (_leasePaymentSettings) ...[
                              //   const SizedBox(
                              //     height: 5,
                              //   ),
                              //   Row(
                              //     children: [
                              //       Checkbox(
                              //         activeColor: blueColor,
                              //         value: _creditCardAccepted,
                              //         onChanged: (bool? value) {
                              //           setState(() {
                              //             _creditCardAccepted = value ?? false;
                              //           });
                              //         },
                              //       ),
                              //       const Text('Accepted Credit Card',
                              //           style: TextStyle(
                              //               fontSize: 14,
                              //               fontWeight: FontWeight.w500,
                              //               color: Color(0xFF748097))),
                              //     ],
                              //   ),
                              //   Row(
                              //     children: [
                              //       Checkbox(
                              //         activeColor: blueColor,
                              //         value: _debitCardAccepted,
                              //         onChanged: (bool? value) {
                              //           setState(() {
                              //             _debitCardAccepted = value ?? false;
                              //           });
                              //         },
                              //       ),
                              //       const Text('Accepted Debit Card',
                              //           style: TextStyle(
                              //               fontSize: 14,
                              //               fontWeight: FontWeight.w500,
                              //               color: Color(0xFF748097))),
                              //     ],
                              //   ),
                              // ],
                    
                    
                            ],
                          ),
                        ),
                      ),
                      */
                    const SizedBox(height: 10),
                      // Payment Settings (web parity) — lease-level, applied to all tenants
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              Text('Payment Settings',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: blueColor)),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      activeColor: blueColor,
                                      value: _enableDebitCardFeeOverride,
                                      onChanged: (v) => setState(() =>
                                          _enableDebitCardFeeOverride =
                                              v ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Enable Debit Card Fee Override',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: blueColor)),
                                ],
                              ),
                              if (_enableDebitCardFeeOverride) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 170,
                                  child: TextFormField(
                                    controller: _overrideFeeController,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    inputFormatters: [
                                      // Web parity: restrict to 0–100% at the
                                      // keystroke level (matches web onChange).
                                      PercentRangeFormatter(),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Add fee here',
                                      suffixText: '%',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCED4DA)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFCED4DA)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FB),
                                  border: Border.all(
                                      color: const Color(0xFFE4E8EF)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Allowed Payment Methods',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Checkbox(
                                            activeColor: blueColor,
                                            value: _allowAch,
                                            onChanged: (v) => setState(() =>
                                                _allowAch = v ?? false),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('ACH',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: blueColor)),
                                        const SizedBox(width: 24),
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Checkbox(
                                            activeColor: blueColor,
                                            value: _allowCard,
                                            onChanged: (v) => setState(() =>
                                                _allowCard = v ?? false),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Card',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: blueColor)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              // Web-parity upload dropzone: icon + title + size
                              // + supported types, tappable to pick files.
                              InkWell(
                                onTap: _pickPdfFiles,
                                borderRadius: BorderRadius.circular(10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.file_upload_outlined,
                                        size: 38, color: Color(0xFF6B7A90)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text('Upload Files (Maximum of 10)',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF152B51))),
                                          SizedBox(height: 4),
                                          Text('Maximum File Size is 20MB',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF748097))),
                                          SizedBox(height: 2),
                                          Text(
                                              'Supported File Types: .png, .jpeg, .pdf, .csv',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF748097))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              /*  SizedBox(height: 20),
                                const SizedBox(height: 10),*/
                              // "Attached Files": add (+) button at the top-right,
                              // files listed vertically (no horizontal scroll).
                              if (_uploadedFileNames.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                        'Attached Files (${_uploadedFileNames.length})',
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF152B51))),
                                    InkWell(
                                      onTap: _pickPdfFiles,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1C2D4E),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.add,
                                            size: 20, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFE4E8EF)),
                                  ),
                                  child: Column(
                                    children: _uploadedFileNames
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final int index = entry.key;
                                      final String fileName = entry.value;
                                      final bool isLast = index ==
                                          _uploadedFileNames.length - 1;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: isLast
                                              ? null
                                              : const Border(
                                                  bottom: BorderSide(
                                                      color: Color(0xFFEAEEF4)),
                                                ),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(fileName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          Color(0xFF152B51))),
                                            ),
                                            const SizedBox(width: 10),
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _uploadedFileNames
                                                      .removeAt(index);
                                                });
                                              },
                                              child: const Icon(Icons.close,
                                                  size: 18,
                                                  color: Color(0xFF6B7A90)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 5),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),

                      Padding(
                        padding: const EdgeInsets.only(
                            top: 16, right: 16, bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0)),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: blueColor,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0))),
                                  onPressed: () async {
                                    if (_formKey.currentState?.validate() ??
                                        false) {
                                      setState(() {
                                        isLoading = true; // Stop loading
                                      });
                                      final provider =
                                          Provider.of<SelectedTenantsProvider>(
                                              context,
                                              listen: false);
                                      final rentShareControllers =
                                          provider.rentShareControllers;
                                      // final provider = Provider.of<SelectedTenantsProvider>(context, listen: false);
                                      // final rentShareControllers = provider.rentShareControllers;
                                      // for (int i = 0; i < rentShareControllers.length; i++) {
                                      //   print('Tenant ${i + 1}: ${rentShareControllers[i].text}');
                                      // }
                                      // bool hasError = false;
                                      // if (hasError || provider.validationMessage != null) {
                                      //   setState(() {
                                      //
                                      //   });
                                      //   return;
                                      // }
                                      // provider.clearValidationMessage();
                                      if (rentShareControllers.length < 1) {
                                        setState(() {
                                          _errorMessage = "required tenants";
                                          // _errorMessagetenants = 'Please select at least one tenant or cosigner.';
                                          // _errorMessage = null;
                                        });
                                        return;
                                      }
                                      setState(() {
                                        // _errorMessagetenants = null;
                                        _errorMessage = null;
                                      });
                                      // Total rent-share validation retired per
                                      // CRM-4132 / CRM-4451: rent share is no
                                      // longer user-editable, so the save must
                                      // never be blocked on a percentage total.
                                      {
                                        SharedPreferences prefs =
                                            await SharedPreferences
                                                .getInstance();
                                        String adminId =
                                            prefs.getString("adminId")!;
                                        bool _isLeaseAdded = false;
                                        // // Printing ChargeData object
                                        // // Printing ChargeData object
                                        //Changes
                                        List<Map<String, dynamic>>
                                            mergedFormDataList = [
                                          ...formDataOneTimeList,
                                          ...formDataRecurringList,
                                        ];
                                        log(mergedFormDataList.toString());
                                        // Creating Entry objects from the merged list
                                        List<Entry> chargeEntries =
                                            mergedFormDataList.map((data) {
                                          return Entry(
                                            entry_id: data['entry_id'] ?? "",
                                            account: data['account'] ?? '',
                                            amount: double.tryParse(
                                                    data['amount'] ?? '0.0') ??
                                                0.0,
                                            chargeType:
                                                data['charge_type'] ?? '',
                                            date: data['charge_type'] ==
                                                    'Recurring Charge'
                                                ? (data['date'] ??
                                                    '') // Ensuring data['date'] is not null
                                                : convertToApiDate(
                                                    rentNextDueDate.text.trim(),
                                                    context),
                                            //: reverseFormatDate(rentNextDueDate.text.trim()),
                                            isRepeatable: data['is_repeatable']
                                                    ?.toLowerCase() ==
                                                'true',
                                            memo: data['memo'] ?? '',
                                            rentCycle: data[
                                                'rent_cycle'], // Assuming this field might be present
                                            tenantId: data[
                                                'tenant_id'], // Assuming this field might be present
                                          );
                                        }).toList();
                                        chargeEntries.add(Entry(
                                            account: "Rent Income",
                                            amount: double.tryParse(
                                                    rentAmount.text.trim()) ??
                                                0.0,
                                            chargeType: 'Rent',
                                            date: convertToApiDate(
                                                rentNextDueDate.text.trim(),
                                                context),
                                            // date: reverseFormatDate(rentNextDueDate.text.trim()),
                                            isRepeatable:
                                                false, // Set to false if it's not repeatable, adjust as needed
                                            memo: 'Last Month\'s Rent',
                                            rentCycle: _selectedRent,
                                            entry_id: rent_entry_id

                                            // Set default value or adjust as needed
                                            ));
                                        chargeEntries.add(Entry(
                                          entry_id: rent_security_id,
                                          account: "Security Deposit",
                                          amount: double.tryParse(
                                                  securityDepositeAmount.text
                                                      .trim()) ??
                                              0.0,
                                          chargeType: 'Security Deposit',
                                          // date: reverseFormatDate(rentNextDueDate.text.trim()),
                                          date: convertToApiDate(
                                              rentNextDueDate.text.trim(),
                                              context),
                                          isRepeatable:
                                              false, // Set to false if it's not repeatable, adjust as needed
                                          memo: 'Security Deposit',
                                          rentCycle:
                                              _selectedRent, // Set default value or adjust as needed
                                        ));
                                        // Creating ChargeData object
                                        ChargeData chargeData = ChargeData(
                                          adminId: adminId,
                                          entry: chargeEntries,
                                          isLeaseAdded: _isLeaseAdded,
                                        );
                                        //Tenant
                                        List<TenantData> tenants = [];
                                        Map<String, String>? firstCosigner =
                                            cosignersMap.isNotEmpty
                                                ? cosignersMap[0]
                                                : {};
                                        List<String> applicantids = [];
                                        List<TenantData> tenantDataList =
                                            tenantsMap.entries.map((entry) {
                                          int index = entry.key;
                                          final tenantMap = entry.value;
                                          if (tenantMap['applicantId']!
                                              .isNotEmpty) {
                                            applicantids
                                                .add(tenantMap['applicantId']!);
                                          }
                                          return TenantData(
                                          emergencyContactsList: (tenantMap['ecArray'] ?? '').isEmpty
                                              ? null
                                              : (jsonDecode(tenantMap['ecArray']!) as List)
                                                  .map((e) => EmergencyContacts(name: e['name'], relation: e['relation'], email: e['email'], phoneNumber: e['phoneNumber']))
                                                  .toList(),
                                          enableOverrideFee: _enableDebitCardFeeOverride,
                                          overrideFee: _enableDebitCardFeeOverride ? _overrideFeeController.text.trim() : null,
                                          allowAch: _allowAch,
                                          allowCard: _allowCard,
                                              adminId: adminId,
                                              comments:
                                                  tenantMap['comments'] ?? '',
                                              emergencyContact:
                                                  EmergencyContacts(
                                                name: tenantMap[
                                                        'emergencyContactName'] ??
                                                    '',
                                                relation: tenantMap[
                                                        'emergencyRelation'] ??
                                                    '',
                                                email: tenantMap[
                                                        'emergencyEmail'] ??
                                                    '',
                                                phoneNumber: tenantMap[
                                                        'emergencyPhoneNumber'] ??
                                                    '',
                                              ),
                                              isDelete: tenantMap['isDelete'] ==
                                                  'true',
                                              taxPayerId:
                                                  tenantMap['taxPayerId'] ?? '',
                                              rentalAddress:
                                                  tenantMap['rental_adress'],
                                              rentalUnit:
                                                  tenantMap['rental_unit'],
                                              tenantAlternativeEmail:
                                                  tenantMap['alterEmail'] ?? '',
                                              tenantAlternativeNumber:
                                                  tenantMap['workNumber'] ?? '',
                                              tenantBirthDate:
                                                  tenantMap['dob'].toString() ??
                                                      '',
                                              tenantEmail:
                                                  tenantMap['email'] ?? '',
                                              createdAt: tenantMap['createdAt'],
                                              tenantFirstName:
                                                  tenantMap['firstName'] ?? '',
                                              tenantId:
                                                  tenantMap['tenantId'] ?? '',
                                              tenantLastName:
                                                  tenantMap['lastName'] ?? '',
                                              tenantPassword:
                                                  tenantMap['passWord'] ?? '',
                                              tenantPhoneNumber:
                                                  tenantMap['phoneNumber'] ??
                                                      '',
                                              // Web parity (CRM-4132): keep sending
                                              // `percentage` in the payload —
                                              // preserve an existing value, else
                                              // first tenant = 100, every other = 0.
                                              rentShare:
                                                  rentShareControllers[index]
                                                          .text
                                                          .trim()
                                                          .isNotEmpty
                                                      ? rentShareControllers[
                                                              index]
                                                          .text
                                                      : (index == 0
                                                          ? "100"
                                                          : "0"));
                                        }).toList();
                                        // Assuming tenantDataList is a List<TenantData>
                                        List<String> tenantIds = tenantDataList
                                            .map((tenant) =>
                                                tenant.tenantId ?? '')
                                            .toList();

                                        // print('selected rent ${_selectedRent}');
                                        // print('rent amount ${rentAmount}');
                                        // print(
                                        //     'start date ${startDateController.text}');
                                        // print('deposite ${securityDepositeAmount}');

                                        Lease lease = Lease(
                                          chargeData: ChargeData(
                                            adminId: adminId ?? "",
                                            entry: chargeEntries,
                                            isLeaseAdded: true,
                                          ),
                                          cosignerData: CosignerData(
                                              cosignerAlternativeNumber: firstCosigner?['workNumber'] ?? '',
                                              cosignerId:
                                                  firstCosigner?['c_id'],
                                              cosignerFirstName:
                                                  firstCosigner?['firstName'] ??
                                                      '',
                                              cosignerLastName:
                                                  firstCosigner?['lastName'] ??
                                                      '',
                                              cosignerPhoneNumber:
                                                  firstCosigner?['phoneNumber'] ??
                                                      '',
                                              cosignerEmail:
                                                  firstCosigner?['email'] ?? '',
                                              cosignerAlternativeEmail:
                                                  firstCosigner?['alterEmail'] ??
                                                      '',
                                              cosignerAddress: firstCosigner?[
                                                      'streetAddress'] ??
                                                  '',
                                              cosignerCity:
                                                  firstCosigner?['city'] ?? '',
                                              cosignerCountry:
                                                  firstCosigner?['country'] ??
                                                      '',
                                              cosignerPostalcode:
                                                  firstCosigner?[
                                                          'postalCode'] ??
                                                      '',
                                              adminId: adminId),
                                          leaseData: LeaseData(
                                            leaseId: widget.leaseId,
                                            adminId: adminId ?? "",
                                            companyName: companyName,
                                            endDate: convertToApiDate(
                                                endDateController.text.trim(),
                                                context),
                                            //   endDate: endDateController.text.trim(),
                                            entry: chargeEntries,
                                            leaseAmount: rentAmount.text.trim(),
                                            leaseType: _selectedLeaseType ?? "",
                                            rentalId: renderId,
                                            startDate: convertToApiDate(
                                                startDateController.text.trim(),
                                                context),
                                            // startDate: startDateController.text.trim(),
                                            tenantId: tenantDataList
                                                .map((tenant) =>
                                                    tenant.tenantId ?? '')
                                                .toList(),
                                            tenantResidentStatus: false,
                                            unitId: _selectedUnit,
                                            // memo: rentMemo.text,
                                            uploadedFile: _uploadedFileNames,
                                            creditCardAccepted:
                                                _creditCardAccepted,
                                            debitCardAccepted:
                                                _debitCardAccepted,
                                            leasePaymentSettings:
                                                _leasePaymentSettings,
                                          ),
                                          tenantData: tenantDataList,
                                        );

                                        await updateLeaseAndNavigate(lease);
                                        setState(() {
                                          isLoading = false; // Stop loading
                                        });
                                        if (applicantids != null &&
                                            applicantids!.isNotEmpty) {
                                          ifApplicantMoveIn(
                                              applicantids.first, applicantids);
                                        } else {
                                        }
                                      }
                                    } else {
                                      SharedPreferences prefs =
                                          await SharedPreferences.getInstance();
                                      String adminId =
                                          prefs.getString("adminId")!;

                                      bool _isLeaseAdded = false;

                                      // // Printing ChargeData object
                                      //Changes
                                      List<Map<String, dynamic>>
                                          mergedFormDataList = [
                                        ...formDataOneTimeList,
                                        ...formDataRecurringList,
                                      ];

                                      // Creating Entry objects from the merged list
                                      List<Entry> chargeEntries =
                                          mergedFormDataList.map((data) {
                                        return Entry(
                                          entry_id: data['entry_id'] ?? "",
                                          account: data['account'] ?? '',
                                          amount: double.tryParse(
                                                  data['amount'] ?? '0.0') ??
                                              0.0,
                                          chargeType: data['charge_type'] ?? '',
                                          date: data['date'] ?? '',
                                          isRepeatable: data['is_repeatable']
                                                  ?.toLowerCase() ==
                                              'true',
                                          memo: data['memo'] ?? '',
                                          rentCycle: data[
                                              'rent_cycle'], // Assuming this field might be present
                                          tenantId: data[
                                              'tenant_id'], // Assuming this field might be present
                                        );
                                      }).toList();
                                      // Creating ChargeData object
                                      ChargeData chargeData = ChargeData(
                                        adminId: adminId,
                                        entry: chargeEntries,
                                        isLeaseAdded: _isLeaseAdded,
                                      );


                                      //consiger

                                      Map<String, String>? firstCosigner =
                                          cosignersMap.isNotEmpty
                                              ? cosignersMap[0]
                                              : {};
                                      List<TenantData> tenantDataList =
                                          tenantsMap.entries.map((entry) {
                                        final tenantMap = entry.value;
                                        return TenantData(
                                          emergencyContactsList: (tenantMap['ecArray'] ?? '').isEmpty
                                              ? null
                                              : (jsonDecode(tenantMap['ecArray']!) as List)
                                                  .map((e) => EmergencyContacts(name: e['name'], relation: e['relation'], email: e['email'], phoneNumber: e['phoneNumber']))
                                                  .toList(),
                                          enableOverrideFee: _enableDebitCardFeeOverride,
                                          overrideFee: _enableDebitCardFeeOverride ? _overrideFeeController.text.trim() : null,
                                          allowAch: _allowAch,
                                          allowCard: _allowCard,
                                          adminId: adminId,
                                          comments: tenantMap['comments'] ?? '',
                                          emergencyContact: EmergencyContacts(
                                            name: tenantMap[
                                                    'emergencyContactName'] ??
                                                '',
                                            relation: tenantMap[
                                                    'emergencyRelation'] ??
                                                '',
                                            email:
                                                tenantMap['emergencyEmail'] ??
                                                    '',
                                            phoneNumber: tenantMap[
                                                    'emergencyPhoneNumber'] ??
                                                '',
                                          ),
                                          isDelete:
                                              tenantMap['isDelete'] == 'true',
                                          taxPayerId:
                                              tenantMap['taxPayerId'] ?? '',
                                          tenantAlternativeEmail:
                                              tenantMap['alterEmail'] ?? '',
                                          tenantAlternativeNumber:
                                              tenantMap['workNumber'] ?? '',
                                          // ?. before .toString(): a tenant with
                                          // no DOB otherwise becomes the literal
                                          // text "null", which is saved back as
                                          // their date of birth. (.toString()
                                          // never returns null, so the ?? '' was
                                          // dead code.)
                                          tenantBirthDate:
                                              tenantMap['dob']?.toString() ?? '',
                                          tenantEmail: tenantMap['email'] ?? '',
                                          tenantFirstName:
                                              tenantMap['firstName'] ?? '',
                                          tenantId: tenantMap['tenantId'] ?? '',
                                          tenantLastName:
                                              tenantMap['lastName'] ?? '',
                                          tenantPassword:
                                              tenantMap['passWord'] ?? '',
                                          tenantPhoneNumber:
                                              tenantMap['phoneNumber'] ?? '',
                                          updatedAt: tenantMap['updatedAt']
                                                  .toString() ??
                                              '',
                                        );
                                      }).toList();
                                      // _handleSubmit();
                                      //print( _selectedRent ??"");
                                    }
                                  },
//                                     onPressed: () async {
//                                       // Validate the form
//                                       if (_formKey.currentState?.validate() ?? false) {
//                                         setState(() {
//                                           isLoading = true; // Stop loading
//                                         });
//                                         final provider = Provider.of<SelectedTenantsProvider>(context, listen: false);
//                                         final rentShareControllers = provider.rentShareControllers;
//
//                                         // Check for required tenants
//                                         if (rentShareControllers.length < 1) {
//                                           setState(() {
//                                             _errorMessage = "Required tenants";
//                                           });
//                                           return;
//                                         }
//
//                                         setState(() {
//                                           _errorMessage = null;
//                                         });
//
//                                         // Calculate total rent share
//                                         double totalRentShare = 0.0;
//                                         for (var controller in rentShareControllers) {
//                                           double rentShare = double.tryParse(controller.text) ?? 0.0;
//                                           totalRentShare += rentShare;
//                                         }
//
//                                         // Check if total rent share equals 100
//                                         if (totalRentShare != 100.0) {
//                                           setState(() {
//                                             _errorMessage = 'Total rent share must equal 100';
//                                           });
//                                           return;
//                                         }
//
//                                         // Check for changes in the form fields
//                                         bool hasChanges = rentAmount.text != initialRentAmount ||
//                                             rentMemo.text != initialRentMemo ||
//                                             rentNextDueDate.text != initialRentNextDueDate ||
//                                             securityDepositeAmount.text != initialSecurityDepositAmount ||
//                                             startDateController.text != initialStartDate ||
//                                             endDateController.text != initialEndDate ||
//                                             _selectedLeaseType != initialSelectedLeaseType ||
//                                             _selectedRent != initialSelectedRent;
//
//
//                                         if (!hasChanges) {
//                                           Navigator.pop(context,false);
//                                           return; // Exit the method if no changes
//                                         }
//
//                                         // Proceed with form submission
//                                         SharedPreferences prefs = await SharedPreferences.getInstance();
//                                         String adminId = prefs.getString("adminId")!;
//                                         bool _isLeaseAdded = false;
//
//                                         // Merge form data
//                                         List<Map<String, dynamic>> mergedFormDataList = [
//                                           ...formDataOneTimeList,
//                                           ...formDataRecurringList,
//                                         ];
//                                         log(mergedFormDataList.toString());
//
//                                         // Create charge entries from the merged list
//                                         List<Entry> chargeEntries = mergedFormDataList.map((data) {
//                                           return Entry(
//                                             entry_id: data['entry_id'] ?? "",
//                                             account: data['account'] ?? '',
//                                             amount: double.tryParse(data['amount'] ?? '0.0') ?? 0.0,
//                                             chargeType: data['charge_type'] ?? '',
//                                             date: data['date'] ?? '',
//                                             isRepeatable: data['is_repeatable']?.toLowerCase() == 'true',
//                                             memo: data['memo'] ?? '',
//                                             rentCycle: data['rent_cycle'],
//                                             tenantId: data['tenant_id'],
//                                           );
//                                         }).toList();
//
//                                         // Add rent entry
//                                         chargeEntries.add(Entry(
//                                           account: "Rent Income",
//                                           amount: double.tryParse(rentAmount.text) ?? 0.0,
//                                           chargeType: 'Rent',
//                                           date: reverseFormatDate(rentNextDueDate.text),
//                                           isRepeatable: false,
//                                           memo: 'Last Month\'s Rent',
//                                           rentCycle: _selectedRent,
//                                           entry_id: rent_entry_id,
//                                         ));
//
//                                         // Add security deposit entry
//                                         chargeEntries.add(Entry(
//                                           entry_id: rent_security_id,
//                                           account: "Security Deposit",
//                                           amount: double.tryParse(securityDepositeAmount.text) ?? 0.0,
//                                           chargeType: 'Security Deposit',
//                                           date: reverseFormatDate(rentNextDueDate.text),
//                                           isRepeatable: false,
//                                           memo: 'Security Deposit',
//                                           rentCycle: _selectedRent,
//                                         ));
//
//                                         // Create ChargeData object
//                                         ChargeData chargeData = ChargeData(
//                                           adminId: adminId,
//                                           entry: chargeEntries,
//                                           isLeaseAdded: _isLeaseAdded,
//                                         );
//                                         Map<String, String>? firstCosigner =
//                                         cosignersMap.isNotEmpty
//                                             ? cosignersMap[0]
//                                             : {};
//                                         // Prepare tenant data
//                                         List<TenantData> tenantDataList = tenantsMap.entries.map((entry) {
//                                           final tenantMap = entry.value;
//                                           return TenantData(
//                                             adminId: adminId,
//                                             comments: tenantMap['comments'] ?? '',
//                                             emergencyContact: EmergencyContacts(
//                                               name: tenantMap['emergencyContactName'] ?? '',
//                                               relation: tenantMap['emergencyRelation'] ?? '',
//                                               email: tenantMap ['emergencyEmail'] ?? '',
//                                               phoneNumber: tenantMap['emergencyPhoneNumber'] ?? '',
//                                             ),
//                                             isDelete: tenantMap['isDelete'] == 'true',
//                                             taxPayerId: tenantMap['taxPayerId'] ?? '',
//                                             rentalAddress: tenantMap['rental_adress'],
//                                             rentalUnit: tenantMap['rental_unit'],
//                                             tenantAlternativeEmail: tenantMap['alterEmail'] ?? '',
//                                             tenantAlternativeNumber: tenantMap['workNumber'] ?? '',
//                                             tenantBirthDate: tenantMap['dob'].toString() ?? '',
//                                             tenantEmail: tenantMap['email'] ?? '',
//                                             tenantFirstName: tenantMap['firstName'] ?? '',
//                                             tenantId: tenantMap['tenantId'] ?? '',
//                                             tenantLastName: tenantMap['lastName'] ?? '',
//                                             tenantPassword: tenantMap['passWord'] ?? '',
//                                             tenantPhoneNumber: tenantMap['phoneNumber'] ?? '',
//                                             rentShare: rentShareControllers[entry.key].text,
//                                           );
//                                         }).toList();
//
//                                         // Prepare lease data
//                                         Lease lease = Lease(
//                                           chargeData: ChargeData(
//                                             adminId: adminId,
//                                             entry: chargeEntries,
//                                             isLeaseAdded: true,
//                                           ),
//                                           cosignerData: CosignerData(
//                                               cosignerId:
//                                               firstCosigner?['c_id'],
//                                               cosignerFirstName:
//                                               firstCosigner?['firstName'] ??
//                                                   '',
//                                               cosignerLastName:
//                                               firstCosigner?['lastName'] ??
//                                                   '',
//                                               cosignerPhoneNumber:
//                                               firstCosigner?['phoneNumber'] ??
//                                                   '',
//                                               cosignerEmail:
//                                               firstCosigner?['email'] ??
//                                                   '',
//                                               cosignerAlternativeEmail:
//                                               firstCosigner?['alterEmail'] ??
//                                                   '',
//                                               cosignerAddress: firstCosigner?[
//                                               'streetAddress'] ??
//                                                   '',
//                                               cosignerCity:
//                                               firstCosigner?['city'] ??
//                                                   '',
//                                               cosignerCountry:
//                                               firstCosigner?['country'] ??
//                                                   '',
//                                               cosignerPostalcode:
//                                               firstCosigner?['postalCode'] ??
//                                                   '',
//                                               adminId: adminId),
//                                           leaseData: LeaseData(
//                                             leaseId: widget.leaseId,
//                                             adminId: adminId,
//                                             companyName: companyName,
//                                             endDate: reverseFormatDate(endDateController.text),
//                                             entry: chargeEntries,
//                                             leaseAmount: rentAmount.text,
//                                             leaseType: _selectedLeaseType,
//                                             rentalId: renderId,
//                                             startDate: reverseFormatDate(startDateController.text),
//                                             tenantId: tenantDataList.map((tenant) => tenant.tenantId ?? '').toList(),
//                                             tenantResidentStatus: false,
//                                             unitId: _selectedUnit,
//                                             uploadedFile: _uploadedFileNames,
//                                           ),
//
//                                           tenantData: tenantDataList,
//                                         );
// print(' start date ${reverseFormatDate(startDateController.text)}');
// print(' end date ${reverseFormatDate(endDateController.text)}');
//                                        await  updateLeaseAndNavigate(lease);
//                                         setState(() {
//                                           isLoading = false; // Stop loading
//                                         });
//                                       } else {
//                                         SharedPreferences prefs = await SharedPreferences.getInstance();
//                                         String adminId = prefs.getString("adminId")!;
//
//                                         bool _isLeaseAdded = false;
//
//                                         // Merge form data
//                                         List<Map<String, dynamic>> mergedFormDataList = [
//                                           ...formDataOneTimeList,
//                                           ...formDataRecurringList,
//                                         ];
//
//                                         // Create charge entries from the merged list
//                                         List<Entry> chargeEntries = mergedFormDataList.map((data) {
//                                           return Entry(
//                                             entry_id: data['entry_id'] ?? "",
//                                             account: data['account'] ?? '',
//                                             amount: double.tryParse(data['amount'] ?? '0.0') ?? 0.0,
//                                             chargeType: data['charge_type'] ?? '',
//                                             date: data['date'] ?? '',
//                                             isRepeatable: data['is_repeatable']?.toLowerCase() == 'true',
//                                             memo: data['memo'] ?? '',
//                                             rentCycle: data['rent_cycle'],
//                                             tenantId: data['tenant_id'],
//                                           );
//                                         }).toList();
//
//                                         // Create ChargeData object
//                                         ChargeData chargeData = ChargeData(
//                                           adminId: adminId,
//                                           entry: chargeEntries,
//                                           isLeaseAdded: _isLeaseAdded,
//                                         );
//
//                                         // Prepare tenant data
//                                         List<TenantData> tenantDataList = tenantsMap.entries.map((entry) {
//                                           final tenantMap = entry.value;
//                                           return TenantData(
//                                             adminId: adminId,
//                                             comments: tenantMap['comments'] ?? '',
//                                             emergencyContact: EmergencyContacts(
//                                               name: tenantMap['emergencyContactName'] ?? '',
//                                               relation: tenantMap['emergencyRelation'] ?? '',
//                                               email: tenantMap['emergencyEmail'] ?? '',
//                                               phoneNumber: tenantMap['emergencyPhoneNumber'] ?? '',
//                                             ),
//                                             isDelete: tenantMap['isDelete'] == 'true',
//                                             taxPayerId: tenantMap['taxPayerId'] ?? '',
//                                             rentalAddress: tenantMap['rental_adress'],
//                                             rentalUnit: tenantMap['rental_unit'],
//                                             tenantAlternativeEmail: tenantMap['alterEmail'] ?? '',
//                                             tenantAlternativeNumber: tenantMap['workNumber'] ?? '',
//                                             tenantBirthDate: tenantMap['dob'].toString() ?? '',
//                                             tenantEmail: tenantMap['email'] ?? '',
//                                             tenantFirstName: tenantMap['firstName'] ?? '',
//                                             tenantId: tenantMap['tenantId'] ?? '',
//                                             tenantLastName: tenantMap['lastName'] ?? '',
//                                             tenantPassword: tenantMap['passWord'] ?? '',
//                                             tenantPhoneNumber: tenantMap['phoneNumber'] ?? '',
//                                           );
//                                         }).toList();
//
//                                         print('invalid');
//                                       }
//                                     },
                                  child: Center(
                                      child: isLoading
                                          ? const SpinKitFadingCircle(
                                              color: Colors.white,
                                              size: 25.0,
                                            )
                                          : const Text(
                                              'Edit Lease',
                                              style: TextStyle(
                                                  color: Color(0xFFf7f8f9),
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold),
                                            )),
                                ))),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0)),
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFffffff),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8.0))),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    child: const Text(
                                      'Cancel',
                                      style:
                                          TextStyle(color: Color(0xFF748097)),
                                    ))))
                          ],
                        ),
                      ),
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

  Future<void> ifApplicantMoveIn(
      String applicantId, List<String> apnt_Id) async {
    bool success =
        await LeaseRepository().ifApplicantMoveInTrue(applicantId, apnt_Id);

    if (success) {
      Navigator.pop(context); // Replace with the actual navigation logic
    } else {
      // Handle the failure case, maybe show a message
    }
  }

  String reverseFormatDate(String inputDate) {
    DateTime parsedDate;

    try {
      // Try parsing the date as yyyy-MM-dd
      parsedDate = DateFormat('yyyy-MM-dd').parseStrict(inputDate);
    } catch (e) {
      try {
        // If the above fails, try parsing the date as dd-MM-yyyy
        parsedDate = DateFormat('dd-MM-yyyy').parseStrict(inputDate);
      } catch (e) {
        // Handle invalid date format or return an error
        throw const FormatException("Invalid date format");
      }
    }

    // Return the date in the yyyy-MM-dd format
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  }

  Future<void> updateLeaseAndNavigate(Lease lease) async {
    bool success = await LeaseRepository().updateLease(lease);

    if (success) {
      Navigator.pop(context, true); // Replace with the actual navigation logic
    } else {
      // Handle the failure case, maybe show a message
    }
  }

  Future<void> addLease() async {
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String adminId = prefs.getString("adminId")!;

    bool _isLeaseAdded = false;

    // // Printing ChargeData object

    List<Map<String, dynamic>> mergedFormDataList = [
      ...formDataOneTimeList,
      ...formDataRecurringList,
    ];

    // Creating Entry objects from the merged list
    List<Entry> chargeEntries = mergedFormDataList.map((data) {
      return Entry(
        account: data['account'] ?? '',
        amount: double.tryParse(data['amount'] ?? '0.0') ?? 0.0,
        chargeType: data['charge_type'] ?? '',
        date: data['date'] ?? '',
        isRepeatable: data['is_repeatable']?.toLowerCase() == 'true',
        memo: data['memo'] ?? '',
        rentCycle: data['rent_cycle'], // Assuming this field might be present
        tenantId: data['tenant_id'], // Assuming this field might be present
      );
    }).toList();

    // Creating ChargeData object
    ChargeData chargeData = ChargeData(
      adminId: adminId,
      entry: chargeEntries,
      isLeaseAdded: _isLeaseAdded,
    );


    setState(() {
      isLoading = false;
    });

    // if (success) {
    //   print('Form is valid');
    //   Fluttertoast.showToast(msg: "Tenant added successfully");
    //   Navigator.of(context).pop(true);
    // } else {
    //   print('Form is invalid');
    // }
  }

  tenent_popup(dynamic person, int index) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTenantCosignerScreen(
          isStaff: true,
          startOnCosigner: true,
          cosigner: person,
          cosignerIndex: index,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }
}

// Charge-popup date fields are shown in the user's DateProvider format, but the
// API always receives yyyy-MM-dd (same as the web). Convert display -> API here.
String _chargeDateToApi(BuildContext context, String display) {
  final String s = display.trim();
  if (s.isEmpty) return "";
  final dp = Provider.of<DateProvider>(context, listen: false);
  for (final String f in <String>[
    'yyyy-MM-dd',
    dp.dateFormat,
    'MM/dd/yyyy',
    'M/d/yyyy',
    'yyyy-MMM-dd',
    'dd-MM-yyyy',
    'MM-dd-yyyy',
  ]) {
    try {
      return DateFormat('yyyy-MM-dd').format(DateFormat(f).parseStrict(s));
    } catch (_) {}
  }
  return s;
}

class OneTimeChargePopUp extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;
  final Map<String, dynamic>? initialData;

  OneTimeChargePopUp({required this.onSave, this.initialData});

  @override
  State<OneTimeChargePopUp> createState() => _OneTimeChargePopUpState();
}

class _OneTimeChargePopUpState extends State<OneTimeChargePopUp> {
  void _openAddAccountOneTime(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return StatefulBuilder(builder: (context, setState) { return Dialog(
                                        backgroundColor: Colors.white,
                                        surfaceTintColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10.0)),
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: 500,
                                            maxHeight: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.8,
                                          ),
                                          child: SingleChildScrollView(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Form(
                                                key: _subFormKey,
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Add account',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    Text(
                                                      'Account Name *',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          return 'Please enter Account Name';
                                                        }
                                                        return null;
                                                      },
                                                      keyboardType:
                                                          TextInputType.text,
                                                      hintText:
                                                          'Enter Account Name',
                                                      controller:
                                                          _accountNameController,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'Account Type',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    CustomDropdown(
                                useBorderStyle: true,
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          return 'Please select a Account Type';
                                                        }
                                                        return null;
                                                      },
                                                      labelText:
                                                          'Select Account Type',
                                                      items: accountTypeItems,
                                                      selectedValue:
                                                          _selectedAccountType,
                                                      onChanged:
                                                          (String? value) {
                                                        setState(() {
                                                          _selectedAccountType =
                                                              value;
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'Fund Type',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    CustomDropdown(
                                useBorderStyle: true,
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          return 'Please select a Fund Type';
                                                        }
                                                        return null;
                                                      },
                                                      labelText:
                                                          'Select Fund Type',
                                                      items: fundTypeItems,
                                                      selectedValue:
                                                          _selectedFundType,
                                                      onChanged:
                                                          (String? value) {
                                                        setState(() {
                                                          _selectedFundType =
                                                              value;
                                                        });
                                                      },
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'Notes',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          return 'Please enter Notes';
                                                        }
                                                        return null;
                                                      },
                                                      keyboardType:
                                                          TextInputType.text,
                                                      hintText: 'Enter Notes',
                                                      controller:
                                                          _notesController,
                                                    ),
                                                    const SizedBox(height: 20),
                                                    RichText(
                                                      text: TextSpan(
                                                        children: <TextSpan>[
                                                          const TextSpan(
                                                            text:
                                                                'We stores this information ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight.w400,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: ' Privately ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              color: blueColor,
                                                            ),
                                                          ),
                                                          const TextSpan(
                                                            text: ' and ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: ' Securely ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight.bold,
                                                              color: blueColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        Container(
                                                            height: 50,
                                                            width: 90,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0)),
                                                            child:
                                                                ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            blueColor,
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                                8.0))),
                                                                    onPressed:
                                                                        () {
                                                                      _submitSubForm();
                                                                    },
                                                                    child:
                                                                        const Text(
                                                                      'Add',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Color(0xFFf7f8f9)),
                                                                    ))),
                                                        const SizedBox(
                                                            width: 10),
                                                        Container(
                                                            height: 50,
                                                            width: 94,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8.0)),
                                                            child:
                                                                ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                        backgroundColor:
                                                                            const Color(
                                                                                0xFFffffff),
                                                                        shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                                8.0))),
                                                                    onPressed:
                                                                        () {
                                                                      setState(
                                                                          () {
                                                                        _selectedProperty = null;
                                                                      });
                                                                      Navigator.pop(
                                                                          context);
                                                                    },
                                                                    child:
                                                                        const Text(
                                                                      'Cancel',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Color(0xFF748097)),
                                                                    )))
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ); });
                                    },
                                  );
                                
    });
  }

  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _subFormKey = GlobalKey<FormState>();
  String? _selectedAccountType;
  String? _selectedFundType;
  final TextEditingController _accountNameController = TextEditingController();
  String? _selectedProperty;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  bool _isInvalid = true;
  List<String> items = []; // Example items

  List<String> accountTypeItems = [
    'Income',
    'Non Operating Income ',
    'Liability Account',
  ]; // Example items
  List<String> fundTypeItems = [
    'Reverse',
    'Operating',
  ]; // Example items

  bool _isLoading = true;
  List<String> accounts = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _selectedProperty = widget.initialData!['account'] ?? '';
      _amountController.text = widget.initialData!['amount'] ?? '';
      _memoController.text = widget.initialData!['memo'] ?? '';
      startDateController.text = Provider.of<DateProvider>(context, listen: false).formatCurrentDate(widget.initialData!['date'] ?? '');
    }
    fetchData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('$Api_url/api/accounts/accounts/$id'), headers: {
      "authorization": "CRM $token",
      "id": "CRM $staffid",
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        items = (data['data'] as List)
            .map((item) => item['account'] as String)
            .toList();
        _isLoading = false;
      });
    } else {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch data')),
      );
    }
  }

  bool _showAccountError = false;
  TextEditingController startDateController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          child: Container(
            color: Colors.white,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    'Add One Time Fee',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Account *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          isExpanded: true,
                          hint: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFb0b6c3),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          items: [
                            // Dedupe so a repeated account (e.g. "Pet Deposit")
                            // doesn't trip the "exactly one item" assertion.
                            ...items.toSet()
                                .map((String item) => DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF152B51),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                            DropdownMenuItem<String>(
                              value: 'button_item',
                              
                                child: const Row(
                                  children: [
                                    Text(
                                      '+ Add New Account',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                            ),
                          ],
                          value: items.contains(_selectedProperty)
                              ? _selectedProperty
                              : null,
                          onChanged: (value) {
                            if (value == 'button_item') { _openAddAccountOneTime(context); return; }
                            setState(() {
                              _selectedProperty = value;
                              _showAccountError =
                                  false; // clear error on change
                            });
                          },
                          buttonStyleData: ButtonStyleData(
                            height: 50,
                            padding: const EdgeInsets.only(left: 0, right: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFCED4DA)),
                            ),
                            elevation: 0,
                          ),
                          iconStyleData: const IconStyleData(
                            icon: Icon(Icons.arrow_drop_down),
                            iconSize: 24,
                            iconEnabledColor: Color(0xFFb0b6c3),
                            iconDisabledColor: Colors.grey,
                          ),
                          dropdownStyleData: DropdownStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            scrollbarTheme: ScrollbarThemeData(
                              radius: const Radius.circular(6),
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
                      if (_showAccountError)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'Please select an account',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Amount *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.number,
                    hintText: 'Enter Amount',
                    controller: _amountController,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Memo *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter memo';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    hintText: 'Enter Memo',
                    controller: _memoController,
                    // optional: true,
                  ),
                  const SizedBox(height: 20),
                  if (MediaQuery.of(context).size.width < 500) ...[
                    Text.rich(TextSpan(text: 'Charge Date ', style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: blueColor), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                    const SizedBox(height: 8),
                    CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          helpText: "Charge Date",
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          locale: const Locale('en', 'US'),
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: blueColor,
                                  onPrimary: Colors.white,
                                  onSurface: blueColor,
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
                        if (pickedDate != null) {
                          String formattedStartDate =
                              "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                          setState(() {
                            startDateController.text = Provider.of<DateProvider>(context, listen: false).formatCurrentDate(formattedStartDate);
                          });
                        }
                      },
                      readOnnly: true,
                      suffixIcon: IconButton(
                        onPressed: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            helpText: "Charge Date",
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                            locale: const Locale('en', 'US'),
                            builder: (BuildContext context, Widget? child) {
                              return Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: blueColor,
                                    onPrimary: Colors.white,
                                    onSurface: blueColor,
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
                          if (pickedDate != null) {
                            String formattedStartDate =
                                "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                            setState(() {
                              startDateController.text = Provider.of<DateProvider>(context, listen: false).formatCurrentDate(formattedStartDate);
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'select start date';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.text,
                      hintText: 'YYYY-MM-DD',
                      label: "select start date",
                      controller: startDateController,
                    ),
                    const SizedBox(height: 15),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                          height: 50,
                          width: 90,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0)),
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: blueColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8.0))),
                              onPressed: () {
                                _submitForm();
                              },
                              child: const Text(
                                'Add',
                                style: TextStyle(color: Color(0xFFf7f8f9)),
                              ))),
                      const SizedBox(width: 10),
                      Container(
                          height: 50,
                          width: 94,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.0)),
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFffffff),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8.0))),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Color(0xFF748097)),
                              )))
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isInvalid = true;
      });
      // Carry the existing charge's entry_id so an edit UPDATES that charge
      // instead of being saved as an additional one. This map REPLACES the
      // loaded record in formDataOneTimeList, so leaving the key out dropped
      // the id the save path reads (`Entry(entry_id: data['entry_id'] ?? "")`).
      // Same shape as the recurring popup below and as web, which sends
      // `entry_id: item.entry_id || ""` for one-time and recurring alike.
      String? id =
          widget.initialData != null ? widget.initialData!['entry_id'] : "";
      final formData = {
        'account': _selectedProperty ?? '',
        'amount': _amountController.text.trim(),
        'memo': _memoController.text.trim(),
        'entry_id': id ?? "",
        'charge_type': 'One Time Charge',
        'date': _chargeDateToApi(context, startDateController.text),
      };
      widget.onSave(formData);
      setState(() {
        _isInvalid = false;
      });
    } else {
      setState(() {
        _isInvalid = false;
      });
    }
  }

  Future _submitSubForm() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String adminId = prefs.getString('adminId').toString();
    if (_subFormKey.currentState?.validate() ?? false) {
      final formData = {
        'admin_id': adminId,
        'account': _accountNameController.text.trim(),
        'account_type': _selectedAccountType ?? '',
        'fund_type': _selectedFundType ?? '',
        'notes': _notesController.text.trim(),
      };
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('adminId');
      String? staffid = prefs.getString("staff_id");
      String? token = prefs.getString('token');
      final response = await apiPost(
        Uri.parse('$Api_url/api/accounts/accounts'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $staffid",
          'Content-Type': 'application/json'
        },
        body: json.encode(formData),
      );

      if (response.statusCode == 200) {
        final newAccountName = _accountNameController.text.trim();
        setState(() {
          items.insert(items.length, newAccountName);
          _selectedProperty = newAccountName;
          _showAccountError = false;
        });
        _accountNameController.clear();
        _selectedAccountType = null;
        _selectedFundType = null;
        _notesController.clear();
        if (mounted) { WidgetsBinding.instance.addPostFrameCallback((_) { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); }); }
        Fluttertoast.showToast(msg: 'Account Added Successfully');
      } else {
        // Handle error response
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add account')),
        );
      }
    } else {
      setState(() {
        _isInvalid = true;
      });
    }
  }
}

class RecurringChargePopUp extends StatefulWidget {
  final Function(Map<String, String>) onSave;
  final Map<String, String>? initialData;

  RecurringChargePopUp({required this.onSave, this.initialData});

  @override
  State<RecurringChargePopUp> createState() => _RecurringChargePopUpState();
}

class _RecurringChargePopUpState extends State<RecurringChargePopUp> {
  void _openAddAccountDialog(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return StatefulBuilder(
                                          builder: (context, setState) {
                                        return Dialog(
                                          backgroundColor: Colors.white,
                                          surfaceTintColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.0)),
                                          child: SingleChildScrollView(
                                            child: Container(
                                              // height: 450,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: Form(
                                                  key: _subFormKey,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Add account',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: 20,
                                                      ),
                                                      Text(
                                                        'Account Name *',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            return 'Please enter Account Name';
                                                          }
                                                          return null;
                                                        },
                                                        keyboardType:
                                                            TextInputType.text,
                                                        hintText:
                                                            'Enter Account Name',
                                                        controller:
                                                            _accountNameController,
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      Text(
                                                        'Account Type',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      CustomDropdown(
                                useBorderStyle: true,
                                                        validator: (value) {
                                                          if (_selectedAccountType ==
                                                                  null ||
                                                              _selectedAccountType!
                                                                  .isEmpty) {
                                                            return 'Please select a Account Type';
                                                          }
                                                          return null;
                                                        },
                                                        labelText:
                                                            'Select Account Type',
                                                        items: accountTypeItems,
                                                        selectedValue:
                                                            _selectedAccountType,
                                                        onChanged:
                                                            (String? value) {
                                                          setState(() {
                                                            _selectedAccountType =
                                                                value;
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      Text(
                                                        'Fund Type',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      CustomDropdown(
                                useBorderStyle: true,
                                                        validator: (value) {
                                                          if (_selectedFundType ==
                                                                  null ||
                                                              _selectedFundType!
                                                                  .isEmpty) {
                                                            return 'Please select a Fund Type';
                                                          }
                                                          return null;
                                                        },
                                                        labelText:
                                                            'Select Fund Type',
                                                        items: fundTypeItems,
                                                        selectedValue:
                                                            _selectedFundType,
                                                        onChanged:
                                                            (String? value) {
                                                          setState(() {
                                                            _selectedFundType =
                                                                value;
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(
                                                          height: 10),
                                                      Text(
                                                        'Notes',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 5),
                                                      CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            return 'Please enter Notes';
                                                          }
                                                          return null;
                                                        },
                                                        keyboardType:
                                                            TextInputType.text,
                                                        hintText: 'Enter Notes',
                                                        controller:
                                                            _notesController,
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      RichText(
                                                        text: const TextSpan(
                                                          children: <TextSpan>[
                                                            TextSpan(
                                                              text:
                                                                  'We stores this information ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.w400,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text:
                                                                  ' Privately ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.bold,
                                                                color: Color
                                                                    .fromRGBO(
                                                                        21,
                                                                        43,
                                                                        83,
                                                                        1),
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text: ' and ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text:
                                                                  ' Securely ',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight.bold,
                                                                color: Color
                                                                    .fromRGBO(
                                                                        21,
                                                                        43,
                                                                        83,
                                                                        1),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          Container(
                                                              height: 50,
                                                              width: 90,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          8.0)),
                                                              child:
                                                                  ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                          backgroundColor: const Color(
                                                                              0xFF152b51),
                                                                          shape: RoundedRectangleBorder(
                                                                              borderRadius: BorderRadius.circular(
                                                                                  8.0))),
                                                                      onPressed:
                                                                          () {
                                                                        _submitSubForm(
                                                                            context);
                                                                      },
                                                                      child:
                                                                          const Text(
                                                                        'Add',
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFFf7f8f9)),
                                                                      ))),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Container(
                                                              height: 50,
                                                              width: 94,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          8.0)),
                                                              child:
                                                                  ElevatedButton(
                                                                      style: ElevatedButton.styleFrom(
                                                                          backgroundColor: const Color(
                                                                              0xFFffffff),
                                                                          shape: RoundedRectangleBorder(
                                                                              borderRadius: BorderRadius.circular(
                                                                                  8.0))),
                                                                      onPressed:
                                                                          () {
                                                                        setState(
                                                                            () {
                                                                          _selectedProperty = null;
                                                                        });
                                                                        Navigator.pop(
                                                                            context);
                                                                      },
                                                                      child:
                                                                          const Text(
                                                                        'Cancel',
                                                                        style: TextStyle(
                                                                            color:
                                                                                Color(0xFF748097)),
                                                                      )))
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      });
                                    },
                                  );
                                
    });
  }

  final _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _subFormKey = GlobalKey<FormState>();
  String? _selectedAccountType;
  String? _selectedFundType;
  final TextEditingController _accountNameController = TextEditingController();
  String? _selectedProperty;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  bool _isInvalid = true;
  List<String> items = []; // Example items

  List<String> accountTypeItems = [
    'Income',
    'Non Operating Income ',
    'Liability Account',
  ]; // Example items
  List<String> fundTypeItems = [
    'Reverse',
    'Operating',
  ]; // Example items

  bool _isLoading = true;
  List<String> accounts = [];

  // @override
  // void initState() {
  //   super.initState();
  //   if (widget.initialData != null) {
  //     _selectedProperty = widget.initialData!['property'] ?? '';
  //     _amountController.text = widget.initialData!['amount'] ?? '';
  //     _memoController.text = widget.initialData!['memo'] ?? '';
  //   }
  //   fetchData();
  // }

  // @override
  // void dispose() {
  //   _amountController.dispose();
  //   _memoController.dispose();
  //   super.dispose();
  // }

  // Future<void> fetchData() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String adminId = prefs.getString('adminId').toString();
  //   final response =
  //       await apiGet(Uri.parse('$Api_url/api/accounts/accounts/$adminId'));
  //   print(response.body);
  //   if (response.statusCode == 200) {
  //     final data = json.decode(response.body);
  //     setState(() {
  //       items = (data['data'] as List)
  //           .where((item) => item['charge_type'] == "One Time Charge")
  //           .map((item) => item['account'] as String)
  //           .toList();
  //       _isLoading = false;
  //       print(items.length);
  //     });
  //   } else {
  //     // Handle error
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Failed to fetch data')),
  //     );
  //   }
  // }

// updated
  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _selectedProperty = widget.initialData!['account'] ?? '';
      _amountController.text = widget.initialData!['amount'] ?? '';
      _memoController.text = widget.initialData!['memo'] ?? '';
      startDateController.text = Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(widget.initialData!['charge_start'] ??
              widget.initialData!['date'] ??
              "");
      selectedDay = widget.initialData!['rent_cycle'] ?? "";
    }
    fetchData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('$Api_url/api/accounts/accounts/$adminid'), headers: {
      "authorization": "CRM $token",
      "id": "CRM $id",
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        items = (data['data'] as List)
            .map((item) => item['account'] as String)
            .toList();
        _isLoading = false;
      });
    } else {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch data')),
      );
    }
  }

  bool _showAccountError = false;
  String? selectedDay;
  TextEditingController startDateController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          child: Container(
            color: Colors.white,
            //height: _isInvalid ? 460 : 475,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2),
                Text(
                  'Add Recurring Fee',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Account *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                SizedBox(height: 8),
                _isLoading
                    ? const Center(
                        child: SpinKitFadingCircle(
                        color: Colors.black,
                        size: 50.0,
                      ))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          isExpanded: true,
                          hint: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFFb0b6c3),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          items: [
                            // Dedupe so a repeated account (e.g. "Pet Deposit")
                            // doesn't trip the "exactly one item" assertion.
                            ...items.toSet()
                                .map((String item) => DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF152B51),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                            //updated
                            DropdownMenuItem<String>(
                              value: 'button_item',
                              
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '+ Add New Account',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                            ),
                          ],
                          value: items.contains(_selectedProperty)
                              ? _selectedProperty
                              : null,
                          onChanged: (value) {
                            if (value == 'button_item') { _openAddAccountDialog(context); return; }
                            setState(() {
                              _selectedProperty = value;
                            });

                            // widget.onChanged(value);
                            // state.didChange(value);
                          },
                          buttonStyleData: ButtonStyleData(
                            height: 50,
                            // width: 160,
                            padding: const EdgeInsets.only(left: 0, right: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFCED4DA)),
                            ),
                            elevation: 0,
                          ),
                          iconStyleData: const IconStyleData(
                            icon: Icon(
                              Icons.arrow_drop_down,
                            ),
                            iconSize: 24,
                            iconEnabledColor: Color(0xFFb0b6c3),
                            iconDisabledColor: Colors.grey,
                          ),
                          dropdownStyleData: DropdownStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.white,
                            ),
                            scrollbarTheme: ScrollbarThemeData(
                              radius: const Radius.circular(6),
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
                const SizedBox(height: 8),
                Text(
                  'Amount *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.number,
                  hintText: 'Enter Amount',
                  controller: _amountController,
                ),
                const SizedBox(height: 8),
                Text(
                  'Memo',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter memo';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.text,
                  hintText: 'Enter Memo',
                  controller: _memoController,
                  optional: true,
                ),
                const SizedBox(height: 10),
                Text(
                  'Recurrence Type *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    hint: Text('select'),
                    isExpanded: true,
                    // menuMaxHeight: 200,
                    // Guard: edit prefill may set selectedDay to a day number
                    // (e.g. "30") which isn't a valid item here -> show hint
                    // instead of crashing.
                    value: (selectedDay == 'Weekly' || selectedDay == 'Monthly')
                        ? selectedDay
                        : null,
                    items: const [
                      DropdownMenuItem<String>(
                        value: 'Weekly',
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Monthly',
                        child: Text('Monthly'),
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        selectedDay = value;
                      });
                    },
                    buttonStyleData: ButtonStyleData(
                      height: 50,
                      // width: 160,
                      padding: const EdgeInsets.only(left: 0, right: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFCED4DA)),
                      ),
                      elevation: 0,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.white,
                      ),
                      scrollbarTheme: ScrollbarThemeData(
                        radius: const Radius.circular(6),
                        thickness: MaterialStateProperty.all(6),
                        thumbVisibility: MaterialStateProperty.all(true),
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                if (MediaQuery.of(context).size.width < 500)
                  Text.rich(TextSpan(text: 'Charge Start From ', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: blueColor), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                if (MediaQuery.of(context).size.width < 500)
                  const SizedBox(
                    height: 8,
                  ),
                if (MediaQuery.of(context).size.width < 500)
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        helpText: "Charge Start",
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                        locale: const Locale('en', 'US'),
                        builder: (BuildContext context, Widget? child) {
                          return Theme(
                            data: ThemeData.light().copyWith(
                              colorScheme: ColorScheme.light(
                                primary: blueColor, // header background color
                                onPrimary: Colors.white, // header text color
                                onSurface: blueColor, // body text color
                              ),
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor:
                                      blueColor, // button text color
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (pickedDate != null) {
                        // String formattedStartDate =
                        //     "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        String formattedStartDate =
                            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                        DateTime endDate = DateTime(pickedDate.year + 1,
                            pickedDate.month, pickedDate.day);
                        // String formattedEndDate =
                        //     "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

                        String formattedEndDate =
                            "${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}";
                        setState(() {
                          startDateController.text = Provider.of<DateProvider>(context, listen: false).formatCurrentDate(formattedStartDate);
                        });
                      }
                    },
                    readOnnly: true,
                    suffixIcon: IconButton(
                      onPressed: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          helpText: "Charge Start",
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                          locale: const Locale('en', 'US'),
                          builder: (BuildContext context, Widget? child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: blueColor, // header background color
                                  onPrimary: Colors.white, // header text color
                                  onSurface: blueColor, // body text color
                                ),
                                textButtonTheme: TextButtonThemeData(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor:
                                        blueColor, // button text color
                                  ),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (pickedDate != null) {
                          // String formattedStartDate =
                          //     "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                          String formattedStartDate =
                              "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                          DateTime endDate = DateTime(pickedDate.year + 1,
                              pickedDate.month, pickedDate.day);
                          // String formattedEndDate =
                          //     "${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";

                          String formattedEndDate =
                              "${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}";
                          setState(() {
                            startDateController.text = Provider.of<DateProvider>(context, listen: false).formatCurrentDate(formattedStartDate);
                          });
                        }
                      },
                      icon: const Icon(Icons.date_range_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'select start date';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    hintText: 'YYYY-MM-DD',
                    label: "select start date",
                    controller: startDateController,
                  ),
                if (MediaQuery.of(context).size.width < 500)
                  const SizedBox(
                    height: 15,
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                        height: 50,
                        width: 90,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0)),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0))),
                            onPressed: () {
                              _submitForm(context);
                            },
                            child: const Text(
                              'Add',
                              style: TextStyle(color: Color(0xFFf7f8f9)),
                            ))),
                    const SizedBox(
                      width: 10,
                    ),
                    Container(
                        height: 50,
                        width: 94,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0)),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFffffff),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0))),
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0xFF748097)),
                            )))
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isInvalid = true;
      });
      // Recurrence type (Weekly/Monthly) lives in selectedDay — do NOT parse it
      // as an int. The charge start date comes from the date picker.
      String? id =
          widget.initialData != null ? widget.initialData!['entry_id'] : "";
      final formData = {
        'account': _selectedProperty ?? '',
        'amount': _amountController.text.trim(),
        'memo': _memoController.text.trim(),
        'entry_id': id ?? "",
        'rent_cycle': selectedDay ?? "",
        'charge_type': 'Recurring Charge',
        'date': _chargeDateToApi(context, startDateController.text),
        'charge_start': _chargeDateToApi(context, startDateController.text),
      };
      widget.onSave(formData);
      setState(() {
        _isInvalid = false;
      });
    } else {
      setState(() {
        _isInvalid = false;
      });
    }
  }

  Future _submitSubForm(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String adminId = prefs.getString('adminId').toString();
    if (_subFormKey.currentState?.validate() ?? false) {
      final formData = {
        'admin_id': adminId,
        'account': _accountNameController.text.trim(),
        'account_type': _selectedAccountType ?? '',
        'fund_type': _selectedFundType ?? '',
        'notes': _notesController.text.trim(),
      };
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('adminId');
      String? token = prefs.getString('token');
      final response = await apiPost(
        Uri.parse('$Api_url/api/accounts/accounts'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
          'Content-Type': 'application/json'
        },
        body: json.encode(formData),
      );
      if (response.statusCode == 200) {
        final newAccountName = _accountNameController.text.trim();
        setState(() {
          items.insert(items.length, newAccountName);
          _selectedProperty = newAccountName;
          _showAccountError = false;
        });
        _accountNameController.clear();
        _selectedAccountType = null;
        _selectedFundType = null;
        _notesController.clear();
        if (mounted) { WidgetsBinding.instance.addPostFrameCallback((_) { if (Navigator.of(context).canPop()) Navigator.of(context).pop(); }); }
        Fluttertoast.showToast(msg: 'Account Added Successfully');
      } else {
        // Handle error response
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add account')),
        );
      }
    } else {
      setState(() {
        _isInvalid = true;
      });
    }
  }
}

class AddTenant extends StatefulWidget {
  const AddTenant({super.key});

  @override
  State<AddTenant> createState() => _AddTenantState();
}

class _AddTenantState extends State<AddTenant> {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController phoneNumber = TextEditingController();
  final TextEditingController workNumber = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController alterEmail = TextEditingController();
  final TextEditingController passWord = TextEditingController();
  final TextEditingController dob = TextEditingController();
  final TextEditingController taxPayerId = TextEditingController();
  final TextEditingController comments = TextEditingController();
  final TextEditingController contactName = TextEditingController();
  final TextEditingController relationToTenant = TextEditingController();
  final TextEditingController emergencyEmail = TextEditingController();
  final TextEditingController emergencyPhoneNumber = TextEditingController();
  TextEditingController searchController = TextEditingController();
  bool _obscureText = true;
  //bool _ischecked = false;
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredTenants = tenants;
    selected = List<bool>.generate(tenants.length, (index) => false);

    fetchTenantsAndApplicants();
    filteredApplicant = Applicant;
    select = List<bool>.generate(Applicant.length, (index) => false);
    // fetchTenants();
  }

  List<Datum> Applicant = [];
  List<Datum> filteredApplicant = [];
  List<Datum> selectedApplicant = [];
  List<bool> select = [];
  Future<void> fetchTenantsAndApplicants() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminid = prefs.getString("adminId");
      String? id = prefs.getString("staff_id");
      String? token = prefs.getString('token');

      // Fetch tenants
      final tenantResponse = await http
          .get(Uri.parse('${Api_url}/api/tenant/tenants/$adminid'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });

      // if (tenantResponse.statusCode == 200) {
      //   Map<String, dynamic> tenantData = json.decode(tenantResponse.body);
      //   if (tenantData.containsKey('data')) {
      //     List<dynamic> tenantList = tenantData['data']['tenants'];
      //     tenants = tenantList.map((item) => Tenant.fromJson(item)).toList();
      //   } else {
      //     print("Unexpected tenant response structure: Missing 'data' key");
      //   }
      // } else {
      //   print("Failed to load tenants: ${tenantResponse.statusCode}");
      // }

      if (tenantResponse.statusCode == 200) {
        Map<String, dynamic> tenantData = json.decode(tenantResponse.body);
        if (tenantData.containsKey('data')) {
          List<dynamic> tenantList = tenantData['data']['tenants'];
          List<dynamic> applicantlist = tenantData['data']['applicants'];

          tenants = tenantList.map((item) => Tenant.fromJson(item)).toList();
          tenants.addAll(applicantlist
              .map((item) => convertApplicantToTenant(Datum.fromJson(item)))
              .toList());
        } else {
        }
      } else {
      }

      // Fetch applicants
      // final applicantResponse = await http
      //     .get(Uri.parse('${Api_url}/api/applicant/applicant/$adminid'), headers: {
      //   "authorization": "CRM $token",
      //   "id": "CRM $id",
      // });

      // if (applicantResponse.statusCode == 200) {
      //   Map<String, dynamic> applicantData = json.decode(applicantResponse.body);
      //   if (applicantData.containsKey('data')) {
      //     List<dynamic> applicantList = applicantData['data'];
      //     List<Tenant> convertedApplicants = applicantList
      //         .map((item) => convertApplicantToTenant(Datum.fromJson(item)))
      //         .toList();
      //
      //     // Merge tenants and converted applicants
      //     tenants.addAll(convertedApplicants);
      //   } else {
      //     print("Unexpected applicant response structure: Missing 'data' key");
      //   }
      // } else {
      //   print("Failed to load applicants: ${applicantResponse.statusCode}");
      // }

      // Update filtered list and selection state
      filteredTenants = List.from(tenants);
      selected = List<bool>.filled(tenants.length, false);
    } catch (e) {
      logError("Error fetching tenants or applicants: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Tenant convertApplicantToTenant(Datum applicant) {
    return Tenant(
      applicantId: applicant.applicantId,
      tenantFirstName: applicant.applicantFirstName,
      tenantLastName: applicant.applicantLastName,
      tenantEmail: applicant.applicantEmail,
      tenantPhoneNumber: applicant.applicantPhoneNumber.toString(),
      tenantId: null, // Explicitly set tenantId as null
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Colors.blue, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(selectedDate);
      });
    }
  }

  bool isValidEmail(String email) {
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  void _toggleObscureText() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  bool _showalterNumber = false;
  bool _showalterEmail = false;
  bool _showPersonalDetail = false;
  bool _showEmergancyDetail = false;
  bool isChecked = false;
  bool isLoading = false;
  int? selectedIndex;
  List<Tenant> tenants = [];
  List<Tenant> filteredTenants = [];
  List<Tenant> selectedTenants = [];
  List<bool> selected = [];
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  Future<void> fetchTenants() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      //String? id = prefs.getString("adminId");
      String? id = prefs.getString("adminId");
      String? staffid = prefs.getString("staff_id");
      String? token = prefs.getString('token');
      final response = await http
          .get(Uri.parse('${Api_url}/api/tenant/tenants/$id'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $staffid",
      });

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        // Check if the response contains the expected keys
        if (responseData.containsKey('data')) {
          List<dynamic> data = responseData['data']['tenants'];
          tenants = data.map((item) => Tenant.fromJson(item)).toList();
          filteredTenants = List.from(tenants);
          selected = List<bool>.filled(tenants.length, false);
        } else {
          // Handle unexpected response structure
        }
      } else {
        // Handle HTTP errors
      }
    } catch (e) {
      // Handle other errors
      logError("Error fetching tenants: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  //
  // void filterOwners(String query) {
  //   setState(() {
  //     filteredOwners = owners.where((owner) {
  //       final fullName = '${owner.firstName} ${owner.lastName}'.toLowerCase();
  //       return fullName.contains(query.toLowerCase());
  //     }).toList();
  //   });
  // }
  List<Tenant> selectedTenantsTemp = [];
  @override
  Widget build(BuildContext context) {
    var selectedTenantsProvider =
        Provider.of<SelectedTenantsProvider>(context, listen: false);
    return Container(
      child: Form(
        key: _formKey,
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 10,
            ),
            //checked
            Row(
              children: [
                SizedBox(
                  width: 24.0, // Standard width for checkbox
                  height: 24.0,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (value) {
                      setState(() {
                        isChecked = value ?? false;
                      });
                    },
                    activeColor: isChecked ? blueColor : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            isChecked
                ? Column(
                    children: [
                      const SizedBox(height: 16.0),
                      const SizedBox(height: 16.0),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('Tenant Name')),
                            const DataColumn(label: Text('Select')),
                          ],
                          rows: filteredTenants.map((tenant) {
                            final matchingTenants =
                                Provider.of<SelectedTenantsProvider>(context)
                                    .selectedTenants
                                    .where((test) => tenant.tenantId != null
                                        ? test.tenantId == tenant.tenantId
                                        : test.applicantId ==
                                            tenant.applicantId)
                                    .toList();

                            final isSelected =
                                matchingTenants.length > 0 ? true : false;
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                      '${tenant.tenantFirstName} ${tenant.tenantLastName}'),
                                ),
                                DataCell(
                                  SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        if (value!) {
                                          selectedTenantsProvider
                                              .addTenant(tenant);
                                        } else {
                                          selectedTenantsProvider
                                              .removeTenant(tenant);
                                        }
                                        setState(() {});
                                      },
                                      activeColor: blueColor,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Row(
                        children: [
                          const SizedBox(
                            width: 2,
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                for (var tenant in selectedTenantsTemp) {
                                  selectedTenantsProvider.addTenant(tenant);
                                }
                                // Clear the temporary list after adding
                                selectedTenantsTemp.clear();
                              });
                              Navigator.pop(context);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5.0),
                              child: Container(
                                height: 40.0,
                                width: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5.0),
                                  color: blueColor,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.grey,
                                      offset: Offset(0.0, 1.0), //(x,y)
                                      blurRadius: 6.0,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    "Add",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5.0),
                              child: Container(
                                height: 40.0,
                                width: 90,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5.0),
                                  color: Colors.white,
                                  border: Border.all(color: blueColor),
                                ),
                                child: Center(
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    children: [
                      //contact information
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFFE4E8EF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A101828),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ]),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Contact information tenant',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white)),
                        ),
                      ),
                      Container(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              height: 10,
                            ),
                            Text.rich(TextSpan(text: 'First Name ', style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                              keyboardType: TextInputType.name,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r"[a-zA-Z\s]")), // Allows letters and spaces
                              ],
                              hintText: 'Enter first name',
                              controller: firstName,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text.rich(TextSpan(text: 'Last Name ', style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                              keyboardType: TextInputType.name,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r"[a-zA-Z\s]")), // Allows letters and spaces
                              ],
                              hintText: 'Enter last name',
                              controller: lastName,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text.rich(TextSpan(text: 'Phone Number ', style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                                PhoneNumberFormatter(),
                              ],
                              hintText: 'Enter phone number',
                              controller: phoneNumber,
                              otherController: workNumber,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the phone number';
                                }
                                return null;
                              },
                              phone: true,
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            _showalterNumber
                                ? Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        const Text('Work Number',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                                10),
                                            PhoneNumberFormatter(),
                                          ],
                                          keyboardType: TextInputType.number,
                                          hintText: 'Enter work number',
                                          controller: workNumber,
                                          otherController: phoneNumber,
                                          optional: true,
                                          phone: true,
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(),
                            if (_showalterNumber == false)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showalterNumber = !_showalterNumber;
                                  });
                                },
                                child: const Text('+Add alternative Phone',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2ec433))),
                              ),
                            if (_showalterNumber == true)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showalterNumber = !_showalterNumber;
                                  });
                                },
                                child: const Text('-Remove alternative Phone',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2ec433))),
                              ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text.rich(TextSpan(text: 'Email ', style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                            const SizedBox(
                              height: 10,
                            ),
                            CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                              keyboardType: TextInputType.emailAddress,
                              hintText: 'Enter Email',
                              controller: email,
                              email: true,
                              alterController: alterEmail,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an email';
                                } else if (!isValidEmail(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            _showalterEmail
                                ? Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        const Text('Alternative Email',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          hintText: 'Enter alternative email',
                                          controller: alterEmail,
                                          optional: true,
                                          email: true,
                                          alterController: email,
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(),
                            if (_showalterEmail == false)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showalterEmail = !_showalterEmail;
                                  });
                                },
                                child: const Text('+Add alternative Email',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2ec433))),
                              ),
                            if (_showalterEmail == true)
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _showalterEmail = !_showalterEmail;
                                  });
                                },
                                child: const Text('-Remove alternative Email',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2ec433))),
                              ),
                            const SizedBox(
                              height: 10,
                            ),
                            Text.rich(TextSpan(text: 'Password ', style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                    keyboardType: TextInputType.text,
                                    obscureText: !_obscureText,
                                    hintText: 'Enter password',
                                    controller: passWord,
                                    optional: true,
                                    validator: (value) {
                                      if (value == null) {
                                        return 'please enter password';
                                      }
                                      return null;
                                    },
                                    pass: true,
                                  ),
                                ),
                                const SizedBox(
                                    width:
                                        10), // Add some space between the widgets
                                Container(
                                  width: 38,
                                  height: 40,
                                  child: Center(
                                    child: GestureDetector(
                                      onTap: _toggleObscureText,
                                      child: FaIcon(
                                        _obscureText
                                            ? FontAwesomeIcons.eyeSlash
                                            : FontAwesomeIcons.eye,
                                        size: 20,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      const BoxShadow(
                                        color: Color(0xFFCED4DA),
                                        offset: Offset(1.0, 1.0),
                                        blurRadius: 8.0,
                                        spreadRadius: 1.0,
                                      ),
                                    ],
                                    border: Border.all(
                                        width: 0, color: Colors.white),
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showPersonalDetail = !_showPersonalDetail;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFE4E8EF)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A101828),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ]),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('+    Personal Information',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                      _showPersonalDetail
                          ? Container(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    height: 15,
                                  ),
                                  const Text('Date of Birth',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 0),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        boxShadow: [
                                          const BoxShadow(
                                            color: Color(0xFFCED4DA),
                                            offset: Offset(1.0,
                                                1.0), // Shadow offset to the bottom right
                                            blurRadius:
                                                8.0, // How much to blur the shadow
                                            spreadRadius:
                                                0.0, // How much the shadow should spread
                                          ),
                                        ],
                                        border: Border.all(
                                            width: 0, color: Colors.white),
                                        borderRadius:
                                            BorderRadius.circular(6.0)),
                                    child: TextFormField(
                                      style: const TextStyle(
                                        color: Color(0xFF8898aa), // Text color
                                        fontSize: 16.0, // Text size
                                        fontWeight:
                                            FontWeight.w400, // Text weight
                                      ),
                                      controller: _dateController,
                                      decoration: InputDecoration(
                                        hintStyle: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                            color: Color(0xFFb0b6c3)),
                                        isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0), border: InputBorder.none,
                                        // labelText: 'Select Date',
                                        hintText: 'YYYY-MM-DD',
                                        suffixIcon: IconButton(
                                          icon:
                                              const Icon(Icons.calendar_today),
                                          onPressed: () {
                                            _selectDate(context);
                                          },
                                        ),
                                      ),
                                      readOnly: true,
                                      onTap: () {
                                        _selectDate(context);
                                      },
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('TaxPayer ID',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(height: 10),
                                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                    keyboardType: TextInputType.text,
                                    hintText: 'Enter TaxPayer ID',
                                    controller: taxPayerId,
                                    optional: true,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('Comments',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                    height: 90,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0, vertical: 0),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        boxShadow: [
                                          const BoxShadow(
                                            color: Color(0xFFCED4DA),
                                            offset: Offset(1.0,
                                                1.0), // Shadow offset to the bottom right
                                            blurRadius:
                                                8.0, // How much to blur the shadow
                                            spreadRadius:
                                                0.0, // How much the shadow should spread
                                          ),
                                        ],
                                        border: Border.all(
                                            width: 0, color: Colors.white),
                                        borderRadius:
                                            BorderRadius.circular(6.0)),
                                    child: TextFormField(
                                        keyboardType: TextInputType.text,
                                        controller: comments,
                                        maxLines: 5,
                                        decoration: const InputDecoration(
                                          isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 0), border: InputBorder.none,
                                          hintStyle: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFFb0b6c3)),
                                          hintText: 'Enter the comment',
                                        )),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                ],
                              ),
                            )
                          : Container(),
                      const SizedBox(
                        height: 10,
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showEmergancyDetail = !_showEmergancyDetail;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFFE4E8EF)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A101828),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ]),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('+    Emergency Contact',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                      _showEmergancyDetail
                          ? Container(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(
                                    height: 15,
                                  ),
                                  const Text('Contact Name',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                    keyboardType: TextInputType.name,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(
                                          r"[a-zA-Z\s]")), // Allows letters and spaces
                                    ],
                                    hintText: 'Enter contact name',
                                    controller: contactName,
                                    optional: true,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('Relationship to Tenant',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                    keyboardType: TextInputType.text,
                                    hintText: 'Enter relationship to tenant',
                                    controller: relationToTenant,
                                    optional: true,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('Email',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                    keyboardType: TextInputType.emailAddress,
                                    hintText: 'Enter email',
                                    controller: emergencyEmail,
                                    optional: true,
                                    email: true,
                                    emrgencyController: alterEmail,
                                    alterController: email,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('Phone Number',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey)),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                      PhoneNumberFormatter(),
                                    ],
                                    hintText: 'Enter phone number',
                                    controller: emergencyPhoneNumber,
                                    optional: true,
                                    otherController: phoneNumber,
                                    businessController: workNumber,
                                    phone: true,
                                  ),
                                ],
                              ),
                            )
                          : Container(),
                      const SizedBox(
                        height: 30,
                      ),
                      if (isChecked == false)
                        Row(
                          children: [
                            const SizedBox(
                              width: 2,
                            ),
                            GestureDetector(
                              onTap: () {
                                if (_formKey.currentState!.validate()) {
                                  final tenant = Tenant(
                                    tenantFirstName: firstName.text.trim(),
                                    tenantLastName: lastName.text.trim(),
                                    tenantPhoneNumber: phoneNumber.text.trim(),
                                    tenantAlternativeNumber:
                                        workNumber.text.trim(),
                                    tenantEmail: email.text.trim(),
                                    tenantAlternativeEmail:
                                        alterEmail.text.trim(),
                                    tenantPassword: passWord.text.trim(),
                                    tenantBirthDate:
                                        _dateController.text.trim(),
                                    taxPayerId: taxPayerId.text.trim(),
                                    comments: comments.text.trim(),
                                    rentshare: "",
                                    emergencyContact: EmergencyContact(
                                      name: contactName.text.trim(),
                                      relation: relationToTenant.text.trim(),
                                      email: emergencyEmail.text.trim(),
                                      phoneNumber:
                                          emergencyPhoneNumber.text.trim(),
                                    ),
                                  );
                                  Provider.of<SelectedTenantsProvider>(context,
                                          listen: false)
                                      .addTenant(tenant);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.0),
                                child: Container(
                                  height: 40.0,
                                  width: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5.0),
                                    color: blueColor,
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.grey,
                                        offset: Offset(0.0, 1.0), //(x,y)
                                        blurRadius: 6.0,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      "Add",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.0),
                                child: Container(
                                  height: 40.0,
                                  width: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5.0),
                                    color: Colors.white,
                                    border: Border.all(color: blueColor),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "Cancel",
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
            const SizedBox(
              height: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class AddCosigner extends StatefulWidget {
  Cosigner? cosigner;
  int? index;
  AddCosigner({super.key, this.cosigner, this.index});

  @override
  State<AddCosigner> createState() => _AddCosignerState();
}

class _AddCosignerState extends State<AddCosigner> {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController phoneNumber = TextEditingController();
  final TextEditingController workNumber = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController alterEmail = TextEditingController();
  final TextEditingController streetAddrees = TextEditingController();
  final TextEditingController city = TextEditingController();
  final TextEditingController country = TextEditingController();
  final TextEditingController postalCode = TextEditingController();
  bool _showalterNumber = false;
  bool _showalterEmail = false;
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    if (widget.cosigner != null) {
      firstName.text = widget.cosigner!.firstName;
      lastName.text = widget.cosigner!.lastName;
      phoneNumber.text = widget.cosigner!.phoneNumber;
      workNumber.text = widget.cosigner!.workNumber;
      email.text = widget.cosigner!.email;
      alterEmail.text = widget.cosigner!.alterEmail;
      streetAddrees.text = widget.cosigner!.streetAddress;
      city.text = widget.cosigner!.city;
      country.text = widget.cosigner!.country;
      postalCode.text = widget.cosigner!.postalCode;
      _showalterNumber = widget.cosigner!.workNumber.isNotEmpty ? true : false;
      _showalterEmail = widget.cosigner!.alterEmail.isNotEmpty ? true : false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          const SizedBox(
            height: 10,
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFE4E8EF)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A101828),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]),
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Contact information cosigner',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white)),
            ),
          ),
          Container(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  Text.rich(TextSpan(text: 'First Name ', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                  const SizedBox(
                    height: 10,
                  ),
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    keyboardType: TextInputType.name,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s]")), // Allows letters and spaces
                    ],
                    hintText: 'Enter first name',
                    controller: firstName,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please enter the first name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text.rich(TextSpan(text: 'Last Name ', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                  const SizedBox(
                    height: 10,
                  ),
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    keyboardType: TextInputType.name,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s]")), // Allows letters and spaces
                    ],
                    hintText: 'Enter last name',
                    controller: lastName,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please enter the last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text.rich(TextSpan(text: 'Phone Number ', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                  const SizedBox(
                    height: 10,
                  ),
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    keyboardType: TextInputType.number,
                    hintText: 'Enter phone number',
                    controller: phoneNumber,
                    otherController: workNumber,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      PhoneNumberFormatter(),
                    ],
                    phone: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please enter the phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (_showalterNumber == false)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showalterNumber = !_showalterNumber;
                        });
                      },
                      child: const Text('+Add alternative Phone',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ec433))),
                    ),
                  if (_showalterNumber == true)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showalterNumber = !_showalterNumber;
                        });
                      },
                      child: const Text('-Remove alternative Phone',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ec433))),
                    ),
                  _showalterNumber
                      ? Container(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              const Text('Work Number',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                  PhoneNumberFormatter(),
                                ],
                                keyboardType: TextInputType.number,
                                hintText: 'Enter work number',
                                controller: workNumber,
                                otherController: phoneNumber,
                                optional: true,
                                phone: true,
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  const SizedBox(
                    height: 10,
                  ),
                  Text.rich(TextSpan(text: 'Email ', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey), children: const [TextSpan(text: '*', style: TextStyle(color: Colors.red))])),
                  const SizedBox(
                    height: 10,
                  ),
                  CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                    keyboardType: TextInputType.emailAddress,
                    hintText: 'Enter Email',
                    controller: email,
                    email: true,
                    alterController: alterEmail,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please enter email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (_showalterEmail == false)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showalterEmail = !_showalterEmail;
                        });
                      },
                      child: const Text('+Add alternative Email',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ec433))),
                    ),
                  if (_showalterEmail == true)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showalterEmail = !_showalterEmail;
                        });
                      },
                      child: const Text('-Remove alternative Email',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2ec433))),
                    ),
                  _showalterEmail
                      ? Container(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: 10,
                              ),
                              const Text('Alternative Email',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                keyboardType: TextInputType.emailAddress,
                                hintText: 'Enter alternative email',
                                controller: alterEmail,
                                alterController: email,
                                email: true,
                                optional: true,
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        )
                      : Container(),
                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
          ),
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Address',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: blueColor),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text('City',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(
                  height: 10,
                ),
                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                  keyboardType: TextInputType.text,
                  hintText: 'Enter city',
                  controller: city,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'please enter the city';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text('Country',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(
                  height: 10,
                ),
                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                  keyboardType: TextInputType.text,
                  hintText: 'Enter country',
                  controller: country,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'please enter country';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text('Zip code',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(
                  height: 10,
                ),
                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                  hintText: 'Enter zip code',
                  controller: postalCode,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'please enter zip code';
                    }
                    return null;
                  },
                ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 2,
                    ),
                    GestureDetector(
                      onTap: () {
                        if (_formKey.currentState!.validate()) {
                          if (widget.cosigner == null) {
                            final cosigner = Cosigner(
                              c_id: firstName.text.trim(),
                              firstName: firstName.text.trim(),
                              lastName: lastName.text.trim(),
                              phoneNumber: phoneNumber.text.trim(),
                              workNumber: workNumber.text.trim(),
                              email: email.text.trim(),
                              alterEmail: alterEmail.text.trim(),
                              streetAddress: streetAddrees.text.trim(),
                              city: city.text.trim(),
                              country: country.text.trim(),
                              postalCode: postalCode.text.trim(),
                            );
                            Provider.of<SelectedCosignersProvider>(context,
                                    listen: false)
                                .addCosigner(cosigner);
                          } else {
                            final cosigner = Cosigner(
                              //c_id : firstName.text,
                              firstName: firstName.text.trim(),
                              lastName: lastName.text.trim(),
                              phoneNumber: phoneNumber.text.trim(),
                              workNumber: workNumber.text.trim(),
                              email: email.text.trim(),
                              alterEmail: alterEmail.text.trim(),
                              streetAddress: streetAddrees.text.trim(),
                              city: city.text.trim(),
                              country: country.text.trim(),
                              postalCode: postalCode.text.trim(),
                            );
                            Provider.of<SelectedCosignersProvider>(context,
                                    listen: false)
                                .updateCosigner(cosigner, widget.index!);
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => Edit_lease(cosigner: cosigner),
                            //   ),
                            // );
                          }
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: Container(
                          height: 40.0,
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5.0),
                            color: blueColor,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.grey,
                                offset: Offset(0.0, 1.0), //(x,y)
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Add",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: Container(
                          height: 40.0,
                          width: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5.0),
                            color: Colors.white,
                            border: Border.all(color: blueColor),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
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
      ),
    );
  }
}

class CustomDropdown extends StatefulWidget {
  final List<String> items;
  final String? labelText;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String>? validator;

  /// When true, uses border instead of elevation/shadow and [dropdownHeight] for height (default 45).
  final bool useBorderStyle;
  final double? dropdownHeight;

  CustomDropdown({
    Key? key,
    required this.labelText,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    required this.validator,
    this.useBorderStyle = false,
    this.dropdownHeight,
  }) : super(key: key);

  @override
  _CustomDropdownState createState() => _CustomDropdownState();
}

class _CustomDropdownState extends State<CustomDropdown> {
  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.selectedValue,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              elevation: widget.useBorderStyle ? 0 : 2,
              borderRadius: BorderRadius.circular(8.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  isExpanded: true,
                  hint: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.labelText ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFb0b6c3),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  items: widget.items
                      .map((String item) => DropdownMenuItem<String>(
                            value: item,
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14,
                                // fontWeight: FontWeight.w400,
                                color: Color(0xFF152B51),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  value: state.value ?? widget.selectedValue,
                  onChanged: (value) {
                    setState(() {
                      widget.onChanged(value);
                      state.didChange(value);
                    });
                  },
                  buttonStyleData: ButtonStyleData(
                    height: widget.useBorderStyle
                        ? (widget.dropdownHeight ?? 50)
                        : (MediaQuery.of(context).size.width < 500 ? 45 : 55),
                    padding: const EdgeInsets.only(left: 0, right: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                      border: widget.useBorderStyle
                          ? Border.all(
                              color: const Color(0xFFCED4DA),
                              width: 1.0,
                            )
                          : null,
                      boxShadow: widget.useBorderStyle
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: const Offset(4, 4),
                                blurRadius: 3,
                              ),
                            ],
                    ),
                  ),
                  iconStyleData: const IconStyleData(
                    icon: Icon(
                      Icons.arrow_drop_down,
                    ),
                    iconSize: 24,
                    iconEnabledColor: Color(0xFFb0b6c3),
                    iconDisabledColor: Colors.grey,
                  ),
                  dropdownStyleData: DropdownStyleData(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.white,
                    ),
                    scrollbarTheme: ScrollbarThemeData(
                      radius: const Radius.circular(6),
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
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 8),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String reverseFormatDate(String inputDate) {
    final String trimmed = inputDate.trim();
    DateTime? parsedDate;

    // Controllers are written in the user's display format (provider
    // dateFormat, e.g. MM/dd/yyyy) or ISO — try those first so the API
    // always receives yyyy-MM-dd like the web sends.
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final List<String> formats = [
      'yyyy-MM-dd',
      dateProvider.dateFormat,
      'dd-MM-yyyy',
      'MM/dd/yyyy',
      'M/d/yyyy',
      'MM-dd-yyyy',
      'dd/MM/yyyy',
    ];

    for (final format in formats) {
      try {
        parsedDate = DateFormat(format).parseStrict(trimmed);
        break;
      } catch (_) {
        continue;
      }
    }

    if (parsedDate == null) {
      // Handle invalid date format or return an error
      throw FormatException("Invalid date format");
    }

    // Return the date in the yyyy-MM-dd format
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  }
}
