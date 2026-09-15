import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
//import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/WorkOrderSetting.dart'
    as WorkOrderModel;
import 'package:three_zero_two_property/repository/SettingWorkorder.dart';

import 'package:three_zero_two_property/repository/setting.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as widget_302_Staff;
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../Model/categories_model.dart';
import '../../StaffModule/widgets/custom_drawer.dart';
import '../../constant/constant.dart';
import '../Team_Access/team_access_section.dart';
import '../../model/setting.dart';
import '../../provider/dateProvider.dart';
import '../../widgets/CustomTableShimmer.dart';
import '../../widgets/custom_drawer.dart';
import '../Leasing/RentalRoll/newAddLease.dart';
import '../Rental/Tenants/add_tenants.dart';
import 'manage_template.dart';
import 'package:three_zero_two_property/Model/All_categories_model.dart';
import 'package:three_zero_two_property/repository/fetch_allcategories.dart';
import '../Maintenance/Vendor/edit_vendor.dart' hide CustomTextField;
import '../Maintenance/Vendor/add_vendor.dart' hide CustomTextField;
import '../../Model/vendor.dart';
import '../../repository/vendor_repository.dart';
import '../Rental/Rentalowner/Rentalowner_table.dart';
import '../Property_Type/Property_type_table.dart';
import '../Maintenance/Vendor/Vendor_table.dart';
// Staff module table widgets
import '../../StaffModule/screen/Rental/Rentalowner/Rentalowner_table.dart'
    as StaffRentalOwner;
import '../../StaffModule/screen/Property_Type/Property_type_table.dart'
    as StaffPropertyType;
import '../../StaffModule/screen/Maintenance/Vendor/Vendor_table.dart'
    as StaffVendor;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

// `kUsStateNames` now lives in constant/constant.dart (imported above) so the
// Profile screen's State dropdown shares the exact same 50-entry web list.

/// One tappable row in the redesigned settings menu.
/// [title] must match the value used by [_onSettingsTabChanged].
class _SettingsMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badge;
  const _SettingsMenuItem(this.title, this.subtitle, this.icon, {this.badge});
}

/// A titled group of settings rows (e.g. COMPANY, FINANCIAL).
class _SettingsMenuSection {
  final String header;
  final List<_SettingsMenuItem> items;
  const _SettingsMenuSection(this.header, this.items);
}

class TabBarExample extends StatefulWidget {
  final String? initialTab; // Optional parameter to specify which tab to open

  const TabBarExample({super.key, this.initialTab});

  @override
  State<TabBarExample> createState() => _TabBarExampleState();
}

class _TabBarExampleState extends State<TabBarExample> with NetworkRetryState {
  int _selectedRadio = 0;
  TextEditingController credit = TextEditingController();
  TextEditingController debit = TextEditingController();
  TextEditingController percent = TextEditingController();
  TextEditingController flat = TextEditingController();
  TextEditingController late_fee = TextEditingController();
  TextEditingController duration = TextEditingController();
  TextEditingController grace_balance = TextEditingController();
  TextEditingController durationmail = TextEditingController();
  TextEditingController description = TextEditingController();
  TextEditingController replyToEmail = TextEditingController();
  TextEditingController categories = TextEditingController();
  TextEditingController twilioAccountSid = TextEditingController();
  TextEditingController twilioAuthToken = TextEditingController();
  TextEditingController twilioPhoneNumber = TextEditingController();
  late Future<List<categories_model>> futureCategories;
  // category_id currently being edited; null means we're in "add" mode
  String? _editingCategoryId;
  late Future<List<Vendor>> futureVendors;
  bool rentDueReminderEmail = false;

  String surge_id = "";
  String latefee_id = "";
  bool isupdate = false;
  bool islatefeeupdate = false;
  String calculationType = "fixed"; // "fixed" or "percent"
  String selectedAccountId = "";
  String selectedAccountName = "";
  List<Setting4> accounts = [];
  List<PropertyOwnerOverride> propertyOwners = [];
  String selectedPropertyOwnerId = "";
  bool isLoadingPropertyOwners = false;
  // Original values for Late Fee Charge change tracking
  String _originalDuration = "";
  String _originalLateFee = "";
  String _originalGraceBalance = "";
  String _originalCalculationType = "fixed";
  String _originalDescription = "";
  String _originalSelectedAccountName = "";
  // Original values for Surcharge change tracking
  String _originalCredit = "";
  String _originalDebit = "";
  String _originalPercent = "";
  String _originalFlat = "";
  String? _originalSelectedAccount;
  int _originalSelectedRadio = 0;
  // Original values for Mail Service change tracking
  String _originalReplyToEmail = "";
  String _originalDurationMail = "";
  bool _originalRentDueReminderEmail = false;
  bool isLoadingAccounts = false;
  bool mailupdate = false;
  bool issurge = false;
  bool ismail = false;
  bool isaccounts = true;
  bool iscompanyprofile = false;
  bool islatefee = false;
  bool isLoading = false;
  bool isloading = false;
  bool isdateformate = false;
  bool isworkorder = false;
  bool iscategories = false;
  bool ismanagetemplate = false;
  bool ischargesetting = false;
  bool isvendor = false;
  bool ispropertyowner = false;
  bool ispropertytype = false;
  bool _isStaffUser = false;
  bool istwilio = false;
  bool isteamaccess = false; // Settings → Team & Access section (placeholder)

  // ---- Redesigned settings menu state ----
  // When true, the categorized menu (search + cards) is shown.
  // When false, the selected section's content is shown with a back button.
  bool _showSettingsMenu = true;
  // Title of the section currently opened (highlighted in the menu when you
  // navigate back). Empty until the user opens a section.
  String _activeSettingsTitle = '';
  final TextEditingController _settingsSearchController =
      TextEditingController();
  String _settingsSearchQuery = '';
  bool twilioSmsEnabled = false;
  String? twilioAccountSidError;
  String? twilioAuthTokenError;
  String? twilioPhoneNumberError;

  // Company profile (Manage Company Profile)
  final TextEditingController _cpCompanyName = TextEditingController();
  final TextEditingController _cpMailingStreet = TextEditingController();
  final TextEditingController _cpMailingCity = TextEditingController();
  final TextEditingController _cpMailingCountry = TextEditingController();
  final TextEditingController _cpMailingZip = TextEditingController();
  final TextEditingController _cpOfficeStreet = TextEditingController();
  final TextEditingController _cpOfficeCity = TextEditingController();
  final TextEditingController _cpOfficeCountry = TextEditingController();
  final TextEditingController _cpOfficeZip = TextEditingController();
  final TextEditingController _cpOfficePhone = TextEditingController();
  final TextEditingController _cpManagerName = TextEditingController();
  String? _cpMailingState;
  String? _cpOfficeState;
  bool _cpLoading = false;
  bool _cpSaving = false;
  bool _cpLoadedOnce = false;
  final Map<String, String> _cpErrors = {};
  String _cpOrigCompanyName = '';
  String _cpOrigMailingStreet = '';
  String _cpOrigMailingCity = '';
  String _cpOrigMailingState = '';
  String _cpOrigMailingCountry = '';
  String _cpOrigMailingZip = '';
  String _cpOrigOfficeStreet = '';
  String _cpOrigOfficeCity = '';
  String _cpOrigOfficeState = '';
  String _cpOrigOfficeCountry = '';
  String _cpOrigOfficeZip = '';
  String _cpOrigOfficePhone = '';
  String _cpOrigManagerName = '';
  String? _cpApiError;

  // Vendor table state variables
  String vendorSearchValue = "";
  int vendorCurrentPage = 0;
  int vendorItemsPerPage = 10;
  List<int> vendorItemsPerPageOptions = [10, 25, 50, 100];
  int? vendorExpandedIndex;
  bool vendorSorting1 = true;
  bool vendorSorting2 = false;
  bool vendorAscending1 = true;
  bool vendorAscending2 = false;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  String? selectedAccount;
  String? _accountError;
  // 1. Add state variables
  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;

  // Workorder notification settings state variables
  bool createAdmin = false;
  bool createAssignee = false;
  bool createTenant = false;
  bool updateAdmin = false;
  bool updateAssignee = false;
  bool updateTenant = false;
  bool completeAdmin = false;
  bool completeAssignee = false;
  bool completeTenant = false;
  bool isLoadingNotifications = false; // For fetching/loading data
  bool isSavingNotifications = false; // For saving data
  bool _hasLoadedNotifications =
      false; // Track if notifications have been loaded

  /// Every request this screen makes on open, in one place so that opening it
  /// and reloading it can never drift apart.
  void _loadEverything() {
    fetchAccounts();
    futureaccount = accountRepository().fetchAccounts();
    fetchSurchargeData();
    fetchlatefeeData();
    fetchPropertyOwners();
    fetchMailData();
    // _loadColorPreference();
    loadChargeSetting();
    _loadVendor();
    _loadStaff();
    fetchWorkData();
  }

