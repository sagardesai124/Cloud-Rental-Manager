import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Model/bid_request.dart';
import '../../constant/constant.dart';

class VendorBidRepository {
  Future<BidRequestResponse> fetchVendorBidRequests({
    required String vendorId,
    int limit = 10000,
    int page = 1,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
    String? status,
  }) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      // For vendor requests, we typically use the vendorId.
      // The API endpoint is: /api/bid-request/bid-requests/vendor/:vendorId

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }

      final url = Uri.parse(
              '${Api_url}/api/bid-request/bid-requests/vendor/$vendorId')
          .replace(queryParameters: queryParams)
          .toString();


      final response = await apiGet(
        Uri.parse(url),
        headers: <String, String>{
          "authorization": "CRM $token",
          "id":
              "CRM $vendorId", // Assuming the header requires the ID of the requester
        },
      );

      // print('Vendor bid requests response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return BidRequestResponse.fromJson(jsonData);
      } else {
        // Single-owner messaging: no toast here. The sole call site
        // (vendor_bid_room_table.dart) already shows its own message, and
        // suppresses it when the screen has flipped to its offline view.
        // Toasting here raised THREE messages for one failed load: this one,
        // then the catch below (the throw lands in it), then the screen's -
        // and on an offline failure it fired even though the screen had
        // deliberately stayed quiet. The server's reason rides the exception
        // instead; friendlyErrorMessage passes it straight through, so the
        // one remaining toast now says why. The status code stays in the log
        // rather than in the user's face.
        final jsonData = json.decode(response.body);
        logError(
            'Vendor bid requests failed: HTTP ${response.statusCode}');
        throw Exception(jsonData['message'] ?? 'Failed to fetch bid requests');
      }
    } catch (e) {
      logError('Error fetching vendor bid requests: $e');
      rethrow;
    }
  }

  // If needed, we can also add fetchBidRequestDetails here,
  // reusing the existing endpoint if it's accessible to vendors
  // or a specific vendor details endpoint if it exists.
  // For now, assuming the public/common details endpoint works.
}
