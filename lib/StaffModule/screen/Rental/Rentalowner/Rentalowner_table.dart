import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../model/staffpermission.dart';
import '../../../repository/staffpermission_provider.dart';
import 'Edit_RentalOwners.dart';
import 'rentalowner_summery.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../../../Model/RentalOwnersData.dart';
import '../../../../constant/constant.dart';
import '../../../model/rentalOwner.dart';
import '../../../model/rentalowners_summery.dart';
import '../../../model/staffmember.dart';
import '../../../repository/Rental_ownersData.dart';
import '../../../repository/Staffmember.dart';
import '../../../repository/rentalowner.dart';
import '../../../widgets/drawer_tiles.dart';

import 'Add_RentalOwners.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class Rentalowner_table extends StatefulWidget {
  final bool
      isEmbedded; // When true, shows only table content without Scaffold/AppBar/Drawer

  const Rentalowner_table({super.key, this.isEmbedded = false});

  @override
  State<Rentalowner_table> createState() => _Rentalowner_tableState();
}

class _Rentalowner_tableState extends State<Rentalowner_table>
    with NetworkRetryState {
  late Future<List<RentalOwnerData>> futureRentalOwners;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  final List<String> roles = ['Manager', 'Employee', 'All'];
  String? selectedRole;
  String searchValue = "";
  int currentPage = 0;
  int itemsPerPage = 10;
  int? expandedIndex;
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

  void sortData(List<RentalOwnerData> data) {
    if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.rentalOwnername!.compareTo(b.rentalOwnername!)
          : b.rentalOwnername!.compareTo(a.rentalOwnername!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.rentalOwnerPhoneNumber!.compareTo(b.rentalOwnerPhoneNumber!)
          : b.rentalOwnerPhoneNumber!.compareTo(a.rentalOwnerPhoneNumber!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.rentalOwnerPrimaryEmail!.compareTo(b.rentalOwnerPrimaryEmail!)
          : b.rentalOwnerPrimaryEmail!.compareTo(a.rentalOwnerPrimaryEmail!));
    }
  }

  // Widget _buildHeaders() {
  //   var width = MediaQuery.of(context).size.width;
  //   return Container(
  //     decoration: BoxDecoration(
  //       color: blueColor,
  //       borderRadius: BorderRadius.only(
  //         topLeft: Radius.circular(13),
  //         topRight: Radius.circular(13),
  //       ),
  //     ),
  //     child: ListTile(
  //       contentPadding: EdgeInsets.zero,
  //       title: Row(
  //         mainAxisAlignment: MainAxisAlignment.start,
  //         children: <Widget>[
  //           Container(
  //             child: Icon(
  //               Icons.expand_less,
  //               color: Colors.transparent,
  //             ),
  //           ),
  //           Expanded(
  //             flex: 3,
  //             child: InkWell(
  //               onTap: () {
  //                 setState(() {
  //                   if (sorting1 == true) {
  //                     sorting2 = false;
  //                     sorting3 = false;
  //                     ascending1 = sorting1 ? !ascending1 : true;
  //                     ascending2 = false;
  //                     ascending3 = false;
  //                   } else {
  //                     sorting1 = !sorting1;
  //                     sorting2 = false;
  //                     sorting3 = false;
  //                     ascending1 = sorting1 ? !ascending1 : true;
  //                     ascending2 = false;
  //                     ascending3 = false;
  //                   }
  //
  //                   // Sorting logic here
  //                 });
  //               },
  //               child: Row(
  //                 children: [
  //                   width < 400
  //                       ? Text("Name",
  //                           style: TextStyle(color: Colors.white, fontSize: 18))
  //                       : Text("Name",
  //                           style:
  //                               TextStyle(color: Colors.white, fontSize: 18)),
  //                   // Text("Property", style: TextStyle(color: Colors.white)),
  //                   SizedBox(width: 3),
  //                   ascending1
  //                       ? Padding(
  //                           padding: const EdgeInsets.only(top: 7, left: 2),
  //                           child: FaIcon(
  //                             FontAwesomeIcons.sortUp,
  //                             size: 20,
  //                             color: Colors.white,
  //                           ),
  //                         )
  //                       : Padding(
  //                           padding: const EdgeInsets.only(bottom: 7, left: 2),
  //                           child: FaIcon(
  //                             FontAwesomeIcons.sortDown,
  //                             size: 20,
  //                             color: Colors.white,
  //                           ),
  //                         ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //           Expanded(
  //             flex: 3,
  //             child: InkWell(
  //               onTap: () {
  //                 setState(() {
  //                   if (sorting2) {
  //                     sorting1 = false;
  //                     sorting2 = sorting2;
  //                     sorting3 = false;
  //                     ascending2 = sorting2 ? !ascending2 : true;
  //                     ascending1 = false;
  //                     ascending3 = false;
  //                   } else {
  //                     sorting1 = false;
  //                     sorting2 = !sorting2;
  //                     sorting3 = false;
  //                     ascending2 = sorting2 ? !ascending2 : true;
  //                     ascending1 = false;
  //                     ascending3 = false;
  //                   }
  //                   // Sorting logic here
  //                 });
  //               },
  //               child: Row(
  //                 children: [
  //                   SizedBox(width: 15),
  //                   Text("Phone",
  //                       style: TextStyle(color: Colors.white, fontSize: 18)),
  //                   SizedBox(width: 5),
  //                   ascending2
  //                       ? Padding(
  //                           padding: const EdgeInsets.only(top: 7, left: 2),
  //                           child: FaIcon(
  //                             FontAwesomeIcons.sortUp,
  //                             size: 20,
  //                             color: Colors.white,
  //                           ),
  //                         )
  //                       : Padding(
  //                           padding: const EdgeInsets.only(bottom: 7, left: 2),
  //                           child: FaIcon(
  //                             FontAwesomeIcons.sortDown,
  //                             size: 20,
  //                             color: Colors.white,
  //                           ),
  //                         ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
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
              flex: 3,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting1 == true) {
                      sorting2 = false;
                      sorting3 = false;
                      ascending1 = sorting1 ? !ascending1 : true;
                      ascending2 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = !sorting1;
                      sorting2 = false;
                      sorting3 = false;
                      ascending1 = sorting1 ? !ascending1 : true;
                      ascending2 = false;
                      ascending3 = false;
                    }

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? Text("Name",
                            style: TextStyle(color: blueColor, fontSize: 18))
                        : Text("Name",
                            style: TextStyle(color: blueColor, fontSize: 18)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                    ascending1
                        ? Padding(
                            padding: const EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 20,
                              color: blueColor,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 20,
                              color: blueColor,
                            ),
                          ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting2) {
                      sorting1 = false;
                      sorting2 = sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = !sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    }
                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    const SizedBox(width: 15),
                    Text("Phone",
                        style: TextStyle(color: blueColor, fontSize: 18)),
                    const SizedBox(width: 5),
                    ascending2
                        ? Padding(
                            padding: const EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 20,
                              color: blueColor,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 20,
                              color: blueColor,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls from `initState` only — controllers, listeners and
  /// filter defaults are not repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureRentalOwners = RentalOwnerService().fetchRentalOwners("");;
      fetchRentalOwneradded();;
    });
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
    futureRentalOwners = RentalOwnerService().fetchRentalOwners("");
    Provider.of<StaffPermissionProvider>(context, listen: false)
        .fetchPermissions();
    fetchRentalOwneradded();
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
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

  List<RentalOwnerData> _tableData = [];
  int totalrecords = 0;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<RentalOwnerData> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0; // Reset to the first page when changing rows per page
    });
  }

  void _sort<T>(Comparable<T> Function(RentalOwnerData d) getField,
      int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _tableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);

        int result;
        if (aValue is String && bValue is String) {
          result = aValue
              .toString()
              .toLowerCase()
              .compareTo(bValue.toString().toLowerCase());
        } else {
          result = aValue.compareTo(bValue as T);
        }

        return _sortAscending ? result : -result;
      });
    });
  }

  void handleEdit(RentalOwnerData rentalOwner) async {
    // Handle edit action
    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Edit_rentalowners(
                  rentalOwner: rentalOwner,
                )));
    if (check == true) {
      setState(() {});
    }
  }

  void _showDeleteAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same record.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this RentalOwner!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
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
              await RentalOwnerService()
                  .DeleteRentalOwners(rentalownerId: id, reason: reason.text);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              setState(() {
                futureRentalOwners = RentalOwnerService().fetchRentalOwners("");
              });
              fetchRentalOwneradded();
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

  void handleDelete(RentalOwnerData rental) {
    _showDeleteAlert(context, rental.rentalownerId!);
    // Handle delete action
  }

  final _scrollController = ScrollController();
  void handleTap(RentalOwnerData rental) async {
    // Handle edit action
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ResponsiveRentalSummary(
                  rentalowners: rental,
                  rentalOwnersid: '',
                )));
    /* if (result == true) {
      setState(() {
        futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
      });
    }*/
  }

  String? rentalOwnersid;
  int rentalownerCount = 0;
  int rentalOwnerCountLimit = 0;
  Future<void> fetchRentalOwneradded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/rental_owner/limitation/$adminid'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
      setState(() {
        rentalownerCount = jsonData['rentalownerCount'];
        rentalOwnerCountLimit = jsonData['rentalOwnerCountLimit'];
      });
    } else {
      throw Exception('Failed to load data');
    }
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
      ],
    ).show();
  }

  Widget _buildTableContent(BuildContext context) {
    final permissionProvider = Provider.of<StaffPermissionProvider>(context);
    StaffPermission? permissions = permissionProvider.permissions;
    Widget content = Column(
      children: [
        // Always show original design
        const SizedBox(height: 20),
        // Header Section with Title and Add Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                  child: widget.isEmbedded
                      ? Text(
                          'Manage Property Owners',
                          style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: MediaQuery.of(context).size.width < 500
                                ? 18
                                : 25,
                          ),
                        )
                      : titleBar(
                          width: double.infinity,
                          title: 'Rental Owner',
                        ),
                ),
              ),
              Flexible(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: GestureDetector(
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => const Add_rentalowners()));
                      if (result != "") {
                        setState(() {
                          futureRentalOwners =
                              RentalOwnerService().fetchRentalOwners("");
                        });
                      }
                    },
                    child: Container(
                      height:
                          (MediaQuery.of(context).size.width < 768) ? 50 : 60,
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
              if (MediaQuery.of(context).size.width < 500) SizedBox(width: 3),
              if (MediaQuery.of(context).size.width > 500) SizedBox(width: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 0, right: 0),
          child: Row(
            children: [
              if (MediaQuery.of(context).size.width < 500)
                const SizedBox(width: 2),
              if (MediaQuery.of(context).size.width > 500)
                const SizedBox(width: 19),
              Expanded(
                child: Material(
                  elevation: 0,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: (MediaQuery.of(context).size.width < 500) ? 45 : 50,
                    width: MediaQuery.of(context).size.width < 500
                        ? MediaQuery.of(context).size.width * .52
                        : MediaQuery.of(context).size.width * .49,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8A95A8)),
                    ),
                    child: TextField(
                      style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width < 500
                              ? 12
                              : 14),
                      onChanged: (value) {
                        setState(() {
                          searchValue = value;
                          if (currentPage != 0) currentPage = 0;
                        });
                      },
                      cursorColor: Colors.blue,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search here...",
                        hintStyle: TextStyle(
                            color: const Color(0xFF8A95A8),
                            fontSize: MediaQuery.of(context).size.width < 500
                                ? 14
                                : 18),
                        contentPadding: (const EdgeInsets.only(
                            left: 8, bottom: 13, top: 5)),
                      ),
                    ),
                  ),
                ),
              ),
              // Spacer(),
              // Column(
              //   mainAxisAlignment: MainAxisAlignment.end,
              //   crossAxisAlignment: CrossAxisAlignment.end,
              //   children: [
              //     Text(
              //       'Added : ${rentalownerCount.toString()} ',
              //       style: TextStyle(
              //         fontWeight: FontWeight.bold,
              //         color: Color(0xFF8A95A8),
              //         fontSize:
              //             MediaQuery.of(context).size.width < 500 ? 14 : 21,
              //       ),
              //     ),
              //     SizedBox(
              //       width: 5,
              //     ),
              //     //  Text("rentalOwnerCountLimit: ${response['rentalOwnerCountLimit']}"),
              //     Text(
              //       'Total : ${rentalOwnerCountLimit.toString()} ',
              //       style: TextStyle(
              //         fontWeight: FontWeight.bold,
              //         color: Color(0xFF8A95A8),
              //         fontSize:
              //             MediaQuery.of(context).size.width < 500 ? 14 : 21,
              //       ),
              //     ),
              //   ],
              // ),
              if (MediaQuery.of(context).size.width < 500)
                const SizedBox(width: 5),
              if (MediaQuery.of(context).size.width > 500)
                const SizedBox(width: 20),
            ],
          ),
        ),
        // if (MediaQuery.of(context).size.width > 500)
        //   const SizedBox(height: 25),
        // if (MediaQuery.of(context).size.width < 500)
        SizedBox(height: 10),
        Padding(
          padding:
              EdgeInsets.all(MediaQuery.of(context).size.width < 500 ? 0 : 0),
          child: FutureBuilder<List<RentalOwnerData>>(
            future: futureRentalOwners,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ColabShimmerLoadingWidget();
              } else if (snapshot.hasError) {
                return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                var data = snapshot.data!;
                if (searchValue == null || searchValue!.isEmpty) {
                  data = snapshot.data!;
                } else if (searchValue == "All") {
                  data = snapshot.data!;
                } else if (searchValue!.isNotEmpty) {
                  data = snapshot.data!
                      .where((rentals) =>
                          (rentals.rentalOwnername ?? '')
                              .toLowerCase()
                              .contains(searchValue!.toLowerCase()) ||
                          (rentals.rentalOwnerPhoneNumber ?? '')
                              .toLowerCase()
                              .contains(searchValue!.toLowerCase()) ||
                          (rentals.rentalOwnerPrimaryEmail ?? '')
                              .toLowerCase()
                              .contains(searchValue!.toLowerCase()))
                      .toList();
                } else {
                  data = snapshot.data!
                      .where(
                          (rentals) => rentals.rentalOwnername == searchValue)
                      .toList();
                }
                sortData(data);
                final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                final currentPageData = data
                    .skip(currentPage * itemsPerPage)
                    .take(itemsPerPage)
                    .toList();
                Widget tableContent = Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildHeaders(),
                    const SizedBox(height: 10),
                    // Filtered-empty shows once via kNoSearchResults below; the second
                    // "No Data Available" block here stacked a redundant empty state
                    // (CRM-4864 pattern). Genuinely-empty is handled by snapshot.isEmpty.
                    Container(
                      // decoration: BoxDecoration(
                      //     borderRadius: BorderRadius.circular(10),
                      //     border: Border.all(
                      //         color:
                      //         Color(0xFFDBE0E5)
                      //
                      //     )),
                      // decoration: BoxDecoration(
                      //     border: Border.all(color: blueColor)),
                      child: Column(
                        children: currentPageData.isEmpty
                            ? [kNoSearchResults(context)]
                            : currentPageData.asMap().entries.map((entry) {
                          int index = entry.key;
                          bool isExpanded = expandedIndex == index;
                          RentalOwnerData rentals = entry.value;
                          //return CustomExpansionTile(data: Propertytype, index: index);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: index % 2 != 0
                                  ? const Color(0xFFF4F8FF)
                                  : Colors.white,
                              border:
                                  Border.all(color: const Color(0xFFDBE0E5)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: <Widget>[
                                ListTile(
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
                                              if (expandedIndex == index) {
                                                expandedIndex = null;
                                              } else {
                                                expandedIndex = index;
                                              }
                                            });
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                left: 5, right: 5),
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
                                          flex: 3,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (expandedIndex == index) {
                                                  expandedIndex = null;
                                                } else {
                                                  expandedIndex = index;
                                                }
                                              });
                                            },
                                            child: Text(
                                              rentals.rentalOwnername!.isEmpty
                                                  ? 'N/A'
                                                  : '${rentals.rentalOwnername}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                .08),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            formatPhoneNumber(
                                                '${rentals.rentalOwnerPhoneNumber}'),
                                            // rentals.rentalOwnerPhoneNumber!.isEmpty ? 'N/A' :
                                            // '${rentals.rentalOwnerPhoneNumber}',
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isExpanded)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                            color: Color(0xFFDBE0E5), width: 1),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              FaIcon(
                                                isExpanded
                                                    ? FontAwesomeIcons.sortUp
                                                    : FontAwesomeIcons.sortDown,
                                                size: 40,
                                                color: Colors.transparent,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: <Widget>[
                                                    Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: 'Email : ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    blueColor), // Bold and black
                                                          ),
                                                          TextSpan(
                                                            text: rentals
                                                                    .rentalOwnerPrimaryEmail!
                                                                    .isEmpty
                                                                ? 'N/A'
                                                                : '${rentals.rentalOwnerPrimaryEmail}',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color:
                                                                    grey), // Light and grey
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .height *
                                                              .01,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: 10,
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              ResponsiveRentalSummary(
                                                                rentalOwnersid:
                                                                    rentals
                                                                        .rentalownerId!,
                                                                rentalowners:
                                                                    rentals,
                                                              )));
                                                },
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      FaIcon(
                                                        FontAwesomeIcons.eye,
                                                        size: 15,
                                                        color: Colors.black,
                                                      ),
                                                      SizedBox(width: 2),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 5,
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  var check =
                                                      await Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  Edit_rentalowners(
                                                                    rentalOwner:
                                                                        rentals,
                                                                  )));
                                                  if (check == true) {
                                                    setState(() {
                                                      futureRentalOwners =
                                                          RentalOwnerService()
                                                              .fetchRentalOwners(
                                                                  "");
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      color: Colors.green
                                                          .shade50), // color:Colors.grey[100],
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      FaIcon(
                                                        FontAwesomeIcons.edit,
                                                        size: 15,
                                                        color: Colors.green,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (permissions?.rentalownerDelete == true) ...[
                                              const SizedBox(
                                                width: 5,
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  _showDeleteAlert(context,
                                                      rentals.rentalownerId!);
                                                },
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      color:
                                                          Colors.red.shade50),
                                                  child: const Row(
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
                                                        size: 15,
                                                        color: Colors.red,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              ],
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
                    const SizedBox(height: 20),
                    if (data.length > itemsPerPage)
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: itemsPerPage,
                                      items:
                                          itemsPerPageOptions.map((int value) {
                                        return DropdownMenuItem<int>(
                                          value: value,
                                          child: Text(value.toString()),
                                        );
                                      }).toList(),
                                      onChanged: data.length >
                                              itemsPerPageOptions
                                                  .first // Condition to check if dropdown should be enabled
                                          ? (newValue) {
                                              setState(() {
                                                itemsPerPage = newValue!;
                                                currentPage =
                                                    0; // Reset to first page when items per page change
                                              });
                                            }
                                          : null,
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
                                  FontAwesomeIcons.circleChevronLeft,
                                  color: currentPage == 0
                                      ? Colors.grey
                                      : blueColor,
                                ),
                                onPressed: currentPage == 0
                                    ? null
                                    : () {
                                        setState(() {
                                          currentPage--;
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
                              Text('Page ${currentPage + 1} of $totalPages'),
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
                                  FontAwesomeIcons.circleChevronRight,
                                  color: currentPage < totalPages - 1
                                      ? blueColor
                                      : Colors.grey,
                                ),
                                onPressed: currentPage < totalPages - 1
                                    ? () {
                                        setState(() {
                                          currentPage++;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                );

                // Wrap in SingleChildScrollView only when NOT embedded
                return widget.isEmbedded
                    ? tableContent
                    : SingleChildScrollView(child: tableContent);
              }
            },
          ),
        ),
      ],
    );

    // Wrap in SingleChildScrollView only when NOT embedded (for standalone pages)
    // When embedded, return content directly - parent ListView handles scrolling
    if (widget.isEmbedded) {
      return !isOffline
          ? content
          : NoInternetView(onRetry: retryNow);
    }

    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Rental Owner",
        dropdown: true,
      ),
      body: !isOffline
          ? SingleChildScrollView(child: content)
          : NoInternetView(onRetry: retryNow),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildTableContent(context);
    }
    return _buildTableContent(context);
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(RentalOwnerData d)? getField) {
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

  Widget _buildDataCell(String text, String inkText) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: InkWell(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ResponsiveRentalSummary(
                            rentalOwnersid: inkText,
                          )));
            },
            child: Text(text, style: const TextStyle(fontSize: 18))),
      ),
    );
  }

  Widget _buildActionsCell(RentalOwnerData data) {
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    int numorpages = 1;
    numorpages = (totalrecords / _rowsPerPage).ceil();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Text('Rows per page: '),
        // SizedBox(width: 10),
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
                items: [10, 2, 5, 1].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    _changeRowsPerPage(newValue);
                  }
                },
                icon: const Icon(
                  Icons.arrow_drop_down,
                  size: 40,
                ),
                style: const TextStyle(color: Colors.black, fontSize: 17),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: FaIcon(
            size: 30,
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
          'Page ${_currentPage + 1} of $numorpages',
          style: const TextStyle(fontSize: 18),
        ),
        IconButton(
          icon: FaIcon(
            size: 30,
            FontAwesomeIcons.circleChevronRight,
            color: (_currentPage + 1) * _rowsPerPage >= _tableData.length
                ? Colors.grey
                : blueColor, // Change color based on availability
          ),
          onPressed: (_currentPage + 1) * _rowsPerPage >= _tableData.length
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
