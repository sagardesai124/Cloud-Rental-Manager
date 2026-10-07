import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

class GetAddressAdminPdfService {
  final String apiUrl = "${Api_url}/api/admin/admin_profile/";

  Future<profile> fetchAdminAddress() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffId = prefs.getString("staff_id");
    String? role = prefs.getString("role");
    // `id` header = the logged-in user's own id (web parity); company id stays in the URL.
    final String? idHeader =
        (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
            ? staffId
            : id;

    final response = await apiGet(
      Uri.parse('$apiUrl$id'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $idHeader",
      },
    );
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData["statusCode"] == 200) {
        return profile.fromJson(responseData["data"]);
      } else {
        throw Exception('Failed to load profile: Invalid status code');
      }
    } else {
      throw Exception('Failed to load profile');
    }
  }
}