  /// Required by [NetworkRetryState]: re-issue this screen's own load. Called
  /// by the Retry button, and silently when the connection came back while
  /// this screen was in the background.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(_loadEverything);
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // If a specific tab was requested (deep-link), open it directly instead
    // of showing the categorized menu.
    if (widget.initialTab != null && widget.initialTab!.trim().isNotEmpty) {
      _showSettingsMenu = false;
    }
    _checkUserType();
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });

    checkInternet();
    _loadEverything();
    // fetchWorkOrderNotificationSettings(); // Removed - will be called when workorder tab is clicked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      dateProvider.loadDateFormat();

      // Set initial tab if specified
      if (widget.initialTab == 'Vendors' || widget.initialTab == 'Vendor') {
        setState(() {
          issurge = false;
          ismail = false;
          isaccounts = false;
          islatefee = false;
          isdateformate = false;
          isworkorder = false;
          ismanagetemplate = false;
          ischargesetting = false;
          iscategories = false;
          ispropertyowner = false;
          ispropertytype = false;
          isvendor = true;
        });
      } else if (widget.initialTab == 'Property Owners') {
        setState(() {
          issurge = false;
          ismail = false;
          isaccounts = false;
          islatefee = false;
          isdateformate = false;
          isworkorder = false;
          ismanagetemplate = false;
          ischargesetting = false;
          iscategories = false;
          isvendor = false;
          ispropertytype = false;
          ispropertyowner = true;
        });
      } else if (widget.initialTab == 'Property Type') {
        setState(() {
          issurge = false;
          ismail = false;
          isaccounts = false;
          islatefee = false;
          isdateformate = false;
          isworkorder = false;
          ismanagetemplate = false;
          ischargesetting = false;
          iscategories = false;
          isvendor = false;
          ispropertyowner = false;
          ispropertytype = true;
        });
      } else if (widget.initialTab == 'Company Profile') {
        setState(() {
          issurge = false;
          ismail = false;
          isaccounts = false;
          islatefee = false;
          isdateformate = false;
          isworkorder = false;
          ismanagetemplate = false;
          ischargesetting = false;
          iscategories = false;
          isvendor = false;
          ispropertyowner = false;
          ispropertytype = false;
          iscompanyprofile = true;
        });
        if (!_cpLoadedOnce) {
          _fetchCompanyProfile();
        }
      }
    });
    // _customDateController.text = customdate!;
    //  customdate = customdate ?? "2025-01-23"; // Example default date
    //  _customDateController.text = customdate!;
    futureCategories = accountRepository().fetchCategories();
    futureVendors = VendorRepository(baseUrl: '').getVendors();
    _loadDropdownCategories();
  }

  Future<void> _loadDropdownCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      setState(() {
        // Sort categories alphabetically by name
        _dropdownCategories = cats
          ..sort((a, b) => (a.name ?? '')
              .toLowerCase()
              .compareTo((b.name ?? '').toLowerCase()));
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
      });
      // Optionally show error
    }
  }

  // Add this helper method after the initState method
  Future<String?> _getApiId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? staffId = prefs.getString('staff_id');
    String? adminId = prefs.getString('adminId');
    String? role = prefs.getString('role');

    // Use staff_id only in a staff session, otherwise admin_id
    return (role == 'Staffmember' && staffId != null && staffId.isNotEmpty)
        ? staffId
        : adminId;
  }

  fetchAccounts() async {
    List<Setting4> fetchedAccounts = await accountRepository().fetchAccounts();
    setState(() {
      accounts = fetchedAccounts; // Store fetched accounts in the state
    });
  }

  fetchPropertyOwners() async {
    setState(() {
      isLoadingPropertyOwners = true;
    });
    List<PropertyOwnerOverride> fetched =
        await PropertyOwnerOverrideRepository().fetchPropertyOwners();
    setState(() {
      propertyOwners = fetched;
      isLoadingPropertyOwners = false;
    });
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back (reliably so on the
    // iOS simulator), which made this screen declare itself offline
    // while requests actually succeed. Confirm before believing it.
    if (connectiondata == ConnectivityResult.none && await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    accountname.dispose();
    note.dispose();
    // Surcharge tab
    credit.dispose();
    debit.dispose();
    percent.dispose();
    flat.dispose();
    // Late Fee Charge tab
    late_fee.dispose();
    duration.dispose();
    grace_balance.dispose();
    description.dispose();
    // Mail service tab
    durationmail.dispose();
    replyToEmail.dispose();
    // Categories tab
    categories.dispose();
    other.dispose();
    // SMS (Twilio) tab
    twilioAccountSid.dispose();
    twilioAuthToken.dispose();
    twilioPhoneNumber.dispose();
    // Date format tab
    _customDateController.dispose();
    _cpCompanyName.dispose();
    _cpMailingStreet.dispose();
    _cpMailingCity.dispose();
    _cpMailingCountry.dispose();
    _cpMailingZip.dispose();
    _cpOfficeStreet.dispose();
    _cpOfficeCity.dispose();
    _cpOfficeCountry.dispose();
    _cpOfficeZip.dispose();
    _cpOfficePhone.dispose();
    _cpManagerName.dispose();
    _settingsSearchController.dispose();
    super.dispose();
  }

  void _refreshAccounts() {
    setState(() {
      futureaccount = accountRepository().fetchAccounts();
    });
  }

  final SurchargeRepository surchargeRepository =
      SurchargeRepository(baseUrl: '${Api_url}');
  final latefeeRepository latefeerepository =
      latefeeRepository(baseUrl: '${Api_url}');
  final accountRepository accountrepository = accountRepository();
  final mailserviceRepository mailrepository =
      mailserviceRepository(baseUrl: '${Api_url}');

  Future<void> fetchSurchargeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? staffId = prefs.getString("staff_id");
    String? role = prefs.getString("role");

    // Use staff_id only in a staff session, otherwise admin_id
    String? id =
        (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
            ? staffId
            : adminId;

    try {
      Setting1 surcharges =
          await surchargeRepository.fetchSurchargeData('${adminId ?? ""}');

      if (surcharges != null) {
        setState(() {
          isupdate = true;
          credit.text = surcharges.surchargePercent.toString();
          debit.text = surcharges.surchargePercentDebit.toString();
          percent.text = surcharges.surchargePercentACH != 0.0
              ? surcharges.surchargePercentACH.toString()
              : "";
          flat.text = surcharges.surchargeFlatACH != 0.0
              ? surcharges.surchargeFlatACH.toString()
              : "";
          surge_id = surcharges.surchargeId.toString();
          if (surcharges!.surcharge_account != null) {
            try {
              var matchingAccount = accounts.firstWhere(
                (account) => account.account == surcharges!.surcharge_account,
              );
              selectedAccount = matchingAccount.accountId;
            } catch (e) {
              selectedAccount = null; // No matching account found
            }
          } else {
            selectedAccount = null;
          }
          _selectedRadio = surcharges.surchargePercentACH != 0.0 &&
                  surcharges.surchargeFlatACH != 0.0
              ? 3
              : surcharges.surchargePercentACH != 0.0
                  ? 1
                  : surcharges.surchargeFlatACH != 0.0
                      ? 2
                      : 0;
          _originalCredit = credit.text.trim();
          _originalDebit = debit.text.trim();
          _originalPercent = percent.text.trim();
          _originalFlat = flat.text.trim();
          _originalSelectedAccount = selectedAccount;
          _originalSelectedRadio = _selectedRadio;
        });
      }
    } catch (e) {
      logError('Failed to load surcharge dataaa: $e');
    }
  }

  Future<void> fetchAccountsData() async {
    setState(() {
      isLoadingAccounts = true;
    });
    try {
      List<Setting4> fetchedAccounts = await accountrepository.fetchAccounts();
      setState(() {
        accounts = fetchedAccounts;
        isLoadingAccounts = false;
      });
    } catch (e) {
      logError('Failed to load accounts: $e');
      setState(() {
        isLoadingAccounts = false;
      });
    }
  }

  Future<void> fetchlatefeeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    try {
      Setting2 latefee = await latefeerepository.fetchLatefeesData('$id');
      if (latefee != null) {
        setState(() {
          islatefeeupdate = true;
          late_fee.text = latefee.late_fee;
          duration.text = latefee.duration.toString();
          grace_balance.text = latefee.graceBalance.toString();
          latefee_id = latefee.latefeeId;
          calculationType = latefee.calculationType;
          description.text = latefee.description;
          // Set default to "Late Fee Income" if no account value from API
          selectedAccountName = latefee.chargeAccount.isNotEmpty
              ? latefee.chargeAccount
              : "Late Fee Income";

          // Store original values for change tracking
          _originalDuration = latefee.duration.toString();
          _originalLateFee = latefee.late_fee;
          _originalGraceBalance = latefee.graceBalance.toString();
          _originalCalculationType = latefee.calculationType;
          _originalDescription = latefee.description ?? "";
          _originalSelectedAccountName = latefee.chargeAccount.isNotEmpty
              ? latefee.chargeAccount
              : "Late Fee Income";
        });
      }
    } catch (e) {
      logError('Failed to load surcharge data: $e');
    }
  }

  // Check if Late Fee Charge fields have been modified
  bool _hasLateFeeChanges() {
    if (!islatefeeupdate) {
      // For new entries, check if any field has a value
      return duration.text.trim().isNotEmpty ||
          late_fee.text.trim().isNotEmpty ||
          grace_balance.text.trim().isNotEmpty ||
          description.text.trim().isNotEmpty ||
          selectedAccountName.isNotEmpty;
    }

    // For updates, compare current values with original values
    return duration.text.trim() != _originalDuration ||
        late_fee.text.trim() != _originalLateFee ||
        grace_balance.text.trim() != _originalGraceBalance ||
        calculationType != _originalCalculationType ||
        description.text.trim() != _originalDescription ||
        selectedAccountName != _originalSelectedAccountName;
  }

  // Check if Mail Service fields have been modified

  bool _hasSurchargeChanges() {
    // Settings are view-only for staff — keep the action disabled.
    if (!_canEditSettings) return false;
    return credit.text.trim() != _originalCredit ||
        debit.text.trim() != _originalDebit ||
        percent.text.trim() != _originalPercent ||
        flat.text.trim() != _originalFlat ||
        selectedAccount != _originalSelectedAccount ||
        _selectedRadio != _originalSelectedRadio;
  }

  Future<void> updateSurcharge() async {
    // Settings are view-only for staff — never send a surcharge change.
    if (!_canEditSettings) return;
    // Check if there are any changes before proceeding
    if (!_hasSurchargeChanges()) {
      return; // No changes made, don't proceed with update
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    try {
      Map<String, dynamic> data = {
        "admin_id": id,
        "surcharge_percent": credit.text.trim().isNotEmpty
            ? double.tryParse(credit.text.trim())
            : null,
        "surcharge_percent_debit": debit.text.trim().isNotEmpty
            ? double.tryParse(debit.text.trim())
            : null,
        "surcharge_percent_ACH": percent.text.trim().isNotEmpty
            ? double.tryParse(percent.text.trim())
            : null, // Add your logic to get this value
        "surcharge_flat_ACH": flat.text.trim().isNotEmpty
            ? double.tryParse(flat.text.trim())
            : null,
        "surcharge_account": selectedAccount != null
            ? (accounts.any((account) => account.accountId == selectedAccount)
                ? accounts
                    .firstWhere(
                        (account) => account.accountId == selectedAccount)
                    .account
                : selectedAccount)
            : null
      };

      bool success =
          await surchargeRepository.updateSurchargeData('$surge_id', data);

      if (success) {
        // Update original values after successful save
        setState(() {
          _originalCredit = credit.text.trim();
          _originalDebit = debit.text.trim();
          _originalPercent = percent.text.trim();
          _originalFlat = flat.text.trim();
          _originalSelectedAccount = selectedAccount;
          _originalSelectedRadio = _selectedRadio;
        });
        Fluttertoast.showToast(msg: "Surcharge Updated Successfully");
        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Surcharge Updated Successfully')));
      } else {
        Fluttertoast.showToast(msg: "Failed to Update Surcharge");
        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Failed to Update Surcharge')));
      }
    } catch (e) {
      logError('Failed to update surcharge data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
    }
  }

  Future<void> AddSurgedata() async {
    // double, not int: these are money fields and the UI accepts decimals.
    // int.tryParse("2.5") returns null (it does not truncate), so a first
    // save silently stored null for every decimal while the toast said it
    // succeeded. updateSurcharge() already parsed these as double.
    // Settings are view-only for staff — never send a surcharge.
    if (!_canEditSettings) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');

    try {
      Map<String, dynamic> data = {
        "admin_id": id,
        "surcharge_percent": credit.text.trim().isNotEmpty
            ? double.tryParse(credit.text.trim())
            : null,
        "surcharge_percent_debit": debit.text.trim().isNotEmpty
            ? double.tryParse(debit.text.trim())
            : null,
        "surcharge_percent_ACH": percent.text.trim().isNotEmpty
            ? double.tryParse(percent.text.trim())
            : null, // Add your logic to get this value
        "surcharge_flat_ACH": flat.text.trim().isNotEmpty
            ? double.tryParse(flat.text.trim())
            : null,
        "surcharge_account": selectedAccount
        // Add your logic to get this value
      };

      bool success =
          await surchargeRepository.AddSurgeData('1714649182536', data);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Surcharge Updated Successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to Update Surcharge')));
      }
    } catch (e) {
      logError('Failed to update surcharge data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
    }
  }

  Future<void> updateLatefee() async {
    // Settings are view-only for staff — never send a late-fee change.
    if (!_canEditSettings) return;
    // Check if there are any changes before proceeding
    if (!_hasLateFeeChanges()) {
      return; // No changes made, don't proceed with update
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    try {
      Map<String, dynamic> data = {
        "admin_id": id,
        "duration": duration.text.trim().isNotEmpty
            ? int.tryParse(duration.text.trim())
            : null,
        "grace_balance": grace_balance.text.trim().isNotEmpty
            ? int.tryParse(grace_balance.text.trim())
            : null,
        "late_fee": late_fee.text.trim().isNotEmpty
            ? double.tryParse(late_fee.text.trim())
            : null,
        "calculation_type": calculationType,
        "description":
            description.text.trim().isNotEmpty ? description.text.trim() : null,
        "charge_account":
            selectedAccountName.isNotEmpty ? selectedAccountName : null,
      };

      bool success =
          await latefeerepository.updateLatefeesData('$latefee_id', data);

      if (success) {
        // Update original values after successful save
        setState(() {
          _originalDuration = duration.text.trim();
          _originalLateFee = late_fee.text.trim();
          _originalGraceBalance = grace_balance.text.trim();
          _originalCalculationType = calculationType;
          _originalDescription = description.text.trim();
          _originalSelectedAccountName = selectedAccountName;
        });
        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Latefee Updated Successfully')));
        Fluttertoast.showToast(msg: 'Late Fee Updated Successfully');
      } else {
        // ScaffoldMessenger.of(context)
        //     .showSnackBar(SnackBar(content: Text('Failed to Update Latefee')));
        Fluttertoast.showToast(msg: 'Failed to Update Late Fee');
      }
    } catch (e) {
      logError('Failed to update Late Fee data: $e');
      // ScaffoldMessenger.of(context)
      //     .showSnackBar(SnackBar(content: Text('Error: $e')));
      Fluttertoast.showToast(msg: 'Error: ${friendlyErrorMessage(e)}');
    }
  }

  // Future<void> updatemailreminder() async {
  //   print("calling");
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? token = prefs.getString('token');
  //   String?  id = prefs.getString('adminId');
  //   try {
  //     Map<String, dynamic> data = {
  //       "admin_id": id,
  //       "remindermail":rentDueReminderEmail,
  //       "duration":
  //       rentDueReminderEmail ? double.tryParse(email_duration.text) : 0,
  //     };
  //
  //     bool success =
  //     await latefeerepository.updateLatefeesData('$latefee_id', data);
  //
  //     if (success) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('Latefee Updated Successfully')));
  //     } else {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text('Failed to Update Latefee')));
  //     }
  //   } catch (e) {
  //     print('Failed to update surcharge data: $e');
  //     ScaffoldMessenger.of(context)
  //         .showSnackBar(SnackBar(content: Text('Error: $e')));
  //   }
  // }
  Future<void> AddLatefeedata() async {
    // Settings are view-only for staff — never send a late-fee rule.
    if (!_canEditSettings) return;
    // Check if there are any changes before proceeding
    if (!_hasLateFeeChanges()) {
      return; // No changes made, don't proceed with add
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    try {
      Map<String, dynamic> data = {
        "admin_id": id,
        "duration": duration.text.trim().isNotEmpty
            ? int.tryParse(duration.text.trim())
            : null,
        "grace_balance": grace_balance.text.trim().isNotEmpty
            ? int.tryParse(grace_balance.text.trim())
            : null,
        "late_fee": late_fee.text.trim().isNotEmpty
            ? int.tryParse(late_fee.text.trim())
            : null,
        "calculation_type": calculationType,
        "description":
            description.text.trim().isNotEmpty ? description.text.trim() : null,
        "charge_account":
            selectedAccountName.isNotEmpty ? selectedAccountName : null,
      };

      bool success =
          await latefeerepository.AddLatefeesData('1714649182536', data);

      if (success) {
        // After successful add, fetch the data to get the ID and update original values
        await fetchlatefeeData();
        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('late_fee Updated Successfully')));
        Fluttertoast.showToast(msg: 'Late Fee updated successfully');
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(content: Text('Failed to Update Surcharge')));
        Fluttertoast.showToast(msg: 'Failed to Update Late Fee');
      }
    } catch (e) {
      logError('Failed to update Late Fee data: $e');
      // ScaffoldMessenger.of(context)
      //     .showSnackBar(SnackBar(content: Text('Error: $e')));
      Fluttertoast.showToast(msg: 'Error: ${friendlyErrorMessage(e)}');
    }
  }

  // Whether the Late Fee Save button should be enabled.
  bool _canSaveLateFee() {
    // Settings are view-only for staff — keep the action disabled.
    if (!_canEditSettings) return false;
    if (selectedPropertyOwnerId.isNotEmpty) {
      // Property Owner override: enable when any field has a value.
      return duration.text.trim().isNotEmpty ||
          late_fee.text.trim().isNotEmpty ||
          grace_balance.text.trim().isNotEmpty ||
          description.text.trim().isNotEmpty ||
          selectedAccountName.isNotEmpty;
    }
    return _hasLateFeeChanges();
  }

  // Save late fee rules for a specific Property Owner (override).
  Future<void> saveLateFeeOverride() async {
    // Settings are view-only for staff — never send a late-fee override.
    if (!_canEditSettings) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    try {
      Map<String, dynamic> lateFeeRules = {
        "calculation_type": calculationType,
        "late_fee": late_fee.text.trim().isNotEmpty
            ? num.tryParse(late_fee.text.trim())
            : null,
        "duration": duration.text.trim().isNotEmpty
            ? int.tryParse(duration.text.trim())
            : null,
        "grace_balance": grace_balance.text.trim().isNotEmpty
            ? int.tryParse(grace_balance.text.trim())
            : null,
        "charge_account":
            selectedAccountName.isNotEmpty ? selectedAccountName : null,
        "description":
            description.text.trim().isNotEmpty ? description.text.trim() : null,
      };
      Map<String, dynamic> data = {
        "rentalowner_id": selectedPropertyOwnerId,
        "admin_id": adminId,
        "is_web": true,
        "user_active_recently": true,
        "late_fee_rules": lateFeeRules,
      };
      bool success =
          await PropertyOwnerOverrideRepository().saveLateFeeOverride(data);
      if (success) {
        Fluttertoast.showToast(
            msg: 'Property Owner override saved successfully');
      } else {
        Fluttertoast.showToast(msg: 'Failed to save Property Owner override');
      }
    } catch (e) {
      logError('Failed to save property owner override: $e');
      Fluttertoast.showToast(msg: 'Error: ${friendlyErrorMessage(e)}');
    }
  }

  //mail Services
  Future<void> fetchMailData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    try {
      Setting3 latefee = await mailrepository.fetchMailData('$id');
      if (latefee != null) {
        setState(() {
          id = latefee.adminId;
          mailupdate = true;
          durationmail.text = latefee.duration ?? "";
          replyToEmail.text = latefee.replyTo ?? "";
          //  rentDueReminderEmail = true;
          if (latefee.remindermail != null) {
            rentDueReminderEmail = latefee.remindermail!;
          }

          // Store original values for change tracking
          _originalDurationMail = latefee.duration?.toString() ?? "";
          _originalRentDueReminderEmail = latefee.remindermail ?? false;
          _originalReplyToEmail = replyToEmail.text.trim();
        });
      }
    } catch (e) {
      logError('Failed to load surcharge data: $e');
    }
  }

  Map<String, dynamic>? chargesetting;

  void loadChargeSetting() async {
    Map<String, dynamic>? chargeData = await fetchChargeSetting();
    if (chargeData != null) {
      bool unbundle = chargeData["unbundle_charges"] ?? false;
      setState(() {
        chargesetting = chargeData;
      });
    }
  }

  //mail Services
  Future<Map<String, dynamic>?> fetchChargeSetting() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = await _getApiId(); // Use helper method to get correct ID
      String? token = prefs.getString('token');
      String? adminid = prefs.getString("adminId");

      if (id == null || token == null) {
        throw Exception("Missing ID or token in SharedPreferences");
      }

      final response = await apiGet(
        Uri.parse('$Api_url/api/charge-setting/$adminid'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
        },
      );

      final responseData = jsonDecode(response.body);

      if (responseData["statusCode"] == 200) {
        Map<String, dynamic> data = responseData["data"];
        return data; // returning as a Map<String, dynamic>
      } else {
        throw Exception('Failed to load charge data');
      }
    } catch (e) {
      logError('Failed to load charge data: $e');
      return null;
    }
  }

  Future<void> updateMail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    try {
      Map<String, dynamic> data = {
        "admin_id": id,
        "duration": rentDueReminderEmail
            ? (durationmail.text.trim().isNotEmpty
                ? double.tryParse(durationmail.text.trim())
                : null)
            : 0,
        "replyToEmail": replyToEmail.text.trim(),
        "remindermail": rentDueReminderEmail,
      };

      bool success = await mailrepository.updateMailData(data);

      if (success) {
        // Update original values after successful save
        setState(() {
          _originalReplyToEmail = replyToEmail.text.trim();
          _originalDurationMail = durationmail.text.trim();
          _originalRentDueReminderEmail = rentDueReminderEmail;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('mail Updated Successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to Update mail')));
      }
    } catch (e) {
      logError('Failed to update mail data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
    }
  }

  Future<bool> AddChargeSettingData(id, Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    final response = await apiPost(
      Uri.parse('$Api_url/api/charge-setting'),
      headers: {
        "authorization": "CRM $token",
        'Content-Type': 'application/json',
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData["statusCode"] == 200) {
        // Show success message
        Fluttertoast.showToast(
            msg: responseData["message"] ??
                "Charge Setting updated successfully");
        return true;
      } else {
        // Show error message from API
        Fluttertoast.showToast(
            msg: responseData["message"] ?? "Failed to update charge setting");
        return false;
      }
    } else {
      // Show error message for HTTP error
      Fluttertoast.showToast(msg: "Failed to update charge setting");
      return false;
    }
  }

  Future<void> Addmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    try {
      Map<String, dynamic> data = {
        "admin_id": id,
        "replyToEmail": replyToEmail.text.trim(),
        "duration": rentDueReminderEmail
            ? (durationmail.text.trim().isNotEmpty
                ? int.tryParse(durationmail.text.trim())
                : null)
            : 0,
        "remindermail": rentDueReminderEmail,
      };

      bool success = await mailrepository.AddMailData(id, data);

      if (success) {
        // After successful add, fetch the data to get the updated values and update original values
        await fetchMailData();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('mail Updated Successfully')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to Update ,ail')));
      }
    } catch (e) {
      logError('Failed to update mail data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
    }
  }

  // --- Company profile (settings) ---

  void _cpTakeSnapshot() {
    _cpOrigCompanyName = _cpCompanyName.text.trim();
    _cpOrigMailingStreet = _cpMailingStreet.text.trim();
    _cpOrigMailingCity = _cpMailingCity.text.trim();
    _cpOrigMailingState = (_cpMailingState ?? '').trim();
    _cpOrigMailingCountry = _cpMailingCountry.text.trim();
    _cpOrigMailingZip = _cpMailingZip.text.trim();
    _cpOrigOfficeStreet = _cpOfficeStreet.text.trim();
    _cpOrigOfficeCity = _cpOfficeCity.text.trim();
    _cpOrigOfficeState = (_cpOfficeState ?? '').trim();
    _cpOrigOfficeCountry = _cpOfficeCountry.text.trim();
    _cpOrigOfficeZip = _cpOfficeZip.text.trim();
    _cpOrigOfficePhone = _cpOfficePhone.text.trim();
    _cpOrigManagerName = _cpManagerName.text.trim();
  }

  bool _hasCompanyProfileChanges() {
    return _cpCompanyName.text.trim() != _cpOrigCompanyName ||
        _cpMailingStreet.text.trim() != _cpOrigMailingStreet ||
        _cpMailingCity.text.trim() != _cpOrigMailingCity ||
        (_cpMailingState ?? '').trim() != _cpOrigMailingState ||
        _cpMailingCountry.text.trim() != _cpOrigMailingCountry ||
        _cpMailingZip.text.trim() != _cpOrigMailingZip ||
        _cpOfficeStreet.text.trim() != _cpOrigOfficeStreet ||
        _cpOfficeCity.text.trim() != _cpOrigOfficeCity ||
        (_cpOfficeState ?? '').trim() != _cpOrigOfficeState ||
        _cpOfficeCountry.text.trim() != _cpOrigOfficeCountry ||
        _cpOfficeZip.text.trim() != _cpOrigOfficeZip ||
        _cpOfficePhone.text.trim() != _cpOrigOfficePhone ||
        _cpManagerName.text.trim() != _cpOrigManagerName;
  }

  String _cpComposeBlockAddress({
    required String street,
    required String city,
    required String state,
    required String country,
    required String zip,
  }) {
    final parts = <String>[
      street.trim(),
      city.trim(),
      state.trim(),
      country.trim(),
      zip.trim(),
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  static final RegExp _cpUsZipRegex = RegExp(r'^\d{5}(-\d{4})?$');

  bool _cpZipValid(String raw) {
    return _cpUsZipRegex.hasMatch(raw.trim());
  }

  bool _cpPhoneValid(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10;
  }

  bool _validateCompanyProfileForm() {
    setState(() {
      _cpErrors.clear();
    });
    var ok = true;
    void err(String key, String msg) {
      _cpErrors[key] = msg;
      ok = false;
    }

    if (_cpCompanyName.text.trim().isEmpty) {
      err('company_name', 'This field is required');
    }
    if (_cpMailingStreet.text.trim().isEmpty) {
      err('mailing_street', 'This field is required');
    }
    if (_cpMailingCity.text.trim().isEmpty) {
      err('mailing_city', 'This field is required');
    }
    if (_cpMailingState == null || _cpMailingState!.trim().isEmpty) {
      err('mailing_state', 'This field is required');
    }
    if (_cpMailingCountry.text.trim().isEmpty) {
      err('mailing_country', 'This field is required');
    }
    final mz = _cpMailingZip.text.trim();
    if (mz.isEmpty) {
      err('mailing_zip', 'This field is required');
    } else if (!_cpZipValid(mz)) {
      err('mailing_zip', 'Enter valid US zip');
    }

    final oz = _cpOfficeZip.text.trim();
    if (oz.isNotEmpty && !_cpZipValid(oz)) {
      err('office_zip', 'Enter valid US zip');
    }

    if (_cpOfficePhone.text.trim().isEmpty) {
      err('office_phone', 'This field is required');
    } else if (!_cpPhoneValid(_cpOfficePhone.text)) {
      err('office_phone', 'Phone number must be 10 digits');
    }

    if (_cpManagerName.text.trim().isEmpty) {
      err('manager_name', 'This field is required');
    }

    setState(() {});
    return ok;
  }

  /// Staff: `id` + `staff_id` use staff id; `admin_id` is the tenant admin.
  /// Admin: `id` + `admin_id` use admin id (no `staff_id`).
  Map<String, String> _companyProfileAuthHeaders({
    required String token,
    required String? adminId,
    required String? staffId,
  }) {
    final h = <String, String>{
      'authorization': 'CRM $token',
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final staff = staffId != null && staffId.isNotEmpty;
    if (staff) {
      h['id'] = 'CRM $staffId';
      h['staff_id'] = staffId!;
      if (adminId != null && adminId.isNotEmpty) {
        h['admin_id'] = adminId!;
      }
    } else {
      final a = adminId ?? '';
      h['id'] = 'CRM $a';
      if (adminId != null && adminId.isNotEmpty) {
        h['admin_id'] = adminId!;
      }
    }
    return h;
  }

  Future<void> _fetchCompanyProfile() async {
    if (_cpLoading) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    final token = prefs.getString('token');
    // Role-gated so a stale staff_id cannot make an Admin session send
    // staff headers to the company-profile endpoints.
    final staffId = prefs.getString('role') == 'Staffmember'
        ? prefs.getString('staff_id')
        : null;
    if (adminId == null || token == null) return;

    setState(() => _cpLoading = true);
    try {
      final hdr = _companyProfileAuthHeaders(
        token: token,
        adminId: adminId,
        staffId: staffId,
      );
      var uri = Uri.parse('$Api_url/api/settings/company-profile/$adminId');
      var res = await apiGet(uri, headers: hdr);
      if (res.statusCode != 200) {
        uri = Uri.parse('$Api_url/api/settings/company-profile');
        res = await apiGet(uri, headers: hdr);
      }
      final decoded = jsonDecode(res.body);
      if (decoded['statusCode'] == 200 && decoded['data'] != null) {
        final d = decoded['data'] as Map<String, dynamic>;
        setState(() {
          // Match web (`company_dba || company_name`): show the DBA, falling
          // back to the legal company name when no separate DBA is set.
          // Without the fallback the field looked blank for companies that
          // never entered a DBA (e.g. keybrainstech).
          final cpDba = (d['company_dba'] ?? '').toString().trim();
          final cpLegalName = (d['company_name'] ?? '').toString().trim();
          _cpCompanyName.text = cpDba.isNotEmpty ? cpDba : cpLegalName;
          _cpMailingStreet.text = (d['mailing_street'] ?? '').toString();
          _cpMailingCity.text = (d['mailing_city'] ?? '').toString();
          final ms = (d['mailing_state'] ?? '').toString().trim();
          _cpMailingState = ms.isEmpty ? null : ms;
          _cpMailingCountry.text = (d['mailing_country'] ?? '').toString();
          _cpMailingZip.text = (d['mailing_zip'] ?? '').toString();
          _cpOfficeStreet.text = (d['office_street'] ?? '').toString();
          _cpOfficeCity.text = (d['office_city'] ?? '').toString();
          final os = (d['office_state'] ?? '').toString().trim();
          _cpOfficeState = os.isEmpty ? null : os;
          if (_cpMailingState != null &&
              !kUsStateNames.contains(_cpMailingState)) {
            _cpMailingState = null;
          }
          if (_cpOfficeState != null &&
              !kUsStateNames.contains(_cpOfficeState)) {
            _cpOfficeState = null;
          }
          _cpOfficeCountry.text = (d['office_country'] ?? '').toString();
          _cpOfficeZip.text = (d['office_zip'] ?? '').toString();
          final phoneRaw = (d['office_phone_number'] ?? '').toString();
          _cpOfficePhone.text = formatPhoneNumberedit(phoneRaw);
          _cpManagerName.text = (d['manager_name'] ?? '').toString();
          _cpLoadedOnce = true;
          _cpApiError = null;
          _cpTakeSnapshot();
        });
      } else {
        setState(() {
          _cpLoadedOnce = true;
          _cpApiError = decoded['message']?.toString();
          _cpTakeSnapshot();
        });
      }
    } catch (e) {
      logError('Company profile fetch failed: $e');
      setState(() {
        _cpLoadedOnce = true;
        _cpApiError = 'Could not load company profile.';
        _cpTakeSnapshot();
      });
    } finally {
      if (mounted) setState(() => _cpLoading = false);
    }
  }

  Future<void> _saveCompanyProfile() async {
    if (!_hasCompanyProfileChanges()) {
      return;
    }
    setState(() => _cpApiError = null);
    if (!_validateCompanyProfileForm()) {
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    final token = prefs.getString('token');
    // Role-gated so a stale staff_id cannot make an Admin session send
    // staff headers to the company-profile endpoints.
    final staffId = prefs.getString('role') == 'Staffmember'
        ? prefs.getString('staff_id')
        : null;
    if (adminId == null || token == null) {
      setState(() => _cpApiError = 'Missing session. Please sign in again.');
      return;
    }

    final mailingBlock = _cpComposeBlockAddress(
      street: _cpMailingStreet.text,
      city: _cpMailingCity.text,
      state: _cpMailingState ?? '',
      country: _cpMailingCountry.text,
      zip: _cpMailingZip.text,
    );
    final officeBlock = _cpComposeBlockAddress(
      street: _cpOfficeStreet.text,
      city: _cpOfficeCity.text,
      state: _cpOfficeState ?? '',
      country: _cpOfficeCountry.text,
      zip: _cpOfficeZip.text,
    );

    final body = <String, dynamic>{
      'admin_id': adminId,
      'company_dba': _cpCompanyName.text.trim(),
      'is_web': kIsWeb,
      'mailing_address': mailingBlock,
      'mailing_street': _cpMailingStreet.text.trim(),
      'mailing_city': _cpMailingCity.text.trim(),
      'mailing_state': _cpMailingState ?? '',
      'mailing_country': _cpMailingCountry.text.trim(),
      'mailing_zip': _cpMailingZip.text.trim(),
      'office_address': officeBlock,
      'office_street': _cpOfficeStreet.text.trim(),
      'office_city': _cpOfficeCity.text.trim(),
      'office_state': _cpOfficeState ?? '',
      'office_country': _cpOfficeCountry.text.trim(),
      'office_zip': _cpOfficeZip.text.trim(),
      'office_phone_number': _cpOfficePhone.text.trim(),
      'manager_name': _cpManagerName.text.trim(),
      'user_active_recently': true,
    };

    setState(() => _cpSaving = true);
    try {
      final res = await apiPut(
        Uri.parse('$Api_url/api/settings/company-profile'),
        headers: _companyProfileAuthHeaders(
          token: token,
          adminId: adminId,
          staffId: staffId,
        ),
        body: jsonEncode(body),
      );
      final decoded = jsonDecode(res.body);
      if (decoded['statusCode'] == 200) {
        _cpTakeSnapshot();
        setState(() {
          _cpApiError = null;
        });
        Fluttertoast.showToast(
            msg: decoded['message']?.toString() ?? 'Company profile saved');
      } else {
        setState(() {
          _cpApiError =
              decoded['message']?.toString() ?? 'Save failed. Try again.';
        });
      }
    } catch (e) {
      setState(() {
        _cpApiError = 'Could not save: $e';
      });
    } finally {
      if (mounted) setState(() => _cpSaving = false);
    }
  }

  /// Matches [Profile_screen] vendor profile field styling.
  Widget _cpLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _cpSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 12, left: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: blueColor,
        ),
      ),
    );
  }

  OutlineInputBorder _cpOutlineBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _cpTextField({
    required TextEditingController controller,
    String? hint,
    bool error = false,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    final borderColor = error ? Colors.red : Colors.grey.shade400;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      cursorColor: blueColor,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        filled: false,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: _cpOutlineBorder(borderColor),
        enabledBorder: _cpOutlineBorder(borderColor),
        focusedBorder: _cpOutlineBorder(
          error ? Colors.red : blueColor,
          width: error ? 1 : 1.5,
        ),
      ),
    );
  }

  Widget _cpStateDropdownField({
    required String? value,
    required void Function(String?) onChanged,
    required String hint,
    bool error = false,
  }) {
    final borderColor = error ? Colors.red : Colors.grey.shade400;
    final menuMaxH =
        (MediaQuery.sizeOf(context).height * 0.35).clamp(200.0, 320.0);

    return DropdownButtonHideUnderline(
      child: DropdownButton2<String>(
        isExpanded: true,
        value: (value == null || value.isEmpty) ? null : value,
        hint: Text(
          hint,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        // The popup rows carry their own inset (see menuItemStyleData below
        // for why it can't come from the package's own padding).
        items: kUsStateNames
            .map((s) => DropdownMenuItem<String>(
                  value: s,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      s,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ),
                ))
            .toList(),
        // Without this the closed button would reuse the padded item widgets
        // above and sit 12px further right than the neighbouring inputs. The
        // Align is required: the package stretches each entry to
        // `menuItemStyleData.height`, and a bare Text would paint at the top of
        // that box instead of centred like DropdownMenuItem's own child.
        selectedItemBuilder: (context) => kUsStateNames
            .map((s) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    s,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ))
            .toList(),
        onChanged: onChanged,
        buttonStyleData: ButtonStyleData(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
        ),
        iconStyleData: IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: blueColor, size: 22),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: menuMaxH,
          elevation: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        // Must stay zero. DropdownButton2 pads the closed button's text by
        // `menuItemStyleData.padding.horizontal / 2` whenever no explicit
        // button/dropdown width is set, so a padding of 12 here pushed the
        // State value 12px right of the sibling _cpTextField inputs. The rows
        // get their inset from the Padding inside each item instead.
        menuItemStyleData: const MenuItemStyleData(
          height: 42,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _cpErrorText(String? msg) {
    if (msg == null || msg.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 2),
      child: Text(
        msg,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  Widget _cpVendorCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCompanyProfileForm() {
    final w = MediaQuery.of(context).size.width;
    final narrow = w < 700;

    if (_cpLoading && !_cpLoadedOnce) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SpinKitFadingCircle(
            color: blueColor,
            size: 35,
          ),
        ),
      );
    }

    Widget row4({
      required Widget c1,
      required Widget c2,
      required Widget c3,
      required Widget c4,
    }) {
      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            c1,
            const SizedBox(height: 12),
            c2,
            const SizedBox(height: 12),
            c3,
            const SizedBox(height: 12),
            c4,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: c1),
          const SizedBox(width: 12),
          Expanded(child: c2),
          const SizedBox(width: 12),
          Expanded(child: c3),
          const SizedBox(width: 12),
          Expanded(child: c4),
        ],
      );
    }

    final zipFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
      LengthLimitingTextInputFormatter(10),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage Company Profile',
          style: TextStyle(
            color: blueColor,
            fontWeight: FontWeight.bold,
            fontSize: w < 500 ? 20 : 24,
          ),
        ),
        if (_cpApiError != null && _cpApiError!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              _cpApiError!,
              style: TextStyle(color: Colors.red.shade900, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _cpSectionTitle('Company'),
        _cpVendorCard(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cpLabel('Company Name / DBA *'),
                  _cpTextField(
                    controller: _cpCompanyName,
                    hint: 'Enter company name',
                    error: _cpErrors.containsKey('company_name'),
                    onChanged: (_) =>
                        setState(() => _cpErrors.remove('company_name')),
                  ),
                  _cpErrorText(_cpErrors['company_name']),
                ],
              ),
            ),
          ],
        ),
        _cpSectionTitle('Mailing Address'),
        _cpVendorCard(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cpLabel('Street *'),
                  _cpTextField(
                    controller: _cpMailingStreet,
                    hint: 'Street address',
                    error: _cpErrors.containsKey('mailing_street'),
                    onChanged: (_) =>
                        setState(() => _cpErrors.remove('mailing_street')),
                  ),
                  _cpErrorText(_cpErrors['mailing_street']),
                ],
              ),
            ),
            row4(
              c1: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cpLabel('City *'),
                        _cpTextField(
                          controller: _cpMailingCity,
                          hint: 'Enter city',
                          error: _cpErrors.containsKey('mailing_city'),
                          onChanged: (_) =>
                              setState(() => _cpErrors.remove('mailing_city')),
                        ),
                        _cpErrorText(_cpErrors['mailing_city']),
                      ],
                    ),
                  ),
                ],
              ),
              c2: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cpLabel('State *'),
                        _cpStateDropdownField(
                          value: _cpMailingState,
                          hint: 'Select State',
                          error: _cpErrors.containsKey('mailing_state'),
                          onChanged: (v) {
                            setState(() {
                              _cpMailingState = v;
                              _cpErrors.remove('mailing_state');
                            });
                          },
                        ),
                        _cpErrorText(_cpErrors['mailing_state']),
                      ],
                    ),
                  ),
                ],
              ),
              c3: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cpLabel('Country *'),
                        _cpTextField(
                          controller: _cpMailingCountry,
                          hint: 'Enter country',
                          error: _cpErrors.containsKey('mailing_country'),
                          onChanged: (_) => setState(
                              () => _cpErrors.remove('mailing_country')),
                        ),
                        _cpErrorText(_cpErrors['mailing_country']),
                      ],
                    ),
                  ),
                ],
              ),
              c4: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cpLabel('Zip *'),
                        _cpTextField(
                          controller: _cpMailingZip,
                          hint: 'Enter zip code',
                          keyboardType: TextInputType.text,
                          inputFormatters: zipFormatters,
                          error: _cpErrors.containsKey('mailing_zip'),
                          onChanged: (_) =>
                              setState(() => _cpErrors.remove('mailing_zip')),
                        ),
                        _cpErrorText(_cpErrors['mailing_zip']),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _cpSectionTitle('Office Address (if different)'),
        _cpVendorCard(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cpLabel('Street'),
                  _cpTextField(
                    controller: _cpOfficeStreet,
                    hint: 'Street address',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            row4(
              c1: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cpLabel('City'),
                    _cpTextField(
                      controller: _cpOfficeCity,
                      hint: 'Enter city',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              c2: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cpLabel('State'),
                    _cpStateDropdownField(
                      value: _cpOfficeState,
                      hint: 'Select State',
                      onChanged: (v) => setState(() => _cpOfficeState = v),
                    ),
                  ],
                ),
              ),
              c3: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cpLabel('Country'),
                    _cpTextField(
                      controller: _cpOfficeCountry,
                      hint: 'Enter country',
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              c4: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cpLabel('Zip'),
                    _cpTextField(
                      controller: _cpOfficeZip,
                      hint: 'Enter zip code',
                      keyboardType: TextInputType.text,
                      inputFormatters: zipFormatters,
                      error: _cpErrors.containsKey('office_zip'),
                      onChanged: (_) =>
                          setState(() => _cpErrors.remove('office_zip')),
                    ),
                    _cpErrorText(_cpErrors['office_zip']),
                  ],
                ),
              ),
            ),
          ],
        ),
        _cpSectionTitle('Contact'),
        _cpVendorCard(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cpLabel('Office Phone Number *'),
                  _cpTextField(
                    controller: _cpOfficePhone,
                    hint: '(xxx) xxx-xxxx',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                      PhoneNumberFormatter(),
                    ],
                    error: _cpErrors.containsKey('office_phone'),
                    onChanged: (_) =>
                        setState(() => _cpErrors.remove('office_phone')),
                  ),
                  _cpErrorText(_cpErrors['office_phone']),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cpLabel('Manager Name *'),
                  _cpTextField(
                    controller: _cpManagerName,
                    hint: 'Enter manager name',
                    error: _cpErrors.containsKey('manager_name'),
                    onChanged: (_) =>
                        setState(() => _cpErrors.remove('manager_name')),
                  ),
                  _cpErrorText(_cpErrors['manager_name']),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: (_cpSaving || !_hasCompanyProfileChanges())
                  ? null
                  : _saveCompanyProfile,
              child: Opacity(
                opacity:
                    (_cpSaving || !_hasCompanyProfileChanges()) ? 0.5 : 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: 48,
                      minWidth: w < 500 ? 228 : 268,
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.symmetric(
                        horizontal: w < 500 ? 20 : 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: blueColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.grey,
                            offset: Offset(0, 1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: _cpSaving
                          ? SpinKitFadingCircle(
                              color: Colors.white,
                              size: 24,
                            )
                          : Text(
                              'Save Company Profile',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: w < 500 ? 14 : 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Future<void> fetchTwilioSettings() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString('adminId');
      String? token = prefs.getString('token');
      String? id = await _getApiId();
      if (adminId == null || token == null || id == null) return;
      final response = await apiGet(
        Uri.parse('$Api_url/api/settings/twilio/$adminId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          responseData["statusCode"] == 200 &&
          responseData["data"] != null) {
        final data = responseData["data"] as Map<String, dynamic>;
        setState(() {
          twilioSmsEnabled = data["enabled"] == true;
          twilioAccountSid.text = (data["accountSid"] ?? "").toString();
          twilioAuthToken.text = (data["authToken"] ?? "").toString();
          twilioPhoneNumber.text = (data["phoneNumber"] ?? "").toString();
        });
      }
    } catch (e) {
      logError('Failed to load Twilio settings: $e');
    }
  }

  void _showTwilioSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> saveTwilioSettings() async {
    setState(() {
      twilioAccountSidError = null;
      twilioAuthTokenError = null;
      twilioPhoneNumberError = null;
    });

    if (twilioSmsEnabled) {
      bool hasError = false;
      if (twilioAccountSid.text.trim().isEmpty) {
        twilioAccountSidError = "Account SID is required";
        hasError = true;
      }
      if (twilioAuthToken.text.trim().isEmpty) {
        twilioAuthTokenError = "Auth Token is required";
        hasError = true;
      }
      if (twilioPhoneNumber.text.trim().isEmpty) {
        twilioPhoneNumberError = "Phone Number is required";
        hasError = true;
      }
      if (hasError) {
        setState(() {});
        // _showTwilioSnackBar("Please fill all required fields.");
        return;
      }
    }

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString('adminId');
      String? id = await _getApiId();
      if (token == null || id == null) {
        _showTwilioSnackBar("Missing authentication.");
        return;
      }
      final body = {
        "admin_id": adminId ?? id,
        "enabled": twilioSmsEnabled,
        "accountSid": twilioAccountSid.text.trim(),
        "authToken": twilioAuthToken.text.trim(),
        "phoneNumber": twilioPhoneNumber.text.trim(),
      };
      final response = await apiPost(
        Uri.parse('$Api_url/api/settings/twilio'),
        headers: {
          "authorization": "CRM $token",
          "Content-Type": "application/json",
          "id": "CRM $id",
        },
        body: jsonEncode(body),
      );
      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData["statusCode"] == 200) {
        _showTwilioSnackBar(
          responseData["message"] ?? "Twilio settings saved successfully.",
          isError: false,
        );
      } else {
        _showTwilioSnackBar(
          responseData["message"] ?? "Failed to save Twilio settings.",
        );
      }
    } catch (e) {
      logError('Failed to save Twilio settings: $e');
      _showTwilioSnackBar("Error saving Twilio settings.");
    }
  }

  //account table

  late Future<List<Setting4>> futureaccount;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;

  String? selectedRole;
  String searchValue = "";
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [
    10,
    25,
    50,
    100,
  ];

  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;

  void sortData(List<Setting4> data) {
    // if (sorting1) {
    //   data.sort((a, b) => ascending1
    //       ? a.staffmemberName!.compareTo(b.staffmemberName!)
    //       : b.staffmemberName!.compareTo(a.staffmemberName!));
    // } else if (sorting2) {
    //   data.sort((a, b) => ascending2
    //       ? a.staffmemberDesignation!.compareTo(b.staffmemberDesignation!)
    //       : b.staffmemberDesignation!.compareTo(a.staffmemberDesignation!));
    // } else if (sorting3) {
    //   data.sort((a, b) => ascending3
    //       ? a.createdAt!.compareTo(b.createdAt!)
    //       : b.createdAt!.compareTo(a.createdAt!));
    // }
  }

  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting1 == true) {
                      sorting2 = false;
                      sorting3 = false;
                      ascending1 = sorting1 ? !ascending1 : true;
                      ascending2 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = !sorting1;
                      sorting2 = false;
                      sorting3 = false;
                      ascending1 = sorting1 ? !ascending1 : true;
                      ascending2 = false;
                      ascending3 = false;
                    }

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? Text("Account",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Account",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting2) {
                      sorting1 = false;
                      sorting2 = sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = !sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    }
                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    Text("    Type",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting3) {
                      sorting1 = false;
                      sorting2 = false;
                      sorting3 = sorting3;
                      ascending3 = sorting3 ? !ascending3 : true;
                      ascending2 = false;
                      ascending1 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = false;
                      sorting3 = !sorting3;
                      ascending3 = sorting3 ? !ascending3 : true;
                      ascending2 = false;
                      ascending1 = false;
                    }

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    // SizedBox(width: 3),
                    Text("Fund Type",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int dateformateselect = 0;
  int timeformateselect = 0;
  int? expandedIndex;
  Set<int> expandedIndices = {};
  String? dateformate1;
  String? dateformate2;
  String? dateformate3;
  String? customdate;
  String? timeformate1;
  String? timeformate2;
  int totalrecords = 0;
  List<Setting4> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Setting4> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0; // Reset to the first page when changing rows per page
    });
  }

  void _sort<T>(Comparable<T> Function(Setting4 d) getField, int columnIndex,
      bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _tableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        int result;
        if (aValue is String && bValue is String) {
          result = aValue
              .toString()
              .toLowerCase()
              .compareTo(bValue.toString().toLowerCase());
        } else {
          result = aValue.compareTo(bValue as T);
        }
        return _sortAscending ? result : -result;
      });
    });
  }

  void _showDeleteAlert(BuildContext context, String id) {
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same account.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this account!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            if (deleting) return;
            deleting = true;
            // The repository toasts the server's own reason and then throws
            // when the delete is rejected (e.g. the account is still in use).
            // Nothing caught it, so Navigator.pop was never reached — the
            // dialog stayed open with no explanation and the exception escaped
            // into the framework. Close the dialog either way; the message has
            // already been shown.
            try {
              await accountRepository().DeleteAccount(account_id: id);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              setState(() {
                futureaccount = accountRepository().fetchAccounts();
              });
              Navigator.pop(context);
            } catch (_) {
              deleting = false;
              if (!mounted) return;
              Navigator.pop(context);
            }
          },
          color: blueColor,
        ),
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8), // Rounded corners
          border: Border.all(
            color: blueColor, // Blue border
            width: 1.5,
          ),
        ),
      ],
    ).show();
  }

  void handleDelete(Setting4 staff) {
    _showDeleteAlert(context, staff.accountId!);

    // Handle delete action
  }

  //for teblet

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(Setting4 d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField, columnIndex, !_sortAscending);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Text(text,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              if (_sortColumnIndex == columnIndex)
                Icon(_sortAscending
                    ? Icons.arrow_drop_down_outlined
                    : Icons.arrow_drop_up_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildActionsCell(Setting4 data) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          height: 50,
          // color: Colors.blue,
          child: Row(
            children: [
              const SizedBox(
                width: 20,
              ),
              InkWell(
                onTap: () {
                  _showEditAccount(context, data);
                },
                child: const FaIcon(
                  FontAwesomeIcons.edit,
                  size: 30,
                  color: Colors.green,
                ),
              ),
              const SizedBox(
                width: 20,
              ),
              InkWell(
                onTap: () {
                  handleDelete(data);
                },
                child: const FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    int numorpages = 1;
    numorpages = (totalrecords / _rowsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Text('Rows per page: '),
        // SizedBox(width: 10),
        Material(
          elevation: 2,
          color: Colors.white,
          child: Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                items: [10, 25, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    _changeRowsPerPage(newValue);
                  }
                },
                icon: const Icon(
                  Icons.arrow_drop_down,
                  size: 40,
                ),
                style: const TextStyle(color: Colors.black, fontSize: 17),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.circleChevronLeft,
            size: 30,
            color: _currentPage == 0 ? Colors.grey : blueColor,
          ),
          onPressed: _currentPage == 0
              ? null
              : () {
                  setState(() {
                    _currentPage--;
                  });
                },
        ),
        Text(
          'Page ${_currentPage + 1} of $numorpages',
          style: const TextStyle(fontSize: 18),
        ),
        IconButton(
          icon: FaIcon(
            size: 30,
            FontAwesomeIcons.circleChevronRight,
            color: (_currentPage + 1) * _rowsPerPage >= _tableData.length
                ? Colors.grey
                : const Color.fromRGBO(
                    21, 43, 83, 1), // Change color based on availability
          ),
          onPressed: (_currentPage + 1) * _rowsPerPage >= _tableData.length
              ? null
              : () {
                  setState(() {
                    _currentPage++;
                  });
                },
        ),
      ],
    );
  }

  Color _selectedColor = Colors.blue;
  Color _selectedLabelColor = Colors.grey; // Default label color

  // void _showColorPicker() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text('Select a color', style: TextStyle(fontWeight: FontWeight.bold)),
  //         content: SingleChildScrollView(
  //           child: ColorPicker(
  //          paletteType: PaletteType.hueWheel,
  //             pickerColor: _selectedColor,
  //             enableAlpha: false,
  //             showLabel: false,
  //             onColorChanged: (Color color) {
  //               setState(() {
  //                 _selectedColor = color;
  //                 _selectedColors = color;
  //               });
  //             },
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('OK'),
  //             onPressed: () {
  //               final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  //               themeProvider.updateColor(_selectedColor);
  //               _saveColorPreference(_selectedColor);
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  // Future<void> _saveColorPreference(Color color, Color labelColor) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setInt('selectedColor', color.value);
  //   await prefs.setInt('labelColor', labelColor.value);
  //   setState(() {
  //     _selectedColor = color;
  //     _selectedLabelColor = labelColor;
  //   });
  // }
  //
  // Future<void> _loadColorPreference() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final colorValue = prefs.getInt('selectedColor');
  //   final colorLabelValue = prefs.getInt('labelColor');
  //   if (colorValue != null) {
  //     setState(() {
  //       _selectedColor = Color(colorValue);
  //     });
  //   }
  //   if (colorLabelValue != null) {
  //     setState(() {
  //       _selectedLabelColor = Color(colorLabelValue);
  //     });
  //   }
  // }
  //
  // void _showColorPicker(Color currentColor, Function(Color) onColorSelected, String title, String preferenceKey) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
  //         content: SingleChildScrollView(
  //           child: ColorPicker(
  //             paletteType: PaletteType.hueWheel,
  //             pickerColor: currentColor,
  //             enableAlpha: false,
  //             showLabel: false,
  //             onColorChanged: (Color color) {
  //               onColorSelected(color);
  //             },
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('OK'),
  //             onPressed: () {
  //               if (preferenceKey == 'selectedColor') {
  //                 _saveColorPreference(currentColor, _selectedLabelColor);
  //               } else if (preferenceKey == 'labelColor') {
  //                 _saveColorPreference(_selectedColor, currentColor);
  //               }
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // void _showColorPicker(Color currentColor, Function(Color) onColorSelected, String title) {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
  //         content: SingleChildScrollView(
  //           child: ColorPicker(
  //             paletteType: PaletteType.hueWheel,
  //             pickerColor: currentColor,
  //             enableAlpha: false,
  //             showLabel: false,
  //             onColorChanged: (Color color) {
  //               onColorSelected(color);
  //             },
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('OK'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  String? _selectedCategory;
  final List<String> _category = [
    'Complaint',
    'Contribution Request',
    'Feedback/Suggestion',
    'General Inquiry',
    'Maintenance Request',
    'Other'
  ];
  String? _selectedEntry;
  final List<String> _entry = [
    'Yes',
    'No',
  ];
  String? _selectedStatus = "New";
  final List<String> _status = [
    'New',
    'In Progress',
    'On Hold',
    'Completed',
    'Closed'
  ];
  final List<String> _account = [
    'Advertizing',
    'Association fees',
  ];
  List<Map<String, dynamic>> rows = [];
  bool _showTextField = false;
  String renderId = '';
  String unitId = '';
  String vendorId = '';
  String StaffId = '';
  String tenantId = '';
  bool _isLoading = false;
  bool _isLoadingvendors = false;
  bool _isLoadingstaff = false;

  //for vendor
  Map<String, String> vendors = {};
  String? _selectedvendorsId;
  String? _selectedVendors;

  //for Staffmember
  Map<String, String> staffs = {};
  String? _selectedstaffId;
  String? _selectedStaffs;
  //for tenants
  Map<String, String> tenants = {};
  String? _selectedtenantId;
  String? _selectedTenants;

  Map<String, String> properties = {}; // Mapping of rental_id to rental_address
  Map<String, String> units = {};
  bool _isLoadingtenant = false;

  final TextEditingController other = TextEditingController();
  Future<void> _loadUnits(String rentalId) async {
    setState(() {
      _isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/unit/rental_unit/$rentalId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> unitAddresses = {};
        jsonResponse.forEach((data) {
          unitAddresses[data['unit_id'].toString()] =
              data['rental_unit'].toString();
        });
        //  200 no hoy tyare _loadtennant
        setState(() {
          units = unitAddresses;
          _isLoading = false;
        });
      } else {
        _loadTenant(rentalId, unitId);
        throw Exception('Failed to load units');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTenant(String rentalId, String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    setState(() {
      _isLoadingtenant = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/leases/get_tenants/$rentalId/$unitId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> tenantsnames = {};
        jsonResponse.forEach((data) {
          tenantsnames[data['tenant_id'].toString()] =
              data['tenant_firstName'].toString() +
                  " " +
                  data['tenant_lastName'].toString();
        });
        setState(() {
          tenants = tenantsnames;
          _isLoadingtenant = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingtenant = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Failed to fetch tenants: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  //for vendor
  Future<void> _loadVendor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    setState(() {
      _isLoadingvendors = true;
    });
    try {
      final response = await http
          .get(Uri.parse('${Api_url}/api/vendor/vendors/$adminid'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> names = {};
        jsonResponse.forEach((data) {
          names[data['vendor_id'].toString()] = data['vendor_name'].toString();
        });

        setState(() {
          // Sort vendors alphabetically by name (values)
          var sortedEntries = names.entries.toList()
            ..sort((a, b) =>
                a.value.toLowerCase().compareTo(b.value.toLowerCase()));
          vendors = Map.fromEntries(sortedEntries);
          _isLoadingvendors = false;
        });
      } else {
        // throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingvendors = false;
      });
      // A network failure already flips this screen to the offline state,
      // which says it better than a snackbar stacked on top of it.
      if (!isNetworkError(e))
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
        );
    }
  }

  Future<void> _loadStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    setState(() {
      _isLoadingstaff = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/staffmember/staff_member/$adminId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> staffnames = {};
        jsonResponse.forEach((data) {
          staffnames[data['staffmember_id'].toString()] =
              data['staffmember_name'].toString();
        });

        setState(() {
          // Sort staff alphabetically by name (values)
          var sortedEntries = staffnames.entries.toList()
            ..sort((a, b) =>
                a.value.toLowerCase().compareTo(b.value.toLowerCase()));
          staffs = Map.fromEntries(sortedEntries);
          _isLoadingstaff = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingstaff = false;
      });
      // A network failure already flips this screen to the offline state,
      // which says it better than a snackbar stacked on top of it.
      if (!isNetworkError(e))
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
        );
    }
  }

  //for update the workorder
  Future<void> updateWorkOrderSettings() async {
    setState(() {
      isloading = true; // Show loading indicator
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    // Ensure a category is selected
    if (_selectedDropdownCategory == null ||
        _selectedDropdownCategory?.categoryId == null) {
      Fluttertoast.showToast(msg: "Please select a category");
      setState(() {
        isloading = false;
      });
      return;
    }

    final url = '${Api_url}/api/work-order/work-defaults';
    final headers = {
      "authorization": "CRM $token",
      "id": "CRM $id",
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final body = json.encode({
      "admin_id": adminId,
      "category": _selectedDropdownCategory?.categoryId, // Send category_id
      // The dropdown and the server read-back both produce 'Yes'/'No'
      // capitalised (_entry above, entryAllowedString below), so the comparison
      // has to match that casing — a lowercase 'yes' never matches and would
      // send false however the admin set the field.
      "entry_allowed": _selectedEntry == 'Yes',
      "staffmember_id": _selectedstaffId,
      "vendor_id": _selectedvendorsId,
    });

    try {
      final response =
          await apiPost(Uri.parse(url), headers: headers, body: body);

      var responseData = json.decode(response.body);
      if (responseData["statusCode"] == 200) {
        Fluttertoast.showToast(msg: responseData["message"]);
        return json.decode(response.body);
      } else {
        Fluttertoast.showToast(msg: responseData["message"]);
        throw Exception('Failed to add workorder');
      }
    } catch (error) {
      // Handle network error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $error')),
      );
    } finally {
      setState(() {
        isloading = false; // Hide loading indicator
      });
    }
  }

  Future<void> fetchWorkData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    try {
      WorkOrderModel.Data workorder = await fetchWorkOrderSetting();
      String? entryAllowedString;
      if (workorder.workDefaults?.entryAllowed != null) {
        entryAllowedString =
            workorder.workDefaults!.entryAllowed! ? 'Yes' : 'No';
      }
      if (workorder != null) {
        // Get category_id from workDefaults.category
        String? fetchedCategoryId = workorder.workDefaults?.category;
        setState(() {
          _selectedvendorsId = workorder.workDefaults?.vendorId?.isEmpty ?? true
              ? null
              : workorder.workDefaults?.vendorId;
          _selectedstaffId =
              workorder.workDefaults?.staffmemberId?.isEmpty ?? true
                  ? null
                  : workorder.workDefaults?.staffmemberId;
          _selectedEntry = entryAllowedString;
          // Set the dropdown value by matching the ID
          if (fetchedCategoryId != null && _dropdownCategories.isNotEmpty) {
            final match = _dropdownCategories
                .where((cat) => cat.categoryId == fetchedCategoryId)
                .toList();
            if (match.length == 1) {
              _selectedDropdownCategory = match.first;
            } else {
              _selectedDropdownCategory = null;
            }
          } else {
            _selectedDropdownCategory = null;
          }
        });
      }
    } catch (e) {
      logError('Failed to load workorder data: $e');
    }
  }

  // Fetch workorder notification settings
  Future<void> fetchWorkOrderNotificationSettings() async {
    // Don't set loading state - fetch in background
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    if (adminId == null || adminId.isEmpty) {
      return;
    }

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    final url =
        '${Api_url}/api/workorder-settings/workorder-notification/$adminId';
    final headers = {
      "authorization": "CRM $token",
      "id": "CRM $id",
      'Content-Type': 'application/json; charset=UTF-8',
    };

    try {
      final response = await apiGet(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);

        if (responseData["statusCode"] == 200) {
          // Check if data exists
          if (responseData["data"] != null) {
            var data = responseData["data"];
            setState(() {
              createAdmin = data["create_admin"] ?? false;
              createAssignee = data["create_assignee"] ?? false;
              createTenant = data["create_tenant"] ?? false;
              updateAdmin = data["update_admin"] ?? false;
              updateAssignee = data["update_assignee"] ?? false;
              updateTenant = data["update_tenant"] ?? false;
              completeAdmin = data["complete_admin"] ?? false;
              completeAssignee = data["complete_assignee"] ?? false;
              completeTenant = data["complete_tenant"] ?? false;
            });
            setState(() {
              _hasLoadedNotifications = true; // Mark as loaded
            });
          } else {
            // Set default values if no data exists (first time setup)
            setState(() {
              createAdmin = false;
              createAssignee = false;
              createTenant = false;
              updateAdmin = false;
              updateAssignee = false;
              updateTenant = false;
              completeAdmin = false;
              completeAssignee = false;
              completeTenant = false;
              _hasLoadedNotifications =
                  true; // Mark as loaded even with defaults
            });
          }
        } else {}
      } else if (response.statusCode == 404) {
        // First time - no settings exist yet, use defaults
        setState(() {
          createAdmin = false;
          createAssignee = false;
          createTenant = false;
          updateAdmin = false;
          updateAssignee = false;
          updateTenant = false;
          completeAdmin = false;
          completeAssignee = false;
          completeTenant = false;
          _hasLoadedNotifications = true; // Mark as loaded even with defaults
        });
      } else {
        var errorBody = response.body;
        Fluttertoast.showToast(
            msg:
                'Failed to load notification settings: ${response.statusCode}');
      }
    } catch (e) {
      logError('Exception loading workorder notification settings: $e');
      Fluttertoast.showToast(
          msg:
              'Failed to load notification settings: ${friendlyErrorMessage(e)}');
    }
  }

  // Save workorder notification settings
  Future<void> saveWorkOrderNotificationSettings() async {
    setState(() {
      isSavingNotifications = true; // Use separate saving state
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    final url = '${Api_url}/api/workorder-settings/workorder-notification';
    final headers = {
      "authorization": "CRM $token",
      "id": "CRM $id",
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final body = json.encode({
      "admin_id": adminId,
      "create_admin": createAdmin,
      "create_assignee": createAssignee,
      "create_tenant": createTenant,
      "update_admin": updateAdmin,
      "update_assignee": updateAssignee,
      "update_tenant": updateTenant,
      "complete_admin": completeAdmin,
      "complete_assignee": completeAssignee,
      "complete_tenant": completeTenant,
    });

    try {
      final response =
          await apiPost(Uri.parse(url), headers: headers, body: body);
      var responseData = json.decode(response.body);

      if (responseData["statusCode"] == 200) {
        Fluttertoast.showToast(
            msg: responseData["message"] ?? "Settings saved");
      } else {
        Fluttertoast.showToast(
            msg: responseData["message"] ?? "Failed to save settings");
      }
    } catch (error) {
      logError('Error saving notification settings: $error');
      Fluttertoast.showToast(msg: 'An error occurred while saving settings');
    } finally {
      setState(() {
        isSavingNotifications = false; // Use separate saving state
      });
    }
  }

  //for date formate
  Future<void> updateDateFormat(String format, String adminId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    final url = Uri.parse('${Api_url}/api/themes/date-format');
    final response = await apiPost(
      url,
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: json.encode({
        'format': format,
        'admin_id': adminId,
      }),
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to Date format');
    }
  }

  TextEditingController _customDateController = TextEditingController();
  bool _isStaff = false;
  bool _isInitialized = false;

  /// Whether the signed-in user may CHANGE settings (Surcharge / Late Fee).
  ///
  /// Per the Staff Permissions table (Settings > Team & Access) Settings is
  /// "View only" for staff: the permission schema exposes `setting_view` with
  /// no add/edit/delete counterpart, so a staff member may read these values
  /// but only an Admin may change them (the server applies the same rule to
  /// team management: "Only an Admin can manage team members."). Admins are
  /// unaffected.
  ///
  /// If the backend ever adds a `setting_edit` permission, wire it in here —
  /// this is the single choke point used by the fields, the action buttons and
  /// the save methods.
  ///
  /// Fails CLOSED: the role is resolved asynchronously by [_checkUserType], so
  /// until `_isInitialized` flips we treat the section as read-only. Otherwise a
  /// staff member would see editable fields for the first frame (`_isStaff`
  /// defaults to false). Admins simply become editable once the role is known.
  bool get _canEditSettings => _isInitialized && !_isStaff;

  /// Inline notice shown in place of the editing controls when a staff member
  /// views a read-only settings section.
  Widget _viewOnlyNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: Color(0xFF8A95A8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'View only — only an Admin can change these settings.',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 500 ? 13 : 15,
                color: const Color(0xFF6B7A90),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _checkUserType() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? staffid = prefs.getString("staff_id");
    String? adminId = prefs.getString('adminId');
    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;

    setState(() {
      _isStaff = (staffid != null && staffid.isNotEmpty);
      _isInitialized = true;
    });
  }

  static const List<String> _settingsTabTitles = [
    'Accounts',
    'Company Profile',
    'Categories',
    // 'Charges',
    'Date Format',
    'Late Fees',
    'Email Services',
    'Property Owners',
    'Property Type',
    'Surcharges',
    'Templates',
    'Work Order',
    'Vendors',

    //   'Twilio',
  ];

  String _getCurrentSettingsTab() {
    if (isaccounts) return 'Accounts';
    if (iscompanyprofile) return 'Company Profile';
    if (iscategories) return 'Categories';
    if (ischargesetting) return 'Charges';
    if (isdateformate) return 'Date Format';
    if (islatefee) return 'Late Fees';
    if (ismanagetemplate) return 'Templates';
    if (ismail) return 'Email Services';
    if (isworkorder) return 'Work Order';
    if (ispropertyowner) return 'Property Owners';
    if (ispropertytype) return 'Property Type';
    if (issurge) return 'Surcharges';
    if (isvendor) return 'Vendors';
    if (istwilio) return 'Twilio';
    if (isteamaccess) return 'Team & Access';

    return 'Accounts';
  }

  void _onSettingsTabChanged(String value) {
    setState(() {
      issurge = value == 'Surcharges';
      iscompanyprofile = value == 'Company Profile';
      ismail = value == 'Email Services';
      isaccounts = value == 'Accounts';
      islatefee = value == 'Late Fees';
      isdateformate = value == 'Date Format';
      isworkorder = value == 'Work Order';
      ismanagetemplate = value == 'Templates';
      ischargesetting = value == 'Charges';
      iscategories = value == 'Categories';
      isvendor = value == 'Vendors' || value == 'Vendor';
      istwilio = value == 'Twilio';
      ispropertyowner = value == 'Property Owners';
      ispropertytype = value == 'Property Type';
      isteamaccess = value == 'Team & Access';
      if (value == 'Date Format') {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        dateformateselect = dateProvider.dateformateselect;
        timeformateselect = dateProvider.timeformateselect;
        DateTime now = DateTime.now();
        dateformate1 = DateFormat('MM/dd/yyyy').format(now);
        dateformate2 = DateFormat('yyyy-MM-dd').format(now);
        dateformate3 = DateFormat('yyyy-MMM-dd').format(now);
        timeformate1 = DateFormat('HH:mm:ss').format(now);
        timeformate2 = DateFormat('h:mm:ss a').format(now);
      }
      if (value == 'Late Fees') {
        fetchAccountsData();
        fetchlatefeeData();
      }
      if (value == 'Work Order') {
        _loadDropdownCategories();
        fetchWorkData();
        fetchWorkOrderNotificationSettings();
      }
      if (value == 'Twilio') {
        fetchTwilioSettings();
      }
    });
    if (value == 'Company Profile' && !_cpLoadedOnce) {
      _fetchCompanyProfile();
    }
  }

  static IconData _iconForSettingsTab(String title) {
    switch (title) {
      case 'Accounts':
        return Icons.account_balance;
      case 'Company Profile':
        return Icons.business;
      case 'Categories':
        return Icons.category;
      case 'Charges':
        return Icons.attach_money;
      case 'Date Format':
        return Icons.calendar_today;
      case 'Late Fees':
        return Icons.schedule;
      case 'Templates':
        return Icons.description;
      case 'Email Services':
        return Icons.email;
      case 'Work Order':
        return Icons.build;
      case 'Property Owners':
        return Icons.people;
      case 'Property Type':
        return Icons.home;
      case 'Surcharges':
        return Icons.receipt;
      case 'Vendors':
      case 'Vendor':
        return Icons.store;
      case 'Twilio':
        return Icons.phone;
      case 'Team & Access':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.settings;
    }
  }

  // ===================== Team & Access =====================
  // Settings -> "Team & Access". The section UI lives in its own widget
  // (TeamAccessSection) which fetches admins + staff via TeamRepository and
  // renders the Admins / Staff / Permissions tabs.
  Widget _buildTeamAccessSection() {
    return const TeamAccessSection();
  }

  // ===================== Surcharge (redesigned) =====================
  Widget _surchargeNumberField({
    required TextEditingController controller,
    bool showPercent = false,
    String hint = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: !_canEditSettings,
        cursorColor: blueColor,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // Web parity: percentage surcharge is capped 0–100 at the keystroke
          // level; the flat ($) field keeps plain numeric entry.
          showPercent ? PercentRangeFormatter() : DecimalAmountFormatter(),
        ],
        onChanged: (value) {
          setState(() {});
        },
        style: TextStyle(
          color: blueColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixText: showPercent ? '%' : null,
          suffixStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _achOptionCard({required int value, required String label}) {
    final bool selected = _selectedRadio == value;
    // Unlike the surcharge number fields (readOnly:) and the account dropdown
    // (onChanged: null), this option card is a plain GestureDetector — it had
    // no _canEditSettings check at all, so Staff could change the ACH option
    // even though the fields below it were already locked.
    return Opacity(
      opacity: _canEditSettings ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: !_canEditSettings
            ? null
            : () {
                setState(() {
                  _selectedRadio = value;
                });
              },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF1FB) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? blueColor : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _dtRadioCircle(selected),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: blueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== Late Fee (redesigned) =====================
  Widget _lateFeeLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: blueColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _lateFeeField({
    required TextEditingController controller,
    bool dollar = false,
    bool percent = false,
    bool numeric = true,
    bool decimal = true,
    String hint = '',
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        readOnly: !_canEditSettings,
        cursorColor: blueColor,
        textAlign: dollar ? TextAlign.right : TextAlign.left,
        keyboardType: numeric
            ? TextInputType.numberWithOptions(decimal: decimal)
            : TextInputType.text,
        inputFormatters: numeric
            ? [
                // Web parity: a percent-mode late fee is capped 0–100; a fixed
                // ($) amount keeps plain numeric entry.
                percent
                    ? PercentRangeFormatter()
                    : FilteringTextInputFormatter.allow(
                        RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
              ]
            : null,
        onChanged: (value) {
          setState(() {});
        },
        style: TextStyle(
          color: blueColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: dollar
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 6),
                  child: Center(
                    widthFactor: 1.0,
                    child: Text(
                      '\$',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : null,
          prefixIconConstraints:
              dollar ? const BoxConstraints(minWidth: 30, maxWidth: 34) : null,
          suffixText: percent ? '%' : null,
          suffixStyle: TextStyle(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _lateFeeCalcOption(String value, String label) {
    final bool selected = calculationType == value;
    // Same gap as _achOptionCard: a plain GestureDetector with no
    // _canEditSettings check, so Staff could change Fixed/Percent even though
    // the amount field below it was already locked.
    return Expanded(
      child: Opacity(
        opacity: _canEditSettings ? 1.0 : 0.5,
        child: GestureDetector(
          onTap: !_canEditSettings
              ? null
              : () {
                  setState(() {
                    calculationType = value;
                  });
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF1FB) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? blueColor : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                _dtRadioCircle(selected),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: blueColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLateFeeSection() {
    final bool isNarrow = MediaQuery.of(context).size.width < 500;
    final List<String> accountOptions = <String>{
      "Late Fee Income",
      ...accounts.map((a) => a.account ?? '').where((a) => a.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          "Late Fee Charge",
          style: TextStyle(
            color: blueColor,
            fontWeight: FontWeight.bold,
            fontSize: isNarrow ? 20 : 25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _canEditSettings
              ? "You can set the default late fee charge from here."
              : "Default late fee charge set by your Admin.",
          style: TextStyle(
            fontSize: isNarrow ? 14 : 18,
            color: const Color(0xFF8A95A8),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!_canEditSettings) ...[
          const SizedBox(height: 12),
          _viewOnlyNotice(),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            Icon(Icons.person_outline, color: blueColor, size: 20),
            const SizedBox(width: 8),
            Text(
              "Property Owner",
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.w600,
                fontSize: isNarrow ? 15 : 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "NEW",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        // dropdown_button2 recolors its text to Theme.disabledColor whenever
        // onChanged is null (see below), which gave Staff a generic Material
        // grey instead of the brand navy Admin sees for the same value.
        // Overriding disabledColor keeps the text the same colour/weight as
        // the (also-disabled-but-undimmed) fields around it — no Opacity
        // wrap, since _lateFeeField doesn't dim either.
        Theme(
          data: Theme.of(context).copyWith(disabledColor: blueColor),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                // dropdown_button2 only adds its own extra closed-state sizing
                // padding when width is left unset on both the button and the
                // dropdown menu — width: double.infinity turns that off, so this
                // padding (matching the TextField's contentPadding exactly) is
                // the only thing governing the text's start position.
                buttonStyleData: const ButtonStyleData(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                value: (selectedPropertyOwnerId.isEmpty ||
                        propertyOwners.any((po) =>
                            po.rentalownerId == selectedPropertyOwnerId))
                    ? selectedPropertyOwnerId
                    : "",
                style: TextStyle(
                  fontSize: 15,
                  color: blueColor,
                  fontWeight: FontWeight.w600,
                ),
                iconStyleData: IconStyleData(
                  icon: isLoadingPropertyOwners
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.keyboard_arrow_down, color: blueColor),
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 260,
                  offset: const Offset(0, -4),
                  elevation: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: "",
                    child: Text(
                      "Default (All Properties)",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...propertyOwners
                      .where((po) =>
                          (po.rentalownerId ?? '').isNotEmpty &&
                          (po.rentalOwnerName ?? '').isNotEmpty)
                      .map((po) {
                    return DropdownMenuItem<String>(
                      value: po.rentalownerId,
                      child: Text(
                        po.rentalOwnerName ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                // Settings are view-only for staff — null disables the dropdown.
                onChanged: !_canEditSettings
                    ? null
                    : (String? newValue) {
                        setState(() {
                          selectedPropertyOwnerId = newValue ?? '';
                        });
                      },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _lateFeeLabel("Number of Grace Period Days"),
        const SizedBox(height: 8),
        _lateFeeField(controller: duration, decimal: false, hint: '0'),
        const SizedBox(height: 20),
        _lateFeeLabel("Late Fee Calculation"),
        const SizedBox(height: 8),
        Row(
          children: [
            _lateFeeCalcOption("fixed", "Fixed"),
            const SizedBox(width: 12),
            _lateFeeCalcOption("percent", "Percent"),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lateFeeLabel(
                      calculationType == "fixed" ? "Amount" : "Percentage"),
                  const SizedBox(height: 8),
                  calculationType == "fixed"
                      ? _lateFeeField(controller: late_fee, dollar: true)
                      : _lateFeeField(controller: late_fee, percent: true),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _lateFeeLabel("Min. Balance"),
                  const SizedBox(height: 8),
                  _lateFeeField(controller: grace_balance, dollar: true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Minimum balance owed before a late fee is charged.",
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF8A95A8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        _lateFeeLabel("Charge Account"),
        const SizedBox(height: 8),
        // dropdown_button2 recolors its text to Theme.disabledColor whenever
        // onChanged is null (see below), which gave Staff a generic Material
        // grey instead of the brand navy Admin sees for the same value.
        // Overriding disabledColor keeps the text the same colour/weight as
        // the (also-disabled-but-undimmed) fields around it — no Opacity
        // wrap, since _lateFeeField doesn't dim either.
        Theme(
          data: Theme.of(context).copyWith(disabledColor: blueColor),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                alignment: AlignmentDirectional.centerStart,
                // dropdown_button2 only adds its own extra closed-state sizing
                // padding when width is left unset on both the button and the
                // dropdown menu — width: double.infinity turns that off, so this
                // padding (matching the TextField's contentPadding exactly) is
                // the only thing governing the text's start position.
                buttonStyleData: const ButtonStyleData(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                value: accountOptions.contains(selectedAccountName)
                    ? selectedAccountName
                    : null,
                hint: Text(
                  "Select Account",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: blueColor,
                  fontWeight: FontWeight.w600,
                ),
                iconStyleData: IconStyleData(
                  icon: Icon(Icons.keyboard_arrow_down, color: blueColor),
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 260,
                  offset: const Offset(0, -4),
                  elevation: 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                ),
                items: accountOptions.map((String accountName) {
                  return DropdownMenuItem<String>(
                    value: accountName,
                    child: Text(
                      accountName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                // Settings are view-only for staff — null disables the dropdown.
                onChanged: !_canEditSettings
                    ? null
                    : (String? newValue) {
                        setState(() {
                          selectedAccountName = newValue ?? '';
                          if (newValue == "Late Fee Income") {
                            selectedAccountId = "";
                          } else {
                            Setting4? selectedAccount = accounts.firstWhere(
                              (account) => account.account == newValue,
                              orElse: () => Setting4(),
                            );
                            selectedAccountId = selectedAccount.accountId ?? '';
                          }
                        });
                      },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _lateFeeLabel("Description"),
        const SizedBox(height: 8),
        _lateFeeField(
            controller: description,
            numeric: false,
            hint: 'Enter a description for late fees'),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: GestureDetector(
                // Reset can't save (the Save button next to it is separately
                // gated by _canSaveLateFee()), but readOnly on a TextField only
                // blocks typing — .clear() still blanks it visibly. Staff could
                // wipe the on-screen amount even though nothing persists.
                onTap: !_canEditSettings
                    ? null
                    : () {
                        duration.clear();
                        late_fee.clear();
                      },
                child: Opacity(
                  opacity: _canEditSettings ? 1.0 : 0.5,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: blueColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        "Reset",
                        style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: _canSaveLateFee()
                    ? () async {
                        if (selectedPropertyOwnerId.isNotEmpty)
                          await saveLateFeeOverride();
                        else if (islatefeeupdate)
                          await updateLatefee();
                        else
                          await AddLatefeedata();
                      }
                    : null,
                child: Opacity(
                  opacity: _canSaveLateFee() ? 1.0 : 0.5,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: blueColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Save",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
      ],
    );
  }

  // ===================== Date & Time Settings (redesigned) =====================
  Widget _buildDateTimeSettings() {
    final dateProvider = Provider.of<DateProvider>(context);
    final bool isNarrow = MediaQuery.of(context).size.width < 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "Manage Date & Time Format",
          style: TextStyle(
            color: blueColor,
            fontWeight: FontWeight.w800,
            fontSize: isNarrow ? 18 : 22,
          ),
        ),
        const SizedBox(height: 14),
        _dtDateCard(
          dateProvider: dateProvider,
          value: 0,
          label: "MM/DD/YYYY",
          format: 'MM/dd/yyyy',
          preview: dateformate1,
        ),
        const SizedBox(height: 12),
        _dtDateCard(
          dateProvider: dateProvider,
          value: 1,
          label: "YYYY-MM-DD",
          format: 'yyyy-MM-dd',
          preview: dateformate2,
        ),
        const SizedBox(height: 12),
        _dtDateCard(
          dateProvider: dateProvider,
          value: 2,
          label: "YYYY-MMM-DD",
          format: 'yyyy-MMM-dd',
          preview: dateformate3,
        ),
        const SizedBox(height: 12),
        _dtDateCard(
          dateProvider: dateProvider,
          value: 3,
          label: "Custom",
          format: null,
          preview: null,
        ),
        if (dateformateselect == 3) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: customdate != null && customdate!.isNotEmpty
                ? customdate
                : dateProvider.dateFormat.toUpperCase(),
            onChanged: (value) {
              setState(() {
                customdate = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Custom format (e.g. DD-MM-YYYY)',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
            ),
          ),
        ],
        const SizedBox(height: 26),
        // Time Format section
        Row(
          children: [
            Icon(Icons.access_time, color: blueColor, size: 20),
            const SizedBox(width: 8),
            Text(
              "Time Format",
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.bold,
                fontSize: isNarrow ? 15 : 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _dtTimeCard(
          dateProvider: dateProvider,
          value: 0,
          title: "24-hour format",
          example: "e.g. 14:00:00",
          format: '24',
          preview: timeformate1,
        ),
        const SizedBox(height: 12),
        _dtTimeCard(
          dateProvider: dateProvider,
          value: 1,
          title: "12-hour format",
          example: "e.g. 2:00:00 PM",
          format: '12',
          preview: timeformate2,
        ),
        const SizedBox(height: 26),
        // How it appears
        _dtHowItAppears(dateProvider),
        const SizedBox(height: 26),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final dp = Provider.of<DateProvider>(context, listen: false);
                  await dp.loadDateFormat();
                  setState(() {
                    dateformateselect = dp.dateformateselect;
                    timeformateselect = dp.timeformateselect;
                    customdate = null;
                    _customDateController.text = "";
                  });
                  Fluttertoast.showToast(
                    msg: "Reset to saved settings",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.black87,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: blueColor, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      "Reset",
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  customdate = customdate != null && customdate!.isNotEmpty
                      ? customdate
                      : dateProvider.dateFormat;
                  if (dateformateselect == 0) {
                    context
                        .read<DateProvider>()
                        .updateDateFormat('MM/dd/yyyy', 0);
                  } else if (dateformateselect == 1) {
                    context
                        .read<DateProvider>()
                        .updateDateFormat('yyyy-MM-dd', 1);
                  } else if (dateformateselect == 2) {
                    context
                        .read<DateProvider>()
                        .updateDateFormat('yyyy-MMM-dd', 2);
                  } else if (dateformateselect == 3 && customdate != null) {
                    String fixedDate = fixDateFormat(customdate!);
                    context.read<DateProvider>().updateDateFormat(fixedDate, 3);
                  }
                  Fluttertoast.showToast(
                    msg: "Date format updated successfully",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: Colors.black87,
                    textColor: Colors.white,
                    fontSize: 16.0,
                  );
                },
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: blueColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Save Changes",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _dtRadioCircle(bool selected) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? blueColor : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: blueColor,
                ),
              ),
            )
          : null,
    );
  }

  Widget _dtPreviewChip(String text, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? Colors.white : const Color(0xFFEDF0F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? blueColor.withOpacity(0.35) : Colors.transparent,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: selected ? blueColor : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _dtDateCard({
    required DateProvider dateProvider,
    required int value,
    required String label,
    required String? format,
    required String? preview,
  }) {
    final bool selected = dateformateselect == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (format != null) {
            dateProvider.updateDateFormatLocally(format, value);
          } else {
            customdate = "";
            _customDateController.text = "";
          }
          dateformateselect = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? blueColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _dtRadioCircle(selected),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: blueColor,
                ),
              ),
            ),
            if (preview != null && preview.isNotEmpty)
              _dtPreviewChip(preview, selected),
          ],
        ),
      ),
    );
  }

  Widget _dtTimeCard({
    required DateProvider dateProvider,
    required int value,
    required String title,
    required String example,
    required String format,
    required String? preview,
  }) {
    final bool selected = timeformateselect == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          dateProvider.updateTimeFormat(format, value);
          timeformateselect = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? blueColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            _dtRadioCircle(selected),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: blueColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    example,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            if (preview != null && preview.isNotEmpty)
              _dtPreviewChip(preview, selected),
          ],
        ),
      ),
    );
  }

  Widget _dtHowItAppears(DateProvider dateProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF3FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, size: 18, color: blueColor),
                const SizedBox(width: 8),
                Text(
                  "HOW IT APPEARS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: blueColor,
                    letterSpacing: 1.1,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Date & Time",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateProvider.getFormattedDateTimePreview(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: blueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTabDropdown() {
    final current = _getCurrentSettingsTab();
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      //padding: const EdgeInsets.symmetric(horizontal: ),
      child: DropdownButton2<String>(
        isExpanded: true,
        underline: const SizedBox(),
        value: current,
        items: _settingsTabTitles.asMap().entries.map((entry) {
          final index = entry.key;
          final title = entry.value;
          return DropdownMenuItem<String>(
            value: title,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: index < _settingsTabTitles.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: blueColor.withOpacity(0.2),
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(_iconForSettingsTab(title), size: 20, color: blueColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: blueColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 25, color: blueColor),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) _onSettingsTabChanged(value);
        },
        selectedItemBuilder: (BuildContext context) {
          return _settingsTabTitles.map((String title) {
            return Row(
              children: [
                Icon(_iconForSettingsTab(title), size: 20, color: blueColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: blueColor,
                  ),
                ),
              ],
            );
          }).toList();
        },
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400!, width: 1),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        iconStyleData: IconStyleData(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          iconSize: 24,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade400!, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: MaterialStateProperty.all(false),
          ),
        ),
        menuItemStyleData: MenuItemStyleData(
          height: 50,
          padding: EdgeInsets.zero,
          overlayColor: MaterialStateProperty.all(Colors.grey[100]),
        ),
      ),
    );
  }

  // ===================== Redesigned settings menu =====================
  // Categorized list of every settings section. Each item's [title] maps to
  // the same value handled by [_onSettingsTabChanged], so tapping a card
  // reuses all existing data-loading / content logic unchanged.
  List<_SettingsMenuSection> get _settingsMenuSections => const [
        _SettingsMenuSection('COMPANY', [
          _SettingsMenuItem('Company Profile',
              'Business details, logo & address', Icons.apartment_outlined),
          _SettingsMenuItem('Accounts', 'Bank & liability accounts',
              Icons.account_balance_outlined),
          _SettingsMenuItem('Categories', 'Income & expense categories',
              Icons.category_outlined),
        ]),
        _SettingsMenuSection('TEAM', [
          _SettingsMenuItem(
              'Team & Access',
              'Team members, roles & permissions',
              Icons.manage_accounts_outlined),
        ]),
        _SettingsMenuSection('FINANCIAL', [
          _SettingsMenuItem('Surcharges', 'Recurring fees & add-ons',
              Icons.receipt_long_outlined),
          _SettingsMenuItem('Late Fees', 'Grace period & penalty rules',
              Icons.schedule_outlined),
        ]),
        _SettingsMenuSection('PROPERTIES', [
          _SettingsMenuItem('Property Owners', 'Owner records & payouts',
              Icons.people_alt_outlined),
          _SettingsMenuItem('Property Type', 'Categorize your portfolio',
              Icons.home_outlined),
          _SettingsMenuItem('Vendors', 'Service providers & contacts',
              Icons.storefront_outlined),
        ]),
        _SettingsMenuSection('OPERATIONS', [
          _SettingsMenuItem('Work Order', 'Statuses & assignment rules',
              Icons.build_outlined),
          _SettingsMenuItem('Templates', 'Lease & document templates',
              Icons.description_outlined),
        ]),
        _SettingsMenuSection('PREFERENCES', [
          _SettingsMenuItem('Date Format', 'Date & time display format',
              Icons.calendar_today_outlined,
              badge: 'SET'),
          _SettingsMenuItem('Email Services', 'SMTP & notification senders',
              Icons.mail_outline),
        ]),
      ];

  Widget _buildSettingsMenu() {
    final q = _settingsSearchQuery.trim().toLowerCase();
    final filtered = _settingsMenuSections
        .map((s) => _SettingsMenuSection(
            s.header,
            s.items
                .where((it) =>
                    q.isEmpty ||
                    it.title.toLowerCase().contains(q) ||
                    it.subtitle.toLowerCase().contains(q))
                .toList()))
        .where((s) => s.items.isNotEmpty)
        .toList();

    return Container(
      color: const Color(0xFFF1F4F9),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
        children: [
          _buildSettingsSearchField(),
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            _buildNoSettingsResults()
          else
            ...filtered.map(_buildSettingsMenuSection),
        ],
      ),
    );
  }

  Widget _buildSettingsSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _settingsSearchController,
        onChanged: (v) => setState(() => _settingsSearchQuery = v),
        cursorColor: blueColor,
        style: TextStyle(
            color: blueColor, fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search settings',
          hintStyle: const TextStyle(
            color: Color(0xFF8A95A8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8A95A8)),
          suffixIcon: _settingsSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close,
                      color: Color(0xFF8A95A8), size: 20),
                  onPressed: () {
                    setState(() {
                      _settingsSearchController.clear();
                      _settingsSearchQuery = '';
                    });
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSettingsMenuSection(_SettingsMenuSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
          child: Text(
            section.header,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF8A95A8),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < section.items.length; i++) ...[
                _buildSettingsMenuTile(section.items[i]),
                if (i != section.items.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 74, right: 16),
                    child: Divider(
                        height: 1, thickness: 1, color: Color(0xFFEEF1F5)),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }

  Widget _buildSettingsMenuTile(_SettingsMenuItem item) {
    final bool isActive = _activeSettingsTitle == item.title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSettingsSection(item.title),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEEF1FB) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: blueColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: blueColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF8A95A8),
                      ),
                    ),
                  ],
                ),
              ),
              if (item.badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF3E4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.badge!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF2E7D45),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right,
                  color: Color(0xFFAEB7C7), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSettingsResults() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 54, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            'No settings found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: blueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  void _openSettingsSection(String title) {
    // Reuse the existing tab logic (sets flags + triggers data loads).
    _onSettingsTabChanged(title);
    setState(() {
      _showSettingsMenu = false;
      _activeSettingsTitle = title;
      _settingsSearchController.clear();
      _settingsSearchQuery = '';
    });
    FocusScope.of(context).unfocus();
  }

  void _backToSettingsMenu() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSettingsMenu = true;
    });
  }

  Widget _buildSettingsDetailHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 14),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _backToSettingsMenu,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF1F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:
                          Icon(Icons.chevron_left, color: blueColor, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _getCurrentSettingsTab(),
                    style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize:
                          MediaQuery.of(context).size.width < 500 ? 24 : 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE7EBF1)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs
      child: Scaffold(
        //appBar: widget_302.App_Bar(context: context, isSettingPageActive: true),
        appBar: !_isInitialized
            ? widget_302.App_Bar(context: context, isSettingPageActive: true)
            : (_isStaff
                ? widget_302_Staff.widget_302_Staff.App_Bar(context: context)
                : widget_302.App_Bar(
                    context: context, isSettingPageActive: true)),
        backgroundColor: Colors.white,
        drawer: !_isInitialized
            ? CustomDrawer(
                currentpage: "Settings",
                dropdown: false,
              )
            : (_isStaff
                ? CustomDrawerStaff(
                    currentpage: "Settings",
                    dropdown: true,
                  )
                : CustomDrawer(
                    currentpage: "Settings",
                    dropdown: false,
                  )),
        // drawer:
        // CustomDrawer(
        //   currentpage: "Settings",
        //   dropdown: false,
        // ),
        body: !isOffline
            ? (_showSettingsMenu
                ? _buildSettingsMenu()
                : Container(
                    color: const Color(0xFFF1F4F9),
                    child: ListView(padding: EdgeInsets.zero, children: [
                      _buildSettingsDetailHeader(),
                      const SizedBox(
                        height: 16,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 18, right: 18),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            //border: Border.all(color: blueColor),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 8),
                              if (issurge)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    Text(
                                      "Surcharge",
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 20
                                                : 25,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _canEditSettings
                                          ? "You can set the default surcharge percentage from here."
                                          : "Default surcharge percentages set by your Admin.",
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 14
                                                : 18,
                                        color: const Color(0xFF8A95A8),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!_canEditSettings) ...[
                                      const SizedBox(height: 12),
                                      _viewOnlyNotice(),
                                    ],
                                    const SizedBox(height: 22),
                                    Text(
                                      "Account to receive surcharges",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton2<String?>(
                                          isExpanded: true,
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          value: selectedAccount != null &&
                                                  accounts.any((account) =>
                                                      account.accountId ==
                                                      selectedAccount)
                                              ? selectedAccount
                                              : null,
                                          hint: Text(
                                            "Select Account",
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: blueColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          // dropdown_button2 only adds its own extra
                                          // closed-state sizing padding when width is
                                          // left unset on both the button and the
                                          // dropdown menu — width: double.infinity
                                          // turns that off, so this padding (matching
                                          // the TextField's contentPadding exactly)
                                          // is the only thing governing where the
                                          // text starts.
                                          buttonStyleData:
                                              const ButtonStyleData(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16),
                                          ),
                                          iconStyleData: IconStyleData(
                                            icon: Icon(
                                                Icons.keyboard_arrow_down,
                                                color: blueColor),
                                            iconSize: 26,
                                          ),
                                          dropdownStyleData: DropdownStyleData(
                                            maxHeight: 260,
                                            offset: const Offset(0, -6),
                                            elevation: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.grey.shade200),
                                            ),
                                            scrollbarTheme: ScrollbarThemeData(
                                              radius: const Radius.circular(8),
                                              thickness:
                                                  WidgetStateProperty.all(5),
                                              thumbVisibility:
                                                  WidgetStateProperty.all(true),
                                            ),
                                          ),
                                          menuItemStyleData:
                                              const MenuItemStyleData(
                                            height: 48,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16),
                                          ),
                                          items:
                                              accounts.map((Setting4 account) {
                                            return DropdownMenuItem<String>(
                                              value: account.accountId,
                                              child: Text(
                                                account.account!,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          // Settings are view-only for staff — null disables the dropdown.
                                          onChanged: !_canEditSettings
                                              ? null
                                              : (String? newValue) {
                                                  setState(() {
                                                    selectedAccount = newValue;
                                                    _accountError = null;
                                                  });
                                                },
                                        ),
                                      ),
                                    ),
                                    if (_accountError != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        _accountError!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Credit Card Surcharge %",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _surchargeNumberField(
                                                controller: credit,
                                                showPercent: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "Debit Card Surcharge %",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              _surchargeNumberField(
                                                controller: debit,
                                                showPercent: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 18, vertical: 16),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEFF3F9),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(16),
                                                topRight: Radius.circular(16),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "ACH SURCHARGE",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: blueColor,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "Supports a percentage, a flat fee, or both.",
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF8A95A8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                16, 16, 16, 16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _achOptionCard(
                                                  value: 1,
                                                  label: "Percentage only",
                                                ),
                                                _achOptionCard(
                                                  value: 2,
                                                  label: "Flat fee only",
                                                ),
                                                _achOptionCard(
                                                  value: 3,
                                                  label:
                                                      "Both percentage and flat fee",
                                                ),
                                                if (_selectedRadio == 1 ||
                                                    _selectedRadio == 3) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    "ACH Percentage",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _surchargeNumberField(
                                                    controller: percent,
                                                    showPercent: true,
                                                  ),
                                                ],
                                                if (_selectedRadio == 2 ||
                                                    _selectedRadio == 3) ...[
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    "ACH Flat Fee",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  _surchargeNumberField(
                                                    controller: flat,
                                                    hint: '\$0.00',
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: GestureDetector(
                                            // Same gap as the Late Fee Reset button:
                                            // this can't save (gated separately by
                                            // _canEditSettings on the Save/Update
                                            // action), but .clear() still blanks the
                                            // readOnly fields visibly. Staff could
                                            // wipe every surcharge value and the
                                            // selected account on screen.
                                            onTap: !_canEditSettings
                                                ? null
                                                : () {
                                                    debit.clear();
                                                    credit.clear();
                                                    flat.clear();
                                                    percent.clear();
                                                    setState(() {
                                                      selectedAccount = null;
                                                    });
                                                  },
                                            child: Opacity(
                                              opacity:
                                                  _canEditSettings ? 1.0 : 0.5,
                                              child: Container(
                                                height: 54,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: blueColor,
                                                      width: 1.5),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    "Reset",
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          flex: 3,
                                          child: GestureDetector(
                                            onTap: _hasSurchargeChanges()
                                                ? () async {
                                                    if (selectedAccount ==
                                                        null) {
                                                      setState(() {
                                                        _accountError =
                                                            "Please select an account";
                                                      });
                                                      return;
                                                    }
                                                    setState(() {
                                                      _accountError = null;
                                                    });
                                                    if (isupdate)
                                                      await updateSurcharge();
                                                    else
                                                      await AddSurgedata();
                                                  }
                                                : null,
                                            child: Opacity(
                                              opacity: _hasSurchargeChanges()
                                                  ? 1.0
                                                  : 0.5,
                                              child: Container(
                                                height: 54,
                                                decoration: BoxDecoration(
                                                  color: blueColor,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.check,
                                                        color: Colors.white,
                                                        size: 20),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      "Update",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                        height: MediaQuery.of(context)
                                                .padding
                                                .bottom +
                                            24),
                                  ],
                                ),
                              if (isteamaccess) _buildTeamAccessSection(),
                              if (iscompanyprofile)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 15),
                                    _buildCompanyProfileForm(),
                                  ],
                                ),
                              if (ismail) _buildMailServiceSection(),
                              if (islatefee) _buildLateFeeSection(),
                              if (isaccounts)
                                Column(
                                  children: [
                                    const SizedBox(height: 15),
                                    Row(
                                      children: [
                                        Text(
                                          "Manage Account",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 18
                                                : 25,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: () async {
                                            _showAccount(context);
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(5.0),
                                            child: Container(
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  .045,
                                              width: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 120
                                                  : 180,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                color: blueColor,
                                                boxShadow: [
                                                  const BoxShadow(
                                                    color: Colors.grey,
                                                    offset: Offset(
                                                        0.0, 1.0), //(x,y)
                                                    blurRadius: 6.0,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: isLoading
                                                    ? const SpinKitFadingCircle(
                                                        color: Colors.white,
                                                        size: 25.0,
                                                      )
                                                    : Text(
                                                        "Add Account",
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width <
                                                                    500
                                                                ? 15
                                                                : 18),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    if (MediaQuery.of(context).size.width > 500)
                                      const SizedBox(height: 25),
                                    if (MediaQuery.of(context).size.width < 500)
                                      if (MediaQuery.of(context).size.width <
                                          500)
                                        FutureBuilder<List<Setting4>>(
                                          future: futureaccount,
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return ColabShimmerLoadingWidget();
                                            } else if (snapshot.hasError) {
                                              return Center(
                                                  child: Text(
                                                      friendlyErrorMessage(
                                                          snapshot.error)));
                                            } else if (!snapshot.hasData ||
                                                snapshot.data!.isEmpty) {
                                              return Container(
                                                height: MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    .5,
                                                child: Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Image.asset(
                                                        "assets/images/no_data.jpg",
                                                        height: 200,
                                                        width: 200,
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        "No Data Available",
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: blueColor,
                                                            fontSize: 16),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              );
                                            } else {
                                              var data = snapshot.data!;
                                              if (searchValue == null ||
                                                  searchValue!.isEmpty) {
                                                data = snapshot.data!;
                                              } else if (searchValue == "All") {
                                                data = snapshot.data!;
                                              } else if (searchValue!
                                                  .isNotEmpty) {
                                                data = snapshot.data!
                                                    .where((staff) => (staff
                                                                .account ??
                                                            '')
                                                        .toLowerCase()
                                                        .contains(searchValue!
                                                            .toLowerCase()))
                                                    .toList();
                                              } else {
                                                data = snapshot.data!
                                                    .where((staff) =>
                                                        staff.accountType ==
                                                        searchValue)
                                                    .toList();
                                              }
                                              sortData(data);
                                              final totalPages = (data.isEmpty
                                                  ? 1
                                                  : (data.length / itemsPerPage)
                                                      .ceil());
                                              final currentPageData = data
                                                  .skip(currentPage *
                                                      itemsPerPage)
                                                  .take(itemsPerPage)
                                                  .toList();
                                              return SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    const SizedBox(height: 10),
                                                    _buildHeaders(),
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      // decoration: BoxDecoration(
                                                      //   border: Border.all(
                                                      //       color: Color.fromRGBO(
                                                      //           152, 162, 179, .5)),
                                                      // ),
                                                      // decoration: BoxDecoration(
                                                      //     border: Border.all(color: blueColor)),
                                                      child: Column(
                                                        children: currentPageData
                                                                .isEmpty
                                                            ? [
                                                                kNoSearchResults(
                                                                    context)
                                                              ]
                                                            : currentPageData
                                                                .asMap()
                                                                .entries
                                                                .map((entry) {
                                                                int index =
                                                                    entry.key;
                                                                bool
                                                                    isExpanded =
                                                                    expandedIndex ==
                                                                        index;
                                                                Setting4
                                                                    account =
                                                                    entry.value;
                                                                //return CustomExpansionTile(data: Propertytype, index: index);
                                                                return Container(
                                                                  margin: const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          6),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: index %
                                                                                2 !=
                                                                            0
                                                                        ? const Color(
                                                                            0xFFF4F8FF)
                                                                        : Colors
                                                                            .white,
                                                                    border: Border.all(
                                                                        color: const Color(
                                                                            0xFFDBE0E5)),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10),
                                                                  ),
                                                                  // decoration: BoxDecoration(
                                                                  //   border: Border.all(color: blueColor),
                                                                  // ),
                                                                  child: Column(
                                                                    children: <Widget>[
                                                                      ListTile(
                                                                        contentPadding:
                                                                            EdgeInsets.zero,
                                                                        title:
                                                                            Padding(
                                                                          padding: const EdgeInsets
                                                                              .all(
                                                                              2.0),
                                                                          child:
                                                                              Row(
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
                                                                                    if (expandedIndex == index) {
                                                                                      expandedIndex = null;
                                                                                    } else {
                                                                                      expandedIndex = index;
                                                                                    }
                                                                                  });
                                                                                },
                                                                                child: Container(
                                                                                  margin: const EdgeInsets.only(left: 5, right: 5),
                                                                                  padding: !isExpanded ? const EdgeInsets.only(bottom: 10) : const EdgeInsets.only(top: 10),
                                                                                  child: FaIcon(
                                                                                    isExpanded ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                                    size: 20,
                                                                                    color: blueColor,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              Expanded(
                                                                                child: InkWell(
                                                                                  onTap: () {
                                                                                    setState(() {
                                                                                      if (expandedIndex == index) {
                                                                                        expandedIndex = null;
                                                                                      } else {
                                                                                        expandedIndex = index;
                                                                                      }
                                                                                    });
                                                                                  },
                                                                                  child: Text(
                                                                                    '${account.account}',
                                                                                    style: TextStyle(
                                                                                      color: blueColor,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      fontSize: 13,
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              SizedBox(width: MediaQuery.of(context).size.width * .07),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  '${account.accountType}',
                                                                                  style: TextStyle(
                                                                                    color: blueColor,
                                                                                    fontWeight: FontWeight.bold,
                                                                                    fontSize: 13,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              SizedBox(width: MediaQuery.of(context).size.width * .03),
                                                                              Expanded(
                                                                                child: Text(
                                                                                  '${account.fundType}',
                                                                                  style: TextStyle(
                                                                                    color: blueColor,
                                                                                    fontWeight: FontWeight.bold,
                                                                                    fontSize: 13,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              SizedBox(width: MediaQuery.of(context).size.width * .02),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      if (isExpanded)
                                                                        Container(
                                                                          padding: const EdgeInsets
                                                                              .only(
                                                                              left: 2,
                                                                              right: 2),
                                                                          margin: const EdgeInsets
                                                                              .only(
                                                                              bottom: 2),
                                                                          child:
                                                                              SingleChildScrollView(
                                                                            child:
                                                                                Container(
                                                                              //color: Colors.blue,
                                                                              child: Column(
                                                                                children: [
                                                                                  Row(
                                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                                    //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                    children: [
                                                                                      GestureDetector(
                                                                                        onTap: () async {
                                                                                          _showEditAccount(context, account);
                                                                                        },
                                                                                        child: Container(
                                                                                          height: 35,
                                                                                          width: 35,
                                                                                          decoration: BoxDecoration(
                                                                                            color: Colors.green.shade50,
                                                                                            borderRadius: BorderRadius.circular(8),
                                                                                          ),
                                                                                          child: Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                                                            children: [
                                                                                              FaIcon(
                                                                                                FontAwesomeIcons.edit,
                                                                                                size: 15,
                                                                                                color: Colors.green,
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                      SizedBox(width: 10),
                                                                                      GestureDetector(
                                                                                        onTap: () {
                                                                                          _showDeleteAlert(context, account.accountId!);
                                                                                        },
                                                                                        child: Container(
                                                                                          height: 35,
                                                                                          width: 35,
                                                                                          decoration: BoxDecoration(
                                                                                            color: Colors.red.shade50,
                                                                                            borderRadius: BorderRadius.circular(8),
                                                                                          ),
                                                                                          child: const Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                                                            children: [
                                                                                              FaIcon(
                                                                                                FontAwesomeIcons.trashCan,
                                                                                                size: 15,
                                                                                                color: Colors.red,
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                      const SizedBox(width: 10),
                                                                                    ],
                                                                                  ),
                                                                                  const SizedBox(height: 10),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }).toList(),
                                                      ),
                                                    ),
                                                    if (totalPages > 1) ...[
                                                      const SizedBox(
                                                          height: 20),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              // Text('Rows per page:'),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Material(
                                                                elevation: 3,
                                                                child:
                                                                    Container(
                                                                  height: 40,
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12.0),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .grey),
                                                                  ),
                                                                  child:
                                                                      DropdownButtonHideUnderline(
                                                                    child:
                                                                        DropdownButton<
                                                                            int>(
                                                                      value:
                                                                          itemsPerPage,
                                                                      items: itemsPerPageOptions
                                                                          .map((int
                                                                              value) {
                                                                        return DropdownMenuItem<
                                                                            int>(
                                                                          value:
                                                                              value,
                                                                          child:
                                                                              Text(value.toString()),
                                                                        );
                                                                      }).toList(),
                                                                      onChanged: data.length >
                                                                              itemsPerPageOptions.first // Condition to check if dropdown should be enabled
                                                                          ? (newValue) {
                                                                              setState(() {
                                                                                itemsPerPage = newValue!;
                                                                                currentPage = 0; // Reset to first page when items per page change
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
                                                                  color: currentPage ==
                                                                          0
                                                                      ? Colors
                                                                          .grey
                                                                      : blueColor,
                                                                ),
                                                                onPressed:
                                                                    currentPage ==
                                                                            0
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
                                                                  color: currentPage <
                                                                          totalPages -
                                                                              1
                                                                      ? blueColor
                                                                      : Colors
                                                                          .grey,
                                                                ),
                                                                onPressed:
                                                                    currentPage <
                                                                            totalPages -
                                                                                1
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
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    if (MediaQuery.of(context).size.width > 500)
                                      FutureBuilder<List<Setting4>>(
                                        future: futureaccount,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return ShimmerTabletTable();
                                          } else if (snapshot.hasError) {
                                            return Center(
                                                child: Text(
                                                    friendlyErrorMessage(
                                                        snapshot.error),
                                                    textAlign:
                                                        TextAlign.center));
                                          } else if (!snapshot.hasData ||
                                              snapshot.data!.isEmpty) {
                                            return Container(
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  .5,
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/no_data.jpg",
                                                      height: 200,
                                                      width: 200,
                                                    ),
                                                    const SizedBox(
                                                      height: 10,
                                                    ),
                                                    Text(
                                                      "No Data Available",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: blueColor,
                                                          fontSize: 16),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            );
                                          } else {
                                            List<Setting4>? filteredData = [];
                                            if (selectedRole == null &&
                                                searchValue == "") {
                                              filteredData = snapshot.data;
                                            } else if (selectedRole == "All") {
                                              filteredData = snapshot.data;
                                            } else if (searchValue.isNotEmpty) {
                                              filteredData = snapshot.data!
                                                  .where((staff) =>
                                                      (staff.account ?? '')
                                                          .toLowerCase()
                                                          .contains(searchValue
                                                              .toLowerCase()) ||
                                                      (staff.accountType ?? '')
                                                          .toLowerCase()
                                                          .contains(searchValue
                                                              .toLowerCase()))
                                                  .toList();
                                            } else {
                                              filteredData = snapshot.data!
                                                  .where((staff) =>
                                                      staff.accountType ==
                                                      selectedRole)
                                                  .toList();
                                            }
                                            //_tableData = snapshot.data!;
                                            // _tableData = snapshot.data!;
                                            _tableData = filteredData!;
                                            totalrecords = _tableData.length;
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5.0,
                                                      vertical: 5),
                                              child: Column(
                                                children: [
                                                  SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Container(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              .91,
                                                      child: Table(
                                                        defaultColumnWidth:
                                                            const IntrinsicColumnWidth(),
                                                        children: [
                                                          TableRow(
                                                            decoration:
                                                                BoxDecoration(
                                                                    border: Border
                                                                        .all()),
                                                            children: [
                                                              _buildHeader(
                                                                  'Account',
                                                                  0,
                                                                  (staff) => staff
                                                                      .account!),
                                                              _buildHeader(
                                                                  'Type',
                                                                  1,
                                                                  (staff) => staff
                                                                      .accountType!),
                                                              _buildHeader(
                                                                  'ChargeType',
                                                                  2,
                                                                  null),
                                                              _buildHeader(
                                                                  'FundType',
                                                                  3,
                                                                  null),
                                                              _buildHeader(
                                                                  'Actions',
                                                                  4,
                                                                  null),
                                                            ],
                                                          ),
                                                          TableRow(
                                                            decoration:
                                                                const BoxDecoration(
                                                              border: Border.symmetric(
                                                                  horizontal:
                                                                      BorderSide
                                                                          .none),
                                                            ),
                                                            children: List.generate(
                                                                5,
                                                                (index) => TableCell(
                                                                    child: Container(
                                                                        height:
                                                                            20))),
                                                          ),
                                                          for (var i = 0;
                                                              i <
                                                                  _pagedData
                                                                      .length;
                                                              i++)
                                                            TableRow(
                                                              decoration:
                                                                  BoxDecoration(
                                                                border: Border(
                                                                  left: const BorderSide(
                                                                      color: Color
                                                                          .fromRGBO(
                                                                              21,
                                                                              43,
                                                                              81,
                                                                              1)),
                                                                  right: const BorderSide(
                                                                      color: Color
                                                                          .fromRGBO(
                                                                              21,
                                                                              43,
                                                                              81,
                                                                              1)),
                                                                  top: const BorderSide(
                                                                      color: Color
                                                                          .fromRGBO(
                                                                              21,
                                                                              43,
                                                                              81,
                                                                              1)),
                                                                  bottom: i ==
                                                                          _pagedData.length -
                                                                              1
                                                                      ? const BorderSide(
                                                                          color: Color.fromRGBO(
                                                                              21,
                                                                              43,
                                                                              81,
                                                                              1))
                                                                      : BorderSide
                                                                          .none,
                                                                ),
                                                              ),
                                                              children: [
                                                                _buildDataCell(
                                                                    _pagedData[
                                                                            i]
                                                                        .account!),
                                                                _buildDataCell(
                                                                    _pagedData[
                                                                            i]
                                                                        .accountType!),
                                                                _buildDataCell(
                                                                    _pagedData[
                                                                            i]
                                                                        .chargeType!),
                                                                _buildDataCell(
                                                                    _pagedData[
                                                                            i]
                                                                        .fundType!),
                                                                _buildActionsCell(
                                                                    _pagedData[
                                                                        i]),
                                                              ],
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 25),
                                                  _buildPaginationControls(),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                ),
                              if (isdateformate) _buildDateTimeSettings(),
                              if (isworkorder)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 15),
                                    Row(
                                      children: [
                                        Text(
                                          "Manage Work Order",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 18
                                                : 25,
                                          ),
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Configure Notifications",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 15
                                                : 28,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 0, vertical: 4),
                                          // decoration: BoxDecoration(
                                          //   color: Colors.white,
                                          //   borderRadius:
                                          //       BorderRadius.circular(10),
                                          //   boxShadow: [
                                          //     BoxShadow(
                                          //       color: Colors.grey
                                          //           .withOpacity(0.1),
                                          //       spreadRadius: 1,
                                          //       blurRadius: 5,
                                          //       offset: const Offset(0, 2),
                                          //     ),
                                          //   ],
                                          // ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Create Section
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFF4F8FF),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: blueColor
                                                        .withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Create',
                                                      style: TextStyle(
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Administrator',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  createAdmin,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  createAdmin =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Assignee',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  createAssignee,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  createAssignee =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Tenant',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  createTenant,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  createTenant =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Update Section
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF4F8FF),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: blueColor
                                                        .withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Update',
                                                      style: TextStyle(
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Administrator',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  updateAdmin,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  updateAdmin =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Assignee',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  updateAssignee,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  updateAssignee =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Tenant',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  updateTenant,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  updateTenant =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Complete Section
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFF4F8FF),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: blueColor
                                                        .withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Complete',
                                                      style: TextStyle(
                                                        fontSize: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width <
                                                                500
                                                            ? 15
                                                            : 18,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Administrator',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  completeAdmin,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  completeAdmin =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Assignee',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  completeAssignee,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  completeAssignee =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              'Tenant',
                                                              style: TextStyle(
                                                                fontSize: MediaQuery.of(context)
                                                                            .size
                                                                            .width <
                                                                        500
                                                                    ? 14
                                                                    : 16,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            Checkbox(
                                                              value:
                                                                  completeTenant,
                                                              onChanged:
                                                                  (value) {
                                                                setState(() {
                                                                  completeTenant =
                                                                      value ??
                                                                          false;
                                                                });
                                                              },
                                                              activeColor:
                                                                  blueColor,
                                                              materialTapTargetSize:
                                                                  MaterialTapTargetSize
                                                                      .shrinkWrap,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              height: 50,
                                              width: 100,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: blueColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                ),
                                                onPressed: isSavingNotifications
                                                    ? null
                                                    : () async {
                                                        await saveWorkOrderNotificationSettings();
                                                      },
                                                child: isSavingNotifications
                                                    ? const Center(
                                                        child:
                                                            SpinKitFadingCircle(
                                                          color: Colors.white,
                                                          size: 30.0,
                                                        ),
                                                      )
                                                    : Text(
                                                        'Save',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 16
                                                              : 25,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Category",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 16
                                                : 25,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    // Dynamic categories dropdown for work order
                                    DropdownButtonHideUnderline(
                                      child:
                                          DropdownButton2<allcategories_model>(
                                        isExpanded: true,
                                        hint: Text(_isLoadingCategories
                                            ? 'Loading categories...'
                                            : 'Select Category'),
                                        value: _dropdownCategories.contains(
                                                _selectedDropdownCategory)
                                            ? _selectedDropdownCategory
                                            : null,
                                        items: _dropdownCategories.map((cat) {
                                          return DropdownMenuItem<
                                              allcategories_model>(
                                            value: cat,
                                            child: Text(cat.name ?? ''),
                                          );
                                        }).toList(),
                                        onChanged: _isLoadingCategories
                                            ? null // disables dropdown while loading
                                            : (allcategories_model? newValue) {
                                                setState(() {
                                                  _selectedDropdownCategory =
                                                      newValue;
                                                  _showTextField =
                                                      newValue?.name == 'Other';
                                                });
                                              },
                                        buttonStyleData: ButtonStyleData(
                                          height: 45,
                                          padding: const EdgeInsets.only(
                                              left: 14, right: 14),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            color: Colors.white,
                                          ),
                                          elevation: 2,
                                        ),
                                        iconStyleData: const IconStyleData(
                                          icon: Icon(Icons.arrow_drop_down),
                                          iconSize: 24,
                                          iconEnabledColor: Color(0xFFb0b6c3),
                                          iconDisabledColor: Colors.grey,
                                        ),
                                        dropdownStyleData: DropdownStyleData(
                                          maxHeight: 250,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            color: Colors.white,
                                          ),
                                          scrollbarTheme: ScrollbarThemeData(
                                            radius: const Radius.circular(6),
                                            thickness:
                                                MaterialStateProperty.all(6),
                                            thumbVisibility:
                                                MaterialStateProperty.all(true),
                                          ),
                                        ),
                                        menuItemStyleData:
                                            const MenuItemStyleData(
                                          height: 50,
                                          padding: EdgeInsets.only(
                                              left: 14, right: 14),
                                        ),
                                      ),
                                    ),
                                    if (_showTextField)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            top: 10, bottom: 10),
                                        child: buildTextField('Other Category',
                                            'Enter Other Category', other),
                                      ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      'Vendor *',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 16
                                                : 25,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FormField<String>(
                                          validator: (value) {
                                            if (_selectedvendorsId == null ||
                                                _selectedvendorsId!.isEmpty) {
                                              return 'Please select a vendor';
                                            }
                                            return null;
                                          },
                                          builder:
                                              (FormFieldState<String> state) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                DropdownButtonHideUnderline(
                                                  child:
                                                      DropdownButtonFormField2<
                                                          String>(
                                                    decoration:
                                                        const InputDecoration(
                                                      border: InputBorder.none,
                                                    ),
                                                    isExpanded: true,
                                                    hint: const Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Select here',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              color: Color(
                                                                  0xFFb0b6c3),
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    items: vendors.keys
                                                        .map((vender_id) {
                                                      return DropdownMenuItem<
                                                          String>(
                                                        value: vender_id,
                                                        child: Text(
                                                          vendors[vender_id]!,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      );
                                                    }).toList(),
                                                    value: _selectedvendorsId,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _selectedvendorsId =
                                                            value;
                                                        _selectedVendors =
                                                            vendors[value];
                                                        vendorId =
                                                            value.toString();
                                                        _loadUnits(value!);
                                                        state.didChange(
                                                            value); // Fetch units for the selected vendor
                                                      });
                                                      state.reset();
                                                      // Notify form field of the change
                                                    },
                                                    buttonStyleData:
                                                        ButtonStyleData(
                                                      height: 45,
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 14,
                                                              right: 14),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        color: Colors.white,
                                                      ),
                                                      elevation: 2,
                                                    ),
                                                    iconStyleData:
                                                        const IconStyleData(
                                                      icon: Icon(Icons
                                                          .arrow_drop_down),
                                                      iconSize: 24,
                                                      iconEnabledColor:
                                                          Color(0xFFb0b6c3),
                                                      iconDisabledColor:
                                                          Colors.grey,
                                                    ),
                                                    dropdownStyleData:
                                                        DropdownStyleData(
                                                      maxHeight: 250,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        color: Colors.white,
                                                      ),
                                                      scrollbarTheme:
                                                          ScrollbarThemeData(
                                                        radius: const Radius
                                                            .circular(6),
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
                                                      height: 50,
                                                      padding: EdgeInsets.only(
                                                          left: 14, right: 14),
                                                    ),
                                                    // validator: (value) {
                                                    //   if (value == null || value.isEmpty) {
                                                    //     return 'Please select a vendor';
                                                    //   }
                                                    //   return null;
                                                    // },
                                                  ),
                                                ),
                                                if (state.hasError)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
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
                                      height: 10,
                                    ),
                                    Text(
                                      'Entry Allowed ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 16
                                                : 25,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton2<String>(
                                        isExpanded: true,
                                        hint: const Text('Select'),
                                        value: _selectedEntry,
                                        items: _entry.map((method) {
                                          return DropdownMenuItem<String>(
                                            value: method,
                                            child: Text(method),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedEntry = newValue;
                                            //_selectedPaymentMethod = addRow();
                                            // if(_selectedCategory == 'Other')
                                            // addRow();
                                          });
                                        },
                                        buttonStyleData: ButtonStyleData(
                                          height: 45,
                                          // width: 200,
                                          padding: const EdgeInsets.only(
                                              left: 14, right: 14),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            color: Colors.white,
                                          ),
                                          elevation: 2,
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
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            color: Colors.white,
                                          ),
                                          scrollbarTheme: ScrollbarThemeData(
                                            radius: const Radius.circular(6),
                                            thickness:
                                                MaterialStateProperty.all(6),
                                            thumbVisibility:
                                                MaterialStateProperty.all(true),
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
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      'Assigned To *',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blueColor,
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 16
                                                : 25,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FormField<String>(
                                          validator: (value) {
                                            if (_selectedstaffId == null ||
                                                _selectedstaffId!.isEmpty) {
                                              return 'Please select a staff member';
                                            }
                                            return null;
                                          },
                                          builder:
                                              (FormFieldState<String> state) {
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                DropdownButtonHideUnderline(
                                                  child:
                                                      DropdownButtonFormField2<
                                                          String>(
                                                    decoration:
                                                        const InputDecoration(
                                                      border: InputBorder.none,
                                                    ),
                                                    isExpanded: true,
                                                    hint: const Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            'Select here',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                              color: Color(
                                                                  0xFFb0b6c3),
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    items: staffs.keys
                                                        .map((staffmember_id) {
                                                      return DropdownMenuItem<
                                                          String>(
                                                        value: staffmember_id,
                                                        child: Text(
                                                          staffs[
                                                              staffmember_id]!,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      );
                                                    }).toList(),
                                                    value: _selectedstaffId,
                                                    onChanged: (value) {
                                                      setState(() {
                                                        _selectedstaffId =
                                                            value;
                                                        _selectedStaffs =
                                                            staffs[value];
                                                        StaffId =
                                                            value.toString();
                                                        state.didChange(value);
                                                      });
                                                      state.reset();
                                                      // Notify form field of the change
                                                    },
                                                    buttonStyleData:
                                                        ButtonStyleData(
                                                      height: 45,
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 14,
                                                              right: 14),
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        color: Colors.white,
                                                      ),
                                                      elevation: 2,
                                                    ),
                                                    iconStyleData:
                                                        const IconStyleData(
                                                      icon: Icon(Icons
                                                          .arrow_drop_down),
                                                      iconSize: 24,
                                                      iconEnabledColor:
                                                          Color(0xFFb0b6c3),
                                                      iconDisabledColor:
                                                          Colors.grey,
                                                    ),
                                                    dropdownStyleData:
                                                        DropdownStyleData(
                                                      maxHeight: 250,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        color: Colors.white,
                                                      ),
                                                      scrollbarTheme:
                                                          ScrollbarThemeData(
                                                        radius: const Radius
                                                            .circular(6),
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
                                                      height: 50,
                                                      padding: EdgeInsets.only(
                                                          left: 14, right: 14),
                                                    ),
                                                  ),
                                                ),
                                                if (state.hasError)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
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
                                      height: 30,
                                    ),
                                    // Configure Notifications Section
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          height: 50,
                                          width: 100,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: blueColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                            onPressed: () async {
                                              updateWorkOrderSettings();
                                            },
                                            child: isLoading
                                                ? const Center(
                                                    child: SpinKitFadingCircle(
                                                      color: Colors.white,
                                                      size: 55.0,
                                                    ),
                                                  )
                                                : Text(
                                                    'Save',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 16
                                                              : 25,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              if (ismanagetemplate) const manage_templates(),
                              if (ischargesetting)
                                Column(
                                  children: [
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Manage Charges",
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 18
                                                : 25,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "Configure how charges should be recorded — either as a single bundled charge or as separate individual charges.",
                                            style: TextStyle(
                                              color: greyColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 14
                                                  : 18,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: Row(
                                        children: [
                                          Switch(
                                            value: chargesetting == null
                                                ? true
                                                : chargesetting![
                                                    "unbundle_charges"],
                                            onChanged: (value) {
                                              setState(() {
                                                if (chargesetting != null)
                                                  chargesetting![
                                                          "unbundle_charges"] =
                                                      !chargesetting![
                                                          "unbundle_charges"];
                                                else
                                                  chargesetting = {
                                                    "unbundle_charges": value
                                                  };
                                              });
                                            },
                                            activeColor:
                                                blueColor, // Color when switch is on
                                            inactiveThumbColor: Colors
                                                .grey, // Color when switch is off
                                          ),
                                          const SizedBox(
                                            width: 10,
                                          ),
                                          Text(
                                            'Unbundle Charges',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            SharedPreferences prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            String? token =
                                                prefs.getString('token');
                                            String? id =
                                                prefs.getString('adminId');
                                            bool success =
                                                await AddChargeSettingData(id, {
                                              "admin_id": id,
                                              "unbundle_charges":
                                                  chargesetting![
                                                      "unbundle_charges"]
                                            });
                                            if (success) {
                                              // Refresh the charge settings data
                                              loadChargeSetting();
                                            }
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(5.0),
                                            child: Container(
                                              height: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 35
                                                  : 50,
                                              width: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 100
                                                  : 150,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                color: blueColor,
                                                boxShadow: [
                                                  const BoxShadow(
                                                    color: Colors.grey,
                                                    offset: Offset(
                                                        0.0, 1.0), //(x,y)
                                                    blurRadius: 6.0,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "Save",
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 16
                                                              : 20),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 10,
                                        ),
                                        GestureDetector(
                                          onTap: () async {
                                            setState(() {
                                              chargesetting = null;
                                            });
                                          },
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(5.0),
                                            child: Container(
                                              height: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 35
                                                  : 50,
                                              width: MediaQuery.of(context)
                                                          .size
                                                          .width <
                                                      500
                                                  ? 100
                                                  : 150,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(5.0),
                                                color: Colors.white,
                                                border: Border.all(
                                                    color: blueColor),
                                                boxShadow: [
                                                  const BoxShadow(
                                                    color: Colors.grey,
                                                    offset: Offset(
                                                        0.0, 1.0), //(x,y)
                                                    blurRadius: 6.0,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  "Reset",
                                                  style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 16
                                                              : 20),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              if (iscategories)
                                Column(
                                  children: [
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          "Manage Categories",
                                          style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 18
                                                : 25,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            height: 48,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  color: Colors.grey.shade400),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            alignment: Alignment.centerLeft,
                                            child: TextField(
                                              controller: categories,
                                              decoration: const InputDecoration
                                                  .collapsed(
                                                hintText: 'Enter category name',
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (_editingCategoryId == null) {
                                              addCategory();
                                            } else {
                                              updateCategory();
                                            }
                                          },
                                          child: Container(
                                            height: 43,
                                            width: 150,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFF1A2F5B), // Dark blue like the image
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _editingCategoryId == null
                                                  ? 'Add Category'
                                                  : 'Update',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (_editingCategoryId != null) ...[
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _editingCategoryId = null;
                                                categories.clear();
                                              });
                                            },
                                            child: Container(
                                              height: 43,
                                              width: 110,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(
                                                    color: blueColor),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    // Category Table
                                    FutureBuilder<List<categories_model>>(
                                      future: futureCategories,
                                      builder: (context, snapshot) {
                                        if (snapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                              child: SpinKitFadingCircle(
                                            color: Colors.black,
                                            size: 40.0,
                                          ));
                                        } else if (snapshot.hasError) {
                                          return Center(
                                              child: Text(
                                                  'Error: \\${friendlyErrorMessage(snapshot.error)}'));
                                        } else if (!snapshot.hasData ||
                                            snapshot.data!.isEmpty) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Header
                                              Container(
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey.shade400,
                                                    width: 1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  color:
                                                      const Color(0xFFF4F8FF),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 8),
                                                child: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Category Name',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 1.1,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Action',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 1.1,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 30),
                                              Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/no_data.jpg",
                                                      height: 120,
                                                      width: 120,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      "No Data Available",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                            ],
                                          );
                                        } else {
                                          final categoriesList = snapshot.data!;
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Header
                                              Container(
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey.shade400,
                                                    width: 1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  color:
                                                      const Color(0xFFF4F8FF),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                        horizontal: 8),
                                                child: const Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        'Category Name',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 1.1,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Action',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 1.1,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              // Rows
                                              ...categoriesList
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                int idx = entry.key;
                                                var cat = entry.value;
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                      bottom: 8),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: Colors
                                                            .grey.shade400,
                                                        width: 1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                    color: idx % 2 == 0
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFFF4F8FF),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 16,
                                                                  horizontal:
                                                                      12),
                                                          child: Text(
                                                            cat.name ?? '',
                                                            style: const TextStyle(
                                                                fontSize: 16,
                                                                color: Colors
                                                                    .black87),
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            categories.text =
                                                                cat.name ?? '';
                                                            _editingCategoryId =
                                                                cat.categoryId;
                                                          });
                                                        },
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .green.shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          child: const Row(
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
                                                      const SizedBox(width: 10),
                                                      GestureDetector(
                                                        onTap: () {
                                                          _showDeleteCategoryAlert(
                                                              context,
                                                              cat.categoryId ??
                                                                  '');
                                                        },
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .red.shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                          ),
                                                          child: const Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .center,
                                                            children: [
                                                              FaIcon(
                                                                FontAwesomeIcons
                                                                    .trashCan,
                                                                size: 15,
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              if (isvendor)
                                _isStaff
                                    ? StaffVendor.Vendor_table(isEmbedded: true)
                                    : Vendor_table(isEmbedded: true),
                              if (ispropertyowner)
                                _isStaff
                                    ? StaffRentalOwner.Rentalowner_table(
                                        isEmbedded: true)
                                    : Rentalowner_table(isEmbedded: true),
                              if (ispropertytype)
                                _isStaff
                                    ? StaffPropertyType.PropertyTable(
                                        isEmbedded: true)
                                    : PropertyTable(isEmbedded: true),
                              if (istwilio)
                                Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Twilio Configuration',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 15),
                                    Row(children: [
                                      Text(
                                        'SMS Notifications',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Enable SMS Notifications',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Switch(
                                          value: twilioSmsEnabled,
                                          onChanged: (value) {
                                            setState(() {
                                              twilioSmsEnabled = value;
                                            });
                                          },
                                          activeColor: blueColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Text(
                                        'Twilio Account SID',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 5),
                                    CustomTextField(
                                      controller: twilioAccountSid,
                                      hintText: 'Enter Twilio Account SID',
                                      keyboardType: TextInputType.text,
                                      readOnnly: !twilioSmsEnabled,
                                      error_mess: twilioAccountSidError,
                                    ),
                                    if (twilioAccountSidError != null)
                                      Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4, left: 5),
                                            child: Text(
                                              twilioAccountSidError!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Text(
                                        'Twilio Auth Token',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 5),
                                    CustomTextField(
                                      controller: twilioAuthToken,
                                      hintText: 'Enter Twilio Auth Token',
                                      keyboardType: TextInputType.text,
                                      obscureText: true,
                                      readOnnly: !twilioSmsEnabled,
                                      error_mess: twilioAuthTokenError,
                                    ),
                                    if (twilioAuthTokenError != null)
                                      Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4, left: 5),
                                            child: Text(
                                              twilioAuthTokenError!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Text(
                                        'Twilio Phone Number',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 5),
                                    CustomTextField(
                                      controller: twilioPhoneNumber,
                                      hintText: 'Enter Twilio Phone Number',
                                      keyboardType: TextInputType.text,
                                      readOnnly: !twilioSmsEnabled,
                                      error_mess: twilioPhoneNumberError,
                                    ),
                                    if (twilioPhoneNumberError != null)
                                      Row(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                top: 4, left: 5),
                                            child: Text(
                                              twilioPhoneNumberError!,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    const SizedBox(height: 20),
                                    Row(children: [
                                      GestureDetector(
                                        onTap: saveTwilioSettings,
                                        child: Container(
                                          height: 45,
                                          width: 150,
                                          decoration: BoxDecoration(
                                            color: blueColor,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Center(
                                            child: Text(
                                              'Save Settings',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ])))
            : NoInternetView(onRetry: retryNow),
      ),
    );
  }

  String fixDateFormat(String customdate) {
    return customdate.replaceAllMapped(
      RegExp(r'[DY]'),
      (match) {
        if (match.group(0) == 'D') {
          return 'd';
        } else if (match.group(0) == 'Y') {
          return 'y';
        }
        return match
            .group(0)!; // Return the character unchanged if it doesn't match
      },
    );
  }

  Widget _buildMailServiceSection() {
    final bool isSmall = MediaQuery.of(context).size.width < 500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        // ===== Card 1: Mail Service =====
        _buildSettingsCard(
          icon: Icons.mail_outline,
          title: "MAIL SERVICE",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Reply-To Address",
                style: TextStyle(
                  fontSize: isSmall ? 15 : 20,
                  color: blueColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildMailTextField(
                controller: replyToEmail,
                hint: "Enter email",
              ),
              const SizedBox(height: 8),
              Text(
                "Tenant replies to automated emails will go to this address.",
                style: TextStyle(
                  fontSize: isSmall ? 12 : 15,
                  color: const Color(0xFF8A95A8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // ===== Card 2: Rent Due Reminder =====
        _buildSettingsCard(
          icon: Icons.notifications_none,
          title: "RENT DUE REMINDER",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRentDueReminderSwitch(),
              Text(
                "You can set a duration for send reminder email before rent due date to tenant",
                style: TextStyle(
                  fontSize: isSmall ? 12 : 15,
                  color: const Color(0xFF8A95A8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (rentDueReminderEmail) ...[
                const SizedBox(height: 14),
                Text(
                  "Duration (days before rent due)",
                  style: TextStyle(
                    fontSize: isSmall ? 15 : 20,
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMailTextField(
                  controller: durationmail,
                  hint: "1",
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        // ===== Buttons: Reset + Save Changes =====
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    replyToEmail.text = _originalReplyToEmail;
                    durationmail.text = _originalDurationMail;
                    rentDueReminderEmail = _originalRentDueReminderEmail;
                  });
                },
                child: Container(
                  height: isSmall ? 44 : 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: blueColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      "Reset",
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 16 : 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  if (mailupdate)
                    await updateMail();
                  else
                    await Addmail();
                },
                child: Container(
                  height: isSmall ? 44 : 52,
                  decoration: BoxDecoration(
                    color: blueColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, 1.0),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Save Changes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmall ? 16 : 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9DEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFEAEFF6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: blueColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildMailTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: grey),
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: const Color.fromRGBO(21, 43, 81, 1),
        onChanged: (value) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: MediaQuery.of(context).size.width * .037,
            color: const Color(0xFF8A95A8),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(13),
        ),
      ),
    );
  }

  Widget _buildRentDueReminderSwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Switch(
            value: rentDueReminderEmail,
            onChanged: (value) {
              setState(() {
                rentDueReminderEmail = value;
              });
            },
            activeColor: blueColor, // Color when switch is on
            inactiveThumbColor: Colors.grey, // Color when switch is off
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            'Rent Due Reminder Email',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: blueColor,
            ),
          ),
        ],
      ),
    );
  }

  final List<String> accountitems = [
    'Liability Account',
    'Recurring Charge',
    'One Time Charge',
  ];
  final List<String> accounttypeitems = [
    'Income',
    'Non Operating Income',
    'Liability Account',
  ];
  final List<String> fundtypeitems = [
    'Reserve',
    'Operating',
  ];

  String? _selectedAccount;
  String? _selectedAccounttype;
  String? _selectedFundtype;
  bool isError = false;

  final TextEditingController accountname = TextEditingController();
  final TextEditingController note = TextEditingController();

  // Add this function to handle category addition
  Future<void> addCategory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String categoryName = categories.text.trim();
    String? token = prefs.getString('token');

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category name')),
      );
      return;
    }
    if (adminId == null || adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin ID is missing')),
      );
      return;
    }

    final url = Uri.parse('${Api_url}/api/settings/categories');
    final response = await apiPost(
      url,
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? adminId}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "admin_id": adminId,
        "name": categoryName,
      }),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData["statusCode"] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category added successfully')),
      );
      categories.clear();
      setState(() {
        futureCategories = accountRepository().fetchCategories();
      }); // Refresh UI and reload categories
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(responseData["message"] ?? 'Failed to add category')),
      );
    }
  }

  // Update an existing category (PUT /api/settings/categories/{admin_id}/{category_id})
  Future<void> updateCategory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');
    String categoryName = categories.text.trim();
    String? categoryId = _editingCategoryId;

    if (categoryName.isEmpty) {
      Fluttertoast.showToast(msg: 'Please enter a category name');
      return;
    }
    if (adminId == null || adminId.isEmpty) {
      Fluttertoast.showToast(msg: 'Admin ID is missing');
      return;
    }
    if (categoryId == null || categoryId.isEmpty) {
      Fluttertoast.showToast(msg: 'No category selected to update');
      return;
    }

    final url =
        Uri.parse('${Api_url}/api/settings/categories/$adminId/$categoryId');
    final response = await apiPut(
      url,
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? adminId}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "admin_id": adminId,
        "name": categoryName,
        "user_active_recently": true,
        "is_web": true,
      }),
    );

    final responseData = jsonDecode(response.body);
    if (response.statusCode == 200 && responseData["statusCode"] == 200) {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? 'Category updated successfully');
      categories.clear();
      setState(() {
        _editingCategoryId = null;
        futureCategories = accountRepository().fetchCategories();
      });
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? 'Failed to update category');
    }
  }

  //popup
  void _showAccountType(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Account Type',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            actions: <Widget>[
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: blueColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Center(
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
            content: SingleChildScrollView(
              child: Container(
                height: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      "Select Account Type",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomDropdown(
                      validator: (value) {
                        if (_selectedAccount == null) {
                          return 'Please select an account';
                        }
                        return null;
                      },
                      labelText: 'Select',
                      items: accountitems,
                      selectedValue: _selectedAccount,
                      onChanged: (String? value) {
                        setState(() {
                          _selectedAccount = value;
                          Navigator.pop(context);
                          _showAccount(context);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Add Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const SizedBox(height: 20),
                  Text(
                    "Account Name",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter account name';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    hintText: 'Enter account name',
                    controller: accountname,
                    showElevation: false,
                    borderColor: const Color(0xFFCED4DA),
                    borderWidth: 1.0,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Account Type",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomDropdown(
                    validator: (value) {
                      if (_selectedAccounttype == null) {
                        return 'Please select an account type';
                      }
                      return null;
                    },
                    labelText: 'Select',
                    items: accounttypeitems,
                    selectedValue: _selectedAccounttype,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedAccounttype = value;
                      });
                    },
                    useBorderStyle: true,
                    dropdownHeight: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Fund Type",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomDropdown(
                    validator: (value) {
                      if (_selectedFundtype == null) {
                        return 'Please select a fund type';
                      }
                      return null;
                    },
                    labelText: 'Select',
                    items: fundtypeitems,
                    selectedValue: _selectedFundtype,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedFundtype = value;
                      });
                    },
                    useBorderStyle: true,
                    dropdownHeight: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Note",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter notes';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    hintText: 'Enter notes',
                    controller: note,
                    showElevation: false,
                    borderColor: const Color(0xFFCED4DA),
                    borderWidth: 1.0,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (_selectedAccounttype == null ||
                                accountname.text.trim().isEmpty ||
                                _selectedFundtype == null) {
                              setState(() {
                                isError = true;
                              });
                            } else {
                              setState(() {
                                isLoading = true;
                                isError = false;
                              });

                              SharedPreferences prefs =
                                  await SharedPreferences.getInstance();
                              String? id = prefs.getString("adminId");

                              try {
                                await accountRepository().addAccount(
                                  adminId: id!,
                                  account: accountname.text.trim(),
                                  accounttype: _selectedAccounttype,
                                  fundtype: _selectedFundtype,
                                  chargetype: "",
                                  notes: note.text.trim(),
                                );
                                Navigator.pop(context);
                                _refreshAccounts();
                              } catch (e) {
                                setState(() {
                                  isError = true;
                                });
                              } finally {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            }
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: blueColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Center(
                              child: isLoading
                                  ? const SpinKitFadingCircle(
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : const Text(
                                      'Add',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: blueColor),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please fill all fields',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showEditAccount(BuildContext context, Setting4 account) {
    // Store original values for comparison
    final String originalAccountName = account.account ?? '';
    final String originalNote = account.notes ?? '';
    final String? originalAccountType = account.accountType;
    final String? originalFundType = account.fundType;

    // Create controllers for edit dialog
    TextEditingController editAccountName =
        TextEditingController(text: account.account ?? '');
    TextEditingController editNote =
        TextEditingController(text: account.notes ?? '');
    String? editSelectedAccounttype = account.accountType;
    String? editSelectedFundtype = account.fundType;
    bool editIsLoading = false;
    bool editIsError = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Edit Account',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // const SizedBox(height: 20),
                  Text(
                    "Account Name",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter account name';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    hintText: 'Enter account name',
                    controller: editAccountName,
                    showElevation: false,
                    borderColor: const Color(0xFFCED4DA),
                    borderWidth: 1.0,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Account Type",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomDropdown(
                    validator: (value) {
                      if (editSelectedAccounttype == null) {
                        return 'Please select an account type';
                      }
                      return null;
                    },
                    labelText: 'Select',
                    items: accounttypeitems,
                    selectedValue: editSelectedAccounttype,
                    onChanged: (String? value) {
                      setState(() {
                        editSelectedAccounttype = value;
                      });
                    },
                    useBorderStyle: true,
                    dropdownHeight: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Fund Type",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomDropdown(
                    validator: (value) {
                      if (editSelectedFundtype == null) {
                        return 'Please select a fund type';
                      }
                      return null;
                    },
                    labelText: 'Select',
                    items: fundtypeitems,
                    selectedValue: editSelectedFundtype,
                    onChanged: (String? value) {
                      setState(() {
                        editSelectedFundtype = value;
                      });
                    },
                    useBorderStyle: true,
                    dropdownHeight: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Note",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter notes';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.text,
                    hintText: 'Enter notes',
                    controller: editNote,
                    showElevation: false,
                    borderColor: const Color(0xFFCED4DA),
                    borderWidth: 1.0,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            if (editSelectedAccounttype == null ||
                                editAccountName.text.trim().isEmpty ||
                                editSelectedFundtype == null) {
                              setState(() {
                                editIsError = true;
                              });
                            } else {
                              // Check if any changes were made
                              final String currentAccountName =
                                  editAccountName.text.trim();
                              final String currentNote = editNote.text.trim();

                              bool hasChanges =
                                  currentAccountName != originalAccountName ||
                                      currentNote != originalNote ||
                                      editSelectedAccounttype !=
                                          originalAccountType ||
                                      editSelectedFundtype != originalFundType;

                              if (!hasChanges) {
                                // No changes made, just close dialog and show message
                                Navigator.pop(context);
                                Fluttertoast.showToast(msg: "No changes made");
                                return;
                              }

                              setState(() {
                                editIsLoading = true;
                                editIsError = false;
                              });

                              try {
                                await accountRepository().updateAccount(
                                  accountId: account.accountId!,
                                  account: currentAccountName,
                                  accounttype: editSelectedAccounttype,
                                  fundtype: editSelectedFundtype,
                                  chargetype: account.chargeType ?? "",
                                  notes: currentNote,
                                );
                                Navigator.pop(context);
                                _refreshAccounts();
                              } catch (e) {
                                setState(() {
                                  editIsError = true;
                                });
                              } finally {
                                setState(() {
                                  editIsLoading = false;
                                });
                              }
                            }
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: blueColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Center(
                              child: editIsLoading
                                  ? const SpinKitFadingCircle(
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : const Text(
                                      'Update',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: blueColor),
                            ),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (editIsError)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please fill all fields',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget buildTextField(
      String label, String hintText, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8.0),
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextFormField(
              controller: controller,
              focusNode: FocusNode(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Add this function to show a delete confirmation dialog with reason for categories
  void _showDeleteCategoryAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same category.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this category!",
      content: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reason for deletion',
                contentPadding: EdgeInsets.only(top: 8, left: 15),
              ),
            ),
          ),
        ],
      ),
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            if (reason.text.isEmpty) {
              Fluttertoast.showToast(msg: "Please enter a reason for deletion");
              return;
            }
            if (deleting) return;
            deleting = true;
            // The repository toasts the server's own reason and then throws
            // when the delete is rejected. Nothing caught it, so
            // Navigator.pop was never reached — the dialog stayed open with no
            // explanation and the exception escaped into the framework. Close
            // the dialog either way; the message has already been shown.
            try {
              await accountRepository()
                  .DeleteCategories(categories_id: id, reason: reason.text);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              setState(() {
                futureCategories = accountRepository().fetchCategories();
              });
              Navigator.pop(context);
            } catch (_) {
              deleting = false;
              if (!mounted) return;
              Navigator.pop(context);
            }
          },
          color: blueColor,
        ),
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8), // Rounded corners
          border: Border.all(
            color: blueColor, // Blue border
            width: 1.5,
          ),
        ),
      ],
    ).show();
  }

  // Vendor table helper functions
  void vendorSortData(List<Vendor> data) {
    if (vendorSorting1) {
      data.sort((a, b) => vendorAscending1
          ? (a.vendorName ?? '')
              .toLowerCase()
              .compareTo((b.vendorName ?? '').toLowerCase())
          : (b.vendorName ?? '')
              .toLowerCase()
              .compareTo((a.vendorName ?? '').toLowerCase()));
    } else if (vendorSorting2) {
      // Was previously safe only because vendorPhoneNumber could never be
      // null (a missing phone came through as the literal string "null").
      // Now that the model yields a real null for a missing phone, sorting
      // a list with any such vendor by phone would throw on the `!`.
      data.sort((a, b) => vendorAscending2
          ? (a.vendorPhoneNumber ?? '').compareTo(b.vendorPhoneNumber ?? '')
          : (b.vendorPhoneNumber ?? '').compareTo(a.vendorPhoneNumber ?? ''));
    }
  }

  Widget _buildVendorHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (vendorSorting1 == true) {
                      vendorSorting2 = false;
                      vendorAscending1 =
                          vendorSorting1 ? !vendorAscending1 : true;
                      vendorAscending2 = false;
                    } else {
                      vendorSorting1 = !vendorSorting1;
                      vendorSorting2 = false;
                      vendorAscending1 =
                          vendorSorting1 ? !vendorAscending1 : true;
                      vendorAscending2 = false;
                    }
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? Text("Name ",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Name",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 3),
                    vendorSorting1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(FontAwesomeIcons.sortDown,
                                size: 20, color: blueColor),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (vendorSorting2) {
                      vendorSorting1 = false;
                      vendorAscending2 =
                          vendorSorting2 ? !vendorAscending2 : true;
                      vendorAscending1 = false;
                    } else {
                      vendorSorting1 = false;
                      vendorSorting2 = !vendorSorting2;
                      vendorAscending2 =
                          vendorSorting2 ? !vendorAscending2 : true;
                      vendorAscending1 = false;
                    }
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? Text("Phone Number ",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Phone Number",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 3),
                    vendorSorting2
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(FontAwesomeIcons.sortDown,
                                size: 20, color: blueColor),
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this function to show a delete confirmation dialog for vendors
  void _showDeleteVendorAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same vendor.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this vendor!",
      content: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reason for deletion',
                contentPadding: EdgeInsets.only(top: 8, left: 15),
              ),
            ),
          ),
        ],
      ),
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            if (reason.text.isEmpty) {
              Fluttertoast.showToast(msg: "Please enter a reason for deletion");
              return;
            }
            if (deleting) return;
            deleting = true;
            // The repository toasts the server's own reason and then throws
            // when the delete is rejected. Nothing caught it, so
            // Navigator.pop was never reached — the dialog stayed open with no
            // explanation and the exception escaped into the framework. Close
            // the dialog either way; the message has already been shown.
            try {
              await VendorRepository(baseUrl: '')
                  .DeleteVender(vender_id: id, reason: reason.text);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              setState(() {
                futureVendors = VendorRepository(baseUrl: '').getVendors();
              });
              Navigator.pop(context);
            } catch (_) {
              deleting = false;
              if (!mounted) return;
              Navigator.pop(context);
            }
          },
          color: blueColor,
        ),
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8), // Rounded corners
          border: Border.all(
            color: blueColor, // Blue border
            width: 1.5,
          ),
        ),
      ],
    ).show();
  }
}
