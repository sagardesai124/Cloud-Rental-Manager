import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../Model/Comunication_model/email_logtable.dart';
import '../../Model/TenantCommunication.dart';
import '../../Model/lease_communication.dart';
import '../../constant/constant.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
class EmailLogRepository {
  final String apiUrl = '${Api_url}/api/email-logs/tenant-email';



  Future<TenantCommunation> fetchEmailLog(String lease_id,{int page = 1,int limit =10,bool isTenant =false}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // The `id` header must carry the CALLER's own id: staff_id for a Staff
      // user, adminId for an Admin. This read staff_id unconditionally, which
      // is null for an Admin — the header went out as "CRM null", the server
      // rejected it, and the catch surfaced "Failed to Acknowledgement payment"
      // (a message copy-pasted from the payment repo) in place of the tenant's
      // communications. Staff was unaffected, which is why it went unnoticed.
      // Matches _actingId in repository/team_repo.dart.
      String? id = prefs.getString('role') == 'Staffmember'
          ? prefs.getString("staff_id")
          : prefs.getString("adminId");
      String? token = prefs.getString('token');

      String? ApiUrl = isTenant ? '${Api_url}/api/email-logs/tenant-email/$lease_id?page=$page&limit=$limit' :'$apiUrl/$lease_id?page=$page&limit=$limit';

      final response = await apiGet(
        Uri.parse('$ApiUrl'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
      );


      if (response.statusCode == 200) {
        return TenantCommunation.fromJson(json.decode(response.body));
      } else if (response.statusCode == 204) {
        return TenantCommunation(statusCode: 204, emails: [], totalEmails: 0, currentPage: 1, totalPages: 0);
      } else {
        throw Exception('Failed to Acknowledgement payment');
      }
    } catch (e) {
      logError('Error fetching email logs: $e');
      throw Exception('Failed to Acknowledgement payment');
    }
  }

}