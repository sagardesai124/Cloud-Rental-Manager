import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart'
    show moveInSuccessMessage;

class LeaseMoveoutRepository {
  // The server takes the caller's OWN id: staff_id for Staff, adminId
  // otherwise. A staff_id left behind by an earlier Staff session must not
  // be sent for an Admin (401).
  String _idHeader(SharedPreferences prefs) {
    final String? staffId = prefs.getString('staff_id');
    return prefs.getString('role') == 'Staffmember' &&
            staffId != null &&
            staffId.isNotEmpty
        ? staffId
        : prefs.getString('adminId') ?? '';
  }


  Future<Map<String, dynamic>> addMoveoutTenant({
    required String? adminId,
    required String? tenantId,
    required String? leaseId,
    required String? moveoutNoticeGivenDate,
    required String? moveoutDate,
    // { ends_lease, ends_on, reason } — see lease_end_decision.dart.
    Map<String, dynamic>? leaseEnd,

  }) async {
    // Dates go as yyyy-MM-dd: the server reads "05-10-2026" as May 10.
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'tenant_id': tenantId,
      'lease_id': leaseId,
      'moveout_notice_given_date':
          reverseFormatDate(moveoutNoticeGivenDate ?? ''),
      'moveout_date': reverseFormatDate(moveoutDate ?? ''),
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
   // String?  id = prefs.getString('adminId');
    // lease_moveout was retired on the server (404); the Admin screens already
    // use lease_multiplemoveout, which takes a list of tenants.
    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/moveout/lease_multiplemoveout/$leaseId'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM ${_idHeader(prefs)}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "moveoutTenants": [data],
        if (leaseEnd != null) "leaseEnd": leaseEnd,
      }),
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);

    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to add property type');
    }
  }
  Future<Map<String, dynamic>> addMoveInTenant({
    required String? adminId,
    required String? tenantId,
    required String? leaseId,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'tenant_id': tenantId,
      'lease_id': leaseId,

    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final http.Response response = await apiPut(
      Uri.parse('${Api_url}/api/moveout/lease_movein/$leaseId'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM ${_idHeader(prefs)}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      // Same success text as web handleMoveIn.
      Fluttertoast.showToast(msg: moveInSuccessMessage);
      return json.decode(response.body);

    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to add property type');
    }
  }
}
