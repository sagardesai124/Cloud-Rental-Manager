import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../Model/Comunication_model/email_logtable.dart';
import '../../Model/lease_communication.dart';
import '../../constant/constant.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
class EmailLogRepository {
  final String apiUrl = '${Api_url}/api/email-logs/emaillogs_lease';



  Future<lease_communications> fetchEmailLog(String lease_id,{int page = 1,int limit =10,bool isTenant =false}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? staffId = prefs.getString("staff_id");
      String? role = prefs.getString("role");
      // `id` header = the logged-in user's own id (web parity).
      final String? idHeader =
          (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
              ? staffId
              : id;

      String? ApiUrl = isTenant ? '${Api_url}/api/email-logs/tenant-email/$lease_id?page=$page&limit=$limit' :'$apiUrl/$lease_id?page=$page&limit=$limit';

      final response = await apiGet(
        Uri.parse('$ApiUrl'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $idHeader",
        },
      );


      if (response.statusCode == 200) {
        return lease_communications.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to Acknowledgement payment');
      }
    } catch (e) {
      logError('Error fetching email logs: $e');
      throw Exception('Failed to Acknowledgement payment');
    }
  }

}