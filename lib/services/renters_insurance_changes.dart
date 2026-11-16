import 'dart:convert';

/// Lease → Renters Insurance → Edit, like web staging
/// (UpdateInsuranceDialog.jsx handleSubmit): tapping Update Insurance with
/// nothing changed shows this message above the buttons, saves nothing and
/// keeps the form open; the message goes away once something is changed.
const String rentersInsuranceNoChangesMessage =
    'No changes detected. Please make at least one change before updating.';

/// The Edit Renters Insurance form reduced to what web compares, so two
/// snapshots are equal exactly when nothing has changed: the provider and
/// policy ID trimmed, the phone as digits only ("(555) 555-5555" is the same
/// number as "5555555555"), the liability coverage as a number ("10" and
/// "10.00" are the same), the dates as shown, the covered tenants in any
/// order, and the document's file name (uploading a new document or removing
/// the old one is a change).
String rentersInsuranceFormSnapshot({
  required String provider,
  required String phone,
  required String policyId,
  required String coverage,
  required String effectiveDate,
  required String expirationDate,
  required Iterable<String> tenants,
  required String document,
}) {
  final amount = coverage.trim().replaceAll(',', '');
  final number = double.tryParse(amount);
  final coveredTenants = tenants.toSet().toList()..sort();
  return jsonEncode([
    provider.trim(),
    phone.replaceAll(RegExp(r'\D'), ''),
    policyId.trim(),
    number?.toString() ?? amount,
    effectiveDate.trim(),
    expirationDate.trim(),
    coveredTenants,
    document.trim(),
  ]);
}
