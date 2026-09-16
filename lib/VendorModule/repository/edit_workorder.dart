import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:three_zero_two_property/constant/constant.dart';

import '../model/Edit_workorder.dart';
/*import '../model/workordr.dart';*/

class WorkOrderRepository {


/*
  Future<List<Data>> fetchWorkOrders() async {
    // Retrieve admin ID and token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    // Define the URL and headers for the request
    final response = await apiGet(
      Uri.parse('$Api_url/api/work-order/work-orders/$id'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM ${prefs.getString("vendor_id") ?? id}',
      },
    );

    // Check the response status
    //print(response.body);
    if (response.statusCode == 200) {
      // Parse the JSON response
      List jsonResponse = json.decode(response.body)['data'];
      // Map the JSON data to List<Data> and return
      return jsonResponse.map((data) => Data.fromJson(data)).toList();
    } else {
      // Throw an exception if the request failed
      throw Exception('Failed to load work orders');
    }
  }
*/


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
    List<String>? workOrderImages,
    bool? entry,
    String? vendorId,
    String? vendorNotes,
    String? priority,
    // String, not bool: the server declares work_charge_to as a String and web
    // sends "Tenant" or "" (AddWorkorder.jsx). Sending a bool here meant the
    // field was stored as "false" no matter what the user picked.
    String? workChargeTo,
    String? date,
    bool? isBillable,
    List<Map<String, dynamic>>? parts,
  }) async {
    // Constructing the request data
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'work_subject': workSubject,
      'staffmember_name': staffMemberName,
      'work_category': workCategory,
      'work_performed': workPerformed,
      'status': status,
      'rental_address': rentalAddress,
      'rental_unit': rentalUnit,
      'entry_allowed': entry, // Assuming this is a boolean
      'tenant_id': tenant,
      'rental_id': rentalid,
      'unit_id': unitid,
      'workOrder_images': workOrderImages,
      'vendor_id': vendorId,
      'vendor_notes': vendorNotes,
      'priority': priority,
      'work_charge_to': workChargeTo,
      'date': date,
      'is_billable': isBillable,
      // 'parts': parts,
    };

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Logging the request data
    //  print('Request data: $data');

    // Sending the request
    //print(jsonEncode({"workOrder": data}));
    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/work-order/work-order'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('vendor_id') ?? id}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({"workOrder": data,'parts': parts,}),
    );


    //print('Response status: ${response.statusCode}');
    // print('Response body: ${response.body}');


    var responseData = json.decode(response.body);

    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return responseData;
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to add work order');
    }
  }

  Future<EditData> fetchWorkordersDetails(String workorderId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String?  id = prefs.getString('vendor_id');
    final response = await apiGet(Uri.parse('${Api_url}/api/work-order/workorder_details/$workorderId'),
      headers: {"authorization" : "CRM $token",
        "id":"CRM $id",},); // Update with your actual API URL
    //print('hello${response.body}');
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      // List leasesJson = jsonResponse['data'];
      return  EditData.fromJson(jsonResponse['data']);
    } else {
      throw Exception('Failed to load workorder');
    }
  }

  Future<Map<String, dynamic>> EditWorkOrder({
    String? adminId,
    String? workOrderid,
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
    List<String>? workOrderImages,
    bool? entry,
    String? vendorId,
    String? vendorNotes,
    String? priority,
    // String, not bool: the server declares work_charge_to as a String and web
    // sends "Tenant" or "" (AddWorkorder.jsx). Sending a bool here meant the
    // field was stored as "false" no matter what the user picked.
    String? workChargeTo,
    String? date,
    bool? isBillable,
    List<Map<String, dynamic>>? parts,
    String? notificationTime,
  }) async {
    // Constructing the request data
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'workOrder_id': workOrderid,
      'work_subject': workSubject,
      'staffmember_name': staffMemberName,
      'work_category': workCategory,
      'work_performed': workPerformed,
      'status': status,
      'rental_address': rentalAddress,
      'rental_unit': rentalUnit,
      'entry_allowed': entry, // Assuming this is a boolean
      'tenant_id': tenant,
      'rental_id': rentalid,
      'unit_id': unitid,
      'workOrder_images': workOrderImages,
      'vendor_id': vendorId,
      'vendor_notes': vendorNotes,
      'priority': priority,
      'work_charge_to': workChargeTo,
      'date': date,
      'is_billable': isBillable,
      'notificationTime':notificationTime,
      // 'parts': parts,
    };

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');


    final http.Response response = await apiPut(
      Uri.parse('${Api_url}/api/work-order/work-order/$workOrderid'),
      headers: <String, String>{
        "authorization": "CRM $token",
        // Header `id` = the vendor's OWN id (web parity); was "CRMss" (typo)
        // which sent a malformed auth prefix.
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        "workOrder": data,
        'parts': parts,
        'notificationTime':notificationTime,
      }),
    );

    // print('Response body: ${response.body}');
    // print(workOrderid);
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      // No success toast here on purpose. Edit_workorders.dart already shows
      // its own styled confirmation in the `.then(...)` after this call, so
      // raising the server's raw `message` as well put TWO toasts on screen at
      // once when saving — the server's "Work-Order updated Successfully" and
      // the screen's "Work order updated successfully". The Admin and Staff
      // copies of this method suppress it for the same reason (see
      // repository/workorder.dart and
      // StaffModule/repository/repository/workorder.dart), so Vendor now
      // matches them. The failure toast below stays: that `throw` is caught by
      // the screen's `.catchError`, which builds its own message from it.
      return responseData;
    } else {
      // Single-owner messaging: no toast here. All five EditWorkOrder call
      // sites already show their own styled failure toast built with
      // friendlyErrorMessage(e), so raising the server's message here too put
      // two messages on screen for one save - the useful one followed by a
      // generic one. The server's reason rides the exception instead, and
      // friendlyErrorMessage passes it straight through, so the single
      // remaining toast now says why the save failed. A transport error still
      // resolves to the standard network message inside that same helper.
      throw Exception(responseData["message"] ?? 'Failed to update work order');
    }
  }

  Future<Map<String, dynamic>> DeleteWorkOrder({
    required String? workOrderid
  }) async {

    //print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String?  id = prefs.getString('adminId');

    final http.Response response = await apiDelete(
      Uri.parse('$Api_url/api/work-order/delete_workorder/$workOrderid'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id":"CRM ${prefs.getString('vendor_id') ?? id}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );
    var responseData = json.decode(response.body);
    //  print(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);

    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to delete workorder');
    }
  }

}
