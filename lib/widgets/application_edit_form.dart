import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/application_edit_rules.dart';
import 'package:three_zero_two_property/services/zip_code.dart';

import 'clearable_date_picker.dart';
import 'clearable_date_suffix.dart';

/// Web-parity "Enter Applicant Details" form (Application tab edit/add).
///
/// Mirrors staging.cloudrentalmanager.com ApplicationTab: Personal
/// Information, Move In Date, Additional Residents, Address History,
/// Employment History, References, Vehicle Information, Emergency Contact,
/// Pets, Additional Information and Signature & Applicant Fee — each array
/// section with a +Add button. Builds the exact web payload and submits via
/// the injected [onSave] (POST /api/applicant/application/{id}).
///
/// Dates display in the app's [dateFormat] (DateProvider) and are converted
/// to yyyy-MM-dd for the payload (matching web / the other APIs).
class ApplicationEditForm extends StatefulWidget {
  final Map<String, dynamic> raw;
  final String applicantId;
  final String dateFormat;

  /// Posts the assembled payload; returns true on success.
  final Future<bool> Function(Map<String, dynamic> payload) onSave;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  /// Loads web's "Require date of birth" setting for Additional Residents;
  /// until it answers (or without it) the date is required, like web.
  final Future<bool> Function()? loadResidentDobRequired;

  const ApplicationEditForm({
    Key? key,
    required this.raw,
    required this.applicantId,
    required this.onSave,
    required this.onCancel,
    required this.onSaved,
    this.dateFormat = 'MM/dd/yyyy',
    this.loadResidentDobRequired,
  }) : super(key: key);

  @override
  State<ApplicationEditForm> createState() => _ApplicationEditFormState();
}

const Color _border = Color(0xFFDBE0E5);
const Color _divider = Color(0xFFEDEFF3);
const Color _hint = Color(0xFFB0B6C3);
const Color _err = Color(0xFFE2574C);

const List<String> _kStates = [
  'Alabama','Alaska','Arizona','Arkansas','California','Colorado','Connecticut',
  'Delaware','District of Columbia','Florida','Georgia','Hawaii','Idaho',
  'Illinois','Indiana','Iowa','Kansas','Kentucky','Louisiana','Maine','Maryland',
  'Massachusetts','Michigan','Minnesota','Mississippi','Missouri','Montana',
  'Nebraska','Nevada','New Hampshire','New Jersey','New Mexico','New York',
  'North Carolina','North Dakota','Ohio','Oklahoma','Oregon','Pennsylvania',
  'Rhode Island','South Carolina','South Dakota','Tennessee','Texas','Utah',
  'Vermont','Virginia','Washington','West Virginia','Wisconsin','Wyoming',
];
const List<String> _kFrequency = [
  'Hourly','Weekly','Bi-Weekly','Monthly','Annually'
];
// Matches the web "Select color" dropdown order.
const List<String> _kColors = [
  'Black','White','Gray','Silver','Blue','Green','Red','Brown','Tan','Beige',
  'Gold','Yellow','Orange','Purple','Pink','Maroon','Bronze','Copper',
  'Cream / Ivory',
];
const List<String> _kSex = ['Male', 'Female'];
const List<String> _kYesNo = ['Yes', 'No'];

/// One repeatable row: text fields + dropdown values + an optional flag
/// (is_current_address / is_current_employment).
class _Rep {
  final Map<String, TextEditingController> t;
  final Map<String, String?> d;
  bool flag;
  _Rep(List<String> textKeys, Map<String, String?> dropdowns,
      {this.flag = false})
      : t = {for (final k in textKeys) k: TextEditingController()},
        d = {...dropdowns};

  void fill(Map e) {
    t.forEach((k, c) => c.text = (e[k] ?? '').toString());
    for (final k in d.keys.toList()) {
      final v = (e[k] ?? '').toString();
      d[k] = v.isEmpty ? null : v;
    }
  }

  void dispose() {
    for (final c in t.values) c.dispose();
  }
}

