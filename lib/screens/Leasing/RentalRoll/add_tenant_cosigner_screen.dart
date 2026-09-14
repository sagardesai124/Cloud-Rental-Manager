// Full-screen "Add Tenant / Cosigner" flow (replaces the old cramped dialog).
//
// Mirrors the LIVE web lease dialog (= the standalone Add-Tenant design): no
// password — an "Account Setup / welcome email" toggle instead — plus DOB
// (required), Notes, multiple Emergency Contacts, and Payment Settings. The
// cosigner tab is Contact Information + Address.
//
// Design reuses the standalone Add-Tenant card system (add_tenants.dart):
// rounded white cards, navy headers, red-* labels, flat CustomTextField inputs.
//
// Shared by BOTH modules (Admin + Staff) and New Lease + Edit Lease — the lease
// flow's models/providers (lib/Model + lib/provider) are shared. Save adds an
// in-memory Tenant/Cosigner to the providers and pops; the lease submit sends
// them later (see TenantData.toJson — no tenant_password/taxPayer_id, sends
// send_welcome_email, matching web).

import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';
import 'package:three_zero_two_property/Model/tenants.dart';
// lowercase 'model/' — matches lease_provider.dart's import path so Cosigner
// is the same type (macOS case-insensitive FS).
import 'package:three_zero_two_property/model/cosigner.dart';
import 'package:three_zero_two_property/repository/setting.dart';
// CustomTextField (flag-driven) is defined here and reused verbatim.
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
// Module-specific AppBar + Drawer so the screen shows Admin's bar/drawer for
// Admin and Staff's for Staff (selected by the isStaff flag).
import 'package:three_zero_two_property/widgets/appbar.dart' show widget_302;
import 'package:three_zero_two_property/widgets/custom_drawer.dart'
    show CustomDrawer;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    show widget_302_Staff;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    show CustomDrawerStaff;

class AddTenantCosignerScreen extends StatefulWidget {
  /// Open directly on the Cosigner tab.
  final bool startOnCosigner;

  /// When editing an existing cosigner (edit-pencil): the cosigner + its index
  /// in SelectedCosignersProvider. Null => add mode.
  final Cosigner? cosigner;
  final int? cosignerIndex;

  /// Which module opened this — controls the AppBar + drawer shown.
  final bool isStaff;

  const AddTenantCosignerScreen({
    super.key,
    this.startOnCosigner = false,
    this.cosigner,
    this.cosignerIndex,
    this.isStaff = false,
  });

  @override
  State<AddTenantCosignerScreen> createState() =>
      _AddTenantCosignerScreenState();
}

class _AddTenantCosignerScreenState extends State<AddTenantCosignerScreen> {
  late bool _isTenant;

  // ---------------- Tenant (new-entry) ----------------
  final _tenantFormKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _work = TextEditingController();
  final _email = TextEditingController();
  final _altEmail = TextEditingController();
  final _dob = TextEditingController();
  final _comments = TextEditingController();

  bool _chooseExisting = false;
  bool _sendWelcomeEmail = true;
  final List<_EcRow> _emergencyContacts = [];

  bool _enableOverrideFee = false;
  bool _enableACH = true;
  bool _enableCard = true;
  final _overrideFee = TextEditingController();
  String _overrideFeeError = '';
  String? _globalDebitCardFee;

  // ---------------- Existing-tenant picker ----------------
  final _search = TextEditingController();
  List<Tenant> _allTenants = [];
  bool _loadingTenants = false;

  // ---------------- Cosigner ----------------
  final _cosignerFormKey = GlobalKey<FormState>();
  final _cFirstName = TextEditingController();
  final _cLastName = TextEditingController();
  final _cPhone = TextEditingController();
  final _cWork = TextEditingController();
  final _cEmail = TextEditingController();
  final _cAltEmail = TextEditingController();
  final _cStreet = TextEditingController();
  final _cCity = TextEditingController();
  final _cCountry = TextEditingController();
  final _cZip = TextEditingController();
  bool _showCWork = false;
  bool _showCAltEmail = false;

