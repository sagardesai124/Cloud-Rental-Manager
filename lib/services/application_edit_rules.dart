/// Leasing › Applicants › applicant › Application › Edit (and "Manually
/// enter application details"), Admin and Staff: web's rules for Date of
/// Birth, Move In Date, Driver's License Number and Zip Code
/// (ApplicantForm.jsx, applicantFormStepValidation.jsx, MaterialDatePicker
/// `validateDateField` and inputValidation `validateZipCodeFormat`).
///
/// Each check returns web's message, or null when the value is fine. Dates
/// are the text shown in the box, in the app's date format.
library;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Web's MINIMUM_APPLICANT_AGE_YEARS: the applicant signs the lease.
const int minimumApplicantAgeYears = 18;

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The latest Applicant Birth Date that is at least 18 years before
/// [today]; web's calendar stops here.
DateTime latestApplicantBirthDate(DateTime today) =>
    DateTime(today.year - minimumApplicantAgeYears, today.month, today.day);

DateTime? _parseShown(String shown, String pattern) {
  try {
    return DateFormat(pattern).parseStrict(shown.trim());
  } catch (_) {
    return null;
  }
}

String _formatError(String pattern) =>
    'Invalid date format. Please use ${pattern.toUpperCase()}';

String? _birthDateError(String shown, String pattern, DateTime today,
    {required bool enforceMinAge}) {
  final date = _parseShown(shown, pattern);
  if (date == null) return _formatError(pattern);
  if (date.year < 1900) return 'Please enter a valid date of birth.';
  final day = _dayOf(today);
  if (date.isAfter(day)) return 'Date of Birth cannot be a future date.';
  if (enforceMinAge && date.isAfter(latestApplicantBirthDate(day))) {
    return 'You must be at least $minimumApplicantAgeYears years old to apply.';
  }
  return null;
}

/// Applicant Birth Date: required, not in the future and at least 18 years
/// old, like web.
String? applicantBirthDateError(String shown, String pattern, DateTime today) {
  if (shown.trim().isEmpty) return 'Date of Birth is required';
  return _birthDateError(shown, pattern, today, enforceMinAge: true);
}

/// An Additional Resident's Date of Birth: required when [required] (web's
/// "Require date of birth" setting) and not in the future, like web.
/// Residents can be minors, so there is no age limit.
String? residentBirthDateError(String shown, String pattern, DateTime today,
    {bool required = false}) {
  if (shown.trim().isEmpty)
    return required ? 'Date of birth is required' : null;
  return _birthDateError(shown, pattern, today, enforceMinAge: false);
}

/// A resident's Name and Relation are always required, like web.
String? residentNameError(String text) =>
    text.trim().isEmpty ? 'Name is required' : null;
String? residentRelationError(String text) =>
    text.trim().isEmpty ? 'Relation is required' : null;

/// Web's "Require date of birth" setting for Additional Residents
/// (stepConfigurations.additionalResidents.fields.dob.required, from
/// Settings → Tenant Application or a property owner's Rules Management):
/// unset means required; only an explicit `false` turns it off. Older
/// settings use the `additional_residents` key, which web reads the same way.
bool residentDobRequired(Object? stepConfigurations) {
  if (stepConfigurations is! Map) return true;
  final step = stepConfigurations['additionalResidents'] ??
      stepConfigurations['additional_residents'];
  if (step is! Map) return true;
  final fields = step['fields'];
  if (fields is! Map || !fields.containsKey('dob')) return true;
  final dob = fields['dob'];
  return !(dob is Map && dob['required'] == false);
}

/// Move In Date: today or later, like web (which also refuses years before
/// 2020, all of them past anyway).
String? moveInDateError(String shown, String pattern, DateTime today) {
  if (shown.trim().isEmpty) return null;
  final date = _parseShown(shown, pattern);
  if (date == null) return _formatError(pattern);
  if (date.year < 2020 || date.isBefore(_dayOf(today))) {
    return 'A past date is not allowed';
  }
  return null;
}

/// Driver's License Number: only letters, numbers and dashes can be typed,
/// like web.
final TextInputFormatter driverLicenseFormatter =
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]'));

// Web's name-like boxes (ApplicantForm.jsx) keep a change only when the
// whole box still matches — `if (/^[A-Za-z\s]*$/.test(value)) onChange(..)` —
// so a typed or pasted number or symbol is ignored rather than stripped.
TextInputFormatter _keepOnlyIfWholeBoxMatches(RegExp pattern) =>
    TextInputFormatter.withFunction((oldValue, newValue) =>
        pattern.hasMatch(newValue.text) ? newValue : oldValue);

/// Letters and spaces only, like web: First Name, City, each Additional
/// Resident's Name and Relation, Address History City and Landlord Name,
/// Employer Name, each Reference's Name and City, and each Emergency
/// Contact's Name and Relationship.
final TextInputFormatter lettersAndSpacesFormatter =
    _keepOnlyIfWholeBoxMatches(RegExp(r'^[A-Za-z\s]*$'));

/// Last Name: letters, spaces and hyphens only, like web.
final TextInputFormatter lastNameFormatter =
    _keepOnlyIfWholeBoxMatches(RegExp(r'^[A-Za-z\s\-]*$'));

/// Driver's License Number: required, 5 to 20 characters, like web.
String? driverLicenseError(String text) {
  final license = text.trim();
  if (license.isEmpty) return "Driver's License Number is required";
  if (license.length < 5) {
    return "Driver's license number must be at least 5 characters";
  }
  if (license.length > 20) {
    return "Driver's license number must be 20 characters or fewer";
  }
  return null;
}

/// The applicant's and each Reference's Zip Code: up to 5 digits, like
/// web's boxes there.
List<TextInputFormatter> fiveDigitZipFormatters() => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(5),
    ];

/// Zip Code: 12345 or 12345-6789, and not 00000, like web.
String? applicationZipError(String text, {bool required = false}) {
  final zip = text.trim();
  if (zip.isEmpty) return required ? 'Zip Code is required' : null;
  if (!RegExp(r'^(\d{5}|\d{5}-\d{4})$').hasMatch(zip) ||
      zip.startsWith('00000')) {
    return 'Please enter a valid zip code (XXXXX or XXXXX-XXXX)';
  }
  return null;
}
