import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import '../../../model/staffpermission.dart';
import '../../../repository/staffpermission_provider.dart';
import '../../../widgets/appbar.dart';
import '../../../../Model/vendor.dart';
import '../../../../constant/constant.dart';
import '../../../repository/vendor_repository.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../../widgets/titleBar.dart';
import 'add_vendor.dart';
import 'edit_vendor.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../../widgets/custom_drawer.dart';
import '../../../../Model/All_categories_model.dart';
import '../../../../repository/fetch_allcategories.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class Vendor_table extends StatefulWidget {
  final bool
      isEmbedded; // When true, shows only table content without Scaffold/AppBar/Drawer

  const Vendor_table({super.key, this.isEmbedded = false});

  @override
  State<Vendor_table> createState() => _Vendor_tableState();
}

class _Vendor_tableState extends State<Vendor_table>
    with NetworkRetryState {
  String searchvalue = "";
  int totalrecords = 0;
  late Future<List<Vendor>> futurePropertyTypes;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [
    10,
    25,
    50,
    100,
  ]; // Options for items per page

  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;

  void sortData(List<Vendor> data) {
    if (sorting1) {
      data.sort((a, b) => ascending1
          ? (a.vendorName ?? '').toLowerCase().compareTo((b.vendorName ?? '').toLowerCase())
          : (b.vendorName ?? '').toLowerCase().compareTo((a.vendorName ?? '').toLowerCase()));
    } else if (sorting2) {
      // Was previously safe only because vendorPhoneNumber could never be
      // null (a missing phone came through as the literal string "null").
      // Now that the model yields a real null for a missing phone, sorting
      // a list with any such vendor by phone would throw on the `!`.
      data.sort((a, b) => ascending2
          ? (a.vendorPhoneNumber ?? '').compareTo(b.vendorPhoneNumber ?? '')
          : (b.vendorPhoneNumber ?? '').compareTo(a.vendorPhoneNumber ?? ''));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? (a.vendorName ?? '').toLowerCase().compareTo((b.vendorName ?? '').toLowerCase())
          : (b.vendorName ?? '').toLowerCase().compareTo((a.vendorName ?? '').toLowerCase()));
    }
  }

  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  bool sorting1 = true; // Default: sort by name
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = true; // Default: ascending order
  bool ascending2 = false;
  bool ascending3 = false;
  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
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
                        ? Text("Name ",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Name",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                    sorting1
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 20,
                              color: blueColor,
                            ),
                          )
                        : const SizedBox.shrink(),
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
                    Text("  Phone  Number",
                        style: TextStyle(
                            color: blueColor, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    Padding(
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
            // Expanded(
            //   flex: 2,
            //   child: InkWell(
            //     onTap: () {
            //       setState(() {
            //         if (sorting3) {
            //           sorting1 = false;
            //           sorting2 = false;
            //           sorting3 = sorting3;
            //           ascending3 = sorting3 ? !ascending3 : true;
            //           ascending2 = false;
            //           ascending1 = false;
            //         } else {
            //           sorting1 = false;
            //           sorting2 = false;
            //           sorting3 = !sorting3;
            //           ascending3 = sorting3 ? !ascending3 : true;
            //           ascending2 = false;
            //           ascending1 = false;
            //         }
            //
            //         // Sorting logic here
            //       });
            //     },
            //     child: Row(
            //       children: [
            //         Text("Action", style: TextStyle(color: Colors.white)),
            //         /* SizedBox(width: 5),
            //         ascending3
            //             ? Padding(
            //           padding: const EdgeInsets.only(top: 7, left: 2),
            //           child: FaIcon(
            //             FontAwesomeIcons.sortUp,
            //             size: 20,
            //             color: Colors.white,
            //           ),
            //         )
            //             : Padding(
            //           padding: const EdgeInsets.only(bottom: 7, left: 2),
            //           child: FaIcon(
            //             FontAwesomeIcons.sortDown,
            //             size: 20,
            //             color: Colors.white,
            //           ),
            //         ),*/
            //       ],
            //     ),
            //   ),
            // ),
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
      futurePropertyTypes = VendorRepository(baseUrl: '').getVendors();
    });
    fetchvendoradded();
    _loadDropdownCategories();
  }

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
    futurePropertyTypes = VendorRepository(baseUrl: '').getVendors();
    Provider.of<StaffPermissionProvider>(context, listen: false)
        .fetchPermissions();
    fetchvendoradded();
    _loadDropdownCategories();
  }

  Future<void> _loadDropdownCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      // Sort categories alphabetically by name
      cats.sort((a, b) {
        final nameA = (a.name ?? '').toLowerCase();
        final nameB = (b.name ?? '').toLowerCase();
        return nameA.compareTo(nameB);
      });
      setState(() {
        _dropdownCategories = cats;
        _isLoadingCategories = false;
      });
    } catch (e) {
      logError('Error fetching categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
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

  void handleEdit(Vendor property) async {
    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => edit_vendor(
                  vender_id: property.vendorId,
                )));
    if (check == true) {
      setState(() {});
    }
    // Handle edit action
    //print('Edit ${property.sId}');
    /* var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Edit_property_type(
              property: property,
            )));*/
    /* if (check == true) {
      setState(() {});
    }*/
    // final result = await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => Edit_property_type(
    //               property: property,
    //             )));
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
      desc: "Once deleted, you will not be able to recover this vendor!",
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
              var data = await VendorRepository(baseUrl: '')
                  .DeleteVender(vender_id: id, reason: reason.text)
                  .then((value) {
                if (!mounted) return;
                // Only refresh when the delete actually succeeded.
                setState(() {
                  futurePropertyTypes =
                      VendorRepository(baseUrl: '').getVendors();
                });
                fetchvendoradded();
              });
              // Add your delete logic here

              if (!mounted) return;
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

  List<Vendor> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Vendor> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(Vendor d) getField, int columnIndex,
      bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _tableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        final result = aValue.compareTo(bValue as T);
        return _sortAscending ? result : -result;
      });
    });
  }

  Widget _buildDataCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(Vendor d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField, columnIndex, !_sortAscending);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
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
    );
  }

  void handleDelete(Vendor property) {
    _showAlert(context, property.vendorId!);
    // Handle delete action
  }

  Widget _buildActionsCell(Vendor data) {
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
                items: [10, 25, 50, 100].map((int value) {
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
            FontAwesomeIcons.circleChevronLeft,
            size: 30,
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

  int vendorCountLimit = 0;
  int vendorCount = 0;

  Future<void> fetchvendoradded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await http
        .get(Uri.parse('${Api_url}/api/vendor/limitation/$adminid'), headers: {
      "authorization": "CRM $token",
      "id": "CRM $id",
    });
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
      setState(() {
        vendorCount = jsonData['vendorCount'];
        vendorCountLimit = jsonData['vendorCountLimit'];
      });
    } else {
      throw Exception('Failed to load data the count');
    }
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
          padding: EdgeInsets.symmetric(
            horizontal: widget.isEmbedded ? 0 : 18,
            vertical: 0,
          ),
          child: Row(
            children: [
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width > 500)
                SizedBox(
                  width: 13,
                ),
              Expanded(
                flex: permissions!.vendorAdd! ? 3 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: widget.isEmbedded
                      ? Text(
                          'Manage Vendors',
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
                          title: 'Vendors',
                        ),
                ),
              ),
              if (permissions!.vendorAdd!)
                Flexible(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: () async {
                        final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const Add_vendor()));
                        if (result == true) {
                          setState(() {
                            futurePropertyTypes =
                                VendorRepository(baseUrl: '').getVendors();
                          });
                          // The header count comes from its own request, so
                          // refreshing only the list left the total stale
                          // until the screen was rebuilt from scratch.
                          fetchvendoradded();
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
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width < 500)
                SizedBox(width: 3),
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width > 500)
                SizedBox(width: 18),
            ],
          ),
        ),
        const SizedBox(height: 20),
        //search
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isEmbedded ? 0 : 18,
          ),
          child: Row(
            children: [
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width < 500)
                const SizedBox(width: 2),
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width > 500)
                const SizedBox(width: 18),
              Expanded(
                child: Material(
                  elevation: 0,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8A95A8))),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TextField(
                            style: TextStyle(
                                fontSize: MediaQuery.of(context).size.width < 500
                                    ? 12
                                    : 14),
                            onChanged: (value) {
                              setState(() {
                                searchvalue = value;
                                if (currentPage != 0) currentPage = 0;
                              });
                            },
                            cursorColor: blueColor,
                            decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Search here...",
                                hintStyle: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 500
                                          ? 14
                                          : 18,
                                  color: const Color(0xFF8A95A8),
                                ),
                                contentPadding: const EdgeInsets.only(
                                    left: 5, bottom: 10, top: 4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.isEmbedded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    elevation: 0,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF8A95A8)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton2<allcategories_model>(
                          isExpanded: true,
                          hint: Text(
                            'Filter by Trade Type',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 12
                                  : 14,
                              color: const Color(0xFF8A95A8),
                            ),
                          ),
                          items: [
                            DropdownMenuItem<allcategories_model>(
                              value: null,
                              child: Text(
                                'All Trade Types',
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 500
                                          ? 12
                                          : 14,
                                  color: const Color(0xFF8A95A8),
                                ),
                              ),
                            ),
                            ..._dropdownCategories
                                .map((allcategories_model item) {
                              return DropdownMenuItem<allcategories_model>(
                                value: item,
                                child: Text(
                                  item.name ?? '',
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width < 500
                                            ? 12
                                            : 14,
                                    color: Colors.black, // Selected item color
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                          value: _selectedDropdownCategory,
                          onChanged: (allcategories_model? value) {
                            setState(() {
                              _selectedDropdownCategory = value;
                              currentPage = 0;
                            });
                          },
                          buttonStyleData: const ButtonStyleData(
                            padding: EdgeInsets.zero,
                          ),
                          menuItemStyleData: const MenuItemStyleData(
                            height: 40,
                          ),
                          dropdownStyleData: DropdownStyleData(
                            maxHeight: 200,
                            width: MediaQuery.of(context).size.width < 500
                                ? MediaQuery.of(context).size.width * .5
                                : 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width < 500)
                const SizedBox(width: 5),
              if (widget.isEmbedded &&
                  MediaQuery.of(context).size.width > 500)
                const SizedBox(width: 25),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 18, right: 18),
          child: Align(
            alignment: Alignment.centerRight,
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Added : ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2332))),
                  TextSpan(text: '$vendorCount', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2332))),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isEmbedded ? 0 : 18,
          ),
          child: FutureBuilder<List<Vendor>>(
            future: futurePropertyTypes,
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
                if (searchvalue != "") {
                  data = snapshot.data!
                      .where((property) =>
                          (property.vendorName ?? '')
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()) ||
                          (property.vendorPhoneNumber ?? '')
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()) ||
                          (property.vendorEmail ?? '')
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()))
                      .toList();
                }
                if (_selectedDropdownCategory != null) {
                  data = data
                      .where((property) =>
                          property.trade?.toLowerCase() ==
                          _selectedDropdownCategory!.name?.toLowerCase())
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
                    if (data.isEmpty)
                      Container(
                        height: MediaQuery.of(context).size.height * .35,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                "assets/images/no_data.jpg",
                                height: 200,
                                width: 200,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No Data Available",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: blueColor,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Container(
                      child: Column(
                        children: currentPageData.isEmpty
                            ? [kNoSearchResults(context)]
                            : currentPageData.asMap().entries.map((entry) {
                          int index = entry.key;
                          bool isExpanded = expandedIndex == index;
                          Vendor Propertytype = entry.value;
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
                                            setState(() {
                                              if (expandedIndex == index) {
                                                expandedIndex = null;
                                              } else {
                                                expandedIndex = index;
                                              }
                                            });
                                          },
                                          child: Container(
                                            margin:
                                                const EdgeInsets.only(left: 5),
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
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: Text(
                                                '${Propertytype.vendorName}',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
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
                                          child: Text(
                                            // Interpolating a null value here
                                            // directly reproduces the same
                                            // "null"-as-text bug this file's
                                            // vendorPhoneNumber sort/search
                                            // sites were just fixed for — an
                                            // empty string lets
                                            // formatPhoneNumber's own isEmpty
                                            // check return "N/A" instead.
                                            formatPhoneNumber(
                                                Propertytype.vendorPhoneNumber ??
                                                    ''),
                                            // '${Propertytype.vendorPhoneNumber}',
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
                                        horizontal: 2.0),
                                    margin: const EdgeInsets.only(bottom: 2),
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
                                                size: 50,
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
                                                            text:
                                                                '${Propertytype.vendorEmail}',
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
                                                    if (!widget.isEmbedded) ...[
                                                      const SizedBox(
                                                          height: 5),
                                                      Text.rich(
                                                        TextSpan(
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  'Trade Type : ',
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      blueColor),
                                                            ),
                                                            TextSpan(
                                                              // Web parity (Vendor.jsx): getTradeLabel(vendor.trade)
                                                              // || "---". Capitalising only the first letter showed
                                                              // the stored "hvac" as "Hvac" instead of "HVAC".
                                                              text: vendorTradeLabel(Propertytype.trade).isEmpty
                                                                  ? '---'
                                                                  : vendorTradeLabel(Propertytype.trade),
                                                              style: TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: grey),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                            height: 10,
                                          ),
                                          Row(
                                            //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              if (permissions!.vendorEdit!)
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () async {
                                                      var check =
                                                          await Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                  builder:
                                                                      (context) =>
                                                                          edit_vendor(
                                                                            vender_id:
                                                                                Propertytype.vendorId,
                                                                          )));
                                                      if (check == true) {
                                                        setState(() {
                                                          futurePropertyTypes =
                                                              VendorRepository(
                                                                      baseUrl:
                                                                          '')
                                                                  .getVendors();
                                                        });
                                                      }
                                                    },
                                                    child: Container(
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            color: Colors.green,
                                                            width: 1.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ), // color:Colors.grey[100],
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
                                                                .edit,
                                                            size: 15,
                                                            color: Colors.green,
                                                          ),
                                                          SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            "Edit",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .green,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (permissions!.vendorEdit!)
                                                const SizedBox(
                                                  width: 5,
                                                ),
                                              if (permissions!.vendorDelete!)
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      _showAlert(
                                                          context,
                                                          Propertytype
                                                              .vendorId!);
                                                    },
                                                    child: Container(
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        border: Border.all(
                                                            color: Colors.red,
                                                            width: 1.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
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
                                                            FontAwesomeIcons
                                                                .trashCan,
                                                            size: 15,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(
                                                            width: 10,
                                                          ),
                                                          Text(
                                                            "Delete",
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          )
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (totalPages > 1) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
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
                                    items: itemsPerPageOptions.map((int value) {
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
                                color:
                                    currentPage == 0 ? Colors.grey : blueColor,
                              ),
                              onPressed: currentPage == 0
                                  ? null
                                  : () {
                                      setState(() {
                                        currentPage--;
                                      });
                                    },
                            ),
                            Text('Page ${currentPage + 1} of $totalPages'),
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
        currentpage: "Vendors",
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
}
