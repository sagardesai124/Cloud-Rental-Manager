import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart'as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/model/properties_summery.dart';

import '../../../constant/constant.dart';
import '../../../model/properties_workorders.dart';
import '../../Model/Properties_revenue_model.dart';
import '../../Model/properties_Lease_model.dart';
import '../../model/unitsummery_propeties.dart';

// class Properies_summery_Repo{
//
//   Future<List<RentalSummary>> fetchPropertiessummery(String id) async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     //String? id = prefs.getString("rentalid");
//     print(id);
//
//    // final response = await apiGet(Uri.parse('${Api_url}/api/rentals/rental_summary/$id'));
//     final response = await apiGet(Uri.parse('${Api_url}/api/api/tenant/rental_tenant/$id'));
//     print(response.body);
//     if (response.statusCode == 200) {
//       List jsonResponse = json.decode(response.body)['data'];
//       print(jsonResponse.first["lease_tenant_data"]);
//       return jsonResponse.map((data) => RentalSummary.fromJson(data)).toList();
//     }
//     return [];
//   }
//
//
//
//
// }
class Properies_summery_Repo{

  Future<List<TenantData>> fetchPropertiessummery(String rentalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await apiGet(Uri.parse('${Api_url}/api/tenant/rental_tenant/$rentalId'),
      headers: {"authorization" : "CRM $token","id":"CRM $id",},);

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => TenantData.fromJson(data)).toList();
    } else {
      return [];
      //throw Exception('Failed to load data');
    }
  }

  Future<Map<String, dynamic>> addUnit({
     String? adminId,
     String? unitId,
     String? rentalunit,
     String? rentalId,
     String? rentalunitadress,
     String? rentalsqft,
     String? rentalbath,
     String? rentalbed,
    List<String?>? rentalImages,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'unit_id': unitId,
      'rental_unit': rentalunit,
      'rental_id': rentalId,
      'rental_unit_adress': rentalunitadress,
      'rental_sqft': rentalsqft,
     'rental_bath': rentalbath,
    'rental_bed': rentalbed,
      'rental_images':rentalImages
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/unit/unit'),
      headers: <String, String>{
        "authorization" : "CRM $token",
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
      throw Exception('Failed to add unit');
    }
  }

  Future<List<unit_properties>> fetchunit(String rentalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    final response = await apiGet(Uri.parse('${Api_url}/api/unit/rental_unit/$rentalId'),
      headers: {"authorization" : "CRM $token","id":"CRM $id",},);
    // print(jsonEncode('data'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => unit_properties.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<Map<String, dynamic>> addappliances({
    String? adminId,
    String? unitId,
    String? rentalId,
    String? appliancename,
    String? appliancedescription,
    String? installeddate,
    String? type,
    String? systemType,
    String? brand,
    String? model,
    String? serialNumber,
    String? warrantyExpiry,
    String? lastMaintenanceDate,
    String? maintenanceNotes,
    String? status,
    String? categoryId,
    List<dynamic>? filters,
    String? appliance_image, // Add this parameter
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");

    // Convert filters to JSON string
    String filtersJson = json.encode(filters ?? []);

    // Create FormData
    var formData = {
      'admin_id': adminId,
      'unit_id': unitId,
      'rental_id': rentalId,
      'appliance_name': appliancename,
      'appliance_description': appliancedescription,
      'installed_date': installeddate,
      'type': type,
      'system_type': systemType ?? '',
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'warranty_expiry': warrantyExpiry,
      'last_maintenance_date': lastMaintenanceDate,
      'maintenance_notes': maintenanceNotes,
      'status': status,
      'category_id': categoryId,
      'filters': filtersJson,
      'appliance_id': "",
      'appliance_image': appliance_image, // Add this field
    };


    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/appliance/appliance'),
      headers: <String, String>{
        "authorization": "CRM $token",
        'Content-Type':
        'application/x-www-form-urlencoded', // Changed content type
        "id": "CRM $id",
      },
      body: formData, // Send as form data
    );

    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: "Infrastructure added successfully");
      return json.decode(response.body);
    } else {
      final serverMsg =
          responseData["message"]?.toString() ?? "Failed to add infrastructure";
      Fluttertoast.showToast(msg: serverMsg);
      throw Exception(serverMsg);
    }
  }

  Future<Map<String, dynamic>> Editappliances({
    String? adminId,
    String? unitId,
    String? rentalId,
    String? applianceid,
    String? removeApplianceImages,
    String? appliancename,
    String? appliancedescription,
    String? installeddate,
    String? type,
    String? systemType,
    String? brand,
    String? model,
    String? serialNumber,
    String? warrantyExpiry,
    String? lastMaintenanceDate,
    String? maintenanceNotes,
    String? status,
    String? categoryId,
    List<dynamic>? filters,
    String? appliance_image, // Add this parameter
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");

    // Convert filters to JSON string
    String filtersJson = json.encode(filters ?? []);

    // Create form data
    var formData = {
      'admin_id': adminId,
      'unit_id': unitId,
      'rental_id': rentalId,
      'appliance_id': applianceid,
      'appliance_name': appliancename,
      'appliance_description': appliancedescription,
      'installed_date': installeddate,
      'type': type,
      'system_type': systemType ?? '',
      'brand': brand,
      'model': model,
      'serial_number': serialNumber,
      'warranty_expiry': warrantyExpiry,
      'last_maintenance_date': lastMaintenanceDate,
      'maintenance_notes': maintenanceNotes,
      'status': status,
      'category_id': categoryId,
      'filters': filtersJson,
      'appliance_image': appliance_image, // Add this field
      'remove_appliance_images': removeApplianceImages ?? 'false',
    };


    final http.Response response = await apiPut(
      Uri.parse('${Api_url}/api/appliance/appliance/$applianceid'),
      headers: <String, String>{
        "authorization": "CRM $token",
        'Content-Type':
        'application/x-www-form-urlencoded', // Changed content type
        "id": "CRM $id",
      },
      body: formData, // Send as form data
    );


    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: "Appliance updated successfully");
      return json.decode(response.body);
    } else {
      Fluttertoast.showToast(
          msg: responseData["message"] ?? "Failed to update appliance");
      throw Exception('Failed to update appliance');
    }
  }

  Future<Map<String, dynamic>> Editunit({
    String? adminId,
    String? id,
    String? unitId,
    String? rentalunit,
    String? rentalId,
    String? rentalunitadress,
    String? rentalsqft,
    String? rentalbath,
    String? rentalbed,
    List<String?>? rentalImages,
  }) async {
    final Map<String, dynamic> data = {
      'admin_id': adminId,
      'unit_id': unitId,
      'rental_unit': rentalunit,
      'rental_id': rentalId,
      'rental_images':rentalImages,
      'rental_unit_adress': rentalunitadress,
      'rental_sqft': rentalsqft,
      'rental_bath': rentalbath,
      'rental_bed': rentalbed,
      'rental_images':rentalImages
    };
    // Server applies $set: req.body, so a null would blank the stored field
    // (bath/bed, rental_images, even rental_id). Send only keys we have.
    data.removeWhere((k, v) => v == null);

   // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    final http.Response response = await apiPut(
      Uri.parse('${Api_url}/api/unit/unit/$unitId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "authorization" : "CRM $token",
        "id":"CRM $id",
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

  Future<Map<String, dynamic>> Deleteapplences({
    required String? appliance_id
  }) async {
    // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    final http.Response response = await apiDelete(
      Uri.parse('${Api_url}/api/appliance/appliance/$appliance_id'),
      headers: <String, String>{
        "authorization" : "CRM $token",
        "id":"CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
    );
    var responseData = json.decode(response.body);
    if (responseData["statusCode"] == 200) {
      Fluttertoast.showToast(msg: responseData["message"]);
      return json.decode(response.body);

    } else {
      Fluttertoast.showToast(msg: responseData["message"]);
      throw Exception('Failed to delete applences');
    }
  }
  Future<Map<String, dynamic>> Deleteunit({
    required String? unitId
  }) async {
    // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    final http.Response response = await apiDelete(
      Uri.parse('${Api_url}/api/unit/unit/$unitId'),
      headers: <String, String>{
        "authorization" : "CRM $token",
        "id":"CRM $id",
        'Content-Type': 'application/json; charset=UTF-8',
      },
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

  // Future<Rentals> fetchrentalDetails(String rentalId) async {
  //
  //   final response = await apiGet(Uri.parse('${Api_url}/api/rentals/rental_summary/$rentalId'));
  //
  //   print(response.body);
  //   print(rentalId);
  //   print('${Api_url}/api/rentals/rental_summary/$rentalId');
  //
  //   if (response.statusCode == 200) {
  //     final jsonResponse = json.decode(response.body);
  //     if (jsonResponse['data'] is List) {
  //       return Rentals.fromJson(jsonResponse['data'][0]);
  //     } else {
  //       return Rentals.fromJson(jsonResponse['data']);
  //     }
  //   } else {
  //     throw Exception('Failed to load rental');
  //   }
  // }

  Future<Rentals> fetchrentalDetails(String rentalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    final response = await apiGet(
        Uri.parse('${Api_url}/api/rentals/rental_summary/$rentalId'),
        headers: {
          "authorization": "CRM $token",
          "id":"CRM $id",
          "Content-Type": "application/json"
        }
    );
    log(response.body);
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['data'] is List) {
        return Rentals.fromJson(jsonResponse['data'][0]);
      } else {
        return Rentals.fromJson(jsonResponse['data']);
      }
    } else {
      throw Exception('Failed to load rental');
    }
  }

  Future<Rentals> addPropertyValue({
    required String rentalId,
    required num estimatedValue,
    required String valueSource,
    required String valueAsOfDate,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString("staff_id");
    if (id == null || id.isEmpty) id = prefs.getString('adminId');
    final response = await apiPost(
      Uri.parse('$Api_url/api/rentals/rental/$rentalId/property_values'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        'estimatedValue': estimatedValue,
        'valueSource': valueSource,
        'valueAsOfDate': valueAsOfDate,
        'user_active_recently': true,
        'is_web': true,
      }),
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data != null && data is Map<String, dynamic>) {
        return Rentals.fromJson(data);
      }
      throw Exception('Invalid response');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Failed to add property value');
    }
  }

  Future<Rentals> updatePropertyValue({
    required String rentalId,
    required String propertyValueId,
    required num estimatedValue,
    required String valueSource,
    required String valueAsOfDate,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString("staff_id");
    if (id == null || id.isEmpty) id = prefs.getString('adminId');
    final response = await apiPut(
      Uri.parse(
          '$Api_url/api/rentals/rental/$rentalId/property_values/$propertyValueId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        'estimatedValue': estimatedValue,
        'valueSource': valueSource,
        'valueAsOfDate': valueAsOfDate,
        'user_active_recently': true,
        'is_web': true,
      }),
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data != null && data is Map<String, dynamic>) {
        return Rentals.fromJson(data);
      }
      throw Exception('Invalid response');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Failed to update property value');
    }
  }

  Future<Rentals> deletePropertyValue({
    required String rentalId,
    required String propertyValueId,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString("staff_id");
    if (id == null || id.isEmpty) id = prefs.getString('adminId');
    final response = await apiDelete(
      Uri.parse(
          '$Api_url/api/rentals/rental/$rentalId/property_values/$propertyValueId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data != null && data is Map<String, dynamic>) {
        return Rentals.fromJson(data);
      }
      throw Exception('Invalid response');
    } else {
      final err = json.decode(response.body);
      throw Exception(err['message'] ?? 'Failed to delete property value');
    }
  }

  Future<List<Properties_lease_model>> fetchrLeaseDetails(String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? adminid = prefs.getString('adminId');
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/leases/leases/$adminid/$unitId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      },
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => Properties_lease_model.fromJson(data)).toList();
    } else {
      return [];
      //throw Exception('Failed to load data');
    }
  }
  Future<List<Properties_Revenu_model>> fetchrRevenueDetails(String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? adminid = prefs.getString('adminId');
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/leases/revenue/$adminid/$unitId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
      },
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse.map((data) => Properties_Revenu_model.fromJson(data)).toList();
    } else {
      return [];
      //throw Exception('Failed to load data');
    }
  }
  Future<List<propertiesworkData>> fetchWorkOrders(String rentalId) async {
    // Retrieve admin ID and token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');

    // Define the URL and headers for the request
    final response = await apiGet(
      Uri.parse('$Api_url/api/work-order/rental_workorder/$rentalId'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM ${prefs.getString("staff_id") ?? id}',
      },
    );
    // Check the response status
    if (response.statusCode == 200) {
      // Parse the JSON response
      List jsonResponse = json.decode(response.body)['data'];
      // Map the JSON data to List<Data> and return
      return jsonResponse.map((data) => propertiesworkData.fromJson(data)).toList();
    } else {
      // Throw an exception if the request failed
      throw Exception('No work order found');
    }
  }

}

