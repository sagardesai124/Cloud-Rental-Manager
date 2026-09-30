import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:provider/provider.dart';
import '../../../provider/dateProvider.dart';

import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/clearable_date_picker.dart';
import 'package:three_zero_two_property/widgets/clearable_date_suffix.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../Model/tenants.dart';

import '../../../repository/tenants.dart';
import '../../../widgets/custom_drawer.dart';

import 'package:three_zero_two_property/widgets/tenant_pets_vehicles_section.dart';

class EditTenants extends StatefulWidget {
  Tenant tenants;

  final String tenantId;
  EditTenants({
    required this.tenantId,
    required this.tenants,
  });
  @override
  State<EditTenants> createState() => _EditTenantsState();
}

class _EditTenantsState extends State<EditTenants> {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController phoneNumber = TextEditingController();
  bool obsecure = true;
  final TextEditingController workNumber = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController alterEmail = TextEditingController();

  final TextEditingController passWord = TextEditingController();

  // final TextEditingController dob = TextEditingController();

  final TextEditingController taxPayerId = TextEditingController();

  final TextEditingController comments = TextEditingController();

  final TextEditingController contactName = TextEditingController();

  final TextEditingController relationToTenant = TextEditingController();

  final TextEditingController emergencyEmail = TextEditingController();

