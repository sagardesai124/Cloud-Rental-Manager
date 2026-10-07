import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../Model/vendor.dart';


class VendorRepository {
  final String baseUrl;

  VendorRepository({required this.baseUrl});

  /// Returns null on success, otherwise the message to show the user.
  ///
  /// Web parity (AddVendor.jsx `handleResponse`): the create/update routes
  /// answer HTTP **201** with `statusCode: 201` and a real reason whenever the
  /// phone number or email is already taken. Keying off the HTTP status alone
  /// collapsed those into a bare "Failed to add vendor" with no explanation,
  /// while web shows the server's own wording.
  static String? _saveError(http.Response response, String fallback) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    final Map<String, dynamic>? body =
        decoded is Map<String, dynamic> ? decoded : null;
    final int code = body?["statusCode"] is int
        ? body!["statusCode"] as int
        : response.statusCode;
    if (code == 200) return null;
    // Suppressed in release by the zone-level print filter in main().
    print('[vendor save] HTTP ${response.statusCode} body=${response.body}');
    final String message = body?["message"]?.toString().trim() ?? '';
    return message.isNotEmpty ? message : fallback;
  }

  Future<String?> addVendor(Vendor vendor) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final url = Uri.parse('$Api_url/api/vendor/vendor');
    final response = await apiPost(
      url,
        headers: {"authorization" : "CRM $token","id":"CRM $id","Content-Type":"application/json",},

      // JSON, not a form-encoded Map. `http` encodes a Map body via
      // `cast<String, String>()`, which throws a TypeError the moment it reads
      // a non-String value — and `is_1099` is a bool, so every save threw
      // before it left the device and surfaced as a bare "Failed to ..." from
      // the catch block. Web posts JSON here too.
      body: jsonEncode(vendor.toJson()),
    );
    return _saveError(response, 'Failed to add vendor');
  }
  Future<List<Vendor>> getVendors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffId = prefs.getString("staff_id");
    String? role = prefs.getString("role");
    // `id` header = the logged-in user's own id (web parity); company id stays in
    // the URL. Staff reaches this from the shared Settings screen.
    final String? idHeader =
        (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
            ? staffId
            : id;
    final url = Uri.parse('$Api_url/api/vendor/vendors/$id');
    final response = await apiGet(url,  headers: {"authorization" : "CRM $token","id":"CRM $idHeader",},);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body)["data"];
      return data.map((json) => Vendor.fromJson(json)).toList();
    } else {
      return [];
    }
  }
  Future<Vendor> getVendor(String vender_id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final url = Uri.parse('$Api_url/api/vendor/get_vendor/$vender_id');
    final response = await apiGet(url,  headers: {"authorization" : "CRM $token","id":"CRM $id",},);

    if (response.statusCode == 200) {
      final Map<String,dynamic> data = jsonDecode(response.body)["data"];
      return  Vendor.fromJson(data);
    } else {
      return Vendor();
    }
  }
  /// Masked Tax ID for the edit form, fetched SEPARATELY from [getVendor].
  ///
  /// Web parity (AddVendor.jsx): the base vendor is loaded without
  /// `include_tax_id`, then the tax id is requested on its own. The server
  /// hides `tax_id` by default and answers 403 for any role other than
  /// admin/super_admin, so folding this into the main request would blank the
  /// whole edit form for Staff instead of just omitting one field.
  ///
  /// Returns null when unavailable (403, missing, or any error) — the caller
  /// simply shows no current-value hint.
  Future<String?> getVendorTaxId(String vender_id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      final url = Uri.parse(
          '$Api_url/api/vendor/get_vendor/$vender_id?include_tax_id=true');
      final response = await apiGet(url, headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });
      // Suppressed in release by the zone-level print filter in main().
      print('[tax id] HTTP ${response.statusCode} body=${response.body}');
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded["data"] : null;
      if (data is! Map) return null;
      final value = data["tax_id"]?.toString().trim() ?? '';
      print('[tax id] parsed value="$value"');
      return value.isEmpty ? null : value;
    } catch (e) {
      print('[tax id] exception: $e');
      return null;
    }
  }

  /// Returns null on success, otherwise the message to show. See [addVendor].
  Future<String?> update_vendor(Vendor vendor,String vender_id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final url = Uri.parse('$Api_url/api/vendor/update_vendor/${vender_id}');
    final response = await apiPut(
      url,
      headers: {"authorization" : "CRM $token","id":"CRM $id","Content-Type":"application/json",},

      // JSON, not a form-encoded Map. `http` encodes a Map body via
      // `cast<String, String>()`, which throws a TypeError the moment it reads
      // a non-String value — and `is_1099` is a bool, so every save threw
      // before it left the device and surfaced as a bare "Failed to ..." from
      // the catch block. Web posts JSON here too.
      body: jsonEncode(vendor.toJson()),
    );
    return _saveError(response, 'Failed to edit vendor');
  }
  Future<bool> DeleteVender({
    required String? vender_id,
    String? reason
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final http.Response response = await apiDelete(
      Uri.parse('$Api_url/api/vendor/delete_vendor/${vender_id}'),
        headers: {"authorization" : "CRM $token","id":"CRM $id",},
        body: jsonEncode({"reason":reason})
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return true;

    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to add property type');
      return false;
    }
  }

}
