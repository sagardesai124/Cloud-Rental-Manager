import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/Summary/applicant_summery2.dart';

class ApplicantSummeryRepository {
  /// Web-parity save: posts the new-schema application payload (flat object
  /// + arrays) straight to /applicant/application/{id}, exactly like web.
  Future<bool> saveApplicationRaw(
      Map<String, dynamic> payload, String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    try {
      final response = await apiPost(
        Uri.parse('$Api_url/api/applicant/application/$applicantId'),
        headers: {
          'Content-Type': 'application/json',
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
        body: jsonEncode(payload),
      );
      var responseData = jsonDecode(response.body);
      if (response.statusCode == 200 && responseData['statusCode'] == 200) {
        Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Application saved successfully');
        return true;
      }
      Fluttertoast.showToast(
          msg: responseData['message'] ?? 'Failed to save application');
      return false;
    } catch (error) {
      logError('saveApplicationRaw exception: $error');
      Fluttertoast.showToast(msg: 'An error occurred');
      return false;
    }
  }

  Future<bool> addApplicantSummaryForm(Data data, String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    try {
      final response = await apiPost(
        Uri.parse('$Api_url/api/applicant/application/$applicantId'),
        headers: {
          'Content-Type': 'application/json',
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
        body: jsonEncode(data.toJson()),
      );

      var responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['statusCode'] == 200) {
          // No success toast here on purpose. The calling screen already shows its
          // own confirmation for this action, so raising the server's message as
          // well put TWO toasts on screen at once. The screen owns the success
          // message (consistent wording/styling); this repository owns only the
          // failure message below, which the screen has no other source for.
          return true;
        } else {
          Fluttertoast.showToast(
              msg: responseData['message'] ?? 'Failed to add tenant');
          return false;
        }
      } else {
        Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Failed to add tenant');
        return false;
      }
    } catch (error) {
      logError('Exception occurred: $error');
      Fluttertoast.showToast(msg: 'An error occurred');
      return false;
    }
  }

