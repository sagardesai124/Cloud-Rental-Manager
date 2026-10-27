import 'dart:convert';
import 'dart:io';
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
    List<Map<String,dynamic>>? multitenantdata,
     List<String>? fileDescriptions,
     List<File>? selectedFiles,
    // { ends_lease, ends_on, reason } — see lease_end_decision.dart.
    Map<String, dynamic>? leaseEnd,

  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'tenant_id': tenantId,
      'lease_id': leaseId,
      'moveout_notice_given_date':  moveoutNoticeGivenDate!,
      'moveout_date': moveoutDate!,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/moveout/lease_multiplemoveout/$leaseId'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM ${_idHeader(prefs)}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "moveoutTenants": multitenantdata,
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
  Future<Map<String, dynamic>> addMoveoutTenantfromlease({
    required String? adminId,
    required String? tenantId,
    required String? leaseId,
    required String? moveoutNoticeGivenDate,
    required String? moveoutDate,
    List<Map<String,dynamic>>? multitenantdata,
    List<String>? fileDescriptions,
    List<File>? selectedFiles,
    // { ends_lease, ends_on, reason } — see lease_end_decision.dart.
    Map<String, dynamic>? leaseEnd,

  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'tenant_id': tenantId,
      'lease_id': leaseId,
      'moveout_notice_given_date':  moveoutNoticeGivenDate!,
      'moveout_date': moveoutDate!,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    final uri = Uri.parse('${Api_url}/api/moveout/lease_multiplemoveout/$leaseId');
    var request = http.MultipartRequest('POST', uri);

    // Headers
    request.headers.addAll({
      "authorization": "CRM $token",
      "id": "CRM ${_idHeader(prefs)}",
      "Content-Type": "multipart/form-data",
    });

    // Attach JSON data
    Map<String, dynamic> jsonData = {
      "moveoutTenants": multitenantdata,
      "descriptions": fileDescriptions,
      if (leaseEnd != null) "leaseEnd": leaseEnd,
    };
    request.fields['data'] = jsonEncode(jsonData);

    // Attach files
    for (int i = 0; i < selectedFiles!.length; i++) {
      File file = selectedFiles![i];
      String filename = file.path.split('/').last;

      request.files.add(
        await http.MultipartFile.fromPath(
          'moveout_documents',
          file.path,
        // or image/jpeg, pdf, etc.
          filename: filename,
        ),
      );
    }

    // Send the request
    final response = await apiSend(request);
    final responseBody = await http.Response.fromStream(response);
    var responseData = json.decode(responseBody.body);


    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return responseData;
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to add moveout tenant with files');
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
