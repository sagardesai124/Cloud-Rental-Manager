import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
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
// import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';

import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/repository/lease.dart';
import 'package:three_zero_two_property/repository/properties.dart';

import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/clearable_date_picker.dart';
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';
import 'package:three_zero_two_property/widgets/drawer_tiles.dart';

import '../../../Model/tenants.dart';
import '../../../model/ApplicantModel.dart';
import '../../../model/cosigner.dart';
import '../../../model/edit_lease.dart';
import '../../../model/lease.dart';

import '../../../provider/lease_provider.dart';
import '../../../repository/tenants.dart';
import '../../../widgets/titleBar.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../provider/dateProvider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/add_tenant_cosigner_screen.dart';

class addLease3 extends StatefulWidget {
  final String? applicantId;
  final String? rentalId;
  final String? unitId;
  String? leaseId;

  addLease3(
      {Key? key, this.applicantId, this.rentalId, this.unitId, this.leaseId})
      : super(key: key);

  @override
  State<addLease3> createState() => _addLease3State();
}

class _addLease3State extends State<addLease3>
    with SingleTickerProviderStateMixin {
  late Future<List<Rentals>> futureRentalOwners;
  String? errormessagefordateissue;
  List<String> applicantIds = [];
  @override
  void initState() {
    super.initState();

    // Delay execution of setting values and loading units
    Future.delayed(const Duration(seconds: 1), () {
      // Ensure that renderId is properly set before proceeding
      if (widget.rentalId != null && widget.rentalId!.isNotEmpty) {
        setState(() {
          _selectedProperty = widget.rentalId!;
        });

        _loadUnits(widget.rentalId!);

        setState(() {
          _selectedUnit = widget.unitId;
        });
      }
    });


    if (widget.leaseId != null && widget.leaseId!.isNotEmpty) {
      setState(() {
        fetchDetails(widget.leaseId!);
      }); // Using widget.leaseId safely
    }

    futureRentalOwners = PropertiesRepository().fetchProperties();
    _loadProperties();
    _tabController = TabController(length: 2, vsync: this);
    _updateProRatedRent(_selectedRent ?? 'Monthly');
  }

  Future<void> fetchDetails(String leaseId) async {
    try {
      // Fetch lease details from the repository
      LeaseDetails fetchedDetails =
          await LeaseRepository()
              .fetchLeaseDetails(leaseId, applicantId: widget.applicantId);

      // Optional delay for demonstration purposes
      await Future.delayed(const Duration(seconds: 1));

      // Check if the widget is still mounted before calling setState
      if (mounted) {
        setState(() {

          // Update state variables
          _selectedProperty = fetchedDetails.rental.rentalId ?? "";
          renderId = fetchedDetails.rental.rentalId ?? "";
          // The rentals-list API is paginated and may not include this
          // rental — inject it so the dropdown can preselect it.
          _ensureRentalInProperties(fetchedDetails.rental.rentalId,
              fetchedDetails.rental.rentalAddress);
          // Preselect Lease Type when the lease carries one — guarded to
          // dropdown values so an unexpected API string can't crash it.
          if (leaseTypeitems.contains(fetchedDetails.lease.leaseType)) {
            _selectedLeaseType = fetchedDetails.lease.leaseType;
          }
          if (fetchedDetails.lease.startDate.isNotEmpty) {
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            startDateController.text =
                dateProvider.formatCurrentDate(fetchedDetails.lease.startDate);
          }
          if (fetchedDetails.lease.endDate.isNotEmpty) {
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            endDateController.text =
                dateProvider.formatCurrentDate(fetchedDetails.lease.endDate);
          }
          // Calculate rent cycle items
          if (fetchedDetails.lease.startDate != null &&
              fetchedDetails.lease.startDate != null)
            // rentCycleItemsDynamic(DateTime.parse(fetchedDetails.lease.endDate)
            //     .difference(DateTime.parse(fetchedDetails.lease.startDate))
            //     .inDays);
          // Update rent charges
          //  _selectedRent = fetchedDetails.rentCharges?.first.rentCycle ?? "";
          // rentMemo.text = fetchedDetails.rentCharges?.first.memo ?? "";
          if (fetchedDetails.tenant != null) {
            for (var t in fetchedDetails.tenant!) {
              applicantIds.add(t.applicantId!);
            }
          }

          // Handle uploaded files
          if (fetchedDetails.lease.uploadedFile != null &&
              fetchedDetails.lease.uploadedFile.isNotEmpty) {
            _uploadedFileNames.add(fetchedDetails.lease.uploadedFile.first);
          }

          Provider.of<SelectedTenantsProvider>(context, listen: false)
              .clearTenant();

          // Update tenants
          if (fetchedDetails.tenant != null) {
            for (int i = 0; i < fetchedDetails.tenant!.length; i++) {
              fetchedDetails.tenant![i].tenantId =
                  fetchedDetails.tenant![i].applicantId;
              Provider.of<SelectedTenantsProvider>(context, listen: false)
                  .addTenant(fetchedDetails.tenant![i]);
              // Provider.of<SelectedTenantsProvider>(context, listen: false)
              //     .rentShareControllers[i].text = fetchedDetails.tenant![i].rentshare.toString();
            }
          }

          // Update cosigners
          if (fetchedDetails.cosigner != null) {
            for (int i = 0; i < fetchedDetails.cosigner!.length; i++) {
              Provider.of<SelectedCosignersProvider>(context, listen: false)
                  .addCosigner(fetchedDetails.cosigner![i]);
            }
          }
        });

        // Load units after setting state
        _loadUnits(renderId);

        // Update selected unit
        if (mounted) {
          setState(() {
            _selectedUnit = fetchedDetails.lease.unitId;
          });
        }
      }
    } catch (e) {
      // Handle any errors that occur during the fetch
      logError('Failed to fetch lease details: $e');
    }
  }

//first container variable
  String selectedFrequency = 'Monthly';
  List<Tenant> selectedTenants = [];
  bool isChecked = false;
  bool isProRent = false;
  bool isAmountEntered = false;
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

  // Rental carried by the lease being edited/created from an applicant —
  // injected into [properties] when the paginated rentals list omits it.
  Map<String, String>? _injectedRental;

  void _ensureRentalInProperties(String? rentalId, String? address) {
    if (rentalId == null || rentalId.isEmpty) return;
    _injectedRental = {
      'rental_id': rentalId,
      'rental_adress':
          (address == null || address.isEmpty) ? rentalId : address,
    };
    if (!properties.any((p) => p['rental_id'] == rentalId)) {
      properties = [...properties, _injectedRental!];
    }
  }
  List<Map<String, String>> units = [];
  String? _selectedProperty;
  String? _selectedUnit;
  String? _selectedLeaseType;

  final TextEditingController startDateController = TextEditingController();
  DateTime? _startDate;
  final TextEditingController endDateController = TextEditingController();
  DateTime? _endDate;

  //second container variables
  String? _selectedRent;
  final TextEditingController rentAmount = TextEditingController();
  final TextEditingController rentNextDueDate = TextEditingController();
  final TextEditingController rentMemo = TextEditingController();

  //changes variables
  bool _showUnitDropdown = false;
  Future<void> _loadProperties() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

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
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        List<Map<String, String>> addresses = jsonResponse.map((data) {
          return {
            'rental_id': data['rental_id'].toString(),
            'rental_adress': data['rental_adress'].toString(),
          };
        }).toList();

        // Guard against duplicate rental_ids from the API — the dropdown
        // asserts when a value matches more than one item.
        final seenRentalIds = <String>{};
        addresses = addresses
            .where((a) => seenRentalIds.add(a['rental_id'] ?? ''))
            .toList();

        // Sort properties alphabetically by address (A-Z)
        addresses.sort((a, b) => (a['rental_adress'] ?? '')
            .toLowerCase()
            .compareTo((b['rental_adress'] ?? '').toLowerCase()));

        setState(() {
          properties = addresses;
          // Re-apply the lease's rental if the paginated list misses it,
          // so the preselected value stays valid.
          if (_injectedRental != null &&
              !properties.any((p) =>
                  p['rental_id'] == _injectedRental!['rental_id'])) {
            properties = [...properties, _injectedRental!];
          }
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
    try {
      final response = await apiGet(
          Uri.parse('$Api_url/api/unit/rental_unit_dropdown/$rentalId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM ${prefs.getString('staff_id') ?? id}",
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
  bool _debitCardAccepted = false; // Debit card checkbox
  // Payment Settings section (web parity) — lease-level, applied to all tenants
  bool _enableDebitCardFeeOverride = false; // Enable Debit Card Fee Override
  final TextEditingController _overrideFeeController = TextEditingController();
  bool _allowAch = true; // Allowed Payment Methods: ACH
  bool _allowCard = true; // Allowed Payment Methods: Card
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
  List<String> rentCycleitems = [
    'Daily',
    'Weekly',
    'Every two weeks',
    'Monthly',
    'Every two months',
    'Quarterly',
    'Yearly',
    'Semi Monthly'
  ];

  rentCycleItemsDynamic(int days) {
    if (days == 1) {
      rentCycleitems = ['Daily'];
    } else if (days >= 365) {
      rentCycleitems = [
        'Daily',
        'Weekly',
        'Every two weeks',
        'Monthly',
        'Every two months',
        'Quarterly',
        'Yearly',
        'Semi Monthly',
      ];
    } else if (days >= 93) {
      rentCycleitems = [
        'Daily',
        'Weekly',
        'Semi Monthly',
        'Every two weeks',
        'Monthly',
        'Every two months',
        'Quarterly',
      ];
    } else if (days >= 62) {
      rentCycleitems = [
        'Daily',
        'Weekly',
        'Semi Monthly',
        'Every two weeks',
        'Monthly',
        'Every two months',
      ];
    } else if (days >= 32) {
      rentCycleitems = [
        'Daily',
        'Weekly',
        'Semi Monthly',
        'Every two weeks',
        'Monthly',
      ];
    } else if (days >= 15) {
      rentCycleitems = [
        'Daily',
        'Weekly',
        'Semi Monthly',
        'Every two weeks',
      ];
    } else if (days >= 7) {
      rentCycleitems = [
        'Daily',
        'Weekly',
      ];
    }
    setState(() {});
  }

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
      case 'Semi Monthly':
        // Get the number of days in the current month
        int lastDayOfMonth =
            DateTime(startDate.year, startDate.month + 1, 0).day;
        // Determine the middle of the month
        int middleOfMonth = (lastDayOfMonth / 2).floor();

        if (startDate.day <= middleOfMonth) {
          // If today is in the first half (1st to mid-month), set the next due date to the middle of this month
          return DateTime(startDate.year, startDate.month, middleOfMonth);
        } else {
          // If today is in the second half (mid+1 to end of month), set the next due date to the middle of next month
          if (startDate.month == 12) {
            // Special case for December, next due date should be January 1st
            return DateTime(startDate.year + 1, 1, middleOfMonth);
          }
          return DateTime(startDate.year, startDate.month + 1, middleOfMonth);
        }
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

  // void _updateProRatedRent() {
  //   if (isProRent && isAmountEntered && rentNextDueDate.text.isNotEmpty) {
  //     // Get the current date
  //     DateTime currentDate = DateTime.now();
  //
  //     // Parse the next due date
  //     DateTime nextDueDate = DateFormat('yyyy-MM-dd').parse(rentNextDueDate.text);
  //
  //     // Calculate the number of days left until the next due date
  //     int daysLeft = nextDueDate.difference(currentDate).inDays + 1; // Include today in the count
  //
  //     // Get the total rent amount
  //     double totalRent = double.tryParse(rentAmount.text) ?? 0.0;
  //
  //     // Calculate the total days in the current month
  //     int totalDaysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day;
  //
  //     // Calculate daily rent
  //     double dailyRent = totalRent / totalDaysInMonth;
  //
  //     // Calculate pro-rated rent
  //     double proRatedRent = dailyRent * daysLeft;
  //
  //     // Update the pro-rated rent field with the calculated pro-rated rent
  //     proRatedRentController.text = proRatedRent.toStringAsFixed(2); // Display with 2 decimal places
  //   } else {
  //     // Clear the pro-rated rent field if conditions are not met
  //     proRatedRentController.text = "0.00"; // Reset to 0.00 if not applicable
  //   }
  // }

  void _updateProRatedRent(String frequency) {
    if (isProRent &&
        isAmountEntered &&
        rentNextDueDate.text.isNotEmpty &&
        startDateController.text.isNotEmpty &&
        endDateController.text.isNotEmpty) {
      try {
        // Parse the start date from the TextField (instead of using current date)
        // Convert display format to API format for parsing
        String convertToApiFormat(String displayDate) {
          if (displayDate.isEmpty) return "";
          try {
            final dateProvider =
                Provider.of<DateProvider>(context, listen: false);
            // Parse the display format and convert to yyyy-MM-dd
            DateTime date =
                DateFormat(dateProvider.dateFormat).parse(displayDate);
            return DateFormat('yyyy-MM-dd').format(date);
          } catch (e) {
            return displayDate; // Return as is if parsing fails
          }
        }

        DateTime currentDate = DateFormat('yyyy-MM-dd')
            .parse(convertToApiFormat(startDateController.text));
        DateTime nextDueDate = DateFormat('yyyy-MM-dd')
            .parse(convertToApiFormat(rentNextDueDate.text));

        double totalRent = double.tryParse(rentAmount.text) ?? 0.0;

        // Debug prints

        // Validate rent and dates
        if (totalRent <= 0 || !nextDueDate.isAfter(currentDate)) {
          setState(() {
            proRatedRentController.text = "0.00";
          });
          return;
        }

        // Calculate days left, including the current day
        int daysLeft = nextDueDate.difference(currentDate).inDays;

        // WEB PARITY (RentRollLeasing.jsx): for every NON-monthly cycle web
        // counts the move-in day itself — `endDate.diff(startDate,'days') + 1`.
        // Monthly deliberately keeps the exclusive count: web computes Monthly
        // by a different route (computeProratedFirstMonth = days remaining in
        // the start month, inclusive), which already equals this exclusive
        // difference, so adding a day there would overcharge the first month.
        final int inclusiveDays = daysLeft + 1;

        // Calculate pro-rated rent
        double proRatedRent = 0.0;

        // Get total days in the current month
        int totalDaysInMonth =
            _getDaysInMonth(nextDueDate.year, currentDate.month);
        // print("Total Days in Month: $totalDaysInMonth");

        // Define total days in other periods
        int totalDaysInYear = 365; // For non-leap years
        int totalDaysInQuarter = totalDaysInMonth * 3; // 3 months period

        switch (frequency) {
          case 'Daily':
            proRatedRent = (totalRent / 1) * inclusiveDays;
            break;
          case 'Weekly':
            proRatedRent = (totalRent / 7) * inclusiveDays;
            break;
          case 'Every two weeks':
            proRatedRent = (totalRent / 14) * inclusiveDays;
            break;
          // case 'Monthly':
          //   proRatedRent = (totalRent / totalDaysInMonth) * daysLeft;
          //   break;
          case 'Monthly':
            int totalDaysInMonth =
                _getDaysInMonth(currentDate.year, currentDate.month);
            proRatedRent = (totalRent / totalDaysInMonth) * daysLeft;
            break;
          case 'Every two months':
            // WEB PARITY (RentRollLeasing.jsx): period length is the current
            // month plus the next one, and the rent IS prorated across it. The
            // day count was previously computed and then discarded, charging a
            // full two-month rent whatever the move-in date.
            // DateTime(year, month + n, 1) rolls a December start into January
            // of the next year, the same way web's `new Date(y, m + n, 0)` does.
            final DateTime secondMonth =
                DateTime(currentDate.year, currentDate.month + 1, 1);
            int totalDaysInTwoMonths =
                _getDaysInMonth(currentDate.year, currentDate.month) +
                    _getDaysInMonth(secondMonth.year, secondMonth.month);
            proRatedRent = totalDaysInTwoMonths > 0
                ? (totalRent / totalDaysInTwoMonths) * inclusiveDays
                : 0.0;
            break;
          case 'Quarterly':
            // WEB PARITY: count the current month and the next two, FORWARD
            // from the move-in month. This previously counted backwards from
            // the next due date, so `month - 1` / `month - 2` became 0 and -1
            // in January and February with no year rollover.
            final DateTime quarterMonth2 =
                DateTime(currentDate.year, currentDate.month + 1, 1);
            final DateTime quarterMonth3 =
                DateTime(currentDate.year, currentDate.month + 2, 1);
            int totalDaysInQuarter =
                _getDaysInMonth(currentDate.year, currentDate.month) +
                    _getDaysInMonth(quarterMonth2.year, quarterMonth2.month) +
                    _getDaysInMonth(quarterMonth3.year, quarterMonth3.month);

            if (totalDaysInQuarter > 0) {
              // Cents are kept, matching web's `.toFixed(2)`; the previous
              // roundToDouble() snapped the quarterly figure to whole dollars.
              proRatedRent = (totalRent / totalDaysInQuarter) * inclusiveDays;
            } else {
              proRatedRent = 0.0; // Fallback in case of an error
            }
            break;
          case 'Semi Monthly':
            // Calculate the semi-monthly due date
            int midMonth =
                _getDaysInMonth(currentDate.year, currentDate.month) > 30
                    ? 15
                    : 14; // Handle shorter months like February

            // If today is before or on the mid-month date, calculate for the first half
            if (currentDate.day <= midMonth) {
              // First half of the month (1st to mid-month)
              proRatedRent = (totalRent / midMonth) * inclusiveDays;
            } else {
              // Second half of the month (after mid-month)
              int remainingDays =
                  _getDaysInMonth(currentDate.year, currentDate.month) -
                      midMonth;
              proRatedRent = (totalRent / remainingDays) * inclusiveDays;
            }
            break;
          case 'Yearly':
            proRatedRent = (totalRent / totalDaysInYear) * inclusiveDays;
            break;
          default:
            proRatedRent = 0.0;
        }

        // Update text field with calculated value
        setState(() {
          proRatedRentController.text = proRatedRent.toStringAsFixed(2);
        });
      } catch (e) {
        // Handle unexpected errors
        setState(() {
          proRatedRentController.text = "Error";
        });
        logError("Error occurred while calculating pro-rated rent: $e");
      }
    }
  }

  int _getDaysInMonth(int year, int month) {
    // Get the number of days in the month considering leap years for February
    switch (month) {
      case 1: // January
      case 3: // March
      case 5: // May
      case 7: // July
      case 8: // August
      case 10: // October
      case 12: // December
        return 31;
      case 4: // April
      case 6: // June
      case 9: // September
      case 11: // November
        return 30;
      case 2: // February
        return _isLeapYear(year) ? 29 : 28;
      default:
        return 30;
    }
  }

  bool _isLeapYear(int year) {
    // Leap year is divisible by 4, but not divisible by 100 unless divisible by 400
    return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
  }

  final TextEditingController proRatedRentController = TextEditingController();

  String? selectedValue;

  late TabController _tabController;
  TextEditingController rentShareControllers = TextEditingController();

  @override
  void dispose() {
    _propertySearchController.dispose();
    _tabController.dispose();
    // Dispose all focus nodes
    for (var focusNode in _rentShareFocusNodes) {
      focusNode.dispose();
    }
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

  List<Map<String, String>> formDataOneTimeList = [];

  void _showPopupForm(BuildContext context, String rent,
      {Map<String, String>? initialData, int? index}) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: EdgeInsets.zero,
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
                  } else {
                    // Add new item
                    formDataRecurringList.add(data);
                    Fluttertoast.showToast(
                        msg: 'Recurring Charge Added Successfully');
                  }
                  Navigator.pop(context);
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
      // allowedExtensions: ['pdf'],
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
  //for rentshare
  String? _errorMessage;
  String? _errorMessagetenants;

  // FocusNode for keyboard actions - will be created dynamically for each field
  List<FocusNode> _rentShareFocusNodes = [];

  // Method to clean up focus nodes
  void _cleanupFocusNodes() {
    final selectedTenants =
        Provider.of<SelectedTenantsProvider>(context, listen: false)
            .selectedTenants;
    // Dispose excess focus nodes if we have more than needed
    while (_rentShareFocusNodes.length > selectedTenants.length) {
      _rentShareFocusNodes.removeLast().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    _cleanupFocusNodes(); // Clean up focus nodes on each build
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
        'ecArray': (tenant.emergencyContacts != null && tenant.emergencyContacts!.isNotEmpty)
            ? jsonEncode(tenant.emergencyContacts!.map((e) => {'name': e.name ?? '', 'relation': e.relation ?? '', 'email': e.email ?? '', 'phoneNumber': e.phoneNumber ?? ''}).toList())
            : '',
        'enableOverrideFee': tenant.enableoverrideFee != null ? tenant.enableoverrideFee.toString() : '',
        'overrideFee': tenant.overRideFee != null ? tenant.overRideFee.toString() : '',
        'allowAch': tenant.allowAch != null ? tenant.allowAch.toString() : '',
        'allowCard': tenant.allowCard != null ? tenant.allowCard.toString() : '',
        'tenantId': tenant.tenantId ?? "",
        'tenant_residentStatus': tenant.tenant_residentStatus.toString(),
        'firstName': tenant.tenantFirstName ?? "",
        'lastName': tenant.tenantLastName ?? "",
        'passWord': tenant.tenantPassword ?? '',
        if (tenant.rentalUnit != null) 'rental_unit': tenant.rentalUnit!,
        'phoneNumber': tenant.tenantPhoneNumber ?? "",
        'workNumber': tenant.tenantAlternativeNumber ?? "",
        'email': tenant.tenantEmail ?? "",
        'alterEmail': tenant.tenantAlternativeEmail ?? "",
        'streetAddress': tenant.rentalAddress ?? "",
        'comments': tenant.comments ?? '',
        'dob': tenant.tenantBirthDate ?? '',
        'taxPayerId': tenant.taxPayerId ?? '',
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
    bool hasSelectedTenants = Provider.of<SelectedTenantsProvider>(context)
        .selectedTenants
        .isNotEmpty;
    bool hasSelectedApplicants = Provider.of<SelectedApplicantProvider>(context)
        .selectedApplicant
        .isNotEmpty;
    bool leasepay = false;
    bool creditcard = false;
    bool debitcard = false;
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Leases",
        dropdown: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 25,
              ),
              Padding(
                padding: const EdgeInsets.all(5.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.0),
                  child: Container(
                    height: 50.0,
                    padding: const EdgeInsets.only(top: 10, left: 10),
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
                      "Add Lease",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              Padding(
                padding: EdgeInsets.only(
                    left: MediaQuery.of(context).size.width < 500 ? 15 : 35,
                    right: MediaQuery.of(context).size.width < 500 ? 15 : 35),
                child: Container(
                  child: Column(
                    // crossAxisAlignment: CrossAxisAlignment.start,
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
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          DropdownButtonHideUnderline(
                                            child: DropdownButtonFormField2<
                                                String>(
                                              // FormField caches its initial
                                              // value — key it so the async
                                              // prefill actually displays.
                                              key: ValueKey(
                                                  'property-$_selectedProperty-${properties.length}'),
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
                                              items: properties.map((property) {
                                                return DropdownMenuItem<String>(
                                                  value: property['rental_id'],
                                                  child: Text(
                                                    property['rental_adress']!,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                      color: Color(0xFF152B51),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              // Only preselect when the id is
                                              // present exactly once, else the
                                              // dropdown asserts and crashes.
                                              value: properties
                                                          .where((p) =>
                                                              p['rental_id'] ==
                                                              _selectedProperty)
                                                          .length ==
                                                      1
                                                  ? _selectedProperty
                                                  : null,
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedProperty = value;
                                                  _selectedUnit =
                                                      null; // Reset _selectedUnit when property changes
                                                  _showUnitDropdown = false;
                                                  state.didChange(
                                                      value); // Notify the FormField that the value has changed
                                                  renderId = value.toString();

                                                  _loadUnits(value!);
                                                });
                                                state.reset();
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
                                      padding: EdgeInsets.only(top: 0.0),
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
                                                // FormField caches its initial
                                                // value — key it so the async
                                                // prefill actually displays.
                                                key: ValueKey(
                                                    'unit-$_selectedUnit-${units.length}'),
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
                              CustomDropdown(
                                useBorderStyle: true,
                                validator: (value) {
                                  if (_selectedLeaseType == null) {
                                    return 'Please select a lease';
                                  }
                                  return null;
                                },
                                labelText: 'Select Lease Type',
                                items: leaseTypeitems,
                                selectedValue: _selectedLeaseType,
                                onChanged: (String? value) {
                                  setState(() {
                                    _selectedLeaseType = value;
                                  });
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
                                    icon: const Icon(Icons.date_range_rounded),
                                  ),
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
                              if (MediaQuery.of(context).size.width < 500 &&
                                  errormessagefordateissue != null)
                                Text(errormessagefordateissue!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red)),
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
                                  onTap: () {
                                    _selectEndDate(context);
                                  },
                                  readOnnly: true,
                                  suffixIcon: ClearableDateSuffix(
                                    controller: endDateController,
                                    icon: Icons.date_range_rounded,
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
                                              onTap: () async {
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
                                              },
                                              readOnnly: true,
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
                                              optional: true,
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
                      //lease
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
                                          builder: (_) => const AddTenantCosignerScreen(),
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
                              const SizedBox(height: 8.0),
                              if (Provider.of<SelectedTenantsProvider>(context)
                                  .selectedTenants
                                  .isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 13),
                                  child: Text(
                                    'Tenants:',
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
                              // if (hasSelectedTenants || hasSelectedApplicants)
                              //   Padding(
                              //     padding:
                              //         const EdgeInsets.only(left: 4, right: 4),
                              //     child: Column(
                              //       crossAxisAlignment:
                              //           CrossAxisAlignment.start,
                              //       children: [
                              //         Table(
                              //           border: TableBorder.all(
                              //             width: 1,
                              //             color: const Color.fromRGBO(
                              //                 21, 43, 83, 1),
                              //           ),
                              //           columnWidths: const {
                              //             0: FlexColumnWidth(2),
                              //             1: FlexColumnWidth(2),
                              //             2: FlexColumnWidth(1.3),
                              //           },
                              //           children: [
                              //             TableRow(
                              //               decoration: BoxDecoration(
                              //                 color: blueColor,
                              //               ),
                              //               children: [
                              //                 Padding(
                              //                   padding:
                              //                       const EdgeInsets.all(8.0),
                              //                   child: Text(
                              //                     'Name',
                              //                     style: TextStyle(
                              //                       color: Colors.white,
                              //                       fontWeight: FontWeight.bold,
                              //                       fontSize:
                              //                           MediaQuery.of(context)
                              //                                       .size
                              //                                       .width <
                              //                                   500
                              //                               ? 14
                              //                               : 20,
                              //                     ),
                              //                   ),
                              //                 ),
                              //                 Padding(
                              //                   padding:
                              //                       const EdgeInsets.all(8.0),
                              //                   child: Text(
                              //                     'Rent Share',
                              //                     style: TextStyle(
                              //                       color: Colors.white,
                              //                       fontWeight: FontWeight.bold,
                              //                       fontSize:
                              //                           MediaQuery.of(context)
                              //                                       .size
                              //                                       .width <
                              //                                   500
                              //                               ? 14
                              //                               : 20,
                              //                     ),
                              //                   ),
                              //                 ),
                              //                 Padding(
                              //                   padding:
                              //                       const EdgeInsets.all(8.0),
                              //                   child: Text(
                              //                     'Action',
                              //                     style: TextStyle(
                              //                       color: Colors.white,
                              //                       fontWeight: FontWeight.bold,
                              //                       fontSize:
                              //                           MediaQuery.of(context)
                              //                                       .size
                              //                                       .width <
                              //                                   500
                              //                               ? 14
                              //                               : 20,
                              //                     ),
                              //                   ),
                              //                 ),
                              //               ],
                              //             ),
                              //             // Tenant Rows
                              //             if (hasSelectedTenants)
                              //               ...Provider.of<
                              //                   SelectedTenantsProvider>(
                              //                   context)
                              //                   .selectedTenants
                              //                   .asMap()
                              //                   .entries
                              //                   .map((entry) {
                              //                 final index = entry.key;
                              //                 final tenant = entry.value;
                              //                 final controller = Provider.of<
                              //                     SelectedTenantsProvider>(
                              //                     context)
                              //                     .rentShareControllers[index];
                              //
                              //                 return TableRow(
                              //                   children: [
                              //                     Padding(
                              //                       padding:
                              //                       const EdgeInsets.only(
                              //                           left: 10, top: 15),
                              //                       child: Text(
                              //                         '${tenant.tenantFirstName} ${tenant.tenantLastName}',
                              //                         style: TextStyle(
                              //                           fontSize:
                              //                           MediaQuery.of(context)
                              //                               .size
                              //                               .width <
                              //                               500
                              //                               ? 14
                              //                               : 18,
                              //                           fontWeight:
                              //                           FontWeight.w700,
                              //                           color:
                              //                           blueColor
                              //
                              //
                              //                           ,
                              //                         ),
                              //                       ),
                              //                     ),
                              //                     Padding(
                              //                       padding:
                              //                       const EdgeInsets.all(8.0),
                              //                       child: Material(
                              //                         elevation: 0,
                              //                         borderRadius:
                              //                         BorderRadius.circular(
                              //                             8),
                              //                         child: Container(
                              //                           height:
                              //                           MediaQuery.of(context)
                              //                               .size
                              //                               .width <
                              //                               500
                              //                               ? 45
                              //                               : 50,
                              //                           width:
                              //                           MediaQuery.of(context)
                              //                               .size
                              //                               .width <
                              //                               500
                              //                               ? 70
                              //                               : 400,
                              //                           decoration: BoxDecoration(
                              //                             color: Colors.white,
                              //                             borderRadius:
                              //                             BorderRadius
                              //                                 .circular(8),
                              //                             border: Border.all(
                              //                               color:
                              //                               Colors.grey[300]!,
                              //                               width: 1,
                              //                             ),
                              //                           ),
                              //                           child: Center(
                              //                             child:
                              //                             Padding(
                              //                               padding:
                              //                               const EdgeInsets
                              //                                   .only(
                              //                                   left: 10,
                              //                                   bottom: 7),
                              //                               child: TextField(
                              //                                 controller:
                              //                                 controller,
                              //                                 style: TextStyle(
                              //                                   fontSize: MediaQuery.of(
                              //                                       context)
                              //                                       .size
                              //                                       .width <
                              //                                       500
                              //                                       ? 16
                              //                                       : 16,
                              //                                   fontWeight:
                              //                                   FontWeight
                              //                                       .bold,
                              //                                   color:
                              //                                   Colors.black,
                              //                                 ),
                              //                                 onChanged: (value) {
                              //                                   double
                              //                                   enteredValue =
                              //                                       double.tryParse(
                              //                                           value) ??
                              //                                           0;
                              //                                   if (enteredValue >
                              //                                       100) {
                              //                                     controller
                              //                                         .text =
                              //                                     '100';
                              //                                     controller
                              //                                         .selection =
                              //                                         TextSelection
                              //                                             .fromPosition(
                              //                                           TextPosition(
                              //                                               offset: controller
                              //                                                   .text
                              //                                                   .length),
                              //                                         );
                              //                                   }
                              //                                   Provider.of<SelectedTenantsProvider>(
                              //                                       context,
                              //                                       listen:
                              //                                       false)
                              //                                       .validateRentShares();
                              //
                              //                                   final provider =
                              //                                   Provider.of<
                              //                                       SelectedTenantsProvider>(
                              //                                       context,
                              //                                       listen:
                              //                                       false);
                              //                                   final rentShareControllers =
                              //                                       provider
                              //                                           .rentShareControllers;
                              //                                   double
                              //                                   totalRentShare =
                              //                                   0.0;
                              //                                   for (var controller
                              //                                   in rentShareControllers) {
                              //                                     double
                              //                                     rentShare =
                              //                                         double.tryParse(
                              //                                             controller.text) ??
                              //                                             0.0;
                              //                                     totalRentShare +=
                              //                                         rentShare;
                              //                                   }
                              //                                   if (totalRentShare !=
                              //                                       100.0) {
                              //                                     setState(() {
                              //                                       _errorMessage =
                              //                                       'Total rent share must equal 100';
                              //                                     });
                              //                                   }
                              //                                   else{
                              //                                     setState(() {
                              //                                       _errorMessage = null;
                              //                                     });
                              //                                   }
                              //                                 },
                              //                                 keyboardType:
                              //                                 TextInputType
                              //                                     .number,
                              //                                 decoration:
                              //                                 InputDecoration(
                              //                                   hintText: "0",
                              //                                   hintStyle:
                              //                                   TextStyle(
                              //                                     fontSize: MediaQuery.of(context)
                              //                                         .size
                              //                                         .width <
                              //                                         500
                              //                                         ? 16
                              //                                         : 16,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold,
                              //                                     color: Colors
                              //                                         .black,
                              //                                   ),
                              //                                   border:
                              //                                   InputBorder
                              //                                       .none,
                              //                                   contentPadding:
                              //                                   EdgeInsets
                              //                                       .symmetric(
                              //                                       vertical:
                              //                                       8),
                              //                                 ),
                              //                               ),
                              //                             ),
                              //                           ),
                              //                         ),
                              //                       ),
                              //                     ),
                              //                     Padding(
                              //                       padding:
                              //                       const EdgeInsets.only(
                              //                           top: 15),
                              //                       child: Row(
                              //                         mainAxisAlignment:
                              //                         MainAxisAlignment
                              //                             .center,
                              //                         crossAxisAlignment:
                              //                         CrossAxisAlignment
                              //                             .center,
                              //                         children: [
                              //                           InkWell(
                              //                             onTap: () {
                              //                               Provider.of<SelectedTenantsProvider>(
                              //                                   context,
                              //                                   listen: false)
                              //                                   .removeTenant(
                              //                                   tenant);
                              //                             },
                              //                             child: Icon(
                              //                               Icons.delete,
                              //                               color: const Color
                              //                                   .fromRGBO(
                              //                                   21, 43, 83, 1),
                              //                               size: MediaQuery.of(
                              //                                   context)
                              //                                   .size
                              //                                   .width <
                              //                                   500
                              //                                   ? 18
                              //                                   : 25,
                              //                             ),
                              //                           ),
                              //                         ],
                              //                       ),
                              //                     ),
                              //                   ],
                              //                 );
                              //               }).toList(),
                              //             // Applicant Rows
                              //             if (hasSelectedApplicants)
                              //               ...Provider.of<
                              //                           SelectedApplicantProvider>(
                              //                       context)
                              //                   .selectedApplicant
                              //                   .asMap()
                              //                   .entries
                              //                   .map((entry) {
                              //                 final index = entry.key;
                              //                 final applicant = entry.value;
                              //                 final controller = Provider.of<
                              //                     SelectedApplicantProvider>(
                              //                     context)
                              //                     .rentShareControllers[index];
                              //
                              //                 return TableRow(
                              //                   children: [
                              //                     Padding(
                              //                       padding:
                              //                           const EdgeInsets.only(
                              //                               left: 20, top: 15),
                              //                       child: Text(
                              //                         '${applicant.applicantFirstName} ${applicant.applicantLastName}',
                              //                         style: TextStyle(
                              //                           fontSize: MediaQuery.of(
                              //                                           context)
                              //                                       .size
                              //                                       .width <
                              //                                   500
                              //                               ? 14
                              //                               : 18,
                              //                           fontWeight:
                              //                               FontWeight.w700,
                              //                           color: blueColor,
                              //                         ),
                              //                       ),
                              //                     ),
                              //                     Padding(
                              //                       padding:
                              //                       const EdgeInsets.all(8.0),
                              //                       child: Material(
                              //                         elevation: 0,
                              //                         borderRadius:
                              //                         BorderRadius.circular(
                              //                             8),
                              //                         child: Container(
                              //                           height:
                              //                           MediaQuery.of(context)
                              //                               .size
                              //                               .width <
                              //                               500
                              //                               ? 45
                              //                               : 50,
                              //                           width:
                              //                           MediaQuery.of(context)
                              //                               .size
                              //                               .width <
                              //                               500
                              //                               ? 70
                              //                               : 400,
                              //                           decoration: BoxDecoration(
                              //                             color: Colors.white,
                              //                             borderRadius:
                              //                             BorderRadius
                              //                                 .circular(8),
                              //                             border: Border.all(
                              //                               color:
                              //                               Colors.grey[300]!,
                              //                               width: 1,
                              //                             ),
                              //                           ),
                              //                           child: Center(
                              //                             child:
                              //                             Padding(
                              //                               padding:
                              //                               const EdgeInsets
                              //                                   .only(
                              //                                   left: 10,
                              //                                   bottom: 7),
                              //                               child: TextField(
                              //                                 controller:
                              //                                 controller,
                              //                                 style: TextStyle(
                              //                                   fontSize: MediaQuery.of(
                              //                                       context)
                              //                                       .size
                              //                                       .width <
                              //                                       500
                              //                                       ? 16
                              //                                       : 16,
                              //                                   fontWeight:
                              //                                   FontWeight
                              //                                       .bold,
                              //                                   color:
                              //                                   Colors.black,
                              //                                 ),
                              //                                 onChanged: (value) {
                              //                                   double
                              //                                   enteredValue =
                              //                                       double.tryParse(
                              //                                           value) ??
                              //                                           0;
                              //                                   if (enteredValue >
                              //                                       100) {
                              //                                     controller
                              //                                         .text =
                              //                                     '100';
                              //                                     controller
                              //                                         .selection =
                              //                                         TextSelection
                              //                                             .fromPosition(
                              //                                           TextPosition(
                              //                                               offset: controller
                              //                                                   .text
                              //                                                   .length),
                              //                                         );
                              //                                   }
                              //                                   Provider.of<SelectedApplicantProvider>(
                              //                                       context,
                              //                                       listen:
                              //                                       false)
                              //                                       .validateRentShares();
                              //
                              //                                   final provider =
                              //                                   Provider.of<
                              //                                       SelectedApplicantProvider>(
                              //                                       context,
                              //                                       listen:
                              //                                       false);
                              //                                   final rentShareControllers =
                              //                                       provider
                              //                                           .rentShareControllers;
                              //                                   double
                              //                                   totalRentShare =
                              //                                   0.0;
                              //                                   for (var controller
                              //                                   in rentShareControllers) {
                              //                                     double
                              //                                     rentShare =
                              //                                         double.tryParse(
                              //                                             controller.text) ??
                              //                                             0.0;
                              //                                     totalRentShare +=
                              //                                         rentShare;
                              //                                   }
                              //                                   if (totalRentShare !=
                              //                                       100.0) {
                              //                                     setState(() {
                              //                                       _errorMessage =
                              //                                       'Total rent share must equal 100';
                              //                                     });
                              //                                   }
                              //                                   else{
                              //                                     setState(() {
                              //                                       _errorMessage = null;
                              //                                     });
                              //                                   }
                              //                                 },
                              //                                 keyboardType:
                              //                                 TextInputType
                              //                                     .number,
                              //                                 decoration:
                              //                                 InputDecoration(
                              //                                   hintText: "0",
                              //                                   hintStyle:
                              //                                   TextStyle(
                              //                                     fontSize: MediaQuery.of(context)
                              //                                         .size
                              //                                         .width <
                              //                                         500
                              //                                         ? 16
                              //                                         : 16,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold,
                              //                                     color: Colors
                              //                                         .black,
                              //                                   ),
                              //                                   border:
                              //                                   InputBorder
                              //                                       .none,
                              //                                   contentPadding:
                              //                                   EdgeInsets
                              //                                       .symmetric(
                              //                                       vertical:
                              //                                       8),
                              //                                 ),
                              //                               ),
                              //                             ),
                              //                           ),
                              //                         ),
                              //                       ),
                              //                     ),
                              //                     Padding(
                              //                       padding:
                              //                       const EdgeInsets.only(
                              //                           top: 15),
                              //                       child: Row(
                              //                         mainAxisAlignment:
                              //                         MainAxisAlignment
                              //                             .center,
                              //                         crossAxisAlignment:
                              //                         CrossAxisAlignment
                              //                             .center,
                              //                         children: [
                              //                           InkWell(
                              //                             onTap: () {
                              //                               Provider.of<SelectedApplicantProvider>(
                              //                                   context,
                              //                                   listen:
                              //                                   false)
                              //                                   .removeApplicant(
                              //                                   applicant);
                              //                             },
                              //                             child: Icon(
                              //                               Icons.delete,
                              //                               color: const Color
                              //                                   .fromRGBO(
                              //                                   21, 43, 83, 1),
                              //                               size: MediaQuery.of(
                              //                                   context)
                              //                                   .size
                              //                                   .width <
                              //                                   500
                              //                                   ? 18
                              //                                   : 25,
                              //                             ),
                              //                           ),
                              //                         ],
                              //                       ),
                              //                     ),
                              //                   ],
                              //                 );
                              //               }).toList(),
                              //           ],
                              //         ),
                              //       ],
                              //     ),
                              //   ),

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

                              /*  if (Provider.of<SelectedTenantsProvider>(context)
                                    .selectedTenants
                                    .isNotEmpty)
                                  Column(
                                    children: [
                                      const SizedBox(
                                        height: 8,
                                      ),
                                      Consumer<SelectedTenantsProvider>(
                                        builder: (context, selectedTenantsProvider, child) {
                                          return selectedTenantsProvider.validationMessage != null
                                              ? Padding(
                                            padding: const EdgeInsets.only(top: 5),
                                            child: Text(
                                              selectedTenantsProvider.validationMessage!,
                                              style: TextStyle(color: Colors.red, fontSize: 16),
                                            ),
                                          )
                                              : SizedBox.shrink();
                                        },
                                      ),

                                    ],
                                  ),*/
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              if (Provider.of<SelectedTenantsProvider>(context)
                                  .selectedTenants
                                  .isNotEmpty)
                                const SizedBox(
                                  height: 8,
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
                                            CustomDropdown(
                                useBorderStyle: true,
                                              validator: (value) {
                                                if (_selectedRent == null) {
                                                  return 'Please select a rent cycle';
                                                }
                                                return null;
                                              },
                                              labelText: 'Select Rent Cycle',
                                              items: rentCycleitems,
                                              selectedValue: _selectedRent,
                                              onChanged: (String? value) {
                                                setState(() {
                                                  _selectedRent = value;

                                                  _updateProRatedRent(
                                                      _selectedRent ??
                                                          'Monthly');
                                                });
                                                _updateNextDueDate();
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
                                            const Text('Next Due Date ',
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
                                              readOnnly: true,
                                              optional: true,
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
                                CustomDropdown(
                                useBorderStyle: true,
                                  key: UniqueKey(),
                                  validator: (value) {
                                    if (_selectedRent == null) {
                                      return 'Please select a rent cycle';
                                    }
                                    return null;
                                  },
                                  labelText: 'Select Rent Cycle',
                                  items: rentCycleitems,
                                  selectedValue: _selectedRent,
                                  onChanged: (String? value) {
                                    setState(() {
                                      _selectedRent = value;
                                      _selectedRent != null;
                                      isProRent = false;
                                      _updateProRatedRent(
                                          _selectedRent ?? 'Monthly');
                                    });
                                    _updateNextDueDate();
                                  },
                                ),
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
                                onChanged: (value) {
                                  setState(() {
                                    isAmountEntered = value.isNotEmpty;
                                    isProRent = false;
                                    _updateProRatedRent(_selectedRent ??
                                        'Monthly'); // Reset checkbox when amount changes
                                  });
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
                                  readOnnly: true,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      _selectNextDueDate(context);
                                    },
                                    icon: const Icon(Icons.date_range_rounded),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please select Next Due Date';
                                    }
                                    return null;
                                  },
                                  optional: true,
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
                              const SizedBox(
                                height: 20,
                              ),
                              Row(
                                children: [
                                  // SizedBox(
                                  //   width: 24.0, // Standard width for checkbox
                                  //   height: 24.0,
                                  //   child: Checkbox(
                                  //     value: isProRent,
                                  //     onChanged: (value) {
                                  //       setState(() {
                                  //         isProRent = value ?? false;
                                  //       });
                                  //     },
                                  //     activeColor: isProRent
                                  //         ? blueColor
                                  //         : Colors.black,
                                  //   ),
                                  // ),

                                  SizedBox(
                                    width: 24.0, // Standard width for checkbox
                                    height: 24.0,
                                    child: Checkbox(
                                      value: isProRent,
                                      onChanged: isAmountEntered &&
                                              rentNextDueDate.text.isNotEmpty &&
                                              _selectedRent != null &&
                                              startDateController
                                                  .text.isNotEmpty &&
                                              endDateController.text.isNotEmpty
                                          ? (value) {
                                              setState(() {
                                                isProRent = value ?? false;
                                                _updateProRatedRent(
                                                    _selectedRent ?? 'Monthly');
                                              });
                                            }
                                          : null,
                                      activeColor:
                                          blueColor, // Disable checkbox if amount is not entered
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Text(
                                    "Charge pro-rated rent for current month",
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: blueColor,
                                        fontWeight: FontWeight.bold),
                                  )
                                ],
                              ),
                              if (isProRent &&
                                  isAmountEntered &&
                                  rentNextDueDate.text.isNotEmpty &&
                                  _selectedRent != null &&
                                  startDateController.text.isNotEmpty &&
                                  endDateController.text.isNotEmpty)
                                const SizedBox(
                                  height: 10,
                                ),
                              if (isProRent &&
                                  isAmountEntered &&
                                  rentNextDueDate.text.isNotEmpty &&
                                  _selectedRent != null &&
                                  startDateController.text.isNotEmpty &&
                                  endDateController.text.isNotEmpty)
                                const Text('Pro-rated Rent',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey)),
                              if (isProRent &&
                                  isAmountEntered &&
                                  rentNextDueDate.text.isNotEmpty &&
                                  _selectedRent != null &&
                                  startDateController.text.isNotEmpty &&
                                  endDateController.text.isNotEmpty)
                                const SizedBox(
                                  height: 8,
                                ),
                              if (isProRent &&
                                  isAmountEntered &&
                                  rentNextDueDate.text.isNotEmpty &&
                                  _selectedRent != null &&
                                  startDateController.text.isNotEmpty &&
                                  endDateController.text.isNotEmpty)
                                CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter rent';
                                    }
                                    return null;
                                  },
                                  keyboardType: TextInputType.text,
                                  hintText: 'Enter rent',
                                  controller: proRatedRentController,
                                  optional: true,
                                ),
                              const SizedBox(
                                height: 20,
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
                          border:
                              Border.all(color: const Color(0xFFE4E8EF)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A101828),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
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
                                optional: false,
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
                      //lease payment setting
                      // Container(
                      //   width: double.infinity,
                      //   decoration: BoxDecoration(
                      //       border: Border.all(
                      //         color: blueColor,
                      //       ),
                      //       borderRadius: BorderRadius.circular(10.0)),
                      //   child: Padding(
                      //     padding: const EdgeInsets.all(12.0),
                      //     child: Column(
                      //       crossAxisAlignment: CrossAxisAlignment.start,
                      //       children: [
                      //         const SizedBox(
                      //           height: 10,
                      //         ),
                      //         Text('Lease Payment Settings',
                      //             style: TextStyle(
                      //                 fontSize: 16,
                      //                 fontWeight: FontWeight.w500,
                      //                 color: blueColor)),
                      //         //     .toList(),
                      //         const SizedBox(height: 5),
                      //         Text(
                      //             "When enabled, these payment settings will override the rental owner's payment settings for this specific lease.  If disabled, the lease will automatically apply the rental owner's default payment settings.",
                      //             textAlign: TextAlign.justify,
                      //             style: TextStyle(
                      //                 fontSize: 13,
                      //                 fontWeight: FontWeight.w300,
                      //                 color: Color(0xFF748097))),
                      //         const SizedBox(height: 10),
                      //         Row(
                      //           children: [
                      //             Checkbox(
                      //               activeColor: blueColor,
                      //               value: _leasePaymentSettings,
                      //               onChanged: (newValue) {
                      //                 setState(() {
                      //                   _leasePaymentSettings =
                      //                       newValue ?? false;
                      //                   if (!_leasePaymentSettings) {
                      //                     _creditCardAccepted = false;
                      //                     _debitCardAccepted = false;
                      //                   }
                      //                 });
                      //               },
                      //             ),
                      //             Text('Enable Lease Payment Settings',
                      //                 style: TextStyle(
                      //                     fontSize: 14,
                      //                     fontWeight: FontWeight.w500,
                      //                     color: blueColor)),
                      //           ],
                      //         ),
                      //         if (_leasePaymentSettings) ...[
                      //           const SizedBox(
                      //             height: 5,
                      //           ),
                      //           Row(
                      //             children: [
                      //               Checkbox(
                      //                 activeColor: blueColor,
                      //                 value: _creditCardAccepted,
                      //                 onChanged: (bool? value) {
                      //                   setState(() {
                      //                     _creditCardAccepted = value ?? false;
                      //                   });
                      //                 },
                      //               ),
                      //               const Text('Accepted Credit Card',
                      //                   style: TextStyle(
                      //                       fontSize: 14,
                      //                       fontWeight: FontWeight.w500,
                      //                       color: Color(0xFF748097))),
                      //             ],
                      //           ),
                      //           Row(
                      //             children: [
                      //               Checkbox(
                      //                 activeColor: blueColor,
                      //                 value: _debitCardAccepted,
                      //                 onChanged: (bool? value) {
                      //                   setState(() {
                      //                     _debitCardAccepted = value ?? false;
                      //                   });
                      //                 },
                      //               ),
                      //               const Text('Accepted Debit Card',
                      //                   style: TextStyle(
                      //                       fontSize: 14,
                      //                       fontWeight: FontWeight.w500,
                      //                       color: Color(0xFF748097))),
                      //             ],
                      //           ),
                      //         ],
                      //       ],
                      //     ),
                      //   ),
                      // ),
                      // const SizedBox(
                      //   height: 10,
                      // ),
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

                              // _uploadedFileNames.isNotEmpty
                              //     ? Text('Uploaded PDFs:')
                              //     : Container(),
                              // ..._uploadedFileNames
                              //     .map((fileName) => Text(fileName))
                              //     .toList(),
                              const SizedBox(height: 5),
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
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Send New Lease Agreement',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: blueColor)),
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Switch(
                                    activeColor: blueColor,
                                    value: _selectedResidentsEmail,
                                    onChanged: (newValue) {
                                      setState(() {
                                        _selectedResidentsEmail = newValue;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              const Text(
                                  'Emails the "New Lease Agreement" notification to every tenant on this lease when the lease is created.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF748097))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
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
                      const SizedBox(
                        height: 10,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 16),
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
                                        isLoading = true; // Start loading
                                      });
                                      final provider =
                                          Provider.of<SelectedTenantsProvider>(
                                              context,
                                              listen: false);
                                      final rentShareControllers =
                                          provider.rentShareControllers;

                                      if (rentShareControllers.length < 1) {
                                        setState(() {
                                          _errorMessage = "required tenants";
                                          isLoading =
                                              false; // Stop loading on error
                                        });
                                        return;
                                      }

                                      setState(() {
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
                                        //Changes
                                        List<Map<String, String>>
                                            mergedFormDataList = [
                                          ...formDataOneTimeList,
                                          ...formDataRecurringList,
                                        ];
                                        String leaseStartDate =
                                            reverseFormatDate(
                                                startDateController.text);
                                        String leaseEndDate = reverseFormatDate(
                                            endDateController.text);

                                        List<Entry> chargeEntries =
                                            mergedFormDataList.map((data) {
                                          return Entry(
                                            account: data['account'] ?? '',
                                            amount: double.tryParse(
                                                    data['amount'] ?? '0.0') ??
                                                0.0,
                                            chargeType:
                                                data['charge_type'] ?? '',
                                            date: data['charge_type'] ==
                                                    'Recurring Charge'
                                                ? (data['charge_start'] ??
                                                    '') // Ensuring data['date'] is not null
                                                : data['charge_start'] != null
                                                    ? (data['charge_start'] ??
                                                        '')
                                                    : rentNextDueDate.text
                                                        .trim(),
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
                                        // print(ne)
                                        chargeEntries.add(Entry(
                                          account: "Rent Income",
                                          amount: double.tryParse(
                                                  rentAmount.text.trim()) ??
                                              0.0,
                                          chargeType: 'Rent',
                                          date: rentNextDueDate.text.trim(),
                                          isRepeatable:
                                              false, // Set to false if it's not repeatable, adjust as needed
                                          memo: rentMemo.text.trim(),
                                          rentCycle:
                                              _selectedRent, // Set default value or adjust as needed
                                        ));
                                        chargeEntries.add(Entry(
                                          account: "Security Deposit",
                                          amount: double.tryParse(
                                                  securityDepositeAmount.text
                                                      .trim()) ??
                                              0.0,
                                          chargeType: 'Security Deposit',
                                          date: rentNextDueDate.text.trim(),
                                          isRepeatable:
                                              false, // Set to false if it's not repeatable, adjust as needed
                                          memo: 'Last Month\'s Rent',
                                          // rentCycle: _selectedRent, // Set default value or adjust as needed
                                        ));
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
                                        String currentDate =
                                            DateTime.now().toString();
                                        List<TenantData> tenantDataList =
                                            tenantsMap.entries.map((entry) {
                                          int index = entry.key;
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
                                            comments:
                                                tenantMap['comments'] ?? '',
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
                                            tenantBirthDate:
                                                tenantMap['dob'].toString() ??
                                                    '',
                                            tenantEmail:
                                                tenantMap['email'] ?? '',
                                            tenantFirstName:
                                                tenantMap['firstName'] ?? '',
                                            tenantId:
                                                tenantMap['tenantId'] ?? '',
                                            tenantLastName:
                                                tenantMap['lastName'] ?? '',
                                            tenantPassword:
                                                tenantMap['passWord'] ?? '',
                                            tenantPhoneNumber:
                                                tenantMap['phoneNumber'] ?? '',
                                            tenant_residentStatus:
                                                _selectedResidentsEmail
                                                    .toString(),
                                            updatedAt: tenantMap['updatedAt']
                                                    .toString() ??
                                                '',
                                            // Web parity (CRM-4132): keep sending
                                            // `percentage` in the payload —
                                            // preserve an existing value, else
                                            // first tenant = 100, every other = 0.
                                            rentShare: rentShareControllers[index]
                                                    .text
                                                    .trim()
                                                    .isNotEmpty
                                                ? rentShareControllers[index]
                                                    .text
                                                    .trim()
                                                : (index == 0 ? "100" : "0"),
                                          );
                                        }).toList();
                                        // Assuming tenantDataList is a List<TenantData>
                                        List<String> tenantIds = tenantDataList
                                            .map((tenant) =>
                                                tenant.tenantId ?? '')
                                            .toList();


                                        //print all data
                                        for (var tenant in tenantDataList) {

                                        }
                                        Lease lease = Lease(
                                          chargeData: ChargeData(
                                            adminId: adminId ?? "",
                                            entry: chargeEntries,
                                            isLeaseAdded: true,
                                          ),
                                          cosignerData: CosignerData(
                                            cosignerAlternativeNumber: firstCosigner?['workNumber'] ?? '',
                                            adminId: adminId,
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
                                                firstCosigner?['country'] ?? '',
                                            cosignerPostalcode:
                                                firstCosigner?['postalCode'] ??
                                                    '',
                                          ),
                                          leaseData: LeaseData(
                                            adminId: adminId ?? "",
                                            isProRent: isProRent,
                                            proRatedRent: isProRent
                                                ? proRatedRentController.text
                                                    .trim()
                                                : null,
                                            companyName: companyName,
                                            endDate: leaseEndDate,
                                            entry: chargeEntries,
                                            leaseAmount: rentAmount.text.trim(),
                                            leaseType: _selectedLeaseType ?? "",
                                            rentalId: renderId,
                                            startDate: leaseStartDate,
                                            tenantId: tenantDataList
                                                .map((tenant) =>
                                                    tenant.tenantId ?? '')
                                                .toList(),
                                            tenantResidentStatus:
                                                _selectedResidentsEmail,
                                            unitId: _selectedUnit,
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
                                        lease.tenantData.forEach((tenant) {
                                        });

                                        await addLeaseAndNavigate(lease);

                                        setState(() {
                                          isLoading = false; // Stop loading
                                        });
                                        if (applicantIds != null &&
                                            applicantIds!.isNotEmpty) {
                                          ifApplicantMoveIn(widget.applicantId!,
                                              applicantIds);
                                        } else {
                                        }

                                      }
                                    } else {
                                      String leaseStartDate = reverseFormatDate(
                                          startDateController.text);
                                      String leaseEndDate = reverseFormatDate(
                                          endDateController.text);

                                      SharedPreferences prefs =
                                          await SharedPreferences.getInstance();
                                      String adminId =
                                          prefs.getString("adminId")!;

                                      bool _isLeaseAdded = false;

                                      // // Printing ChargeData object
                                      //Changes
                                      List<Map<String, String>>
                                          mergedFormDataList = [
                                        ...formDataOneTimeList,
                                        ...formDataRecurringList,
                                      ];

                                      // Creating Entry objects from the merged list
                                      List<Entry> chargeEntries =
                                          mergedFormDataList.map((data) {
                                        return Entry(
                                          account: data['account'] ?? '',
                                          amount: double.tryParse(
                                                  data['amount'] ?? '0.0') ??
                                              0.0,
                                          chargeType: data['charge_type'] ?? '',
                                          date: rentNextDueDate.text,
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
                                          adminId: tenantMap['adminId'] ?? '',
                                          comments: tenantMap['comments'] ?? '',
                                          createdAt:
                                              tenantMap['createdAt'] ?? '',
                                          emergencyContact: EmergencyContacts(
                                            name: tenantMap[
                                                    'emergencyContactName'] ??
                                                '',
                                            relation: tenantMap[
                                                    'emergencyContactRelation'] ??
                                                '',
                                            email: tenantMap[
                                                    'emergencyContactEmail'] ??
                                                '',
                                            phoneNumber: tenantMap[
                                                    'emergencyContactPhoneNumber'] ??
                                                '',
                                          ),
                                          isDelete:
                                              tenantMap['isDelete'] == 'true',
                                          rentalAddress:
                                              tenantMap['rentalAddress'] ?? '',
                                          rentalUnit:
                                              tenantMap['rentalUnit'] ?? '',
                                          taxPayerId:
                                              tenantMap['taxPayerId'] ?? '',
                                          tenantAlternativeEmail: tenantMap[
                                                  'tenantAlternativeEmail'] ??
                                              '',
                                          tenantAlternativeNumber: tenantMap[
                                                  'tenantAlternativeNumber'] ??
                                              '',
                                          tenantBirthDate:
                                              tenantMap['dob'] ?? '',
                                          tenantEmail:
                                              tenantMap['tenantEmail'] ?? '',
                                          tenantFirstName:
                                              tenantMap['tenantFirstName'] ??
                                                  '',
                                          tenantId: tenantMap['tenantId'] ?? '',
                                          tenantLastName:
                                              tenantMap['tenantLastName'] ?? '',
                                          tenantPassword:
                                              tenantMap['tenantPassword'] ?? '',
                                          tenantPhoneNumber:
                                              tenantMap['tenantPhoneNumber'] ??
                                                  '',
                                          tenant_residentStatus:
                                              _selectedResidentsEmail
                                                  .toString(),
                                          updatedAt:
                                              tenantMap['updatedAt'] ?? '',
                                          v: int.tryParse(
                                                  tenantMap['v'] ?? '0') ??
                                              0,
                                          id: tenantMap['id'] ?? '',
                                        );
                                      }).toList();
                                    }
                                  },
                                  child: Center(
                                      child: isLoading
                                          ? const SpinKitFadingCircle(
                                              color: Colors.white,
                                              size: 25.0,
                                            )
                                          : const Text(
                                              'Create Lease',
                                              style: TextStyle(
                                                  color: Color(0xFFf7f8f9),
                                                  fontSize: 16),
                                            )),
                                ))),
                            const SizedBox(
                              width: 10,
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

  Future<void> addLeaseAndNavigate(Lease lease) async {
    // bool success = await LeaseRepository().postLease(lease);
    Checklease(lease);
    // if (success) {
    //   Navigator.pop(context, true); // Replace with the actual navigation logic
    // } else {
    //   // Handle the failure case, maybe show a message
    // }
  }

  Future<bool> Checklease(Lease lease) async {
    setState(() {
      isLoading = true;
    });
    final url = Uri.parse('${Api_url}/api/leases/check_lease');
    List<String?> tenantids =
        lease.tenantData.map((element) => element.tenantId).toList();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    var checkdata = {
      "admin_id": id,
      "lease_id": "",
      "tenant_id": tenantids,
      "rental_id": lease.leaseData.rentalId,
      "unit_id": lease.leaseData.unitId,
      "start_date": lease.leaseData.startDate,
      "end_date": lease.leaseData.endDate
    };
    try {
      final response = await apiPost(
        url,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
          'Content-Type': 'application/json'
        },
        body: jsonEncode(checkdata),
      );
      var responseData = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (responseData['statusCode'] == 200) {
          //  print('Response successfully: ${responseData['message']}');

          bool success = await LeaseRepository().postLease(lease);
          setState(() {
            isLoading = false;
          });
          if (success) {
            Navigator.pop(
                context, true); // Replace with the actual navigation logic
          } else {
            // Handle the failure case, maybe show a message
          }
          return true;
        } else {
          setState(() {
            errormessagefordateissue = responseData['message'];
            isLoading = false;
          });
          Fluttertoast.showToast(
              msg: responseData['message'] ?? 'Failed to add lease');
          return false;
        }
      } else {
        Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Failed to add lease');
        return false;
      }
    } catch (error) {
      logError('Exception occurred: $error');
      Fluttertoast.showToast(msg: 'An error occurred');
      return false;
    }
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

  Future<void> addLease() async {
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String adminId = prefs.getString("adminId")!;

    bool _isLeaseAdded = false;

    // // Printing ChargeData object

    List<Map<String, String>> mergedFormDataList = [
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
  }

  tenent_popup(dynamic person, int index) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTenantCosignerScreen(
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
  final Function(Map<String, String>) onSave;
  final Map<String, String>? initialData;

  OneTimeChargePopUp({required this.onSave, this.initialData});

  @override
  State<OneTimeChargePopUp> createState() => _OneTimeChargePopUpState();
}

class _OneTimeChargePopUpState extends State<OneTimeChargePopUp> {
  void _openAddAccountDialog(BuildContext context) {
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
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: ' Privately ',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
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
                                                                  FontWeight
                                                                      .bold,
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
  List<String> items = [];

  List<String> accountTypeItems = [
    'Income',
    'Non Operating Income ',
    'Liability Account'
  ];
  List<String> fundTypeItems = [
    'Reverse',
    'Operating',
  ];

  bool _isLoading = true;
  List<String> accounts = [];

  // For showing error message under Account dropdown
  bool _showAccountError = false;

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
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('$Api_url/api/accounts/accounts/$id'), headers: {
      "authorization": "CRM $token",
      "id": "CRM ${prefs.getString('staff_id') ?? id}",
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch data')),
      );
    }
  }

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
                            ...items
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
                          value: items.contains(_selectedProperty) ? _selectedProperty : null,
                          onChanged: (value) {
                            if (value == 'button_item') { _openAddAccountDialog(context); return; }
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
    bool valid = _formKey.currentState?.validate() ?? false;
    bool accountValid = _selectedProperty != null &&
        _selectedProperty!.isNotEmpty &&
        _selectedProperty != 'button_item';

    setState(() {
      _showAccountError = !accountValid;
    });

    if (valid && accountValid) {
      setState(() {
        _isInvalid = true;
      });
      final formData = {
        'account': _selectedProperty ?? '',
        'amount': _amountController.text.trim(),
        'memo': _memoController.text.trim(),
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
                                                    BorderRadius.circular(
                                                        10.0)),
                                            child: SingleChildScrollView(
                                              child: Container(
                                                // height: 450,
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                      16.0),
                                                  child: Form(
                                                    key: _subFormKey,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
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
                                                        const SizedBox(
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
                                                        const SizedBox(
                                                            height: 5),
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
                                                              TextInputType
                                                                  .text,
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
                                                        const SizedBox(
                                                            height: 5),
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
                                                          items:
                                                              accountTypeItems,
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
                                                        const SizedBox(
                                                            height: 5),
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
                                                        const SizedBox(
                                                            height: 5),
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
                                                              TextInputType
                                                                  .text,
                                                          hintText:
                                                              'Enter Notes',
                                                          controller:
                                                              _notesController,
                                                        ),
                                                        const SizedBox(
                                                          height: 20,
                                                        ),
                                                        RichText(
                                                          text: TextSpan(
                                                            children: <TextSpan>[
                                                              const TextSpan(
                                                                text:
                                                                    'We stores this information ',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    ' Privately ',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      blueColor,
                                                                ),
                                                              ),
                                                              const TextSpan(
                                                                text: ' and ',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                              ),
                                                              TextSpan(
                                                                text:
                                                                    ' Securely ',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      blueColor,
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
                                                                            backgroundColor:
                                                                                blueColor,
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
                                                                          style:
                                                                              TextStyle(color: Color(0xFFf7f8f9)),
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
                                                                          style:
                                                                              TextStyle(color: Color(0xFF748097)),
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
  TextEditingController startDateController = TextEditingController();
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
  bool _showAccountError = false;

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
        //items = (data['data'] as List).where((item) => item['charge_type'] == "Recurring Charge").map((item) => item['account'] as String).toList();
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

  String? selectedDay;
  List<Map<String, String>> formDataOneTimeList = [];
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          child: Container(
            color: Colors.white,
            // height: _isInvalid ? 460 : 475,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Add Recurring Fee',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Account *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                  ),
                ),
                const SizedBox(height: 8),
                FormField<String>(
                  validator: (value) {
                    if (_selectedProperty == null ||
                        _selectedProperty!.isEmpty) {
                      setState(() {
                        _showAccountError = true;
                      });
                      return 'Please select an account';
                    }
                    setState(() {
                      _showAccountError = false;
                    });
                    return null;
                  },
                  builder: (FormFieldState<String> state) {
                    return Column(
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
                              ...items.map(
                                  (String item) => DropdownMenuItem<String>(
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
                                
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                            value: items.contains(_selectedProperty) ? _selectedProperty : null,
                            onChanged: (value) {
                            if (value == 'button_item') { _openAddAccountDialog(context); return; }
                              setState(() {
                                _selectedProperty = value;
                                state.didChange(value);
                              });
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              // width: 160,
                              padding:
                                  const EdgeInsets.only(left: 0, right: 14),
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
                                thumbVisibility:
                                    MaterialStateProperty.all(true),
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
                    );
                  },
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
                FormField<String>(
                  validator: (value) {
                    if (selectedDay == null || selectedDay!.isEmpty) {
                      return 'Please select a recurrence type';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            hint: const Text('select'),
                            isExpanded: true,
                            value: (selectedDay == 'Weekly' || selectedDay == 'Monthly') ? selectedDay : null,
                            items: [
                              const DropdownMenuItem<String>(
                                value: 'Weekly',
                                child: Text('Weekly'),
                              ),
                              const DropdownMenuItem<String>(
                                value: 'Monthly',
                                child: Text('Monthly'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedDay = value;
                                state.didChange(value);
                              });
                            },
                            buttonStyleData: ButtonStyleData(
                              height: 50,
                              padding:
                                  const EdgeInsets.only(left: 0, right: 14),
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
                                thumbVisibility:
                                    MaterialStateProperty.all(true),
                              ),
                            ),
                          ),
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              state.errorText!,
                              style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
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
      DateTime now = DateTime.now();
      int selectedYear = now.year;
      int selectedMonth = now.month;

      // Construct the date using the selected day, current year, and month
      // int selectedDayInt = int.parse(selectedDay!);

      // Format date to always have two-digit months and days

      String? id =
          widget.initialData != null ? widget.initialData!['entry_id'] : "";
      final formData = {
        'account': _selectedProperty ?? '',
        'amount': _amountController.text.trim(),
        'memo': _memoController.text.trim(),
        'entry_id': id ?? "",
        "rent_cycle": selectedDay ?? "",
        'charge_type': 'Recurring Charge',
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
        // 'charge_type': 'Recurring Charge',
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
        //widget.onSave(formData);
        final newAccountName = _accountNameController.text.trim();
        setState(() {
          items.insert(items.length, newAccountName);
          _selectedProperty = newAccountName;
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
  TextEditingController rentShareControllers = TextEditingController();
  bool _obscureText = true;
  //bool _ischecked = false;
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredTenants = tenants;
    selected = List<bool>.generate(tenants.length, (index) => false);
    fetchTenantsAndApplicants();
    // fetchTenants();
    //  fetchApplicants();
    filteredApplicant = Applicant;
    select = List<bool>.generate(Applicant.length, (index) => false);
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

  Tenant convertApplicantToTenant(Datum applicant) {
    return Tenant(
        tenantFirstName: applicant.applicantFirstName,
        tenantLastName: applicant.applicantLastName,
        tenantEmail: applicant.applicantEmail,
        tenantPhoneNumber: applicant.applicantPhoneNumber.toString(),
        tenantId: null, // Explicitly set tenantId as null
        applicantId: applicant.applicantId);
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
  // Future<void> fetchTenants() async {
  //   setState(() {
  //     isLoading = true;
  //   });
  //
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     String? id = prefs.getString("adminId");
  //     String? token = prefs.getString('token');
  //     final response = await http
  //         .get(Uri.parse('${Api_url}/api/tenant/tenants/$id'), headers: {
  //       "authorization": "CRM $token",
  //       "id": "CRM $id",
  //     });
  //
  //     if (response.statusCode == 200) {
  //       Map<String, dynamic> responseData = json.decode(response.body);
  //
  //       // Check if the response contains the expected keys
  //       if (responseData.containsKey('data')) {
  //         List<dynamic> data = responseData['data']['tenants'];
  //         tenants = data.map((item) => Tenant.fromJson(item)).toList();
  //         filteredTenants = List.from(tenants);
  //         selected = List<bool>.filled(tenants.length, false);
  //       } else {
  //         // Handle unexpected response structure
  //         print("Unexpected response structure: Missing 'data' key");
  //       }
  //     } else {
  //       // Handle HTTP errors
  //       print("Failed to load tenants: ${response.statusCode}");
  //     }
  //   } catch (e) {
  //     // Handle other errors
  //     print("Error fetching tenants: $e");
  //   } finally {
  //     setState(() {
  //       isLoading = false;
  //     });
  //   }
  // }
  Future<void> fetchTenantsAndApplicants() async {
    setState(() {
      isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      // Fetch tenants
      final tenantResponse = await http
          .get(Uri.parse('${Api_url}/api/tenant/tenants/$id'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });

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
      //     .get(Uri.parse('${Api_url}/api/applicant/applicant/$id'), headers: {
      //   "authorization": "CRM $token",
      //   "id": "CRM $id",
      // });
      //
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

  // Tenant convertApplicantToTenant(Datum applicant) {
  //   return Tenant(
  //     applicantId: applicant.applicantId,
  //     tenantFirstName: applicant.applicantFirstName,
  //     tenantLastName: applicant.applicantLastName,
  //     tenantEmail: applicant.applicantEmail,
  //     tenantPhoneNumber: applicant.applicantPhoneNumber.toString(),
  //     tenantId: null, // Explicitly set tenantId as null
  //   );
  // }
  // Future<void> fetchTenantsAndApplicants() async {
  //   if (mounted) {
  //     setState(() {
  //       isLoading = true;
  //     });
  //   }
  //
  //   try {
  //     SharedPreferences prefs = await SharedPreferences.getInstance();
  //     String? id = prefs.getString("adminId");
  //     String? token = prefs.getString('token');
  //
  //     // Fetch tenants
  //     final tenantResponse = await http
  //         .get(Uri.parse('${Api_url}/api/tenant/tenants/$id'), headers: {
  //       "authorization": "CRM $token",
  //       "id": "CRM $id",
  //     });
  //
  //     if (tenantResponse.statusCode == 200) {
  //       Map<String, dynamic> tenantData = json.decode(tenantResponse.body);
  //       if (tenantData.containsKey('data')) {
  //         List<dynamic> tenantList = tenantData['data']['tenants'];
  //         tenants = tenantList.map((item) => Tenant.fromJson(item)).toList();
  //       } else {
  //         print("Unexpected tenant response structure: Missing 'data' key");
  //       }
  //     } else {
  //       print("Failed to load tenants: ${tenantResponse.statusCode}");
  //     }
  //
  //     // Fetch applicants
  //     final applicantResponse = await http
  //         .get(Uri.parse('${Api_url}/api/applicant/applicant/$id'), headers: {
  //       "authorization": "CRM $token",
  //       "id": "CRM $id",
  //     });
  //
  //     if (applicantResponse.statusCode == 200) {
  //       Map<String, dynamic> applicantData =
  //           json.decode(applicantResponse.body);
  //       if (applicantData.containsKey('data')) {
  //         List<dynamic> applicantList = applicantData['data'];
  //         List<Tenant> convertedApplicants = applicantList
  //             .map((item) => convertApplicantToTenant(Datum.fromJson(item)))
  //             .toList();
  //
  //         // Merge tenants and converted applicants
  //         tenants.addAll(convertedApplicants);
  //       } else {
  //         print("Unexpected applicant response structure: Missing 'data' key");
  //       }
  //     } else {
  //       print("Failed to load applicants: ${applicantResponse.statusCode}");
  //     }
  //
  //     if (mounted) {
  //       setState(() {
  //         filteredTenants = List.from(tenants);
  //         selected = List<bool>.filled(tenants.length, false);
  //       });
  //     }
  //   } catch (e) {
  //     print("Error fetching tenants or applicants: $e");
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         isLoading = false;
  //       });
  //     }
  //   }
  // }

  //for applicant

  bool isloading = false;
  // int? selectedIndex;
  List<Datum> Applicant = [];
  List<Datum> filteredApplicant = [];
  List<Datum> selectedApplicant = [];
  List<bool> select = [];

  Future<void> fetchApplicants() async {
    setState(() {
      isloading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      final response = await http
          .get(Uri.parse('${Api_url}/api/applicant/applicant/$id'), headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      });

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = json.decode(response.body);

        // Check if the response contains the expected keys
        if (responseData.containsKey('data')) {
          List<dynamic> data = responseData['data'];
          Applicant = data.map((item) => Datum.fromJson(item)).toList();
          List<Tenant> tenants =
              Applicant.map((applicant) => convertApplicantToTenant(applicant))
                  .toList();
          filteredApplicant = List.from(Applicant);
          select = List<bool>.filled(Applicant.length, false);
        } else {
          // Handle unexpected response structure
        }
      } else {
        // Handle HTTP errors
      }
    } catch (e) {
      // Handle other errors
      logError("Error fetching Applicant: $e");
    } finally {
      setState(() {
        isloading = false;
      });
    }
  }

  List<Tenant> selectedTenantsTemp = [];
  //
  // void filterOwners(String query) {
  //   setState(() {
  //     filteredOwners = owners.where((owner) {
  //       final fullName = '${owner.firstName} ${owner.lastName}'.toLowerCase();
  //       return fullName.contains(query.toLowerCase());
  //     }).toList();
  //   });
  // }
  @override
  Widget build(BuildContext context) {
    var selectedTenantsProvider =
        Provider.of<SelectedTenantsProvider>(context, listen: false);
    var selectedApplicantProvider =
        Provider.of<SelectedApplicantProvider>(context, listen: false);
    return Container(
      child: Form(
        key: _formKey,
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              height: 20,
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
                const SizedBox(
                  width: 5,
                ),
                const Text("Choose an existing Tenant")
              ],
            ),
            const SizedBox(
              height: 10,
            ),
            isChecked
                ? Column(
                    children: [
                      const SizedBox(height: 10.0),
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
                          rows: [
                            // Add tenant rows
                            ...filteredTenants.map((tenant) {
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
                                    Checkbox(
                                      // value: selectedTenantsProvider
                                      //     .selectedTenants
                                      //     .contains(tenant),
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
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                            // Add applicant rows
                            // ...filteredApplicant.map((applicant) {
                            //   return DataRow(
                            //     cells: [
                            //       DataCell(
                            //         Padding(
                            //           padding: const EdgeInsets.only(
                            //               left: 20.0), // Indent for applicants
                            //           child: Text(
                            //               '${applicant.applicantFirstName} ${applicant.applicantLastName}'),
                            //         ),
                            //       ),
                            //       DataCell(
                            //         Checkbox(
                            //           value: selectedApplicantProvider
                            //               .selectedApplicant
                            //               .contains(applicant),
                            //           onChanged: (bool? value) {
                            //             if (value!) {
                            //               selectedApplicantProvider
                            //                   .addApplicant(applicant);
                            //             } else {
                            //               selectedApplicantProvider
                            //                   .removeApplicant(applicant);
                            //             }
                            //             setState(() {});
                            //           },
                            //         ),
                            //       ),
                            //     ],
                            //   );
                            // }).toList(),
                          ],
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
                              // When the Add button is clicked, update the provider with selected tenants
                              setState(() {
                                for (var tenant in selectedTenantsTemp) {
                                  selectedTenantsProvider.addTenant(tenant);
                                }
                                // Clear the temporary list after adding
                                // selectedTenantsTemp.clear();
                              });
                              Navigator.pop(
                                  context); // Close the dialog or screen after adding
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
                      const SizedBox(height: 16.0),
                      const Row(
                        children: [
                          SizedBox(
                            width: 2,
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
                              hintText: 'Enter first name',
                              controller: firstName,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r"[a-zA-Z\s]")), // Allows letters and spaces
                              ],
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
                              hintText: 'Enter last name',
                              controller: lastName,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(
                                    r"[a-zA-Z\s]")), // Allows letters and spaces
                              ],
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
                              phone: true,
                              otherController: workNumber,
                              controller: phoneNumber,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'please enter the phone number';
                                }
                                return null;
                              },
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                                PhoneNumberFormatter(),
                              ],
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
                                          phone: true,
                                          optional: true,
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
                                          email: true,
                                          optional: true,
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
                                        hintText: 'yyyy-mm-dd',
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
                                    hintText: 'Enter contact name',
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(
                                          r"[a-zA-Z\s]")), // Allows letters and spaces
                                    ],
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
                                    alterController: email,
                                    emrgencyController: alterEmail,
                                    email: true,
                                    optional: true,
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Text('Phone Number ',
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
                                    hintText: 'Enter phone number',
                                    controller: emergencyPhoneNumber,
                                    optional: true,
                                    phone: true,
                                    otherController: phoneNumber,
                                    businessController: workNumber,
                                  ),
                                ],
                              ),
                            )
                          : Container(),
                      const SizedBox(
                        height: 30,
                      ),

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
                                  tenantBirthDate: _dateController.text.trim(),
                                  taxPayerId: taxPayerId.text.trim(),
                                  comments: comments.text.trim(),
                                  rentshare: rentShareControllers.text.trim(),
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
                                Navigator.of(context).pop();
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
                    hintText: 'Enter first name',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s]")), // Allows letters and spaces
                    ],
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
                    hintText: 'Enter last name',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s]")), // Allows letters and spaces
                    ],
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please enter the phone number';
                      }
                      return null;
                    },
                    phone: true,
                    otherController: workNumber,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      PhoneNumberFormatter(),
                    ],
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
                                optional: true,
                                otherController: phoneNumber,
                                phone: true,
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
                    // optional: true,
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
                                optional: true,
                                email: true,
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
                  hintText: 'Enter zip code',
                  controller: postalCode,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return TextEditingValue(
                        text: newValue.text.toUpperCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
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
                            Navigator.pop(context);
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
                            Navigator.pop(context);
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => addLease3(cosigner: cosigner),
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
