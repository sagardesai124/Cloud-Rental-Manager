import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:three_zero_two_property/widgets/appbar.dart';

import '../../constant/constant.dart';
import '../../repository/team_repo.dart';
import '../../widgets/custom_drawer.dart';
import 'team_form_widgets.dart';

/// Add Staff Member. On success pops `true` so the Team & Access list refreshes.
///
/// NOTE: the create call uses [TeamRepository.inviteStaffMember], whose endpoint
/// is a best-guess (mirrors invite-coadmin) because the new design has no
/// password field. Confirm/adjust the endpoint in the repository.
class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _phoneError;
  bool _loading = false;

  final TeamRepository _repo = TeamRepository();

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _title.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _firstNameError =
          _firstName.text.trim().isEmpty ? 'Please enter first name' : null;
      // Same as web (InviteUserModal.jsx): Last name is required.
      _lastNameError =
          _lastName.text.trim().isEmpty ? 'Last name is required.' : null;
      if (_email.text.trim().isEmpty) {
        _emailError = 'Please enter email';
      } else if (!EmailValidator.validate(_email.text.trim())) {
        _emailError = 'Email is not valid';
      } else {
        _emailError = null;
      }
      final phoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
      _phoneError = (phoneDigits.isNotEmpty && phoneDigits.length != 10)
          ? 'Phone number must be 10 digits'
          : null;
    });
    if (_firstNameError != null ||
        _lastNameError != null ||
        _emailError != null ||
        _phoneError != null) {
      return;
    }

    setState(() => _loading = true);
    try {
      await _repo.inviteStaffMember(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        designation: _title.text.trim(),
        phoneNumber: _phone.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: const Color(0xFFF1F4F9),
      drawer: CustomDrawer(currentpage: "Settings", dropdown: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          teamBackRow(context),
          const SizedBox(height: 8),
          teamBanner('Add Staff Member'),
          const SizedBox(height: 14),
          const Text(
            "Staff members get access defined by the company's role permissions. "
            "They'll get an email with a link to set their own password.",
            style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF8A95A8)),
          ),
          const SizedBox(height: 22),
          // First name + Last name side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    teamFieldLabel('First Name', required: true),
                    teamTextField(
                      _firstName,
                      'First name',
                      onChanged: () {
                        if (_firstNameError != null) {
                          setState(() => _firstNameError = null);
                        }
                      },
                    ),
                    if (_firstNameError != null) teamErrorText(_firstNameError!),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    teamFieldLabel('Last Name', required: true),
                    teamTextField(
                      _lastName,
                      'Last name',
                      onChanged: () {
                        if (_lastNameError != null) {
                          setState(() => _lastNameError = null);
                        }
                      },
                    ),
                    if (_lastNameError != null) teamErrorText(_lastNameError!),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          teamFieldLabel('Email', required: true),
          teamTextField(
            _email,
            'Enter email',
            keyboardType: TextInputType.emailAddress,
            onChanged: () {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          if (_emailError != null) teamErrorText(_emailError!),
          const SizedBox(height: 16),
          teamFieldLabel('Title / role'),
          teamTextField(_title, 'Enter title / role'),
          const SizedBox(height: 16),
          teamFieldLabel('Phone'),
          teamTextField(
            _phone,
            'Enter phone number (optional)',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
              PhoneNumberFormatter(),
            ],
            onChanged: () {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
          if (_phoneError != null) teamErrorText(_phoneError!),
          const SizedBox(height: 28),
          teamButtons(
            onCancel: () => Navigator.of(context).maybePop(),
            onPrimary: _submit,
            primaryLabel: 'Add Staff',
            primaryIcon: Icons.add,
            loading: _loading,
          ),
        ],
      ),
    );
  }
}
