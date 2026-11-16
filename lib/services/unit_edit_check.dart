// Same spelling as the pages and repository use ("model", lower case); a
// "Model" import is a different library to Dart and its type would not match.
import '../model/unitsummery_propeties.dart';

/// Web's message when Edit Unit is saved without a change (PropDetails.jsx
/// and StaffPropertyDetail.jsx).
const String unitEditNoChangesMessage = 'No changes detected';

/// Like web's isUnitEditUnchanged (Units.jsx): true when the Edit Unit form
/// still matches the saved [unit], so nothing is sent and the form stays
/// open. Text is compared trimmed, and [photos] must be the same photos in
/// the same order. A form passes only the fields it edits; a null argument
/// is not compared. [newPhotos] is true when a photo was picked in the form
/// but is not part of [photos] (web counts a new file as a change).
///
/// The form shows bed and bath in dropdowns and rewrites a saved value that
/// is not one of the options (a saved "2" shows as "2 Bed"); an untouched
/// dropdown still counts as unchanged, as on web.
bool isUnitEditUnchanged(
  unit_properties unit, {
  String? unitNumber,
  String? address,
  String? sqft,
  String? bed,
  String? bath,
  List<String>? photos,
  bool newPhotos = false,
  List<String> bedOptions = const [],
  List<String> bathOptions = const [],
}) {
  if (newPhotos) return false;
  String t(String? v) => (v ?? '').trim();
  bool same(String? now, String? saved) => t(now) == t(saved);

  if (unitNumber != null && !same(unitNumber, unit.rentalunit)) return false;
  if (address != null && !same(address, unit.rentalunitadress)) return false;
  if (sqft != null && !same(sqft, unit.rentalsqft)) return false;
  if (bed != null &&
      !same(bed, unit.rentalbed) &&
      !same(bed, unitBedShown(t(unit.rentalbed), bedOptions))) {
    return false;
  }
  if (bath != null &&
      !same(bath, unit.rentalbath) &&
      !same(bath, unitBathShown(t(unit.rentalbath), bathOptions))) {
    return false;
  }
  if (photos != null) {
    final saved = unit.rentalImages ?? const <String>[];
    if (photos.length != saved.length) return false;
    for (var i = 0; i < photos.length; i++) {
      if (!same(photos[i], saved[i])) return false;
    }
  }
  return true;
}

/// What the Bed dropdown shows for a saved value (the page's
/// normalizeBedValue): an option as is, otherwise "<n> Bed" or "9+ Bed".
String unitBedShown(String saved, List<String> options) {
  if (saved.isEmpty || options.contains(saved)) return saved;
  final match = RegExp(r'(\d+)').firstMatch(saved);
  if (match == null) return saved;
  final beds = int.parse(match.group(1)!);
  if (beds >= 9) return '9+ Bed';
  if (beds > 0) return '$beds Bed';
  return saved;
}

/// What the Bath dropdown shows for a saved value (the page's
/// normalizeBathValue): an option as is, otherwise rounded to the nearest .5
/// as "<n> Bath", or "5+ Bath".
String unitBathShown(String saved, List<String> options) {
  if (saved.isEmpty || options.contains(saved)) return saved;
  final match = RegExp(r'(\d+\.?\d*)').firstMatch(saved);
  if (match == null) return saved;
  final baths = double.parse(match.group(1)!);
  if (baths >= 5) return '5+ Bath';
  final rounded = (baths * 2).round() / 2;
  if (rounded > 0 && rounded < 5) {
    return '${rounded.toStringAsFixed(rounded.truncateToDouble() == rounded ? 0 : 1)} Bath';
  }
  return saved;
}