  final TextEditingController emergencyPhoneNumber = TextEditingController();

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  bool form_valid = false;
  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    if (_dateController.text.isNotEmpty) {
      try {
        // Try to parse the date using common formats since it's now in user's preferred format
        List<String> dateFormats = [
          'yyyy-MM-dd',
          'yyyy-MMM-dd',
          'MM/dd/yyyy',
          'MM-dd-yyyy',
          'dd/MM/yyyy',
          'dd-MM-yyyy'
        ];

        for (String format in dateFormats) {
          try {
            initialDate = DateFormat(format).parse(_dateController.text);
            break;
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        // If parsing fails, use current date
        initialDate = DateTime.now();
      }
    }

    final ClearableDatePickerResult? result = await showClearableDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (result == null) return; // cancelled — keep the current value
    if (result.cleared) {
      setState(() {
        _dateController.clear();
      });
      return;
    }
    final DateTime selectedDate = result.date!;
    setState(() {
      // Get dateProvider to format the date according to user's preference
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      // Display format: Use provider's format for user display
      String apiFormatDate = DateFormat('yyyy-MM-dd').format(selectedDate);
      _dateController.text = dateProvider.formatCurrentDate(apiFormatDate);
    });
  }

  bool isValidEmail(String email) {
    String pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$';
    RegExp regex = RegExp(pattern);
    return regex.hasMatch(email);
  }

  String? initialFirstName;
  String? initialLastName;
  String? initialPhoneNumber;
  String? initialWorkNumber;
  String? initialEmail;
  String? initialAlterEmail;
  String? initialPassword;
  String? initialDob;
  String? initialTaxPayerId;
  String? initialComments;
  String? initialContactName;
  String? initialRelationToTenant;
  String? initialEmergencyEmail;
  String? initialEmergencyPhoneNumber;
  bool? initialoverride;
  bool initialEnableOverrideFee = false;
  String initialOverrideFee = '';
  bool initialEnableACH = true;
  bool initialEnableCard = true;

  // Web-aligned Edit form state: dynamic emergency contacts + the
  // read-only global debit fee line.
  final List<_EditEmergencyContactRow> emergencyContactsList = [];
  // Web parity (CRM-4585): optional Pets / Vehicles rows, hydrated from
  // get_tenant. Only sent back once loaded, so a failed load can never
  // overwrite the stored arrays with [] (server $set's only sent keys).
  final List<TenantSubdocRow> petsList = [];
  final List<TenantSubdocRow> vehiclesList = [];
  bool petsVehiclesLoaded = false;
  // TODO(API): replace with the owner's configured global debit fee.
  String globalDebitCardFee = "8";

  @override
  void initState() {
    overrideFee.addListener(_validateInput);
    // TODO: implement initState
    firstName.text = widget.tenants.tenantFirstName ?? "";
    lastName.text = widget.tenants.tenantLastName ?? "";
    phoneNumber.text = widget.tenants.tenantPhoneNumber != null
        ? formatPhoneNumberedit(widget.tenants.tenantPhoneNumber!)
        : "";
    workNumber.text = widget.tenants.tenantAlternativeNumber != null
        ? formatPhoneNumberedit(widget.tenants.tenantAlternativeNumber!)
        : "";
    email.text = widget.tenants.tenantEmail ?? "";
    alterEmail.text = widget.tenants.tenantAlternativeEmail ?? "";
    enableACH = widget.tenants.allowAch ?? true;
    enableCard = widget.tenants.allowCard ?? true;
    // passWord.text = widget.tenants.tenantPassword ?? "";
    // _dateController.text = widget.tenants.tenantBirthDate ?? "";
    taxPayerId.text = widget.tenants.taxPayerId ?? "";
    comments.text = widget.tenants.comments ?? "";
    contactName.text = widget.tenants.emergencyContact?.name ?? "";
    relationToTenant.text = widget.tenants.emergencyContact?.relation ?? "";
    emergencyPhoneNumber.text = widget.tenants.emergencyContact?.phoneNumber !=
            null
        ? formatPhoneNumberedit(widget.tenants.emergencyContact!.phoneNumber!)
        : "";
    emergencyEmail.text = widget.tenants.emergencyContact?.email ?? "";
    // Get dateProvider to format the date according to user's preference
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    String birthDate = widget.tenants.tenantBirthDate ?? "";
    if (birthDate.isNotEmpty) {
      _dateController.text = dateProvider.formatCurrentDate(birthDate);
    } else {
      _dateController.text = "";
    }

    // enableOverrideFee = widget.tenants.enableoverrideFee!;
    // overrideFee.text = widget.tenants.overRideFee?.toString() ?? '';

    initialFirstName = widget.tenants.tenantFirstName;
    initialLastName = widget.tenants.tenantLastName;
    initialPhoneNumber = widget.tenants.tenantPhoneNumber;
    initialWorkNumber = widget.tenants.tenantAlternativeNumber;
    initialEmail = widget.tenants.tenantEmail;
    initialAlterEmail = widget.tenants.tenantAlternativeEmail;
    initialPassword = widget.tenants.tenantPassword;
    initialDob = widget.tenants.tenantBirthDate;
    initialTaxPayerId = widget.tenants.taxPayerId;
    initialComments = widget.tenants.comments;
    initialContactName = widget.tenants.emergencyContact?.name;
    initialRelationToTenant = widget.tenants.emergencyContact?.relation;
    initialEmergencyEmail = widget.tenants.emergencyContact?.email;
    initialEmergencyPhoneNumber = widget.tenants.emergencyContact?.phoneNumber;

    fetchCompany();
    fetchTenantOverrideFee(widget.tenants.tenantId!);
    super.initState();
  }

  bool isLoading = false;
  bool isInitialLoading = true; // Add this to track initial loading
  String? errorMessage;
  bool formValid = false;
  String companyName = '';
  // String errorMessage = '';
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

  bool enableOverrideFee = false;
  bool enableACH = true;
  // WEB parity: allow_card is opt-out (defaults true) like tenantFormConfig.js
  bool enableCard = true;
  final TextEditingController overrideFee = TextEditingController();
  String overRideFeeError = '';
  void _validateInput() {
    setState(() {
      String input = overrideFee.text.trim();
      if (input.isEmpty) {
        overRideFeeError = 'This field cannot be empty';
      } else if (!RegExp(r'^(\d{1,2}(\.\d{1,2})?|100(\.0{1,2})?)$')
          .hasMatch(input)) {
        overRideFeeError =
            'Enter a valid number up to 100 with up to 2 decimal places';
      } else {
        overRideFeeError = '';
      }
    });
  }

  /// Parse bool from API (handles bool, string "true"/"false", 0/1, or null).
  bool _parseBoolFromApi(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    if (value is int) return value == 1;
    return defaultValue;
  }

  // Helper function to convert display format back to API format (yyyy-MM-dd)
  String _convertToApiFormat(String displayDate) {
    if (displayDate.isEmpty) return "";
    try {
      DateTime? parsedDate;

      // Try to parse the date using common formats
      List<String> dateFormats = [
        'yyyy-MM-dd',
        'yyyy-MMM-dd',
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'dd/MM/yyyy',
        'dd-MM-yyyy'
      ];

      for (String format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(displayDate);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }

      return displayDate; // Return as is if parsing fails
    } catch (e) {
      return displayDate; // Return as is if parsing fails
    }
  }

  @override
  void dispose() {
    overrideFee.removeListener(_validateInput);
    overrideFee.dispose();
    for (final row in emergencyContactsList) {
      row.dispose();
    }
    for (final row in [...petsList, ...vehiclesList]) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> fetchTenantOverrideFee(String tenantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    // get_tenant returns allow_ach, allow_card, enable_override_fee, override_fee in data object
    final response = await apiGet(
      Uri.parse('$Api_url/api/tenant/get_tenant/$tenantId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      // get_tenant returns { "data": { ...tenant object } }, not an array
      final tenantData = jsonResponse['data'];
      if (tenantData == null || tenantData is! Map) {
        setState(() => isInitialLoading = false);
        return;
      }

      setState(() {
        enableOverrideFee = _parseBoolFromApi(tenantData['enable_override_fee'], defaultValue: false);
        overrideFee.text = tenantData['override_fee'] != null
            ? tenantData['override_fee'].toString()
            : '';
        // Parse allow_ach / allow_card (API may send bool, string "true"/"false", or camelCase)
        enableACH = _parseBoolFromApi(tenantData['allow_ach'] ?? tenantData['allowAch'], defaultValue: true);
        enableCard = _parseBoolFromApi(tenantData['allow_card'] ?? tenantData['allowCard'], defaultValue: true);
        initialEnableOverrideFee = enableOverrideFee;
        initialOverrideFee = overrideFee.text;
        initialEnableACH = enableACH;
        initialEnableCard = enableCard;
        passWord.text = tenantData['tenant_password'] ?? '';

        // Handle null values for phone numbers and other fields
        workNumber.text = tenantData['tenant_alternativeNumber'] != null
            ? formatPhoneNumberedit(tenantData['tenant_alternativeNumber'])
            : '';
        emergencyPhoneNumber.text =
            tenantData['emergency_contact']?['phoneNumber'] != null
                ? formatPhoneNumberedit(
                    tenantData['emergency_contact']['phoneNumber'])
                : '';

        // Build the editable emergency-contacts list from the legacy
        // singular field + the emergency_contacts array (mirrors the web).
        for (final r in emergencyContactsList) {
          r.dispose();
        }
        emergencyContactsList.clear();
        final legacyEc = tenantData['emergency_contact'];
        if (legacyEc is Map &&
            ((legacyEc['name'] ?? '').toString().isNotEmpty ||
                (legacyEc['relation'] ?? '').toString().isNotEmpty ||
                (legacyEc['email'] ?? '').toString().isNotEmpty ||
                (legacyEc['phoneNumber'] ?? '').toString().isNotEmpty)) {
          emergencyContactsList.add(_EditEmergencyContactRow(
            contactId: 'primary',
            name: legacyEc['name']?.toString() ?? '',
            relation: legacyEc['relation']?.toString() ?? '',
            email: legacyEc['email']?.toString() ?? '',
            phone:
                formatPhoneNumberedit(legacyEc['phoneNumber']?.toString() ?? ''),
          ));
        }
        final ecArray = tenantData['emergency_contacts'];
        if (ecArray is List) {
          for (final c in ecArray) {
            if (c is Map &&
                c['contact_id'] != null &&
                c['contact_id'].toString().isNotEmpty) {
              emergencyContactsList.add(_EditEmergencyContactRow(
                contactId: c['contact_id'].toString(),
                name: c['name']?.toString() ?? '',
                relation: c['relation']?.toString() ?? '',
                email: c['email']?.toString() ?? '',
                phone: formatPhoneNumberedit(c['phoneNumber']?.toString() ?? ''),
              ));
            }
          }
        }

        // [EC-DEBUG] Temporary diagnostic (remove after emergency-contact
        // reload issue is resolved). Prints contact_id presence only, no PII.

        for (final r in [...petsList, ...vehiclesList]) {
          r.dispose();
        }
        petsList
          ..clear()
          ..addAll(tenantSubdocRowsFromJson(
              tenantData['pets'], kTenantPetFields));
        vehiclesList
          ..clear()
          ..addAll(tenantSubdocRowsFromJson(
              tenantData['vehicles'], kTenantVehicleFields));
        petsVehiclesLoaded = true;

        isInitialLoading = false; // Mark initial loading as complete
      });
    } else {
      setState(() {
        isInitialLoading = false; // Mark loading as complete even on error
      });
      throw Exception('Failed to load tenant override fee data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: pageBg,
      drawer: CustomDrawer(
        currentpage: "Tenants",
        dropdown: true,
      ),
      body: isInitialLoading
          ? const Center(
              child: SpinKitFadingCircle(color: Colors.black, size: 40.0),
            )
          : Form(
              key: _formkey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBar(width: double.infinity, title: 'Edit Tenant'),
                        const SizedBox(height: 20),
                        _personalInfoCard(),
                        const SizedBox(height: 16),
                        _emergencyContactsCard(),
                        const SizedBox(height: 16),
                        TenantSubdocSection.pets(
                          rows: petsList,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        TenantSubdocSection.vehicles(
                          rows: vehiclesList,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _paymentSettingsCard(),
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

  // ---- Web-aligned Edit Tenant form helpers -----------------------------

  Widget _sectionCard({
    required String title,
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

  Widget _input({
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool optional = false,
    bool email = false,
    bool phone = false,
    bool readOnly = false,
    String? label,
    VoidCallback? onTap,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    TextEditingController? otherController,
    TextEditingController? alterController,
    TextEditingController? telephoneController,
  }) {
    return CustomTextField(
      hintText: hint,
      controller: controller,
      keyboardType: keyboardType,
      optional: optional,
      email: email ? true : null,
      phone: phone ? true : null,
      readOnnly: readOnly,
      label: label,
      onTap: onTap,
      suffixIcon: suffixIcon,
      inputFormatters: inputFormatters,
      otherController: otherController,
      alterController: alterController,
      telephoneController: telephoneController,
      showElevation: false,
      borderColor: outlineClr,
      borderWidth: 1,
    );
  }

  Widget _checkRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget label,
    CrossAxisAlignment cross = CrossAxisAlignment.center,
  }) {
    return Row(
      crossAxisAlignment: cross,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
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
        Expanded(child: label),
      ],
    );
  }

  Widget _notesField() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: outlineClr),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: comments,
        maxLines: null,
        expands: true,
        keyboardType: TextInputType.multiline,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
          hintText: 'Enter notes',
          hintStyle: TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
        ),
      ),
    );
  }

  Widget _personalInfoCard() {
    return _sectionCard(
      title: 'Personal Information',
      children: [
        _fieldLabel('First Name', required: true),
        _input(
            hint: 'Enter first name',
            controller: firstName,
            // Web parity: first name accepts letters, space, apostrophe only.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z ']")),
            ]),
        const SizedBox(height: 16),
        _fieldLabel('Last Name', required: true),
        _input(
            hint: 'Enter last name',
            controller: lastName,
            // Web parity: last name accepts letters, space, hyphen, apostrophe.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z '-]")),
            ]),
        const SizedBox(height: 16),
        _fieldLabel('Phone Number', required: true),
        _input(
          hint: 'Enter phone number',
          controller: phoneNumber,
          keyboardType: TextInputType.phone,
          phone: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(14),
            PhoneNumberFormatter(),
          ],
        ),
        const SizedBox(height: 16),
        _fieldLabel('Work Number'),
        _input(
          hint: 'Enter work number',
          controller: workNumber,
          keyboardType: TextInputType.phone,
          optional: true,
          phone: true,
          // Web parity: work number must differ from the primary phone.
          otherController: phoneNumber,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(14),
            PhoneNumberFormatter(),
          ],
        ),
        const SizedBox(height: 16),
        _fieldLabel('Email', required: true),
        _input(
          hint: 'Enter email',
          controller: email,
          keyboardType: TextInputType.emailAddress,
          email: true,
        ),
        const SizedBox(height: 16),
        _fieldLabel('Alternative Email'),
        _input(
          hint: 'Enter alternative email',
          controller: alterEmail,
          keyboardType: TextInputType.emailAddress,
          optional: true,
          email: true,
          // Web parity: alternative email must differ from the primary email.
          alterController: email,
        ),
        const SizedBox(height: 16),
        _fieldLabel('Date of Birth'),
        _input(
          hint: 'YYYY-MM-DD',
          controller: _dateController,
          readOnly: true,
          optional: true,
          onTap: () => _selectDate(context),
          suffixIcon: ClearableDateSuffix(
            controller: _dateController,
            onPick: () => _selectDate(context),
            iconColor: mutedClr,
          ),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Notes'),
        _notesField(),
      ],
    );
  }

