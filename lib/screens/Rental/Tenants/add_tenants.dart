import 'package:three_zero_two_property/services/app_log.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:provider/provider.dart';
import '../../../provider/dateProvider.dart';

import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

// Kept for the commented-out legacy Tenant/EmergencyContact payload in
// addTenant() (the live Add path now builds a plain web-aligned Map).
// ignore: unused_import
import '../../../Model/tenants.dart';

import '../../../repository/tenants.dart';
import 'package:three_zero_two_property/repository/setting.dart';
import '../../../widgets/custom_drawer.dart';

class AddTenant extends StatefulWidget {
  @override
  State<AddTenant> createState() => _AddTenantState();
}

class _AddTenantState extends State<AddTenant> {
  final TextEditingController firstName = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController phoneNumber = TextEditingController();
  bool obsecure = true;
  bool hasPasswordError = false;
  final TextEditingController workNumber = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController alterEmail = TextEditingController();
  // OLD (removed from Add payload — server now generates the password):
  // final TextEditingController passWord = TextEditingController();
  final TextEditingController dob = TextEditingController();
  // OLD (removed from Add payload — SSN/TIN is not stored in the CRM):
  // final TextEditingController taxPayerId = TextEditingController();
  final TextEditingController comments = TextEditingController();
  // OLD single emergency-contact controllers — replaced by the dynamic
  // emergencyContactsList (web sends an emergency_contacts array). Kept
  // commented for future reference.
  // final TextEditingController contactName = TextEditingController();
  // final TextEditingController relationToTenant = TextEditingController();
  // final TextEditingController emergencyEmail = TextEditingController();
  // final TextEditingController emergencyPhoneNumber = TextEditingController();
  bool enableOverrideFee = false;
  bool enableACH = true;
  bool enableCard = true;
  final TextEditingController overrideFee = TextEditingController();

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  bool form_valid = false;

