import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:io';
import 'dart:ui';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:three_zero_two_property/screens/Dashboard/dashbordpolices_table.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/Applicants_table.dart';
import 'package:three_zero_two_property/screens/Maintenance/Vendor/Vendor_table.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Workorder_table.dart';
// Wizard not used for now: same Add Work Order screen as web/tablet (phone skill = easy access).
// import 'package:three_zero_two_property/screens/Maintenance/Workorder/AddWorkOrderMobileWizard.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/Add_workorder.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/lease_table.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/Properties_table.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/Tenants_table.dart';
import 'package:three_zero_two_property/widgets/pie_chart.dart';

import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../constant/constant.dart';
import '../../provider/NetworkProvider.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/drawer_tiles.dart';
import '../../widgets/fl_chart.dart';

import '../../widgets/barchart.dart';
import 'RentPastDueReport.dart';
import 'admin_dashboard_screen.dart';
import 'cronjob_payment_table.dart';
import 'dashboard_leaseExpiring.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class DashboardData {
  // int tenantCount = 0;
  // int rentalCount = 0;
  // int vendorCount = 0;
  // int applicantCount = 0;
  // int workOrderCount = 0;

  List<int> countList = [];
  List<int> amountList = [];

  List<String> icons = [
    "assets/images/Properti-icon.svg",
    "assets/images/tenant-icon.svg",
    "assets/images/applicant-icon.svg",
    "assets/images/vendor-icon.svg",
    "assets/images/workorder-icon.svg"
  ];

  List<String> titles = [
    "Properties",
    "Tenants",
    "Applicants",
    "Vendors",
    "Work Orders"
  ];

  final List<Widget> pages = [
    PropertiesTable(),
    Tenants_table(),
    Applicants_table(),
    Vendor_table(),
    Workorder_table(),
  ];

  List<Color> colorc = [
    blueColor,
    const Color.fromRGBO(40, 60, 95, 1),
    const Color.fromRGBO(50, 75, 119, 1),
    const Color.fromRGBO(60, 89, 142, 1),
    const Color.fromRGBO(90, 134, 213, 1),
  ];

  List<Color> colors = [
    blueColor,
    const Color.fromRGBO(40, 60, 95, 1),
    const Color.fromRGBO(50, 75, 119, 1),
    const Color.fromRGBO(60, 89, 142, 1),
    const Color.fromRGBO(90, 134, 213, 1),
  ];

  DashboardData({required this.countList, required this.amountList});
}