  @override
  void initState() {
    super.initState();
    _isTenant = !widget.startOnCosigner && widget.cosigner == null;
    _overrideFee.addListener(_validateOverride);
    // Live-filter the existing-tenant list as the user types.
    _search.addListener(() {
      if (mounted) setState(() {});
    });
    _loadGlobalDebitFee();
    final c = widget.cosigner;
    if (c != null) {
      _cFirstName.text = c.firstName;
      _cLastName.text = c.lastName;
      _cPhone.text = c.phoneNumber;
      _cWork.text = c.workNumber;
      _cEmail.text = c.email;
      _cAltEmail.text = c.alterEmail;
      _cStreet.text = c.streetAddress;
      _cCity.text = c.city;
      _cCountry.text = c.country;
      _cZip.text = c.postalCode;
      _showCWork = c.workNumber.isNotEmpty;
      _showCAltEmail = c.alterEmail.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _overrideFee.removeListener(_validateOverride);
    for (final c in [
      _firstName, _lastName, _phone, _work, _email, _altEmail, _dob,
      _comments, _overrideFee, _search, _cFirstName, _cLastName, _cPhone,
      _cWork, _cEmail, _cAltEmail, _cStreet, _cCity, _cCountry, _cZip,
    ]) {
      c.dispose();
    }
    for (final r in _emergencyContacts) {
      r.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  Future<void> _loadGlobalDebitFee() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId') ?? '';
      final surcharges = await SurchargeRepository(baseUrl: '$Api_url')
          .fetchSurchargeData(adminId);
      final fee = surcharges.surchargePercentDebit;
      if (!mounted) return;
      setState(() {
        _globalDebitCardFee =
            fee == fee.roundToDouble() ? fee.toInt().toString() : fee.toString();
      });
    } catch (_) {
      // Fee line stays hidden when unavailable (web parity).
    }
  }

  void _validateOverride() {
    setState(() {
      final input = _overrideFee.text.trim();
      if (input.isEmpty) {
        _overrideFeeError = 'This field cannot be empty';
      } else if (!RegExp(r'^(\d{1,2}(\.\d{1,2})?|100(\.0{1,2})?)$')
          .hasMatch(input)) {
        _overrideFeeError =
            'Enter a valid number up to 100 with up to 2 decimal places';
      } else {
        _overrideFeeError = '';
      }
    });
  }

  String _toApiDate(String display) {
    if (display.isEmpty) return '';
    for (final f in [
      'yyyy-MM-dd', 'yyyy-MMM-dd', 'MM/dd/yyyy', 'MM-dd-yyyy',
      'dd/MM/yyyy', 'dd-MM-yyyy'
    ]) {
      try {
        return DateFormat('yyyy-MM-dd').format(DateFormat(f).parse(display));
      } catch (_) {}
    }
    return display;
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: blueColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      final api = DateFormat('yyyy-MM-dd').format(picked);
      setState(() => _dob.text = dateProvider.formatCurrentDate(api));
    }
  }

