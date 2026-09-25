import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/model/properties.dart';
import 'package:three_zero_two_property/model/properties_summery.dart';

import '../Model/Properties_revenue_model.dart';
import '../Model/properties_Lease_model.dart';
import '../constant/constant.dart';
import '../model/properties_workorders.dart';
import '../model/unitsummery_propeties.dart';
import '../screens/Leasing/RentalRoll/addcard/CardModel.dart';

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
class Properies_summery_Repo {
  Future<List<TenantData>> fetchPropertiessummery(String rentalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? id = prefs.getString('adminId');
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/tenant/rental_tenant/$rentalId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
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
      'rental_images': rentalImages
    };
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    final http.Response response = await apiPost(
      Uri.parse('${Api_url}/api/unit/unit'),
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
      throw Exception('Failed to add unit');
    }
  }

  Future<List<unit_properties>> fetchunit(String rentalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/unit/rental_unit/$rentalId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    // print(jsonEncode('data'));
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse
          .map((data) => unit_properties.fromJson(data))
          .toList();
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
    String? id = prefs.getString('adminId');

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
    String? id = prefs.getString('adminId');

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
      'rental_images': rentalImages,
      'rental_unit_adress': rentalunitadress,
      'rental_sqft': rentalsqft,
      'rental_bath': rentalbath,
      'rental_bed': rentalbed,
      'rental_images': rentalImages
    };
    // Server applies $set: req.body, so a null would blank the stored field.
    data.removeWhere((k, v) => v == null);

    // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    final http.Response response = await apiPut(
      Uri.parse('${Api_url}/api/unit/unit/$unitId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "authorization": "CRM $token",
        "id": "CRM $id",
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

  Future<Map<String, dynamic>> Deleteapplences(
      {required String? appliance_id}) async {
    // print('$apiUrl/$id');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    final http.Response response = await apiDelete(
      Uri.parse('${Api_url}/api/appliance/appliance/$appliance_id'),
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
      throw Exception('Failed to delete applences');
    }
  }

  Future<Map<String, dynamic>> Deleteunit({required String? unitId}) async {
    // print('$apiUrl/$id');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    final http.Response response = await apiDelete(
      Uri.parse('${Api_url}/api/unit/unit/$unitId'),
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
    String? id = prefs.getString('adminId');

    final response = await apiGet(
        Uri.parse('${Api_url}/api/rentals/rental_summary/$rentalId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json"
        });

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['data'];
      if (data is List && data.isNotEmpty) {
        return Rentals.fromJson(data[0]);
      }
      if (data is Map && data.containsKey('rental')) {
        return Rentals.fromJson(data['rental']);
      }
      return Rentals.fromJson(data);
    } else {
      throw Exception('Failed to load rental details');
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
    String? id = prefs.getString('adminId');
    final response = await apiPost(
      Uri.parse('$Api_url/api/rentals/rental/$rentalId/property_values'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
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
    String? id = prefs.getString('adminId');
    final response = await apiPut(
      Uri.parse(
          '$Api_url/api/rentals/rental/$rentalId/property_values/$propertyValueId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
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
    String? id = prefs.getString('adminId');
    final response = await apiDelete(
      Uri.parse(
          '$Api_url/api/rentals/rental/$rentalId/property_values/$propertyValueId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
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
    String? id = prefs.getString('adminId');
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/leases/leases/$id/$unitId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse
          .map((data) => Properties_lease_model.fromJson(data))
          .toList();
    } else {
      return [];
      //throw Exception('Failed to load data');
    }
  }

  Future<List<Properties_Revenu_model>> fetchrRevenueDetails(
      String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    //String? id = prefs.getString("rentalid");
    String? id = prefs.getString('adminId');
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/leases/revenue/$id/$unitId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body)['data'];
      return jsonResponse
          .map((data) => Properties_Revenu_model.fromJson(data))
          .toList();
    } else {
      return [];
      //throw Exception('Failed to load data');
    }
  }

  Future<List<propertiesworkData>> fetchWorkOrders(String rentalId) async {
    // Retrieve admin ID and token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    // Define the URL and headers for the request
    final response = await apiGet(
      Uri.parse('$Api_url/api/work-order/rental_workorder/$rentalId'),
      headers: {
        'authorization': 'CRM $token',
        'id': 'CRM $id',
      },
    );
    // Check the response status
    if (response.statusCode == 200) {
      // Parse the JSON response
      List jsonResponse = json.decode(response.body)['data'];
      // Map the JSON data to List<Data> and return
      return jsonResponse
          .map((data) => propertiesworkData.fromJson(data))
          .toList();
    } else {
      // Throw an exception if the request failed
      throw Exception('No work order found');
    }
  }

  Future<void> addrecurringtenant(Map<String, dynamic> data) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString('adminId');
    final http.Response response =
        await apiPost(Uri.parse('${Api_url}/api/recurring-cards/add-cards'),
            headers: <String, String>{
              "authorization": "CRM $token",
              "id": "CRM $id",
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(data));
    var responseData = json.decode(response.body);
  }
}

class tenant_cards {
  List<BillingData> cardDetails = [];
  int? customervaultid;
  Future<List<BillingData>> fetchcreditcard(String tenantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final response = await apiGet(
      Uri.parse('$Api_url/api/creditcard/getCreditCards/$tenantId'),
      headers: {"id": "CRM $id", "authorization": "CRM $token"},
    );
    log("${response.body} || response boy");
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      customervaultid = jsonResponse['customer_vault_id'];
      List<dynamic> cardDetailsList = jsonResponse['card_detail'];

      // Debug print to check the response structure

      for (var cardDetail in cardDetailsList) {
        // Debug print to check each card detail

        //  BillingData billingData = BillingData.fromJson(cardDetail);
        // print('Parsed Billing ID: ${billingData.billingId}');

        // Assuming this is part of the logic to print billing_id
      }

      CustomerData? customerData = await postBillingCustomerVault(
          customervaultid.toString(), cardDetailsList);

      if (customerData != null) {
        return customerData.billing;
      }
      return [];
    } else if (response.statusCode == 404) {
      return [];
      // throw Exception('Failed to load credit card data');
    } else {
      return [];
      throw Exception('Failed to load credit card data');
    }
  }

  Future<CustomerData?> postBillingCustomerVault(
      String customerVaultId, List<dynamic> cardDetailsList) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');

    Map<String, String> requestBody = {
      "customer_vault_id": customerVaultId,
      "admin_id": adminId.toString(),
    };

    final response = await apiPost(
      Uri.parse('$Api_url/api/nmipayment/get-billing-customer-vault'),
      headers: {
        'Content-Type': 'application/json',
        "id": "CRM $adminId",
        "authorization": "CRM $token",
      },
      body: json.encode(requestBody),
    );
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      var customerJson = jsonResponse['data']['customer'];
      CustomerData customerData = CustomerData.fromJson(customerJson);

      customerData.billing.forEach((billing) {
      });

      final Map<String, String> cardTypeByBillingId = {};
      for (final dynamic item in cardDetailsList) {
        if (item is Map) {
          final billingId = item['billing_id']?.toString();
          final cardType = item['card_type']?.toString();
          if (billingId != null && billingId.isNotEmpty && cardType != null) {
            cardTypeByBillingId[billingId] = cardType;
          }
        }
      }
      for (final billing in customerData.billing) {
        final id = billing.billingId;
        if (id != null && cardTypeByBillingId.containsKey(id)) {
          billing.binResult = cardTypeByBillingId[id];
        }
      }

      return customerData;
    } else {
      return null;
    }
  }

  Future<Map<String, bool>> fetchCardAcceptance(
      String tenantId, String leaseId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final response = await apiGet(
      Uri.parse('$Api_url/api/tenant/payment_settings/$tenantId/$leaseId'),
      headers: {
        'Content-Type': 'application/json',
        "id": "CRM $adminId",
        "authorization": "CRM $token",
      },
    );
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return {
        'creditCardAccepted':
            responseData['data']['creditCardAccepted'] ?? false,
        'debitCardAccepted': responseData['data']['debitCardAccepted'] ?? false,
      };
    } else {
      throw Exception('Failed to load card acceptance');
    }
  }