class Dashboard extends StatefulWidget {
  Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with NetworkRetryState {
  String firstname = '';
  String lastname = '';
  bool loading = false;
  final List<Widget> pages = [
    PropertiesTable(),
    Tenants_table(),
    Applicants_table(),
    Vendor_table(),
    Workorder_table(),
  ];
  Future<void> fetchDatacount() async {
    setState(() {
      loading = true;
    });
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      final response = await http
          .get(Uri.parse('${Api_url}/api/admin/counts/${id!}'), headers: {
        "id": "CRM $id",
        "authorization": "CRM $token",
        "Content-Type": "application/json"
      });
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200) {
        setState(() {
          // Null-safe like the Staff dashboard (:166-169). A null or double
          // here threw inside setState, skipped `loading = false` below, and
          // left the dashboard on the loader with no way to refresh.
          countList[1] = (jsonData['tenantCount'] as num?)?.toInt() ?? 0;
          countList[0] = (jsonData['rentalCount'] as num?)?.toInt() ?? 0;
          countList[3] = (jsonData['vendorCount'] as num?)?.toInt() ?? 0;
          countList[2] = (jsonData['applicantCount'] as num?)?.toInt() ?? 0;
          countList[4] = (jsonData['workOrderCount'] as num?)?.toInt() ?? 0;
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
        });
        throw Exception('Failed to load dataxxx');
      }
    } catch (e) {
      logError('Error fetching data: $e');
      // Staff resets the flag on failure (StaffModule dashboard :200-204);
      // Admin never did, so a failed or malformed response kept the spinner
      // up until the app was killed.
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } finally {}
  }

  double currentMonthRentDue = 0.0;
  double lastMonthRentDue = 0.0;
  double currentMonthRentPaid = 0.0;
  double lastMonthRentPaid = 0.0;
  double totalRentPastDue = 0.0;

  Future<void> fetchData() async {
    //   print("calling");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('${Api_url}/api/payment/admin_balance/$id'), headers: {
      "authorization": "CRM $token",
      "id": "CRM $id",
      "Content-Type": "application/json"
    });
    // print('${Api_url}/api/payment/admin_balance/$id');
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200) {
        final data = jsonData["data"];
        setState(() {
          currentMonthRentDue =
              double.tryParse(data['currentMonthRentDue'].toString()) ?? 0.0;
          lastMonthRentDue =
              double.tryParse(data['lastMonthRentDue'].toString()) ?? 0.0;
          currentMonthRentPaid =
              double.tryParse(data['currentMonthRentPaid'].toString()) ?? 0.0;
          lastMonthRentPaid =
              double.tryParse(data['lastMonthRentPaid'].toString()) ?? 0.0;
          totalRentPastDue =
              double.tryParse(data['totalRentPastDue'].toString()) ?? 0.0;
        });
      } else {
        throw Exception('Failed to load dataaaaaaaa');
      }
    } else {
      throw Exception('Failed to load datawwwwww');
    }
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
  late DashboardData dashboardData;
  List<int> countList = List.filled(5, 0);
  List<int> amountList = List.filled(5, 0);

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      fetchchartdata();;
      fetchDatacount();;
      fetchData();;
      _loadName();;
    });
  }

  @override
  void initState() {
    super.initState();

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      if (!mounted) return;
      // The event is only a trigger. A stale `none` from the plugin would
      // otherwise strand this screen on the offline view while requests
      // succeed, so verify against the network before deciding.
      var settled = result;
      if (settled == ConnectivityResult.none && await hasNetworkNow()) {
        settled = ConnectivityResult.wifi;
      }
      if (!mounted) return;
      setState(() {
        _connectivityResult = settled;
      });
    });
    fetchchartdata();
    dashboardData =
        DashboardData(countList: [0, 0, 0, 0, 0], amountList: [0, 0, 0, 0, 0]);

    fetchDatacount();
    fetchData();

    _loadName();
  }

  Future<void> _loadName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      firstname = prefs.getString('first_name') ?? '';
      lastname = prefs.getString('last_name') ?? '';
    });
  }

  Future<void> fetchchartdata() async {
    // print("calling");
    var connectiondata;
    connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus can report a stale `none` after the
    // connection is back; confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }

    setState(() {
      loading = true;

      _connectivityResult = connectiondata;
    });

    // This method sets `loading = true` only after the connectivity checks
    // above, so it can re-raise the flag after fetchData() has already
    // cleared it; and it used to throw out of the method on any non-200
    // with no reset at all. Either way the dashboard sat on the loader
    // for good. Whatever happens below, the flag is released in `finally`.
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      final response = await apiGet(
          Uri.parse('${Api_url}/api/rentals/occupied_properties/$id'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
            "Content-Type": "application/json"
          });
      // print('${Api_url}/api/payment/admin_balance/$id');
      // print(response.body);
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["statusCode"] == 200) {
          final dataaa = jsonData["data"];
          //   print("dataaaaa ${dataaa.length}");
          setState(() {
            data = [];
            dataaa.forEach((element) {
              data.add(Map<String, dynamic>.from(element));
            });
          });
        } else {
          throw Exception('Failed to load dataaaaaaaa');
        }
      } else {
        throw Exception('Failed to load datawwwwww');
      }
    } catch (e) {
      logError('Error fetching chart data: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {

    try {
      // Add a small delay to show the refresh indicator
      await Future.delayed(Duration(milliseconds: 500));

      // Await all the async operations to ensure proper completion
      await Future.wait([
        fetchchartdata(),
        fetchDatacount(),
        fetchData(),
        _loadName(),
      ]);

      // Reset dashboard data
      dashboardData = DashboardData(
          countList: [0, 0, 0, 0, 0], amountList: [0, 0, 0, 0, 0]);

    } catch (e) {
      logError('❌ Dashboard refresh error: $e'); // Debug print
    }
  }

  /// --- PHONE SKILL / IN-THE-FIELD FLOW (admin, no wizard) ---
  /// Same idea as staff: on phone (width < 600), "In the field" quick actions at top.
  /// Add Work Order → same form as web (ResponsiveAddWorkOrder). Take Payment → Leases → pick lease → Make payment. Work Orders → list.
  /// Phone skill = 1-tap access from dashboard; same screens and flow as web.
  Widget _buildQuickActionsForField(BuildContext context, double width) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 11),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blueColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 10),
            child: Text(
              'In the field',
              style: TextStyle(
                color: blueColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _quickActionCard(
                  context: context,
                  icon: Icons.build_circle_outlined,
                  label: 'Add Work Order',
                  onTap: () async {
                    // Use same Add Work Order screen as web (no wizard).
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ResponsiveAddWorkOrder(),
                      ),
                    );
                    if (result == true) {
                      fetchDatacount();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickActionCard(
                  context: context,
                  icon: Icons.payment_outlined,
                  label: 'Take Payment',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Lease_table(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _quickActionCard(
                  context: context,
                  icon: Icons.assignment_outlined,
                  label: 'Work Orders',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => Workorder_table(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: blueColor),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: blueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> data = [
    {"month": "Oct", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Nov", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Dec", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Jan", "rentals": 0, "leases": 0, "occupiedPercentage": 0},
    {"month": "Feb", "rentals": 3, "leases": 0, "occupiedPercentage": 0},
    {"month": "Mar", "rentals": 6, "leases": 0, "occupiedPercentage": 0},
    {"month": "Apr", "rentals": 6, "leases": 0, "occupiedPercentage": 0},
    {"month": "May", "rentals": 6, "leases": 0, "occupiedPercentage": 0},
    {"month": "Jun", "rentals": 7, "leases": 0, "occupiedPercentage": 0},
    {"month": "Jul", "rentals": 7, "leases": 0, "occupiedPercentage": 0},
    {"month": "Aug", "rentals": 8, "leases": 1, "occupiedPercentage": 12.5},
    {"month": "Sep", "rentals": 8, "leases": 9, "occupiedPercentage": 102.5},
  ];
  var appBarHeight = AppBar().preferredSize.height;
  @override
  Widget build(BuildContext context) {
    final connectionProvider =
        Provider.of<CheckConnection>(context, listen: false);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return WillPopScope(
      onWillPop: () async {
        return await _showExitPopup(context);
      },
      child: Scaffold(
          backgroundColor: Color.fromRGBO(241, 244, 250, 1),
          drawer: CustomDrawer(
            currentpage: "Dashboard",
            dropdown: false,
          ),
          appBar: widget_302.App_Bar(context: context),
          body: !isOffline
              ? Center(
                  child: loading
                      ? Lottie.asset('assets/images/loader.json',
                          height: 150, width: 100)
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: Colors.blue,
                          backgroundColor: Colors.white,
                          strokeWidth: 2.0,
                          child: ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              // Material(
                              //   elevation: 3,
                              //   child: Divider(
                              //     height: 1,
                              //     color: Colors.transparent,
                              //   ),
                              // ),
                              SizedBox(
                                  height: MediaQuery.of(context).size.height *
                                      0.012),
                              // Phone skill: quick actions on phone. To enable, uncomment next 4 lines.
                              // if (width < 600) _buildQuickActionsForField(context, width),
                              // if (width < 600)
                              //   SizedBox(
                              //       height: MediaQuery.of(context).size.height *
                              //           0.02),
                              DashboardAdminSample(
                                countList: countList,
                                currentMonthRentDue: currentMonthRentDue,
                                currentMonthRentPaid: currentMonthRentPaid,
                                lastMonthRentDue: lastMonthRentDue,
                                lastMonthRentPaid: lastMonthRentPaid,
                                totalRentPastDue: totalRentPastDue,
                              ),
                              //welcome
                              // LayoutBuilder(
                              //   builder: (BuildContext context,
                              //       BoxConstraints constraints) {
                              //     return Row(
                              //       children: [
                              //         SizedBox(width: width * 0.05),
                              //         Container(
                              //           color: Color.fromRGBO(2, 121, 210, 1),
                              //           margin: EdgeInsets.only(
                              //             top:
                              //             MediaQuery.of(context).size.height *
                              //                 0.012,
                              //           ),
                              //           width: 3,
                              //           child: Column(
                              //             children: [
                              //               Container(
                              //                 height: MediaQuery.of(context)
                              //                     .size
                              //                     .height *
                              //                     0.012 +
                              //                     MediaQuery.of(context)
                              //                         .size
                              //                         .width *
                              //                         0.04 +
                              //                     3 +
                              //                     16,
                              //               ),
                              //             ],
                              //           ),
                              //         ),
                              //         Column(
                              //           mainAxisAlignment:
                              //           MainAxisAlignment.start,
                              //           crossAxisAlignment:
                              //           CrossAxisAlignment.start,
                              //           children: [
                              //             SizedBox(
                              //                 height: MediaQuery.of(context)
                              //                     .size
                              //                     .height *
                              //                     0.012),
                              //             Row(
                              //               children: [
                              //                 SizedBox(width: width * 0.05),
                              //                 Text(
                              //                   "Hello $firstname $lastname, Welcome back",
                              //                   style: TextStyle(
                              //                     color: Colors.black,
                              //                     fontSize: MediaQuery.of(context)
                              //                         .size
                              //                         .width >
                              //                         500
                              //                         ? MediaQuery.of(context)
                              //                         .size
                              //                         .width *
                              //                         0.03
                              //                         : MediaQuery.of(context)
                              //                         .size
                              //                         .width *
                              //                         0.04,
                              //                   ),
                              //                 ),
                              //               ],
                              //             ),
                              //             //   SizedBox(height: 3),
                              //             // My Dashboard
                              //             Row(
                              //               children: [
                              //                 SizedBox(width: width * 0.05),
                              //                 Text(
                              //                   "My Dashboard",
                              //                   style: TextStyle(
                              //                     color: Colors.black,
                              //                     fontWeight: FontWeight.bold,
                              //                     fontSize: 22,
                              //                   ),
                              //                 ),
                              //               ],
                              //             ),
                              //           ],
                              //         ),
                              //       ],
                              //     );
                              //   },
                              // ),
                              // LayoutBuilder(
                              //   builder: (context, constraints) {
                              //     if (constraints.maxWidth > 600) {
                              //       // Tablet layout - horizontal
                              //       return Padding(
                              //         padding: const EdgeInsets.only(
                              //             left: 35, right: 80, top: 20),
                              //         child: Wrap(
                              //           alignment: WrapAlignment.start,
                              //           spacing:
                              //           MediaQuery.of(context).size.width *
                              //               0.02,
                              //           runSpacing:
                              //           MediaQuery.of(context).size.width *
                              //               0.02,
                              //           children: List.generate(
                              //             5,
                              //                 (index) => SizedBox(
                              //               width:
                              //               160, // Ensure SizedBox has defined width
                              //               height:
                              //               160, // Ensure SizedBox has defined height
                              //               child: Material(
                              //                 elevation: 3,
                              //                 borderRadius:
                              //                 BorderRadius.circular(10),
                              //                 child: Container(
                              //                   decoration: BoxDecoration(
                              //                     color:
                              //                     dashboardData.colorc[index],
                              //                     borderRadius:
                              //                     BorderRadius.circular(10),
                              //                   ),
                              //                   child: Column(
                              //                     children: [
                              //                       const SizedBox(height: 10),
                              //                       Row(
                              //                         children: [
                              //                           const SizedBox(width: 10),
                              //                           Material(
                              //                             elevation: 5,
                              //                             borderRadius:
                              //                             BorderRadius
                              //                                 .circular(20),
                              //                             child: Container(
                              //                               height: 40,
                              //                               width: 40,
                              //                               padding:
                              //                               const EdgeInsets
                              //                                   .all(10),
                              //                               decoration:
                              //                               BoxDecoration(
                              //                                 color: dashboardData
                              //                                     .colors[index],
                              //                                 borderRadius:
                              //                                 BorderRadius
                              //                                     .circular(
                              //                                     20),
                              //                               ),
                              //                               child:
                              //                               SvgPicture.asset(
                              //                                 "${dashboardData.icons[index]}",
                              //                                 fit: BoxFit.cover,
                              //                                 height: 27,
                              //                                 width: 27,
                              //                               ),
                              //                             ),
                              //                           ),
                              //                         ],
                              //                       ),
                              //                       const SizedBox(height: 10),
                              //                       Row(
                              //                         children: [
                              //                           const SizedBox(width: 10),
                              //                           Text(
                              //                             countList[index]
                              //                                 .toString(),
                              //                             style: const TextStyle(
                              //                               color: Colors.white,
                              //                               fontSize: 15,
                              //                               fontWeight:
                              //                               FontWeight.bold,
                              //                             ),
                              //                           ),
                              //                         ],
                              //                       ),
                              //                       const SizedBox(height: 10),
                              //                       Row(
                              //                         children: [
                              //                           const SizedBox(width: 10),
                              //                           Text(
                              //                             dashboardData
                              //                                 .titles[index],
                              //                             style: const TextStyle(
                              //                               color: Colors.white,
                              //                               fontWeight:
                              //                               FontWeight.bold,
                              //                               fontSize: 20,
                              //                             ),
                              //                           ),
                              //                         ],
                              //                       ),
                              //                     ],
                              //                   ),
                              //                 ),
                              //               ),
                              //             ),
                              //           ),
                              //         ),
                              //       );
                              //     } else {
                              //       // Phone layout - vertical
                              //       return Column(
                              //         children: [
                              //           SizedBox(
                              //               height: MediaQuery.of(context)
                              //                   .size
                              //                   .width *
                              //                   0.05),
                              //           Padding(
                              //             padding: const EdgeInsets.only(
                              //                 left: 25, right: 25),
                              //             child: GridView.builder(
                              //               itemCount: 5,
                              //               gridDelegate:
                              //               SliverGridDelegateWithFixedCrossAxisCount(
                              //                 crossAxisCount:
                              //                 2, // Number of items per row
                              //                 crossAxisSpacing:
                              //                 MediaQuery.of(context)
                              //                     .size
                              //                     .width *
                              //                     0.02,
                              //                 mainAxisSpacing:
                              //                 MediaQuery.of(context)
                              //                     .size
                              //                     .width *
                              //                     0.02,
                              //                 childAspectRatio:
                              //                 .99, // Adjust as needed for your design
                              //               ),
                              //               itemBuilder: (context, index) {
                              //                 return GestureDetector(
                              //                   onTap: () {
                              //                     Navigator.push(
                              //                       context,
                              //                       MaterialPageRoute(
                              //                           builder: (context) =>
                              //                           pages[index]),
                              //                     );
                              //                   },
                              //                   child: Material(
                              //                     elevation: 3,
                              //                     borderRadius:
                              //                     BorderRadius.circular(10),
                              //                     child: Container(
                              //                       decoration: BoxDecoration(
                              //                         color: dashboardData
                              //                             .colorc[index],
                              //                         borderRadius:
                              //                         BorderRadius.circular(
                              //                             8),
                              //                       ),
                              //                       child: Padding(
                              //                         padding:
                              //                         const EdgeInsets.only(
                              //                             left: 5),
                              //                         child: Column(
                              //                           children: [
                              //                             const SizedBox(
                              //                                 height: 15),
                              //                             Row(
                              //                               children: [
                              //                                 const SizedBox(
                              //                                     width: 10),
                              //                                 Material(
                              //                                   elevation: 5,
                              //                                   borderRadius:
                              //                                   BorderRadius
                              //                                       .circular(
                              //                                       15),
                              //                                   child: Container(
                              //                                       height: 50,
                              //                                       width: 50,
                              //                                       padding:
                              //                                       const EdgeInsets
                              //                                           .all(
                              //                                           10),
                              //                                       decoration:
                              //                                       BoxDecoration(
                              //                                         color: dashboardData
                              //                                             .colors[
                              //                                         index],
                              //                                         borderRadius:
                              //                                         BorderRadius.circular(
                              //                                             15),
                              //                                       ),
                              //                                       child:
                              //                                       SvgPicture
                              //                                           .asset(
                              //                                         "${dashboardData.icons[index]}",
                              //                                         // fit: BoxFit.cover,
                              //                                         height: 30,
                              //                                         width: 30,
                              //                                       )),
                              //                                 ),
                              //                               ],
                              //                             ),
                              //                             const SizedBox(
                              //                                 height: 16),
                              //                             Row(
                              //                               children: [
                              //                                 const SizedBox(
                              //                                     width: 10),
                              //                                 Text(
                              //                                   countList[index]
                              //                                       .toString(),
                              //                                   style:
                              //                                   const TextStyle(
                              //                                     color: Colors
                              //                                         .white,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold,
                              //                                     fontSize: 20,
                              //                                   ),
                              //                                 ),
                              //                               ],
                              //                             ),
                              //                             const SizedBox(
                              //                                 height: 10),
                              //                             Row(
                              //                               children: [
                              //                                 const SizedBox(
                              //                                     width: 10),
                              //                                 Text(
                              //                                   dashboardData
                              //                                       .titles[
                              //                                   index],
                              //                                   style:
                              //                                   const TextStyle(
                              //                                     color: Colors
                              //                                         .white,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold,
                              //                                     fontSize: 18,
                              //                                   ),
                              //                                 ),
                              //                                 SizedBox(
                              //                                   width: 5,
                              //                                 ),
                              //                                 Icon(
                              //                                   Icons
                              //                                       .arrow_forward_rounded,
                              //                                   color:
                              //                                   Colors.white,
                              //                                 ),
                              //                               ],
                              //                             ),
                              //                           ],
                              //                         ),
                              //                       ),
                              //                     ),
                              //                   ),
                              //                 );
                              //               },
                              //               shrinkWrap:
                              //               true, // If you want the GridView to take only the space it needs
                              //               physics:
                              //               const NeverScrollableScrollPhysics(), // If you don't want it to scroll
                              //             ),
                              //           )
                              //         ],
                              //       );
                              //     }
                              //   },
                              // ),
                              // LayoutBuilder(
                              //   builder: (context, constraints) {
                              //     if (constraints.maxWidth > 600) {
                              //       // Tablet layout - horizontal
                              //       return Column(
                              //         children: [
                              //           const SizedBox(
                              //             height: 20,
                              //           ),
                              //           Row(
                              //             children: [
                              //               Container(
                              //                 width: 360,
                              //                 height: 110,
                              //                 margin: EdgeInsets.symmetric(
                              //                     horizontal: width * .040),
                              //                 decoration: const BoxDecoration(
                              //                   borderRadius: BorderRadius.all(
                              //                       Radius.circular(15)),
                              //                 ),
                              //                 child: Material(
                              //                   elevation: 3,
                              //                   borderRadius:
                              //                   const BorderRadius.all(
                              //                       Radius.circular(15)),
                              //                   child: Column(
                              //                     children: [
                              //                       Expanded(
                              //                         flex: 4,
                              //                         child: Container(
                              //                           decoration:
                              //                           const BoxDecoration(
                              //                             color: Color.fromRGBO(
                              //                                 50, 75, 119, 1),
                              //                             borderRadius:
                              //                             BorderRadius.vertical(
                              //                                 top: Radius
                              //                                     .circular(
                              //                                     15)),
                              //                           ),
                              //                           child: const Center(
                              //                               child: Text(
                              //                                 "Rent Due",
                              //                                 style: TextStyle(
                              //                                     color: Colors.white,
                              //                                     fontSize: 16,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold),
                              //                               )),
                              //                         ),
                              //                       ),
                              //                       Expanded(
                              //                         flex: 8,
                              //                         child: Container(
                              //                           decoration:
                              //                           const BoxDecoration(
                              //                             color: Colors.white,
                              //                             borderRadius:
                              //                             BorderRadius.vertical(
                              //                                 bottom: Radius
                              //                                     .circular(
                              //                                     15)),
                              //                           ),
                              //                           child: Padding(
                              //                             padding:
                              //                             const EdgeInsets
                              //                                 .all(8.0),
                              //                             child: Row(
                              //                               mainAxisAlignment:
                              //                               MainAxisAlignment
                              //                                   .spaceEvenly,
                              //                               children: [
                              //                                 Column(
                              //                                   mainAxisAlignment:
                              //                                   MainAxisAlignment
                              //                                       .center,
                              //                                   crossAxisAlignment:
                              //                                   CrossAxisAlignment
                              //                                       .center,
                              //                                   children: [
                              //                                     const Text(
                              //                                       "Current Month",
                              //                                       style: TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold,
                              //                                           color: Color.fromRGBO(
                              //                                               138,
                              //                                               149,
                              //                                               168,
                              //                                               1)),
                              //                                     ),
                              //                                     // SizedBox(height: 8), // Space between the text
                              //                                     Text(
                              //                                       "\$${currentMonthRentDue}",
                              //                                       style: const TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           color: Color.fromRGBO(
                              //                                               90,
                              //                                               134,
                              //                                               213,
                              //                                               1),
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold),
                              //                                     ),
                              //                                   ],
                              //                                 ),
                              //                                 Column(
                              //                                   mainAxisAlignment:
                              //                                   MainAxisAlignment
                              //                                       .center,
                              //                                   crossAxisAlignment:
                              //                                   CrossAxisAlignment
                              //                                       .center,
                              //                                   children: [
                              //                                     const Text(
                              //                                       "Last Month",
                              //                                       style: TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold,
                              //                                           color: Color.fromRGBO(
                              //                                               138,
                              //                                               149,
                              //                                               168,
                              //                                               1)),
                              //                                     ),
                              //                                     // SizedBox(height: 8), // Space between the text
                              //                                     Text(
                              //                                       "\$${lastMonthRentDue}",
                              //                                       style: const TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           color: Color.fromRGBO(
                              //                                               90,
                              //                                               134,
                              //                                               213,
                              //                                               1),
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold),
                              //                                     ),
                              //                                   ],
                              //                                 ),
                              //                               ],
                              //                             ),
                              //                           ),
                              //                         ),
                              //                       ),
                              //                     ],
                              //                   ),
                              //                 ),
                              //               ),
                              //               Container(
                              //                 width: 360,
                              //                 height: 110,
                              //                 margin: EdgeInsets.symmetric(
                              //                     horizontal: width * .00),
                              //                 decoration: const BoxDecoration(
                              //                   borderRadius: BorderRadius.all(
                              //                       Radius.circular(15)),
                              //                 ),
                              //                 child: Material(
                              //                   elevation: 3,
                              //                   borderRadius:
                              //                   const BorderRadius.all(
                              //                       Radius.circular(15)),
                              //                   child: Column(
                              //                     children: [
                              //                       Expanded(
                              //                         flex: 4,
                              //                         child: Container(
                              //                           decoration:
                              //                           const BoxDecoration(
                              //                             color: Color.fromRGBO(
                              //                                 50, 75, 119, 1),
                              //                             borderRadius:
                              //                             BorderRadius.vertical(
                              //                                 top: Radius
                              //                                     .circular(
                              //                                     15)),
                              //                           ),
                              //                           child: const Center(
                              //                               child: Text(
                              //                                 "Rent Paid",
                              //                                 style: TextStyle(
                              //                                     color: Colors.white,
                              //                                     fontSize: 16,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold),
                              //                               )),
                              //                         ),
                              //                       ),
                              //                       Expanded(
                              //                         flex: 8,
                              //                         child: Container(
                              //                           decoration:
                              //                           const BoxDecoration(
                              //                             color: Colors.white,
                              //                             borderRadius:
                              //                             BorderRadius.vertical(
                              //                                 bottom: Radius
                              //                                     .circular(
                              //                                     15)),
                              //                           ),
                              //                           child: Padding(
                              //                             padding:
                              //                             const EdgeInsets
                              //                                 .all(8.0),
                              //                             child: Row(
                              //                               mainAxisAlignment:
                              //                               MainAxisAlignment
                              //                                   .spaceEvenly,
                              //                               children: [
                              //                                 Column(
                              //                                   mainAxisAlignment:
                              //                                   MainAxisAlignment
                              //                                       .center,
                              //                                   crossAxisAlignment:
                              //                                   CrossAxisAlignment
                              //                                       .center,
                              //                                   children: [
                              //                                     const Text(
                              //                                       "Current Month",
                              //                                       style: TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold,
                              //                                           color: Color.fromRGBO(
                              //                                               138,
                              //                                               149,
                              //                                               168,
                              //                                               1)),
                              //                                     ),
                              //                                     // SizedBox(height: 8), // Space between the text
                              //                                     Text(
                              //                                       "\$${currentMonthRentPaid}",
                              //                                       style: const TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           color: Color.fromRGBO(
                              //                                               90,
                              //                                               134,
                              //                                               213,
                              //                                               1),
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold),
                              //                                     ),
                              //                                   ],
                              //                                 ),
                              //                                 Column(
                              //                                   mainAxisAlignment:
                              //                                   MainAxisAlignment
                              //                                       .center,
                              //                                   crossAxisAlignment:
                              //                                   CrossAxisAlignment
                              //                                       .center,
                              //                                   children: [
                              //                                     const Text(
                              //                                       "Last Month",
                              //                                       style: TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold,
                              //                                           color: Color.fromRGBO(
                              //                                               138,
                              //                                               149,
                              //                                               168,
                              //                                               1)),
                              //                                     ),
                              //                                     // SizedBox(height: 8), // Space between the text
                              //                                     Text(
                              //                                       "\$${lastMonthRentPaid}",
                              //                                       style: const TextStyle(
                              //                                           fontSize:
                              //                                           16,
                              //                                           color: Color.fromRGBO(
                              //                                               90,
                              //                                               134,
                              //                                               213,
                              //                                               1),
                              //                                           fontWeight:
                              //                                           FontWeight
                              //                                               .bold),
                              //                                     ),
                              //                                   ],
                              //                                 ),
                              //                               ],
                              //                             ),
                              //                           ),
                              //                         ),
                              //                       ),
                              //                     ],
                              //                   ),
                              //                 ),
                              //               ),
                              //             ],
                              //           ),
                              //           const SizedBox(
                              //             height: 20,
                              //           ),
                              //           Row(
                              //             children: [
                              //               Container(
                              //                 width: 360,
                              //                 height: 110,
                              //                 margin: EdgeInsets.symmetric(
                              //                     horizontal: width * .040),
                              //                 decoration: const BoxDecoration(
                              //                   borderRadius: BorderRadius.all(
                              //                       Radius.circular(15)),
                              //                 ),
                              //                 child: Material(
                              //                   elevation: 3,
                              //                   borderRadius:
                              //                   const BorderRadius.all(
                              //                       Radius.circular(15)),
                              //                   child: Column(
                              //                     children: [
                              //                       Expanded(
                              //                         flex: 4,
                              //                         child: Container(
                              //                           decoration:
                              //                           const BoxDecoration(
                              //                             color: Color.fromRGBO(
                              //                                 50, 75, 119, 1),
                              //                             borderRadius:
                              //                             BorderRadius.vertical(
                              //                                 top: Radius
                              //                                     .circular(
                              //                                     15)),
                              //                           ),
                              //                           child: const Center(
                              //                               child: Text(
                              //                                 "Rent Past Due",
                              //                                 style: TextStyle(
                              //                                     color: Colors.white,
                              //                                     fontSize: 16,
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold),
                              //                               )),
                              //                         ),
                              //                       ),
                              //                       Expanded(
                              //                         flex: 8,
                              //                         child: Container(
                              //                             decoration:
                              //                             const BoxDecoration(
                              //                               color: Colors.white,
                              //                               borderRadius:
                              //                               BorderRadius.vertical(
                              //                                   bottom: Radius
                              //                                       .circular(
                              //                                       15)),
                              //                             ),
                              //                             child: Center(
                              //                               child: Text(
                              //                                 "\$${totalRentPastDue}",
                              //                                 style: const TextStyle(
                              //                                     fontSize: 18,
                              //                                     color: Color
                              //                                         .fromRGBO(
                              //                                         90,
                              //                                         134,
                              //                                         213,
                              //                                         1),
                              //                                     fontWeight:
                              //                                     FontWeight
                              //                                         .bold),
                              //                               ),
                              //                             )),
                              //                       ),
                              //                     ],
                              //                   ),
                              //                 ),
                              //               ),
                              //               Container(
                              //                 width: 350,
                              //                 height: 110,
                              //                 margin: EdgeInsets.symmetric(
                              //                     horizontal: width * .00),
                              //               ),
                              //             ],
                              //           ),
                              //         ],
                              //       );
                              //     } else {
                              //       // Phone layout - vertical
                              //       return Column(
                              //         children: [
                              //           const SizedBox(
                              //             height: 20,
                              //           ),
                              //           InkWell(
                              //             onTap: () {
                              //               Navigator.push(
                              //                   context,
                              //                   MaterialPageRoute(
                              //                       builder: (context) =>
                              //                           RentPastDueReports(
                              //                             title: "Rent Due",
                              //                           )));
                              //             },
                              //             child: Container(
                              //               height: 110,
                              //               margin: EdgeInsets.symmetric(
                              //                   horizontal: width * .05),
                              //               decoration: const BoxDecoration(
                              //                 borderRadius: BorderRadius.all(
                              //                     Radius.circular(15)),
                              //               ),
                              //               child: Material(
                              //                 elevation: 3,
                              //                 borderRadius:
                              //                 const BorderRadius.all(
                              //                     Radius.circular(15)),
                              //                 child: Column(
                              //                   children: [
                              //                     Expanded(
                              //                       flex: 4,
                              //                       child: Container(
                              //                         decoration:
                              //                         const BoxDecoration(
                              //                           color: Color.fromRGBO(
                              //                               50, 75, 119, 1),
                              //                           borderRadius:
                              //                           BorderRadius.vertical(
                              //                               top: Radius
                              //                                   .circular(
                              //                                   15)),
                              //                         ),
                              //                         child: const Center(
                              //                             child: Text(
                              //                               "Rent Due",
                              //                               style: TextStyle(
                              //                                   color: Colors.white,
                              //                                   fontSize: 16,
                              //                                   fontWeight:
                              //                                   FontWeight.bold),
                              //                             )),
                              //                       ),
                              //                     ),
                              //                     Expanded(
                              //                       flex: 8,
                              //                       child: Container(
                              //                         decoration:
                              //                         const BoxDecoration(
                              //                           color: Colors.white,
                              //                           borderRadius:
                              //                           BorderRadius.vertical(
                              //                               bottom: Radius
                              //                                   .circular(
                              //                                   15)),
                              //                         ),
                              //                         child: Padding(
                              //                           padding:
                              //                           const EdgeInsets.all(
                              //                               8.0),
                              //                           child: Row(
                              //                             mainAxisAlignment:
                              //                             MainAxisAlignment
                              //                                 .spaceEvenly,
                              //                             children: [
                              //                               Column(
                              //                                 mainAxisAlignment:
                              //                                 MainAxisAlignment
                              //                                     .center,
                              //                                 crossAxisAlignment:
                              //                                 CrossAxisAlignment
                              //                                     .center,
                              //                                 children: [
                              //                                   const Text(
                              //                                     "Current Month",
                              //                                     style: TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             138,
                              //                                             149,
                              //                                             168,
                              //                                             1)),
                              //                                   ),
                              //                                   // SizedBox(height: 8), // Space between the text
                              //                                   Text(
                              //                                     "\$${currentMonthRentDue.toStringAsFixed(2)}",
                              //                                     style: const TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             90,
                              //                                             134,
                              //                                             213,
                              //                                             1),
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold),
                              //                                   ),
                              //                                 ],
                              //                               ),
                              //                               Column(
                              //                                 mainAxisAlignment:
                              //                                 MainAxisAlignment
                              //                                     .center,
                              //                                 crossAxisAlignment:
                              //                                 CrossAxisAlignment
                              //                                     .center,
                              //                                 children: [
                              //                                   const Text(
                              //                                     "Last Month",
                              //                                     style: TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             138,
                              //                                             149,
                              //                                             168,
                              //                                             1)),
                              //                                   ),
                              //                                   // SizedBox(height: 8), // Space between the text
                              //                                   Text(
                              //                                     "\$${lastMonthRentDue.toStringAsFixed(2)}",
                              //                                     style: const TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             90,
                              //                                             134,
                              //                                             213,
                              //                                             1),
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold),
                              //                                   ),
                              //                                 ],
                              //                               ),
                              //                             ],
                              //                           ),
                              //                         ),
                              //                       ),
                              //                     ),
                              //                   ],
                              //                 ),
                              //               ),
                              //             ),
                              //           ),
                              //           const SizedBox(
                              //             height: 10,
                              //           ),
                              //           InkWell(
                              //             onTap: () {
                              //               Navigator.push(
                              //                   context,
                              //                   MaterialPageRoute(
                              //                       builder: (context) =>
                              //                           RentPastDueReports(
                              //                             isRentdue: true,
                              //                             title: "Rent Paid",
                              //                           )));
                              //             },
                              //             child: Container(
                              //               height: 110,
                              //               margin: EdgeInsets.symmetric(
                              //                   horizontal: width * .05),
                              //               decoration: const BoxDecoration(
                              //                 borderRadius: BorderRadius.all(
                              //                     Radius.circular(15)),
                              //               ),
                              //               child: Material(
                              //                 elevation: 3,
                              //                 borderRadius:
                              //                 const BorderRadius.all(
                              //                     Radius.circular(15)),
                              //                 child: Column(
                              //                   children: [
                              //                     Expanded(
                              //                       flex: 4,
                              //                       child: Container(
                              //                         decoration:
                              //                         const BoxDecoration(
                              //                           color: Color.fromRGBO(
                              //                               50, 75, 119, 1),
                              //                           borderRadius:
                              //                           BorderRadius.vertical(
                              //                               top: Radius
                              //                                   .circular(
                              //                                   15)),
                              //                         ),
                              //                         child: const Center(
                              //                             child: Text(
                              //                               "Rent Paid",
                              //                               style: TextStyle(
                              //                                   color: Colors.white,
                              //                                   fontSize: 16,
                              //                                   fontWeight:
                              //                                   FontWeight.bold),
                              //                             )),
                              //                       ),
                              //                     ),
                              //                     Expanded(
                              //                       flex: 8,
                              //                       child: Container(
                              //                         decoration:
                              //                         const BoxDecoration(
                              //                           color: Colors.white,
                              //                           borderRadius:
                              //                           BorderRadius.vertical(
                              //                               bottom: Radius
                              //                                   .circular(
                              //                                   15)),
                              //                         ),
                              //                         child: Padding(
                              //                           padding:
                              //                           const EdgeInsets.all(
                              //                               8.0),
                              //                           child: Row(
                              //                             mainAxisAlignment:
                              //                             MainAxisAlignment
                              //                                 .spaceEvenly,
                              //                             children: [
                              //                               Column(
                              //                                 mainAxisAlignment:
                              //                                 MainAxisAlignment
                              //                                     .center,
                              //                                 crossAxisAlignment:
                              //                                 CrossAxisAlignment
                              //                                     .center,
                              //                                 children: [
                              //                                   const Text(
                              //                                     "Current Month",
                              //                                     style: TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             138,
                              //                                             149,
                              //                                             168,
                              //                                             1)),
                              //                                   ),
                              //                                   // SizedBox(height: 8), // Space between the text
                              //                                   Text(
                              //                                     "\$${currentMonthRentPaid.toStringAsFixed(2)}",
                              //                                     style: const TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             90,
                              //                                             134,
                              //                                             213,
                              //                                             1),
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold),
                              //                                   ),
                              //                                 ],
                              //                               ),
                              //                               Column(
                              //                                 mainAxisAlignment:
                              //                                 MainAxisAlignment
                              //                                     .center,
                              //                                 crossAxisAlignment:
                              //                                 CrossAxisAlignment
                              //                                     .center,
                              //                                 children: [
                              //                                   const Text(
                              //                                     "Last Month",
                              //                                     style: TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             138,
                              //                                             149,
                              //                                             168,
                              //                                             1)),
                              //                                   ),
                              //                                   // SizedBox(height: 8), // Space between the text
                              //                                   Text(
                              //                                     "\$${lastMonthRentPaid.toStringAsFixed(2)}",
                              //                                     style: const TextStyle(
                              //                                         fontSize:
                              //                                         16,
                              //                                         color: Color
                              //                                             .fromRGBO(
                              //                                             90,
                              //                                             134,
                              //                                             213,
                              //                                             1),
                              //                                         fontWeight:
                              //                                         FontWeight
                              //                                             .bold),
                              //                                   ),
                              //                                 ],
                              //                               ),
                              //                             ],
                              //                           ),
                              //                         ),
                              //                       ),
                              //                     ),
                              //                   ],
                              //                 ),
                              //               ),
                              //             ),
                              //           ),
                              //           const SizedBox(
                              //             height: 10,
                              //           ),
                              //           InkWell(
                              //             onTap: () {
                              //               Navigator.push(
                              //                   context,
                              //                   MaterialPageRoute(
                              //                       builder: (context) =>
                              //                           RentPastDueReports(
                              //                             title: "Rent Past Due",
                              //                           )));
                              //             },
                              //             child: Container(
                              //               height: 110,
                              //               margin: EdgeInsets.symmetric(
                              //                   horizontal: width * .05),
                              //               decoration: const BoxDecoration(
                              //                 borderRadius: BorderRadius.all(
                              //                     Radius.circular(15)),
                              //               ),
                              //               child: Material(
                              //                 elevation: 3,
                              //                 borderRadius:
                              //                 const BorderRadius.all(
                              //                     Radius.circular(15)),
                              //                 child: Column(
                              //                   children: [
                              //                     Expanded(
                              //                       flex: 4,
                              //                       child: Container(
                              //                         decoration:
                              //                         const BoxDecoration(
                              //                           color: Color.fromRGBO(
                              //                               50, 75, 119, 1),
                              //                           borderRadius:
                              //                           BorderRadius.vertical(
                              //                               top: Radius
                              //                                   .circular(
                              //                                   15)),
                              //                         ),
                              //                         child: const Center(
                              //                             child: Text(
                              //                               "Rent Past Due",
                              //                               style: TextStyle(
                              //                                   color: Colors.white,
                              //                                   fontSize: 16,
                              //                                   fontWeight:
                              //                                   FontWeight.bold),
                              //                             )),
                              //                       ),
                              //                     ),
                              //                     Expanded(
                              //                       flex: 8,
                              //                       child: Container(
                              //                           decoration:
                              //                           const BoxDecoration(
                              //                             color: Colors.white,
                              //                             borderRadius:
                              //                             BorderRadius.vertical(
                              //                                 bottom: Radius
                              //                                     .circular(
                              //                                     15)),
                              //                           ),
                              //                           child: Center(
                              //                             child: Text(
                              //                               "\$${totalRentPastDue.toStringAsFixed(2)}",
                              //                               style: const TextStyle(
                              //                                   fontSize: 18,
                              //                                   color: Color
                              //                                       .fromRGBO(
                              //                                       90,
                              //                                       134,
                              //                                       213,
                              //                                       1),
                              //                                   fontWeight:
                              //                                   FontWeight
                              //                                       .bold),
                              //                             ),
                              //                           )),
                              //                     ),
                              //                   ],
                              //                 ),
                              //               ),
                              //             ),
                              //           ),
                              //         ],
                              //       );
                              //     }
                              //   },
                              // ),
                              // LayoutBuilder(
                              //   builder: (BuildContext context,
                              //       BoxConstraints constraints) {
                              //     // Check if the device width is less than 600 (considered as phone screen)
                              //     if (constraints.maxWidth < 500) {
                              //       // Phone layout
                              //       return Column(
                              //         children: [
                              //
                              //           FlChartApp(
                              //             data: data,
                              //           ),
                              //           // Vertical layout for phone
                              //           SizedBox(
                              //               height: MediaQuery.of(context)
                              //                   .size
                              //                   .height *
                              //                   0.015),
                              //           Padding(
                              //             padding: const EdgeInsets.only(
                              //                 left: 0, right: 8),
                              //             child: Barchart(),
                              //           ),
                              //           Padding(
                              //             padding: const EdgeInsets.only(
                              //                 left: 0, right: 8),
                              //             child: Cronjob_payment_table(),
                              //           ),
                              //           Padding(
                              //             padding: const EdgeInsets.only(
                              //                 left: 0, right: 8),
                              //             child: Dashboard_leaseExpiring(),
                              //           ),
                              //           SizedBox(height: 8,),
                              //           Padding(
                              //             padding: const EdgeInsets.only(
                              //                 left: 0, right: 8),
                              //             child: Dashboard_Policy_Table(),
                              //           ),
                              //
                              //         ],
                              //       );
                              //     } else {
                              //       // Tablet layout
                              //       return Padding(
                              //         padding: const EdgeInsets.only(
                              //           top: 10,
                              //         ),
                              //         child: Row(
                              //           children: [
                              //             const SizedBox(
                              //               width: 20,
                              //             ),
                              //             Padding(
                              //               padding: const EdgeInsets.only(
                              //                   left: 10, right: 10),
                              //               child: PieCharts(dataMap: {
                              //                 "Properties":
                              //                 countList[0].toDouble(),
                              //                 "Gap1": 0.2,
                              //                 "Tenants": countList[1].toDouble(),
                              //                 "Gap2": 0.2,
                              //                 "Applicants":
                              //                 countList[2].toDouble(),
                              //                 "Gap3": 0.2,
                              //                 "Vendors": countList[3].toDouble(),
                              //                 "Gap4": 0.2,
                              //                 "Work Orders":
                              //                 countList[4].toDouble(),
                              //                 "Gap5": 0.2,
                              //               }),
                              //             ),
                              //             const SizedBox(
                              //               width: 10,
                              //             ),
                              //             Barchart(),
                              //           ],
                              //         ),
                              //       );
                              //     }
                              //   },
                              // ),
                            ],
                          ),
                        ),
                )
              : NoInternetView(onRetry: retryNow)),
    );
  }

  /* Widget buildListTile(BuildContext context,Widget leadingIcon, String title,bool active) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: active?blueColor:Colors.transparent,
          borderRadius: BorderRadius.circular(10)
      ),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(

        leading: leadingIcon,
        title: Text(title,style: TextStyle(
            color: active?Colors.white:Colors.black
        ),),
      ),
    );
  }*/
  /* Widget buildDropdownListTile(
      BuildContext context,Widget leadingIcon, String title, List<String> subTopics) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ExpansionTile(
        leading: leadingIcon,
        title: Text(title),
        children: subTopics.map((subTopic) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              title: Text(subTopic),
              onTap: () {
                // Handle sub-topic selection
                Navigator.pop(
                    context); // Close drawer after selecting a sub-topic
              },
            ),
          );
        }).toList(),
      ),
    );
  }*/

  Future<bool> _showExitPopup(BuildContext context) async {
    bool exitConfirmed = false;

    await Alert(
      context: context,
      type: AlertType.warning,
      title: "Exit App",
      desc: "Do you want to exit the app?",
      style: AlertStyle(
        backgroundColor: Colors.white,
        titleStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        descStyle: TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
        animationType: AnimationType.grow,
        isOverlayTapDismiss: false,
        overlayColor: Colors.black.withOpacity(0.5),
        alertBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: BorderSide(color: Colors.blue, width: 2),
        ),
        alertPadding: EdgeInsets.all(16.0),
      ),
      buttons: [
        DialogButton(
          child: Text(
            "No",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
          color: Colors.red,
          radius: BorderRadius.circular(8.0),
        ),
        DialogButton(
          child: Text(
            "Yes",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () {
            exitConfirmed = true;
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else if (Platform.isIOS) {
              exit(0);
            }
          },
          color: Colors.green,
          radius: BorderRadius.circular(8.0),
        ),
      ],
    ).show();

    return exitConfirmed;
  }
}