  Future<void> _fetchExistingTenants() async {
    setState(() => _loadingTenants = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId') ?? '';
      final token = prefs.getString('token') ?? '';
      // Staff must send their OWN id in the `id` header (adminId 401s for staff
      // at multi-co-admin companies); the URL path always uses adminId.
      final idHeader =
          widget.isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final res = await apiGet(
        Uri.parse('$Api_url/api/tenant/tenants/$adminId'),
        headers: {'authorization': 'CRM $token', 'id': 'CRM $idHeader'},
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final data = body is Map ? (body['data'] ?? body) : body;
        final List tenants = (data is Map ? data['tenants'] : null) ?? [];
        final List applicants = (data is Map ? data['applicants'] : null) ?? [];
        final parsed = <Tenant>[];
        for (final t in tenants) {
          try {
            parsed.add(Tenant.fromJson(Map<String, dynamic>.from(t)));
          } catch (_) {}
        }
        for (final a in applicants) {
          try {
            final m = Map<String, dynamic>.from(a);
            parsed.add(Tenant(
              applicantId: m['applicant_id']?.toString(),
              tenantFirstName:
                  (m['applicant_firstName'] ?? m['tenant_firstName'] ?? '')
                      .toString(),
              tenantLastName:
                  (m['applicant_lastName'] ?? m['tenant_lastName'] ?? '')
                      .toString(),
              tenantPhoneNumber:
                  (m['applicant_phoneNumber'] ?? m['tenant_phoneNumber'] ?? '')
                      .toString(),
              tenantEmail:
                  (m['applicant_email'] ?? m['tenant_email'] ?? '').toString(),
            ));
          } catch (_) {}
        }
        if (mounted) setState(() => _allTenants = parsed);
      } else {
      }
    } catch (e) {
      logError('[existing-tenants] error=$e');
    } finally {
      if (mounted) setState(() => _loadingTenants = false);
    }
  }

  bool _isSelected(Tenant t, List<Tenant> selected) {
    return selected.any((s) =>
        (t.tenantId != null && s.tenantId == t.tenantId) ||
        (t.applicantId != null && s.applicantId == t.applicantId));
  }

  // ------------------------------------------------------------------ save

  void _saveTenant() {
    // Same gap as Add Tenant: the override-fee message is listener-driven,
    // so Form.validate() never sees it. Re-run it here (covers a field that
    // was never typed in) and let it block the save.
    if (_enableOverrideFee) _validateOverride();
    final formOk = _tenantFormKey.currentState?.validate() ?? false;
    if (!formOk || (_enableOverrideFee && _overrideFeeError.isNotEmpty)) return;
    final ecItems = _emergencyContacts
        .where((c) =>
            c.name.text.trim().isNotEmpty ||
            c.relation.text.trim().isNotEmpty ||
            c.email.text.trim().isNotEmpty ||
            c.phone.text.trim().isNotEmpty)
        .map((c) => EmergencyContactItem(
              name: c.name.text.trim(),
              relation: c.relation.text.trim(),
              email: c.email.text.trim(),
              phoneNumber: c.phone.text.trim(),
            ))
        .toList();
    final firstEc = ecItems.isNotEmpty ? ecItems.first : null;

    final tenant = Tenant(
      tenantFirstName: _firstName.text.trim(),
      tenantLastName: _lastName.text.trim(),
      tenantPhoneNumber: _phone.text.trim(),
      tenantAlternativeNumber: _work.text.trim(),
      tenantEmail: _email.text.trim(),
      tenantAlternativeEmail: _altEmail.text.trim(),
      tenantBirthDate:
          _dob.text.trim().isNotEmpty ? _toApiDate(_dob.text.trim()) : '',
      comments: _comments.text.trim(),
      // Legacy single object (kept for the lease payload's emergency_contact).
      emergencyContact: firstEc == null
          ? null
          : EmergencyContact(
              name: firstEc.name,
              relation: firstEc.relation,
              email: firstEc.email,
              phoneNumber: firstEc.phoneNumber,
            ),
      emergencyContacts: ecItems,
      enableoverrideFee: _enableOverrideFee,
      overRideFee:
          _enableOverrideFee ? double.tryParse(_overrideFee.text.trim()) : null,
      allowAch: _enableACH,
      allowCard: _enableCard,
      sendWelcomeEmail: _sendWelcomeEmail,
    );
    Provider.of<SelectedTenantsProvider>(context, listen: false)
        .addTenant(tenant);
    Navigator.of(context).pop(true);
  }

