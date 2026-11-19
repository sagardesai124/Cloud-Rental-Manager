import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constant/constant.dart';
import '../services/api_helpers.dart';

/// The facts the Tenant Statement letterhead prints, fetched when the
/// statement is exported, like web (LeaseFinancialTab →
/// loadStatementHeaderFacts):
///   - company: GET /api/tenantRental/companyName/:admin_id (company_name,
///     company_dba, brand_logo, mailing_* / office_*, phone numbers);
///   - tenants + property: GET /api/leases/lease_tenant/:lease_id `data`
///     (tenants[], rental_adress, rental_city, rental_state, rental_zip).
/// A failed fetch only leaves that block off the statement, like web; it
/// never stops the export. Without the company reply the name and logo saved
/// at sign-in are used, as web falls back to the signed-in company's.
Future<({Map<String, dynamic> company, Map<String, dynamic> leaseTenant})>
    loadTenantStatementFacts({
  required String leaseId,
  required bool asStaff,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');
  final adminId = prefs.getString('adminId') ?? '';
  final staffId = prefs.getString('staff_id') ?? '';
  final headers = {
    'authorization': 'CRM $token',
    'id': 'CRM ${asStaff && staffId.isNotEmpty ? staffId : adminId}',
  };

  Future<Map<String, dynamic>?> getJson(String path) async {
    try {
      final response =
          await apiGet(Uri.parse('$Api_url/api/$path'), headers: headers);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  final replies = await Future.wait([
    adminId.isEmpty
        ? Future<Map<String, dynamic>?>.value(null)
        : getJson('tenantRental/companyName/$adminId'),
    leaseId.isEmpty
        ? Future<Map<String, dynamic>?>.value(null)
        : getJson('leases/lease_tenant/$leaseId'),
  ]);
  final company = replies[0] ??
      <String, dynamic>{
        'company_name': prefs.getString('companyName'),
        'brand_logo': prefs.getString('brand_logo'),
      };
  final leaseTenant = replies[1]?['data'];
  return (
    company: company,
    leaseTenant: leaseTenant is Map<String, dynamic>
        ? leaseTenant
        : <String, dynamic>{},
  );
}

final RegExp _logoDataUri =
    RegExp(r'^data:image/(png|jpe?g|webp);base64,', caseSensitive: false);

/// The company logo's bytes for the PDF (PNG, JPEG or WEBP), or null, like
/// web's resolveStatementLogo: a stored data URI is decoded, an http(s) URL
/// is fetched, and anything missing, unsupported or unreachable prints the
/// company's name instead.
Future<Uint8List?> resolveStatementLogo(String? logo) async {
  final src = (logo ?? '').trim();
  if (src.isEmpty) return null;
  if (src.startsWith('data:')) {
    final match = _logoDataUri.firstMatch(src);
    if (match == null) return null;
    try {
      return base64Decode(src.substring(match.end).replaceAll(RegExp(r'\s'), ''));
    } catch (_) {
      return null;
    }
  }
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(src)) return null;
  try {
    final response = await http.get(Uri.parse(src));
    if (response.statusCode != 200) return null;
    final type = (response.headers['content-type'] ?? '').toLowerCase();
    if (!RegExp(r'^image/(png|jpe?g|webp)').hasMatch(type)) return null;
    return response.bodyBytes;
  } catch (_) {
    return null;
  }
}
