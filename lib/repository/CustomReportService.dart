import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/CustomReportDataModel.dart';
import 'package:three_zero_two_property/Model/SavedReportModel.dart';
import 'package:three_zero_two_property/constant/constant.dart';

class CustomReportService {
  Future<SavedReportModel> fetchSavedReports(
      {required String adminId, bool isStaff = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final uri = Uri.parse('$Api_url/api/reports/saved').replace(
        queryParameters: {'admin_id': adminId},
      );

      final headerId =
          isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final response = await apiGet(uri, headers: {
        "authorization": "CRM $token",
        "id": "CRM $headerId",
        "Content-Type": "application/json",
      });
      if (response.statusCode == 200) {
        final parsedJson = jsonDecode(response.body) as Map<String, dynamic>;
        return SavedReportModel.fromJson(parsedJson);
      }
      if (response.statusCode == 401) {
        return SavedReportModel(
          statusCode: 401,
          message: 'User session is expired or invalid, please login again.',
          data: [],
          count: 0,
        );
      }
      return SavedReportModel(
        statusCode: response.statusCode,
        message: 'Failed to load saved reports',
        data: [],
        count: 0,
      );
    } catch (e) {
      return SavedReportModel(
        statusCode: 0,
        message: 'Error: $e',
        data: [],
        count: 0,
      );
    }
  }

