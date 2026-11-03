import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/Model/tenants.dart';
import 'package:three_zero_two_property/TenantsModule/model/workorder_summery_model.dart';
import 'package:three_zero_two_property/TenantsModule/repository/workorder.dart';
import 'update_workorder.dart';
import 'package:three_zero_two_property/TenantsModule/widgets/drawer_tiles.dart';

import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/repository/lease.dart';

import 'package:three_zero_two_property/screens/Leasing/RentalRoll/newModel.dart';
// import 'package:three_zero_two_property/repository/properties_summery.dart';
import '../../../widgets/VideoPlayerWidget.dart';
import '../../../widgets/titleBar.dart';
import '../../widgets/appbar.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/drawer_tiles.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

/// Due date: top-level date or first workorder_update that has a date (web shows first/any available).
String? _getDueDateForSummery(WorkOrderData_summery summery) {
  if (summery.date != null && summery.date!.isNotEmpty) return summery.date;
  final updates = summery.workorderUpdates;
  if (updates == null || updates.isEmpty) return null;
  for (var u in updates) {
    if (u.date != null && u.date!.isNotEmpty) return u.date;
  }
  return null;
}

class Workorder_summery extends StatefulWidget {
  String? workorder_id;
  Workorder_summery({super.key, this.workorder_id});

  @override
  State<Workorder_summery> createState() => _Workorder_summeryState();
}

