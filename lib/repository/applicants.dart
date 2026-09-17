import 'dart:convert';
import 'package:d_chart/d_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/lease.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../model/ApplicantModel.dart';

class ApplicantRepository {

  static Future<Map<String, dynamic>> postApplicant({
    required Datum applicantData,
  }) async {
    final Map<String, dynamic> postData = applicantData.toJson();
    // Web parity: the web sends these flags with the add payload.
    postData['is_web'] = true;
    postData['user_active_recently'] = true;

    // Log the postData for debugging
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiPost(
      Uri.parse('$Api_url/api/applicant/applicant'),
      headers: <String, String>{
        "id": "CRM $id",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(postData),
    );
    if (response.statusCode == 200) {
      Fluttertoast.showToast(msg: 'Applicant Added Successfully');
      return jsonDecode(response.body);
    } else if (response.statusCode >= 200 && response.statusCode < 300) {
      // A rejected add is NOT an HTTP error here: a duplicate email or phone
      // comes back as 203 with the reason in the body, and the add screens
      // already read `response['statusCode'] == 203` and show that message.
      // Throwing on it made their handler unreachable, so a duplicate saved
      // nothing and said nothing. Any other 2xx is returned for the same
      // reason rather than being guessed at here.
      return jsonDecode(response.body);
    } else {
      // Log the response body for debugging
      throw Exception('Failed to post applicant and lease data');
    }
  }

  Future<List<Datum>> fetchApplicants() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('$Api_url/api/applicant/applicant/$id'), headers: {
      "authorization": "CRM $token",
      "id": "CRM $id",
    });
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> applicantJson = data['data'];
      return applicantJson.map((json) => Datum.fromJson(json)).toList();
    } else {
      // Was `return []`, which made a 500 or a 403 look exactly like "no
      // applicants yet" - the list screen showed its empty-state artwork and
      // the user had no idea the load had failed. Offline is handled higher
      // up by NetworkRetryState/NoInternetView; this covers server errors.
      throw Exception(friendlyErrorMessage(response.body));
    }
  }

  static Future<Map<String, dynamic>> updateApplicants({
    required String applicantId,
    required Map<String, dynamic> applicantData,
  }) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final response = await apiPut(
      Uri.parse('$Api_url/api/applicant/applicant/$applicantId'),
      headers: <String, String>{
        "id": "CRM $id",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      // Web parity: same wrapper + flags the web sends on update.
      body: jsonEncode({
        "applicant": applicantData,
        "is_web": true,
        "user_active_recently": true,
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Accept any 2xx, not just 200: a successful update can come back as
      // 201 (ApplicantService returns statusCode 201 on one of its success
      // paths, and the route mirrors it into the HTTP status). The old
      // `== 200` therefore threw on a save that had actually worked, and the
      // caller's success toast was skipped.
      return jsonDecode(response.body);
    } else {
      // Log the response body for debugging
      throw Exception('Failed to update applicant data');
    }
  }

  Future<Map<String, dynamic>> DeleteApplicant(
      {required String? Applicantid,String? reason}) async {
    // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final http.Response response = await apiDelete(
      Uri.parse('$Api_url/api/applicant/applicant/$Applicantid'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
        body: jsonEncode({"reason":reason})
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
}
