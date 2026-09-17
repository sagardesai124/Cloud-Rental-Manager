import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/appbar.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../widgets/titleBar.dart';
import '../../../constant/constant.dart';
import '../work_order/workorder_summery.dart';

class notifications extends StatefulWidget {
  const notifications({super.key});

  @override
  State<notifications> createState() => _notificationsState();
}

class _notificationsState extends State<notifications>
    with NetworkRetryState {
  late Future<List<Map<String,dynamic>>> fetchnoti;
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The one fetch initState makes.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      fetchnoti = fetchNotifications()!;
    });
  }

  void initState() {
    super.initState();
    fetchnoti = fetchNotifications()!;
  }

  /// The list endpoint returns only UNREAD notifications, so once one is opened
  /// (which marks it read) the cached future is stale and still shows it. The
  /// handler's Navigator.push is awaited, so this resolves only after the user
  /// pops back — refreshing then drops the notification they just read.
  Future<void> _onNotificationTap(Map<String, dynamic> notification) async {
    await handleNotificationTap(
      context,
      notification['is_workorder'],
      notification['notification_id'],
    );
    if (!mounted) return;
    setState(() {
      fetchnoti = fetchNotifications()!;
    });
  }


  Future<List<Map<String,dynamic>>>? fetchNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/notification/vendor/$id'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    // A non-JSON body (e.g. an HTML 502 page) threw FormatException out of here.
    // FutureBuilder catches it, but with no hasError branch a failure rendered
    // the "No Notifications Yet" empty state instead of an error.
    final dynamic jsonData;
    try {
      jsonData = json.decode(response.body);
    } on FormatException {
      throw Exception('Could not load notifications. Please try again.');
    }
    if (jsonData is Map &&
        (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201)) {
      List<Map<String, dynamic>> notifications = List<Map<String, dynamic>>.from(jsonData["data"]);
      return notifications;
    } else {

      throw Exception('Failed to load data');
    }
  }
  String formatNotificationDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final difference = now.difference(dateTime);

    if (dateTime.isAfter(today)) {
      // For today
      return 'Today | ${DateFormat('hh:mm a').format(dateTime)}';
    } else if (dateTime.isAfter(yesterday)) {
      // For yesterday
      return 'Yesterday | ${DateFormat('hh:mm a').format(dateTime)}';
    } else if (difference.inDays < 31) {
      // For days ago (less than a month)
      return '${difference.inDays} days ago | ${DateFormat('hh:mm a').format(dateTime)}';
    }
    else if (difference.inDays < 60) {
      // For more than a month ago
      return '${(difference.inDays / 30).floor()} month ago';
    }
    else if (difference.inDays < 365) {
      // For more than a month ago
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      // For more than a year ago
      return DateFormat('dd-MM-yyyy').format(dateTime);
    }
  }
  Future<void> handleNotificationTap(
      BuildContext context, bool isWorkOrder, String notificationId) async
  {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    String apiUrl =
        '${Api_url}/api/notification/vendor_notification/$notificationId';


    try {
      // Make the PUT request to the API
      var response = await apiPut(
        Uri.parse(apiUrl),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
        body: json.encode({'is_workorder': isWorkOrder}),
      );

      final jsonData = json.decode(response.body);

      if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {

        final responseData = jsonData['data'];

        // Check if it's a work order or payment
        if (responseData['is_workorder'] == true) {
          String workOrderId =
          responseData['notification_type']['workorder_id'];
          // Awaited so the caller can refresh the list once the user pops back.
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      Workorder_summery(workorder_id: workOrderId)));
        }

      } else {
      }
    } catch (e) {
      logError("Error: $e");
    }
  }
  String formatDateTime(String dateTime) {
    // Same reasoning as [_relativeTime]: this field is an unvalidated String on
    // the server, so fall back to showing it as-is rather than throwing.
    final DateTime? parsedDateTime = DateTime.tryParse(dateTime);
    if (parsedDateTime == null) return dateTime;
    return DateFormat('dd-MM-yyyy hh:mm a').format(parsedDateTime);
  }

  /// Relative time for a notification's `createdAt`.
  ///
  /// The server declares this field as a plain String (Notification.js) with no
  /// date coercion, and part of it is client-supplied (`notificationTime`), so
  /// the value is only ever ISO-ish by convention. `DateTime.parse` throws a
  /// FormatException on anything it cannot read, and this sits inside build() —
  /// so one malformed row would take out the whole notifications list rather
  /// than a single entry. tryParse degrades to the same 'No date available'
  /// the empty case already shows, and toString() keeps a non-String value
  /// (which `?.isEmpty` would have thrown on) from blowing up first.
  String _relativeTime(dynamic raw) {
    final String value = raw?.toString() ?? '';
    if (value.isEmpty) return 'No date available';
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) return 'No date available';
    return timeago.format(parsed.toLocal(), locale: 'en_custom');
  }

  var appBarHeight = AppBar().preferredSize.height;
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key:key,
      appBar: widget_302.App_Bar(context: context,onDrawerIconPressed: () {
        key.currentState!.openDrawer();
        // Scaffold.of(context).openDrawer();
      }),
      // Gated inside this screen's own Scaffold so the app bar stays put — see
      // the vendor dashboard note: blocking above the header removes the only
      // request that could report the connection coming back.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: titleBar(
                width: MediaQuery.of(context).size.width * .93,
                title: 'Notifications',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: FutureBuilder<List<Map<String,dynamic>>>(
                future: fetchnoti,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: MediaQuery.of(context).size.height *.7,
                      child: Center(
                        child: SpinKitFadingCircle(
                          color: blueColor,
                          size: 50.0,
                        ),
                      ),
                    );
                    // return ColabShimmerLoadingWidget();
                  } else if (snapshot.hasError) {
                    // Distinguish a failed fetch from a genuinely empty list.
                    return Container(
                      height: MediaQuery.of(context).size.height * .6,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            "Could not load notifications. Please try again.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: blueColor,
                                fontSize: 15),
                          ),
                        ),
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      height: MediaQuery.of(context).size.height * .6,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset("assets/images/no_notification.jpg"),
                            SizedBox(height: 10,),
                            Text("No Notifications Yet",style: TextStyle(fontWeight: FontWeight.bold,color:blueColor,fontSize: 16),)
                          ],
                        ),
                      ),
                    );
                  } else
                  {
                    List<Map<String, dynamic>> notifications = snapshot.data!;

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: notifications.map((notification) {
                            // The whole notification is tappable, not just the
                            // eye icon — the title, date and detail text were
                            // dead space before.
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onNotificationTap(notification),
                              child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.blue.shade100,

                                          child: FaIcon(FontAwesomeIcons.solidBell,size: 18,)),
                                      SizedBox(width: 14.0),

                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.start,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notification['notification_title'],
                                            style: TextStyle(
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.bold,
                                                color: blueColor
                                            ),
                                          ),
                                          Text(
                                            _relativeTime(notification['createdAt']),
                                            style: TextStyle(
                                              color: Colors.black.withOpacity(.7),
                                              fontSize: 14,
                                            ),
                                          )
                                        ],
                                      ),
                                      Spacer(),
                                      GestureDetector(
                                        onTap: () =>
                                            _onNotificationTap(notification),
                                        child: Container(
                                            height: 40,
                                            width: 40,
                                            decoration: BoxDecoration(
                                                color: Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(6)
                                            ),
                                            child: Center(child: FaIcon(FontAwesomeIcons.solidEye,size: 22,))),
                                      )
                                    ],
                                  ),
                                  SizedBox(height: 14.0),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      notification['notification_detail'],
                                      style: TextStyle(
                                        fontSize: 14.0,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8.0),
                                  /* Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Text(
                                       formatNotificationDateTime(notification['createdAt']),
                                       style: TextStyle(
                                         fontSize: 14.0,
                                         color:blueColor,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                     ElevatedButton(
                                       onPressed: () {
                                        *//* if(notification['notification_title'] =="Workorder Created"){
                                           Navigator.of(context).push(MaterialPageRoute(
                                               builder: (context) =>  ResponsiveEditWorkOrder(workorderId: notification['notification_type']['workorder_id'],)));
                                         }else if(notification['notification_title'] =="New Payment"){
                                           Navigator.of(context).push(MaterialPageRoute(
                                               builder: (context) =>  SummeryPageLease(leaseId: notification['notification_type']['lease_id'],isredirectpayment: true,)));

                                         }*//*

                                         // Handle view button press
                                       },
                                       child: Text('View'),
                                     ),
                                   ],
                                 ),*/
                                  Divider(thickness: 1.0),
                                ],
                              ),
                            ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