class _Workorder_summeryState extends State<Workorder_summery>
    with SingleTickerProviderStateMixin, NetworkRetryState {
  List<String> applicantCheckedChecklist = [
    "CreditCheck",
    "EmploymentVerification",
    "ApplicationFee",
    "IncomeVerification",
    "LandlordVerification"
  ];

  List<String> applicantChecklist = [];
  final Map<String, String> displayNames = {
    "CreditCheck": "Credit and background check",
    "EmploymentVerification": "Employment verification",
    "ApplicationFee": "Application fee collected",
    "IncomeVerification": "Income verification",
    "LandlordVerification": "Landlord verification",
  };

  bool addcheckbox = false;
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();
  TextEditingController checkvalue = TextEditingController();
  List formDataRecurringList = [];
  late Future<WorkOrderData_summery> futureworkorderSummary;
  String? _selectedValue;
  TabController? _tabController;
  List<String> items = ["Approved", "Rejected"];
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    startdateController.dispose();
    enddateController.dispose();
    checkvalue.dispose();
    super.dispose();
  }
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The summary fetch only — the TabController initState also builds must not
  /// be rebuilt, or the user's tab would reset and the old one would leak.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureworkorderSummary =
          WorkOrderRepository.getworkorderSummary(widget.workorder_id!);
    });
  }

  @override
  void initState() {

    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    // TODO: implement initState
    futureworkorderSummary =
        WorkOrderRepository.getworkorderSummary(widget.workorder_id!);

    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

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

  // Note block used inside Update History cards (matches Admin/Staff design).
  Widget _historyNoteBlock({
    required String label,
    required String badgeText,
    required Color badgeBg,
    required Color badgeFg,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Container(height: 1, color: const Color(0xFFDBE0E5)),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7A90),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeFg,
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: blueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  bool isLoading = false;
  int visibleCount = 5;
  int _partsVisibleCount = 5;
  final PageController _partsPageCtrl = PageController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: widget302.,
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {
          key.currentState!.openDrawer();
        },
      ),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: 'Work Orders',
      ),
      body: !isOffline
          ? Column(
        children: [
          const SizedBox(
            height: 15,
          ),
          /* Row(
            children: [
              Spacer(),
             */
          /* GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Material(
                  elevation: 3,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(5),
                  ),
                  child: Container(
                    height: 40,
                    width: 80,
                    decoration: const BoxDecoration(
                      color: blueColor,
                      borderRadius: BorderRadius.all(
                        Radius.circular(5),
                      ),
                    ),
                    child: const Center(
                        child: Text(
                      "Back",
                      style: TextStyle(
                          fontWeight: FontWeight.w500, color: Colors.white),
                    )),
                  ),
                ),
              ),*/
          /*
              const SizedBox(
                width: 20,
              ),
            ],
          ),*/
          const SizedBox(
            height: 20,
          ),
          titleBar(
            width: MediaQuery.of(context).size.width * .91,
            title: 'Work Order Details',
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: FutureBuilder<WorkOrderData_summery>(
                  future: futureworkorderSummary,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: SpinKitFadingCircle(
                          color: Colors.black,
                          size: 55.0,
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                          child: friendlyErrorState(snapshot.error));
                    } else if (!snapshot.hasData ||
                        snapshot.data == null) {
                      return const Center(child: Text('No data found.'));
                    } else {
                      // _selectedValue = snapshot.data!.applicantStatus!.last!.status;
                      return Column(
                        children: <Widget>[
                          const SizedBox(height: 15),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Work Order : #${snapshot.data!.ticketNumber ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: AnimatedBuilder(
                              animation: _tabController!,
                              builder: (context, _) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _tabController!.animateTo(0),
                                        child: Container(
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: _tabController!.index == 0 ? blueColor : Colors.white,
                                            border: Border.all(color: blueColor),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Summary',
                                            style: TextStyle(
                                              color: _tabController!.index == 0 ? Colors.white : blueColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => _tabController!.animateTo(1),
                                        child: Container(
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: _tabController!.index == 1 ? blueColor : Colors.white,
                                            border: Border.all(color: blueColor),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Task',
                                            style: TextStyle(
                                              color: _tabController!.index == 1 ? Colors.white : blueColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                Summery_page(snapshot.data!),
                                Task(snapshot.data!),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                  }),
            ),
          ),
        ],
      )
          : NoInternetView(onRetry: retryNow),
    );
  }

  List<String> titles = [' Account', 'Qty', '  Price', 'Amount'];
  Map<int, TableColumnWidth> columnWidth = {
    0: const FlexColumnWidth(3.3),
    1: const FlexColumnWidth(1),
    2: const FlexColumnWidth(1.9),
    3: const FlexColumnWidth(1.81),
  };
  // int getTotalPrice() {
  //   //return products.fold(0, (sum, item) => sum + item.totalAmount);
  //   return 0;
  // }
  double getTotalPrice(List<PartsandchargeData>? partsList) {
    if (partsList == null || partsList.isEmpty) return 0.0;

    return partsList.fold(
        0.0,
            (sum, item) =>
        sum + ((item.partsQuantity ?? 0) * (item.partsPrice ?? 0)));
  }

  Summery_page(WorkOrderData_summery summery) {
    final dateProvider = Provider.of<DateProvider>(context);
    double grandTotal = 0;
    // applicantChecklist = List<String>.from(summery.applicantCheckedChecklist!);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth > 600) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Billing Information
                      Expanded(
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 50,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2F8),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    'Billing Information',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const SizedBox(width: 1),
                                    Checkbox(
                                      value: summery.isBillable == 'Yes' || summery.isBillable == true,
                                      onChanged: null,
                                      activeColor: blueColor,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Billable to Tenant',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Contacts
                      Expanded(
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 50,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2F8),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person, color: blueColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Vendor', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text(summery.vendorData?.companyName ?? 'N/A', style: TextStyle(color: blueColor, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (summery.tenantData != null) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.person, color: blueColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Tenant', style: TextStyle(color: blueColor, fontWeight: FontWeight.w500, fontSize: 14)),
                                                  Text('${summery.tenantData?.firstname ?? ''} ${summery.tenantData?.lastname ?? ''}', style: TextStyle(color: blueColor, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Material(
                  borderOnForeground: true,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFFDBE0E5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2F8),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                          ),
                          child: Text(
                            'Property',
                            style: TextStyle(
                              color: blueColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (summery.propertyData?.rental_image != null &&
                                summery.propertyData!.rental_image!.isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: "$image_url${summery.propertyData!.rental_image}",
                                        placeholder: (context, url) => Text("${summery.propertyData!.rental_image}"),
                                        errorWidget: (context, url, error) => Icon(Icons.error, color: blueColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                Text(
                                  "${summery.propertyData?.rentaladress ?? 'N/A'} ",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    color: blueColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 300,
                                  child: Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 4.0,
                                    runSpacing: 4.0,
                                    children: [
                                      Text(
                                        "${summery.propertyData?.rental_city ?? ''}, ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData?.rental_state ?? ''}, ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData?.rental_country ?? ''}, ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData?.rental_postcode ?? ''}",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  children: <Widget>[
                    Container(
                      width: MediaQuery.of(context).size.width * .48,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        // color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  border: Border.all(color: blueColor),
                                  // color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(
                                width: 20,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width:
                                    MediaQuery.of(context).size.width > 500
                                        ? 200
                                        : 180,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 1),
                                      child: Text(
                                        '${summery.workSubject ?? "N/A"}',
                                        maxLines:
                                        5, // Set maximum number of lines
                                        overflow: TextOverflow
                                            .ellipsis, // Handle overflow with ellipsis
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                .size
                                                .width <
                                                500
                                                ? 13
                                                : 18,
                                            color: blueColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 10,
                                  ),
                                  SizedBox(
                                    width:
                                    MediaQuery.of(context).size.width > 500
                                        ? 200
                                        : 180,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 1),
                                      child: Text(
                                        '${summery.propertyData?.rentaladress ?? "N/A"}',
                                        maxLines:
                                        5, // Set maximum number of lines
                                        overflow: TextOverflow
                                            .ellipsis, // Handle overflow with ellipsis
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                .size
                                                .width <
                                                500
                                                ? 13
                                                : 18,
                                            color: blueColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  // Container(
                                  //     child: Text(
                                  //   '${summery.workSubject ?? "N/A"}',
                                  //   style: TextStyle(
                                  //       fontWeight: FontWeight.bold,
                                  //       color: blueColor),
                                  // )),
                                  // SizedBox(
                                  //   height: 10,
                                  // ),
                                  // Container(
                                  //     child: Text(
                                  //   '${summery.propertyData?.rentaladress ?? "N/A"}',
                                  //   style: TextStyle(color: blueColor),
                                  // )),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                        'Description',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                        '${summery.workPerformed ?? "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Status",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text('${summery.status ?? "N/A"}',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                        'Permission To Enter',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                        '${summery.entryAllowed == true ? "Yes" : summery.entryAllowed == false ? "No" : "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Due Date",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                            () {
                                          final d = _getDueDateForSummery(summery);
                                          return d != null ? dateProvider.formatCurrentDate(d) : 'N/A';
                                        }(),
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                        'Vendors Note',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                        '${summery.vendorNotes ?? "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Assignees",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    summery.staffData != null
                                        ? Text(
                                        '${summery.staffData?.firstname ?? "N/A"}',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold))
                                        : Text('N/A',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .45,
                      child: Column(
                        children: [
                          if (summery.tenantData != null)
                            SizedBox(
                              height: 220,
                              child: Material(
                                elevation: 7,
                                borderOnForeground: true,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 220,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 2, // 40%
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            // color: Colors.blue,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            /*   boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // changes position of shadow
                                ),
                              ],*/
                                          ),
                                          child: Material(
                                            elevation: 4,
                                            color: Colors.white,
                                            borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Contacts',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 16,
                                                    fontWeight:
                                                    FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 7, // 60%
                                        child: Column(
                                          children: [
                                            Container(
                                                decoration: const BoxDecoration(
                                                  //  color: Colors.green,
                                                  borderRadius:
                                                  BorderRadius.vertical(
                                                    bottom: Radius.circular(10),
                                                  ),
                                                ),
                                                child: ListTile(
                                                  title: Text(
                                                    "Vendor",
                                                    style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                        FontWeight.w500),
                                                  ),
                                                  subtitle: summery
                                                      .vendorData !=
                                                      null
                                                      ? Text(
                                                    summery.vendorData!
                                                        .companyName ??
                                                        "N/A",
                                                    style: TextStyle(
                                                        color: blueColor),
                                                  )
                                                      : Text(
                                                    "N/A",
                                                    style: TextStyle(
                                                        color: blueColor),
                                                  ),
                                                  leading: Container(
                                                    padding:
                                                    const EdgeInsets.only(
                                                        top: 3),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 30,
                                                    ),
                                                  ),
                                                )),
                                            const Divider(
                                              thickness: 3,
                                            ),
                                            Container(
                                                decoration: const BoxDecoration(
                                                  //  color: Colors.green,
                                                  borderRadius:
                                                  BorderRadius.vertical(
                                                    bottom: Radius.circular(10),
                                                  ),
                                                ),
                                                child: ListTile(
                                                  title: Text(
                                                    "Tenant",
                                                    style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                        FontWeight.w500),
                                                  ),
                                                  subtitle: summery
                                                      .tenantData !=
                                                      null
                                                      ? Text(
                                                    "${summery.tenantData!.firstname ?? "N/A"} ${summery.tenantData!.lastname ?? "N/A"}",
                                                    style: TextStyle(
                                                        color: blueColor),
                                                  )
                                                      : Text(
                                                    "N/A",
                                                    style: TextStyle(
                                                        color: blueColor),
                                                  ),
                                                  leading: Container(
                                                    padding:
                                                    const EdgeInsets.only(
                                                        top: 3),
                                                    child: const Icon(
                                                      Icons.person,
                                                      size: 30,
                                                    ),
                                                  ),
                                                )),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (summery.tenantData == null)
                            SizedBox(
                              height: 100,
                              child: Material(
                                elevation: 7,
                                borderOnForeground: true,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 3, // 40%
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            // color: Colors.blue,
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            /*   boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // changes position of shadow
                                ),
                              ],*/
                                          ),
                                          child: Material(
                                            elevation: 4,
                                            color: Colors.white,
                                            borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Contacts',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontSize: 16,
                                                    fontWeight:
                                                    FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 7, // 60%
                                        child: Container(
                                            decoration: const BoxDecoration(
                                              //  color: Colors.green,
                                              borderRadius:
                                              BorderRadius.vertical(
                                                bottom: Radius.circular(10),
                                              ),
                                            ),
                                            child: ListTile(
                                              title: Text(
                                                "Vendor",
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                    FontWeight.w500),
                                              ),
                                              subtitle:
                                              summery.vendorData != null
                                                  ? Text(
                                                summery.vendorData!
                                                    .companyName ??
                                                    "N/A",
                                                style: TextStyle(
                                                    color: blueColor),
                                              )
                                                  : Text(
                                                "N/A",
                                                style: TextStyle(
                                                    color: blueColor),
                                              ),
                                              leading: Container(
                                                padding: const EdgeInsets.only(
                                                    top: 3),
                                                child: const Icon(
                                                  Icons.person,
                                                  size: 30,
                                                ),
                                              ),
                                            )),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(
                            height: 10,
                          ),
                          Material(
                            elevation: 7,
                            borderOnForeground: true,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                    ),
                                    child: Material(
                                      elevation: 4,
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(10),
                                      ),
                                      child: Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Property',
                                            style: TextStyle(
                                              color: blueColor,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      if (summery.propertyData!.rental_image !=
                                          null)
                                        Column(
                                          children: [
                                            const SizedBox(
                                              height: 10,
                                            ),
                                            CachedNetworkImage(
                                              imageUrl:
                                              "$image_url${summery.propertyData!.rental_image}",
                                              placeholder: (context, url) => Text(
                                                  "${summery.propertyData!.rental_image}"),
                                              errorWidget:
                                                  (context, url, error) =>
                                              const Icon(Icons.error),
                                              /*  imageBuilder: (context, imageProvider) => Container(
                                      width: 40.0,
                                      height: 40.0,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),*/
                                            ),
                                          ],
                                        ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Text(
                                        "${summery.propertyData!.rentaladress} (${summery.unitData!.unitName})",
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        children: [
                                          Text(
                                              "${summery.propertyData!.rental_city}, "),
                                          Text(
                                              "${summery.propertyData!.rental_state}, "),
                                          Text(
                                              "${summery.propertyData!.rental_country}, "),
                                          Text(
                                              "${summery.propertyData!.rental_postcode} "),
                                        ],
                                      ),
                                      const SizedBox(
                                        height: 10,
                                      ),
                                    ],
                                  )
                                  /*  ListTile(
                            title: Text(
                              "Vendor",
                              style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              "Vendor Company Name",
                              style: TextStyle(color: blueColor),
                            ),
                            leading: Container(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.person,
                                size: 30,
                              ),
                            )

                          ),*/
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                if (summery.partsandchargeData!.length > 0)
                  IntrinsicHeight(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFDBE0E5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                            ),
                            child: Text(
                              'Parts and Labor',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                          /*Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Column(
                                      children: summery.partsandchargeData!.map((part) {
                                        int partTotal =
                                        (part.partsPrice! * part.partsQuantity!);
                                        print(partTotal);
                                        grandTotal += partTotal;
                                        print(grandTotal);
                                        return PartWidget(part: part, total: 0.0);
                                      }).toList(),
                                    ),
                                    */ /*  Column(
                                  children: summery.partsandchargeData!.map((part) {
                                    int partTotal = (part.partsPrice! * part.partsQuantity!);
                                    print(partTotal);
                                    grandTotal += partTotal;
                                    print(grandTotal);
                                    return PartWidget(part: part, total:0.0);
                                  }).toList(),
                                ),*/ /*
                                    // Divider(color: Colors.grey),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          formatMoney(grandTotal),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),*/
                          Table(
                            border: TableBorder.all(width: 1),
                            columnWidths: const {
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(2),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2),
                              4: FlexColumnWidth(2),
                            },
                            children: [
                              TableRow(children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('QTY',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Account',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Description',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Price',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text('Amount',
                                      style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ]),
                              ...summery.partsandchargeData!
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                int index = entry.key;
                                PartsandchargeData row = entry.value;
                                grandTotal +=
                                (row.partsQuantity! * row.partsPrice!);
                                return TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("${row.partsQuantity}"),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("${row.account}"),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text("${row.description}"),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(formatMoney(row.partsPrice ?? 0)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        formatMoney(row.partsPrice! * row.partsQuantity!)),
                                  ),
                                ]);
                              }).toList(),
                              TableRow(children: [
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('Total',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text('',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(formatMoney(grandTotal),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),

                                /* Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                                formatMoney(totalAmount)),
                          ),*/
                              ]),
                              /*TableRow(children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              height: 34,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(width: 1),
                                  borderRadius:
                                  BorderRadius.circular(10.0)),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(
                                            10.0)),
                                    elevation: 0,
                                    backgroundColor: Colors.white),
                                onPressed: addRow,
                                child: const Text(
                                  'Add Row',
                                  style: TextStyle(
                                    color:
                                    blueColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                        ]),*/
                            ],
                          ),
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEEF2F8),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Update History', style: TextStyle(fontSize: 16, color: blueColor, fontWeight: FontWeight.bold)),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UpdateWorkOrderTenant(
                                      workorderId: widget.workorder_id!,
                                      summery: summery,
                                    ),
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    setState(() {
                                      futureworkorderSummary =
                                          WorkOrderRepository
                                              .getworkorderSummary(
                                                  widget.workorder_id!);
                                    });
                                  }
                                });
                              },
                              child: Container(
                                height: 30,
                                width: 85,
                                decoration: BoxDecoration(color: blueColor, borderRadius: BorderRadius.circular(8)),
                                child: const Center(child: Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      ...summery.workorderUpdates!.reversed.take(visibleCount).map((update) {
                        const updLabel = TextStyle(
                          color: Color(0xFF6B7A90),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        );
                        final updValue = TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        );
                        Widget field(String label, String value, {Color? valueColor}) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: updLabel),
                              const SizedBox(height: 4),
                              Text(
                                value,
                                style: updValue.copyWith(color: valueColor ?? blueColor),
                              ),
                            ],
                          );
                        }
                        final dateStr = update.date?.isNotEmpty == true
                            ? dateProvider.formatCurrentDate('${update.date}')
                            : 'N/A';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2F8),
                            border: Border.all(color: const Color(0xFFDBE0E5)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: field('Assignees', update.staffmemberName ?? 'N/A')),
                                  const SizedBox(width: 12),
                                  Expanded(child: field('Due Date', dateStr)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: const Color(0xFFDBE0E5)),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: field('Status', update.status ?? 'N/A', valueColor: const Color(0xFF1F9D55))),
                                  const SizedBox(width: 12),
                                  Expanded(child: field('Updated By', update.statusUpdatedBy ?? 'N/A')),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(height: 1, color: const Color(0xFFDBE0E5)),
                              const SizedBox(height: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Message', style: updLabel), const SizedBox(height: 4), Text('${update.statusUpdatedBy ?? ""} updated this work order ($dateStr)', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14))]),
                              if ((update.publicNotes ?? '').trim().isNotEmpty)
                                _historyNoteBlock(
                                  label: 'Notes',
                                  badgeText: 'VISIBLE TO ALL',
                                  badgeBg: const Color(0xFFE7F6EC),
                                  badgeFg: const Color(0xFF1F9D55),
                                  value: update.publicNotes!,
                                ),
                              if (update.workOrderUpdateimages != null &&
                                  update.workOrderUpdateimages!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: update.workOrderUpdateimages!
                                      .map<Widget>((imageUrl) {
                                    return GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(20),
                                                    child: CachedNetworkImage(
                                                      imageUrl:
                                                          "$image_url$imageUrl",
                                                      placeholder: (context,
                                                              url) =>
                                                          const CircularProgressIndicator(),
                                                      errorWidget: (context, url,
                                                              error) =>
                                                          const Icon(
                                                              Icons.error),
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 10,
                                                  right: 10,
                                                  child: IconButton(
                                                    icon: const Icon(Icons.close,
                                                        size: 30,
                                                        color: Colors.white),
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width:
                                            (MediaQuery.of(context).size.width /
                                                    3) -
                                                20,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: CachedNetworkImage(
                                            imageUrl: "$image_url$imageUrl",
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                SpinKitFadingCircle(
                                                    color: blueColor,
                                                    size: 30.0),
                                            errorWidget: (context, url, error) =>
                                                const Icon(Icons.error),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      if (summery.workorderUpdates!.length > 5)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() { visibleCount = visibleCount == 5 ? summery.workorderUpdates!.length : 5; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFDBE0E5)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      visibleCount == 5 ? '+${summery.workorderUpdates!.length - 5} more' : 'View Less',
                                      style: TextStyle(color: blueColor, fontWeight: FontWeight.w600, fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      visibleCount == 5 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                      size: 16,
                                      color: blueColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        );
      } else {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Billing Information
                      Expanded(
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 50,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2F8),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    'Billing Information',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const SizedBox(width: 1),
                                    Checkbox(
                                      value: summery.isBillable == 'Yes' || summery.isBillable == true,
                                      onChanged: null,
                                      activeColor: blueColor,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Billable to Tenant',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Contacts
                      Expanded(
                        child: Material(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 50,
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEEF2F8),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                                  ),
                                  child: Text(
                                    'Contacts',
                                    style: TextStyle(
                                      color: blueColor,
                                      fontSize: MediaQuery.of(context).size.width < 400 ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.person, color: blueColor),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Vendor', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                Text(summery.vendorData?.companyName ?? 'N/A', style: TextStyle(color: blueColor, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (summery.tenantData != null) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.person, color: blueColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text('Tenant', style: TextStyle(color: blueColor, fontWeight: FontWeight.w500, fontSize: 14)),
                                                  Text('${summery.tenantData?.firstname ?? ''} ${summery.tenantData?.lastname ?? ''}', style: TextStyle(color: blueColor, fontSize: 13)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Material(
                  borderOnForeground: true,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFFDBE0E5)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEF2F8),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                          ),
                          child: Text(
                            'Property',
                            style: TextStyle(
                              color: blueColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (summery.propertyData?.rental_image != null &&
                                summery.propertyData!.rental_image!.isNotEmpty)
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: "$image_url${summery.propertyData!.rental_image}",
                                        placeholder: (context, url) => Text("${summery.propertyData!.rental_image}"),
                                        errorWidget: (context, url, error) => Icon(Icons.error, color: blueColor),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                Text(
                                  "${summery.propertyData?.rentaladress ?? 'N/A'} ",
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    color: blueColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 300,
                                  child: Wrap(
                                    alignment: WrapAlignment.start,
                                    spacing: 4.0,
                                    runSpacing: 4.0,
                                    children: [
                                      Text(
                                        "${summery.propertyData?.rental_city ?? ''}, ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData?.rental_state ?? ''}, ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData?.rental_country ?? ''}, ",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        "${summery.propertyData?.rental_postcode ?? ''}",
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Builder(builder: (context) {
                    const labelPill = TextStyle(
                      color: Color(0xFF6B7A90),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    );
                    final valuePill = TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    );
                    Widget pill({required String label, required String value, Color? valueColor, bool tinted = true}) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: tinted ? const Color(0xFFEEF2F8) : Colors.white,
                          border: tinted ? null : Border.all(color: const Color(0xFFDBE0E5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: labelPill),
                            const SizedBox(height: 6),
                            Text(value, style: valuePill.copyWith(color: valueColor ?? blueColor)),
                          ],
                        ),
                      );
                    }
                    final dueDate = () {
                      final d = _getDueDateForSummery(summery);
                      return d != null ? dateProvider.formatCurrentDate(d) : 'N/A';
                    }();
                    final unitSuffix = (summery.unitData?.rental_unit != null &&
                            summery.unitData!.rental_unit.toString().trim().isNotEmpty)
                        ? ' (${summery.unitData?.rental_unit})'
                        : '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summery.workSubject ?? "N/A"}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, color: blueColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: const Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(text: '${summery.propertyData?.rentaladress ?? "N/A"}'),
                              if (unitSuffix.isNotEmpty)
                                TextSpan(
                                  text: unitSuffix,
                                  style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pill(label: 'Assignees', value: summery.staffData?.firstname ?? 'N/A')),
                            const SizedBox(width: 10),
                            Expanded(child: pill(label: 'Due Date', value: dueDate)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: pill(
                              label: 'Permission To Enter',
                              value: summery.entryAllowed == true ? 'Yes' : summery.entryAllowed == false ? 'No' : 'N/A',
                              valueColor: summery.entryAllowed == true ? const Color(0xFF1F9D55) : null,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: pill(
                              label: 'Status',
                              value: (summery.status != null && summery.status!.isNotEmpty) ? summery.status! : 'N/A',
                              valueColor: const Color(0xFF1F9D55),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Description',
                          value: (summery.workPerformed != null && summery.workPerformed!.isNotEmpty) ? summery.workPerformed! : 'N/A',
                          tinted: false,
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Vendor Notes',
                          value: (summery.vendorNotes != null && summery.vendorNotes!.isNotEmpty) ? summery.vendorNotes! : 'N/A',
                          tinted: false,
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(
                  height: 10,
                ),
                if (summery.partsandchargeData!.length > 0)
                  IntrinsicHeight(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFDBE0E5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Parts and Labor',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE1E9F4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${summery.partsandchargeData?.length ?? 0}',
                                    style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Builder(
                              builder: (context) {
                                final parts = summery.partsandchargeData ?? [];
                                final showCount = _partsVisibleCount > parts.length ? parts.length : _partsVisibleCount;
                                final visibleItems = parts.take(showCount).toList();
                                final hiddenCount = parts.length - showCount;
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: visibleItems.map((item) {
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: Color(0xFFDBE0E5)),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 28,
                                                height: 28,
                                                decoration: const BoxDecoration(color: Color(0xFFE8F0FA), shape: BoxShape.circle),
                                                child: Icon(Icons.settings, size: 16, color: blueColor),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(item.account ?? '', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        const Text('Qty ', style: TextStyle(color: Color(0xFF6B7A90), fontSize: 12)),
                                                        Text('${item.partsQuantity ?? 0}', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                        const SizedBox(width: 14),
                                                        const Text('Price ', style: TextStyle(color: Color(0xFF6B7A90), fontSize: 12)),
                                                        Text(formatMoney(item.partsPrice ?? 0), style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                formatMoney(item.amount ?? ((item.partsPrice ?? 0) * (item.partsQuantity ?? 0))),
                                                style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    if (parts.length > 5)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 8, top: 2),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () => setState(() {
                                              _partsVisibleCount = _partsVisibleCount >= parts.length ? 5 : parts.length;
                                            }),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                border: Border.all(color: const Color(0xFFDBE0E5)),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    hiddenCount > 0 ? '+$hiddenCount more' : 'View Less',
                                                    style: TextStyle(color: blueColor, fontWeight: FontWeight.w600, fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    hiddenCount > 0 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                                    size: 16,
                                                    color: blueColor,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                      decoration: BoxDecoration(color: blueColor, borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text(
                                            formatMoney(getTotalPrice(summery.partsandchargeData)),
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          // Padding(
                          //   padding: const EdgeInsets.all(8.0),
                          //   child: Column(
                          //     children: [
                          //       Column(
                          //         children:
                          //             summery.partsandchargeData!.map((part) {
                          //           int partTotal = (part.partsPrice! *
                          //               part.partsQuantity!);
                          //           print(partTotal);
                          //           grandTotal += partTotal;
                          //           print(grandTotal);
                          //           return PartWidget(part: part, total: 0.0);
                          //         }).toList(),
                          //       ),
                          //       /*  Column(
                          //         children: summery.partsandchargeData!.map((part) {
                          //           int partTotal = (part.partsPrice! * part.partsQuantity!);
                          //           print(partTotal);
                          //           grandTotal += partTotal;
                          //           print(grandTotal);
                          //           return PartWidget(part: part, total:0.0);
                          //         }).toList(),
                          //       ),*/
                          //       // Divider(color: Colors.grey),
                          //       Row(
                          //         mainAxisAlignment:
                          //             MainAxisAlignment.spaceBetween,
                          //         children: [
                          //           Text(
                          //             'Total',
                          //             style: TextStyle(
                          //                 fontWeight: FontWeight.bold,
                          //                 fontSize: 16),
                          //           ),
                          //           Text(
                          //             formatMoney(grandTotal),
                          //             style: TextStyle(
                          //               fontWeight: FontWeight.bold,
                          //               fontSize: 16,
                          //               color: Colors.black87,
                          //             ),
                          //           ),
                          //         ],
                          //       ),
                          //     ],
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFDBE0E5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Update History',
                              style: TextStyle(
                                fontSize: 16,
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UpdateWorkOrderTenant(
                                      workorderId: widget.workorder_id!,
                                      summery: summery,
                                    ),
                                  ),
                                ).then((_) {
                                  if (mounted) {
                                    setState(() {
                                      futureworkorderSummary =
                                          WorkOrderRepository
                                              .getworkorderSummary(
                                                  widget.workorder_id!);
                                    });
                                  }
                                });
                              },
                              child: Material(
                                elevation: 1,
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                child: Container(
                                  height: 30,
                                  width: 85,
                                  decoration: BoxDecoration(
                                    color: blueColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                      child: Text(
                                        "Update",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      )),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...summery.workorderUpdates!.reversed
                            .take(visibleCount)
                            .map((update) {
                          const updLabel = TextStyle(color: Color(0xFF6B7A90), fontWeight: FontWeight.w600, fontSize: 13);
                          final updValue = TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14);
                          Widget field(String label, String value, {Color? valueColor}) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: updLabel),
                                const SizedBox(height: 4),
                                Text(value, style: updValue.copyWith(color: valueColor ?? blueColor)),
                              ],
                            );
                          }
                          final dateStr = update.date != null && update.date!.isNotEmpty
                              ? dateProvider.formatCurrentDate(update.date!)
                              : 'N/A';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2F8),
                              border: Border.all(color: const Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: field('Assignees', update.staffmemberName ?? 'N/A')),
                                    const SizedBox(width: 12),
                                    Expanded(child: field('Due Date', dateStr)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(height: 1, color: const Color(0xFFDBE0E5)),
                                const SizedBox(height: 10),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: field('Status', update.status ?? 'N/A', valueColor: const Color(0xFF1F9D55))),
                                    const SizedBox(width: 12),
                                    Expanded(child: field('Updated By', update.statusUpdatedBy ?? 'N/A')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(height: 1, color: const Color(0xFFDBE0E5)),
                                const SizedBox(height: 10),
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Message', style: updLabel), const SizedBox(height: 4), Text('${update.statusUpdatedBy ?? ""} updated this work order ($dateStr)', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14))]),
                                if ((update.publicNotes ?? '').trim().isNotEmpty)
                                  _historyNoteBlock(
                                    label: 'Notes',
                                    badgeText: 'VISIBLE TO ALL',
                                    badgeBg: const Color(0xFFE7F6EC),
                                    badgeFg: const Color(0xFF1F9D55),
                                    value: update.publicNotes!,
                                  ),
                                if (update.workOrderUpdateimages != null &&
                                    update.workOrderUpdateimages!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: update.workOrderUpdateimages!
                                        .map<Widget>((imageUrl) {
                                      return GestureDetector(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              backgroundColor:
                                                  Colors.transparent,
                                              child: Stack(
                                                children: [
                                                  Center(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              20),
                                                      child: CachedNetworkImage(
                                                        imageUrl:
                                                            "$image_url$imageUrl",
                                                        placeholder: (context,
                                                                url) =>
                                                            const CircularProgressIndicator(),
                                                        errorWidget: (context,
                                                                url, error) =>
                                                            const Icon(
                                                                Icons.error),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 10,
                                                    right: 10,
                                                    child: IconButton(
                                                      icon: const Icon(
                                                          Icons.close,
                                                          size: 30,
                                                          color: Colors.white),
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: (MediaQuery.of(context)
                                                      .size
                                                      .width /
                                                  3) -
                                              20,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: CachedNetworkImage(
                                              imageUrl: "$image_url$imageUrl",
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  SpinKitFadingCircle(
                                                      color: blueColor,
                                                      size: 30.0),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        if (summery.workorderUpdates!.length > 5)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(() { visibleCount = visibleCount == 5 ? summery.workorderUpdates!.length : 5; }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: const Color(0xFFDBE0E5)),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        visibleCount == 5 ? '+${summery.workorderUpdates!.length - 5} more' : 'View Less',
                                        style: TextStyle(color: blueColor, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        visibleCount == 5 ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                        size: 16,
                                        color: blueColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )),
                const SizedBox(
                  height: 10,
                ),
                const SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),
        );
      }
    });
  }

  Task(WorkOrderData_summery summery) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);

    double grandTotal = 0;
    // applicantChecklist = List<String>.from(summery.applicantCheckedChecklist!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      width: MediaQuery.of(context).size.width * .5,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        // color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  border: Border.all(color: blueColor),
                                  // color: Colors.blue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      width: 150,
                                      child: Text(
                                        '${summery.workSubject ?? "N/A"}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                      child: Text(
                                        '${summery.propertyData?.rentaladress ?? "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              if (summery.priority == "High")
                                Container(
                                  height: 35,
                                  width: 62,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                    Border.all(color: Colors.red, width: 2),
                                  ),
                                  child: const Center(
                                      child: Text("High",
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w400))),
                                ),
                              if (summery.priority == "Medium")
                                Container(
                                  height: 35,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                    Border.all(color: blueColor, width: 3),
                                  ),
                                  child: Center(
                                      child: Text("Medium",
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.w400))),
                                ),
                              if (summery.priority == "Normal")
                                Container(
                                  height: 35,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey, width: 3),
                                  ),
                                  child: const Center(
                                      child: Text("Normal",
                                          style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w400))),
                                )
                            ],
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                        'Description',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                        '${(summery.workPerformed != null && summery.workPerformed!.isNotEmpty) ? summery.workPerformed : "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Status",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text('${summery.status ?? "N/A"}',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                        'Permission To Enter',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      child: Text(
                                        '${summery.entryAllowed == true ? "Yes" : summery.entryAllowed == false ? "No" : "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Due Date",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                            () {
                                          final d = _getDueDateForSummery(summery);
                                          return d != null ? dateProvider.formatCurrentDate(d) : 'N/A';
                                        }(),
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              const SizedBox(
                                width: 10,
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                      child: Text(
                                        'Vendors Note',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      )),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  Container(
                                      width: 150,
                                      child: Text(
                                        '${(summery.vendorNotes != null && summery.vendorNotes!.isNotEmpty) ? summery.vendorNotes : "N/A"}',
                                        style: TextStyle(color: blueColor),
                                      )),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                height: 70,
                                width: MediaQuery.of(context).size.width * .2,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Column(
                                  // crossAxisAlignment: CrossAxisAlignment.center,
                                  // mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "Assignees",
                                      style: TextStyle(
                                        color: blueColor,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    summery.staffData != null
                                        ? Text(
                                        '${summery.staffData?.firstname ?? "N/A"}',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold))
                                        : Text('N/A',
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Material(
                      elevation: 7,
                      borderOnForeground: true,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.43,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                              ),
                              child: Material(
                                elevation: 4,
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(10),
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      'Images ',
                                      style: TextStyle(
                                        color: blueColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (summery.workorderUpdates != null)
                                  Column(
                                    children: [
                                      const SizedBox(
                                        height: 10,
                                      ),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: summery.workOrderImages!
                                            .map((imageUrl) {
                                          return Container(
                                            width:
                                            summery.workOrderImages!
                                                .length ==
                                                1
                                                ? MediaQuery.of(context)
                                                .size
                                                .width /
                                                3
                                                : (MediaQuery.of(context)
                                                .size
                                                .width /
                                                3) -
                                                10,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius.circular(10),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                              BorderRadius.circular(10),
                                              child: GestureDetector(
                                                  // Opens the photo full screen, matching the video beside
                                                  // it and the Admin/Staff copies of this screen.
                                                  onTap: () => _openImagePreview('$image_url$imageUrl'),
                                                  child: CachedNetworkImage(
                                                    imageUrl: "$image_url$imageUrl",
                                                    placeholder: (context, url) =>
                                                    const Center(
                                                        child:
                                                        CircularProgressIndicator()),
                                                    errorWidget:
                                                        (context, url, error) {
                                                      return Container();
                                                    },
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                if (summery.workOrderImages!.length == 0)
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("No Images Provided"),
                                      // Text("(${summery.unitData!.unitName})"),
                                    ],
                                  ),
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  "${summery.propertyData!.rentaladress} (${summery.unitData!.unitName})",
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                SizedBox(
                                  width: 300,
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing:
                                    4.0, // Space between texts horizontally
                                    runSpacing:
                                    4.0, // Space between lines when wrapping
                                    children: [
                                      Text(
                                          "${summery.propertyData!.rental_city}, "),
                                      Text(
                                          "${summery.propertyData!.rental_state}, "),
                                      Text(
                                          "${summery.propertyData!.rental_country}, "),
                                      Text(
                                          "${summery.propertyData!.rental_postcode}"),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                              ],
                            )
                            /*  ListTile(
                              title: Text(
                                "Vendor",
                                style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                "Vendor Company Name",
                                style: TextStyle(color: blueColor),
                              ),
                              leading: Container(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(
                                  Icons.person,
                                  size: 30,
                                ),
                              )

                            ),*/
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: Builder(builder: (context) {
                    const labelPill = TextStyle(
                      color: Color(0xFF6B7A90),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    );
                    final valuePill = TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    );
                    Widget pill({required String label, required String value, Color? valueColor, bool tinted = true}) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: tinted ? const Color(0xFFEEF2F8) : Colors.white,
                          border: tinted ? null : Border.all(color: const Color(0xFFDBE0E5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: labelPill),
                            const SizedBox(height: 6),
                            Text(value, style: valuePill.copyWith(color: valueColor ?? blueColor)),
                          ],
                        ),
                      );
                    }
                    final dueDate = () {
                      final d = _getDueDateForSummery(summery);
                      return d != null ? dateProvider.formatCurrentDate(d) : 'N/A';
                    }();
                    final unitSuffix = (summery.unitData?.rental_unit != null &&
                            summery.unitData!.rental_unit.toString().trim().isNotEmpty)
                        ? ' (${summery.unitData?.rental_unit})'
                        : '';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${summery.workSubject ?? "N/A"}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, color: blueColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A90), fontWeight: FontWeight.w500),
                            children: [
                              TextSpan(text: '${summery.propertyData?.rentaladress ?? "N/A"}'),
                              if (unitSuffix.isNotEmpty)
                                TextSpan(
                                  text: unitSuffix,
                                  style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: pill(label: 'Assignees', value: summery.staffData?.firstname ?? 'N/A')),
                            const SizedBox(width: 10),
                            Expanded(child: pill(label: 'Due Date', value: dueDate)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: pill(
                              label: 'Permission To Enter',
                              value: summery.entryAllowed == true ? 'Yes' : summery.entryAllowed == false ? 'No' : 'N/A',
                              valueColor: summery.entryAllowed == true ? const Color(0xFF1F9D55) : null,
                            )),
                            const SizedBox(width: 10),
                            Expanded(child: pill(
                              label: 'Status',
                              value: (summery.status != null && summery.status!.isNotEmpty) ? summery.status! : 'N/A',
                              valueColor: const Color(0xFF1F9D55),
                            )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Description',
                          value: (summery.workPerformed != null && summery.workPerformed!.isNotEmpty) ? summery.workPerformed! : 'N/A',
                          tinted: false,
                        ),
                        const SizedBox(height: 10),
                        pill(
                          label: 'Vendor Notes',
                          value: (summery.vendorNotes != null && summery.vendorNotes!.isNotEmpty) ? summery.vendorNotes! : 'N/A',
                          tinted: false,
                        ),
                      ],
                    );
                  }),
                ),
                const SizedBox(
                  height: 10,
                ),
                IntrinsicHeight(
                  child: Material(
                    borderOnForeground: true,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                              border: Border(bottom: BorderSide(color: Color(0xFFDBE0E5), width: 1)),
                            ),
                            child: Text(
                              'Images',
                              style: TextStyle(
                                color: blueColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (summery.workOrderImages != null && summery.workOrderImages!.isNotEmpty)
                                Column(
                                  children: [
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: summery.workOrderImages!.map((imageUrl) {
                                        bool isMp4 = isVideo(imageUrl);
                                        return Container(
                                          width: summery.workOrderImages!.length == 1
                                              ? MediaQuery.of(context).size.width / 3
                                              : (MediaQuery.of(context).size.width / 3) - 10,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: isMp4
                                                ? Container(
                                                    height: 80,
                                                    width: 80,
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        _showVideoDialog('$image_url${imageUrl}');
                                                      },
                                                      child: Stack(
                                                        alignment: Alignment.center,
                                                        children: [
                                                          VideoItem(url: '$image_url${imageUrl}'),
                                                          const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                : GestureDetector(
                                                    // Opens the photo full screen, matching the video beside
                                                    // it and the Admin/Staff copies of this screen.
                                                    onTap: () => _openImagePreview('$image_url$imageUrl'),
                                                    child: CachedNetworkImage(
                                                        imageUrl: "$image_url$imageUrl",
                                                        placeholder: (context, url) => const Center(
                                                            child: SpinKitFadingCircle(color: Colors.black, size: 40.0)),
                                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                                        fit: BoxFit.cover,
                                                      ),
                                                  ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                ),
                              if (summery.workOrderImages == null || summery.workOrderImages!.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      "No Images Provided",
                                      style: TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                IntrinsicHeight(
                  child: Material(
                    borderOnForeground: true,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Color(0xFFDBE0E5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEEF2F8),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            child: Text(
                              'Property',
                              style: TextStyle(
                                color: blueColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${summery.propertyData?.rentaladress ?? "N/A"}${(summery.unitData?.rental_unit != null && summery.unitData!.rental_unit.toString().trim().isNotEmpty) ? ' (${summery.unitData?.rental_unit})' : ''}",
                                  style: TextStyle(fontSize: 15, color: blueColor, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${summery.propertyData?.rental_city ?? ""}, ${summery.propertyData?.rental_state ?? ""}, ${summery.propertyData?.rental_country ?? ""}, ${summery.propertyData?.rental_postcode ?? ""}",
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        }
      }),
    );
  }

  bool isVideo(String url) {
    return url.toLowerCase().endsWith(".mp4");
  }

  void _showVideoDialog(String videoFile) {
    showDialog(
      context: context,
      builder: (context) {
        return Container(
          child: VideoPlayerDialog(
            videoUrl: videoFile,
          ),
        );
      },
    );
  }

  // Task(WorkOrderData_summery summery) {
  //   print(summery.workOrderImages);
  //   double grandTotal = 0;
  //   // applicantChecklist = List<String>.from(summery.applicantCheckedChecklist!);
  //   return Padding(
  //     padding: EdgeInsets.symmetric(horizontal: 10),
  //     child: LayoutBuilder(builder: (context, constraints) {
  //       if (constraints.maxWidth > 500) {
  //         return SingleChildScrollView(
  //           child: Column(
  //             children: [
  //               SizedBox(
  //                 height: 10,
  //               ),
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.start,
  //                 children: [
  //                   SizedBox(
  //                     height: 10,
  //                   ),
  //                   Container(
  //                     width: MediaQuery.of(context).size.width * .5,
  //                     padding: const EdgeInsets.all(10),
  //                     decoration: BoxDecoration(
  //                       border: Border.all(color: blueColor),
  //                       // color: Colors.blue,
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                     child: Column(
  //                       children: [
  //                         Row(
  //                           children: [
  //                             Container(
  //                               height: 40,
  //                               width: 40,
  //                               decoration: BoxDecoration(
  //                                 color: blueColor,
  //                                 border: Border.all(color: blueColor),
  //                                 // color: Colors.blue,
  //                                 borderRadius: BorderRadius.circular(10),
  //                               ),
  //                               child: Icon(
  //                                 Icons.menu,
  //                                 color: Colors.white,
  //                               ),
  //                             ),
  //                             SizedBox(
  //                               width: 20,
  //                             ),
  //                             Column(
  //                               mainAxisAlignment: MainAxisAlignment.start,
  //                               crossAxisAlignment: CrossAxisAlignment.start,
  //                               children: [
  //                                 Container(
  //                                     width: 150,
  //                                     child: Text(
  //                                       '${summery.workSubject ?? "N/A"}',
  //                                       style: TextStyle(
  //                                           fontWeight: FontWeight.bold,
  //                                           color: blueColor),
  //                                     )),
  //                                 SizedBox(
  //                                   height: 10,
  //                                 ),
  //                                 Container(
  //                                     child: Text(
  //                                   '${summery.propertyData?.rentaladress ?? "N/A"}',
  //                                   style: TextStyle(color: blueColor),
  //                                 )),
  //                               ],
  //                             ),
  //                             Spacer(),
  //                             if (summery.priority == "High")
  //                               Container(
  //                                 height: 35,
  //                                 width: 70,
  //                                 decoration: BoxDecoration(
  //                                   borderRadius: BorderRadius.circular(10),
  //                                   border:
  //                                       Border.all(color: Colors.red, width: 3),
  //                                 ),
  //                                 child: Center(
  //                                     child: Text("High",
  //                                         style: TextStyle(
  //                                             color: Colors.red,
  //                                             fontWeight: FontWeight.w400))),
  //                               ),
  //                             if (summery.priority == "Medium")
  //                               Container(
  //                                 height: 35,
  //                                 width: 70,
  //                                 decoration: BoxDecoration(
  //                                   borderRadius: BorderRadius.circular(10),
  //                                   border:
  //                                       Border.all(color: blueColor, width: 3),
  //                                 ),
  //                                 child: Center(
  //                                     child: Text("Medium",
  //                                         style: TextStyle(
  //                                             color: blueColor,
  //                                             fontWeight: FontWeight.w400))),
  //                               ),
  //                             if (summery.priority == "Normal")
  //                               Container(
  //                                 height: 35,
  //                                 width: 70,
  //                                 decoration: BoxDecoration(
  //                                   borderRadius: BorderRadius.circular(10),
  //                                   border: Border.all(
  //                                       color: Colors.grey, width: 3),
  //                                 ),
  //                                 child: Center(
  //                                     child: Text("Normal",
  //                                         style: TextStyle(
  //                                             color: Colors.grey,
  //                                             fontWeight: FontWeight.w400))),
  //                               )
  //                           ],
  //                         ),
  //                         SizedBox(
  //                           height: 20,
  //                         ),
  //                         Row(
  //                           children: [
  //                             SizedBox(
  //                               width: 10,
  //                             ),
  //                             Column(
  //                               mainAxisAlignment: MainAxisAlignment.start,
  //                               crossAxisAlignment: CrossAxisAlignment.start,
  //                               children: [
  //                                 Container(
  //                                     child: Text(
  //                                   'Description',
  //                                   style: TextStyle(
  //                                       fontWeight: FontWeight.bold,
  //                                       color: blueColor),
  //                                 )),
  //                                 SizedBox(
  //                                   height: 8,
  //                                 ),
  //                                 Container(
  //                                     child: Text(
  //                                   '${summery.workPerformed ?? "N/A"}',
  //                                   style: TextStyle(color: blueColor),
  //                                 )),
  //                               ],
  //                             ),
  //                             Spacer(),
  //                             Container(
  //                               height: 70,
  //                               width: MediaQuery.of(context).size.width * .2,
  //                               decoration: BoxDecoration(
  //                                 borderRadius: BorderRadius.circular(8),
  //                                 border: Border.all(color: Colors.grey),
  //                               ),
  //                               child: Column(
  //                                 // crossAxisAlignment: CrossAxisAlignment.center,
  //                                 // mainAxisAlignment: MainAxisAlignment.start,
  //                                 children: [
  //                                   SizedBox(
  //                                     height: 10,
  //                                   ),
  //                                   Text(
  //                                     "Status",
  //                                     style: TextStyle(
  //                                       color: blueColor,
  //                                     ),
  //                                   ),
  //                                   SizedBox(
  //                                     height: 4,
  //                                   ),
  //                                   Text('${summery.status ?? "N/A"}',
  //                                       style: TextStyle(
  //                                           color: blueColor,
  //                                           fontWeight: FontWeight.bold)),
  //                                 ],
  //                               ),
  //                             ),
  //                             SizedBox(
  //                               width: 10,
  //                             ),
  //                           ],
  //                         ),
  //                         SizedBox(
  //                           height: 10,
  //                         ),
  //                         Row(
  //                           children: [
  //                             SizedBox(
  //                               width: 10,
  //                             ),
  //                             Column(
  //                               mainAxisAlignment: MainAxisAlignment.start,
  //                               crossAxisAlignment: CrossAxisAlignment.start,
  //                               children: [
  //                                 Container(
  //                                     child: Text(
  //                                   'Permission To Enter',
  //                                   style: TextStyle(
  //                                       fontWeight: FontWeight.bold,
  //                                       color: blueColor),
  //                                 )),
  //                                 SizedBox(
  //                                   height: 8,
  //                                 ),
  //                                 Container(
  //                                     child: Text(
  //                                   '${summery.entryAllowed == true ? "Yes" : summery.entryAllowed == false ? "No" : "N/A"}',
  //                                   style: TextStyle(color: blueColor),
  //                                 )),
  //                               ],
  //                             ),
  //                             Spacer(),
  //                             Container(
  //                               height: 70,
  //                               width: MediaQuery.of(context).size.width * .2,
  //                               decoration: BoxDecoration(
  //                                 borderRadius: BorderRadius.circular(8),
  //                                 border: Border.all(color: Colors.grey),
  //                               ),
  //                               child: Column(
  //                                 // crossAxisAlignment: CrossAxisAlignment.center,
  //                                 // mainAxisAlignment: MainAxisAlignment.start,
  //                                 children: [
  //                                   SizedBox(
  //                                     height: 10,
  //                                   ),
  //                                   Text(
  //                                     "Due Date",
  //                                     style: TextStyle(
  //                                       color: blueColor,
  //                                     ),
  //                                   ),
  //                                   SizedBox(
  //                                     height: 4,
  //                                   ),
  //                                   Text(
  //                                       '${summery.workorderUpdates?.last.date ?? "N/A"}',
  //                                       style: TextStyle(
  //                                           color: blueColor,
  //                                           fontWeight: FontWeight.bold)),
  //                                   SizedBox(
  //                                     height: 10,
  //                                   ),
  //                                 ],
  //                               ),
  //                             ),
  //                             SizedBox(
  //                               width: 10,
  //                             ),
  //                           ],
  //                         ),
  //                         SizedBox(
  //                           height: 10,
  //                         ),
  //                         Row(
  //                           children: [
  //                             SizedBox(
  //                               width: 10,
  //                             ),
  //                             Column(
  //                               mainAxisAlignment: MainAxisAlignment.start,
  //                               crossAxisAlignment: CrossAxisAlignment.start,
  //                               children: [
  //                                 Container(
  //                                     child: Text(
  //                                   'Vendors Note',
  //                                   style: TextStyle(
  //                                       fontWeight: FontWeight.bold,
  //                                       color: blueColor),
  //                                 )),
  //                                 SizedBox(
  //                                   height: 8,
  //                                 ),
  //                                 Container(
  //                                     child: Text(
  //                                   '${summery.vendorNotes ?? "N/A"}',
  //                                   style: TextStyle(color: blueColor),
  //                                 )),
  //                               ],
  //                             ),
  //                             Spacer(),
  //                             Container(
  //                               height: 70,
  //                               width: MediaQuery.of(context).size.width * .2,
  //                               decoration: BoxDecoration(
  //                                 borderRadius: BorderRadius.circular(8),
  //                                 border: Border.all(color: Colors.grey),
  //                               ),
  //                               child: Column(
  //                                 // crossAxisAlignment: CrossAxisAlignment.center,
  //                                 // mainAxisAlignment: MainAxisAlignment.start,
  //                                 children: [
  //                                   SizedBox(
  //                                     height: 10,
  //                                   ),
  //                                   Text(
  //                                     "Assignees",
  //                                     style: TextStyle(
  //                                       color: blueColor,
  //                                     ),
  //                                   ),
  //                                   SizedBox(
  //                                     height: 4,
  //                                   ),
  //                                   summery.staffData != null
  //                                       ? Text(
  //                                           '${summery.staffData?.firstname ?? "N/A"}',
  //                                           style: TextStyle(
  //                                               color: blueColor,
  //                                               fontWeight: FontWeight.bold))
  //                                       : Text('N/A',
  //                                           style: TextStyle(
  //                                               color: blueColor,
  //                                               fontWeight: FontWeight.bold)),
  //                                 ],
  //                               ),
  //                             ),
  //                             SizedBox(
  //                               width: 10,
  //                             ),
  //                           ],
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   SizedBox(
  //                     width: 10,
  //                   ),
  //                   Material(
  //                     elevation: 7,
  //                     borderOnForeground: true,
  //                     borderRadius: BorderRadius.circular(10),
  //                     child: Container(
  //                       width: MediaQuery.of(context).size.width * 0.43,
  //                       decoration: BoxDecoration(
  //                         color: Colors.white,
  //                         border: Border.all(),
  //                         borderRadius: BorderRadius.circular(10),
  //                       ),
  //                       child: Column(
  //                         children: [
  //                           Container(
  //                             decoration: BoxDecoration(
  //                               borderRadius: BorderRadius.vertical(
  //                                 top: Radius.circular(10),
  //                               ),
  //                             ),
  //                             child: Material(
  //                               elevation: 4,
  //                               color: Colors.white,
  //                               borderRadius: BorderRadius.vertical(
  //                                 top: Radius.circular(10),
  //                               ),
  //                               child: Center(
  //                                 child: Padding(
  //                                   padding: const EdgeInsets.all(8.0),
  //                                   child: Text(
  //                                     'Images',
  //                                     style: TextStyle(
  //                                       color: blueColor,
  //                                       fontSize: 16,
  //                                       fontWeight: FontWeight.bold,
  //                                     ),
  //                                   ),
  //                                 ),
  //                               ),
  //                             ),
  //                           ),
  //                           Column(
  //                             mainAxisAlignment: MainAxisAlignment.center,
  //                             crossAxisAlignment: CrossAxisAlignment.center,
  //                             children: [
  //                               if (summery.workorderUpdates != null)
  //                                 Column(
  //                                   children: [
  //                                     SizedBox(
  //                                       height: 10,
  //                                     ),
  //                                     Wrap(
  //                                       spacing: 10,
  //                                       runSpacing: 10,
  //                                       children: summery.workOrderImages!
  //                                           .map((imageUrl) {
  //                                         return Container(
  //                                           width:
  //                                               summery.workOrderImages!
  //                                                           .length ==
  //                                                       1
  //                                                   ? MediaQuery.of(context)
  //                                                           .size
  //                                                           .width /
  //                                                       3
  //                                                   : (MediaQuery.of(context)
  //                                                               .size
  //                                                               .width /
  //                                                           3) -
  //                                                       10,
  //                                           decoration: BoxDecoration(
  //                                             borderRadius:
  //                                                 BorderRadius.circular(10),
  //                                           ),
  //                                           child: ClipRRect(
  //                                             borderRadius:
  //                                                 BorderRadius.circular(10),
  //                                             child: CachedNetworkImage(
  //                                               imageUrl: "$image_url$imageUrl",
  //                                               placeholder: (context, url) =>
  //                                                   Center(
  //                                                       child:
  //                                                           CircularProgressIndicator()),
  //                                               errorWidget:
  //                                                   (context, url, error) {
  //                                                 print(error);
  //                                                 return Container();
  //                                               },
  //                                               fit: BoxFit.cover,
  //                                             ),
  //                                           ),
  //                                         );
  //                                       }).toList(),
  //                                     ),
  //                                   ],
  //                                 ),
  //                               if (summery.workOrderImages!.length == 0)
  //                                 Row(
  //                                   mainAxisAlignment: MainAxisAlignment.center,
  //                                   children: [
  //                                     Text("No Images Provided"),
  //                                     // Text("(${summery.unitData!.unitName})"),
  //                                   ],
  //                                 ),
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                               Text(
  //                                 "${summery.propertyData!.rentaladress} (${summery.unitData!.unitName})",
  //                                 textAlign: TextAlign.center,
  //                               ),
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                               Row(
  //                                 mainAxisAlignment: MainAxisAlignment.center,
  //                                 children: [
  //                                   Text(
  //                                       "${summery.propertyData!.rental_city}, "),
  //                                   Text(
  //                                       "${summery.propertyData!.rental_state}, "),
  //                                   Text(
  //                                       "${summery.propertyData!.rental_country}, "),
  //                                   Text(
  //                                       "${summery.propertyData!.rental_postcode} "),
  //                                 ],
  //                               ),
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                             ],
  //                           )
  //                           /*  ListTile(
  //                             title: Text(
  //                               "Vendor",
  //                               style: TextStyle(
  //                                 color: blueColor,
  //                                 fontWeight: FontWeight.w500,
  //                               ),
  //                             ),
  //                             subtitle: Text(
  //                               "Vendor Company Name",
  //                               style: TextStyle(color: blueColor),
  //                             ),
  //                             leading: Container(
  //                               padding: EdgeInsets.only(top: 3),
  //                               child: Icon(
  //                                 Icons.person,
  //                                 size: 30,
  //                               ),
  //                             )
  //
  //                           ),*/
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                   SizedBox(
  //                     height: 20,
  //                   ),
  //                 ],
  //               ),
  //             ],
  //           ),
  //         );
  //       } else {
  //         return SingleChildScrollView(
  //           child: Column(
  //             children: [
  //               SizedBox(
  //                 height: 10,
  //               ),
  //               Container(
  //                 padding: const EdgeInsets.all(10),
  //                 decoration: BoxDecoration(
  //                   border: Border.all(color: blueColor),
  //                   // color: Colors.blue,
  //                   borderRadius: BorderRadius.circular(10),
  //                 ),
  //                 child: Column(
  //                   children: [
  //                     Row(
  //                       children: [
  //                         Container(
  //                           height: 40,
  //                           width: 40,
  //                           decoration: BoxDecoration(
  //                             color: blueColor,
  //                             border: Border.all(color: blueColor),
  //                             // color: Colors.blue,
  //                             borderRadius: BorderRadius.circular(10),
  //                           ),
  //                           child: Icon(
  //                             Icons.menu,
  //                             color: Colors.white,
  //                           ),
  //                         ),
  //                         SizedBox(
  //                           width: 20,
  //                         ),
  //                         Column(
  //                           mainAxisAlignment: MainAxisAlignment.start,
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Container(
  //                                 width: 180,
  //                                 child: Text(
  //                                   '${summery.workSubject ?? "N/A"}',
  //                                   style: TextStyle(
  //                                       fontWeight: FontWeight.bold,
  //                                       color: blueColor),
  //                                 )),
  //                             SizedBox(
  //                               height: 10,
  //                             ),
  //                             Container(
  //                                 child: Text(
  //                               '${summery.propertyData?.rentaladress ?? "N/A"}',
  //                               style: TextStyle(color: blueColor),
  //                             )),
  //                           ],
  //                         ),
  //                         Spacer(),
  //                         if (summery.priority == "High")
  //                           Container(
  //                             height: 35,
  //                             width: 70,
  //                             decoration: BoxDecoration(
  //                               borderRadius: BorderRadius.circular(10),
  //                               border: Border.all(color: Colors.red, width: 3),
  //                             ),
  //                             child: Center(
  //                                 child: Text("High",
  //                                     style: TextStyle(
  //                                         color: Colors.red,
  //                                         fontWeight: FontWeight.w400))),
  //                           ),
  //                         if (summery.priority == "Medium")
  //                           Container(
  //                             height: 35,
  //                             width: 70,
  //                             decoration: BoxDecoration(
  //                               borderRadius: BorderRadius.circular(10),
  //                               border: Border.all(color: blueColor, width: 3),
  //                             ),
  //                             child: Center(
  //                                 child: Text("Medium",
  //                                     style: TextStyle(
  //                                         color: blueColor,
  //                                         fontWeight: FontWeight.w400))),
  //                           ),
  //                         if (summery.priority == "Normal")
  //                           Container(
  //                             height: 35,
  //                             width: 70,
  //                             decoration: BoxDecoration(
  //                               borderRadius: BorderRadius.circular(10),
  //                               border:
  //                                   Border.all(color: Colors.grey, width: 3),
  //                             ),
  //                             child: Center(
  //                                 child: Text("Normal",
  //                                     style: TextStyle(
  //                                         color: Colors.grey,
  //                                         fontWeight: FontWeight.w400))),
  //                           )
  //                       ],
  //                     ),
  //                     SizedBox(
  //                       height: 20,
  //                     ),
  //                     Row(
  //                       children: [
  //                         SizedBox(
  //                           width: 10,
  //                         ),
  //                         Column(
  //                           mainAxisAlignment: MainAxisAlignment.start,
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Container(
  //                                 child: Text(
  //                               'Description',
  //                               style: TextStyle(
  //                                   fontWeight: FontWeight.bold,
  //                                   color: blueColor),
  //                             )),
  //                             SizedBox(
  //                               height: 8,
  //                             ),
  //                             Container(
  //                                 width: 180,
  //                                 child: Text(
  //                                   '${summery.workPerformed ?? "N/A"}',
  //                                   style: TextStyle(color: blueColor),
  //                                 )),
  //                           ],
  //                         ),
  //                         Spacer(),
  //                         Container(
  //                           height: 70,
  //                           width: MediaQuery.of(context).size.width * .3,
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.circular(8),
  //                             border: Border.all(color: Colors.grey),
  //                           ),
  //                           child: Column(
  //                             // crossAxisAlignment: CrossAxisAlignment.center,
  //                             // mainAxisAlignment: MainAxisAlignment.start,
  //                             children: [
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                               Text(
  //                                 "Status",
  //                                 style: TextStyle(
  //                                   color: blueColor,
  //                                 ),
  //                               ),
  //                               SizedBox(
  //                                 height: 4,
  //                               ),
  //                               Text('${summery.status ?? "N/A"}',
  //                                   style: TextStyle(
  //                                       color: blueColor,
  //                                       fontWeight: FontWeight.bold)),
  //                             ],
  //                           ),
  //                         ),
  //                         SizedBox(
  //                           width: 10,
  //                         ),
  //                       ],
  //                     ),
  //                     SizedBox(
  //                       height: 10,
  //                     ),
  //                     Row(
  //                       children: [
  //                         SizedBox(
  //                           width: 10,
  //                         ),
  //                         Column(
  //                           mainAxisAlignment: MainAxisAlignment.start,
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Container(
  //                                 child: Text(
  //                               'Permission To Enter',
  //                               style: TextStyle(
  //                                   fontWeight: FontWeight.bold,
  //                                   color: blueColor),
  //                             )),
  //                             SizedBox(
  //                               height: 8,
  //                             ),
  //                             Container(
  //                                 child: Text(
  //                               '${summery.entryAllowed == true ? "Yes" : summery.entryAllowed == false ? "No" : "N/A"}',
  //                               style: TextStyle(color: blueColor),
  //                             )),
  //                           ],
  //                         ),
  //                         Spacer(),
  //                         Container(
  //                           height: 70,
  //                           width: MediaQuery.of(context).size.width * .3,
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.circular(8),
  //                             border: Border.all(color: Colors.grey),
  //                           ),
  //                           child: Column(
  //                             // crossAxisAlignment: CrossAxisAlignment.center,
  //                             // mainAxisAlignment: MainAxisAlignment.start,
  //                             children: [
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                               Text(
  //                                 "Due Date",
  //                                 style: TextStyle(
  //                                   color: blueColor,
  //                                 ),
  //                               ),
  //                               SizedBox(
  //                                 height: 4,
  //                               ),
  //                               Text(
  //                                   '${summery.workorderUpdates?.last.date ?? "N/A"}',
  //                                   style: TextStyle(
  //                                       color: blueColor,
  //                                       fontWeight: FontWeight.bold)),
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                             ],
  //                           ),
  //                         ),
  //                         SizedBox(
  //                           width: 10,
  //                         ),
  //                       ],
  //                     ),
  //                     SizedBox(
  //                       height: 10,
  //                     ),
  //                     Row(
  //                       children: [
  //                         SizedBox(
  //                           width: 10,
  //                         ),
  //                         Column(
  //                           mainAxisAlignment: MainAxisAlignment.start,
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             Container(
  //                                 child: Text(
  //                               'Vendors Note',
  //                               style: TextStyle(
  //                                   fontWeight: FontWeight.bold,
  //                                   color: blueColor),
  //                             )),
  //                             SizedBox(
  //                               height: 8,
  //                             ),
  //                             SizedBox(
  //                               width: MediaQuery.of(context).size.width > 500
  //                                   ? 200
  //                                   : 150,
  //                               child: Text(
  //                                 '${summery.vendorNotes ?? "N/A"}',
  //                                 maxLines: 4, // Set maximum number of lines
  //                                 overflow: TextOverflow.ellipsis,
  //                                 textAlign: TextAlign
  //                                     .justify, // Handle overflow with ellipsis
  //                                 style: TextStyle(
  //                                   fontSize:
  //                                       MediaQuery.of(context).size.width < 500
  //                                           ? 13
  //                                           : 18,
  //                                   color: blueColor,
  //                                 ),
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         Spacer(),
  //                         Container(
  //                           height: 70,
  //                           width: MediaQuery.of(context).size.width * .3,
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.circular(8),
  //                             border: Border.all(color: Colors.grey),
  //                           ),
  //                           child: Column(
  //                             // crossAxisAlignment: CrossAxisAlignment.center,
  //                             // mainAxisAlignment: MainAxisAlignment.start,
  //                             children: [
  //                               SizedBox(
  //                                 height: 10,
  //                               ),
  //                               Text(
  //                                 "Assignees",
  //                                 style: TextStyle(
  //                                   color: blueColor,
  //                                 ),
  //                               ),
  //                               SizedBox(
  //                                 height: 4,
  //                               ),
  //                               summery.staffData != null
  //                                   ? Text('${summery.staffData?.firstname ?? "N/A"}',
  //                                       style: TextStyle(
  //                                           color: blueColor,
  //                                           fontWeight: FontWeight.bold))
  //                                   : Text('N/A',
  //                                       style: TextStyle(
  //                                           color: blueColor,
  //                                           fontWeight: FontWeight.bold)),
  //                             ],
  //                           ),
  //                         ),
  //                         SizedBox(
  //                           width: 10,
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               SizedBox(
  //                 height: 10,
  //               ),
  //               IntrinsicHeight(
  //                 child: Material(
  //                   elevation: 7,
  //                   borderOnForeground: true,
  //                   borderRadius: BorderRadius.circular(10),
  //                   child: Container(
  //                     decoration: BoxDecoration(
  //                       color: Colors.white,
  //                       border: Border.all(),
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                     child: Column(
  //                       children: [
  //                         Container(
  //                           decoration: BoxDecoration(
  //                             borderRadius: BorderRadius.vertical(
  //                               top: Radius.circular(10),
  //                             ),
  //                           ),
  //                           child: Material(
  //                             elevation: 4,
  //                             color: Colors.white,
  //                             borderRadius: BorderRadius.vertical(
  //                               top: Radius.circular(10),
  //                             ),
  //                             child: Center(
  //                               child: Padding(
  //                                 padding: const EdgeInsets.all(8.0),
  //                                 child: Text(
  //                                   'Images',
  //                                   style: TextStyle(
  //                                     color: blueColor,
  //                                     fontSize: 16,
  //                                     fontWeight: FontWeight.bold,
  //                                   ),
  //                                 ),
  //                               ),
  //                             ),
  //                           ),
  //                         ),
  //                         Column(
  //                           mainAxisAlignment: MainAxisAlignment.center,
  //                           crossAxisAlignment: CrossAxisAlignment.center,
  //                           children: [
  //                             if (summery.workorderUpdates != null)
  //                               Column(
  //                                 children: [
  //                                   SizedBox(
  //                                     height: 10,
  //                                   ),
  //                                   Wrap(
  //                                     spacing: 10,
  //                                     runSpacing: 10,
  //                                     children: summery.workOrderImages!
  //                                         .map((imageUrl) {
  //                                       return Container(
  //                                         width:
  //                                             summery.workOrderImages!
  //                                                         .length ==
  //                                                     1
  //                                                 ? MediaQuery.of(context)
  //                                                         .size
  //                                                         .width /
  //                                                     3
  //                                                 : (MediaQuery.of(context)
  //                                                             .size
  //                                                             .width /
  //                                                         3) -
  //                                                     10,
  //                                         decoration: BoxDecoration(
  //                                           borderRadius:
  //                                               BorderRadius.circular(10),
  //                                         ),
  //                                         child: ClipRRect(
  //                                           borderRadius:
  //                                               BorderRadius.circular(10),
  //                                           child: CachedNetworkImage(
  //                                             imageUrl: "$image_url$imageUrl",
  //                                             placeholder: (context, url) => Center(
  //                                                 child:
  //                                                     CircularProgressIndicator()),
  //                                             errorWidget:
  //                                                 (context, url, error) {
  //                                               print(error);
  //                                               return Container();
  //                                             },
  //                                             fit: BoxFit.cover,
  //                                           ),
  //                                         ),
  //                                       );
  //                                     }).toList(),
  //                                   ),
  //                                 ],
  //                               ),
  //                             if (summery.workOrderImages!.length == 0)
  //                               Row(
  //                                 mainAxisAlignment: MainAxisAlignment.center,
  //                                 children: [
  //                                   Text("No Images Provided"),
  //                                   // Text("(${summery.unitData!.unitName})"),
  //                                 ],
  //                               ),
  //                             SizedBox(
  //                               height: 10,
  //                             ),
  //                             Text(
  //                               "${summery.propertyData!.rentaladress}",
  //                               textAlign: TextAlign.center,
  //                             ),
  //                             SizedBox(
  //                               height: 10,
  //                             ),
  //                             Row(
  //                               mainAxisAlignment: MainAxisAlignment.center,
  //                               children: [
  //                                 Text(
  //                                     "${summery.propertyData!.rental_city}, "),
  //                                 Text(
  //                                     "${summery.propertyData!.rental_state}, "),
  //                                 Text(
  //                                     "${summery.propertyData!.rental_country}, "),
  //                                 Text(
  //                                     "${summery.propertyData!.rental_postcode} "),
  //                               ],
  //                             ),
  //                             SizedBox(
  //                               height: 10,
  //                             ),
  //                           ],
  //                         )
  //                         /*  ListTile(
  //                           title: Text(
  //                             "Vendor",
  //                             style: TextStyle(
  //                               color: blueColor,
  //                               fontWeight: FontWeight.w500,
  //                             ),
  //                           ),
  //                           subtitle: Text(
  //                             "Vendor Company Name",
  //                             style: TextStyle(color: blueColor),
  //                           ),
  //                           leading: Container(
  //                             padding: EdgeInsets.only(top: 3),
  //                             child: Icon(
  //                               Icons.person,
  //                               size: 30,
  //                             ),
  //                           )
  //
  //                         ),*/
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               SizedBox(
  //                 height: 20,
  //               ),
  //             ],
  //           ),
  //         );
  //       }
  //     }),
  //   );
  // }

  //
  // updatecheckBox() async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   String? id = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //   var checkvalue = {"applicant_checkedChecklist": applicantChecklist};
  //   final response = await apiPut(
  //     Uri.parse('$Api_url/api/applicant/applicant/${widget.applicant_id}'),
  //     headers: <String, String>{
  //       "id": "CRM $id",
  //       "authorization": "CRM $token",
  //       'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: jsonEncode(checkvalue),
  //   );
  //   if (response.statusCode == 200) {
  //     // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');
  //
  //     setState(() {});
  //   } else {
  //     // Log the response body for debugging
  //     print('Failed to update data: ${response.body}');
  //     throw Exception('Failed to update applicant data');
  //   }
  // }
  //
  // updatecheckBoxnew(List applicant) async {
  //   SharedPreferences prefs = await SharedPreferences.getInstance();
  //
  //   String? id = prefs.getString("adminId");
  //   String? token = prefs.getString('token');
  //   var checkvalue = {"applicant_checklist": applicant};
  //   final response = await apiPut(
  //     Uri.parse(
  //         '$Api_url/api/applicant/applicant/${widget.applicant_id}/checklist'),
  //     headers: <String, String>{
  //       "id": "CRM $id",
  //       "authorization": "CRM $token",
  //       'Content-Type': 'application/json; charset=UTF-8',
  //     },
  //     body: jsonEncode(checkvalue),
  //   );
  //   if (response.statusCode == 200) {
  //     // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');
  //
  //     setState(() {});
  //   } else {
  //     // Log the response body for debugging
  //     print('Failed to update data: ${response.body}');
  //     throw Exception('Failed to update applicant data');
  //   }
  // }
  final labelStyle = const TextStyle(
    color: Colors.grey,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );

  final TextStyle valueStyle = TextStyle(
    color: blueColor,
    fontWeight: FontWeight.bold,
    fontSize: 13,
  );

  /// Full-screen, pinch-to-zoom preview for a work order image.
  ///
  /// Thumbnails in the Images section were display-only, so a photo could not
  /// be seen at the size it was uploaded — while a video beside it already
  /// opened on tap. Mirrors the preview on the Admin and Staff copies of this
  /// screen.
  void _openImagePreview(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5.0,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (context, u) => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, u, error) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              color: Colors.white54, size: 48),
                          SizedBox(height: 8),
                          Text('Could not load image',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -14,
              right: -14,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PartWidget extends StatelessWidget {
  final PartsandchargeData part;
  final double total;

  PartWidget({required this.part, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            part.account!,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatMoney(part.partsPrice ?? 0)} x ${part.partsQuantity}',
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              Text(
                formatMoney(part.partsPrice! * part.partsQuantity!),
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "${part.description}",
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const Divider(color: Colors.grey),
          /* Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                formatMoney(part.partsPrice! * part.partsQuantity!),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),*/
        ],
      ),
    );
  }
}
