// lib/TenantsModule/screen/Payment/nmi_keys_service.dart
// Service to fetch NMI keys (merchant ID and terminal ID) from API

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';

class NmiKeysService {
  /// Fetch NMI keys (merchant ID and terminal ID) from API
  /// GET /api/nmi-keys/nmi-keys/:admin_id
  Future<Map<String, dynamic>> fetchNmiKeys() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? tenantId = prefs.getString("tenant_id");
    String? role = prefs.getString("role");

    if (adminId == null || token == null) {
      throw Exception('Admin ID or token not found');
    }

    final url = Uri.parse('$Api_url/api/nmi-keys/nmi-keys/$adminId');

    // `id` header = the logged-in user's own id (web parity): the server only
    // honours adminId with an admin token. The company id stays in the URL,
    // and a tenant gets the document back without its secret keys.
    final String idHeader =
        (role == "Tenant" && tenantId != null && tenantId.isNotEmpty)
            ? tenantId
            : adminId;

    final response = await apiGet(
      url,
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $idHeader",
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // API response structure: { "statusCode": 200, "data": { "merchant_id": "...", ... } }
      // Return the inner data object
      Map<String, dynamic> extractedData;
      if (data['data'] != null) {
        extractedData = data['data'] as Map<String, dynamic>;
      } else {
        // Fallback: return the whole response if structure is different
        extractedData = data;
      }

      return extractedData;
    } else {
      throw Exception(
          'Failed to load NMI keys: ${response.statusCode} - ${response.body}');
    }
  }
}
