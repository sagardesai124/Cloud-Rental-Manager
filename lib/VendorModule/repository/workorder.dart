import 'dart:convert';
import 'dart:developer';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/workorder_summery_model.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../model/workorder_model.dart';

class WorkOrderRepository {

 //  Future<List<WorkOrder>> fetchWorkOrders() async {
 //    SharedPreferences prefs = await SharedPreferences.getInstance();
 //    String? id = prefs.getString("vendor_id");
 //    String? admin_id = prefs.getString("adminId");
 //    String? token = prefs.getString('token');
 //
 //    final response = await apiGet(
 //      Uri.parse('${Api_url}/api/work-order/vendor_work/$id'),
 //      headers: {
 //        'authorization': 'CRM $token',
 //        'id': 'CRM $id',
 //      },
 //    );
 // // log(response.body);
 //    if (response.statusCode == 200) {
 //      List jsonResponse = json.decode(response.body)['data'];
 //
 //      return jsonResponse.map((data) => WorkOrder.fromJson(data)).toList();
 //    } else {
 //      throw Exception('Failed to load work orders');
 //    }
 //  }
  Future<List<WorkOrder>> fetchWorkOrders() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');


    final response = await apiGet(
      Uri.parse('${Api_url}/api/work-order/vendor_work/$id'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );
    // log(response.body);
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];

      return jsonResponse.map((data) => WorkOrder.fromJson(data)).toList();
    } else if (json.decode(response.body)['message'] ==
        'No work orders found for the specified vendor.') {
      return [];
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
        "id": "CRM ${prefs.getString('vendor_id') ?? id}",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({"workOrder":data}),
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

  // Vendor dashboard chart data — "last 12 months" stats.
  // GET /api/vendor/dashboard_workorder_stats/{vendor_id}/{admin_id}
  // Returns data.months: [{ month, year, received, overdue }, ...] already
  // computed by the backend, so the chart just renders what comes back.
  Future<List<MonthStat>> fetchVendorWorkOrderStats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final response = await apiGet(
      Uri.parse('${Api_url}/api/vendor/dashboard_workorder_stats/$id/$admin_id'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List months = decoded['data']?['months'] ?? [];
      return months.map((m) => MonthStat.fromJson(m)).toList();
    } else {
      throw Exception('Failed to load vendor work order stats: ${response.body}');
    }
  }

  static Future<WorkOrderData_summery> getworkorderSummary(String workorderId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final url = Uri.parse('$Api_url/api/work-order/workorder_details/$workorderId');
    final response = await apiGet(
        url,
        headers: {"authorization" : "CRM $token","id":"CRM $id",}
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body)["data"];
      return WorkOrderData_summery.fromJson(data);
    } else {
      // Never surface the raw body - it leaks the JSON payload to the UI.
      throw Exception(workOrderFetchErrorMessage(response.body));
    }
  }
  static Future<bool> updateworkorderSummary(Map<String,dynamic> workorder,String workorderId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Header `id` (used below) must be the vendor's OWN id (web parity).
    // Was "tenant_id", which is null for a vendor → auth failed / 500.
    String? id = prefs.getString("vendor_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    //http://localhost:4000/api/work-order/work-order/1721286680248
    final url = Uri.parse('$Api_url/api/work-order/work-order/$workorderId');
    final response = await apiPut(
        url,
        headers: {"authorization" : "CRM $token","id":"CRM $id", 'Content-Type': 'application/json; charset=UTF-8',},
        body: jsonEncode(workOrderUpdateBody(workorder))
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body)["data"];
      return true;
    } else {
      // Never surface the raw body - it leaks the JSON payload to the UI.
      throw Exception(workOrderFetchErrorMessage(response.body));
    }
  }
}

/// One bar-group in the vendor dashboard "Statistics" chart (one month).
/// [received] = new work orders that month, [overdue] = overdue that month.
class MonthStat {
  final String month;
  final int year;
  final int received;
  final int overdue;

  MonthStat({
    required this.month,
    required this.year,
    required this.received,
    required this.overdue,
  });

  factory MonthStat.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) =>
        v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return MonthStat(
      month: json['month']?.toString() ?? '',
      year: _toInt(json['year']),
      received: _toInt(json['received']),
      overdue: _toInt(json['overdue']),
    );
  }
}
