import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/RentPastDueModel.dart';
import 'package:three_zero_two_property/Model/WorkOrderSetting.dart';

import '../constant/constant.dart';

Future<Data> fetchWorkOrderSetting() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  String? id = prefs.getString("adminId");
  String url = '${Api_url}/api/work-order/work-defaults/${id}';

  try {
    final response = await apiGet(
      Uri.parse(url),
      headers: {
        "authorization": "CRM $token",
        "id":"CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic>? jsonData = json.decode(response.body);
      return Data.fromJson(jsonData!["data"]);

    } else {
      throw Exception('Failed to work order setting');
    }
  } catch (error) {
    logError('Error work order setting: $error');
    throw Exception('Error work order setting');
  }
}


Future<Data> fetchWorkOrderSettingstaff() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  String? adminid = prefs.getString("adminId");
  String? id = prefs.getString("staff_id");
  String url = '${Api_url}/api/work-order/work-defaults/${adminid}';

  try {
    final response = await apiGet(
      Uri.parse(url),
      headers: {
        "authorization": "CRM $token",
        "id":"CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic>? jsonData = json.decode(response.body);
      return Data.fromJson(jsonData!["data"]);

    } else {
      throw Exception('Failed to work order setting');
    }
  } catch (error) {
    logError('Error work order setting: $error');
    throw Exception('Error work order setting');
  }
}

/// Tenant portal: the account's Work Defaults (web TAddWork.jsx
/// fetchWorkDefaults). The `id` header carries the tenant's own id.
Future<Data> fetchWorkOrderSettingTenant() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? token = prefs.getString('token');
  String? adminid = prefs.getString("adminId");
  String? id = prefs.getString("tenant_id");
  final response = await apiGet(
    Uri.parse('${Api_url}/api/work-order/work-defaults/${adminid}'),
    headers: {
      "authorization": "CRM $token",
      "id": "CRM $id",
      'Content-Type': 'application/json; charset=UTF-8',
    },
  );
  if (response.statusCode == 200) {
    final Map<String, dynamic>? jsonData = json.decode(response.body);
    return Data.fromJson(jsonData!["data"]);
  }
  throw Exception('Failed to load work defaults');
}