  void _saveCosigner() {
    if (!(_cosignerFormKey.currentState?.validate() ?? false)) return;
    final provider =
        Provider.of<SelectedCosignersProvider>(context, listen: false);
    final cosigner = Cosigner(
      c_id:
          widget.cosigner == null ? _cFirstName.text.trim() : widget.cosigner!.c_id,
      cosignerId: widget.cosigner?.cosignerId,
      firstName: _cFirstName.text.trim(),
      lastName: _cLastName.text.trim(),
      phoneNumber: _cPhone.text.trim(),
      workNumber: _cWork.text.trim(),
      email: _cEmail.text.trim(),
      alterEmail: _cAltEmail.text.trim(),
      streetAddress: _cStreet.text.trim(),
      city: _cCity.text.trim(),
      country: _cCountry.text.trim(),
      postalCode: _cZip.text.trim(),
    );
    if (widget.cosigner != null && widget.cosignerIndex != null) {
      provider.updateCosigner(cosigner, widget.cosignerIndex!);
    } else {
      provider.addCosigner(cosigner);
    }
    Navigator.of(context).pop(true);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      // Each module shows its own AppBar + navigation drawer.
      appBar: widget.isStaff
          ? widget_302_Staff.App_Bar(context: context)
          : widget_302.App_Bar(context: context),
      drawer: widget.isStaff
          ? CustomDrawerStaff(currentpage: "Leases", dropdown: true)
          : CustomDrawer(currentpage: "Leases", dropdown: true),
      body: Column(
        children: [
          _header(),
          _toggle(),
          Expanded(
            // Existing-tenant mode: list scrolls inside its own area with the
            // search + Done/Cancel pinned. Everything else scrolls the page.
            child: (_isTenant && _chooseExisting)
                ? _existingTenantView()
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        16, 16, 16, 28 + MediaQuery.of(context).padding.bottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _isTenant ? _tenantTab() : _cosignerTab(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // In-body header: back button + screen title (the module AppBar has the
  // drawer/hamburger, so back navigation lives here inside the screen).
  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: outlineClr),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.chevron_left, color: navyClr),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Add Tenant / Cosigner',
            style: TextStyle(
              color: navyClr,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggle() {
    Widget seg(String text, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? navyClr : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: active ? Colors.white : mutedClr,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: pageBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderClr),
        ),
        child: Row(
          children: [
            seg('Tenant', _isTenant, () => setState(() => _isTenant = true)),
            seg('Cosigner', !_isTenant, () => setState(() => _isTenant = false)),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------- Tenant tab

  Widget _tenantTab() {
    return Form(
      key: _tenantFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chooseExistingCard(),
          const SizedBox(height: 16),
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
          _actionButtons('Add Tenant', _saveTenant),
        ],
      ),
    );
  }

  Widget _chooseExistingCard() {
    return _card(
      child: _checkRow(
        value: _chooseExisting,
        onChanged: (v) {
          setState(() => _chooseExisting = v ?? false);
          if (_chooseExisting && _allTenants.isEmpty) _fetchExistingTenants();
        },
        label: Text(
          'Choose an existing Tenant',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: navyClr,
          ),
        ),
      ),
    );
  }

  // Existing-tenant picker: search + header pinned at top, list scrolls in the
  // middle (Expanded), Done/Cancel pinned at the bottom — so a long list never
  // pushes the buttons off-screen.
  Widget _existingTenantView() {
    final selected =
        Provider.of<SelectedTenantsProvider>(context).selectedTenants;
    final q = _search.text.trim().toLowerCase();
    final filtered = _allTenants.where((t) {
      final name =
          '${t.tenantFirstName ?? ''} ${t.tenantLastName ?? ''}'.toLowerCase();
      return q.isEmpty || name.contains(q);
    }).toList();

    return Padding(
      // Extra bottom space under the Done/Cancel row (+ home-indicator inset).
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chooseExistingCard(),
          const SizedBox(height: 16),
          _input(
              hint: 'Search by first and last name',
              controller: _search,
              optional: true),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tintBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tenant Name',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: navyClr)),
                Text('Select',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: navyClr)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loadingTenants
                ? const Center(
                    child: SpinKitFadingCircle(
                        color: Colors.blueGrey, size: 28))
                : filtered.isEmpty
                    ? Center(
                        child: Text('No tenants found',
                            style: TextStyle(
                                color: mutedClr,
                                fontStyle: FontStyle.italic)),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _tenantRow(
                            filtered[i], _isSelected(filtered[i], selected)),
                      ),
          ),
          const SizedBox(height: 12),
          _actionButtons('Done', () => Navigator.of(context).pop(true)),
        ],
      ),
    );
  }

