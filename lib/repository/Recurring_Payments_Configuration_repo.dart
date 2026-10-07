import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/Recurring_Payments_Configuration_model.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
class Recurring_Payments_Configuration_Services{

  Future<Recurring_Payments_Configuration> fetchRecurringPaymentConfiguration()async{

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    String? staffId = prefs.getString("staff_id");
    String? role = prefs.getString("role");
    // `id` header = the logged-in user's own id (web parity); company id stays in the URL.
    final String? idHeader =
        (role == "Staffmember" && staffId != null && staffId.isNotEmpty)
            ? staffId
            : adminId;
    try {
      final response = await apiGet(
          Uri.parse('$Api_url/api/recurring-cards/recurring-payment-configuration/$adminId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $idHeader",
          });

      if (response.statusCode == 200) {
        // If the server returns a 200 OK response, parse the JSON

        final parsedJson = jsonDecode(response.body);
        return Recurring_Payments_Configuration.fromJson(parsedJson);

           } else {
        // If the server did not return a 200 OK response, throw an exception
        throw Exception('Failed to load renters insurance');
      }
    } catch (e) {
      // Handle any other exceptions
      logError('Error fetching data: $e');
      throw Exception('Failed to load renters insurance');
    }


  }


}