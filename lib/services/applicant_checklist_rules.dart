/// Leasing → Applicants → applicant → Summary → Application Checklist, like
/// web staging (ApplicantSummary.jsx and ApplicantSummary/SummaryTab.jsx).

/// The five standard checklist items with web's labels.
const Map<String, String> kApplicantChecklistLabels = {
  'CreditCheck': 'Credit and Background Check',
  'EmploymentVerification': 'Employment Verification',
  'ApplicationFee': 'Application Fee Collected',
  'IncomeVerification': 'Income Verification',
  'LandlordVerification': 'Landlord Verification',
};

/// Web's message when Save Changes is tapped with no checklist change.
const String applicantChecklistNoChangesMessage =
    'Nothing has changed, nothing will be saved';

/// Web's message once the checklist is saved.
const String applicantChecklistSavedMessage = 'Checklist saved successfully';

/// Like web (handleSaveChecklist): whether the checked items differ from the
/// last saved ones, ignoring order and repeats.
bool applicantChecklistChanged(
    Iterable<String> checked, Iterable<String> saved) {
  final now = checked.toSet().toList()..sort();
  final before = saved.toSet().toList()..sort();
  if (now.length != before.length) return true;
  for (var i = 0; i < now.length; i++) {
    if (now[i] != before[i]) return true;
  }
  return false;
}

/// Like web (handleAddItem): a custom item that is empty or only spaces is
/// not added.
bool isBlankChecklistItem(String text) => text.trim().isEmpty;
