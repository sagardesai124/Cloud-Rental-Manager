import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Model/history_item_model.dart';
import '../enums/history_type.dart';
import '../constant/constant.dart';

/// Web's History line for a deleted unit (PropertyUnitsTab.jsx):
/// "Unit <number> has been deleted", falling back to the unit id, then N/A.
String unitDeletedDescription({String? unitNumber, String? unitId}) {
  final name = [unitNumber, unitId].firstWhere(
      (v) => v != null && v.trim().isNotEmpty,
      orElse: () => 'N/A');
  return 'Unit $name has been deleted';
}

class HistoryService {
  /// The name web writes on a History entry (PropDetails.jsx getUsername):
  /// "First Last", else the username, else the email, else "System".
  static String usernameFrom(SharedPreferences prefs) {
    final first = (prefs.getString('first_name') ?? '').trim();
    final last = (prefs.getString('last_name') ?? '').trim();
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    for (final key in ['username', 'email']) {
      final value = (prefs.getString(key) ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return 'System';
  }

  /// Like web's saveHistory (utils/historyService.js): POST /api/history.
  /// A failed save never breaks the action it records, so this returns null
  /// instead of throwing.
  static Future<Map<String, dynamic>?> saveHistory({
    required String entityType,
    required String entityId,
    required String actionType,
    required String description,
    Map<String, dynamic> metadata = const {},
    String category = 'General',
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await apiPost(
        Uri.parse('$Api_url/api/history'),
        headers: {
          "authorization": "CRM ${prefs.getString('token')}",
          "id": "CRM ${_sessionId(prefs)}",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'entity_type': entityType,
          'entity_id': entityId,
          'action_type': actionType,
          'description': description,
          'username': usernameFrom(prefs),
          'metadata': metadata,
          'category': category,
        }),
      );
      final data = jsonDecode(response.body);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  /// The id header for the current session: the staff id for a staff
  /// session, otherwise the admin id (see fetchHistory for why).
  static String? _sessionId(SharedPreferences prefs) {
    final staffId = prefs.getString("staff_id");
    return (prefs.getString("role") == "Staffmember" &&
            staffId != null &&
            staffId.isNotEmpty)
        ? staffId
        : prefs.getString("adminId");
  }

  static Future<HistoryResponse> fetchHistory({
    required HistoryType historyType,
    required String entityId,
    int page = 1,
    int limit = 10,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString("adminId");
      String? staffId = prefs.getString("staff_id");
      String? role = prefs.getString("role");

      // Pick the id from the ROLE of the current session, not from whether a
      // staff_id happens to be stored.
      //
      // `staff_id` is written on staff login and only ever cleared by the
      // logout path's prefs.clear(); login itself does not clear prefs. So a
      // session that ended any other way (app killed, token expiry, switching
      // accounts) leaves the previous staff_id behind. Preferring it whenever
      // it was non-empty meant an Admin session sent a staff id against an
      // admin token, and the server's verifyToken found no matching claim and
      // answered 401 - while every other call on the same screen, which sends
      // adminId, kept working.
      String? id = (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
          ? staffId
          : adminId;

      // print('🔵 HistoryService - Fetching history');
      // print('🔵 User Type: ${staffId != null && staffId.isNotEmpty ? "Staff" : "Admin"}');
      // print('🔵 ID used in header: $id');

      // Lease history uses a different endpoint
      String url;
      if (historyType == HistoryType.lease) {
        url = '$Api_url/api/leases/lease_history/$entityId';
      } else {
        url =
            '$Api_url/api/history/${historyType.apiPath}/$entityId?page=$page&limit=$limit&_t=${DateTime.now().millisecondsSinceEpoch}';
      }

      // print('🔵 URL: $url');
      // print('🔵 HistoryType: $historyType, API Path: ${historyType.apiPath}');
      // print('🔵 EntityId: $entityId');
      // print('🔵 Page: $page, Limit: $limit');

      final response = await apiGet(
        Uri.parse(url),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
      );

      // print('🔵 HistoryService - Response Status: ${response.statusCode}');
      // print('🔵 HistoryService - Response Body Length: ${response.body.length}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        // print('🔵 HistoryService - JSON decoded successfully');
        // print('🔵 HistoryService - Data array length: ${jsonData['data']?.length ?? 0}');

        // Check if this is frontend pagination (data length > limit) or backend pagination
        final dataLength = jsonData['data']?.length ?? 0;
        final isFrontendPagination =
            historyType == HistoryType.lease || dataLength > limit;

        // print('🔵 HistoryService - Is Frontend Pagination: $isFrontendPagination');

        final historyResponse = HistoryResponse.fromJson(
          jsonData,
          isLeaseHistory: historyType == HistoryType.lease,
          isFrontendPagination: isFrontendPagination,
          currentPage: page,
          itemsPerPage: limit,
        );
        // print('🔵 HistoryService - Parsed ${historyResponse.data.length} history items');
        // print('🔵 HistoryService - Pagination: Total=${historyResponse.pagination.total}, Pages=${historyResponse.pagination.totalPages}');
        return historyResponse;
      } else {
        // print('🔴 HistoryService - Error Status: ${response.statusCode}');
        // print('🔴 HistoryService - Error Body: ${response.body}');
        throw Exception('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      // print('Error fetching history: $e');
      throw Exception('Error fetching history: $e');
    }
  }
}
