import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../Model/categories_model.dart';
import '../constant/constant.dart';
import '../model/setting.dart';

class SurchargeRepository {
  final String baseUrl;

  SurchargeRepository({required this.baseUrl});

  Future<Setting1> fetchSurchargeData(String adminId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    final response = await apiGet(
        Uri.parse('$baseUrl/api/surcharge/surcharge/getadmin/$adminId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json"
        });
    final response_Data = jsonDecode(response.body);
    if (response_Data["statusCode"] == 200) {
      // final apiResponse = ApiResponse.fromJson(jsonDecode(response.body));
      final apiResponse =
          Setting1.fromJson(jsonDecode(response.body)["data"][0]);
      return apiResponse;
    } else {
      throw Exception('Failed to load surcharge data');
    }
  }

  Future<List<Setting1>> fetchUpdat(Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    final response =
        await apiPut(Uri.parse('${Api_url}/api/surcharge/surcharge/$adminId'),
            headers: {
              "authorization": "CRM $token",
              "id": "CRM $id",
            },
            body: data);
    final response_Data = jsonDecode(
      response.body,
    );
    if (response_Data["statusCode"] == 200) {
      final apiResponse =
          ApiResponse.fromJson(jsonDecode(response.body)["data"]);
      return apiResponse.data;
    } else {
      throw Exception('Failed to update the data');
    }
  }

  Future<bool> updateSurchargeData(
      String surchargeId, Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    final response = await apiPut(
      Uri.parse('$baseUrl/api/surcharge/surcharge/$surchargeId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json'
      },
      body: jsonEncode(data),
    );


    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> AddSurgeData(
      String surchargeId, Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminId = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminId;
    final response = await apiPost(
      Uri.parse('$baseUrl/api/surcharge/surcharge'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json'
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }
}

class latefeeRepository {
  final String baseUrl;

  latefeeRepository({required this.baseUrl});

  Future<Setting2> fetchLatefeesData(String adminId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiGet(
      Uri.parse('$baseUrl/api/latefee/latefee/$adminId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final response_Data = jsonDecode(response.body);
    if (response_Data["statusCode"] == 200) {
      // final apiResponse = ApiResponse.fromJson(jsonDecode(response.body));
      final apiResponse = Setting2.fromJson(jsonDecode(response.body)["data"]);
      return apiResponse;
    } else {
      throw Exception('Failed to load surcharge data');
    }
  }

  Future<bool> updateLatefeesData(
      String surchargeId, Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");
    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;

    final response = await apiPut(
      Uri.parse('$baseUrl/api/latefee/latefee/$surchargeId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json'
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> AddLatefeesData(
      String surchargeId, Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;

    final response = await apiPost(
      Uri.parse('$Api_url/api/latefee/latefee'),
      headers: {
        "authorization": "CRM $token",
        'Content-Type': 'application/json',
        "id": "CRM $id",
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }
}

class mailserviceRepository {
  final String baseUrl;
  mailserviceRepository({required this.baseUrl});

  Future<Setting3> fetchMailData(String adminId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiGet(
      Uri.parse('$baseUrl/api/mail_permission/$adminId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final response_Data = jsonDecode(response.body);
    if (response_Data["statusCode"] == 200) {

      // final apiResponse = ApiResponse.fromJson(jsonDecode(response.body));
      final apiResponse = Setting3.fromJson(jsonDecode(response.body)["data"]);
      return apiResponse;
    } else {
      throw Exception('Failed to load mail data');
    }
  }

  Future<bool> updateMailData(Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiPut(
      Uri.parse('$Api_url/api/mail_permission/$adminid'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json'
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> AddMailData(id, Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiPost(
      Uri.parse('$Api_url/api/mail_permission'),
      headers: {
        "authorization": "CRM $token",
        'Content-Type': 'application/json',
        "id": "CRM $id",
      },
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  }
}

class accountRepository {
  Future<List<Setting4>> fetchAccounts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiGet(
      Uri.parse('${Api_url}/api/accounts/accounts/$adminid'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => Setting4.fromJson(data)).toList();
    } else {
      return [];
    }
  }

  Future<Map<String, dynamic>> addAccount({
    required String? adminId,
    required String? account,
    required String? accounttype,
    required String? fundtype,
    required String? chargetype,
    required String? notes,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'account': account,
      'account_type': accounttype,
      'fund_type': fundtype,
      'notes': notes,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;

    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/accounts/accounts'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
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
      throw Exception('Failed to add account');
    }
  }

  Future<Map<String, dynamic>> updateAccount({
    required String? accountId,
    required String? account,
    required String? accounttype,
    required String? fundtype,
    required String? chargetype,
    required String? notes,
  }) async {
    final Map<String, dynamic> data = {
      'account': account,
      'account_type': accounttype,
      'fund_type': fundtype,
      'charge_type': chargetype,
      'notes': notes,
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;

    final http.Response response = await apiPut(
      Uri.parse('${Api_url}/api/accounts/accounts/$accountId'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
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
      throw Exception('Failed to update account');
    }
  }

  Future<Map<String, dynamic>> DeleteAccount(
      {required String? account_id}) async {
    //print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;

    final http.Response response = await apiDelete(
      Uri.parse('${Api_url}/api/accounts/accounts/$account_id'),
      headers: <String, String>{
        "authorization": "CRM $token",
        "id": "CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to delete account');
    }
  }

  Future<List<categories_model>> fetchCategories() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiGet(
      Uri.parse('${Api_url}/api/settings/categories/$adminid'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse
          .map((data) => categories_model.fromJson(data))
          .toList();
    } else {
      return [];
    }
  }

  Future<Map<String, dynamic>> DeleteCategories(
      {required String? categories_id, String? reason}) async {
    // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    final http.Response response = await apiDelete(
        Uri.parse('${Api_url}/api/settings/categories/$adminid/$categories_id'),
        headers: <String, String>{
          "authorization": "CRM $token",
          "id": "CRM $adminid",
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({"reason": reason}));
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: 'Category deleted successfully'); // web wording
      return json.decode(response.body);
    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to delete categories');
    }
  }
}

class PropertyOwnerOverrideRepository {
  Future<List<PropertyOwnerOverride>> fetchPropertyOwners() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiGet(
      Uri.parse('${Api_url}/api/property-owner-overrides/list/$adminid'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'] ?? [];
      return jsonResponse
          .map((data) => PropertyOwnerOverride.fromJson(data))
          .toList();
    } else {
      return [];
    }
  }

  Future<bool> saveLateFeeOverride(Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString('adminId');
    String? staffid = prefs.getString("staff_id");

    String? id = (staffid != null && staffid.isNotEmpty) ? staffid : adminid;
    final response = await apiPost(
      Uri.parse('${Api_url}/api/property-owner-overrides'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      return true;
    } else {
      return false;
    }
  }
}