  // Pass-1 redesign (web parity): welcome-email toggle, dynamic
  // emergency contacts, and the read-only global debit fee line.
  bool sendWelcomeEmail = true;
  final List<_EmergencyContactRow> emergencyContactsList = [];
  // Owner's configured global debit fee (surcharge_percent_debit). Null until
  // loaded; WEB parity — the fee line + override UI stay hidden while null
  // (TenantFormFields.jsx `globalDebitFee != null` guard).
  String? globalDebitCardFee;
  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      // initialDate: DateTime.now(),
      // firstDate: DateTime(1900),
      // lastDate: DateTime(2101),
      initialDate: DateTime.now(),
      firstDate: DateTime(1900), // You can adjust this to your needs
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              // onSurface: Colors.blue, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(selectedDate);
        _dateController.text = dateProvider.formatCurrentDate(apiFormatDate);
      });
    }
  }

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
  void initState() {
    super.initState();
    overrideFee.addListener(_validateInput);
    _loadGlobalDebitFee();
  }

  // Fetch the owner's real global debit-card fee (surcharge_percent_debit) and
  // show it on the "Global debit card fee" line, replacing the placeholder.
  Future<void> _loadGlobalDebitFee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId') ?? '';
      final surcharges = await SurchargeRepository(baseUrl: '${Api_url}')
          .fetchSurchargeData(adminId);
      final fee = surcharges.surchargePercentDebit;
      if (!mounted) return;
      setState(() {
        globalDebitCardFee =
            fee == fee.roundToDouble() ? fee.toInt().toString() : fee.toString();
      });
    } catch (e) {
      logError('global debit fee fetch failed: $e');
    }
  }

  @override
  void dispose() {
    overrideFee.removeListener(_validateInput);
    overrideFee.dispose();
    for (final row in emergencyContactsList) {
      row.dispose();
    }
    super.dispose();
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
      body: Form(
        key: _formkey,
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
                    title: 'Add Tenant',
                  ),
                  const SizedBox(height: 20),
                  _personalInfoCard(),
                  const SizedBox(height: 16),
                  _accountSetupCard(),
                  const SizedBox(height: 16),
                  _notesCard(),
                  const SizedBox(height: 16),
                  _emergencyContactsCard(),
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

  // ---- Pass-1 redesign helpers (web-aligned Add Tenant form) -------------

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
        _fieldLabel('Date of Birth', required: true),
        _input(
          hint: 'YYYY-MM-DD',
          controller: _dateController,
          readOnly: true,
          label: 'enter date of birth',
          onTap: () => _selectDate(context),
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            color: mutedClr,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _accountSetupCard() {
    return _sectionCard(
      title: 'Account Setup',
      children: [
        _checkRow(
          value: sendWelcomeEmail,
          cross: CrossAxisAlignment.start,
          onChanged: (v) => setState(() => sendWelcomeEmail = v ?? false),
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email tenant a welcome email to set up their account',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: navyClr,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The tenant receives a one-time link (valid 4 hours) to set '
                'their own password. You can re-send or reset later from the '
                'tenant detail page.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: mutedClr,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _notesCard() {
    return _sectionCard(
      title: 'Notes',
      children: [
        Container(
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
        ),
      ],
    );
  }

  Widget _emergencyContactsCard() {
    return _sectionCard(
      title: 'Emergency Contacts',
      trailing: OutlinedButton.icon(
        onPressed: () {
          setState(() => emergencyContactsList.add(_EmergencyContactRow()));
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
        // WEB parity: the fee line + override controls render only when a real
        // global debit fee has loaded; hidden when none configured/fetch fails.
        if (globalDebitCardFee != null) ...[
        RichText(
          text: TextSpan(
            text: 'Global debit card fee: ',
            style: TextStyle(color: mutedClr, fontSize: 14),
            children: [
              TextSpan(
                text: '$globalDebitCardFee%',
                style: TextStyle(
                  color: navyClr,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _checkRow(
          value: enableOverrideFee,
          onChanged: (v) => setState(() => enableOverrideFee = v ?? false),
          label: Text(
            "Replace this tenant's debit card fee",
            style: TextStyle(fontSize: 15, color: navyClr),
          ),
        ),
        if (enableOverrideFee) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: _input(
              hint: '%',
              controller: overrideFee,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              optional: true,
              // Web parity: block non-numeric / out-of-0-100 at keystroke.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final t = newValue.text;
                  if (t.isEmpty || t == '.') return newValue;
                  if ('.'.allMatches(t).length > 1) return oldValue;
                  final v = double.tryParse(t);
                  if (v == null || v < 0 || v > 100) return oldValue;
                  return newValue;
                }),
              ],
            ),
          ),
          if (overRideFeeError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                overRideFeeError,
                style: TextStyle(color: redClr, fontSize: 11),
              ),
            ),
        ],
        ],
        const SizedBox(height: 16),
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
            onPressed: isLoading
                ? null
                : () async {
                    setState(() => formValid = true);
                    // The override-fee message is a plain string driven by a
                    // text listener, so Form.validate() never sees it: an
                    // invalid or never-typed percentage showed the red text
                    // and saved anyway. Re-run it here so a never-touched
                    // field is checked too, and let it block the save.
                    if (enableOverrideFee) _validateInput();
                    final feeOk = !enableOverrideFee || overRideFeeError.isEmpty;
                    if (_formkey.currentState!.validate() && feeOk) {
                      setState(() => formValid = false);
                      await addTenant();
                    }
                  },
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
                    child: SpinKitFadingCircle(
                      color: Colors.white,
                      size: 22,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.add, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Add Tenant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  bool isLoading = false;
  bool formValid = true;

  Future<void> addTenant() async {
    setState(() {
      isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String adminId = prefs.getString("adminId")!;
    String companyName = prefs.getString("companyName") ?? "";

    // Build the web-aligned emergency_contacts array from the dynamic list.
    // Skip fully-empty rows; new contacts carry no contact_id (server stamps).
    final List<Map<String, dynamic>> emergencyContacts = emergencyContactsList
        .where((c) =>
            c.name.text.trim().isNotEmpty ||
            c.relation.text.trim().isNotEmpty ||
            c.email.text.trim().isNotEmpty ||
            c.phone.text.trim().isNotEmpty)
        .map((c) => {
              "name": c.name.text.trim(),
              "relation": c.relation.text.trim(),
              "email": c.email.text.trim().toLowerCase(),
              "phoneNumber": formatPhoneNumberedit(c.phone.text.trim()),
            })
        .toList();

    // ===== OLD payload (pre web-alignment) — kept for future reference =====
    // EmergencyContact emergencyContact = EmergencyContact(
    //   name: contactName.text.trim(),
    //   relation: relationToTenant.text.trim(),
    //   email: emergencyEmail.text.trim(),
    //   phoneNumber: emergencyPhoneNumber.text.trim(),
    // );
    // double? overRideFee = double.tryParse(overrideFee.text.trim());
    // Tenant tenant = Tenant(
    //   adminId: adminId,
    //   tenantFirstName: firstName.text.trim(),
    //   tenantLastName: lastName.text.trim(),
    //   tenantPhoneNumber: phoneNumber.text.trim(),
    //   tenantAlternativeNumber: workNumber.text.trim(),
    //   tenantEmail: email.text.trim(),
    //   tenantAlternativeEmail: alterEmail.text.trim(),
    //   tenantPassword: passWord.text.trim(),   // removed: server generates password
    //   tenantBirthDate: _dateController.text.trim().isNotEmpty
    //       ? _convertToApiFormat(_dateController.text.trim())
    //       : "",
    //   taxPayerId: taxPayerId.text.trim(),     // removed: SSN/TIN not stored
    //   comments: comments.text.trim(),
    //   emergencyContact: emergencyContact,     // replaced by emergency_contacts[]
    //   enableoverrideFee: enableOverrideFee,
    //   overRideFee: overRideFee,
    //   allowAch: enableACH,
    //   allowCard: enableCard,
    // );
    // bool success = await TenantsRepository().addTenant(tenant);
    // =======================================================================

    // Web-aligned payload — mirrors the web POST /tenant/tenants body exactly:
    // no tenant_password / taxPayer_id, emergency_contacts as an array,
    // formatted phone numbers, override_fee as a string. The web-only flags
    // is_web / user_active_recently are intentionally NOT sent from mobile.
    final Map<String, dynamic> body = {
      "tenant_id": "",
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
      "send_welcome_email": sendWelcomeEmail,
      "emergency_contacts": emergencyContacts,
      "enable_override_fee": enableOverrideFee,
      "override_fee": enableOverrideFee ? overrideFee.text.trim() : "",
      "allow_ach": enableACH,
      "allow_card": enableCard,
      "admin_id": adminId,
      "company_name": companyName,
    };

    // [EC-DEBUG] Temporary diagnostic (remove later) — emergency payload ids.
    bool success = await TenantsRepository().addTenantPayload(body);

    setState(() {
      isLoading = false;
    });

    if (success) {
      Fluttertoast.showToast(msg: "Tenant added successfully");
      Navigator.of(context).pop(true);
    }
  }
}

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 0),
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
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFFb0b6c3)),
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

/// Holds the text controllers for one dynamic emergency-contact row
/// in the Add Tenant form (web-parity multi-contact list).
class _EmergencyContactRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController relation = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();

  void dispose() {
    name.dispose();
    relation.dispose();
    email.dispose();
    phone.dispose();
  }
}
