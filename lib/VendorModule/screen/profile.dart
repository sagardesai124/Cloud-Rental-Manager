import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../constant/constant.dart';
import '../widgets/drawer_tiles.dart';
import '../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';
import 'package:three_zero_two_property/services/zip_code.dart';

class Profile_screen extends StatefulWidget {
  const Profile_screen({Key? key}) : super(key: key);

  @override
  State<Profile_screen> createState() => _Profile_screenState();
}

class _ContactEntry {
  TextEditingController name = TextEditingController();
  TextEditingController number = TextEditingController();
  TextEditingController email = TextEditingController();
}

class _ZipDistanceEntry {
  TextEditingController zipCode = TextEditingController();
  TextEditingController distanceMiles = TextEditingController();
}

class _Profile_screenState extends State<Profile_screen>
    with NetworkRetryState {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> profiledata = {};

  // Vendor Information
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyEmailController = TextEditingController();
  final TextEditingController _cellPhoneController = TextEditingController();
  final TextEditingController _contactCellController = TextEditingController();

  // Address Details
  final TextEditingController _streetAddressController =
      TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  // Contact Information (dynamic list)
  List<_ContactEntry> _contacts = [];

  // Trade & Service Area: one common trade type, multiple zip+distance pairs
  String? _selectedTradeType;
  List<_ZipDistanceEntry> _zipDistancePairs = [];
  // Web's canonical trade list (AddVendor.jsx TRADE_OPTIONS), which is also
  // what the Admin and Staff vendor screens use. This list previously differed
  // on both sides: it labelled the stored value 'general' as "General
  // Contractor" (web and Admin both show "General", so the same vendor read
  // differently depending on who looked at it), it omitted Drywall, Painting
  // and Roofing entirely, and it offered an "Other" option that stored
  // 'other' — a value neither web nor the Admin list can label, so it
  // displayed as raw lowercase text.
  static const Map<String, String> _tradeToApiValue = {
    'General': 'general',
    'Drywall': 'drywall',
    'Electrical': 'electrical',
    'HVAC': 'hvac',
    'Landscaping': 'landscaping',
    'Painting': 'painting',
    'Plumbing': 'plumbing',
    'Roofing': 'roofing',
  };
  static const Map<String, String> _apiValueToTrade = {
    'general': 'General',
    'drywall': 'Drywall',
    'electrical': 'Electrical',
    'hvac': 'HVAC',
    'landscaping': 'Landscaping',
    'painting': 'Painting',
    'plumbing': 'Plumbing',
    'roofing': 'Roofing',
  };
  final List<String> _tradeTypeOptions = [
    'General',
    'Drywall',
    'Electrical',
    'HVAC',
    'Landscaping',
    'Painting',
    'Plumbing',
    'Roofing',
  ];

  // Compliance & Legal
  final TextEditingController _licensesPermitsController =
      TextEditingController();

  bool _showValidationError = false;

  /// Snapshot of profile data after load; used to skip API when nothing changed.
  Map<String, dynamic>? _initialProfileBody;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The profile fetch only; the contact and zip-distance rows initState seeds
  /// are not re-added, or a reload would duplicate them.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    await _fetchProfile();
  }

  @override
  void initState() {
    super.initState();
    _contacts.add(_ContactEntry());
    _zipDistancePairs.add(_ZipDistanceEntry());
    _fetchProfile();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _cellPhoneController.dispose();
    _contactCellController.dispose();
    _streetAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _licensesPermitsController.dispose();
    for (var c in _contacts) {
      c.name.dispose();
      c.number.dispose();
      c.email.dispose();
    }
    for (var z in _zipDistancePairs) {
      z.zipCode.dispose();
      z.distanceMiles.dispose();
    }
    super.dispose();
  }

  void _populateFromProfile() {
    // Vendor Information
    _companyNameController.text = profiledata['vendor_name']?.toString() ?? '';
    _companyEmailController.text =
        profiledata['vendor_email']?.toString() ?? '';
    _cellPhoneController.text =
        profiledata['vendor_phoneNumber']?.toString() ?? '';
    // Contact Cell in Vendor Info: backend contact_cell_number, or first contact's number from contact_info
    final contactCellFromApi = profiledata['contact_cell_number']?.toString().trim();
    if (contactCellFromApi != null && contactCellFromApi.isNotEmpty) {
      _contactCellController.text = contactCellFromApi;
    } else {
      final contactsList =
          (profiledata['contact_info'] ?? profiledata['contacts']) as List?;
      if (contactsList != null && contactsList.isNotEmpty) {
        final first = contactsList[0] is Map ? contactsList[0] as Map : null;
        _contactCellController.text =
            first?['contact_number']?.toString().trim() ?? '';
      } else {
        _contactCellController.text = '';
      }
    }

    // Address Details
    _streetAddressController.text =
        (profiledata['vendor_address'] ?? profiledata['street_address'])
                ?.toString() ??
            '';
    _cityController.text =
        (profiledata['vendor_city'] ?? profiledata['city'])?.toString() ?? '';
    _stateController.text =
        (profiledata['vendor_state'] ?? profiledata['state'])?.toString() ?? '';
    _zipCodeController.text =
        (profiledata['vendor_zip'] ?? profiledata['zip_code'])?.toString() ??
            '';
    _countryController.text =
        (profiledata['vendor_country'] ?? profiledata['country'])?.toString() ??
            '';

    // Compliance & Legal
    _licensesPermitsController.text =
        profiledata['licenses_permits']?.toString() ?? '';

    // Contact Information – support both contact_info and contacts from API
    final contactsList =
        (profiledata['contact_info'] ?? profiledata['contacts']) as List?;
    if (contactsList != null && contactsList.isNotEmpty) {
      while (_contacts.length > contactsList.length) {
        final last = _contacts.removeLast();
        last.name.dispose();
        last.number.dispose();
        last.email.dispose();
      }
      for (var i = 0; i < contactsList.length; i++) {
        final m = contactsList[i] is Map ? contactsList[i] as Map : null;
        if (i < _contacts.length) {
          _contacts[i].name.text = m?['contact_name']?.toString() ?? '';
          _contacts[i].number.text = m?['contact_number']?.toString() ?? '';
          _contacts[i].email.text = m?['contact_email']?.toString() ?? '';
        } else {
          final e = _ContactEntry();
          e.name.text = m?['contact_name']?.toString() ?? '';
          e.number.text = m?['contact_number']?.toString() ?? '';
          e.email.text = m?['contact_email']?.toString() ?? '';
          _contacts.add(e);
        }
      }
    } else {
      // No contacts from API: keep one empty contact row
      while (_contacts.length > 1) {
        final last = _contacts.removeLast();
        last.name.dispose();
        last.number.dispose();
        last.email.dispose();
      }
      _contacts[0].name.text = '';
      _contacts[0].number.text = '';
      _contacts[0].email.text = '';
    }

    // Trade & Service Area
    final tradeFromApi =
        (profiledata['trade'] ?? profiledata['trade_type'])?.toString();
    _selectedTradeType = tradeFromApi != null
        ? (_apiValueToTrade[tradeFromApi.toString().toLowerCase()] ??
            (_tradeTypeOptions.contains(tradeFromApi) ? tradeFromApi : null))
        : null;

    final tradeList = (profiledata['region_covered'] ??
        profiledata['trade_service_areas']) as List?;
    if (tradeList != null && tradeList.isNotEmpty) {
      if (_selectedTradeType != null &&
          !_tradeTypeOptions.contains(_selectedTradeType)) {
        _selectedTradeType = null;
      }
      while (_zipDistancePairs.length > tradeList.length) {
        final last = _zipDistancePairs.removeLast();
        last.zipCode.dispose();
        last.distanceMiles.dispose();
      }
      for (var i = 0; i < tradeList.length; i++) {
        final m = tradeList[i] is Map ? tradeList[i] as Map : null;
        final zipVal = m?['zip_code']?.toString() ?? '';
        final distVal = m?['distance_miles']?.toString() ??
            ''; // handles number (e.g. 98) from API
        if (i < _zipDistancePairs.length) {
          _zipDistancePairs[i].zipCode.text = zipVal;
          _zipDistancePairs[i].distanceMiles.text = distVal;
        } else {
          final e = _ZipDistanceEntry();
          e.zipCode.text = zipVal;
          e.distanceMiles.text = distVal;
          _zipDistancePairs.add(e);
        }
      }
    } else {
      while (_zipDistancePairs.length > 1) {
        final last = _zipDistancePairs.removeLast();
        last.zipCode.dispose();
        last.distanceMiles.dispose();
      }
      if (_zipDistancePairs.isNotEmpty) {
        _zipDistancePairs[0].zipCode.text = '';
        _zipDistancePairs[0].distanceMiles.text = '';
      }
      if (_selectedTradeType != null &&
          !_tradeTypeOptions.contains(_selectedTradeType)) {
        _selectedTradeType = null;
      }
    }
  }

  Future<void> fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    //  String? token = prefs.getString('token');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    final String apiUrl = "${Api_url}/api/vendor/get_vendor/$id";
    final response = await apiGet(
      Uri.parse('$apiUrl'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final response_Data = jsonDecode(response.body);
    if (response_Data["statusCode"] == 200) {
      setState(() {
        profiledata = response_Data["data"] ?? {};
        _isLoading = false;
        _populateFromProfile();
        _saveInitialProfileBody();
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to load profile');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      await fetchProfile();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getCurrentProfileBody() {
    return {
      'vendor_name': _companyNameController.text.trim(),
      'vendor_email': _companyEmailController.text.trim(),
      'vendor_phoneNumber': _cellPhoneController.text.trim(),
      'vendor_address': _streetAddressController.text.trim(),
      'vendor_city': _cityController.text.trim(),
      'vendor_state': _stateController.text.trim(),
      'vendor_zip': _zipCodeController.text.trim(),
      'vendor_country': _countryController.text.trim(),
      'contact_cell_number': _contactCellController.text.trim(),
      'contact_info': _contacts
          .map((c) => {
                'contact_name': c.name.text.trim(),
                'contact_number': c.number.text.trim(),
                'contact_email': c.email.text.trim(),
              })
          .toList(),
      'trade': _selectedTradeType != null
          ? (_tradeToApiValue[_selectedTradeType!] ??
              (_selectedTradeType ?? '').toLowerCase().replaceAll(' ', '_'))
          : null,
      'region_covered': _zipDistancePairs
          .map((z) => {
                'zip_code': z.zipCode.text.trim(),
                'distance_miles': z.distanceMiles.text.trim(),
              })
          .toList(),
      'licenses_permits': _licensesPermitsController.text.trim(),
    };
  }

  void _saveInitialProfileBody() {
    _initialProfileBody = _getCurrentProfileBody();
  }

  Future<void> _updateProfile() async {
    setState(() => _showValidationError = false);
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _showValidationError = true);
      return;
    }
    if (_initialProfileBody != null &&
        jsonEncode(_getCurrentProfileBody()) == jsonEncode(_initialProfileBody)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No changes to update')),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("vendor_id");
      String? token = prefs.getString('token');
      final body = {
        'vendor_name': _companyNameController.text.trim(),
        'vendor_email': _companyEmailController.text.trim(),
        'vendor_phoneNumber': _cellPhoneController.text.trim(),
        'contact_cell_number': _contactCellController.text.trim(),
        'vendor_address': _streetAddressController.text.trim(),
        'vendor_city': _cityController.text.trim(),
        'vendor_state': _stateController.text.trim(),
        'vendor_zip': _zipCodeController.text.trim(),
        'vendor_country': _countryController.text.trim(),
        'contact_info': _contacts
            .map((c) => {
                  'contact_name': c.name.text.trim(),
                  'contact_number': c.number.text.trim(),
                  'contact_email': c.email.text.trim(),
                })
            .toList(),
        'trade': _selectedTradeType != null
            ? (_tradeToApiValue[_selectedTradeType!] ??
                (_selectedTradeType ?? '').toLowerCase().replaceAll(' ', '_'))
            : null,
        'region_covered': _zipDistancePairs
            .map((z) => {
                  'zip_code': z.zipCode.text.trim(),
                  'distance_miles': z.distanceMiles.text.trim(),
                })
            .toList(),
        'licenses_permits': _licensesPermitsController.text.trim(),
        'user_active_recently': true,
        'is_web': true,
      };
      final response = await apiPut(
        Uri.parse('${Api_url}/api/vendor/update_vendor/$id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );
      final result = jsonDecode(response.body);
      setState(() => _isLoading = false);
      if (response.statusCode == 200 && result["statusCode"] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result["message"]?.toString() ?? 'Profile updated')),
        );
        await fetchProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result["message"]?.toString() ?? 'Update failed')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Widget _sectionTitle(String title) {
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

  static String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Phone number must be 10 digits';
    return null;
  }

  static String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (!EmailValidator.validate(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? _validateDistance(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (RegExp(r'[a-zA-Z]').hasMatch(v)) return 'Numbers only';
    return null;
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label' : label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint ?? 'Enter $label',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade400),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: blueColor, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: validator ??
                (required
                    ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                    : null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {
          key.currentState!.openDrawer();
        },
      ),
      backgroundColor: Colors.white,
      drawer: Drawer(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Image.asset("assets/images/logo.png"),
              ),
              const SizedBox(height: 40),
              buildListTile(
                  context,
                  SvgPicture.asset(
                    "assets/images/tenants/dashboard.svg",
                    fit: BoxFit.cover,
                    height: 20,
                    width: 20,
                  ),
                  "Dashboard",
                  false),
              buildListTile(
                  context,
                  SvgPicture.asset(
                    "assets/images/tenants/admin2.svg",
                    fit: BoxFit.cover,
                    height: 20,
                    width: 20,
                  ),
                  "Profile",
                  true),
              /* buildListTile(
                  context,
                  SvgPicture.asset(
                    "assets/images/tenants/Property.svg",
                    fit: BoxFit.cover,
                    height: 20,
                    width: 20,
                  ),
                  "Properties",
                  false),
              buildListTile(
                  context,
                  SvgPicture.asset(
                    "assets/images/tenants/Financial.svg",
                    fit: BoxFit.cover,
                    height: 20,
                    width: 20,
                  ),
                  "Financial",
                  false),*/
              buildListTile(
                  context,
                  SvgPicture.asset(
                    "assets/images/tenants/Work.svg",
                    fit: BoxFit.cover,
                    height: 20,
                    width: 20,
                  ),
                  "Work Order",
                  false),
              /* buildDropdownListTile(
                  context,
                  const FaIcon(
                    FontAwesomeIcons.key,
                    size: 20,
                    color: Colors.black,
                  ),
                  "Rental",
                  ["Properties", "RentalOwner", "Tenants"]),
              buildDropdownListTile(
                  context,
                  const FaIcon(
                    FontAwesomeIcons.thumbsUp,
                    size: 20,
                    color: Colors.black,
                  ),
                  "Leasing",
                  ["Rent Roll", "Applicants"]),
              buildDropdownListTile(
                  context,
                  Image.asset("assets/icons/maintence.png",
                      height: 20, width: 20),
                  "Maintenance",
                  ["Vendor", "Work Order"]),*/
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: SpinKitFadingCircle(
                color: Colors.black,
                size: 50.0,
              ),
            )
          : _hasError
              ? (isNetworkError(_errorMessage)
                  // Was dumping the raw exception text at the user; a network
                  // failure now gets the app's standard offline state with a
                  // working Retry instead.
                  ? NoInternetView(onRetry: retryNow)
                  : Center(
                      child: Text(friendlyErrorMessage(_errorMessage)),
                    ))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   'Vendor Profile',
                        //   style: TextStyle(
                        //     fontSize: 22,
                        //     fontWeight: FontWeight.bold,
                        //     color: blueColor,
                        //   ),
                        // ),
                        titleBar(
                          width: MediaQuery.of(context).size.width > 500
                              ? MediaQuery.of(context).size.width * .88
                              : MediaQuery.of(context).size.width * .91,
                          title: 'Vendor Profile',
                        ),
                        const SizedBox(height: 10),
                        _sectionTitle('Vendor Information'),

                        Container(
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
                            children: [
                              _buildTextField(
                                label: 'Company Name *',
                                controller: _companyNameController,
                                hint: 'Enter company name',
                              ),
                              _buildTextField(
                                label: 'Company Email *',
                                controller: _companyEmailController,
                                hint: 'Enter company email',
                                keyboardType: TextInputType.emailAddress,
                                validator: _validateEmail,
                              ),
                              _buildTextField(
                                label: 'Cell Phone Number *',
                                controller: _cellPhoneController,
                                hint: '(xxx) xxx-xxxx',
                                keyboardType: TextInputType.phone,
                                validator: _validatePhone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                  PhoneNumberFormatter(),
                                ],
                              ),
                              _buildTextField(
                                label: 'Contact Cell Number *',
                                controller: _contactCellController,
                                hint: '(xxx) xxx-xxxx',
                                keyboardType: TextInputType.phone,
                                required: true,
                                validator: _validatePhone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                  PhoneNumberFormatter(),
                                ],
                              ),
                            ],
                          ),
                        ),

                        _sectionTitle('Address Details'),
                        Container(
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
                              children: [
                                _buildTextField(
                                  label: 'Street Address *',
                                  controller: _streetAddressController,
                                  hint: 'Start typing your address...',
                                ),
                                _buildTextField(
                                  label: 'City *',
                                  controller: _cityController,
                                  hint: 'Enter city',
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'State *',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      UsStateDropdown(
                                        controller: _stateController,
                                        hintText: 'Select state',
                                        borderColor: Colors.grey.shade400,
                                      ),
                                    ],
                                  ),
                                ),
                                // Like web (VendorProfile.jsx): digits only,
                                // ZIP+4 hyphen added as typed, web's checks.
                                _buildTextField(
                                  label: 'Zip Code *',
                                  controller: _zipCodeController,
                                  hint: 'Enter zip code',
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      validateZipCode(v, required: true),
                                  inputFormatters: [zipCodeFormatter],
                                ),
                                _buildTextField(
                                  label: 'Country *',
                                  controller: _countryController,
                                  hint: 'Enter country',
                                ),
                              ]),
                        ),

                        _sectionTitle('Contact Information *'),
                        ...List.generate(_contacts.length, (i) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_contacts.length > 1)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: Text(
                                            'Contact ${i + 1}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: blueColor,
                                            ),
                                          ),
                                        ),
                                      _buildTextField(
                                        label: 'Contact Name *',
                                        controller: _contacts[i].name,
                                        hint: 'Enter contact name',
                                      ),
                                      _buildTextField(
                                        label: 'Contact Email *',
                                        controller: _contacts[i].email,
                                        hint: 'Enter contact email',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: _validateEmail,
                                      ),
                                    ],
                                  ),
                                ),
                                if (_contacts.length > 1)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8, top: 8),
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _contacts[i].name.dispose();
                                          _contacts[i].number.dispose();
                                          _contacts[i].email.dispose();
                                          _contacts.removeAt(i);
                                        });
                                      },
                                      icon: Icon(Icons.remove_circle_outline,
                                          color: Colors.grey.shade600,
                                          size: 24),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey.shade100,
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _contacts.add(_ContactEntry())),
                          child: 
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.add,
                                  size: 15,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 2),
                              ],
                            ),
                          ),
                        
                        ),
                        const SizedBox(height: 15),
                        Divider(color: Colors.grey.shade400,height: 1,),
                        SizedBox(height: 8),
                        // OutlinedButton.icon(
                        //   onPressed: () =>
                        //       setState(() => _contacts.add(_ContactEntry())),
                        //   icon:  Icon(Icons.add, size: 20,color: Colors.green),
                        //   label: const Text(''),
                        //   style: OutlinedButton.styleFrom(
                        //     backgroundColor: Colors.green.withOpacity(0.1),

                        //  // side: BorderSide(color: blueColor),
                        //     padding: const EdgeInsets.symmetric(
                        //         vertical: 14, horizontal: 14),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        // ),
                        _sectionTitle('Trade & Service Area'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: blueColor.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: blueColor.withOpacity(0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Trade/Service Type *',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _tradeTypeOptions
                                        .contains(_selectedTradeType)
                                    ? _selectedTradeType
                                    : null,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                ),
                                hint: const Text('Select Trade'),
                                items: _tradeTypeOptions
                                    .map((s) => DropdownMenuItem(
                                        value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedTradeType = v),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Text(
                        //   'Service areas (zip code & distance)',
                        //   style: TextStyle(
                        //     fontSize: 13,
                        //     fontWeight: FontWeight.w600,
                        //     color: Colors.grey.shade700,
                        //   ),
                        // ),
                        const SizedBox(height: 10),
                        ...List.generate(_zipDistancePairs.length, (i) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
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
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        // Numbered from the 2nd row, like web.
                                        child: _buildTextField(
                                          label:
                                              'Zip Code${i > 0 ? ' ${i + 1}' : ''} *',
                                          controller:
                                              _zipDistancePairs[i].zipCode,
                                          hint: 'Enter zip code',
                                          keyboardType: TextInputType.number,
                                          validator: (v) => validateZipCode(v,
                                              required: true),
                                          inputFormatters: [zipCodeFormatter],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildTextField(
                                          label:
                                              'Distance (Miles)${i > 0 ? ' ${i + 1}' : ''} *',
                                          controller: _zipDistancePairs[i]
                                              .distanceMiles,
                                          hint: 'Enter distance',
                                          keyboardType: TextInputType.number,
                                          validator: _validateDistance,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_zipDistancePairs.length > 1)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(left: 8, top: 28),
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _zipDistancePairs[i]
                                              .zipCode
                                              .dispose();
                                          _zipDistancePairs[i]
                                              .distanceMiles
                                              .dispose();
                                          _zipDistancePairs.removeAt(i);
                                        });
                                      },
                                      icon: Icon(Icons.remove_circle_outline,
                                          color: Colors.grey.shade600,
                                          size: 24),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.grey.shade100,
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        GestureDetector(onTap: () => setState(() => _zipDistancePairs.add(_ZipDistanceEntry())),
                         child:
                          Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FaIcon(
                                  FontAwesomeIcons.add,
                                  size: 15,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 2),
                              ],
                            ),
                          ),
                        
                        ),
                        // OutlinedButton.icon(
                        //   onPressed: () => setState(
                        //       () => _zipDistancePairs.add(_ZipDistanceEntry())),
                        //   icon: const Icon(Icons.add, size: 20),
                        //   label: const Text('Add service area'),
                        //   style: OutlinedButton.styleFrom(
                        //     foregroundColor: blueColor,
                        //     side: BorderSide(color: blueColor),
                        //     padding: const EdgeInsets.symmetric(
                        //         vertical: 14, horizontal: 20),
                        //     shape: RoundedRectangleBorder(
                        //       borderRadius: BorderRadius.circular(10),
                        //     ),
                        //   ),
                        // ),
                         const SizedBox(height: 15),
                         Divider(color: Colors.grey.shade400,height: 1,),
                         SizedBox(height: 8),

                        _sectionTitle('Compliance & Legal'),
                        _buildTextField(
                          label: 'Licenses/Permits *',
                          controller: _licensesPermitsController,
                          hint:
                              'Please provide details of your licenses and permits...',
                          maxLines: 4,
                        ),
                        if (_showValidationError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Please complete all required fields marked in red',
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13),
                            ),
                          ),

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _updateProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: blueColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Update Profile',style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => _fetchProfile(),
                                  style: OutlinedButton.styleFrom(
                                    side:
                                        BorderSide(color: Colors.grey.shade600),
                                    foregroundColor: Colors.grey.shade700,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Cancel',style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold),),
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
