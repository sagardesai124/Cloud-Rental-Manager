import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/TenantsModule/model/workorder_summery_model.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../model/workorder_model.dart';

class WorkOrderRepository {

  Future<List<WorkOrder>> fetchWorkOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final response = await apiGet(
      Uri.parse('${Api_url}/api/work-order/tenant_work/$id'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];

      return jsonResponse.map((data) => WorkOrder.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load work orders');
    }
  }
  // Future<Map<String, dynamic>> addWorkOrder({
  //    String? adminId,
  //    String? workSubject,
  //    String? staffMemberName,
  //    String? workCategory,
  //    String? workPerformed,
  //    String? status,
  //    String? rentalAddress,
  //    String? rentalUnit,
  //    String? tenant,
  //    bool? entry,
  //
  // }) async {
  //   // Constructing the request data
  //   final Map<String, dynamic> data = {
  //     'admin_id': adminId,
  //     'work_subject': workSubject,
  //     'staffmember_name': staffMemberName,
  //     'work_category': workCategory,
  //     'work_performed': workPerformed,
  //     'status': status,
  //     'rental_adress': rentalAddress,
  //     'rental_unit': rentalUnit,
  //     'entry_allowed': entry, // Assuming this is a boolean
  //     'statusUpdatedBy': tenant,
  //     'workOrderImage': [],
  //   };
  //
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? id = prefs.getString("tenant_id");
  //   String? admin_id = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //
  //   // Sending the request
  //   final http.Response response = await apiPost(
  //     Uri.parse('$Api_url/api/work-order/work-order'),
  //     headers: <String, String>{
  //       "authorization": "CRM $token",
  //       "id": "CRM $id",
  //       'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: jsonEncode(data),
  //   );
  //
  //   // Handling the response
  //   var responseData = json.decode(response.body);
  //
  //   if (responseData["statusCode"] == 200) {
  //     Fluttertoast.showToast(msg: responseData["message"]);
  //     return json.decode(response.body);
  //   } else {
  //     Fluttertoast.showToast(msg: responseData["message"]);
  //     throw Exception('Failed to add work order');
  //   }
  // }
  Future<Map<String, dynamic>> addWorkOrder({
    String? adminId,
    String? workSubject,
    String? staffMemberName,
    String? workCategory,
    String? workPerformed,
    String? status,
    String? rentalAddress,
    String? rentalUnit,
    String? tenant,
    String? rentalid,
    String? unitid,
 List? workOrder_images,
    bool? entry,
    String? notificationTime,
  }) async {
    // Constructing the request data
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'work_subject': workSubject,
      'staffmember_name': staffMemberName,
      'work_category': workCategory,
      'work_performed': workPerformed,
      'status': status,
      'rental_adress': rentalAddress,
      'rental_unit': rentalUnit,
      'entry_allowed': entry, // Assuming this is a boolean
      'statusUpdatedBy': tenant,
      'rental_id': rentalid,
      'unit_id': unitid,
      'workOrder_images': workOrder_images,
      'notificationTime':notificationTime,
    };

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    // Logging the request data

    // Sending the request
    final http.Response response = await apiPost(
      Uri.parse('$Api_url/api/work-order/work-order'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "workOrder":data,
        'notificationTime':notificationTime,
      }),
    );

    // Logging the response status and body

    // Handling the response
    var responseData = json.decode(response.body);

    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return responseData;
    } else {
      // One message only - the screen's catch renders it. Toasting here too
      // meant the screen's toast instantly overwrote the server's real reason.
      final String serverMessage = '${responseData["message"] ?? ''}'.trim();
      throw Exception(
          serverMessage.isNotEmpty ? serverMessage : 'Failed to add work order');
    }
  }

  static Future<WorkOrderData_summery> getworkorderSummary(String workorderId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final url = Uri.parse('$Api_url/api/work-order/workorder_details/$workorderId');
    final response = await apiGet(
        url,
        headers: {"authorization" : "CRM $token","id":"CRM $id",}
    );

    // Status check + guarded decode live in the shared helper; the bare
    // `jsonDecode` here used to throw an uncaught FormatException on a 200
    // carrying a proxy or gateway page. The shape handling below stays -
    // this endpoint genuinely answers in three different shapes.
    final decoded = workOrderDecodedBody(response.statusCode, response.body);
    final dynamic dataRaw = decoded["data"];
    Map<String, dynamic> data;
    if (dataRaw is List) {
      // `dataRaw[0] as Map<String, dynamic>` was a hard cast: a list holding
      // anything else threw a type error.
      final dynamic first = dataRaw.isNotEmpty ? dataRaw.first : null;
      data = first is Map<String, dynamic> ? first : {};
    } else if (dataRaw is Map<String, dynamic>) {
      // API may return data.result (e.g. from details) or flat object
      final result = dataRaw["result"];
      data = result is Map<String, dynamic> ? result : dataRaw;
    } else {
      data = {};
    }
    return WorkOrderData_summery.fromJson(data);
  }
  static Future<bool> updateworkorderSummary(
    Map<String, dynamic> workorder,
    String workorderId, {
    String? notificationTime,
    String? categoryId,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? token = prefs.getString('token');
    final url = Uri.parse('$Api_url/api/work-order/work-order/$workorderId');
    final body = <String, dynamic>{"workOrder": workorder};
    if (notificationTime != null) body['notificationTime'] = notificationTime;
    if (categoryId != null) body['category_id'] = categoryId;
    final response = await apiPut(
      url,
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(body),
    );
    // Was `throw Exception('Failed to update work order: ${response.body}')`,
    // which put the whole raw JSON payload into a user-facing toast. The other
    // three modules route failures through workOrderFetchErrorMessage for
    // exactly that reason; this now matches them.
    ensureWorkOrderSuccess(response.statusCode, response.body);
    return true;
  }
}
