/// Settings → Property Types search, like web staging
/// (property-types-v2/propertyTypeRows.js matchRow, the page both Admin and
/// Staff use): the search matches the main type, the sub type, and the
/// Created On and Updated On dates as the list shows them, in the company's
/// date format. The search text is trimmed and the match ignores case.

/// Web's search box prompt.
const String kPropertyTypeSearchHint = 'Search type or date';

/// A created/updated date as the list shows it, for the search; '' when
/// there is none (web never matches its "no date" placeholder).
String propertyTypeShownDay(
    String? value, String Function(String value) formatDay) {
  final String v = (value ?? '').trim();
  return v.isEmpty ? '' : formatDay(v);
}

/// Whether a property type matches the search, like web.
bool propertyTypeMatchesSearch(
  String query, {
  String? type,
  String? subType,
  String createdOn = '',
  String updatedOn = '',
}) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return <String?>[type, subType, createdOn, updatedOn]
      .any((v) => (v ?? '').trim().toLowerCase().contains(q));
}
