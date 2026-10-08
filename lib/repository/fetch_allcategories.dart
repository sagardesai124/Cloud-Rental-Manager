import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../Model/All_categories_model.dart';
import '../constant/constant.dart';

class FetchAllcategories {
  Future<List<allcategories_model>> fetchAllCategories() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffId = prefs.getString("staff_id");
    String? tenantId = prefs.getString("tenant_id");
    String? vendorId = prefs.getString("vendor_id");
    String? role = prefs.getString("role");
    // The id header is the signed-in user's own id — the server only honours
    // adminId with an admin token. Tenant and Vendor work-order screens load
    // categories too. The company id stays in the URL.
    String? ownId = switch (role) {
      "Staffmember" => staffId,
      "Tenant" => tenantId,
      "Vendor" => vendorId,
      _ => null,
    };
    String? id = (ownId != null && ownId.isNotEmpty) ? ownId : adminId;

    final response = await apiGet(
      Uri.parse('${Api_url}/api/settings/allCategories/$adminId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => allcategories_model.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load categories');
    }
  }
}