  Widget _emergencyContactsCard() {
    return _sectionCard(
      title: 'Emergency Contacts',
      trailing: OutlinedButton.icon(
        onPressed: () {
          setState(() => emergencyContactsList.add(_EditEmergencyContactRow()));
        },
        icon: Icon(Icons.add_circle_outline, size: 18, color: navyClr),
        label: Text(
          'Add Contact',
          style: TextStyle(color: navyClr, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: outlineClr),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      children: [
        if (emergencyContactsList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: pageBg,
              border: Border.all(color: borderClr),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No emergency contacts yet. Tap "Add Contact" to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: mutedClr,
                fontSize: 13,
              ),
            ),
          )
        else
          ...List.generate(
            emergencyContactsList.length,
            (i) => _contactCard(i),
          ),
      ],
    );
  }

  Widget _contactCard(int index) {
    final row = emergencyContactsList[index];
    final isLast = index == emergencyContactsList.length - 1;
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pageBg,
        border: Border.all(color: borderClr),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contact #${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyClr,
                  fontSize: 14,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    emergencyContactsList[index].dispose();
                    emergencyContactsList.removeAt(index);
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: redClr.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline, color: redClr, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('Contact Name'),
          _input(
            hint: 'Enter contact name',
            controller: row.name,
            optional: true,
            // Web parity: emergency contact name accepts letters and spaces
            // only (web blocks non-[a-zA-Z\s] input in TenantFormFields).
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('Relationship to Tenant'),
          _input(
            hint: 'Enter relationship to tenant',
            controller: row.relation,
            optional: true,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Email'),
          _input(
            hint: 'Enter email',
            controller: row.email,
            keyboardType: TextInputType.emailAddress,
            optional: true,
            email: true,
            // Web parity: emergency email must differ from the tenant's email.
            alterController: email,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Phone Number'),
          _input(
            hint: 'Enter phone number',
            controller: row.phone,
            keyboardType: TextInputType.phone,
            optional: true,
            phone: true,
            // Web parity: emergency phone must differ from the tenant's phone.
            telephoneController: phoneNumber,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(14),
              PhoneNumberFormatter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentSettingsCard() {
    return _sectionCard(
      title: 'Payment Settings',
      children: [
        // Web parity: on Edit the global debit-card fee line and the
        // per-tenant override are hidden (managed at Add time). The
        // tenant's existing enable_override_fee / override_fee are still
        // preserved and sent unchanged in the PUT payload.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tintBg,
            border: Border.all(color: borderClr),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Allowed Payment Methods',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: navyClr,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              _checkRow(
                value: enableACH,
                onChanged: (v) => setState(() => enableACH = v ?? false),
                label: Text(
                  'ACH',
                  style: TextStyle(fontSize: 15, color: navyClr),
                ),
              ),
              const SizedBox(height: 8),
              _checkRow(
                value: enableCard,
                onChanged: (v) => setState(() => enableCard = v ?? false),
                label: Text(
                  'Credit Card',
                  style: TextStyle(fontSize: 15, color: navyClr),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomActionBar() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
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
            onPressed: isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: navyClr,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: SpinKitFadingCircle(color: Colors.white, size: 22),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
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

  Future<void> _saveChanges() async {
    setState(() => formValid = true);
    if (!_formkey.currentState!.validate()) return;

    setState(() => isLoading = true);

    // Build web-aligned emergency_contacts array. Existing rows keep their
    // contact_id; new rows omit it (server stamps one). Empty rows skipped.
    final List<Map<String, dynamic>> emergencyContacts = emergencyContactsList
        .where((c) =>
            c.name.text.trim().isNotEmpty ||
            c.relation.text.trim().isNotEmpty ||
            c.email.text.trim().isNotEmpty ||
            c.phone.text.trim().isNotEmpty)
        .map((c) {
      final m = <String, dynamic>{
        "name": c.name.text.trim(),
        "relation": c.relation.text.trim(),
        "email": c.email.text.trim().toLowerCase(),
        "phoneNumber": formatPhoneNumberedit(c.phone.text.trim()),
      };
      if ((c.contactId ?? '').isNotEmpty) m["contact_id"] = c.contactId;
      return m;
    }).toList();

    // [EC-DEBUG] Temporary diagnostic (remove later) — emergency payload ids.

    // Web-aligned Edit PUT body: no tenant_id / admin_id / company_name /
    // send_welcome_email; legacy emergency_contact cleared (moved to array);
    // is_web / user_active_recently intentionally omitted on mobile.
    final Map<String, dynamic> body = {
      "tenant_firstName": firstName.text.trim(),
      "tenant_lastName": lastName.text.trim(),
      "tenant_phoneNumber": formatPhoneNumberedit(phoneNumber.text.trim()),
      "tenant_alternativeNumber":
          formatPhoneNumberedit(workNumber.text.trim()),
      "tenant_email": email.text.trim().toLowerCase(),
      "tenant_alternativeEmail": alterEmail.text.trim().toLowerCase(),
      "tenant_birthDate": _dateController.text.trim().isNotEmpty
          ? _convertToApiFormat(_dateController.text.trim())
          : "",
      "comments": comments.text.trim(),
      "emergency_contact": {
        "name": "",
        "relation": "",
        "email": "",
        "phoneNumber": "",
      },
      "emergency_contacts": emergencyContacts,
      if (petsVehiclesLoaded) "pets": tenantSubdocPayload(petsList),
      if (petsVehiclesLoaded) "vehicles": tenantSubdocPayload(vehiclesList),
      "enable_override_fee": enableOverrideFee,
      "override_fee": enableOverrideFee ? overrideFee.text.trim() : "",
      "allow_ach": enableACH,
      "allow_card": enableCard,
    };

    try {
      final ok = await TenantsRepository()
          .editTenantPayload(widget.tenants.tenantId ?? "", body);
      if (!mounted) return;
      setState(() => isLoading = false);
      if (ok) {
        Fluttertoast.showToast(msg: "Tenant updated successfully");
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      logError(e.toString());
    }
  }

  reload_Screen() {
    setState(() {});
  }
}

// class CustomTextField extends StatefulWidget {
//   final String hintText;
//   final TextEditingController? controller;
//   final TextInputType keyboardType;
//   final String? Function(String?)? validator;
//   final bool obscureText;
//   final Function(String)? onChanged;
//   final Function(String)? onChanged2;
//   final Widget? suffixIcon;
//   final IconData? prefixIcon;
//   final void Function()? onSuffixIconPressed;
//   final void Function()? onTap;
//   final String? label;
//   final bool readOnnly;
//   final bool? amount_check;
//   final String? max_amount;
//   final String? error_mess;
//   final bool? optional;
//   final bool? email;
//   final bool? pass;
//   final bool? phone;
//   final List<TextInputFormatter>? inputFormatters;
//   final bool? worknum;
//   final bool? phonenum;
//   final bool? businessnum;
//   final TextEditingController? otherController;
//   final TextEditingController? businessController;
//   final TextEditingController? telephoneController;
//   final bool? samephonenumber;
//
//   CustomTextField({
//     Key? key,
//     this.onChanged,
//     this.controller,
//     required this.hintText,
//     this.obscureText = false,
//     this.keyboardType = TextInputType.emailAddress,
//     this.readOnnly = false,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.validator,
//     this.onSuffixIconPressed,
//     this.label,
//     this.onTap,
//     this.onChanged2,
//     this.amount_check,
//     this.max_amount,
//     this.error_mess,
//     this.optional = false,
//     this.email,
//     this.pass,
//     this.phone,
//     this.inputFormatters,
//     this.worknum,
//     this.phonenum,
//     this.businessnum,
//     this.otherController, // For work number comparison
//     this.businessController,
//     this.telephoneController,
//     this.samephonenumber=false
//     // Initialize onTap
//   }) : super(key: key);
//
//   @override
//   CustomTextFieldState createState() => CustomTextFieldState();
// }
//
// class CustomTextFieldState extends State<CustomTextField> {
//   String? _errorMessage;
//   TextEditingController _textController =
//       TextEditingController(); // Add this line
//   late FocusNode _focusNode;
//   @override
//   void dispose() {
//     _textController.dispose(); // Dispose the controller when not needed anymore
//     super.dispose();
//     _focusNode.dispose();
//   }
//
//   @override
//   void initState() {
//     super.initState();
//     _textController = widget.controller ?? TextEditingController();
//     _focusNode = FocusNode();
//   }
//
//   KeyboardActionsConfig _buildConfig(BuildContext context) {
//     return KeyboardActionsConfig(
//       actions: [
//         KeyboardActionsItem(
//           focusNode: _focusNode,
//           toolbarButtons: [
//             (node) {
//               return GestureDetector(
//                 onTap: () {
//                   if (widget.onChanged2 != null) {
//                     widget.onChanged2!(_textController.text);
//                   }
//                   node.unfocus(); // Dismiss the keyboard
//                 },
//                 child: Padding(
//                   padding: EdgeInsets.all(14.0),
//                   child: Text(
//                     "Done",
//                     style: TextStyle(
//                         color: Colors.blue, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               );
//             },
//           ],
//         ),
//       ],
//     );
//   }
//   void _validatePhoneNumber(String value) {
//     String formattedPhoneNumber = value.replaceAll(RegExp(r'\D'), '');
//
//     // Check if phone number is exactly 10 digits
//     if (formattedPhoneNumber.length != 10) {
//       setState(() {
//         _errorMessage = "Phone number must be 10 digits";
//       });
//     } else {
//       // Validate uniqueness across all phone number controllers
//       if (widget.telephoneController != null &&
//           widget.telephoneController?.text == value) {
//         setState(() {
//           _errorMessage = 'Number cannot be the same as another';
//         });
//       } else if (widget.otherController != null &&
//           widget.otherController?.text == value) {
//         setState(() {
//           _errorMessage = 'Number cannot be the same as another';
//         });
//       } else if (widget.businessController != null &&
//           widget.businessController?.text == value) {
//         setState(() {
//           _errorMessage = 'Number cannot be the same as another';
//         });
//       } else {
//         setState(() {
//           _errorMessage = null; // Clear error message when the number is valid
//         });
//       }
//     }
//   }
//   @override
//   Widget build(BuildContext context) {
//     final shouldUseKeyboardActions =
//         widget.keyboardType == TextInputType.number;
//     Widget textfield = Stack(
//       clipBehavior: Clip.none,
//       children: <Widget>[
//         FormField<String>(
//           validator: widget.optional!
//               ? (value) {
//                   if (widget.controller!.text.isEmpty) {
//                     return null;
//                   } else if (widget.phone != null) {
//                     print(" num calling ${widget.phone}");
//                     // String formattedPhoneNumber =
//                     //     widget.controller!.text.replaceAll(RegExp(r'\D'), '');
//                     //
//                     // // Removed the empty check
//                     // if (formattedPhoneNumber.length != 10) {
//                     //   setState(() {
//                     //     _errorMessage = "Phone number must be 10 digits";
//                     //   });
//                     //   return '';
//                     // }
//                     _validatePhoneNumber(widget.controller!.text);
//                     return '';
//                   } else if (widget.amount_check != null &&
//                       double.parse(widget.controller!.text) >
//                           double.parse(widget.max_amount!))
//                     setState(() {
//                       _errorMessage = '${widget.error_mess}';
//                     });
//                   return null;
//                 }
//               : (value) {
//                   if (widget.controller!.text.isEmpty) {
//                     setState(() {
//                       if (widget.label == null)
//                         _errorMessage = 'Please ${widget.hintText.toLowerCase()}';
//                       else
//                         _errorMessage = 'Please ${(widget.label ?? '').toLowerCase()}';
//                     });
//                     return '';
//                   } else if (widget.phone != null) {
//                     String formattedPhoneNumber =
//                         widget.controller!.text.replaceAll(RegExp(r'\D'), '');
//
//                     // Removed the empty check
//                     if (formattedPhoneNumber.length != 10) {
//                       setState(() {
//                         _errorMessage = "Phone number must be 10 digits";
//                       });
//                       return '';
//                     }
//                   } else if (widget.email != null) {
//                     if (!EmailValidator.validate(widget.controller!.text)) {
//                       setState(() {
//                         _errorMessage = "Email is not valid";
//                       });
//                       return '';
//                     }
//                   } else if (widget.pass != null) {
//                     String? validationMessage =
//                         ValidatePassword(widget.controller!.text);
//                     if (validationMessage != null) {
//                       setState(() {
//                         _errorMessage = validationMessage;
//                       });
//                       return '';
//                     }
//                   }
//                   // else if (widget.pass != null) {
//                   //   // Validate as password
//                   //   String? validationMessage = ValidatePassword(value ?? '');
//                   //   if (validationMessage != null) {
//                   //     setState(() {
//                   //       _errorMessage = validationMessage;
//                   //     });
//                   //     return ''; // Return empty string to indicate error
//                   //   }
//                   // }
//
//                   else if (widget.amount_check != null &&
//                       double.parse(widget.controller!.text) >
//                           double.parse(widget.max_amount!))
//                     setState(() {
//                       _errorMessage = '${widget.error_mess}';
//                     });
//                   return null;
//                 },
//           builder: (FormFieldState<String> state) {
//             return Column(
//               children: <Widget>[
//                 Material(
//                   elevation: 2,
//                   borderRadius: BorderRadius.circular(8.0),
//                   child: Container(
//                     height: 50,
//                     padding:
//                         EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8.0),
//                       //border: Border.all(color: blueColor),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.2),
//                           offset: Offset(4, 4),
//                           blurRadius: 3,
//                         ),
//                       ],
//                     ),
//                     child: TextFormField(
//                       /*    onFieldSubmitted: (value){
//                         if(value.isNotEmpty){
//
//                           if(widget.amount_check != null){
//                             if(int.parse(value) > int.parse(widget.max_amount!)){
//                               setState(() {
//                                 _errorMessage = '${widget.error_mess}';
//                               });
//                             }
//                           }
//                           else{
//                             setState(() {
//                               _errorMessage = null;
//                             });
//                           }
//
//                         }
//                         print(value);
//                         widget.onChanged2;
//                       },*/
//                       onFieldSubmitted: widget.onChanged2,
//                       onChanged: (value) {
//                         //  print("object calin $value");
//                         if (value.isNotEmpty) {
//                           setState(() {
//                             _errorMessage = null;
//                           });
//                         }
//                         if (widget.onChanged != null) widget.onChanged!(value);
// //print("callllll");
//                       },
//                       inputFormatters: widget.inputFormatters ?? [],
//                       focusNode: _focusNode,
//                       onTap: () {
//                         if (widget.onTap != null) {
//                           widget.onTap!();
//                           setState(() {
//                             _errorMessage = null;
//                           });
//                         }
//                       },
//                       obscureText: widget.obscureText,
//                       readOnly: widget.readOnnly,
//                       keyboardType: widget.keyboardType,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           state.validate();
//                         }
//                         return null;
//                       },
//                       controller: widget.controller,
//                       decoration: InputDecoration(
//                         suffixIcon: widget.suffixIcon,
//                         hintStyle:
//                             TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
//                         border: InputBorder.none,
//                         hintText: widget.hintText,
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (state.hasError && _errorMessage != null ||
//                     widget.amount_check != null)
//                   SizedBox(height: 24),
//                 // Reserve space for error message
//               ],
//             );
//           },
//         ),
//         if (_errorMessage != null)
//           Positioned(
//             top: 60,
//             left: 8,
//             child: Text(
//               _errorMessage!,
//               style: TextStyle(
//                 color: Colors.red,
//                 fontSize: 12.0,
//               ),
//             ),
//           ),
//       ],
//     );
//     return shouldUseKeyboardActions
//         ? SizedBox(
//             height: 60,
//             width: MediaQuery.of(context).size.width * .98,
//             child: KeyboardActions(
//               config: _buildConfig(context),
//               child: textfield,
//             ),
//           )
//         : textfield;
//   }
// }
class CustomTextField extends StatefulWidget {
  final String hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Function(String)? onChanged;
  final Function(String)? onChanged2;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final void Function()? onSuffixIconPressed;
  final void Function()? onTap;
  final String? label;
  final bool readOnnly;
  final bool? amount_check;
  final String? max_amount;
  final String? error_mess;
  final bool? optional;
  final bool? email;
  final bool? pass;
  final bool? phone;
  final bool? worknum;
  final bool? phonenum;
  final bool? businessnum;
  final List<TextInputFormatter>? inputFormatters;
  final TextEditingController? otherController;
  final TextEditingController? businessController;
  final TextEditingController? telephoneController;
  final TextEditingController? alterController;
  final TextEditingController? emrgencyController;
  final bool? samephonenumber;
  final bool? isInRow; // NEW PARAMETER FOR ROW LAYOUT
  final Border? customBorder; // NEW PARAMETER FOR CUSTOM BORDER
  final Color? borderColor; // NEW PARAMETER FOR BORDER COLOR
  final double? borderWidth; // NEW PARAMETER FOR BORDER WIDTH
  final bool showElevation; // NEW PARAMETER TO CONTROL ELEVATION AND SHADOW
  final int? errorMaxLines; // NEW PARAMETER FOR ERROR MESSAGE MAX LINES
  final TextInputAction? textInputAction; // NEW PARAMETER FOR TEXT INPUT ACTION

  CustomTextField(
      {Key? key,
      this.onChanged,
      this.controller,
      required this.hintText,
      this.obscureText = false,
      this.keyboardType = TextInputType.emailAddress,
      this.readOnnly = false,
      this.prefixIcon,
      this.suffixIcon,
      this.validator,
      this.onSuffixIconPressed,
      this.label,
      this.onTap,
      this.onChanged2,
      this.amount_check,
      this.max_amount,
      this.error_mess,
      this.optional = false,
      this.email,
      this.pass,
      this.phone,
      this.inputFormatters,
      this.worknum,
      this.phonenum,
      this.businessnum,
      this.otherController, // For work number comparison
      this.businessController,
      this.telephoneController,
      this.alterController,
      this.emrgencyController,
      this.samephonenumber = false,
      this.isInRow = false, // DEFAULT TO FALSE FOR SINGLE COLUMN LAYOUT
      this.customBorder, // CUSTOM BORDER PARAMETER
      this.borderColor, // BORDER COLOR PARAMETER
      this.borderWidth, // BORDER WIDTH PARAMETER
      this.showElevation =
          true, // DEFAULT TO TRUE TO MAINTAIN EXISTING BEHAVIOR
      this.errorMaxLines, // PARAMETER FOR ERROR MESSAGE MAX LINES
      this.textInputAction // PARAMETER FOR TEXT INPUT ACTION
      })
      : super(key: key);

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  String? _errorMessage;
  TextEditingController _textController =
      TextEditingController(); // Add this line
  late FocusNode _focusNode;
  @override
  void dispose() {
    //  _textController.dispose(); // Dispose the controller when not needed anymore
    super.dispose();
    _focusNode.dispose();
  }

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
  }

  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      actions: [
        KeyboardActionsItem(
          focusNode: _focusNode,
          toolbarButtons: [
            (node) {
              return GestureDetector(
                onTap: () {
                  if (widget.onChanged2 != null) {
                    widget.onChanged2!(_textController.text);
                  }
                  node.unfocus(); // Dismiss the keyboard
                },
                child: const Padding(
                  padding: EdgeInsets.all(14.0),
                  child: Text(
                    "Done",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ],
        ),
      ],
    );
  }

  void _validatePhoneNumber(String value) {
    String formattedPhoneNumber = value.replaceAll(RegExp(r'\D'), '');
    // Check if phone number is exactly 10 digits
    if (formattedPhoneNumber.length != 10) {
      setState(() {
        _errorMessage = "Phone number must be 10 digits";
      });
    } else {
      // Validate uniqueness across all phone number controllers
      if (widget.telephoneController != null &&
          widget.telephoneController?.text == value) {
        setState(() {
          _errorMessage = 'Number cannot be the same as another';
        });
      } else if (widget.otherController != null &&
          widget.otherController?.text == value) {
        setState(() {
          _errorMessage = 'Number cannot be the same as another';
        });
      } else if (widget.businessController != null &&
          widget.businessController?.text == value) {
        setState(() {
          _errorMessage = 'Number cannot be the same as another';
        });
      } else {
        setState(() {
          _errorMessage = null; // Clear error message when the number is valid
        });
      }
    }
  }

  void _validateEmail(String value) {
    // Validate email format using EmailValidator
    if (!EmailValidator.validate(value)) {
      setState(() {
        _errorMessage = "Email is not valid";
      });
    } else {
      // Check if email is not the same as another email (example: other controllers)
      if (widget.alterController != null &&
          widget.alterController?.text == value) {
        setState(() {
          _errorMessage = 'Email cannot be the same';
        });
      } else if (widget.emrgencyController != null &&
          widget.emrgencyController?.text == value) {
        setState(() {
          _errorMessage = 'Email cannot be the same';
        });
      } else {
        setState(() {
          _errorMessage = null; // Clear error message when email is valid
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldUseKeyboardActions =
        widget.keyboardType == TextInputType.number;

    bool hasError = _errorMessage != null && _errorMessage!.isNotEmpty;

    Widget textfield = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // SHRINK TO CONTENT LIKE YOUR STAFF FILE
      children: [
        FormField<String>(
          validator: widget.optional!
              ? (value) {
                  if (widget.controller!.text.trim().isEmpty) {
                    return null;
                  } else if (widget.phone != null) {
                    _validatePhoneNumber(widget.controller!.text.trim());
                    if (_errorMessage == null) {
                      return null;
                    }
                    return '';
                  } else if (widget.email != null) {
                    _validateEmail(widget.controller!.text.trim());
                    // Return an empty string or handle accordingly
                    if (_errorMessage == null) {
                      return null;
                    }
                    return '';
                  } else if (widget.amount_check != null &&
                      (double.tryParse(widget.controller!.text.trim()) ?? 0.0) >
                          (double.tryParse(widget.max_amount!) ?? 0.0))
                    setState(() {
                      _errorMessage = '${widget.error_mess}';
                    });
                  return null;
                }
              : (value) {
                  if (widget.controller!.text.trim().isEmpty) {
                    setState(() {
                      if (widget.label == null)
                        _errorMessage = 'Please ${widget.hintText.toLowerCase()}';
                      else
                        _errorMessage = 'Please ${(widget.label ?? '').toLowerCase()}';
                    });
                    return '';
                  } else if (widget.phone != null) {
                    // Check if it's a phone number
                    String formattedPhoneNumber =
                        widget.controller!.text.replaceAll(RegExp(r'\D'), '');

                    if (formattedPhoneNumber.length != 10) {
                      setState(() {
                        _errorMessage = "Phone number must be 10 digits";
                      });
                      return '';
                    }
                    if (widget.samephonenumber != null &&
                        widget.samephonenumber!) {
                      setState(() {
                        _errorMessage =
                            'Phone number and work number cannot be the same';
                      });
                      return '';
                    } else {
                      // Clear error message if phone number is valid
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  } else if (widget.email != null) {
                    if (!EmailValidator.validate(
                        widget.controller!.text.trim())) {
                      setState(() {
                        _errorMessage = "Email is not valid";
                      });
                      return '';
                    }
                    //   _validateEmail(widget.controller!.text);
                    //
                    //   // Return an empty string or handle accordingly
                    //   return '';
                  } else if (widget.pass != null) {
                    String? validationMessage =
                        ValidatePassword(widget.controller!.text.trim());
                    if (validationMessage != null) {
                      setState(() {
                        _errorMessage = validationMessage;
                      });
                      return '';
                    }
                  } else if (widget.amount_check != null &&
                      (double.tryParse(widget.controller!.text.trim()) ?? 0.0) >
                          (double.tryParse(widget.max_amount!) ?? 0.0))
                    setState(() {
                      _errorMessage = '${widget.error_mess}';
                    });
                  return null;
                },
          builder: (FormFieldState<String> state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Material(
                  elevation: widget.showElevation ? 2 : 0,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 50,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      // Custom border implementation
                      border: widget.customBorder ??
                          (widget.borderColor != null
                              ? Border.all(
                                  color: widget.borderColor!,
                                  width: widget.borderWidth ?? 1.0)
                              : null),
                      boxShadow: widget.showElevation
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: const Offset(4, 4),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                    child: TextFormField(
                      onFieldSubmitted: widget.onChanged2,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                        if (widget.onChanged != null) widget.onChanged!(value);
                      },
                      inputFormatters: widget.inputFormatters ?? [],
                      focusNode: _focusNode,
                      onTap: () {
                        if (widget.onTap != null) {
                          widget.onTap!();
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                      obscureText: widget.obscureText,
                      readOnly: widget.readOnnly,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          state.validate();
                        }
                        return null;
                      },
                      controller: widget.controller,
                      decoration: InputDecoration(
                        suffixIcon: widget.suffixIcon,
                        hintStyle:
                            const TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
                        border: InputBorder.none,
                        hintText: widget.hintText,
                      ),
                    ),
                  ),
                ),
                hasError
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.pass == true) const SizedBox(width: 4),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(1.0),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11.0, // Even smaller font size
                                      height: 1.1, // Even tighter line height
                                      letterSpacing:
                                          -0.2, // Slightly tighter letter spacing
                                    ),
                                    maxLines: widget.pass == true
                                        ? 6
                                        : 1, // Increased to 6 lines for very long messages
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ],
            );
          },
        ),
      ],
    );
    return shouldUseKeyboardActions
        ? SizedBox(
            height: widget.isInRow == true
                ? 70
                : (hasError
                    ? (widget.pass == true ? 150 : 74)
                    : 54), // Increased height for password errors with icon
            child: KeyboardActions(
              config: _buildConfig(context),
              child: textfield,
            ),
          )
        : widget.isInRow == true
            ? SizedBox(
                height:
                    82, // Compact height for row alignment with minimal space
                child: textfield,
              )
            : textfield; // Dynamic shrink only for single column fields
  }
}

/// Holds the controllers (+ existing contact_id) for one emergency-contact
/// row in the web-aligned Edit Tenant form.
class _EditEmergencyContactRow {
  String? contactId;
  final TextEditingController name = TextEditingController();
  final TextEditingController relation = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();

  _EditEmergencyContactRow({
    this.contactId,
    String name = '',
    String relation = '',
    String email = '',
    String phone = '',
  }) {
    this.name.text = name;
    this.relation.text = relation;
    this.email.text = email;
    this.phone.text = phone;
  }

  void dispose() {
    name.dispose();
    relation.dispose();
    email.dispose();
    phone.dispose();
  }
}
