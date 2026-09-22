import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Model/propertytype.dart';
import '../../../constant/constant.dart';

class PropertyTypeRepository {
  final String apiUrl = '${Api_url}/api/propertytype/property_type';

  Future<Map<String, dynamic>> addPropertyType({
    required String? adminId,
    required String? propertyType,
    required String? propertySubType,
    required bool isMultiUnit,
    String? propertyTypeImage,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'property_type': propertyType,
      'propertysub_type': propertySubType,
      'is_multiunit': isMultiUnit,
      'property_type_image': propertyTypeImage ?? '',
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
     String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
     final http.Response response = await apiPost(
      Uri.parse(apiUrl),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id":"CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
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

  Future<List<propertytype>> fetchPropertyTypes() async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
     String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");

    final response = await apiGet(Uri.parse('${Api_url}/api/propertytype/property_type/$adminid'),
        headers: {
          "authorization": "CRM $token",
          "id":"CRM $id",
        }
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => propertytype.fromJson(data)).toList();
    } else {
      return [];
      // throw Exception('Failed to load data');
    }
  }

  Future<Map<String, dynamic>> EditPropertyType({
    required String? adminId,
    required String? propertyType,
    required String? propertySubType,
    required bool isMultiUnit,
    required String? id,
    String? propertyTypeImage,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'property_type': propertyType,
      'propertysub_type': propertySubType,
      'is_multiunit': isMultiUnit,
      'property_type_image': propertyTypeImage ?? '',
    };

   // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
     String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? s_id = prefs.getString("staff_id");

    final http.Response response = await apiPut(
      Uri.parse('$apiUrl/$id'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id":"CRM $s_id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(data),
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
  Future<Map<String, dynamic>> DeletePropertyType({
    required String? pro_id,
    String? reason
  }) async {

    //print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
     String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");

    final http.Response response = await apiDelete(
      Uri.parse('$apiUrl/$pro_id'),
      headers: <String, String>{

          "authorization": "CRM $token",
        "id":"CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
        body: jsonEncode({
          "reason":reason
        })
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);

    } else {
      // Don't toast here: Android's native toast caps at two lines, and the
      // server's refusal ("Cannot delete Property-Type. The Property-Type is
      // already assigned to a lease.") is long enough to be cut off mid-
      // sentence. Carry the message on the exception so the screen can show it
      // in a SnackBar, which wraps.
      throw PropertyTypeDeleteException(
          (responseData["message"] ?? '').toString().trim());
    }
  }
}

/// Carries the server's own refusal message out to the screen so it can be
/// displayed in full.
class PropertyTypeDeleteException implements Exception {
  final String serverMessage;
  const PropertyTypeDeleteException(this.serverMessage);

  @override
  String toString() => serverMessage.isNotEmpty
      ? serverMessage
      : 'Failed to delete property type';
}