  Widget _tenantRow(Tenant t, bool selected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? tintBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? navyClr : borderClr),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.tenantFirstName ?? ''} ${t.tenantLastName ?? ''}',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, color: navyClr)),
                const SizedBox(height: 2),
                Text(t.tenantPhoneNumber ?? '',
                    style: TextStyle(color: mutedClr, fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: selected,
              activeColor: navyClr,
              side: BorderSide(color: checkOffClr, width: 1.5),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onChanged: (v) {
                final provider = Provider.of<SelectedTenantsProvider>(context,
                    listen: false);
                if (v == true) {
                  provider.addTenant(t);
                } else {
                  provider.removeTenant(t);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------- Tenant cards

  Widget _personalInfoCard() {
    return _sectionCard(title: 'Personal Information', children: [
      _fieldLabel('First Name', required: true),
      _input(hint: 'Enter first name', controller: _firstName, inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z ']")),
      ]),
      const SizedBox(height: 16),
      _fieldLabel('Last Name', required: true),
      _input(hint: 'Enter last name', controller: _lastName, inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z '-]")),
      ]),
      const SizedBox(height: 16),
      _fieldLabel('Phone Number', required: true),
      _input(
        hint: 'Enter phone number',
        controller: _phone,
        keyboardType: TextInputType.phone,
        phone: true,
        inputFormatters: _phoneFormatters(),
      ),
      const SizedBox(height: 16),
      _fieldLabel('Work Number'),
      _input(
        hint: 'Enter work number',
        controller: _work,
        keyboardType: TextInputType.phone,
        optional: true,
        phone: true,
        otherController: _phone,
        inputFormatters: _phoneFormatters(),
      ),
      const SizedBox(height: 16),
      _fieldLabel('Email', required: true),
      _input(
          hint: 'Enter email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          email: true),
      const SizedBox(height: 16),
      _fieldLabel('Alternative Email'),
      _input(
        hint: 'Enter alternative email',
        controller: _altEmail,
        keyboardType: TextInputType.emailAddress,
        optional: true,
        email: true,
        alterController: _email,
      ),
      const SizedBox(height: 16),
      _fieldLabel('Date of Birth', required: true),
      _input(
        hint: 'YYYY-MM-DD',
        controller: _dob,
        readOnly: true,
        label: 'enter date of birth',
        onTap: _pickDob,
        suffixIcon:
            Icon(Icons.calendar_today_outlined, color: mutedClr, size: 18),
      ),
    ]);
  }

  Widget _accountSetupCard() {
    return _sectionCard(title: 'Account Setup', children: [
      _checkRow(
        value: _sendWelcomeEmail,
        cross: CrossAxisAlignment.start,
        onChanged: (v) => setState(() => _sendWelcomeEmail = v ?? false),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email tenant a welcome email to set up their account',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: navyClr)),
            const SizedBox(height: 6),
            Text(
              'The tenant receives a one-time link (valid 4 hours) to set their '
              'own password. You can re-send or reset later from the tenant '
              'detail page.',
              style: TextStyle(fontSize: 12.5, color: mutedClr, height: 1.4),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _notesCard() {
    return _sectionCard(title: 'Notes', children: [
      Container(
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: outlineClr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextFormField(
          controller: _comments,
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
    ]);
  }

  Widget _emergencyContactsCard() {
    return _sectionCard(
      title: 'Emergency Contacts',
      trailing: OutlinedButton.icon(
        onPressed: () => setState(() => _emergencyContacts.add(_EcRow())),
        icon: Icon(Icons.add_circle_outline, size: 18, color: navyClr),
        label: Text('Add Contact',
            style: TextStyle(color: navyClr, fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: outlineClr),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      children: [
        if (_emergencyContacts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: pageBg,
              border: Border.all(color: borderClr),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No emergency contacts yet. Click "Add Contact" to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontStyle: FontStyle.italic, color: mutedClr, fontSize: 13),
            ),
          )
        else
          ...List.generate(
              _emergencyContacts.length, (i) => _contactCard(i)),
      ],
    );
  }

  Widget _contactCard(int index) {
    final row = _emergencyContacts[index];
    final isLast = index == _emergencyContacts.length - 1;
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
              Text('Contact #${index + 1}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: navyClr, fontSize: 14)),
              InkWell(
                onTap: () => setState(() {
                  _emergencyContacts[index].dispose();
                  _emergencyContacts.removeAt(index);
                }),
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]')),
              ]),
          const SizedBox(height: 14),
          _fieldLabel('Relationship to Tenant'),
          _input(
              hint: 'Enter relationship to tenant',
              controller: row.relation,
              optional: true),
          const SizedBox(height: 14),
          _fieldLabel('Email'),
          _input(
            hint: 'Enter email',
            controller: row.email,
            keyboardType: TextInputType.emailAddress,
            optional: true,
            email: true,
            alterController: _email,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Phone Number'),
          _input(
            hint: 'Enter phone number',
            controller: row.phone,
            keyboardType: TextInputType.phone,
            optional: true,
            phone: true,
            telephoneController: _phone,
            inputFormatters: _phoneFormatters(),
          ),
        ],
      ),
    );
  }

  Widget _paymentSettingsCard() {
    return _sectionCard(title: 'Payment Settings', children: [
      if (_globalDebitCardFee != null) ...[
        RichText(
          text: TextSpan(
            text: 'Global debit card fee: ',
            style: TextStyle(color: mutedClr, fontSize: 14),
            children: [
              TextSpan(
                text: '$_globalDebitCardFee%',
                style:
                    TextStyle(color: navyClr, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _checkRow(
          value: _enableOverrideFee,
          onChanged: (v) => setState(() => _enableOverrideFee = v ?? false),
          label: Text('Enable Debit Card Fee Override',
              style: TextStyle(fontSize: 15, color: navyClr)),
        ),
        if (_enableOverrideFee) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: _input(
              hint: '%',
              controller: _overrideFee,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              optional: true,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                TextInputFormatter.withFunction((oldV, newV) {
                  final t = newV.text;
                  if (t.isEmpty || t == '.') return newV;
                  if ('.'.allMatches(t).length > 1) return oldV;
                  final v = double.tryParse(t);
                  if (v == null || v < 0 || v > 100) return oldV;
                  return newV;
                }),
              ],
            ),
          ),
          if (_overrideFeeError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_overrideFeeError,
                  style: TextStyle(color: redClr, fontSize: 11)),
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
            Text('Allowed Payment Methods',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: navyClr, fontSize: 14)),
            const SizedBox(height: 12),
            _checkRow(
              value: _enableACH,
              onChanged: (v) => setState(() => _enableACH = v ?? false),
              label:
                  Text('ACH', style: TextStyle(fontSize: 15, color: navyClr)),
            ),
            const SizedBox(height: 8),
            _checkRow(
              value: _enableCard,
              onChanged: (v) => setState(() => _enableCard = v ?? false),
              label: Text('Card',
                  style: TextStyle(fontSize: 15, color: navyClr)),
            ),
          ],
        ),
      ),
    ]);
  }

  // -------------------------------------------------- Cosigner tab

  Widget _cosignerTab() {
    return Form(
      key: _cosignerFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionCard(title: 'Contact Information', children: [
            _fieldLabel('First Name', required: true),
            _input(hint: 'Enter first name', controller: _cFirstName,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z ']")),
                ]),
            const SizedBox(height: 16),
            _fieldLabel('Last Name', required: true),
            _input(hint: 'Enter last name', controller: _cLastName,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z '-]")),
                ]),
            const SizedBox(height: 16),
            _fieldLabel('Phone Number', required: true),
            _input(
              hint: 'Enter phone number',
              controller: _cPhone,
              keyboardType: TextInputType.phone,
              phone: true,
              inputFormatters: _phoneFormatters(),
            ),
            if (_showCWork) ...[
              const SizedBox(height: 16),
              _fieldLabel('Work Number'),
              _input(
                hint: 'Enter work number',
                controller: _cWork,
                keyboardType: TextInputType.phone,
                optional: true,
                phone: true,
                otherController: _cPhone,
                inputFormatters: _phoneFormatters(),
              ),
            ],
            const SizedBox(height: 8),
            _addLink(
                _showCWork
                    ? '- Remove alternative phone'
                    : '+ Add alternative phone',
                () => setState(() => _showCWork = !_showCWork)),
            const SizedBox(height: 8),
            _fieldLabel('Email', required: true),
            _input(
                hint: 'Enter email',
                controller: _cEmail,
                keyboardType: TextInputType.emailAddress,
                email: true),
            if (_showCAltEmail) ...[
              const SizedBox(height: 16),
              _fieldLabel('Alternative Email'),
              _input(
                hint: 'Enter alternative email',
                controller: _cAltEmail,
                keyboardType: TextInputType.emailAddress,
                optional: true,
                email: true,
                alterController: _cEmail,
              ),
            ],
            const SizedBox(height: 8),
            _addLink(
                _showCAltEmail
                    ? '- Remove alternative email'
                    : '+ Add alternative email',
                () => setState(() => _showCAltEmail = !_showCAltEmail)),
          ]),
          const SizedBox(height: 16),
          _sectionCard(title: 'Address', children: [
            _fieldLabel('Street Address'),
            _input(
                hint: 'Enter street address',
                controller: _cStreet,
                optional: true),
            const SizedBox(height: 16),
            _fieldLabel('City'),
            _input(hint: 'Enter city', controller: _cCity, optional: true),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Country'),
                      _input(
                          hint: 'Enter country',
                          controller: _cCountry,
                          optional: true),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Zip Code'),
                      _input(
                        hint: 'Enter zip code',
                        controller: _cZip,
                        optional: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]')),
                          TextInputFormatter.withFunction((o, n) =>
                              n.copyWith(text: n.text.toUpperCase())),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 20),
          _actionButtons(
              widget.cosigner != null ? 'Save Cosigner' : 'Add Cosigner',
              _saveCosigner),
        ],
      ),
    );
  }

  // -------------------------------------------------- shared UI helpers

  List<TextInputFormatter> _phoneFormatters() => [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(14),
        PhoneNumberFormatter(),
      ];

  Widget _addLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF2F6BFF),
              fontWeight: FontWeight.bold,
              fontSize: 13)),
    );
  }

  Widget _card({required Widget child}) {
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
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _sectionCard({
    required String title,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: navyClr)),
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
              fontSize: 14, fontWeight: FontWeight.bold, color: navyClr),
          children: required
              ? [
                  TextSpan(
                      text: ' *',
                      style:
                          TextStyle(color: redClr, fontWeight: FontWeight.bold)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: label),
      ],
    );
  }

  // Add (primary) on the left, Cancel on the right — matches the web dialog.
  Widget _actionButtons(String primaryText, VoidCallback onPrimary) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(
              backgroundColor: navyClr,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(primaryText,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: outlineClr),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Cancel',
                style: TextStyle(
                    color: mutedClr,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

/// Backing controllers for one dynamic emergency-contact row.
class _EcRow {
  final name = TextEditingController();
  final relation = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();

  void dispose() {
    name.dispose();
    relation.dispose();
    email.dispose();
    phone.dispose();
  }
}
