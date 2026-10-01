import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/screen/Dashboard/cronjob_payment_table.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/Applicants/Applicants_table.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Vendor/Vendor_table.dart';
import 'package:three_zero_two_property/StaffModule/screen/Dashboard/Unpaid_Properties.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/lease_table.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/Properties_table.dart';
// Wizard not used for now: same Add Work Order screen as web/tablet (phone skill = easy access, not different UI).
// import 'package:three_zero_two_property/screens/Maintenance/Workorder/AddWorkOrderMobileWizard.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/Add_workorder.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Tenants/Tenants_table.dart';
import 'package:three_zero_two_property/widgets/pie_chart.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/properties.dart';
import '../../Model/properties.dart';
import '../../constant/geolocation_data_filter.dart';
import '../../model/properties_workorders.dart';
import '../../screens/Dashboard/dashboard_sample.dart';
import 'Dashboard/dashboard_leaseExpiring_staff.dart';
import '../../screens/Rental/Properties/summery_page.dart';
import '../model/staffpermission.dart';
import '../repository/staffpermission_provider.dart';
import '../widgets/appbar.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../constant/constant.dart';
import '../../repository/RentPastDue.dart';
import '../../provider/dateProvider.dart';
import '../widgets/drawer_tiles.dart';
import '../widgets/custom_drawer.dart';
import '../../widgets/barchart.dart';
import '../widgets/chart.dart';
import '../../../../model/workordr.dart';
import '../screen/Maintenance/Workorder/workorder_summery.dart';
import 'profile.dart';
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
    "assets/icons/Frame1.svg"
  ];

  List<String> titles = [
    "Properties",
    "Tenants",
    "Applicants",
    "Vendors",
    "Unpaid Properties"
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

class Dashboard_staff extends StatefulWidget {
  Dashboard_staff({super.key});

  @override
  State<Dashboard_staff> createState() => _Dashboard_staffState();
}

class _Dashboard_staffState extends State<Dashboard_staff>
    with WidgetsBindingObserver, NetworkRetryState {
  String firstname = '';
  String lastname = '';
  bool loading = false;
  List<Rentals> properties = [];
  Rentals? nearstProperty;
  final List<Widget> pages = [
    PropertiesTable(),
    Tenants_table(),
    Applicants_table(),
    const Vendor_table(),
    const Unpaid_Properties(),
  ];
  List<Data> nearestWorkOrders = [];
  List<Data> nearestPropertyWorkOrders = [];
  StaffPermission? permissions;
  int totalWorkOrders = 0;

  /// True when at least one nearby/nearest property has an open (non-Completed) work order.
  /// When false, show normal dashboard; when true, show 5 miles dashboard.
  bool get hasNearbyPropertiesWithOpenWorkOrders {
    final nearbyRentalIds = <String>{};
    for (var r in properties) {
      if (r.rentalId != null) nearbyRentalIds.add(r.rentalId!);
    }
    if (nearstProperty?.rentalId != null) {
      nearbyRentalIds.add(nearstProperty!.rentalId!);
    }
    return nearestWorkOrders.any((wo) {
      final rid = wo.rentalAddress?.rentalId;
      if (rid == null || !nearbyRentalIds.contains(rid)) return false;
      final status = wo.workOrderData?.status ?? '';
      return status != 'Completed';
    });
  }

  Future<void> fetchDatacount() async {
    /*setState(() {
      loading = true;
    });*/
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
      String? admin_id = prefs.getString("adminId");
      String? token = prefs.getString('token');


      final response = await apiGet(
          Uri.parse('${Api_url}/api/staffmember/count/${id!}/${admin_id}'),
          headers: {
            "id": "CRM $id",
            "authorization": "CRM $token",
            "Content-Type": "application/json"
          });
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200) {
        setState(() {
          countList[0] = jsonData['property_staffMember'] ?? 0;
          countList[1] = jsonData['tenant_staffMember'] ?? 0;
          countList[2] = jsonData['applicant_staffMember'] ?? 0;
          countList[3] = jsonData['vendor_staffMember'] ?? 0;
          loading = false;
        });
        // Rent balance data from admin balance API
        try {
          final balanceRes = await apiGet(
            Uri.parse('${Api_url}/api/payment/admin_balance/$admin_id'),
            headers: {
              "id": "CRM $id",
              "authorization": "CRM $token",
              "Content-Type": "application/json",
            },
          );
          if (balanceRes.statusCode == 200) {
            final balanceJson = json.decode(balanceRes.body);
            if (balanceJson["statusCode"] == 200 && balanceJson["data"] != null) {
              final data = balanceJson["data"];
              setState(() {
                countList[4] = data["totalUnpaidRentLeases"] as int? ?? 0;
                currentMonthRentDue = (data["currentMonthRentDue"] as num?)?.toDouble() ?? 0.0;
                lastMonthRentDue = (data["lastMonthRentDue"] as num?)?.toDouble() ?? 0.0;
                currentMonthRentPaid = (data["currentMonthRentPaid"] as num?)?.toDouble() ?? 0.0;
                lastMonthRentPaid = (data["lastMonthRentPaid"] as num?)?.toDouble() ?? 0.0;
                totalRentPastDue = (data["totalRentPastDue"] as num?)?.toDouble() ?? 0.0;
              });
            }
          }
        } catch (_) {}
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      logError('Error fetching data: $e');
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  // Coming back from a dashboard card: reload the counts and work-order
  // numbers in place (both loads are loader-free). Guarded so a failed or
  // late reply leaves the current numbers instead of surfacing an error.
  Future<void> _refreshCountsQuietly() async {
    if (!mounted) return;
    try {
      await fetchDatacount();
      if (!mounted) return;
      await fetchData();
    } catch (e) {
      logError('Error refreshing dashboard counts: $e');
    }
  }

  int newworkorder = 0;
  int overdueworkorder = 0;
  double currentMonthRentDue = 0.0;
  double lastMonthRentDue = 0.0;
  double currentMonthRentPaid = 0.0;
  double lastMonthRentPaid = 0.0;
  double totalRentPastDue = 0.0;
  // True when the last load couldn't get a location (off/denied/timeout), so the
  // app-resume handler knows it's worth silently re-fetching the nearby section.
  bool _locationWasUnavailable = false;

  // Watches the device location toggle so nearby can load the instant location is
  // switched on — even without leaving the app. Cancelled in dispose.
  StreamSubscription<ServiceStatus>? _serviceStatusSub;

  Future<Map<String, dynamic>> fetchProperties({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
      });
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');

    final response = await apiGet(
      // `limit=0` is the server's own no-limit flag; without it the API
      // returns a page of 10 (Rentals.js) and this picker is truncated.
      Uri.parse('${Api_url}/api/rentals/rentals/$adminid?limit=0'),
      headers: {"authorization": "CRM $token", "id": "CRM $id"},
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      // Check the statusCode in the response body
      if (responseData['statusCode'] == 200) {
        List jsonResponse = responseData['data'];
        List<Rentals> rentals =
        jsonResponse.map((data) => Rentals.fromJson(data)).toList();

        try {
          // Time-box location so a hanging GPS request can't freeze the Staff
          // dashboard (matches the Vendor dashboard's 15s timeout).
          Position userLocation =
              await getCurrentLocation().timeout(const Duration(seconds: 15));
          _locationWasUnavailable = false;
          Rentals? nearestProperty;
          double minDistance = double.infinity;
          List<Rentals> nearbyProperties = [];

          for (Rentals rental in rentals) {
            final coords = await getCoordinatesFromAddress(rental);
            if (coords != null) {
              double distanceInMeters = Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                // 39.6613845,
                // -75.6339627,
                coords.latitude,
                coords.longitude,
              );

              double distanceInKm = distanceInMeters / 1000;
              if (distanceInKm <= 5) {
                // Track nearest
                if (distanceInMeters < minDistance) {
                  minDistance = distanceInMeters;
                  nearestProperty = rental;
                }
                // Add to nearby (will remove nearest later to avoid duplication)
                nearbyProperties.add(rental);
              }
            }
          }

          // Remove nearest from nearby list to avoid duplication
          if (nearestProperty != null) {
            nearbyProperties
                .removeWhere((r) => r.rentalId == nearestProperty!.rentalId);
          }

          return {
            "nearest": nearestProperty,
            "nearby": nearbyProperties,
          };
        } catch (e) {
          _locationWasUnavailable = true;
          logError('[LOCATION][Staff] location unavailable (off/denied/timeout) → nearby skipped: $e');
          setState(() {
            loading = false;
          });
          return {};
        }
      } else if (responseData['statusCode'] == 201) {
        // No rentals found for the specified admin
        setState(() {
          loading = false;
        });
        return {};
      } else {
        setState(() {
          loading = false;
        });
        return {};
      }
    } else {
      setState(() {
        loading = false;
      });
      return {};
    }
  }

  void fetchNearbyProperties({bool silent = false, bool nearbyOnly = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
      });
    }
    // Load counts / data / name up front (independent of location) so they
    // appear immediately instead of waiting behind the location lookup — and
    // so both initState and the refresh button get them via this one method.
    // nearbyOnly (app-resume / location-toggle refresh) skips these 3
    // location-independent calls, so a brief app-switch doesn't re-hit them —
    // only the location-dependent nearby lookup below is redone.
    if (!nearbyOnly) {
      fetchDatacount();
      fetchData();
      _loadName();
    }
    final result = await fetchProperties(silent: silent);
    if (result.isNotEmpty) {
      List<Data> workOrders = await fetchWorkOrders("");
      nearstProperty = result["nearest"];
      if (nearstProperty != null) {
        nearestPropertyWorkOrders = workOrders
            .where((workOrder) =>
        workOrder.rentalAddress != null &&
            workOrder.rentalAddress!.rentalId ==
            nearstProperty!.rentalId! &&
            (workOrder.workOrderData?.status ?? "") != "Completed")
            .toList();
      }
// Multiple near properties work orders
      List<dynamic> multipleRentalIds = result["nearby"]
          .where((property) => property.rentalId != null)
          .map((property) => property.rentalId!)
          .toList();

      // List<Data> multiplePropertiesWorkOrders = workOrders
      //     .where((workOrder) => multipleRentalIds.contains(workOrder.rentalAddress!.rentalId))
      //     .toList();

      setState(() {
        // nearestProperty = nearest;
        properties = result["nearby"];
        nearestWorkOrders = workOrders;
        // nearestPropertyWorkOrders = nearestPropertyWorkOrders;
        loading = false;
      });
    } else {
      // Location off/denied or no data: clear any stale nearby results so an
      // old list can't linger under the "turn on location" banner.
      if (mounted) {
        setState(() {
          nearstProperty = null;
          properties = [];
          nearestPropertyWorkOrders = [];
        });
      }
    }
    // setState(() {
    //   properties = data;
    // });
    // (counts / data / name are now loaded at the top of this method, once.)
  }

  Future<void> fetchData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("staff_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiGet(
        Uri.parse(
            '${Api_url}/api/staffmember/dashboard_workorder/$id/$admin_id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json"
        });
    //print('${Api_url}/api/payment/admin_balance/$id');
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200) {
        final data = jsonData["data"];
        setState(() {
          List newwork = data["new_workorder"];
          List overdue = data["overdue_workorder"];
          newworkorder = newwork.length;
          overdueworkorder = overdue.length;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } else {
      throw Exception('Failed to load data');
    }
  }

  Future<List<Data>> fetchWorkOrders(String rentalId) async {
    // Retrieve admin ID and token from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    // Define the URL and headers for the request
    final response = await apiGet(
      Uri.parse('$Api_url/api/work-order/work-orders/$adminid'),
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
      return jsonResponse.map((data) => Data.fromJson(data)).toList();
    } else {
      // Throw an exception if the request failed
      throw Exception('No work order found');
    }
  }

  late DashboardData dashboardData;
  List<int> countList = List.filled(5, 0);
  List<int> amountList = List.filled(5, 0);

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// fetchNearbyProperties() loads the counts, the data and the name itself,
  /// so this one call is the whole dashboard. The lifecycle observer and the
  /// location-service listener initState also sets up are NOT re-registered.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    // Permissions are fetched once, at Splash. If the app started offline
    // that fetch failed, every gated drawer item vanished, and nothing ever
    // tried again — so refetch here, the screen that recovers on reconnect.
    Provider.of<StaffPermissionProvider>(context, listen: false)
        .fetchPermissions();
    fetchNearbyProperties();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForLocationServiceOn();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    dashboardData = DashboardData(countList: [0, 0], amountList: [0, 0]);
    // fetchNearbyProperties() loads counts / data / name itself (once), so they
    // are no longer called again here — they were previously firing twice.
    fetchNearbyProperties();
  }

  // Instant nearby-load when the device location service is switched ON while the
  // app is open (stronger than resume-only). Fully guarded so it can neither crash
  // nor disturb other logic: wrapped in try/catch, stream errors swallowed, gated
  // on the same _locationWasUnavailable flag, and it only calls the existing silent
  // fetch (no new fetch / nearby logic).
  void _listenForLocationServiceOn() {
    try {
      _serviceStatusSub = Geolocator.getServiceStatusStream().listen(
        (ServiceStatus status) {
          if (status == ServiceStatus.enabled &&
              _locationWasUnavailable &&
              mounted) {
            fetchNearbyProperties(silent: true, nearbyOnly: true);
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Platform can't stream service status → skip; resume-refresh still covers it.
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _serviceStatusSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // User returned to the foreground (e.g. after enabling location in
    // Settings). Silently re-fetch the nearby section only if location was
    // unavailable last time — no full-screen spinner, no re-login, and no
    // needless API call when nearby already loaded.
    if (state == AppLifecycleState.resumed && _locationWasUnavailable) {
      fetchNearbyProperties(silent: true, nearbyOnly: true);
    }
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back (reliably so on the
    // iOS simulator), which made this screen declare itself offline
    // while requests actually succeed. Confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  Future<void> _loadName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      firstname = prefs.getString('first_name') ?? '';
      lastname = prefs.getString('last_name') ?? '';
    });
  }

  Future<bool> _showExitPopup(BuildContext context) async {
    bool exitConfirmed = false;

    await Alert(
      context: context,
      type: AlertType.warning,
      title: "Exit App",
      desc: "Do you want to exit the app?",
      style: AlertStyle(
        backgroundColor: Colors.white,
        titleStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        descStyle: const TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
        animationType: AnimationType.grow,
        isOverlayTapDismiss: false,
        overlayColor: Colors.black.withOpacity(0.5),
        alertBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          side: const BorderSide(color: Colors.blue, width: 2),
        ),
        alertPadding: const EdgeInsets.all(16.0),
      ),
      buttons: [
        DialogButton(
          child: const Text(
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
          child: const Text(
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

  // ==========================================================================
  // PHONE SKILL – STAFF MODULE & ADMIN MODULE (explained in detail)
  // ==========================================================================
  //
  // What "phone skill" means: easy access to key field tasks from the dashboard
  // on phone (width < 600). Same screens and flow as web – no wizard, no extra UI.
  //
  // --- STAFF MODULE (this file) ---
  // • When: Staff opens dashboard on a phone/small tablet (width < 600).
  // • What appears: An "In the field" section at the top with 3 actions.
  // • Add Work Order: 1 tap → opens the SAME Add Work Order form as web
  //   (ResponsiveAddWorkOrder from StaffModule). If the app has detected a
  //   "nearest property" (from device location), that property is pre-filled
  //   so staff does not have to search when they are on site.
  // • Take Payment: 1 tap → opens Leases list (Staff Lease_table). Staff
  //   picks a lease → opens lease summary → uses "Make payment" there. Same
  //   flow as Drawer → Leasing → Leases, but one tap from dashboard.
  // • Work Orders: 1 tap → opens Work Orders list (same as tapping the
  //   Work Orders card in the dashboard).
  //
  // --- ADMIN MODULE (screens/Dashboard/dashboard_one.dart) ---
  // • Same idea: on phone (width < 600), "In the field" quick actions at top.
  // • Add Work Order: 1 tap → same Add Work Order form as web (ResponsiveAddWorkOrder
  //   from main app). Admin has no "nearest property" so no pre-fill.
  // • Take Payment: 1 tap → Leases list (admin Lease_table) → pick lease →
  //   Make payment on lease summary.
  // • Work Orders: 1 tap → Work Orders list.
  //
  // --- TO DISABLE (comment for now) ---
  // In THIS file: comment out the two lines that show the quick actions:
  //   (1) "if (width < 600) _buildQuickActionsForField(context, width),"
  //   (2) the "if (width < 600) SizedBox(...)" right below it.
  // You can also comment out _buildQuickActionsForField and _quickActionCard
  // methods below if you want. To turn it back on later, uncomment the same.
  //
  // --- TO USE WIZARD INSTEAD (optional, later) ---
  // Uncomment the AddWorkOrderMobileWizard import at top and in the Add Work
  // Order onTap use: AddWorkOrderMobileWizard(rentalid: nearstProperty?.rentalId).
  // ==========================================================================

  Widget _buildQuickActionsForField(BuildContext context, double width) {
    return Container(
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
                    // Use same Add Work Order screen as web (no wizard). Pre-fill property when at nearest site.
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ResponsiveAddWorkOrder(
                          rentalid: nearstProperty?.rentalId,
                        ),
                      ),
                    );
                    if (result == true) {
                      fetchNearbyProperties();
                      fetchDatacount();
                      fetchData();
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
                  icon: Icons.layers_outlined,
                  label: 'Unpaid Properties',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const Unpaid_Properties(),
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

  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      // decoration: BoxDecoration(
      //   color: blueColor,
      //   borderRadius: const BorderRadius.only(
      //     topLeft: Radius.circular(10),
      //     topRight: Radius.circular(10),
      //   ),
      // ),
      decoration: BoxDecoration(
          color: Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        // leading: Container(
        //   child: Icon(
        //     Icons.expand_less,
        //     color: Colors.transparent,
        //   ),
        // ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              flex: 4,
              child: InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    width < 400
                        ? Text("  Work Order ",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold))
                        : Text("  Work Order",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Text("Status",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                    SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            // Expanded(
            //   flex: 3,
            //   child: InkWell(
            //     onTap: () {},
            //     child: Row(
            //       children: [
            //         const Text("      Billable ",
            //             style: TextStyle(color: Colors.white)),
            //         const SizedBox(width: 5),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  int? expandedIndex;
  int? expandedIndexrow;
  var appBarHeight = AppBar().preferredSize.height;
  @override
  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<StaffPermissionProvider>(context);
    final dateProvider = Provider.of<DateProvider>(context);
    permissions = permissionProvider.permissions;
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return WillPopScope(
      onWillPop: () async {
        return await _showExitPopup(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: CustomDrawerStaff(
          currentpage: 'Dashboard',
          dropdown: false,
        ),
        appBar: widget_302_Staff.App_Bar(context: context),
        body: !isOffline
            ? loading
            ? Center(
          child: Lottie.asset('assets/images/loader.json',
              height: 150, width: 100),
        )
            : (properties.length > 0 || nearstProperty != null) &&
            hasNearbyPropertiesWithOpenWorkOrders
            ? SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 11, right: 11),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (BuildContext context,
                      BoxConstraints constraints) {
                    return Row(
                      children: [
                        SizedBox(width: width * 0.014),
                        // Container(
                        //   color: Color.fromRGBO(2, 121, 210, 1),
                        //   margin: EdgeInsets.only(
                        //     top: MediaQuery.of(context)
                        //             .size
                        //             .height *
                        //         0.012,
                        //   ),
                        //   width: 3,
                        //   child: Column(
                        //     children: [
                        //       Container(
                        //         height: MediaQuery.of(context)
                        //                     .size
                        //                     .height *
                        //                 0.012 +
                        //             MediaQuery.of(context)
                        //                     .size
                        //                     .width *
                        //                 0.04 +
                        //             3 +
                        //             16,
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        Column(
                          mainAxisAlignment:
                          MainAxisAlignment.start,
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                                height: MediaQuery.of(context)
                                    .size
                                    .height *
                                    0.012),
                            Row(
                              children: [
                                // SizedBox(width: width * 0.05),
                                Text(
                                  "Hello $firstname $lastname, Welcome back",
                                  style: TextStyle(
                                    color: blueColor,
                                    fontSize: MediaQuery.of(
                                        context)
                                        .size
                                        .width >
                                        500
                                        ? MediaQuery.of(context)
                                        .size
                                        .width *
                                        0.03
                                        : MediaQuery.of(context)
                                        .size
                                        .width *
                                        0.04,
                                  ),
                                ),
                              ],
                            ),
                            //   SizedBox(height: 3),
                            // My Dashboard
                            Row(
                              children: [
                                // SizedBox(width: width * 0.05),
                                Text(
                                  "My Dashboard",
                                  style: TextStyle(
                                    color: blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: MediaQuery.of(
                                        context)
                                        .size
                                        .width >
                                        500
                                        ? MediaQuery.of(context)
                                        .size
                                        .width *
                                        0.03
                                        : MediaQuery.of(context)
                                        .size
                                        .width *
                                        0.04,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(
                    height: MediaQuery.of(context).size.height *
                        0.02),
                // Quick actions for field (phone): easy access to Add Work Order & Take Payment
                // Phone skill: quick actions on phone. To enable, uncomment next 4 lines.
                // if (width < 600) _buildQuickActionsForField(context, width),
                // if (width < 600)
                //   SizedBox(
                //       height: MediaQuery.of(context).size.height *
                //           0.02),
                if (nearestPropertyWorkOrders.length > 0)
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          border: Border.all(
                              color: const Color(0xFF8A95A8)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: blueColor,
                                  fontSize: MediaQuery.of(context)
                                      .size
                                      .width >
                                      500
                                      ? MediaQuery.of(context)
                                      .size
                                      .width *
                                      0.03
                                      : 14,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                    "${nearstProperty!.rentalAddress!} ",
                                    style: const TextStyle(
                                        fontWeight:
                                        FontWeight.bold),
                                  ),
                                  const TextSpan(
                                    text:
                                    "is your current property. See open work orders below.",
                                    style: TextStyle(
                                        fontWeight:
                                        FontWeight.normal),
                                  ),
                                ],
                              ),
                            )),
                      ),
                      const SizedBox(height: 15),
                      _buildHeaders(),
                      // const SizedBox(height: 20),
                      Container(
                        child: Column(
                          children: nearestPropertyWorkOrders
                          //  .where((workOrder) => workOrder!.rentalAddress!.rentalId == nearstProperty!.rentalId).toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            int index = entry.key;
                            bool isExpanded =
                                expandedIndex == index;
                            Data workOrder = entry.value;
                            //return CustomExpansionTile(data: Data, index: index);
                            return Container(
                              margin: EdgeInsets.symmetric(
                                  vertical: 6),
                              decoration: BoxDecoration(
                                color: index % 2 != 0
                                    ? Color(0xFFF4F8FF)
                                    : Colors.white,
                                border: Border.all(
                                    color: Color(0xFFDBE0E5)),
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: <Widget>[
                                  ListTile(
                                    onTap: () {
                                      setState(() {
                                        if (expandedIndex ==
                                            index) {
                                          expandedIndex = null;
                                        } else {
                                          expandedIndex = index;
                                        }
                                      });
                                    },
                                    contentPadding:
                                    EdgeInsets.zero,
                                    title: Padding(
                                      padding:
                                      const EdgeInsets.all(
                                          2.0),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .start,
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .center,
                                        children: <Widget>[
                                          InkWell(
                                            onTap: () {
                                              // setState(() {
                                              //    isExpanded = !isExpanded;
                                              // //  expandedIndex = !expandedIndex;
                                              //
                                              // });
                                              // setState(() {
                                              //   if (isExpanded) {
                                              //     expandedIndex = null;
                                              //     isExpanded = !isExpanded;
                                              //   } else {
                                              //     expandedIndex = index;
                                              //   }
                                              // });
                                              setState(() {
                                                if (expandedIndex ==
                                                    index) {
                                                  expandedIndex =
                                                  null;
                                                } else {
                                                  expandedIndex =
                                                      index;
                                                }
                                              });
                                            },
                                            child: Container(
                                              margin:
                                              const EdgeInsets
                                                  .only(
                                                  left: 5,
                                                  right: 8),
                                              padding: !isExpanded
                                                  ? const EdgeInsets
                                                  .only(
                                                  bottom: 10)
                                                  : const EdgeInsets
                                                  .only(
                                                  top: 10),
                                              child: FaIcon(
                                                isExpanded
                                                    ? FontAwesomeIcons
                                                    .sortUp
                                                    : FontAwesomeIcons
                                                    .sortDown,
                                                size: 20,
                                                color: blueColor,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              '${workOrder.workOrderData!.workSubject}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight:
                                                FontWeight
                                                    .bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                              width: MediaQuery.of(
                                                  context)
                                                  .size
                                                  .width *
                                                  .06),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              '${workOrder.workOrderData?.status ?? "N/A"}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight:
                                                FontWeight
                                                    .bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                              width: MediaQuery.of(
                                                  context)
                                                  .size
                                                  .width *
                                                  .03),
                                          // Expanded(
                                          //   flex: 3,
                                          //   child: Row(
                                          //     mainAxisAlignment:
                                          //     MainAxisAlignment
                                          //         .center,
                                          //     crossAxisAlignment:
                                          //     CrossAxisAlignment
                                          //         .center,
                                          //     children: [
                                          //       if (workOrder
                                          //           .workOrderData!
                                          //           .isBillable ==
                                          //           true)
                                          //         Icon(
                                          //           Icons.check,
                                          //           color:
                                          //           blueColor,
                                          //         ),
                                          //       if (workOrder
                                          //           .workOrderData!
                                          //           .isBillable ==
                                          //           false)
                                          //         Icon(
                                          //           Icons.close,
                                          //           color:
                                          //           blueColor,
                                          //         ),
                                          //     ],
                                          //   ),
                                          // ),
                                          // SizedBox(
                                          //     width: MediaQuery.of(
                                          //         context)
                                          //         .size
                                          //         .width *
                                          //         .02),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isExpanded)
                                    Container(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 2),
                                      margin:
                                      const EdgeInsets.only(
                                          bottom: 1),
                                      child:
                                      SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                FaIcon(
                                                  isExpanded
                                                      ? FontAwesomeIcons
                                                      .sortUp
                                                      : FontAwesomeIcons
                                                      .sortDown,
                                                  size: 30,
                                                  color: Colors
                                                      .transparent,
                                                ),
                                                Expanded(
                                                  child: Table(
                                                    columnWidths: {
                                                      0: const FlexColumnWidth(), // Distribute columns equally
                                                      1: const FlexColumnWidth(),
                                                      // 0: FixedColumnWidth(150.0), // Adjust width as needed
                                                      // 1: FlexColumnWidth(),
                                                    },
                                                    children: [
                                                      // _buildTableRow(
                                                      //     'Property :',
                                                      //     _getDisplayValue(workOrder
                                                      //         .rentalAddress!
                                                      //         .rentalAdress),
                                                      //     'Assign :',
                                                      //     _getDisplayValue(workOrder
                                                      //         .staffMember
                                                      //         ?.staffmemberName)),
                                                      // _buildTableRow(
                                                      //     'Created On :',
                                                      //     workOrder.workOrderData!.createdAt
                                                      //         ?.isNotEmpty ==
                                                      //         true
                                                      //         ? dateProvider.formatCurrentDate(
                                                      //         '${workOrder.workOrderData!.createdAt}')
                                                      //         : 'N/A',
                                                      //     '',
                                                      //     ''
                                                      // ),

                                                      _buildTableRow(
                                                          ' Created On : ',
                                                          workOrder.workOrderData!.createdAt?.isNotEmpty ==
                                                              true
                                                              ? dateProvider.formatCurrentDate('${workOrder.workOrderData!.createdAt}')
                                                              : 'N/A',
                                                          '',
                                                          '')
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 5,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                                  .end,
                                              children: [
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (context) => Workorder_summery(
                                                              workorder_id: workOrder.workOrderData?.workOrderId,
                                                            )));
                                                  },
                                                  child:
                                                  Container(
                                                    height: 40,
                                                    // width: 35,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center,
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .center,
                                                      children: [
                                                        const FaIcon(
                                                          FontAwesomeIcons
                                                              .eye,
                                                          size:
                                                          15,
                                                          color: Colors
                                                              .black,
                                                        ),
                                                        // SizedBox(
                                                        //     width:
                                                        //     2),
                                                        const SizedBox(
                                                          width:
                                                          8,
                                                        ),
                                                        Text(
                                                          "View Summary",
                                                          style: TextStyle(
                                                              fontSize:
                                                              11,
                                                              color:
                                                              blueColor,
                                                              fontWeight:
                                                              FontWeight.bold),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 8,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  //SizedBox(height: 13,),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                    ],
                  ),

                // Always show "Properties Within 5 Miles" section with default state when empty
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 5,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Text(
                        "Properties Within 5 Miles",
                        style: TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 15,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    if (properties.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 0.0, vertical: 0.0),
                          child: Column(
                            children: properties
                                .asMap()
                                .entries
                                .map((entry) {
                              int index = entry.key;
                              Rentals rental = entry.value;
                              return PropertyCard(
                                rental: rental,
                                index: index,
                                nearestPropertyWorkOrders:
                                nearestWorkOrders,
                              );
                            }).toList(),
                          )),
                    if (properties.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 4.0),
                        child: Text(
                          "No properties within 5 miles of your location.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),

                // Dynamically build Column items from properties list
                // const SizedBox(height: 15),
                Dashboard_leaseExpiringStaff(),
              ],
            ),
          ),
        )
            : SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardMobileSimple(
                propertyCount: countList[0],
                tenantCount: countList[1],
                applicantCount: countList[2],
                vendorCount: countList[3],
                unpaidPropertiesCount: countList[4],
                newWorkOrder: newworkorder,
                overdueWorkOrder: overdueworkorder,
                totalWorkOrders: totalWorkOrders,
                currentMonthRentDue: currentMonthRentDue,
                lastMonthRentDue: lastMonthRentDue,
                currentMonthRentPaid: currentMonthRentPaid,
                lastMonthRentPaid: lastMonthRentPaid,
                totalRentPastDue: totalRentPastDue,
                fromStaffModule: true,
                onReturn: _refreshCountsQuietly,
              )
              /*  LayoutBuilder(
                builder:
                    (BuildContext context, BoxConstraints constraints) {
                  // Check if the device width is less than 600 (considered as phone screen)
                  if (constraints.maxWidth < 500) {
                    // Phone layout
                    return Column(
                      children: [
                        Padding(
                          padding:
                          const EdgeInsets.only(left: 10, right: 10),
                          child: PieCharts(dataMap: {
                            "Properties": countList[0].toDouble(),

                            "Work Orders": countList[1].toDouble(),
                          }),
                        ), // Vertical layout for phone
                        SizedBox(
                            height: MediaQuery.of(context).size.height *
                                0.015),
                        Padding(
                          padding:
                          const EdgeInsets.only(left: 0, right: 8),
                          child: Barchart(),
                        ),
                      ],
                    );
                  } else {
                    // Tablet layout
                    return Padding(
                      padding: const EdgeInsets.only(
                        top: 35,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                          ),
                          PieCharts(dataMap: {
                            "Properties": countList[0].toDouble(),

                            "Work Orders": countList[2].toDouble(),
                          }),
                          const SizedBox(
                            width: 10,
                          ),
                          Barchart(),
                        ],
                      ),
                    );
                  }
                },
              ),*/
            ],
          ),
        )
            : NoInternetView(onRetry: retryNow),
      ),
    );
  }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 13),
                ),
                const SizedBox(height: 2.0), // Space between label and value
                Text(
                  leftValue,
                  style: TextStyle(color: grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        // TableCell(
        //   child: Padding(
        //     padding: EdgeInsets.only(left: 25),
        //     child: Padding(
        //       padding: const EdgeInsets.all(8.0),
        //       child: Column(
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           Text(
        //             rightLabel,
        //             style:
        //                 TextStyle(fontWeight: FontWeight.bold, color: blueColor,fontSize: 14),
        //           ),
        //           const SizedBox(height: 2.0), // Space between label and value
        //           Text(
        //             rightValue,
        //             style: TextStyle(color: grey,fontSize: 13),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
        // ),
      ],
    );
  }

  String _getDisplayValue(String? value) {
    // Return 'N/A' if the value is null or empty, otherwise return the value
    return (value == null || value.trim().isEmpty) ? 'N/A' : value;
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
}

class PropertyCard extends StatefulWidget {
  final Rentals rental;
  final int index;
  final List<Data> nearestPropertyWorkOrders;

  const PropertyCard(
      {super.key,
        required this.rental,
        required this.index,
        required this.nearestPropertyWorkOrders});

  @override
  State<PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<PropertyCard> {
  bool _isExpanded = false;
  int? expandedIndexrow;
  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      //  height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(5),
          topRight: Radius.circular(5),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        // leading: Container(
        //   child: Icon(
        //     Icons.expand_less,
        //     color: Colors.transparent,
        //   ),
        // ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              flex: 4,
              child: InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    width < 400
                        ? Text("Work Order ",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Work Order",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {},
                child: Row(
                  children: [
                    Text("Status",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    final matchingWorkOrders = widget.nearestPropertyWorkOrders
        .where((workOrder) =>
    workOrder != null &&
        workOrder.rentalAddress?.rentalId == widget.rental.rentalId &&
        (workOrder.workOrderData?.status ?? "") != "Completed")
        .toList();

    bool hasWorkOrders = matchingWorkOrders.isNotEmpty;
    final rental = widget.rental;

    // Always show the property card (with or without work orders)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      decoration: BoxDecoration(
        color: widget.index % 2 != 0 ? const Color(0xFFF4F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color.fromRGBO(152, 162, 179, .5)),
        // border: Border.all(color: Colors.grey.shade300),
        // boxShadow: [
        //   BoxShadow(
        //     color: Colors.black12,
        //     blurRadius: 4,
        //     offset: Offset(0, 2),
        //   ),
        //],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          if (hasWorkOrders) {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(5.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        rental.rentalAddress ?? 'No Address',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF3A4A57),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (hasWorkOrders)
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey[700],
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          'No open work orders',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Expanded section (only when there are work orders)
              if (_isExpanded && hasWorkOrders) ...[
                if (hasWorkOrders)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // const SizedBox(height: 5),
                      const Divider(),
                      const SizedBox(height: 10),
                      _buildHeaders(),
                      // const SizedBox(height: 10),
                      Container(
                        // decoration: BoxDecoration(
                        //     border: Border.all(
                        //         color:
                        //             Colors.green)),
                        // decoration: BoxDecoration(
                        //     border: Border.all(color: blueColor)),
                        child: Column(
                          children: widget.nearestPropertyWorkOrders
                              .where((workOrder) =>
                          workOrder!.rentalAddress!.rentalId ==
                              widget.rental!.rentalId &&
                              (workOrder.workOrderData?.status ?? "") !=
                                  "Completed")
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                            int index = entry.key;
                            bool isExpanded = expandedIndexrow == index;
                            Data workOrder = entry.value;
                            //return CustomExpansionTile(data: Data, index: index);
                            return Container(
                              decoration: BoxDecoration(
                                color: index % 2 != 0
                                    ? Colors.white
                                    : blueColor.withOpacity(0.09),
                                border:
                                Border.all(color: const Color(0xFFDBE0E5)),
                              ),
                              // decoration: BoxDecoration(
                              //   border: Border.all(color: blueColor),
                              // ),
                              child: Column(
                                children: <Widget>[
                                  ListTile(
                                    onTap: () {
                                      setState(() {
                                        if (expandedIndexrow == index) {
                                          expandedIndexrow = null;
                                        } else {
                                          expandedIndexrow = index;
                                        }
                                      });
                                    },
                                    contentPadding: EdgeInsets.zero,
                                    title: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.start,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: <Widget>[
                                          InkWell(
                                            onTap: () {
                                              // setState(() {
                                              //    isExpanded = !isExpanded;
                                              // //  expandedIndex = !expandedIndex;
                                              //
                                              // });
                                              // setState(() {
                                              //   if (isExpanded) {
                                              //     expandedIndex = null;
                                              //     isExpanded = !isExpanded;
                                              //   } else {
                                              //     expandedIndex = index;
                                              //   }
                                              // });
                                              setState(() {
                                                if (expandedIndexrow == index) {
                                                  expandedIndexrow = null;
                                                } else {
                                                  expandedIndexrow = index;
                                                }
                                              });
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                  left: 5, right: 8),
                                              padding: !isExpanded
                                                  ? const EdgeInsets.only(
                                                  bottom: 10)
                                                  : const EdgeInsets.only(
                                                  top: 10),
                                              child: FaIcon(
                                                isExpanded
                                                    ? FontAwesomeIcons.sortUp
                                                    : FontAwesomeIcons.sortDown,
                                                size: 20,
                                                color: blueColor,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              '${workOrder.workOrderData!.workSubject}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                              width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                                  .02),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              '${workOrder.workOrderData?.status ?? "N/A"}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isExpanded)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      margin: const EdgeInsets.only(bottom: 1),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                FaIcon(
                                                  isExpanded
                                                      ? FontAwesomeIcons.sortUp
                                                      : FontAwesomeIcons
                                                      .sortDown,
                                                  size: 30,
                                                  color: Colors.transparent,
                                                ),
                                                Expanded(
                                                  child: Table(
                                                    columnWidths: {
                                                      0: const FlexColumnWidth(), // Distribute columns equally
                                                      1: const FlexColumnWidth(),
                                                      // 0: FixedColumnWidth(150.0), // Adjust width as needed
                                                      // 1: FlexColumnWidth(),
                                                    },
                                                    children: [
                                                      // _buildTableRow(
                                                      //     'Property :',
                                                      //     _getDisplayValue(
                                                      //         workOrder
                                                      //             .rentalAddress!
                                                      //             .rentalAdress),
                                                      //     'Assign :',
                                                      //     _getDisplayValue(workOrder
                                                      //         .staffMember
                                                      //         ?.staffmemberName)),
                                                      // _buildTableRow(
                                                      //     'Created On:',
                                                      //     workOrder.workOrderData!.createdAt
                                                      //         ?.isNotEmpty ==
                                                      //         true
                                                      //         ? dateProvider.formatCurrentDate(
                                                      //         '${workOrder.workOrderData!.createdAt}')
                                                      //         : 'N/A',
                                                      //     '',
                                                      //     ''),
                                                      _buildTableRow(
                                                          ' Created On : ',
                                                          workOrder
                                                              .workOrderData!
                                                              .createdAt
                                                              ?.isNotEmpty ==
                                                              true
                                                              ? dateProvider
                                                              .formatCurrentDate(
                                                              '${workOrder.workOrderData!.createdAt}')
                                                              : 'N/A',
                                                          '',
                                                          '')
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 5,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            Row(
                                              //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              mainAxisAlignment:
                                              MainAxisAlignment.end,
                                              children: [
                                                // if(permissions!.workorderView!)
                                                GestureDetector(
                                                  onTap: () {
                                                    Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                            builder: (context) =>
                                                                Workorder_summery(
                                                                  workorder_id:
                                                                  workOrder
                                                                      .workOrderData
                                                                      ?.workOrderId,
                                                                )));
                                                  },
                                                  child: Container(
                                                    height: 40,
                                                    // width: 35,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center,
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .center,
                                                      children: [
                                                        const FaIcon(
                                                          FontAwesomeIcons.eye,
                                                          size: 15,
                                                          color: Colors.black,
                                                        ),
                                                        // SizedBox(
                                                        //     width:
                                                        //     2),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          "View Summary",
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: blueColor,
                                                              fontWeight:
                                                              FontWeight
                                                                  .bold),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 8,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  //SizedBox(height: 13,),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                    ],
                  ),
                if (!hasWorkOrders)
                  const Column(
                    children: [
                      SizedBox(height: 5),
                      Divider(),
                      SizedBox(height: 10),
                      Text("No Work Orders",
                          style: TextStyle(color: Colors.blueGrey)),
                      SizedBox(height: 10),
                    ],
                  ),
                // Add more fields if needed
              ]
            ],
          ),
        ),
      ),
    );
  }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 13),
                ),
                const SizedBox(height: 2.0), // Space between label and value
                Text(
                  leftValue,
                  style: TextStyle(color: grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        // TableCell(
        //   child: Padding(
        //     padding: const EdgeInsets.all(4.0),
        //     child: Column(
        //       crossAxisAlignment: CrossAxisAlignment.start,
        //       children: [
        //         Text(
        //           rightLabel,
        //           style:
        //               TextStyle(fontWeight: FontWeight.bold, color: blueColor),
        //         ),
        //         const SizedBox(height: 2.0), // Space between label and value
        //         Text(
        //           rightValue,
        //           style: TextStyle(color: grey),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
      ],
    );
  }

  String _getDisplayValue(String? value) {
    // Return 'N/A' if the value is null or empty, otherwise return the value
    return (value == null || value.trim().isEmpty) ? 'N/A' : value;
  }
}