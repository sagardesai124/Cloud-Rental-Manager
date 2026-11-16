/// Web's rule for the Delete Tenant reason (tenants-v2/tenantRows.js
/// `deleteReasonProblem`; the classic TenantsTable.jsx prompt enforced the
/// same thing): it can't be blank, and may use letters, numbers and spaces
/// only.
final RegExp tenantDeleteReasonAllowed = RegExp(r'^[a-zA-Z0-9 ]*$');

/// Web's message when the reason is empty or only spaces.
const String tenantDeleteReasonBlankMessage =
    'Enter a reason for deleting this tenant.';

/// Web's message when the reason has anything but letters, numbers, spaces.
const String tenantDeleteReasonCharsMessage =
    'Use only letters A–Z, numbers and spaces in the reason.';

/// null when the reason is fine, otherwise web's message saying what to fix.
String? tenantDeleteReasonProblem(String? reason) {
  final r = reason ?? '';
  if (r.trim().isEmpty) return tenantDeleteReasonBlankMessage;
  if (!tenantDeleteReasonAllowed.hasMatch(r)) {
    return tenantDeleteReasonCharsMessage;
  }
  return null;
}
