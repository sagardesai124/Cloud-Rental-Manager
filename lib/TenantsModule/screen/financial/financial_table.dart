import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/TenantsModule/screen/financial/payment/make_payment.dart';
import 'package:three_zero_two_property/TenantsModule/screen/property/summery_page.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';

import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../constant/constant.dart';

import '../../../provider/Plan Purchase/plancheckProvider.dart';
import '../../model/tenant_financial.dart';
import '../../model/tenant_property.dart';

import '../../repository/permission_provider.dart';
import '../../repository/tenant_financial.dart';
import '../../widgets/appbar.dart';
import '../../repository/tenant_repository.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/drawer_tiles.dart';
import 'AddCard/AddCard.dart';
import 'AddAchAccount/AddAchAccount.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class FinancialTable extends StatefulWidget {
  @override
  _FinancialTableState createState() => _FinancialTableState();
}

class _FinancialTableState extends State<FinancialTable>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<List<Data>> futureFinancial;
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

  void sortData(List<Data> data) {
    /*  if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.propertyType!.compareTo(b.propertyType!)
          : b.propertyType!.compareTo(a.propertyType!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.propertysubType!.compareTo(b.propertysubType!)
          : b.propertysubType!.compareTo(a.propertysubType!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.createdAt!.compareTo(b.createdAt!)
          : b.createdAt!.compareTo(a.createdAt!));
    }*/
  }
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;
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
            /* Container(
              child: Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),*/

            Expanded(
              flex: 4,
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
                        ? Text("       Date ",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15))
                        : Text("       Date",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    SizedBox(width: 3),
                    /*ascending1
                        ? Padding(
                      padding: const EdgeInsets.only(top: 7, left: 2),
                      child: FaIcon(
                        FontAwesomeIcons.sortUp,
                        size: 20,
                        color: Colors.white,
                      ),
                    )
                        : Padding(
                      padding: const EdgeInsets.only(bottom: 7, left: 2),
                      child: FaIcon(
                        FontAwesomeIcons.sortDown,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),*/
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
                    Text(" Type",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(width: 5),
                    /* ascending2
                        ? Padding(
                      padding: const EdgeInsets.only(top: 7, left: 2),
                      child: FaIcon(
                        FontAwesomeIcons.sortUp,
                        size: 20,
                        color: Colors.white,
                      ),
                    )
                        : Padding(
                      padding: const EdgeInsets.only(bottom: 7, left: 2),
                      child: FaIcon(
                        FontAwesomeIcons.sortDown,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),*/
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting3) {
                      sorting1 = false;
                      sorting2 = false;
                      sorting3 = sorting3;
                      ascending3 = sorting3 ? !ascending3 : true;
                      ascending2 = false;
                      ascending1 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = false;
                      sorting3 = !sorting3;
                      ascending3 = sorting3 ? !ascending3 : true;
                      ascending2 = false;
                      ascending1 = false;
                    }

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    Text("  Balance",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),

                    // SizedBox(width: 5),
                    /*ascending3
                        ? Padding(
                      padding: const EdgeInsets.only(top: 7, left: 2),
                      child: FaIcon(
                        FontAwesomeIcons.sortUp,
                        size: 20,
                        color: Colors.white,
                      ),
                    )
                        : Padding(
                      padding: const EdgeInsets.only(bottom: 7, left: 2),
                      child: FaIcon(
                        FontAwesomeIcons.sortDown,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),*/
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> items = ['Residential', "Commercial", "All"];
  String? selectedValue;
  String searchvalue = "";
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // WEB PARITY (TenantFinancial.jsx): the Ledger's Add Card / Add ACH buttons
  // render for every tenant — web gates them only on the financial_add
  // permission and a non-Free plan (done in build()), never on the tenant's
  // allow_card / allow_ach flags. Those flags belong to payment-method
  // SELECTION, which Make Payment still honours (make_payment.dart
  // tenantAllowAch / tenantAllowCard, matching AddPaymentByTenant.jsx).

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureFinancial = TenantFinancialRepository().fetchTenantFinancial();;
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
    futureFinancial = TenantFinancialRepository().fetchTenantFinancial();
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

  void handleEdit(Data property) async {
    /* // Handle edit action
    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Edit_property_type(
              property: property,
            )));
    if (check == true) {
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
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this property!",
      style: AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
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
        DialogButton(
          child: Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            /* var data = TenantPropertyRepository().DeletePropertyType(id: id);
            // Add your delete logic here
            setState(() {
              futurePropertyTypes =
                  PropertyTypeRepository().fetchPropertyTypes();
            });
            Navigator.pop(context);*/
          },
          color: Colors.red,
        )
      ],
    ).show();
  }

  List<Data> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Data> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(Data d) getField, int columnIndex,
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

  void handleDelete(Data tenant) {
    // _showAlert(context, property.propertyId!);
    // // Handle delete action
    // print('Delete ${property.sId}');
  }

  // Widget _buildHeader<T>(String text, int columnIndex,
  //     Comparable<T> Function(propertytype d)? getField) {
  //   return Container(
  //     height: 70,
  //     // color: Colors.blue,
  //     child: TableCell(
  //       child: GestureDetector(
  //         onTap: getField != null
  //             ? () {
  //                 _sort(getField, columnIndex, !_sortAscending);
  //               }
  //             : null,
  //         child: Padding(
  //           padding: const EdgeInsets.all(14.0),
  //           child: Row(
  //             children: [
  //               SizedBox(width: 10),
  //               Text(text,
  //                   style:
  //                       TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
  //               if (_sortColumnIndex == columnIndex)
  //                 Icon(_sortAscending
  //                     ? Icons.arrow_drop_down_outlined
  //                     : Icons.arrow_drop_up_outlined),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildHeader<T>(
      String text, int columnIndex, Comparable<T> Function(Data d)? getField) {
    return TableCell(
      child: GestureDetector(
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

  // Widget _buildDataCell(String text) {
  //   return Padding(
  //     padding: const EdgeInsets.all(5.0),
  //     child: Container(
  //       height: 50,
  //       // color: Colors.blue,
  //       child: TableCell(
  //         child: Padding(
  //           padding: const EdgeInsets.all(10.0),
  //           child: Center(child: Text(text, style: TextStyle(fontSize: 18))),
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildDataCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  // Widget _buildActionsCell(propertytype data) {
  //   return Padding(
  //     padding: const EdgeInsets.all(5.0),
  //     child: Container(
  //       height: 50,
  //       // color: Colors.blue,
  //       child: TableCell(
  //         child: Row(
  //           children: [
  //             SizedBox(
  //               width: 20,
  //             ),
  //             GestureDetector(
  //               onTap: () {
  //                 handleEdit(data);
  //               },
  //               child: FaIcon(
  //                 FontAwesomeIcons.edit,
  //                 size: 30,
  //               ),
  //             ),
  //             SizedBox(
  //               width: 15,
  //             ),
  //             GestureDetector(
  //               onTap: () {
  //                 handleDelete(data);
  //               },
  //               child: FaIcon(
  //                 FontAwesomeIcons.trashCan,
  //                 size: 30,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }
  Widget _buildActionsCell(Data data) {
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
              GestureDetector(
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
              GestureDetector(
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
            padding: EdgeInsets.symmetric(horizontal: 12.0),
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
                icon: Icon(
                  Icons.arrow_drop_down,
                  size: 40,
                ),
                style: TextStyle(color: Colors.black, fontSize: 17),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        SizedBox(width: 10),
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
          style: TextStyle(fontSize: 18),
        ),
        IconButton(
          icon: FaIcon(
            size: 30,
            FontAwesomeIcons.circleChevronRight,
            color: (_currentPage + 1) * _rowsPerPage >= _tableData.length
                ? Colors.grey
                : Color.fromRGBO(
                    21, 43, 83, 1), // Change color based on availability
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

  final _scrollController = ScrollController();

  Widget _financialActionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    final width = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: width < 500 ? 44 : width * 0.065,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: blueColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: width > 500 ? width * 0.024 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Filters the ledger by the search text. Matches tenant name first, then
  /// type, account, memo, date, balance and amount. Used by both layouts.
  List<Data> _applyFilters(List<Data> source) {
    final q = searchvalue.trim().toLowerCase();
    if (q.isEmpty) return List<Data>.from(source);
    return source.where((d) {
      final tenantName =
          '${d.tenantData?.tenantFirstName ?? ''} ${d.tenantData?.tenantLastName ?? ''}'
              .toLowerCase();
      if (tenantName.contains(q)) return true;
      if ((d.type ?? '').toLowerCase().contains(q)) return true;
      if ((d.balance?.toString() ?? '').contains(q)) return true;
      if ((d.totalAmount?.toString() ?? '').contains(q)) return true;
      if (d.entry != null) {
        for (final e in d.entry!) {
          if ((e.account ?? '').toLowerCase().contains(q) ||
              (e.memo ?? '').toLowerCase().contains(q) ||
              (e.date ?? '').toLowerCase().contains(q)) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  Widget _noDataWidget() {
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
            SizedBox(height: 10),
            Text(
              "No Data Available",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Empty state for the mobile layout: keeps the Date/Type/Balance column
  // header visible above the "No Data Available" message.
  Widget _mobileNoData() {
    return Column(
      children: [
        const SizedBox(height: 10),
        _buildHeaders(),
        const SizedBox(height: 10),
        _noDataWidget(),
      ],
    );
  }

  Widget _buildLedgerHeader() {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: isWide ? 58 : 50,
        width: double.infinity,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
          color: blueColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(color: Colors.grey, offset: Offset(0, 1), blurRadius: 6),
          ],
        ),
        child: const Text(
          'Ledger',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: TextField(
          onChanged: (value) => setState(() {
            searchvalue = value;
            currentPage = 0;
            _currentPage = 0;
          }),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hintText: 'Search here...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon:
                Icon(Icons.search, color: blueColor.withOpacity(0.7), size: 22),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialActionsRow(BuildContext context) {
    final gap = MediaQuery.of(context).size.width < 500 ? 6.0 : 22.0;
    final buttons = <Widget>[
      _financialActionButton(
        label: "Add ACH",
        onTap: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? id = prefs.getString("tenant_id");
          if (id == null) return;
          final result = await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => AddAchAccount(tenantId: id)));
          if (result == true) {
            setState(() {
              futureFinancial =
                  TenantFinancialRepository().fetchTenantFinancial();
            });
          }
        },
      ),
      _financialActionButton(
        label: "Add Card",
        onTap: () async {
          final result = await Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => AddCard()));
          if (result == true) {
            setState(() {
              futureFinancial =
                  TenantFinancialRepository().fetchTenantFinancial();
            });
          }
        },
      ),
      _financialActionButton(
        label: "Make Payment",
        onTap: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          String? id = prefs.getString("tenant_id");
          final result = await Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => MakePayment(leaseId: '', tenantId: id!)));
          if (result == true) {
            setState(() {
              futureFinancial =
                  TenantFinancialRepository().fetchTenantFinancial();
            });
          }
        },
      ),
    ];
    return Row(
      children: [
        for (int i = 0; i < buttons.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    bool isFreePlan = Provider.of<checkPlanPurchaseProiver>(context)
            .checkplanpurchaseModel
            ?.data
            ?.planDetail
            ?.planName ==
        'Free Plan';
    final permissionProvider = Provider.of<PermissionProvider>(context);
    final permissions = permissionProvider.permissions;
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {
          key.currentState!.openDrawer();
        },
      ),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: 'Ledger',
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 16,
                  ),

                  // 1) Ledger header (top)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: _buildLedgerHeader(),
                  ),
                  SizedBox(height: 12),

                  // 2) Action buttons
                  if (!isFreePlan && permissions!.financialAdd) ...[
                    Padding(
                      padding: (MediaQuery.of(context).size.width > 500)
                          ? EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(context).size.width * 0.045)
                          : const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildFinancialActionsRow(context),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 3) Search
                  _buildSearchBar(),
                  SizedBox(height: 6),

                  if (MediaQuery.of(context).size.width > 500)
                    SizedBox(height: 25),
                  if (MediaQuery.of(context).size.width < 500)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: FutureBuilder<List<Data>>(
                        future: futureFinancial,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              margin: const EdgeInsets.only(top: 20.0),
                              child: ColabShimmerLoadingWidget(),
                            );
                          } else if (!snapshot.hasData ||
                              snapshot.data!.isEmpty) {
                            return _mobileNoData();
                          } else {
                            var data = _applyFilters(snapshot.data!);
                            if (data.length == 0) {
                              return _mobileNoData();
                            }
                            //sortData(data);
                            //  print(data);
                            //   print(snapshot.data!.first.totalBalance);
                            final totalPages =
                                (data.length / itemsPerPage).ceil();
                            final currentPageData = data
                                .skip(currentPage * itemsPerPage)
                                .take(itemsPerPage)
                                .toList();
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  SizedBox(height: 10),
                                  _buildHeaders(),
                                  SizedBox(height: 10),
                                  Container(
                                    child: Column(
                                      children: currentPageData
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        int index = entry.key;
                                        bool isExpanded =
                                            expandedIndex == index;
                                        Data Tenant_financial = entry.value;
                                        // A ledger row can arrive with no
                                        // `entry` array at all (the model only
                                        // fills it when the key is present), an
                                        // empty one, or entries with no
                                        // account. The old code null-asserted
                                        // both and then trimmed two characters
                                        // off the result, so any of the three
                                        // took the whole tab down.
                                        final String accounts =
                                            (Tenant_financial.entry ?? [])
                                                .map((e) => e.account ?? '')
                                                .where((a) => a.isNotEmpty)
                                                .join(', ');

                                        //print(Tenant_financial.totalBalance);
                                        //return CustomExpansionTile(data: Propertytype, index: index);
                                        return GestureDetector(
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
                                                        GestureDetector(
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
                                                                EdgeInsets.only(
                                                                    left: 5,
                                                                    right: 5),
                                                            padding: !isExpanded
                                                                ? EdgeInsets
                                                                    .only(
                                                                        bottom:
                                                                            10)
                                                                : EdgeInsets
                                                                    .only(
                                                                        top:
                                                                            10),
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
                                                          flex: 3,
                                                          child: Text(
                                                            // `?.first` guards a
                                                            // null list but not
                                                            // an empty one, which
                                                            // still threw here.
                                                            (Tenant_financial.entry
                                                                            ?.isNotEmpty ??
                                                                        false) &&
                                                                    (Tenant_financial
                                                                            .entry!
                                                                            .first
                                                                            .date
                                                                            ?.isNotEmpty ??
                                                                        false)
                                                                ? dateProvider
                                                                    .formatCurrentDate(
                                                                        '${Tenant_financial.entry!.first.date}')
                                                                : 'N/A',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                            width: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .02),
                                                        Expanded(
                                                          flex: 2,
                                                          child: Text(
                                                            '${Tenant_financial.type}',
                                                            textAlign:
                                                                TextAlign.left,
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                            width: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .03),
                                                        Expanded(
                                                          flex: 2,
                                                          // right align the text
                                                          child: Align(
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: Text(
                                                              // Shared helper
                                                              // (constant.dart
                                                              // formatMoney-
                                                              // Accounting):
                                                              // grouped en-US
                                                              // currency, with
                                                              // a credit shown
                                                              // as ($1,234.56).
                                                              formatMoneyAccounting(
                                                                  Tenant_financial
                                                                      .balance!),
                                                              style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                            width: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .04),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (isExpanded)
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 8.0),
                                                    margin: EdgeInsets.only(
                                                        bottom: 20),
                                                    child:
                                                        SingleChildScrollView(
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
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
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: <Widget>[
                                                                    Text.rich(
                                                                      TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                'Tenant : ',
                                                                            style:
                                                                                TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                          ),
                                                                          TextSpan(
                                                                            text:
                                                                                ' ${Tenant_financial.tenantData != null ? '${Tenant_financial.tenantData?.tenantFirstName} ${Tenant_financial.tenantData?.tenantLastName}' : 'N/A'}',
                                                                            style:
                                                                                TextStyle(fontWeight: FontWeight.w700, color: grey), // Light and grey
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text.rich(
                                                                      TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                'Transaction : ',
                                                                            style:
                                                                                TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                          ),
                                                                          TextSpan(
                                                                            text:
                                                                                '${Tenant_financial.type == 'Payment' ? 'Manual ${Tenant_financial.type} ${Tenant_financial.response} For ${Tenant_financial.paymentType}' : '${accounts}'}',
                                                                            style:
                                                                                TextStyle(fontWeight: FontWeight.w700, color: grey), // Light and grey
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Text.rich(
                                                                      TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                'Account : ',
                                                                            style:
                                                                                TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                          ),
                                                                          TextSpan(
                                                                            text:
                                                                                '${accounts}',
                                                                            style:
                                                                                TextStyle(fontWeight: FontWeight.w700, color: grey), // Light and grey
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Text.rich(
                                                                          TextSpan(
                                                                            children: [
                                                                              TextSpan(
                                                                                text: 'Amount : ',
                                                                                style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                              ),
                                                                              TextSpan(
                                                                                text: Tenant_financial.type == 'Refund' || Tenant_financial.type == 'Charge' ? formatMoney(Tenant_financial.totalAmount!.abs()) : ' - ${formatMoney(Tenant_financial.totalAmount!.abs())}',
                                                                                style: TextStyle(fontWeight: FontWeight.w700, color: grey), // Light and grey
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              25,
                                                                        ),
                                                                        /*  Text.rich(
                                                                    TextSpan(
                                                                      children: [
                                                                        TextSpan(
                                                                          text:
                                                                          'Decrease : ',
                                                                          style: TextStyle(
                                                                              fontWeight:
                                                                              FontWeight
                                                                                  .bold,
                                                                              color:
                                                                              blueColor), // Bold and black
                                                                        ),
                                                                        TextSpan(
                                                                          text: Tenant_financial.type != 'Refund' ? ' ${Tenant_financial.totalAmount}' : ' N/A',
                                                                          style: TextStyle(
                                                                              fontWeight:
                                                                              FontWeight
                                                                                  .w700,
                                                                              color:grey), // Light and grey
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),*/
                                                                      ],
                                                                    ),
                                                                    SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                    /* Text.rich(
                                                                TextSpan(
                                                                  children: [
                                                                    TextSpan(
                                                                      text:
                                                                      'Balance : ',
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                          color:
                                                                          blueColor), // Bold and black
                                                                    ),
                                                                    TextSpan(
                                                                      text: '${Tenant_financial.balance?.abs()}',
                                                                      style: TextStyle(
                                                                          fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                          color: grey), // Light and grey
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),*/
                                                                    SizedBox(
                                                                      height: 5,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              // SizedBox(width: 5),
                                                              // Expanded(
                                                              //   child: Column(
                                                              //     crossAxisAlignment:
                                                              //     CrossAxisAlignment.start,
                                                              //     children: <Widget>[
                                                              //       Text.rich(
                                                              //         TextSpan(
                                                              //           children: [
                                                              //             TextSpan(
                                                              //               text:
                                                              //               'Increase: ',
                                                              //               style: TextStyle(
                                                              //                   fontWeight:
                                                              //                   FontWeight
                                                              //                       .bold,
                                                              //                   color:
                                                              //                   blueColor), // Bold and black
                                                              //             ),
                                                              //             TextSpan(
                                                              //               text: '',
                                                              //               style: TextStyle(
                                                              //                   fontWeight:
                                                              //                   FontWeight
                                                              //                       .w700,
                                                              //                   color: Colors
                                                              //                       .grey), // Light and grey
                                                              //             ),
                                                              //           ],
                                                              //         ),
                                                              //       ),
                                                              //       Text.rich(
                                                              //         TextSpan(
                                                              //           children: [
                                                              //             TextSpan(
                                                              //               text:
                                                              //               'Balance : ',
                                                              //               style: TextStyle(
                                                              //                   fontWeight:
                                                              //                   FontWeight
                                                              //                       .bold,
                                                              //                   color:
                                                              //                   blueColor), // Bold and black
                                                              //             ),
                                                              //             TextSpan(
                                                              //               text: '${Tenant_financial.balance}',
                                                              //               style: TextStyle(
                                                              //                   fontWeight:
                                                              //                   FontWeight
                                                              //                       .w700,
                                                              //                   color: Colors
                                                              //                       .grey), // Light and grey
                                                              //             ),
                                                              //           ],
                                                              //         ),
                                                              //       ),
                                                              //
                                                              //     ],
                                                              //   ),
                                                              // ),
                                                              /*Container(
                                                          width: 40,
                                                          child: Column(
                                                            children: [
                                                              IconButton(
                                                                icon: FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 20,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      83,
                                                                      1),
                                                                ),
                                                                onPressed:
                                                                    () async {
                                                                  // handleEdit(Propertytype);
                                    
                                                                  // var check = await Navigator.push(
                                                                  //     context,
                                                                  //     MaterialPageRoute(
                                                                  //         builder: (context) => Edit_property_type(
                                                                  //           property: Propertytype,
                                                                  //         )));
                                                                  // if (check ==
                                                                  //     true) {
                                                                  //   setState(
                                                                  //           () {});
                                                                  // }
                                                                },
                                                              ),
                                                              IconButton(
                                                                icon: FaIcon(
                                                                  FontAwesomeIcons
                                                                      .trashCan,
                                                                  size: 20,
                                                                  color: Color
                                                                      .fromRGBO(
                                                                      21,
                                                                      43,
                                                                      83,
                                                                      1),
                                                                ),
                                                                onPressed: () {
                                                                  //handleDelete(Propertytype);
                                                                  // _showAlert(
                                                                  //     context,
                                                                  //     Propertytype
                                                                  //         .propertyId!);
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),*/
                                                            ],
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
                                  SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          // Text('Rows per page:'),
                                          SizedBox(width: 10),
                                          Material(
                                            elevation: 3,
                                            child: Container(
                                              height: 40,
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12.0),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.grey),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton<int>(
                                                  value: itemsPerPage,
                                                  items: itemsPerPageOptions
                                                      .map((int value) {
                                                    return DropdownMenuItem<
                                                        int>(
                                                      value: value,
                                                      child: Text(
                                                          value.toString()),
                                                    );
                                                  }).toList(),
                                                  onChanged: data.length >
                                                          itemsPerPageOptions
                                                              .first // Condition to check if dropdown should be enabled
                                                      ? (newValue) {
                                                          setState(() {
                                                            itemsPerPage =
                                                                newValue!;
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
                                              FontAwesomeIcons
                                                  .circleChevronLeft,
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
                                          Text(
                                              'Page ${currentPage + 1} of $totalPages'),
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
                                              color:
                                                  currentPage < totalPages - 1
                                                      ? blueColor
                                                      : Colors.grey,
                                            ),
                                            onPressed:
                                                currentPage < totalPages - 1
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
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  if (MediaQuery.of(context).size.width > 500)
                    FutureBuilder<List<Data>>(
                      future: futureFinancial,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: SpinKitFadingCircle(
                              color: Colors.black,
                              size: 55.0,
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return _noDataWidget();
                        } else {
                          //  _tableData = snapshot.data!;
                          //var data = snapshot.data!;
                          _tableData = _applyFilters(snapshot.data!);
                          if (_tableData.isEmpty) return _noDataWidget();
                          String formattedText =
                              'Manual ${snapshot.data!.first.type} ${snapshot.data!.first.response} For ${snapshot.data!.first.paymentType}';
                          String increase =
                              snapshot.data?.first.type == 'Refund'
                                  ? '${snapshot.data?.first.totalAmount}'
                                  : 'N/A';
                          String decrease =
                              snapshot.data?.first.type != 'Refund'
                                  ? '${snapshot.data?.first.totalAmount}'
                                  : 'N/A';

                          totalrecords = _tableData.length;
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                Container(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20.0, vertical: 5),
                                    child: Column(
                                      children: [
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Container(
                                            padding:
                                                const EdgeInsets.only(left: 2),
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.91,
                                            child: Column(
                                              children: [
                                                // Header Row with Mobile-like Styling
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Color(0xFFF4F8FF),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                    border: Border.all(
                                                        color:
                                                            Color(0xFFDBE0E5)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Text(
                                                            'Date',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Text(
                                                            'Type',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Text(
                                                            'Account',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Text(
                                                            'Transaction',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Text(
                                                            'Increase',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Text(
                                                            'Decrease',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 20),
                                                          child: Align(
                                                            alignment: Alignment
                                                                .centerRight,
                                                            child: Text(
                                                              'Balance',
                                                              style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 15,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                SizedBox(
                                                    height:
                                                        10), // Space between header and first data row
                                                // Data Rows with Mobile-like Styling
                                                for (var i = 0;
                                                    i < _pagedData.length;
                                                    i++)
                                                  Column(
                                                    children: [
                                                      Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: i % 2 != 0
                                                              ? Color(
                                                                  0xFFF4F8FF)
                                                              : Colors.white,
                                                          border: Border.all(
                                                              color: Color(
                                                                  0xFFDBE0E5)),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Text(
                                                                  // `.first` on an
                                                                  // empty entry list
                                                                  // threw even when
                                                                  // the list itself
                                                                  // was present.
                                                                  (_pagedData[i].entry ??
                                                                              [])
                                                                          .isEmpty
                                                                      ? ''
                                                                      : (_pagedData[i]
                                                                              .entry!
                                                                              .first
                                                                              .date ??
                                                                          ''),
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Text(
                                                                  _pagedData[i]
                                                                      .type!,
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Text(
                                                                  (_pagedData[i].entry ??
                                                                              [])
                                                                          .isEmpty
                                                                      ? ''
                                                                      : (_pagedData[i]
                                                                              .entry!
                                                                              .first
                                                                              .account ??
                                                                          ''),
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Text(
                                                                  'Manual ${_pagedData[i].type} ${_pagedData[i].response} For ${_pagedData[i].paymentType}',
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Text(
                                                                  _pagedData[i]
                                                                              .type !=
                                                                          'Refund'
                                                                      ? '${_pagedData[i].totalAmount}'
                                                                      : 'N/A',
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Text(
                                                                  _pagedData[i]
                                                                              .type ==
                                                                          'Refund'
                                                                      ? '${_pagedData[i].totalAmount}'
                                                                      : 'N/A',
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                        horizontal:
                                                                            16,
                                                                        vertical:
                                                                            20),
                                                                child: Align(
                                                                  alignment:
                                                                      Alignment
                                                                          .centerRight,
                                                                  child: Text(
                                                                    _pagedData[i].balance !=
                                                                            null
                                                                        ? formatMoneyAccounting(
                                                                            _pagedData[i]
                                                                                .balance!)
                                                                        : 'N/A',
                                                                    style:
                                                                        TextStyle(
                                                                      color:
                                                                          blueColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            // Expanded(
                                                            //   child: Container(
                                                            //     padding: EdgeInsets
                                                            //         .symmetric(
                                                            //             horizontal:
                                                            //                 16,
                                                            //             vertical:
                                                            //                 20),
                                                            //     child: Row(
                                                            //       children: [
                                                            //         GestureDetector(
                                                            //           onTap:
                                                            //               () {
                                                            //             handleEdit(
                                                            //                 _pagedData[i]);
                                                            //           },
                                                            //           child:
                                                            //               FaIcon(
                                                            //             FontAwesomeIcons
                                                            //                 .edit,
                                                            //             size:
                                                            //                 20,
                                                            //             color:
                                                            //                 blueColor,
                                                            //           ),
                                                            //         ),
                                                            //         SizedBox(
                                                            //             width:
                                                            //                 15),
                                                            //         GestureDetector(
                                                            //           onTap:
                                                            //               () {
                                                            //             handleDelete(
                                                            //                 _pagedData[i]);
                                                            //           },
                                                            //           child:
                                                            //               FaIcon(
                                                            //             FontAwesomeIcons
                                                            //                 .trashCan,
                                                            //             size:
                                                            //                 20,
                                                            //             color:
                                                            //                 blueColor,
                                                            //           ),
                                                            //         ),
                                                            //       ],
                                                            //     ),
                                                            //   ),
                                                            // ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (i <
                                                          _pagedData.length - 1)
                                                        SizedBox(
                                                            height:
                                                                10), // Space between data rows
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 25),
                                        _buildPaginationControls(),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 25),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}

void main() => runApp(MaterialApp(home: FinancialTable()));
