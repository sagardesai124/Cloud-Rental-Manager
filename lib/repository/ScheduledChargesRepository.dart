import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../Model/schduled_charge.dart';
import '../Model/charge_history_entry.dart';


class ScheduledChargesRepository {
  final String baseUrl = 'https://saas.cloudrentalmanager.com/api';

  Future<List<ScheduledCharges>> fetchScheduledCharges({String? leaseid}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String?  adminid = prefs.getString('adminId');
      String url = "";
      if(leaseid == null) {
        url = '$Api_url/api/charge/scheduled-charges/$adminid';
      } else {
        url = '$Api_url/api/charge/lease-scheduled-charges/$leaseid';
      }

      final response = await apiGet(Uri.parse(url), headers: <String, String>{
        "authorization" : "CRM $token",
        "id":"CRM $adminid",
        'Content-Type': 'application/json; charset=UTF-8',
      },);
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);

        // Parse the data array into a list of ScheduledCharges
        final List<dynamic> data = responseBody['data'];
        return data.map((json) => ScheduledCharges.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load scheduled charges');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  /// Change history (audit log) for one scheduled charge.
  /// GET /api/charge/scheduled-charges/{task_id}/history →
  /// { statusCode, data: [ {action, description, reason, by, at} ] }.
  /// Returns an empty list on any failure so the panel shows an empty state.
  Future<List<ChargeHistoryEntry>> fetchChargeHistory(String taskId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminid = prefs.getString('adminId');
      final response = await apiGet(
        Uri.parse('$Api_url/api/charge/scheduled-charges/$taskId/history'),
        headers: <String, String>{
          "authorization": "CRM $token",
          "id": "CRM $adminid",
          'Content-Type': 'application/json; charset=UTF-8',
        },
      );
      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        final List<dynamic> data = responseBody['data'] ?? [];
        return data.map((e) => ChargeHistoryEntry.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

   submitCharge(
      {
        String? leaseId,
        String? account,
        String? action_date,
        String? chargeType,
        String? amount,

        String? description,
        String? charge_id,
      }

      ) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? Id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");
    String? company_name = prefs.getString("companyName");
//if (!_formKey.currentState!.validate()) return;


    final url = charge_id == null
        ? Uri.parse("$Api_url/api/charge/scheduled-charges")
        : Uri.parse("$Api_url/api/charge/scheduled-charges/${charge_id}");

    final body = {
      "account": account,
      "action_date": action_date,
      "amount": double.tryParse(amount ?? "") ?? 0.0,
      "chargeType": chargeType,
      "company_name": company_name,
      "description": description,
    };

    final response = charge_id == null
        ? await apiPut(url, body: json.encode(body), headers: {
      "authorization": "CRM $token",
      "id": "CRM $Id",
      "Content-Type": "application/json",
    })
        : await apiPut(url, body: json.encode(body), headers: {
      "authorization": "CRM $token",
      "id": "CRM $Id",
      "Content-Type": "application/json",
    });

    if (response.statusCode == 200 || response.statusCode == 201) {
      return response.body;
      // Navigator.of(context).pop();
      //  setState(() {
      //    _futureleasenotes = fetchleasenotedata();
      //  });
      //widget.onSuccess();
    } else {

    }
  }

  Future<Map<String, dynamic>> deleteNote({
    required String noteid,
    String? reason,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');
      String? staffid = prefs.getString("staff_id");
      String? company_name = prefs.getString("companyName");
      final Uri uri = Uri.parse('$Api_url/api/charge/scheduled-charges/$noteid?company_name=$company_name');


      final http.Response response = await apiDelete(
        uri,
        headers: <String, String>{
          "authorization": "CRM $token",
          "id": "CRM $id",
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({"reason": reason}),
      );

      var responseData = json.decode(response.body);
      // print(renters_insurance_id);
      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: responseData["message"]);
        return json.decode(response.body);
      } else {
        Fluttertoast.showToast(msg: responseData["message"]);
        throw Exception('Failed to delete Insurance');
      }
    } catch (e) {
      throw Exception('Failed to delete Insurance: $e');
    }
  }
}
