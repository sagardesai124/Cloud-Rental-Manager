import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/application_edit_rules.dart';

/// Whether a resident's Date of Birth is required on this application, read
/// the way web's ApplicantForm loads it (loadTenantApplicationRuntime): the
/// company's step configurations, replaced by the property owner's effective
/// application rules when the applicant's property has an owner. A call
/// that fails keeps what was loaded before it; with nothing loaded the date
/// is required, like web. [asStaff] sends the Staff member's own id.
Future<bool> fetchResidentDobRequired({
  required Map<String, dynamic> raw,
  required bool asStaff,
}) async {
  String text(Object? v) => v == null ? '' : v.toString().trim();

  final adminId = text(raw['admin_id']);
  if (adminId.isEmpty) return true;

  final prefs = await SharedPreferences.getInstance();
  final ownId = asStaff ? prefs.getString('staff_id') : prefs.getString('adminId');
  final headers = {
    'id': 'CRM $ownId',
    'authorization': 'CRM ${prefs.getString('token')}',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  // The `data` of a { statusCode: 200, data } reply, or null.
  Future<Object?> dataOf(String path) async {
    final http.Response response =
        await apiGet(Uri.parse('$Api_url/api/$path'), headers: headers);
    if (response.statusCode != 200) return null;
    final body = json.decode(response.body);
    if (body is! Map || body['statusCode'] != 200) return null;
    return body['data'];
  }

  var required = true;
  try {
    final company = await dataOf('tenant/step-configurations/$adminId');
    if (company != null) required = residentDobRequired(company);
  } catch (e) {
    logError('Application rules: step configurations: $e');
  }

  final properties = raw['properties'];
  final propertyId = [
    text(raw['selected_property']),
    text(raw['rental_id']),
    if (properties is List && properties.isNotEmpty && properties.first is! Map)
      text(properties.first),
  ].firstWhere((id) => id.isNotEmpty, orElse: () => '');
  if (propertyId.isEmpty) return required;

  try {
    final summary = await dataOf('rentals/rental_summary/$propertyId');
    final row = summary is List && summary.isNotEmpty ? summary.first : summary;
    final ownerId = row is Map ? text(row['rentalowner_id']) : '';
    if (ownerId.isEmpty) return required;
    final effective = await dataOf(
        'property-owner-overrides/effective/application-rules/$ownerId?admin_id=$adminId');
    if (effective is Map) {
      required = residentDobRequired(effective['stepConfigurations'] ?? const {});
    }
  } catch (e) {
    logError('Application rules: owner rules: $e');
  }
  return required;
}
