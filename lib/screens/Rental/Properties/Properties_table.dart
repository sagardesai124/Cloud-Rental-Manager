import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/add_new_property.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/summery_page.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../Model/propertytype.dart';
import '../../../constant/constant.dart';
import '../../../model/properties.dart';
import '../../../model/properties_summery.dart';
import '../../../model/rental_properties.dart';
import '../../../provider/add_property.dart';
import '../../../provider/dateProvider.dart';
import '../../../repository/properties.dart';
import '../../../repository/rental_properties.dart';
import '../../../repository/Rental_ownersData.dart';
import '../../../Model/RentalOwnersData.dart' as RentalOwnerModel;
import '../../../widgets/drawer_tiles.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import 'EditProperties.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class _Dessert {
  _Dessert(
    this.name,
    this.property,
    this.subtype,
    this.rentalowenername,
  );

  final String name;
  final String property;
  final String subtype;
  final String rentalowenername;
  bool selected = false;
}

class PropertiesTable extends StatefulWidget {
  @override
  _PropertiesTableState createState() => _PropertiesTableState();
}

class _PropertiesTableState extends State<PropertiesTable>
    with NetworkRetryState {
  late Future<RentalsPageResult> futurePropertiesLoad;
  // late Future<List<propertytype>> futurePropertyTypes;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;
  List<Rentals> _tableData = [];
  int totalrecords = 0;
  int? expandedIndex;
  String?
      expandedRentalId; // Track expanded property by rentalId instead of index
  Set<int> expandedIndices = {};

  List<int> itemsPerPageOptions = [
    10,
    25,
    50,
    100,
  ]; // Options for items per page
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;
  final List<String> applicantStatusOptions = [
    'All',
    'Accepting Applications',
    'Not Accepting Applications',
  ];
  final List<String> applicantoccupiedOptions = [
    'All',
    'Occupied',
    'Vacant',
  ];
  String? selectedApplicantStatus;
  String? selectedApplicantOcuupied;
  String? selectedRentalOwner;
  late Future<List<RentalOwnerModel.RentalOwnerData>> futureRentalOwnersList;

  void sortData(List<Rentals> data) {
    if (sorting1) {
      data.sort((a, b) => ascending1
          ? (a.rentalAddress ?? '')
              .toLowerCase()
              .compareTo((b.rentalAddress ?? '').toLowerCase())
          : (b.rentalAddress ?? '')
              .toLowerCase()
              .compareTo((a.rentalAddress ?? '').toLowerCase()));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? (a.propertyTypeData!.propertyType ?? '')
              .toLowerCase()
              .compareTo((b.propertyTypeData!.propertyType ?? '').toLowerCase())
          : (b.propertyTypeData!.propertyType ?? '')
              .toLowerCase()
              .compareTo((a.propertyTypeData!.propertyType ?? '').toLowerCase()));
    } else if (sorting3) {
      for (int i = 0; i < (data.length > 5 ? 5 : data.length); i++) {
      }
      data.sort((a, b) {
        // Primary sort: by is_available
        if (a.is_available! != b.is_available!) {
          if (ascending3) {
            // Ascending: true comes before false
            return a.is_available! ? -1 : 1;
          } else {
            // Descending: false comes before true
            return a.is_available! ? 1 : -1;
          }
        }
        // Secondary sort: by property name (for stable sorting)
        return (a.rentalAddress ?? '')
            .toLowerCase()
            .compareTo((b.rentalAddress ?? '').toLowerCase());
      });
      for (int i = 0; i < (data.length > 5 ? 5 : data.length); i++) {
      }
    } else {
      // Default sorting by createdAt in descending order (newest first) to match web
      data.sort((a, b) {
        if (a.createdAt == null || b.createdAt == null) return 0;
        return DateTime.parse(b.createdAt!)
            .compareTo(DateTime.parse(a.createdAt!));
      });
    }
  }

  bool _useServerPagination() {
    if (selectedValue != null && selectedValue != 'All') return false;
    if (selectedApplicantStatus != null &&
        selectedApplicantStatus != 'All') return false;
    if (selectedApplicantOcuupied != null &&
        selectedApplicantOcuupied != 'All') return false;
    if (selectedRentalOwner != null && selectedRentalOwner != 'All') {
      return false;
    }
    return true;
  }

  MapEntry<String, String> _apiSortParams() {
    if (sorting1) {
      return MapEntry('rental_adress', ascending1 ? 'asc' : 'desc');
    }
    if (sorting2) {
      return MapEntry('property_type', ascending2 ? 'asc' : 'desc');
    }
    if (sorting3) {
      return MapEntry('is_available', ascending3 ? 'asc' : 'desc');
    }
    return const MapEntry('createdAt', 'desc');
  }

  List<Rentals> _applyLocalFilters(List<Rentals> data) {
    var list = List<Rentals>.from(data);
    if (selectedValue != null && selectedValue != "All") {
      list = list
          .where((properties) =>
              properties.propertyTypeData?.propertyType == selectedValue)
          .toList();
    }
    if (searchvalue.isNotEmpty) {
      list = list
          .where((properties) =>
              (properties.rentalAddress ?? '').toLowerCase().contains(searchvalue.toLowerCase()) ||
              (properties.propertyTypeData!.propertyType ?? '')
                  .toLowerCase()
                  .contains(searchvalue.toLowerCase()) ||
              (properties.propertyTypeData!.propertySubType ?? '')
                  .toLowerCase()
                  .contains(searchvalue.toLowerCase()) ||
              (properties.rentalOwnerData!.rentalOwnerName ?? '')
                  .toLowerCase()
                  .contains(searchvalue.toLowerCase()) ||
              (properties.rentalOwnerData!.rentalOwnerPhoneNumber ?? '')
                  .toLowerCase()
                  .contains(searchvalue.toLowerCase()) ||
              (properties.rentalOwnerData!.rentalOwnerCompanyName ?? '')
                  .toLowerCase()
                  .contains(searchvalue.toLowerCase()) ||
              (properties.rentalOwnerData!.rentalOwnerPrimaryEmail ?? '')
                  .toLowerCase()
                  .contains(searchvalue.toLowerCase()) ||
              (properties.rentalOwnerData!.Address ?? '').toLowerCase().contains(searchvalue.toLowerCase()) ||
              (properties.tenantsData != null && properties.tenantsData!.any((tenant) => (tenant.tenantFirstName ?? '').toLowerCase().contains(searchvalue.toLowerCase()) || (tenant.tenantLastName ?? '').toLowerCase().contains(searchvalue.toLowerCase()))))
          .toList();
    }
    if (selectedApplicantStatus == 'Accepting Applications') {
      list = list.where((properties) => properties.is_available == true).toList();
    } else if (selectedApplicantStatus == 'Not Accepting Applications') {
      list = list.where((properties) => properties.is_available == false).toList();
    }
    if (selectedApplicantOcuupied == 'Occupied') {
      list = list
          .where((properties) =>
              properties.tenantsData != null && properties.tenantsData!.length > 0)
          .toList();
    } else if (selectedApplicantOcuupied == 'Vacant') {
      list = list
          .where((properties) =>
              properties.tenantsData == null || properties.tenantsData!.length == 0)
          .toList();
    }
    if (selectedRentalOwner != null && selectedRentalOwner != "All") {
      list = list
          .where((properties) =>
              properties.rentalOwnerData?.rentalOwnerId == selectedRentalOwner)
          .toList();
    }
    return list;
  }

  Future<RentalsPageResult> _loadProperties() async {
    final repo = PropertiesRepository();
    if (_useServerPagination()) {
      final sort = _apiSortParams();
      var result = await repo.fetchPropertiesPage(
        page: _currentPage + 1,
        limit: _rowsPerPage,
        search: searchvalue,
        sortBy: sort.key,
        sortOrder: sort.value,
        throwOnFailure: true,
      );
      final p = result.pagination;
      if (p != null && p.totalPages > 0 && _currentPage >= p.totalPages) {
        _currentPage = (p.totalPages - 1).clamp(0, p.totalPages - 1);
        result = await repo.fetchPropertiesPage(
          page: _currentPage + 1,
          limit: _rowsPerPage,
          search: searchvalue,
          sortBy: sort.key,
          sortOrder: sort.value,
        );
      }
      return result;
    }
    List<Rentals> list = await repo.fetchProperties();
    list = _applyLocalFilters(list);
    sortData(list);
    return RentalsPageResult(items: list, pagination: null);
  }

  void _reloadProperties() {
    setState(() {
      futurePropertiesLoad = _loadProperties();
    });
  }

  void _scheduleSearchReload() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _currentPage = 0;
        futurePropertiesLoad = _loadProperties();
      });
    });
  }

  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      // decoration: BoxDecoration(
      //   color: blueColor,
      //   borderRadius: BorderRadius.only(
      //     topLeft: Radius.circular(13),
      //     topRight: Radius.circular(13),
      //   ),
      // ),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
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
                onTap: () {
                  setState(() {
                    if (sorting1 == true) {
                      sorting2 = false;
                      sorting3 = false;
                      ascending1 = !ascending1;
                      ascending2 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = true;
                      sorting2 = false;
                      sorting3 = false;
                      ascending1 = false;
                      ascending2 = false;
                      ascending3 = false;
                    }
                    _currentPage = 0;
                    futurePropertiesLoad = _loadProperties();
                  });
                },
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    width < 400
                        ? Text("Property",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14
                            ))
                        : Text("Property",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                    ascending1
                        ? Padding(
                            padding: EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 15,
                              color: blueColor,
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 15,
                              color: blueColor,
                            ),
                          )
                  ],
                ),
              ),
            ),
            // Expanded(
            //   child: InkWell(
            //     onTap: () {
            //       setState(() {
            //         if (sorting2) {
            //           sorting1 = false;
            //           sorting2 = sorting2;
            //           sorting3 = false;
            //           ascending2 = sorting2 ? !ascending2 : true;
            //           ascending1 = false;
            //           ascending3 = false;
            //         } else {
            //           sorting1 = false;
            //           sorting2 = !sorting2;
            //           sorting3 = false;
            //           ascending2 = sorting2 ? !ascending2 : true;
            //           ascending1 = false;
            //           ascending3 = false;
            //         }
            //         // Sorting logic here
            //       });
            //     },
            //     child: Row(
            //       children: [
            //         Text("     Type",
            //             style: TextStyle(color: blueColor, fontWeight: FontWeight.bold , fontSize: 15)),
            //         SizedBox(width: 2),
            //         ascending2
            //             ? Padding(
            //                 padding: const EdgeInsets.only(top: 7, left: 2),
            //                 child: FaIcon(
            //                   FontAwesomeIcons.sortUp,
            //                   size: 20,
            //                   color: Colors.white,
            //                 ),
            //               )
            //             : Padding(
            //                 padding: const EdgeInsets.only(bottom: 7, left: 2),
            //                 child: FaIcon(
            //                   FontAwesomeIcons.sortDown,
            //                   size: 20,
            //                   color: Colors.white,
            //                 ),
            //               ),
            //       ],
            //     ),
            //   ),
            // ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting3 == true) {
                      sorting1 = false;
                      sorting2 = false;
                      ascending3 = !ascending3;
                      ascending2 = false;
                      ascending1 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = false;
                      sorting3 = true;
                      ascending3 = true;
                      ascending2 = false;
                      ascending1 = false;
                    }
                    // Reset expanded index when sorting changes
                    expandedIndex = null;
                    expandedRentalId = null;
                    _currentPage = 0;
                    futurePropertiesLoad = _loadProperties();
                  });
                },
                child: Row(
                  children: [
                    Text("Accepting\nApplication",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    const SizedBox(width: 5),
                    // ascending3
                    //     ? Padding(
                    //         padding: const EdgeInsets.only(top: 7, left: 2),
                    //         child: FaIcon(
                    //           FontAwesomeIcons.sortUp,
                    //           size: 20,
                    //           color: Colors.white,
                    //         ),
                    //       )
                    //     : Padding(
                    //         padding: const EdgeInsets.only(bottom: 7, left: 2),
                    //         child: FaIcon(
                    //           FontAwesomeIcons.sortDown,
                    //           size: 20,
                    //           color: Colors.white,
                    //         ),
                    //       ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Rentals> get _pagedData {
    if (_tableData.isEmpty) return [];

    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;

    // Ensure startIndex is within bounds
    if (startIndex >= _tableData.length) {
      _currentPage = (_tableData.length / _rowsPerPage).floor() - 1;
      startIndex = _currentPage * _rowsPerPage;
      endIndex = startIndex + _rowsPerPage;
    }

    // Ensure endIndex doesn't exceed the array length
    endIndex = endIndex > _tableData.length ? _tableData.length : endIndex;

    return _tableData.sublist(startIndex, endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0; // Reset to the first page when changing rows per page
    });
  }

  final List<String> items = ["All", "Commercial", "Residential"];
  String? selectedValue;
  String searchvalue = "";
  Timer? _searchDebounce;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  ///
  /// Deliberately re-runs the SAME calls `initState` makes and touches no
  /// filter, sort or page field, so a reload returns the user to the list they
  /// were looking at rather than resetting them to an unfiltered page one.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futurePropertiesLoad = _loadProperties();
      futureRentalOwnersList = RentalOwnerService().fetchRentalOwners(null);
    });
    if (mounted) fetchRentaladded();
  }

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    futurePropertiesLoad = _loadProperties();
    futureRentalOwnersList = RentalOwnerService().fetchRentalOwners(null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fetchRentaladded();
    });
    // Set initial sorting to createdAt
    sorting1 = false;
    sorting2 = false;
    sorting3 = false;
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

  void handleEdit(Rentals properties) async {
    // Handle edit action
    // print('Edit ${properties.staffMemberId}');
    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Edit_properties(
                  properties: properties,
                  rentalId: properties.rentalId!,
                )));
    if (check == true) {
      _reloadProperties();
    }
    // final result = await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => Edit_properties(properties: properties,)));
    /* if (result == true) {
      setState(() {
        futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
      });
    }*/
  }

  void handleTap(Rentals properties) async {
    // Handle edit action
    // print('Edit ${properties.rentalId}');
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Summery_page(
                  properties: properties,
                  onPropertyUpdated: _reloadProperties,
                )));
    /* if (result == true) {
      setState(() {
        futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
      });
    }*/
  }

  void _showAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same record.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this property!",
      content: Column(
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for deletion',
                  contentPadding: EdgeInsets.only(top: 8, left: 15)),
            ),
          ),
        ],
      ),
      style: const AlertStyle(
        backgroundColor: Colors.white,
        //  overlayColor: Colors.black.withOpacity(.8)
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            if (reason.text.isEmpty) {
              Fluttertoast.showToast(msg: "Please enter a reason for deletion");
              return;
            }
            if (deleting) return;
            deleting = true;
            // The repository toasts the server's own reason and then throws
            // when the delete is rejected. Nothing caught it, so
            // Navigator.pop was never reached — the dialog stayed open with no
            // explanation and the exception escaped into the framework. Close
            // the dialog either way; the message has already been shown.
            try {
              // print(id);
              var data = await PropertiesRepository()
                  .DeleteProperties(id: id, reason: reason.text);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              if (data != null) _reloadProperties();
              fetchRentaladded();
              Navigator.pop(context);
            } catch (_) {
              deleting = false;
              if (!mounted) return;
              Navigator.pop(context);
            }
          },
          color: blueColor,
        ),
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8), // Rounded corners
          border: Border.all(
            color: blueColor, // Blue border
            width: 1.5,
          ),
        ),
      ],
    ).show();
  }

  void _showAlertforLimit(BuildContext context) {
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Plan Limitation",
      desc:
          "The limit for adding rentalowners according to the plan has been reached.",
      style: const AlertStyle(
          backgroundColor: Color.fromRGBO(255, 255, 255, 1),
          descStyle: TextStyle(fontSize: 14)
          //  overlayColor: Colors.black.withOpacity(.8)
          ),
      buttons: [
        DialogButton(
          child: const Text(
            "OK",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () => Navigator.pop(context),
          color: blueColor,
        ),
        /* DialogButton(
          child: Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
             var data = PropertiesRepository().DeleteProperties(id: id);

            setState(() {
              futureRentalOwners = PropertiesRepository().fetchProperties();
              //  futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
            });
            Navigator.pop(context);
          },
          color: Colors.red,
        )*/
      ],
    ).show();
  }

  void _sort<T>(Comparable<T> Function(Rentals) getField, int columnIndex,
      bool ascending) {
    futurePropertiesLoad.then((result) {
      if (result.pagination != null) return;
      final sorted = List<Rentals>.from(result.items);
      sorted.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        if (aValue is String && bValue is String) {
          final r = (aValue as String)
              .toLowerCase()
              .compareTo((bValue as String).toLowerCase());
          return ascending ? r : -r;
        }
        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
      if (!mounted) return;
      setState(() {
        _sortColumnIndex = columnIndex;
        _sortAscending = ascending;
        futurePropertiesLoad =
            Future.value(RentalsPageResult(items: sorted, pagination: null));
      });
    });
  }

  void handleDelete(Rentals properties) {
    // print(properties.propertyId);
    // _showAlert(context,property.propertyId!);
    _showAlert(context, properties.rentalId!);

    // Handle delete action
    // print('Delete ${properties.propertyId}');
  }

  final _scrollController = ScrollController();
  int rentalCount = 0;
  int propertyCountLimit = 0;
  Future<void> fetchRentaladded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? id = prefs.getString("adminId");
      final String? token = prefs.getString('token');
      if (id == null || token == null) {
        if (mounted) setState(() {});
        return;
      }
      final response = await apiGet(
        Uri.parse('${Api_url}/api/rentals/limitation/$id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
      );
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final code = jsonData["statusCode"];
      final ok = code == 200 ||
          code == 201 ||
          code == '200' ||
          code == '201';
      if (!mounted) return;
      if (ok) {
        int toInt(dynamic v) {
          if (v == null) return 0;
          if (v is int) return v;
          if (v is num) return v.toInt();
          return int.tryParse(v.toString()) ?? 0;
        }

        setState(() {
          rentalCount = toInt(jsonData['rentalCount']);
          propertyCountLimit = toInt(jsonData['propertyCountLimit']);
        });
      }
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Properties",
        dropdown: true,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(
                    height: 20,
                  ),
                  // Header Section with Title and Add Button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(
                            width: 13,
                          ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: titleBar(
                              width: double.infinity,
                              title: 'Properties',
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () async {
                                final ownerDetailsProvider =
                                    Provider.of<OwnerDetailsProvider>(context,
                                        listen: false);
                                ownerDetailsProvider.clearOwners();
                                final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            Add_new_property()));
                                if (result == true) {
                                  setState(() {
                                    _currentPage = 0;
                                    futurePropertiesLoad = _loadProperties();
                                  });
                                  fetchRentaladded();
                                }
                              },
                              child: Container(
                                height:
                                    (MediaQuery.of(context).size.width < 768)
                                        ? 50
                                        : 60,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Text(
                                    "+ Add",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (MediaQuery.of(context).size.width < 500)
                          SizedBox(width: 3),
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 18),
                      ],
                    ),
                  ),
                  // SizedBox(height: 10),
                  const SizedBox(height: 10),
                  // search and type
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 11,
                      right: 11,
                    ),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 18),
                        Expanded(
                          child: Material(
                            elevation: 3,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              // height: 40,
                              height: MediaQuery.of(context).size.width < 500
                                  ? 45
                                  : 50,
                              // width: MediaQuery.of(context).size.width < 500
                              //     ? MediaQuery.of(context).size.width * .52
                              //     : MediaQuery.of(context).size.width * .49,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  // border: Border.all(color: Colors.grey),
                                  border: Border.all(
                                      color: const Color(0xFF8A95A8))),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: TextField(
                                      style: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 12
                                              : 14),
                                      // onChanged: (value) {
                                      //   setState(() {
                                      //     cvverror = false;
                                      //   });
                                      // },
                                      // controller: cvv,
                                      onChanged: (value) {
                                        setState(() {
                                          searchvalue = value;
                                          if (!_useServerPagination() &&
                                              _currentPage != 0) {
                                            _currentPage = 0;
                                          }
                                        });
                                        if (_useServerPagination()) {
                                          _scheduleSearchReload();
                                        }
                                      },
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Search here...",
                                        hintStyle: TextStyle(
                                            color: const Color(0xFF495160),
                                            fontWeight: FontWeight.bold,
                                            // fontWeight: FontWeight.bold,
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 14
                                                : 18),
                                        contentPadding: (const EdgeInsets.only(
                                            left: 5, bottom: 12, top: 5)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: Material(
                              elevation: 3,
                              borderRadius: BorderRadius.circular(8),
                              child: DropdownButton2<String>(
                                isExpanded: true,
                                hint: const Row(
                                  children: [
                                    SizedBox(
                                      width: 4,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Select Type',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF495160),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                items: items
                                    .map((String item) =>
                                        DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                value: selectedValue,
                                onChanged: (value) {
                                  setState(() {
                                    selectedValue = value;
                                    _currentPage = 0;
                                    futurePropertiesLoad = _loadProperties();
                                  });
                                },
                                buttonStyleData: ButtonStyleData(
                                  // height: 40,
                                  height:
                                      MediaQuery.of(context).size.width < 500
                                          ? 45
                                          : 50,
                                  width: MediaQuery.of(context).size.width < 500
                                      ? MediaQuery.of(context).size.width * .37
                                      : MediaQuery.of(context).size.width * .4,
                                  padding: const EdgeInsets.only(
                                      left: 8, right: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      // color: Colors.black26,
                                      color: const Color(0xFF8A95A8),
                                    ),
                                    color: Colors.white,
                                  ),
                                  elevation: 0,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 200,
                                  width: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    //color: Colors.redAccent,
                                  ),
                                  offset: const Offset(-20, 0),
                                  scrollbarTheme: ScrollbarThemeData(
                                    radius: const Radius.circular(40),
                                    thickness: MaterialStateProperty.all(6),
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                  ),
                                ),
                                menuItemStyleData: const MenuItemStyleData(
                                  height: 40,
                                  padding: EdgeInsets.only(left: 14, right: 14),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 11,
                      right: 11,
                    ),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 18),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: Material(
                              elevation: 3,
                              borderRadius: BorderRadius.circular(8),
                              child: DropdownButton2<String>(
                                isExpanded: true,
                                hint: Row(
                                  children: [
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Select Availability',
                                        style: TextStyle(
                                          fontSize:
                                              screenHeight > 677 ? 13.6 : 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF495160),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                buttonStyleData: ButtonStyleData(
                                  // height: 40,
                                  height:
                                      MediaQuery.of(context).size.width < 500
                                          ? 45
                                          : 50,
                                  width: MediaQuery.of(context).size.width < 500
                                      ? MediaQuery.of(context).size.width * .37
                                      : MediaQuery.of(context).size.width * .4,
                                  padding:
                                      const EdgeInsets.only(left: 8, right: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      // color: Colors.black26,
                                      color: const Color(0xFF8A95A8),
                                    ),
                                    color: Colors.white,
                                  ),
                                  elevation: 0,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 200,
                                  width: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    //color: Colors.redAccent,
                                  ),
                                  offset: const Offset(-20, 0),
                                  scrollbarTheme: ScrollbarThemeData(
                                    radius: const Radius.circular(40),
                                    thickness: MaterialStateProperty.all(6),
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                  ),
                                ),
                                menuItemStyleData: const MenuItemStyleData(
                                  height: 40,
                                  padding: EdgeInsets.only(left: 14, right: 14),
                                ),
                                items: applicantStatusOptions
                                    .map((String item) =>
                                        DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                value: selectedApplicantStatus,
                                onChanged: (value) {
                                  setState(() {
                                    selectedApplicantStatus = value;
                                    _currentPage = 0;
                                    futurePropertiesLoad = _loadProperties();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: Material(
                              elevation: 3,
                              borderRadius: BorderRadius.circular(8),
                              child: DropdownButton2<String>(
                                isExpanded: true,
                                hint: Row(
                                  children: [
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Select Occupancy',
                                        style: TextStyle(
                                          fontSize:
                                              screenHeight > 677 ? 12.8 : 12.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF495160),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                buttonStyleData: ButtonStyleData(
                                  // height: 40,
                                  height:
                                      MediaQuery.of(context).size.width < 500
                                          ? 45
                                          : 50,
                                  width: MediaQuery.of(context).size.width < 500
                                      ? MediaQuery.of(context).size.width * .37
                                      : MediaQuery.of(context).size.width * .4,
                                  padding:
                                      const EdgeInsets.only(left: 8, right: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      // color: Colors.black26,
                                      color: const Color(0xFF8A95A8),
                                    ),
                                    color: Colors.white,
                                  ),
                                  elevation: 0,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 200,
                                  width: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    //color: Colors.redAccent,
                                  ),
                                  offset: const Offset(-20, 0),
                                  scrollbarTheme: ScrollbarThemeData(
                                    radius: const Radius.circular(40),
                                    thickness: MaterialStateProperty.all(6),
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                  ),
                                ),
                                menuItemStyleData: const MenuItemStyleData(
                                  height: 40,
                                  padding: EdgeInsets.only(left: 14, right: 14),
                                ),
                                items: applicantoccupiedOptions
                                    .map((String item) =>
                                        DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                value: selectedApplicantOcuupied,
                                onChanged: (value) {
                                  setState(() {
                                    selectedApplicantOcuupied = value;
                                    _currentPage = 0;
                                    futurePropertiesLoad = _loadProperties();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 11,
                      right: 11,
                    ),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 18),
                        Expanded(
                          flex: 1,
                          child: FutureBuilder<
                              List<RentalOwnerModel.RentalOwnerData>>(
                            future: futureRentalOwnersList,
                            builder: (context, snapshot) {
                              List<String> ownerOptions = ['All'];
                              if (snapshot.hasData && snapshot.data != null) {
                                // Sort rental owners alphabetically by name
                                List<RentalOwnerModel.RentalOwnerData>
                                    sortedOwners = List.from(snapshot.data!);
                                sortedOwners.sort((a, b) {
                                  String nameA =
                                      (a.rentalOwnername ?? '').toLowerCase();
                                  String nameB =
                                      (b.rentalOwnername ?? '').toLowerCase();
                                  return nameA.compareTo(nameB);
                                });
                                ownerOptions.addAll(sortedOwners
                                    .where((owner) =>
                                        owner.rentalownerId != null &&
                                        owner.rentalownerId!.isNotEmpty)
                                    .map((owner) => owner.rentalownerId!)
                                    .toList());
                              }
                              return DropdownButtonHideUnderline(
                                child: Material(
                                  elevation: 3,
                                  borderRadius: BorderRadius.circular(8),
                                  child: DropdownButton2<String>(
                                    isExpanded: true,
                                    hint: Row(
                                      children: [
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Select Owner',
                                            style: TextStyle(
                                              fontSize: screenHeight > 677
                                                  ? 13.6
                                                  : 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF495160),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    buttonStyleData: ButtonStyleData(
                                      height:
                                          MediaQuery.of(context).size.width <
                                                  500
                                              ? 45
                                              : 50,
                                      padding: const EdgeInsets.only(
                                          left: 8, right: 6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF8A95A8),
                                        ),
                                        color: Colors.white,
                                      ),
                                      elevation: 0,
                                    ),
                                    dropdownStyleData: DropdownStyleData(
                                      maxHeight: 200,
                                      width: 200,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      offset: const Offset(-20, 0),
                                      scrollbarTheme: ScrollbarThemeData(
                                        radius: const Radius.circular(40),
                                        thickness: MaterialStateProperty.all(6),
                                        thumbVisibility:
                                            MaterialStateProperty.all(true),
                                      ),
                                    ),
                                    menuItemStyleData: const MenuItemStyleData(
                                      height: 40,
                                      padding:
                                          EdgeInsets.only(left: 14, right: 14),
                                    ),
                                    items: ownerOptions.map((String item) {
                                      String displayText = item;
                                      if (item != 'All' &&
                                          snapshot.hasData &&
                                          snapshot.data != null) {
                                        try {
                                          // Use sorted owners for consistent lookup
                                          List<RentalOwnerModel.RentalOwnerData>
                                              sortedOwners =
                                              List.from(snapshot.data!);
                                          sortedOwners.sort((a, b) {
                                            String nameA =
                                                (a.rentalOwnername ?? '')
                                                    .toLowerCase();
                                            String nameB =
                                                (b.rentalOwnername ?? '')
                                                    .toLowerCase();
                                            return nameA.compareTo(nameB);
                                          });
                                          final owner = sortedOwners.firstWhere(
                                            (o) =>
                                                o.rentalownerId != null &&
                                                o.rentalownerId == item,
                                          );
                                          displayText =
                                              owner.rentalOwnername ?? item;
                                        } catch (e) {
                                          displayText = item;
                                        }
                                      }
                                      return DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(
                                          displayText,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    value: selectedRentalOwner,
                                    onChanged: (value) {
                                      setState(() {
                                        selectedRentalOwner = value;
                                        _currentPage = 0;
                                        futurePropertiesLoad =
                                            _loadProperties();
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: screenHeight > 677 ? 13.6 : 13,
                                    color: blueColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Added : ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2332),)),
                                    TextSpan(
                                      text: '$rentalCount',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A2332),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 6),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                  // const SizedBox(
                  //   height: 10,
                  // ),
                  // Row(
                  //   children: [
                  //     Spacer(),
                  //     Row(
                  //       children: [
                  //         Text(
                  //           'Added : ${rentalCount.toString()}',
                  //           style: TextStyle(
                  //             fontWeight: FontWeight.bold,
                  //             color: Color(0xFF8A95A8),
                  //             fontSize:
                  //                 MediaQuery.of(context).size.width < 500 ? 13 : 18,
                  //           ),
                  //         ),
                  //         SizedBox(
                  //           width: 5,
                  //         ),
                  //         Text(
                  //           "/",
                  //           style: TextStyle(color: greyColor),
                  //         ),
                  //         SizedBox(
                  //           width: 5,
                  //         ),
                  //         //  Text("rentalOwnerCountLimit: ${response['rentalOwnerCountLimit']}"),
                  //         Text(
                  //           'Total: ${propertyCountLimit.toString()}',
                  //           style: TextStyle(
                  //             fontWeight: FontWeight.bold,
                  //             color: Color(0xFF8A95A8),
                  //             fontSize:
                  //                 MediaQuery.of(context).size.width < 500 ? 13 : 18,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //     if (MediaQuery.of(context).size.width < 500)
                  //       SizedBox(width: 15),
                  //     if (MediaQuery.of(context).size.width > 500)
                  //       SizedBox(width: 39),
                  //   ],
                  // ),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(height: 25),
                  if (MediaQuery.of(context).size.width < 500)
                    Padding(
                      // padding: const EdgeInsets.all(11.0),
                      padding: EdgeInsets.all(
                          MediaQuery.of(context).size.width < 500 ? 11 : 28),
                      child: FutureBuilder<RentalsPageResult>(
                        future: futurePropertiesLoad,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return ColabShimmerLoadingWidget();
                          } else if (snapshot.hasError) {
                            // A FAILED request has no data either, so without
                            // this branch it fell through to "No Data
                            // Available" below — a network failure disguised
                            // as an empty list, with no way to retry.
                            return NoInternetView(onRetry: retryNow);
                          } else if (!snapshot.hasData ||
                              snapshot.data!.items.isEmpty) {
                            return Container(
                              height: MediaQuery.of(context).size.height * .5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      "assets/images/no_data.jpg",
                                      height: 200,
                                      width: 200,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "No Data Available",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 16),
                                    )
                                  ],
                                ),
                              ),
                            );
                          } else {
                            final pageResult = snapshot.data!;
                            final pag = pageResult.pagination;
                            late final int totalPages;
                            late final List<Rentals> currentPageData;

                            if (pag != null) {
                              _tableData = pageResult.items;
                              totalPages = pag.totalPages <= 0
                                  ? 1
                                  : pag.totalPages;
                              currentPageData = pageResult.items;
                            } else {
                              final data =
                                  List<Rentals>.from(pageResult.items);
                              _tableData = data;
                              final rawPages =
                                  (_tableData.length / _rowsPerPage).ceil();
                              totalPages = rawPages < 1 ? 1 : rawPages;
                              if (_currentPage >= totalPages) {
                                _currentPage = totalPages - 1;
                              }
                              if (_currentPage < 0) _currentPage = 0;
                              final startIndex = _currentPage * _rowsPerPage;
                              final endIndex =
                                  startIndex + _rowsPerPage > _tableData.length
                                      ? _tableData.length
                                      : startIndex + _rowsPerPage;
                              currentPageData =
                                  _tableData.sublist(startIndex, endIndex);
                            }

                            final int totalForPager =
                                pag?.totalItems ?? _tableData.length;
                            // Always show pager when there is data so rows-per-page can be
                            // changed (e.g. 25 → 10) even when everything fits one page.
                            final bool showPagination = totalForPager > 0;

                            for (int i = 0; i < currentPageData.length; i++) {
                            }

                            // Find the correct index for expanded property by rentalId
                            if (expandedRentalId != null) {
                              int? foundIndex;
                              for (int i = 0; i < currentPageData.length; i++) {
                                if (currentPageData[i].rentalId ==
                                    expandedRentalId) {
                                  foundIndex = i;
                                  break;
                                }
                              }
                              if (foundIndex != null &&
                                  foundIndex != expandedIndex) {
                                expandedIndex = foundIndex;
                              } else if (foundIndex == null) {
                                expandedIndex = null;
                                expandedRentalId = null;
                              }
                            }

                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  const SizedBox(height: 2),
                                  _buildHeaders(),
                                  const SizedBox(height: 10),
                                  Container(
                                    // decoration: BoxDecoration(
                                    //     border: Border.all(
                                    //         color: Color.fromRGBO(
                                    //             152, 162, 179, .5))),
                                    // decoration: BoxDecoration(
                                    //     border: Border.all(color: blueColor)),
                                    child: Column(
                                      children: currentPageData.isEmpty
                                          ? [kNoSearchResults(context)]
                                          : currentPageData
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        int index = entry.key;
                                        bool isExpanded =
                                            expandedIndex == index;
                                        Rentals rentals = entry.value;
                                        //return CustomExpansionTile(data: Propertytype, index: index);
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (expandedIndex == index) {
                                                expandedIndex = null;
                                                expandedRentalId = null;
                                              } else {
                                                expandedIndex = index;
                                                expandedRentalId =
                                                    rentals.rentalId;
                                              }
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            // decoration: BoxDecoration(
                                            //   border: Border.all(color: blueColor),
                                            // ),
                                            decoration: BoxDecoration(
                                              color: index % 2 != 0
                                                  ? const Color(0xFFF4F8FF)
                                                  : Colors.white,
                                              border: Border.all(
                                                  color:
                                                      const Color(0xFFDBE0E5)),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              children: <Widget>[
                                                ListTile(
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
                                                            setState(() {
                                                              if (expandedIndex ==
                                                                  index) {
                                                                expandedIndex =
                                                                    null;
                                                                expandedRentalId =
                                                                    null;
                                                              } else {
                                                                expandedIndex =
                                                                    index;
                                                                expandedRentalId =
                                                                    rentals
                                                                        .rentalId;
                                                              }
                                                            });
                                                          },
                                                          child: Container(
                                                            //width: 25,
                                                            // color: Colors.blue,
                                                            margin:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 5,
                                                                    right: 2),
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
                                                          child: InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                if (expandedIndex ==
                                                                    index) {
                                                                  expandedIndex =
                                                                      null;
                                                                  expandedRentalId =
                                                                      null;
                                                                } else {
                                                                  expandedIndex =
                                                                      index;
                                                                  expandedRentalId =
                                                                      rentals
                                                                          .rentalId;
                                                                }
                                                              });
                                                            },
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left:
                                                                          10.0),
                                                              child: Text(
                                                                '${(rentals.rentalAddress ?? '').isEmpty ? 'N/A' : rentals.rentalAddress}',
                                                                style:
                                                                    TextStyle(
                                                                  color:
                                                                      blueColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        // SizedBox(
                                                        //     width: MediaQuery.of(
                                                        //                 context)
                                                        //             .size
                                                        //             .width *
                                                        //         .01),
                                                        // Expanded(
                                                        //   child: Text(
                                                        //     '${(rentals.propertyTypeData!.propertyType ?? '').isEmpty ? 'N/A' : rentals.propertyTypeData!.propertyType} - \n ${(rentals.propertyTypeData!.propertySubType ?? '').isEmpty ? 'N/A' : rentals.propertyTypeData!.propertySubType}  ',
                                                        //     style: TextStyle(
                                                        //       color: blueColor,
                                                        //       fontWeight:
                                                        //           FontWeight.bold,
                                                        //       fontSize: 13,
                                                        //     ),
                                                        //   ),
                                                        // ),
                                                        SizedBox(
                                                            width:
                                                                MediaQuery.of(context)
                                                                        .size
                                                                        .width *
                                                                    .05),

                                                        rentals!.is_available!
                                                            ? Expanded(
                                                                flex: 2,
                                                                child: Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        _publishRentAmount(
                                                                            rentals
                                                                                .rentalId!,
                                                                            "0",
                                                                            isAvailable:
                                                                                true);
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            5),
                                                                        decoration: BoxDecoration(
                                                                            borderRadius:
                                                                                BorderRadius.circular(8),
                                                                            color: Colors.greenAccent.shade100),
                                                                        child: const Center(
                                                                            child: Icon(
                                                                          Icons
                                                                              .check_circle,
                                                                          color:
                                                                              Colors.green,
                                                                        )),
                                                                      ),
                                                                    ),
                                                                    const Spacer()
                                                                  ],
                                                                ))
                                                            : Expanded(
                                                                flex: 2,
                                                                child: Row(
                                                                  children: [
                                                                    const SizedBox(
                                                                      width: 2,
                                                                    ),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        _showPublishRentDialog(
                                                                            rentals.rentalId!);
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        padding: const EdgeInsets
                                                                            .all(
                                                                            5),
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color: Colors
                                                                              .redAccent
                                                                              .withOpacity(0.3),
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                        ),
                                                                        child: const Center(
                                                                            child: Icon(
                                                                          Icons
                                                                              .lock_rounded,
                                                                          color:
                                                                              Colors.red,
                                                                        )),
                                                                      ),
                                                                    ),
                                                                    const Spacer()
                                                                  ],
                                                                )),
                                                        SizedBox(
                                                            width:
                                                                MediaQuery.of(context)
                                                                        .size
                                                                        .width *
                                                                    .02),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (isExpanded)
                                                  Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                      border: Border(
                                                        top: BorderSide(
                                                            color: Color(
                                                                0xFFDBE0E5),
                                                            width: 1),
                                                      ),
                                                    ),
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
                                                                size: 20,
                                                                color: Colors
                                                                    .transparent,
                                                              ),
                                                              Expanded(
                                                                child: Table(
                                                                  columnWidths: {
                                                                    // 0: FixedColumnWidth(150.0), // Adjust width as needed
                                                                    // 1: FlexColumnWidth(),
                                                                    0: const FlexColumnWidth(), // Distribute columns equally
                                                                    1: const FlexColumnWidth(),
                                                                  },
                                                                  children: [
                                                                    _buildTableRow(
                                                                        'Rental Company Name :',
                                                                        _getDisplayValue(rentals
                                                                            .rentalOwnerData
                                                                            ?.rentalOwnerCompanyName),
                                                                        'City :',
                                                                        _getDisplayValue(
                                                                            rentals.rentalCity)),
                                                                    _buildTableRow(
                                                                      'Property Type :',
                                                                      '${_getDisplayValue(rentals.propertyTypeData?.propertyType)} - ${_getDisplayValue(rentals.propertyTypeData?.propertySubType)}',
                                                                      'Tenants :',
                                                                      rentals.tenantsData != null &&
                                                                              rentals
                                                                                  .tenantsData!.isNotEmpty
                                                                          ? rentals
                                                                              .tenantsData!
                                                                              .map((tenant) => "${tenant.tenantFirstName ?? ''} ${tenant.tenantLastName ?? ''}".trim())
                                                                              .join(", ")
                                                                          : "-----",
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),

                                                              // FaIcon(
                                                              //   isExpanded
                                                              //       ? FontAwesomeIcons
                                                              //       .sortUp
                                                              //       : FontAwesomeIcons
                                                              //       .sortDown,
                                                              //   size: 20,
                                                              //   color:
                                                              //   Colors.transparent,
                                                              // ),
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
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                              GestureDetector(
                                                                onTap: () {
                                                                  // Check if property is multi-unit based on property type data
                                                                  bool
                                                                      isMultiUnit =
                                                                      rentals.propertyTypeData
                                                                              ?.isMultiunit ??
                                                                          false;

                                                                  Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                          builder: (context) => Summery_page(
                                                                                properties: rentals,
                                                                                onPropertyUpdated: _reloadProperties,
                                                                              )));
                                                                },
                                                                child:
                                                                    Container(
                                                                  height: 35,
                                                                  width: 35,
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade200,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child:
                                                                      const Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      FaIcon(
                                                                        FontAwesomeIcons
                                                                            .eye,
                                                                        size:
                                                                            15,
                                                                        color: Colors
                                                                            .black,
                                                                      ),
                                                                      SizedBox(
                                                                          width:
                                                                              2),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 5,
                                                              ),
                                                              GestureDetector(
                                                                onTap:
                                                                    () async {
                                                                  var check =
                                                                      await Navigator
                                                                          .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              Edit_properties(
                                                                        properties:
                                                                            rentals,
                                                                        rentalId:
                                                                            rentals.rentalId!,
                                                                      ),
                                                                    ),
                                                                  );
                                                                  if (check ==
                                                                      true) {
                                                                    _reloadProperties();
                                                                  }
                                                                },
                                                                child:
                                                                    Container(
                                                                  height: 35,
                                                                  width: 35,
                                                                  decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8),
                                                                      color: Colors
                                                                          .green
                                                                          .shade50), // color:Colors.grey[100],
                                                                  child:
                                                                      const Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      FaIcon(
                                                                        FontAwesomeIcons
                                                                            .edit,
                                                                        size:
                                                                            15,
                                                                        color: Colors
                                                                            .green,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 5,
                                                              ),
                                                              GestureDetector(
                                                                onTap: () {
                                                                  setState(() {
                                                                    _showAlert(
                                                                        context,
                                                                        rentals
                                                                            .rentalId!);
                                                                  });
                                                                },
                                                                child:
                                                                    Container(
                                                                  height: 35,
                                                                  width: 35,
                                                                  decoration: BoxDecoration(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              8),
                                                                      color: Colors
                                                                          .red
                                                                          .shade50),
                                                                  child:
                                                                      const Row(
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      FaIcon(
                                                                        FontAwesomeIcons
                                                                            .trashCan,
                                                                        size:
                                                                            15,
                                                                        color: Colors
                                                                            .red,
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 12,
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                            height: 15,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                //SizedBox(height: 13,),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  if (showPagination)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Row(
                                          children: [
                                            // Text('Rows per page:'),
                                            const SizedBox(width: 10),
                                            Material(
                                              elevation: 3,
                                              child: Container(
                                                height: 40,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12.0),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                ),
                                                child:
                                                    DropdownButtonHideUnderline(
                                                  child: DropdownButton<int>(
                                                    value: _rowsPerPage,
                                                    items: itemsPerPageOptions
                                                        .map((int value) {
                                                      return DropdownMenuItem<
                                                          int>(
                                                        value: value,
                                                        child: Text(
                                                            value.toString()),
                                                      );
                                                    }).toList(),
                                                    onChanged: totalForPager > 0
                                                        ? (newValue) {
                                                            setState(() {
                                                              _rowsPerPage =
                                                                  newValue!;
                                                              _currentPage =
                                                                  0;
                                                              if (_useServerPagination()) {
                                                                futurePropertiesLoad =
                                                                    _loadProperties();
                                                              }
                                                            });
                                                          }
                                                        : null,
                                                    icon: const Icon(
                                                      Icons.arrow_drop_down,
                                                      size: 40,
                                                    ),
                                                    style: const TextStyle(
                                                        color: Colors.black,
                                                        fontSize: 17),
                                                    dropdownColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: FaIcon(
                                                FontAwesomeIcons
                                                    .circleChevronLeft,
                                                color: _currentPage == 0
                                                    ? Colors.grey
                                                    : blueColor,
                                              ),
                                              onPressed: _currentPage == 0
                                                  ? null
                                                  : () {
                                                      setState(() {
                                                        _currentPage--;
                                                        if (pag != null) {
                                                          futurePropertiesLoad =
                                                              _loadProperties();
                                                        }
                                                      });
                                                    },
                                            ),
                                            // IconButton(
                                            //   icon: Icon(Icons.arrow_back),
                                            //   onPressed: currentPage > 0
                                            //       ? () {
                                            //     setState(() {
                                            //       currentPage--;
                                            //     });
                                            //   }
                                            //       : null,
                                            // ),
                                            Text(
                                                'Page ${_currentPage + 1} of $totalPages'),
                                            // IconButton(
                                            //   icon: Icon(Icons.arrow_forward),
                                            //   onPressed: currentPage < totalPages - 1
                                            //       ? () {
                                            //     setState(() {
                                            //       currentPage++;
                                            //     });
                                            //   }
                                            //       : null,
                                            // ),
                                            IconButton(
                                              icon: FaIcon(
                                                FontAwesomeIcons
                                                    .circleChevronRight,
                                                color: _currentPage <
                                                        totalPages - 1
                                                    ? blueColor
                                                    : Colors.grey,
                                              ),
                                              onPressed:
                                                  _currentPage < totalPages - 1
                                                      ? () {
                                                          setState(() {
                                                            _currentPage++;
                                                            if (pag != null) {
                                                              futurePropertiesLoad =
                                                                  _loadProperties();
                                                            }
                                                          });
                                                        }
                                                      : null,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }

  void _showPublishRentDialog(String rentalId) {
    TextEditingController rentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Published Rent Amount'),
          content: TextField(
            controller: rentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Rent Amount',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                String rentAmount = rentController.text.trim();
                if (rentAmount.isEmpty) {
                  Fluttertoast.showToast(msg: "Please enter a rent amount");
                  return;
                }
                if (double.tryParse(rentAmount) == null) {
                  Fluttertoast.showToast(
                      msg: "Please enter a valid rent amount");
                  return;
                }
                Navigator.of(context).pop();
                await _publishRentAmount(rentalId, rentAmount);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _publishRentAmount(String rentalId, String rentAmount,
      {bool isAvailable = false}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    try {
      final response = await apiPut(
        Uri.parse('${Api_url}/api/rentals/rental/$rentalId/availability'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "is_available": !isAvailable ? true : false,
          "published_rent_amount": double.tryParse(rentAmount) ?? 0.0,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
            msg: "Property availability updated successfully.");
        // Optionally refresh data here
        _reloadProperties();
      } else {
        Fluttertoast.showToast(msg: "Failed to publish rent amount");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${friendlyErrorMessage(e)}");
    }
  }
  // Widget _buildHeader<T>(String text, int columnIndex,
  //     Comparable<T> Function(Rentals d)? getField) {
  //   return Container(
  //     height: 70,
  //     child: TableCell(
  //       child: InkWell(
  //         onTap: getField != null
  //             ? () {
  //                 _sort(getField, columnIndex, !_sortAscending);
  //               }
  //             : null,
  //         child: Padding(
  //           padding: const EdgeInsets.all(8.0),
  //           child: Row(
  //             children: [
  //               Text(text,
  //                   style:
  //                       TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
  //               if (getField != null)
  //                 Icon(
  //                   _sortColumnIndex == columnIndex
  //                       ? (_sortAscending
  //                           ? Icons.arrow_drop_up_outlined
  //                           : Icons.arrow_drop_down_outlined)
  //                       : Icons
  //                           .arrow_drop_down_outlined, // Default icon for unsorted columns
  //                 ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                const SizedBox(height: 4.0), // Space between label and value
                Text(
                  leftValue,
                  style: TextStyle(color: grey),
                ),
              ],
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.only(left: 65, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  rightLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                const SizedBox(height: 4.0), // Space between label and value
                Text(
                  rightValue,
                  style: TextStyle(color: grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayValue(String? value) {
    // Return 'N/A' if the value is null or empty, otherwise return the value
    return (value == null || value.trim().isEmpty) ? 'N/A' : value;
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(Rentals d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField, columnIndex, !_sortAscending);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Container(
            height: 60,
            child: Row(
              children: [
                Text(text,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                if (_sortColumnIndex == columnIndex)
                  Icon(_sortAscending
                      ? Icons.arrow_drop_down_outlined
                      : Icons.arrow_drop_up_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, Rentals inkText) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => Summery_page(
                            properties: inkText,
                            onPropertyUpdated: _reloadProperties,
                          )));
            },
            child: Text(text?.isNotEmpty == true ? text! : 'N/A',
                style: const TextStyle(fontSize: 18))),
      ),
    );
  }

  Widget _buildActionsCell(Rentals data) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          height: 50,
          // color: Colors.blue,
          child: Row(
            children: [
              const SizedBox(
                width: 20,
              ),
              InkWell(
                onTap: () {
                  handleEdit(data);
                },
                child: const FaIcon(
                  FontAwesomeIcons.edit,
                  size: 30,
                  color: Colors.green,
                ),
              ),
              const SizedBox(
                width: 15,
              ),
              InkWell(
                onTap: () {
                  handleDelete(data);
                },
                child: const FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 30,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    int totalPages = (_tableData.isEmpty ? 1 : (_tableData.length / _rowsPerPage).ceil());

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          elevation: 2,
          color: Colors.white,
          child: Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                items: itemsPerPageOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: _tableData.length > itemsPerPageOptions.first
                    ? (newValue) {
                        setState(() {
                          _rowsPerPage = newValue!;
                          _currentPage = 0; // Reset to first page
                        });
                      }
                    : null,
                icon: const Icon(Icons.arrow_drop_down, size: 40),
                style: const TextStyle(color: Colors.black, fontSize: 17),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.circleChevronLeft,
            color: _currentPage == 0 ? Colors.grey : blueColor,
          ),
          onPressed: _currentPage == 0
              ? null
              : () {
                  setState(() {
                    _currentPage--;
                  });
                },
        ),
        Text(
          'Page ${_currentPage + 1} of $totalPages',
          style: const TextStyle(fontSize: 18),
        ),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.circleChevronRight,
            color: _currentPage >= totalPages - 1 ? Colors.grey : blueColor,
          ),
          onPressed: _currentPage >= totalPages - 1
              ? null
              : () {
                  setState(() {
                    _currentPage++;
                  });
                },
        ),
      ],
    );
  }
}