  Future<bool> editApplicantSummaryForm(Data data, String applicantId) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffId = prefs.getString("staff_id");
    String? role = prefs.getString("role");
    // `id` header = the logged-in user's own id (web parity). Staff's Save
    // Applicant comes through this shared method.
    final String? idHeader =
        (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
            ? staffId
            : id;

    try {
      final response = await apiPost(
        Uri.parse('$Api_url/api/applicant/application/$applicantId'),
        headers: {
          'Content-Type': 'application/json',
          "authorization": "CRM $token",
          "id": "CRM $idHeader",
        },
        body: jsonEncode(data.toJson()),
      );

      var responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['statusCode'] == 200) {
          Fluttertoast.showToast(
              msg: responseData['message'] ?? 'Successfully updated tenant');

          return true;
        } else {
          Fluttertoast.showToast(
              msg: responseData['message'] ?? 'Failed to update tenant');
          return false;
        }
      } else {
        Fluttertoast.showToast(
            msg: responseData['message'] ?? 'Failed to update tenant');
        return false;
      }
    } catch (error) {
      logError('Exception occurred: $error');
      Fluttertoast.showToast(msg: 'An error occurred');
      return false;
    }
  }

  // static Future<applicant_summery_details> getApplicantSummary(
  //     String applicantId) async {
  //   print('entry');
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String? id = prefs.getString('adminId');
  //   String? token = prefs.getString('token');
  //   print('token $token');

  //   final url =
  //       Uri.parse('$Api_url/api/applicant/applicant_summary/$applicantId');

  //   final response = await apiGet(url, headers: {
  //     "authorization": "CRM $token",
  //     "id": "CRM $id",
  //   });

  //   if (response.statusCode == 200) {
  //     print('entry 200');
  //     final Map<String, dynamic> data = jsonDecode(response.body)["data"][0];
  //     print("response.body : ${response.body}");

  //     return applicant_summery_details.fromJson(data);
  //   } else {
  //     throw Exception('Failed to fetch applicant summary: ${response.body}');
  //   }
  // }

  static Future<applicant_summery_details> getApplicantSummary(
      String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('adminId');
    String? token = prefs.getString('token');

    final url =
        Uri.parse('$Api_url/api/applicant/applicant_summary/$applicantId');

    try {
      final response = await apiGet(url, headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        // Check if the "data" field is present and is a list
        if (jsonResponse.containsKey('data') && jsonResponse['data'] is List) {
          final List<dynamic> dataList = jsonResponse['data'] as List;
          if (dataList.isNotEmpty) {
            final Map<String, dynamic> data =
                dataList[0] as Map<String, dynamic>;
            return applicant_summery_details.fromJson(data);
          } else {
            throw Exception('Data list is empty');
          }
        } else {
          throw Exception('Invalid response format: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to fetch applicant summary: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      logError('Error fetching applicant summary: $e');
      throw Exception('Error fetching applicant summary: $e');
    }
  }

  Future<int> noteAndFilePost(NoteFile noteFile, String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');

    final body = jsonEncode(noteFile.toJson());

    final response = await apiPut(
      Uri.parse(
          '$Api_url/api/applicant/applicant/note_attachment/$applicantId'),
      headers: {
        "id": "CRM $adminId",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      return response.statusCode;
    } else {
      throw Exception('Failed to post note and files');
    }
  }

  Future<int> deleteNoteAndFiles(String applicantId, String note__id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');

    final response = await apiDelete(
        Uri.parse(
            '$Api_url/api/applicant/applicant/note_attachment/$applicantId/$note__id'),
        headers: {
          "id": "CRM $adminId",
          "authorization": "CRM $token",
          'Content-Type': 'application/json; charset=UTF-8',
        });

    if (response.statusCode == 200) {
      return response.statusCode;
    } else {
      return response.statusCode;
    }
  }

  Future<ApplicantContentDetails> fetchApplicantDetails(
      String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');
    try {
      final response = await apiGet(
          Uri.parse('$Api_url/api/applicant/applicant_details/$applicantId'),
          headers: {
            "id": "CRM $adminId",
            "authorization": "CRM $token",
            'Content-Type': 'application/json; charset=UTF-8',
          });

      if (response.statusCode == 200) {
        return ApplicantContentDetails.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load applicant details');
      }
    } catch (e) {
      logError('Error: $e');
      throw Exception('Failed to load applicant details');
    }
  }

  Future<int> sendMail(String applicantId) async {
    final reponse = await http
        .get(Uri.parse('$Api_url/api/applicant/applicant/mail/$applicantId'));

    if (reponse.statusCode == 200) {
      return reponse.statusCode;
    } else {
      return reponse.statusCode;
    }
  }

  Future<ApproveRejectApplicantDetail> fetchApprovedDetail(
      String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');

    final response = await apiGet(
        Uri.parse('$Api_url/api/applicant/status_data/$applicantId/Approved'),
        headers: {
          "id": "CRM $adminId",
          "authorization": "CRM $token",
          'Content-Type': 'application/json; charset=UTF-8',
        });
    if (response.statusCode == 200) {
      var jsonData = json.decode(response.body);
      var data = jsonData['data'];
      if (data != null && data is List && data.isNotEmpty) {
        return ApproveRejectApplicantDetail.fromJson(data[0]);
      } else {
        throw Exception('No data found');
      }
    } else {
      throw Exception('Failed to load applicant details');
    }
  }

  Future<ApproveRejectApplicantDetail> fetchRejectedDetail(
      String applicantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? token = prefs.getString('token');

    final response = await apiGet(
        Uri.parse('$Api_url/api/applicant/status_data/$applicantId/Rejected'),
        headers: {
          "id": "CRM $adminId",
          "authorization": "CRM $token",
          'Content-Type': 'application/json; charset=UTF-8',
        });
    if (response.statusCode == 200) {
      var jsonData = json.decode(response.body);
      var data = jsonData['data'];
      if (data != null && data is List && data.isNotEmpty) {
        return ApproveRejectApplicantDetail.fromJson(data[0]);
      } else {
        throw Exception('No data found');
      }
    } else {
      throw Exception('Failed to load applicant details');
    }
  }

  Future<void> updateApplicantStatus(String applicantId, String status) async {
    final url =
        Uri.parse('$Api_url/api/applicant/applicant/$applicantId/status');
    final response = await apiPut(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'statusUpdatedBy': 'Admin',
        'status': status,
        'rental_id': '',
        'unit_id': '',
      }),
    );

    if (response.statusCode == 200) {
    } else {
    }
  }
}