  /// GET /api/reports/saved/:reportId?admin_id=...
  Future<SavedReportSingleModel> fetchSavedReportById({
    required String adminId,
    required String reportId,
    bool isStaff = false,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final uri = Uri.parse('$Api_url/api/reports/saved/$reportId').replace(
        queryParameters: {'admin_id': adminId},
      );

      final headerId =
          isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final response = await apiGet(uri, headers: {
        "authorization": "CRM $token",
        "id": "CRM $headerId",
        "Content-Type": "application/json",
      });
      // --- GET /api/reports/saved/:reportId - full response log (compare with web) ---
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final model = SavedReportSingleModel.fromJson(parsed);
        if (model.data != null) {
          final r = model.data!;
        } else {
        }
        return model;
      }
      if (response.statusCode == 401) {
        return SavedReportSingleModel(
          statusCode: 401,
          message: 'User session is expired or invalid, please login again.',
        );
      }
      return SavedReportSingleModel(
        statusCode: response.statusCode,
        message: 'Failed to load report',
      );
    } catch (e) {
      return SavedReportSingleModel(
        statusCode: 0,
        message: 'Error: $e',
      );
    }
  }

  /// POST /api/reports/custom - body same as web for whole data: pass null dates and empty dynamicFieldConfigs when no filters
  Future<CustomReportDataModel> fetchCustomReportData({
    required String adminId,
    required String reportId,
    SavedReport? reportConfig,
    bool isStaff = false,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final uri = Uri.parse('$Api_url/api/reports/custom');
      final Map<String, dynamic> bodyMap = {
        'admin_id': adminId,
        'report_id': reportId,
      };
      if (reportConfig != null) {
        // Send null for dates when not set so backend returns whole data (same as web)
        bodyMap['dateRange'] = reportConfig.dateRange.isEmpty ? null : reportConfig.dateRange;
        bodyMap['selectedStartDate'] = reportConfig.selectedStartDate;
        bodyMap['selectedEndDate'] = reportConfig.selectedEndDate;
        bodyMap['includeHistory'] = reportConfig.includeHistory;
        bodyMap['selectedColumns'] = reportConfig.selectedColumns;
        bodyMap['dynamicFieldConfigs'] = reportConfig.dynamicFieldConfigs ?? {};
      }
      final body = jsonEncode(bodyMap);

      // Readable log for debugging: show key fields like selectedColumns
      final cols = bodyMap['selectedColumns'] as List?;

      final headerId =
          isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final response = await apiPost(
        uri,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
          "Content-Type": "application/json",
        },
        body: body,
      );
      // --- POST /api/reports/custom - full response log (compare with web) ---
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        final model = CustomReportDataModel.fromJson(parsed);
        for (int i = 0; i < model.data.length; i++) {
          final r = model.data[i];
        }
        return model;
      }
      if (response.statusCode == 401) {
        return CustomReportDataModel(
          statusCode: 401,
          message: 'User session is expired or invalid, please login again.',
          data: [],
          count: 0,
        );
      }
      return CustomReportDataModel(
        statusCode: response.statusCode,
        message: 'Failed to load report data',
        data: [],
        count: 0,
      );
    } catch (e) {
      return CustomReportDataModel(
        statusCode: 0,
        message: 'Error: $e',
        data: [],
        count: 0,
      );
    }
  }

  /// POST /api/reports/save - create or update report
  /// Body: admin_id, name, description, selectedColumns, dateRange,
  ///       selectedStartDate, selectedEndDate, includeHistory, dynamicFieldConfigs [, report_id for update]
  Future<SaveReportResponse> saveReport({
    required String adminId,
    required String name,
    required String description,
    required List<String> selectedColumns,
    String? dateRange,
    String? selectedStartDate,
    String? selectedEndDate,
    required bool includeHistory,
    Map<String, dynamic>? dynamicFieldConfigs,
    String? reportId,
    bool isStaff = false,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final uri = Uri.parse('$Api_url/api/reports/save');
      final body = <String, dynamic>{
        'admin_id': adminId,
        'name': name,
        'description': description,
        'selectedColumns': selectedColumns,
        'dateRange': dateRange,
        'selectedStartDate': selectedStartDate,
        'selectedEndDate': selectedEndDate,
        'includeHistory': includeHistory,
        'dynamicFieldConfigs': dynamicFieldConfigs ?? {},
      };
      if (reportId != null && reportId.isNotEmpty) {
        body['report_id'] = reportId;
      }

      final headerId =
          isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final response = await apiPost(
        uri,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return SaveReportResponse(
          statusCode: parsed['statusCode'] as int? ?? 200,
          message: parsed['message'] as String? ?? 'Report saved successfully.',
          data: parsed['data'] != null && parsed['data'] is Map
              ? SavedReport.fromJson(parsed['data'] as Map<String, dynamic>)
              : null,
        );
      }
      return SaveReportResponse(
        statusCode: response.statusCode,
        message: parsed['message'] as String? ?? 'Failed to save report',
        data: null,
      );
    } catch (e) {
      return SaveReportResponse(
        statusCode: 0,
        message: 'Error: $e',
        data: null,
      );
    }
  }

  /// DELETE /api/reports/saved/:reportId
  Future<SaveReportResponse> deleteReport({
    required String adminId,
    required String reportId,
    bool isStaff = false,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final uri = Uri.parse('$Api_url/api/reports/saved/$reportId').replace(
        queryParameters: {'admin_id': adminId},
      );

      final headerId =
          isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final response = await apiDelete(
        uri,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
          "Content-Type": "application/json",
        },
      );
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return SaveReportResponse(
          statusCode: parsed['statusCode'] as int? ?? 200,
          message:
              parsed['message'] as String? ?? 'Report deleted successfully.',
          data: null,
        );
      }
      return SaveReportResponse(
        statusCode: response.statusCode,
        message: parsed['message'] as String? ?? 'Failed to delete report',
        data: null,
      );
    } catch (e) {
      return SaveReportResponse(
        statusCode: 0,
        message: 'Error: $e',
        data: null,
      );
    }
  }

  /// PUT /api/reports/saved/:reportId - update existing report (called when editing from Saved Reports)
  Future<SaveReportResponse> updateReport({
    required String adminId,
    required String reportId,
    required String name,
    required String description,
    required List<String> selectedColumns,
    String? dateRange,
    String? selectedStartDate,
    String? selectedEndDate,
    required bool includeHistory,
    Map<String, dynamic>? dynamicFieldConfigs,
    bool isStaff = false,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    try {
      final uri = Uri.parse('$Api_url/api/reports/saved/$reportId').replace(
        queryParameters: {'admin_id': adminId},
      );
      final body = <String, dynamic>{
        'admin_id': adminId,
        'name': name,
        'description': description,
        'selectedColumns': selectedColumns,
        'dateRange': dateRange,
        'selectedStartDate': selectedStartDate,
        'selectedEndDate': selectedEndDate,
        'includeHistory': includeHistory,
        'dynamicFieldConfigs': dynamicFieldConfigs ?? {},
      };

      final headerId =
          isStaff ? (prefs.getString('staff_id') ?? adminId) : adminId;
      final response = await apiPut(
        uri,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return SaveReportResponse(
          statusCode: parsed['statusCode'] as int? ?? 200,
          message:
              parsed['message'] as String? ?? 'Report updated successfully.',
          data: parsed['data'] != null && parsed['data'] is Map
              ? SavedReport.fromJson(parsed['data'] as Map<String, dynamic>)
              : null,
        );
      }
      return SaveReportResponse(
        statusCode: response.statusCode,
        message: parsed['message'] as String? ?? 'Failed to update report',
        data: null,
      );
    } catch (e) {
      return SaveReportResponse(
        statusCode: 0,
        message: 'Error: $e',
        data: null,
      );
    }
  }
}

class SaveReportResponse {
  final int statusCode;
  final String? message;
  final SavedReport? data;

  SaveReportResponse({
    required this.statusCode,
    this.message,
    this.data,
  });
}
