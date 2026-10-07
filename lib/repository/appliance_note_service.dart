import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constant/constant.dart';

class ApplianceNoteService {
  Future<Map<String, dynamic>> addNote({
    required String applianceId,
    required String noteText,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString('adminId');

      if (token == null || adminId == null) {
        throw Exception('Authentication credentials not found');
      }

      final Map<String, dynamic> requestBody = {
        'note_text': noteText,
        'appliance_id': applianceId,
        'admin_id': adminId,
      };


      String? staffId = prefs.getString('staff_id');
      String? role = prefs.getString('role');
      // `id` header = the logged-in user's own id (web parity); admin_id stays in the body.
      final String idHeader =
          (role == 'Staffmember' && staffId != null && staffId.isNotEmpty)
              ? staffId
              : adminId;

      final response = await apiPost(
        Uri.parse('$Api_url/api/appliance/add_note'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'authorization': 'CRM $token',
          'id': 'CRM $idHeader',
        },
        body: json.encode(requestBody),
      );


      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to add note');
      }
    } catch (e) {
      logError('Error adding note: $e');
      throw Exception('Failed to add note: $e');
    }
  }

  Future<Map<String, dynamic>> deleteNote({
    required String noteId,
    required String applianceId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString('adminId');

      if (token == null || adminId == null) {
        throw Exception('Authentication credentials not found');
      }

      String? staffId = prefs.getString('staff_id');
      String? role = prefs.getString('role');
      final String idHeader =
          (role == 'Staffmember' && staffId != null && staffId.isNotEmpty)
              ? staffId
              : adminId;

      final response = await apiDelete(
        Uri.parse('$Api_url/api/appliance/delete_note/$noteId'),
        headers: {
          'authorization': 'CRM $token',
          'id': 'CRM $idHeader',
        },
      );


      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to delete note');
      }
    } catch (e) {
      logError('Error deleting note: $e');
      throw Exception('Failed to delete note: $e');
    }
  }

  Future<Map<String, dynamic>> updateNote({
    required String noteId,
    required String noteText,
    required String applianceId,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString('adminId');

      if (token == null || adminId == null) {
        throw Exception('Authentication credentials not found');
      }

      final Map<String, dynamic> requestBody = {
        'note_text': noteText,
        'appliance_id': applianceId,
        'note_id': noteId,
      };

      String? staffId = prefs.getString('staff_id');
      String? role = prefs.getString('role');
      final String idHeader =
          (role == 'Staffmember' && staffId != null && staffId.isNotEmpty)
              ? staffId
              : adminId;

      final response = await apiPut(
        Uri.parse('$Api_url/api/appliance/update_note'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'authorization': 'CRM $token',
          'id': 'CRM $idHeader',
        },
        body: json.encode(requestBody),
      );


      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to update note');
      }
    } catch (e) {
      logError('Error updating note: $e');
      throw Exception('Failed to update note: $e');
    }
  }
} 