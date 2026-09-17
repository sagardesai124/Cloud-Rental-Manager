import 'dart:convert';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../Model/team_member.dart';
import '../constant/constant.dart';

/// Repository for the Team & Access section.
///
/// Follows the same conventions as the other table repositories (e.g.
/// [StaffMemberRepository] in `lib/repository/Staffmember.dart`): IDs/token are
/// read from [SharedPreferences], requests go through the shared [apiGet] helper
/// with the standard `CRM` auth headers, and an empty result is returned on a
/// non-200 so callers can render an empty state instead of crashing.
class TeamRepository {
  final String apiUrl = '${Api_url}/api/admin/team/team';

  /// The `id` header must be the acting user's OWN id: `staff_id` for a Staff
  /// user, `adminId` for an Admin. Sending `adminId` as Staff makes the server
  /// return a generic "User does not exist or is not active" 401 instead of the
  /// real permission message, so every call resolves the caller's own id here.
  String? _actingId(SharedPreferences prefs) =>
      prefs.getString('role') == 'Staffmember'
          ? prefs.getString('staff_id')
          : prefs.getString('adminId');

  /// GET the company's admins + staff in a single payload.
  Future<TeamData> fetchTeam() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = _actingId(prefs);
    String? token = prefs.getString('token');

    final response = await apiGet(
      Uri.parse(apiUrl),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      return TeamData.fromJson(jsonResponse);
    } else {
      return TeamData();
    }
  }

  /// POST /api/admin/team/invite-coadmin
  /// Creates a pending co-admin and emails them a set-password link.
  Future<Map<String, dynamic>> inviteCoAdmin({
    required String? firstName,
    required String? lastName,
    required String? email,
    required String? phoneNumber,
  }) async {
    final Map<String, dynamic> data = {
      "first_name": firstName,
      "last_name": lastName ?? "",
      "email": email,
      "phone_number": phoneNumber ?? "",
      "is_web": true,
      "user_active_recently": true,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = _actingId(prefs);

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/team/invite-coadmin'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    final responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Co-admin invitation sent.");
      return responseData;
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Failed to invite co-admin");
      throw Exception('Failed to invite co-admin');
    }
  }

  /// POST /api/admin/team/invite-staff
  /// Creates a pending staff member and emails them a set-password link.
  /// The form's first + last name are combined into `staffmember_name`.
  Future<Map<String, dynamic>> inviteStaffMember({
    required String? firstName,
    required String? lastName,
    required String? email,
    required String? designation,
    required String? phoneNumber,
  }) async {
    final String fullName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    final Map<String, dynamic> data = {
      "staffmember_name": fullName,
      "staffmember_email": email,
      "staffmember_designation": designation ?? "",
      "staffmember_phoneNumber": phoneNumber ?? "",
      "is_web": true,
      "user_active_recently": true,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = _actingId(prefs);

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/team/invite-staff'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    final responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Staff invitation sent.");
      return responseData;
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Failed to invite staff member");
      throw Exception('Failed to invite staff member');
    }
  }

  /// POST /api/admin/team/send-reset-link
  /// Re-sends the set/reset-password email to an existing admin or staff member.
  Future<Map<String, dynamic>> sendResetLink({
    required String userType, // "staffmember" | "admin"
    required String? userId,
    required String? email,
  }) async {
    final Map<String, dynamic> data = {
      "userType": userType,
      "user_id": userId,
      "email": email,
      "is_web": true,
      "user_active_recently": true,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = _actingId(prefs);

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/team/send-reset-link'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    final responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      // Success UI (the "Reset link sent" dialog) is handled by the caller.
      return responseData;
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Failed to send reset link");
      throw Exception('Failed to send reset link');
    }
  }

  /// POST /api/admin/team/cancel-invite
  /// Cancels a pending admin / staff invitation. Note: no email in the payload.
  Future<Map<String, dynamic>> cancelInvite({
    required String userType, // "staffmember" | "admin"
    required String? userId,
  }) async {
    final Map<String, dynamic> data = {
      "userType": userType,
      "user_id": userId,
      "user_active_recently": true,
      "is_web": true,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = _actingId(prefs);

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/team/cancel-invite'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    final responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Invitation cancelled.");
      return responseData;
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Failed to cancel invitation");
      throw Exception('Failed to cancel invitation');
    }
  }

  /// POST /api/admin/team/move-role
  /// Promotes a staff member to admin (target_role: "admin") or demotes an
  /// admin to staff (target_role: "staff"). Payload matches the web platform.
  Future<Map<String, dynamic>> moveRole({
    required String? userId,
    required String targetRole, // "admin" | "staff"
  }) async {
    final Map<String, dynamic> data = {
      "user_id": userId,
      "target_role": targetRole,
      "user_active_recently": true,
      "is_web": true,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = _actingId(prefs);

    final response = await apiPost(
      Uri.parse('${Api_url}/api/admin/team/move-role'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
    );

    final responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      // Success UI (the confirmation dialog) is handled by the caller.
      return responseData;
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Failed to update role");
      throw Exception('Failed to move role');
    }
  }

  /// GET /api/admin/team/activity
  ///
  /// The Team & Access activity log, paged and optionally filtered by action
  /// code. Mirrors the web CRM's Activity Log tab (`TeamAccess.jsx`), which
  /// calls the same route with `page` / `pageSize` / `action`.
  ///
  /// The server caps `pageSize` at 200 and defaults it to 25; an unknown
  /// `action` is ignored server-side and all team actions are returned.
  /// The route is admin-only (`requireAdminCaller`), so a Staff caller gets a
  /// non-200 — returned here as an empty page so the view shows its empty
  /// state rather than throwing.
  Future<TeamActivityPage> fetchActivity({
    int page = 1,
    int pageSize = 25,
    String action = '',
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = _actingId(prefs);
    String? token = prefs.getString('token');

    final Map<String, String> query = {
      'page': '$page',
      'pageSize': '$pageSize',
      if (action.isNotEmpty) 'action': action,
    };

    final response = await apiGet(
      Uri.parse('${Api_url}/api/admin/team/activity')
          .replace(queryParameters: query),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      return TeamActivityPage.fromJson(jsonResponse);
    }
    return TeamActivityPage();
  }
}