// Function to filter cards based on the acceptance flags
  List<BillingData> filterCards(
      List<BillingData> cards, Map<String, bool> cardAcceptanceResponse) {
    bool creditAccepted = cardAcceptanceResponse['creditCardAccepted'] ?? false;
    bool debitAccepted = cardAcceptanceResponse['debitCardAccepted'] ?? false;

    return cards.where((card) {
      if (card.binResult == "CREDIT" && creditAccepted) {
        return true;
      }
      if (card.binResult == "DEBIT" && debitAccepted) {
        return true;
      }
      return false;
    }).toList();
  }

  Future<Map<String, dynamic>> disableCard(String rentalId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final response = await apiPut(
      Uri.parse('$Api_url/api/recurring-cards/disable-cards/$rentalId'),
      headers: {
        'Content-Type': 'application/json',
        "id": "CRM $adminId",
        "authorization": "CRM $token",
      },
    );
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      return responseData;
    } else {
      throw Exception('Failed to load card acceptance');
    }
  }
}

class DropdownProvider with ChangeNotifier {
  List<String> _tenantCard = [];

  List<String> get tenantCard => _tenantCard;

  void updateTenantCard(int index, String value) {
    _tenantCard[index] = value;
    notifyListeners();
  }

  void initializeTenantCard(List<List<BillingData>> billingDataList) {

    _tenantCard = List<String>.generate(billingDataList.length,
        (index) => billingDataList[index].first.ccNumber!);
    // notifyListeners();
  }
}