class _ApplicationEditFormState extends State<ApplicationEditForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Web's "Please correct the red boxes above" line by Save.
  bool _showFixHint = false;
  bool _fixHintCheckQueued = false;

  // Like web's Formik: a box is checked once the user leaves it, and every
  // box once Save is pressed; from then on it follows each change. Typing
  // in one box no longer turns every other empty box red.
  final Set<TextEditingController> _touched = {};
  bool _submitted = false;

  // Web's "Require date of birth" for Additional Residents (unset = on).
  bool _residentDobRequired = true;

  // Personal Information
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _dlNumber = TextEditingController();
  final _currentAddress = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();
  final _cell = TextEditingController();
  final _birth = TextEditingController();
  final _moveIn = TextEditingController();
  final _agreeBy = TextEditingController();
  final _bankruptcyDate = TextEditingController();
  final _insuranceCompany = TextEditingController();
  String? _dlState;
  String? _state;

  // Additional Information radios
  String _hasBankruptcy = 'No';
  String _hasEviction = 'No';
  String _hasRefusedRent = 'No';
  String _hasRentersInsurance = 'No';

  // Repeatable sections
  final List<_Rep> _residents = [];
  final List<_Rep> _addresses = [];
  final List<_Rep> _employments = [];
  final List<_Rep> _references = [];
  final List<_Rep> _vehicles = [];
  final List<_Rep> _emergency = [];
  final List<_Rep> _pets = [];

  Map<String, dynamic> get _raw => widget.raw;
  String _s(String key) => (_raw[key] ?? '').toString();
  String get _df => widget.dateFormat.isEmpty ? 'MM/dd/yyyy' : widget.dateFormat;

  // --------------------------------------------------------------- date i/o

  /// API/raw date -> provider-format string for display.
  String _toDisplay(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    const inFmts = ['yyyy-MM-dd', 'yyyy-MMM-dd', 'yyyy-M-d', 'MM/dd/yyyy',
      'M/d/yyyy', 'dd-MM-yyyy'];
    for (final f in inFmts) {
      try {
        return DateFormat(_df).format(DateFormat(f).parseStrict(s));
      } catch (_) {}
    }
    final p = DateTime.tryParse(s);
    return p != null ? DateFormat(_df).format(p) : s;
  }

  /// Provider-format display string -> yyyy-MM-dd for the payload.
  String _toApi(String display) {
    final s = display.trim();
    if (s.isEmpty) return '';
    try {
      return DateFormat('yyyy-MM-dd').format(DateFormat(_df).parseStrict(s));
    } catch (_) {}
    const fb = ['MM/dd/yyyy', 'M/d/yyyy', 'yyyy-MM-dd', 'dd-MM-yyyy'];
    for (final f in fb) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateFormat(f).parseStrict(s));
      } catch (_) {}
    }
    final p = DateTime.tryParse(s);
    return p != null ? DateFormat('yyyy-MM-dd').format(p) : s;
  }

  @override
  void initState() {
    super.initState();
    _first.text = _s('applicant_firstName');
    _last.text = _s('applicant_lastName');
    _email.text = _s('applicant_email');
    _dlNumber.text = _s('driver_license');
    _currentAddress.text = _s('current_address').isNotEmpty
        ? _s('current_address')
        : _s('applicant_streetAddress');
    _city.text = _s('applicant_city');
    _zip.text = _s('applicant_postalCode');
    _cell.text = _s('applicant_phoneNumber');
    _birth.text = _toDisplay(_s('applicant_birthDate'));
    _moveIn.text = _toDisplay(_s('move_in_date'));
    _agreeBy.text =
        _s('agreeBy').isNotEmpty ? _s('agreeBy') : _s('printed_name');
    _dlState = _opt(_s('state'), _kStates);
    _state = _opt(_s('applicant_state'), _kStates);

    _hasBankruptcy = _s('has_bankruptcy').isEmpty ? 'No' : _s('has_bankruptcy');
    _bankruptcyDate.text = _toDisplay(_s('bankruptcy_date'));
    _hasEviction = _s('has_eviction').isEmpty ? 'No' : _s('has_eviction');
    _hasRefusedRent =
        _s('has_refused_rent').isEmpty ? 'No' : _s('has_refused_rent');
    _hasRentersInsurance =
        _s('has_renters_insurance').isEmpty ? 'No' : _s('has_renters_insurance');
    _insuranceCompany.text = _s('renters_insurance_company');

    // Like web: no empty resident row to start with; "+ Add Resident" adds
    // one, and every row there must be filled in or removed.
    _initList(_residents, 'additional_residents', ['name', 'relation', 'dob'],
        {'child_id': null},
        dateKeys: ['dob'],
        seedBlankRow: false);
    widget.loadResidentDobRequired?.call().then((required) {
      if (mounted && required != _residentDobRequired) {
        setState(() => _residentDobRequired = required);
      }
    }).catchError((_) {});
    _initList(
        _addresses,
        'address_history',
        ['street', 'city', 'zip', 'from_date', 'to_date', 'monthly_payment',
          'landlord', 'landlord_phone'],
        {'state': null},
        flagKey: 'is_current_address',
        firstFlag: true,
        dateKeys: ['from_date', 'to_date'],
        moneyKeys: ['monthly_payment']);
    _initList(
        _employments,
        'employment_history',
        ['employer', 'from_date', 'to_date', 'hr_contact', 'salary'],
        {'resident_id': 'primary', 'salary_frequency': null},
        flagKey: 'is_current_employment',
        firstFlag: true,
        dateKeys: ['from_date', 'to_date'],
        moneyKeys: ['salary']);
    _initList(
        _references,
        'personal_references',
        ['name', 'phone', 'email', 'years_acquainted', 'address', 'city', 'zip'],
        {'state': null});
    _initList(_vehicles, 'vehicles', ['make_model', 'year', 'license_plate'],
        {'color': null, 'state': null});
    // Emergency: the stored `emergency_contacts` array can be partial
    // (name+email) while the singular `emergency_contact` holds the full
    // record — merge the singular into the first entry so relationship/phone
    // aren't lost on re-save.
    const ecKeys = ['name', 'relationship', 'email', 'phone_number'];
    final ecSingle = _raw['emergency_contact'] is Map
        ? Map<String, dynamic>.from(_raw['emergency_contact'] as Map)
        : <String, dynamic>{};
    final ecArray = (_raw['emergency_contacts'] is List)
        ? (_raw['emergency_contacts'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    if (ecArray.isEmpty && ecSingle.isNotEmpty) ecArray.add(ecSingle);
    if (ecArray.isEmpty) {
      _emergency.add(_Rep(ecKeys, {}));
    } else {
      for (int i = 0; i < ecArray.length; i++) {
        final e = ecArray[i];
        if (i == 0) {
          for (final k in ecKeys) {
            if ((e[k] ?? '').toString().trim().isEmpty &&
                (ecSingle[k] ?? '').toString().trim().isNotEmpty) {
              e[k] = ecSingle[k];
            }
          }
        }
        final r = _Rep(ecKeys, {});
        r.fill(e);
        _emergency.add(r);
      }
    }
    _initList(
        _pets,
        'pets',
        ['type', 'breed', 'color', 'weight', 'age'],
        {'sex': null, 'neutered': null, 'declawed': null});
  }

  String? _opt(String v, List<String> options) =>
      options.contains(v) ? v : null;

  /// Strips currency formatting ($, commas, spaces) from a pre-filled money
  /// value so the field shows a bare number (the UI draws its own "$" prefix).
  String _cleanMoney(String v) {
    final s = v.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    return s.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  void _initList(List<_Rep> target, String key, List<String> textKeys,
      Map<String, String?> dropdowns,
      {String? flagKey,
      bool firstFlag = false,
      List<String> dateKeys = const [],
      List<String> moneyKeys = const [],
      bool seedBlankRow = true}) {
    final data = _raw[key];
    final entries = (data is List) ? data.whereType<Map>().toList() : const [];
    if (entries.isEmpty) {
      if (!seedBlankRow) return;
      final r = _Rep(textKeys, dropdowns, flag: firstFlag);
      _normalizeDropdowns(r);
      target.add(r);
      return;
    }
    for (int i = 0; i < entries.length; i++) {
      final r = _Rep(textKeys, dropdowns);
      r.fill(entries[i]);
      for (final dk in dateKeys) {
        if (r.t.containsKey(dk)) r.t[dk]!.text = _toDisplay(r.t[dk]!.text);
      }
      for (final mk in moneyKeys) {
        if (r.t.containsKey(mk)) r.t[mk]!.text = _cleanMoney(r.t[mk]!.text);
      }
      if (flagKey != null) {
        final fv = (entries[i][flagKey] ?? '').toString().toLowerCase();
        r.flag = fv == 'true' || fv == '1' || entries[i][flagKey] == true;
      }
      _normalizeDropdowns(r);
      target.add(r);
    }
  }

  // Ensure prefilled dropdown values are valid options (else null -> hint).
  void _normalizeDropdowns(_Rep r) {
    if (r.d.containsKey('state')) r.d['state'] = _opt(r.d['state'] ?? '', _kStates);
    if (r.d.containsKey('color')) r.d['color'] = _opt(r.d['color'] ?? '', _kColors);
    if (r.d.containsKey('salary_frequency')) {
      r.d['salary_frequency'] = _opt(r.d['salary_frequency'] ?? '', _kFrequency);
    }
    if (r.d.containsKey('sex')) r.d['sex'] = _opt(r.d['sex'] ?? '', _kSex);
    if (r.d.containsKey('neutered')) r.d['neutered'] = _opt(r.d['neutered'] ?? '', _kYesNo);
    if (r.d.containsKey('declawed')) r.d['declawed'] = _opt(r.d['declawed'] ?? '', _kYesNo);
  }

  @override
  void dispose() {
    for (final c in [
      _first, _last, _email, _dlNumber, _currentAddress, _city, _zip, _cell,
      _birth, _moveIn, _agreeBy, _bankruptcyDate, _insuranceCompany
    ]) {
      c.dispose();
    }
    for (final list in [
      _residents, _addresses, _employments, _references, _vehicles,
      _emergency, _pets
    ]) {
      for (final r in list) r.dispose();
    }
    super.dispose();
  }

  // ----------------------------------------------------------- validators

  String? _reqV(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  String? _emailV(String? v, {bool required = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return required ? 'Please enter email' : null;
    return EmailValidator.validate(t) ? null : 'Enter a valid email';
  }

  String? _phoneV(String? v, {bool required = false}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return required ? 'Please enter phone number' : null;
    return t.replaceAll(RegExp(r'\D'), '').length == 10
        ? null
        : 'Phone number must be 10 digits';
  }

  // Like web: 12345 or 12345-6789 (not 00000), marked with a red box.
  String? _zipV(String? v, {bool required = false}) =>
      _redBox(applicationZipError(v ?? '', required: required));

  /// Web marks every text box and dropdown, Move In Date and a resident's
  /// Date of Birth with a red box only, no message under it.
  static String? _redBox(String? webError) => webError == null ? null : '';

  /// Today, for the date limits (web uses the current day too).
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String? _numV(String? v, {bool required = false, String label = 'amount'}) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return required ? 'Please enter $label' : null;
    // Strip currency formatting ($, commas, spaces) before parsing so a
    // pre-filled value like "$ 5,000" still validates as a number.
    final cleaned = t.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) != null
        ? null
        : 'Enter a valid $label';
  }

  // ----------------------------------------------------------- payload build

  String _t(_Rep r, String k) => r.t[k]?.text.trim() ?? '';
  String _dt(_Rep r, String k) => _toApi(r.t[k]?.text ?? '');
  String _d(_Rep r, String k) => (r.d[k] ?? '').toString();

  Map<String, dynamic> _buildPayload() {
    final residents = _residents
        .map((r) => {
              'name': _t(r, 'name'),
              'relation': _t(r, 'relation'),
              'dob': _dt(r, 'dob'),
              'email': '',
              'phoneNumber': '',
              'child_id': r.d['child_id'],
            })
        .toList();

    final addresses = _addresses
        .map((r) => {
              'street': _t(r, 'street'),
              'city': _t(r, 'city'),
              'state': _d(r, 'state'),
              'zip': _t(r, 'zip'),
              'from_date': _dt(r, 'from_date'),
              'to_date': r.flag ? '' : _dt(r, 'to_date'),
              'monthly_payment': _t(r, 'monthly_payment'),
              'landlord': _t(r, 'landlord'),
              'landlord_phone': _t(r, 'landlord_phone'),
              'is_current_address': r.flag,
            })
        .toList();

    final employments = <Map<String, dynamic>>[];
    for (int i = 0; i < _employments.length; i++) {
      final r = _employments[i];
      // Only the first job can be the current one (web behavior).
      final isCurrent = i == 0 && r.flag;
      employments.add({
        'resident_id':
            _d(r, 'resident_id').isEmpty ? 'primary' : _d(r, 'resident_id'),
        'is_current_employment': isCurrent,
        'salary_frequency': _d(r, 'salary_frequency'),
        'employer': _t(r, 'employer'),
        'from_date': _dt(r, 'from_date'),
        'to_date': isCurrent ? '' : _dt(r, 'to_date'),
        'hr_contact': _t(r, 'hr_contact'),
        'salary': _t(r, 'salary'),
      });
    }

    final references = _references
        .map((r) => {
              'name': _t(r, 'name'),
              'phone': _t(r, 'phone'),
              'email': _t(r, 'email'),
              'address': _t(r, 'address'),
              'years_acquainted': _t(r, 'years_acquainted'),
              // Web parity: reference 'city' is shown in the UI but NOT sent
              // in the request body (web doesn't persist it).
              'state': _d(r, 'state'),
              'zip': _t(r, 'zip'),
            })
        .toList();

    final vehicles = _vehicles
        .map((r) => {
              'make_model': _t(r, 'make_model'),
              'year': _t(r, 'year'),
              'color': _d(r, 'color'),
              'license_plate': _t(r, 'license_plate'),
              'state': _d(r, 'state'),
            })
        .toList();

    final pets = _pets
        .map((r) => {
              'type': _t(r, 'type'),
              'breed': _t(r, 'breed'),
              'color': _t(r, 'color'),
              'weight': _t(r, 'weight'),
              'age': _t(r, 'age'),
              'sex': _d(r, 'sex'),
              'neutered': _d(r, 'neutered'),
              'declawed': _d(r, 'declawed'),
            })
        .toList();

    final emergencyContacts = _emergency
        .map((r) => {
              'name': _t(r, 'name'),
              'relationship': _t(r, 'relationship'),
              'email': _t(r, 'email'),
              'phone_number': _t(r, 'phone_number'),
            })
        .toList();

    final firstEmergency = emergencyContacts.isNotEmpty
        ? emergencyContacts.first
        : {'name': '', 'relationship': '', 'email': '', 'phone_number': ''};

    bool rawBool(String k) => _raw[k] == true;

    return {
      'applicant_id': widget.applicantId,
      'admin_id': _s('admin_id'),
      'applicant_firstName': _first.text.trim(),
      'applicant_lastName': _last.text.trim(),
      'applicant_email': _email.text.trim(),
      'applicant_phoneNumber': _cell.text.trim(),
      'applicant_birthDate': _toApi(_birth.text),
      'applicant_streetAddress': _currentAddress.text.trim(),
      'current_address': _currentAddress.text.trim(),
      'applicant_city': _city.text.trim(),
      'applicant_state': _state ?? '',
      'applicant_country': _s('applicant_country'),
      'applicant_postalCode': _zip.text.trim(),
      'driver_license': _dlNumber.text.trim(),
      'state': _dlState ?? '',
      'move_in_date': _toApi(_moveIn.text),
      'additional_residents': residents,
      'address_history': addresses,
      'employment_history': employments,
      'personal_references': references,
      'vehicles': vehicles,
      'pets': pets,
      'emergency_contacts': emergencyContacts,
      'emergency_contact': firstEmergency,
      'employment': _raw['employment'] is Map
          ? _raw['employment']
          : {
              'name': '', 'streetAddress': '', 'city': '', 'state': '',
              'country': '', 'postalCode': '', 'employment_primaryEmail': '',
              'employment_phoneNumber': '', 'employment_position': '',
              'supervisor_firstName': '', 'supervisor_lastName': '',
              'supervisor_title': ''
            },
      'has_bankruptcy': _hasBankruptcy,
      'bankruptcy_date': _hasBankruptcy == 'Yes' ? _toApi(_bankruptcyDate.text) : '',
      'has_eviction': _hasEviction,
      'has_refused_rent': _hasRefusedRent,
      'has_renters_insurance': _hasRentersInsurance,
      'renters_insurance_company':
          _hasRentersInsurance == 'Yes' ? _insuranceCompany.text.trim() : '',
      'agreeBy': _agreeBy.text.trim(),
      'printed_name': _agreeBy.text.trim(),
      'signatureDataUrl': _s('signatureDataUrl'),
      'agreeto': rawBool('agreeto'),
      'draft_saved': rawBool('draft_saved'),
      'form_submitted': rawBool('form_submitted'),
      'application_certification': rawBool('application_certification'),
      'consumer_report_consent': rawBool('consumer_report_consent'),
      'information_use_consent': rawBool('information_use_consent'),
      'release_authorization': rawBool('release_authorization'),
      'has_registered': rawBool('has_registered'),
      'is_invited': rawBool('is_invited'),
      'is_password_changed': rawBool('is_password_changed'),
      'payment_made': rawBool('payment_made'),
      'sms_consent_opt_in': rawBool('sms_consent_opt_in'),
      'isMovedin': rawBool('isMovedin'),
      'is_delete': rawBool('is_delete'),
      'isApplicantDataEmpty': _raw['isApplicantDataEmpty'] ?? false,
      'is_web': true,
      'user_active_recently': true,
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      // Like web: the wrong boxes turn red and "Please correct the red boxes
      // above" shows by Save.
      setState(() {
        _submitted = true;
        _showFixHint = true;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final ok = await widget.onSave(_buildPayload());
      if (!mounted) return;
      setState(() => _saving = false);
      if (ok) widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      Fluttertoast.showToast(msg: 'Failed to save application');
    }
  }

  /// Like web's hasFormErrors: "Please correct the red boxes above" shows
  /// while any box on the form is marked wrong, and goes once they're fixed.
  void _queueFixHintCheck() {
    if (_fixHintCheckQueued) return;
    _fixHintCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fixHintCheckQueued = false;
      if (!mounted) return;
      final show = _anyBoxMarkedWrong();
      if (show != _showFixHint) setState(() => _showFixHint = show);
    });
  }

  bool _anyBoxMarkedWrong() {
    var found = false;
    void visit(Element e) {
      if (found) return;
      if (e is StatefulElement &&
          e.state is FormFieldState &&
          (e.state as FormFieldState).hasError) {
        found = true;
        return;
      }
      e.visitChildren(visit);
    }

    _formKey.currentContext?.visitChildElements(visit);
    return found;
  }

  /// When a box shows whether it's right: after the user leaves it or after
  /// Save, like web.
  AutovalidateMode _autoFor(TextEditingController c) =>
      _submitted || _touched.contains(c)
          ? AutovalidateMode.always
          : AutovalidateMode.disabled;

  /// The user left [c] (or closed its calendar), like web's blur.
  void _touch(TextEditingController c) {
    if (!mounted) return;
    if (_touched.add(c)) setState(() {});
    _queueFixHintCheck();
  }

  // ------------------------------------------------------------- UI builders

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
              color: blueColor, fontSize: 13, fontWeight: FontWeight.bold),
          children: required
              ? const [TextSpan(text: ' *', style: TextStyle(color: _err))]
              : const [],
        ),
      ),
    );
  }

  /// For boxes web marks with a red border only: the box turns red with no
  /// message (and no empty line) under it.
  static Widget _noMessage(BuildContext context, String errorText) =>
      const SizedBox.shrink();

  InputDecoration _dec(String hint, {Widget? prefix}) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c));
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hint, fontSize: 13),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 0),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: b(_border),
      focusedBorder: b(blueColor),
      border: b(_border),
      errorBorder: b(_err),
      focusedErrorBorder: b(_err),
      errorStyle: const TextStyle(color: _err, fontSize: 12),
    );
  }

  Widget _text(String label, TextEditingController c,
      {String hint = '',
      bool required = false,
      TextInputType keyboard = TextInputType.text,
      Widget? prefix,
      List<TextInputFormatter>? formatters,
      bool autocorrect = true,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          // Like web: the box turns red once the user leaves it (or after
          // Save), with no message under it.
          Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (hasFocus) {
              if (!hasFocus) _touch(c);
            },
            child: TextFormField(
              controller: c,
              keyboardType: keyboard,
              inputFormatters: formatters,
              autocorrect: autocorrect,
              enableSuggestions: autocorrect,
              style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3A)),
              decoration: _dec(hint, prefix: prefix),
              autovalidateMode: _autoFor(c),
              errorBuilder: _noMessage,
              validator: validator ??
                  (required
                      ? (v) => _reqV(v, 'Please enter ${label.toLowerCase()}')
                      : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneField(String label, TextEditingController c,
      {bool required = false}) {
    return _text(label, c,
        hint: 'Enter phone number',
        required: required,
        keyboard: TextInputType.phone,
        formatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
          PhoneNumberFormatter(),
        ],
        validator: (v) => _phoneV(v, required: required));
  }

  Widget _emailField(String label, TextEditingController c,
      {bool required = false, String hint = 'Enter email'}) {
    return _text(label, c,
        hint: hint,
        required: required,
        keyboard: TextInputType.emailAddress,
        validator: (v) => _emailV(v, required: required));
  }

  /// Like web: the applicant's and References' boxes take 5 digits; Address
  /// History ([plus4]) also takes ZIP+4, with the dash added (12345-6789).
  Widget _zipField(String label, TextEditingController c,
      {bool required = false, bool plus4 = false}) {
    return _text(label, c,
        hint: 'Zip Code',
        required: required,
        keyboard: TextInputType.number,
        formatters: plus4 ? [zipCodeFormatter] : fiveDigitZipFormatters(),
        validator: (v) => _zipV(v, required: required));
  }

  Widget _money(String label, TextEditingController c,
      {bool required = false, String? Function(String?)? validator}) {
    return _text(label, c,
        hint: '0',
        required: required,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        validator: validator ?? (v) =>
            _numV(v, required: required, label: 'amount'),
        prefix: const Padding(
          padding: EdgeInsets.only(left: 12, right: 2),
          child: Text('\$',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 15)),
        ));
  }

  Widget _numberField(String label, TextEditingController c,
      {String hint = ''}) {
    return _text(label, c,
        hint: hint,
        keyboard: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly]);
  }

  /// [clearable] opts a date field out of the "Clear" affordance without
  /// changing its validation — used for fields the web schema hard-requires
  /// (e.g. move_in_date) that this form does not locally mark `required`.
  /// [firstDate] / [lastDate] limit the calendar like web's minDate/maxDate.
  Widget _date(String label, TextEditingController c,
      {bool required = false,
      bool clearable = true,
      DateTime? firstDate,
      DateTime? lastDate,
      bool redBoxOnly = false,
      String? Function(String?)? validator}) {
    final bool offerClear = clearable && !required;
    final DateTime first = firstDate ?? DateTime(1900);
    final DateTime last = lastDate ?? DateTime(2100);

    DateTime initialFor(TextEditingController ctl) {
      if (ctl.text.trim().isNotEmpty) {
        try {
          return DateFormat(_df).parseStrict(ctl.text.trim());
        } catch (_) {}
      }
      return DateTime.now();
    }

    Future<void> pick() async {
      // A saved date outside the limits (e.g. a Move In Date that has
      // passed) opens the calendar at the nearest allowed day.
      DateTime initial = initialFor(c);
      if (initial.isBefore(first)) initial = first;
      if (initial.isAfter(last)) initial = last;
      if (!offerClear) {
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          // Match the app's standard date picker theme (navy).
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              primaryColor: blueColor,
              colorScheme: ColorScheme.light(primary: blueColor),
              buttonTheme: const ButtonThemeData(
                textTheme: ButtonTextTheme.primary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          setState(() => c.text = DateFormat(_df).format(picked));
        }
        return;
      }
      // Optional date -> offer Clear, matching the browser-native date input
      // on web (QA: mobile had no way to unset a picked date).
      final res = await showClearableDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        helpText: label,
      );
      if (res == null) return; // cancelled -> keep the old value
      setState(() {
        c.text = res.cleared ? '' : DateFormat(_df).format(res.date!);
      });
    }

    // Like web's blur: once the calendar closes, the box shows whether it's
    // right.
    Future<void> pickAndTouch() async {
      await pick();
      _touch(c);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          TextFormField(
            controller: c,
            readOnly: true,
            autovalidateMode: _autoFor(c),
            style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3A)),
            errorBuilder: redBoxOnly ? _noMessage : null,
            decoration: _dec(_df.toUpperCase()).copyWith(
              suffixIcon: offerClear
                  ? ClearableDateSuffix(
                      controller: c,
                      onPick: pickAndTouch,
                      onClear: () {
                        setState(c.clear);
                        _touch(c);
                      },
                      iconColor: const Color(0xFF8A95A8),
                    )
                  : const Icon(Icons.calendar_today_outlined,
                      size: 18, color: Color(0xFF8A95A8)),
            ),
            validator: validator ??
                (required
                    ? (v) => _reqV(v, 'Please pick ${label.toLowerCase()}')
                    : null),
            onTap: pickAndTouch,
          ),
        ],
      ),
    );//
  }

  Widget _dropdown(String label, String? value, List<String> options,
      ValueChanged<String?> onChanged,
      {bool required = false,
      String hint = 'Select',
      String? Function(String?)? validator}) {
    final safe = options.contains(value) ? value : null;
    final String? Function(String?)? check = validator ??
        (required ? (v) => (v == null || v.isEmpty) ? '' : null : null);
    final red = OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _err));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          // Like web: a wrong picker gets a red outline only, with no message
          // (and no empty line) under it, and only after Save (web's pickers
          // have no blur check). The check sits on this FormField, so Save is
          // still blocked.
          FormField<String>(
            validator: check == null ? null : (_) => check(safe),
            autovalidateMode: _submitted
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            builder: (field) => DropdownButtonFormField2<String>(
              value: safe,
              isExpanded: true,
              hint: Text(hint, style: const TextStyle(color: _hint, fontSize: 13)),
              style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3A)),
              decoration: field.hasError
                  ? _dec(hint).copyWith(enabledBorder: red, focusedBorder: red)
                  : _dec(hint),
              iconStyleData: const IconStyleData(
                icon: Icon(Icons.keyboard_arrow_down),
                iconEnabledColor: Color(0xFF8A95A8),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(color: _border),
                ),
                offset: const Offset(0, -4),
                scrollbarTheme: ScrollbarThemeData(
                  radius: const Radius.circular(6),
                  thickness: MaterialStateProperty.all(6),
                  thumbVisibility: MaterialStateProperty.all(true),
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                  height: 44, padding: EdgeInsets.symmetric(horizontal: 14)),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// Resident dropdown (primary applicant + named residents).
  Widget _checkRow(String label, bool value, ValueChanged<bool> onChanged,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                activeColor: blueColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: blueColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// Read-only / disabled field (greyed) — matches web's non-editable fields
  /// (Resident, Agreed by). Shows the value but the user can't change it.
  Widget _disabledField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF8A95A8)),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves an employment row's resident_id to a display name
  String _residentDisplayName(_Rep r) {
    final id = (r.d['resident_id'] ?? 'primary').toString();
    if (id == 'primary') {
      final n = '${_first.text.trim()} ${_last.text.trim()}'.trim();
      return n.isEmpty ? 'Primary Applicant' : n;
    }
    if (id.startsWith('resident_')) {
      final idx = int.tryParse(id.substring('resident_'.length));
      if (idx != null && idx >= 0 && idx < _residents.length) {
        final nm = _residents[idx].t['name']?.text.trim() ?? '';
        if (nm.isNotEmpty) return nm;
      }
    }
    return id;
  }

  Widget _yesNo(String question, String value, ValueChanged<String> onChanged,
      {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: question,
              style: const TextStyle(
                  color: Color(0xFF44505F),
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              children: required
                  ? const [TextSpan(text: ' *', style: TextStyle(color: _err))]
                  : const [],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final opt in _kYesNo)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChanged(opt),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(
                          value: opt,
                          groupValue: value,
                          onChanged: (v) => onChanged(v ?? opt),
                          activeColor: blueColor,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        Text(opt,
                            style: const TextStyle(
                                color: Color(0xFF44505F), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {VoidCallback? onAdd, String addLabel = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: blueColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ),
          if (onAdd != null)
            GestureDetector(
              onTap: onAdd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_box, color: blueColor, size: 18),
                  const SizedBox(width: 5),
                  Text(addLabel,
                      style: TextStyle(
                          color: blueColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _entryLabel(String text, {VoidCallback? onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: blueColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.delete_outline, size: 18, color: _err),
            ),
        ],
      ),
    );
  }

  Widget _sectionDivider() => Container(
      height: 1,
      color: _divider,
      margin: const EdgeInsets.symmetric(vertical: 18));

  // -------------------------------------------------------------- sections

  Widget _personalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Personal Information'),
        // Like web: names take letters and spaces (Last Name hyphens too); a
        // typed or pasted number or symbol is ignored. No autocorrect on these
        // boxes, so iPhone can't swap a word for one with an apostrophe
        // ("Plano's") and lose the space typed after it.
        _text('First Name', _first,
            hint: 'Enter first name',
            required: true,
            formatters: [lettersAndSpacesFormatter],
            autocorrect: false),
        _text('Last Name', _last,
            hint: 'Enter last name',
            required: true,
            formatters: [lastNameFormatter],
            autocorrect: false),
        _emailField('Email', _email, required: true),
        _dropdown("Driver's License State", _dlState, _kStates,
            (v) => setState(() => _dlState = v),
            required: true, hint: 'Select state'),
        // Like web: letters, numbers and dashes; 5 to 20 characters. No
        // autocorrect, so iPhone can't change "ab" to "an" (web's box
        // keeps what you type).
        _text("Driver's License Number", _dlNumber,
            hint: "Enter driver's license number",
            required: true,
            formatters: [driverLicenseFormatter],
            autocorrect: false,
            validator: (v) => _redBox(driverLicenseError(v ?? ''))),
        _text('Current Address', _currentAddress,
            hint: 'Enter current address', required: true),
        _text('City', _city,
            hint: 'Enter city',
            required: true,
            formatters: [lettersAndSpacesFormatter],
            autocorrect: false),
        _dropdown('State', _state, _kStates, (v) => setState(() => _state = v),
            required: true, hint: 'Select state'),
        _zipField('Zip Code', _zip, required: true),
        _phoneField('Cell Phone Number', _cell, required: true),
        // Like web: the calendar stops 18 years ago, and web's message shows
        // under the box.
        _date('Applicant Birth Date', _birth,
            required: true,
            lastDate: latestApplicantBirthDate(_today),
            validator: (v) => applicantBirthDateError(v ?? '', _df, _today)),
      ],
    );
  }

  Widget _residentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Additional Residents',
            addLabel: 'Add Resident',
            onAdd: () => setState(() =>
                _residents.add(_Rep(['name', 'relation', 'dob'], {'child_id': null})))),
        // Like web: every row can be removed, the last one too, and Name,
        // Relation and (unless the setting turns it off) Date of Birth are
        // required on each, marked with a red box.
        for (int i = 0; i < _residents.length; i++) ...[
          _entryLabel('Resident ${i + 1}',
              onRemove: () => setState(() {
                    _residents[i].dispose();
                    _residents.removeAt(i);
                  })),
          _text('Name', _residents[i].t['name']!,
              hint: 'Enter full name',
              required: true,
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false,
              validator: (v) => _redBox(residentNameError(v ?? ''))),
          _text('Relation', _residents[i].t['relation']!,
              hint: 'Enter relationship',
              required: true,
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false,
              validator: (v) => _redBox(residentRelationError(v ?? ''))),
          // Like web: no future dates; residents can be minors.
          _date('Date of Birth', _residents[i].t['dob']!,
              required: _residentDobRequired,
              lastDate: _today,
              redBoxOnly: true,
              validator: (v) => _redBox(residentBirthDateError(
                  v ?? '', _df, _today,
                  required: _residentDobRequired))),
        ],
      ],
    );
  }

  Widget _addressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Address History',
            addLabel: 'Add Address',
            onAdd: () => setState(() => _addresses.add(_Rep([
                  'street', 'city', 'zip', 'from_date', 'to_date',
                  'monthly_payment', 'landlord', 'landlord_phone'
                ], {'state': null})))),
        for (int i = 0; i < _addresses.length; i++) ...[
          _entryLabel(_addresses[i].flag ? 'Current Address' : 'Address ${i + 1}',
              onRemove: _addresses.length > 1
                  ? () => setState(() {
                        _addresses[i].dispose();
                        _addresses.removeAt(i);
                      })
                  : null),
          _checkRow('Current Address', _addresses[i].flag,
              (v) => setState(() => _addresses[i].flag = v)),
          _text('Street Address', _addresses[i].t['street']!,
              hint: 'Enter full street address'),
          _text('City', _addresses[i].t['city']!,
              hint: 'City',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _dropdown('State', _addresses[i].d['state'], _kStates,
              (v) => setState(() => _addresses[i].d['state'] = v),
              hint: 'Select state'),
          _zipField('Zip Code', _addresses[i].t['zip']!, plus4: true),
          _date('Start Date', _addresses[i].t['from_date']!),
          if (!_addresses[i].flag) _date('To Date', _addresses[i].t['to_date']!),
          _money('Monthly Rent/Mortgage', _addresses[i].t['monthly_payment']!),
          _text('Landlord Name', _addresses[i].t['landlord']!,
              hint: 'Enter landlord name',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _phoneField('Landlord Phone Number', _addresses[i].t['landlord_phone']!),
        ],
      ],
    );
  }

  Widget _employmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Employment History',
            addLabel: 'Add Employment',
            onAdd: () => setState(() => _employments.add(_Rep(
                  ['employer', 'from_date', 'to_date', 'hr_contact', 'salary'],
                  {'resident_id': 'primary', 'salary_frequency': null},
                )))),
        for (int i = 0; i < _employments.length; i++) ...[
          // Web parity: only the first job carries the "Current Employment"
          // checkbox; every additional job is a "Previous Employment #N".
          if (i == 0)
            // Web parity: "Current Employment" is disabled (the first job is
            // always current; user can't toggle it).
            _checkRow('Current Employment', _employments[0].flag,
                (v) {}, enabled: false)
          else
            _entryLabel('Previous Employment #$i',
                onRemove: () => setState(() {
                      _employments[i].dispose();
                      _employments.removeAt(i);
                    })),
          // Web parity: Resident is display-only (not editable).
          _disabledField('Resident', _residentDisplayName(_employments[i])),
          _text('Employer Name', _employments[i].t['employer']!,
              hint: 'Enter employer',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _date('From Date', _employments[i].t['from_date']!),
          if (i > 0 || !_employments[i].flag)
            _date('To Date', _employments[i].t['to_date']!),
          _phoneField('HR Contact Phone', _employments[i].t['hr_contact']!),
          _money('Salary', _employments[i].t['salary']!),
          _dropdown('Frequency', _employments[i].d['salary_frequency'],
              _kFrequency,
              (v) => setState(() => _employments[i].d['salary_frequency'] = v),
              hint: 'Select'),
        ],
      ],
    );
  }

  Widget _referencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('References',
            addLabel: 'Add Reference',
            onAdd: () => setState(() => _references.add(_Rep([
                  'name', 'phone', 'email', 'years_acquainted', 'address',
                  'city', 'zip'
                ], {'state': null})))),
        for (int i = 0; i < _references.length; i++) ...[
          _entryLabel('Personal Reference #${i + 1}',
              onRemove: _references.length > 1
                  ? () => setState(() {
                        _references[i].dispose();
                        _references.removeAt(i);
                      })
                  : null),
          _text('Name', _references[i].t['name']!,
              hint: 'Enter full name',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _phoneField('Phone Number', _references[i].t['phone']!),
          _emailField('Email Address', _references[i].t['email']!,
              hint: 'Enter email address'),
          _numberField('Years Acquainted', _references[i].t['years_acquainted']!,
              hint: 'Enter number of years'),
          _text('Address', _references[i].t['address']!,
              hint: 'Enter full street address'),
          _text('City', _references[i].t['city']!,
              hint: 'City',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _dropdown('State', _references[i].d['state'], _kStates,
              (v) => setState(() => _references[i].d['state'] = v),
              hint: 'Select state'),
          _zipField('Zip Code', _references[i].t['zip']!),
        ],
      ],
    );
  }

  Widget _vehicleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Vehicle Information',
            addLabel: 'Add Vehicle',
            onAdd: () => setState(() => _vehicles.add(_Rep(
                  ['make_model', 'year', 'license_plate'],
                  {'color': null, 'state': null})))),
        for (int i = 0; i < _vehicles.length; i++) ...[
          if (_vehicles.length > 1)
            _entryLabel('Vehicle ${i + 1}',
                onRemove: () => setState(() {
                      _vehicles[i].dispose();
                      _vehicles.removeAt(i);
                    })),
          _text('Make/Model', _vehicles[i].t['make_model']!,
              hint: 'Enter make & model'),
          _numberField('Year', _vehicles[i].t['year']!, hint: 'Enter year'),
          _dropdown('Color', _vehicles[i].d['color'], _kColors,
              (v) => setState(() => _vehicles[i].d['color'] = v),
              hint: 'Select color'),
          _text('License Plate', _vehicles[i].t['license_plate']!,
              hint: 'Enter License Plate'),
          _dropdown('State', _vehicles[i].d['state'], _kStates,
              (v) => setState(() => _vehicles[i].d['state'] = v),
              hint: 'Select state'),
        ],
      ],
    );
  }

  Widget _emergencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Emergency Contact',
            addLabel: 'Add Emergency Contact',
            onAdd: () => setState(() => _emergency.add(_Rep(
                  ['name', 'relationship', 'email', 'phone_number'], {})))),
        for (int i = 0; i < _emergency.length; i++) ...[
          _entryLabel('Emergency Contact ${i + 1}',
              onRemove: _emergency.length > 1
                  ? () => setState(() {
                        _emergency[i].dispose();
                        _emergency.removeAt(i);
                      })
                  : null),
          _text('Contact Name', _emergency[i].t['name']!,
              hint: 'Enter name',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _text('Relationship to Tenant', _emergency[i].t['relationship']!,
              hint: 'Enter relationship',
              formatters: [lettersAndSpacesFormatter],
              autocorrect: false),
          _emailField('E-Mail', _emergency[i].t['email']!),
          _phoneField('Phone Number', _emergency[i].t['phone_number']!),
        ],
      ],
    );
  }

  Widget _petsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Pets',
            addLabel: 'Add Pet',
            onAdd: () => setState(() => _pets.add(_Rep(
                  ['type', 'breed', 'color', 'weight', 'age'],
                  {'sex': null, 'neutered': null, 'declawed': null})))),
        for (int i = 0; i < _pets.length; i++) ...[
          if (_pets.length > 1)
            _entryLabel('Pet ${i + 1}',
                onRemove: () => setState(() {
                      _pets[i].dispose();
                      _pets.removeAt(i);
                    })),
          _text('Type of Pet', _pets[i].t['type']!, hint: "Enter pet's type"),
          _text('Breed', _pets[i].t['breed']!, hint: "Enter pet's breed"),
          _text('Color', _pets[i].t['color']!, hint: 'Enter color'),
          _numberField('Full Grown Weight (lbs)', _pets[i].t['weight']!,
              hint: 'Enter weight'),
          _numberField('Age', _pets[i].t['age']!, hint: 'Enter age'),
          _dropdown('Sex', _pets[i].d['sex'], _kSex,
              (v) => setState(() => _pets[i].d['sex'] = v),
              hint: 'Select sex'),
          _dropdown('Neutered', _pets[i].d['neutered'], _kYesNo,
              (v) => setState(() => _pets[i].d['neutered'] = v),
              hint: 'Select option'),
          _dropdown('Declawed', _pets[i].d['declawed'], _kYesNo,
              (v) => setState(() => _pets[i].d['declawed'] = v),
              hint: 'Select option'),
        ],
      ],
    );
  }

  Widget _additionalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Additional Information',
            style: TextStyle(
                color: blueColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Bankruptcy History',
            style: TextStyle(
                color: blueColor, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _yesNo('Have you ever filed for bankruptcy?', _hasBankruptcy,
            (v) => setState(() => _hasBankruptcy = v)),
        if (_hasBankruptcy == 'Yes') _date('Bankruptcy Date', _bankruptcyDate),
        _sectionDivider(),
        Text('Rental History',
            style: TextStyle(
                color: blueColor, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _yesNo('Have you ever been evicted from any tenancy?', _hasEviction,
            (v) => setState(() => _hasEviction = v)),
        _yesNo('Have you ever willfully and intentionally refused to pay rent when due?',
            _hasRefusedRent, (v) => setState(() => _hasRefusedRent = v)),
        _sectionDivider(),
        Text("Renter's Insurance",
            style: TextStyle(
                color: blueColor, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        _yesNo("Do you currently have renter's insurance?",
            _hasRentersInsurance,
            (v) => setState(() => _hasRentersInsurance = v)),
        if (_hasRentersInsurance == 'Yes')
          _text("What company is your renter's insurance with?",
              _insuranceCompany,
              hint: 'Enter company name'),
      ],
    );
  }

  Widget _signatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Signature & Applicant Fee',
            style: TextStyle(
                color: blueColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        // Web parity: Agreed by is display-only (not editable).
        _disabledField('Agreed by', _agreeBy.text),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rows added or removed can change whether any box is still red.
    if (_showFixHint) _queueFixHintCheck();
    return Container(
      color: const Color(0xFFF4F6F9),
      child: Form(
        key: _formKey,
        // Each box decides when it's checked (see _autoFor), like web.
        onChanged: _queueFixHintCheck,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onCancel,
                    child: const Icon(Icons.arrow_back, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text('Enter Applicant Details',
                      style: TextStyle(
                          color: blueColor,
                          fontSize: 19,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _personalInfo(),
                  _sectionDivider(),
                  Text('Move In Date',
                      style: TextStyle(
                          color: blueColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Web hard-requires move_in_date (ApplicantForm yup schema),
                  // so no Clear affordance here. Like web: today or later, so
                  // a saved date that has passed must be changed to save.
                  _date('Move In Date', _moveIn,
                      clearable: false,
                      firstDate: _today,
                      redBoxOnly: true,
                      validator: (v) =>
                          _redBox(moveInDateError(v ?? '', _df, _today))),
                  _sectionDivider(),
                  _residentsSection(),
                  _sectionDivider(),
                  _addressSection(),
                  _sectionDivider(),
                  _employmentSection(),
                  _sectionDivider(),
                  _referencesSection(),
                  _sectionDivider(),
                  _vehicleSection(),
                  _sectionDivider(),
                  _emergencySection(),
                  _sectionDivider(),
                  _petsSection(),
                  _sectionDivider(),
                  _additionalInfo(),
                  _sectionDivider(),
                  _signatureSection(),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_showFixHint)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Please correct the red boxes above',
                    style: TextStyle(
                        color: _err,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Application',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _saving ? null : widget.onCancel,
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: Color(0xFF748097),
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
