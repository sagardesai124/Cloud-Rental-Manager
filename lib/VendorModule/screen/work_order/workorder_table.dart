import 'package:three_zero_two_property/services/app_log.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../constant/constant.dart';

import '../../../widgets/CustomTableShimmer.dart';
import '../../model/tenant_financial.dart';
import '../../model/tenant_property.dart';

import '../../repository/tenant_financial.dart';
import '../../repository/workorder.dart';
import '../../widgets/appbar.dart';
import '../../repository/tenant_repository.dart';
import '../../widgets/drawer_tiles.dart';
import 'add_workorder.dart';
import '../../model/workorder_model.dart';
import '../work_order/workorder_summery.dart';
import '../work_order/Edit_workorders.dart';

class WorkOrderTable extends StatefulWidget {
  String? filter;
  WorkOrderTable({this.filter});
  @override
  _WorkOrderTableState createState() => _WorkOrderTableState();
}

class _WorkOrderTableState extends State<WorkOrderTable>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<List<WorkOrder>> futureworkorder;
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

  void sortData(List<WorkOrder> data) {
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
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
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
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ?  Text("Work Order ",
                            style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14))
                        :  Text("Work Order",
                            style: TextStyle(color: blueColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
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
                  });
                },
                child:  Row(
                  children: [
                    Text("Ticket #",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    SizedBox(width: 5),
                  ],
                ),
              ),
            ),
          ],  
        ),
      ),
    );
  }

  TableRow _buildTableRow(String leftLabel, String leftValue,
      String rightLabel, String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 13),
                ),
                const SizedBox(height: 2.0),
                Text(
                  leftValue.isEmpty ? 'N/A' : leftValue,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.only(left: 31,bottom: 4),
            child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rightLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 13),
                ),
                const SizedBox(height: 2.0),
                Text(
                  rightValue.isEmpty ? 'N/A' : rightValue,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }

  final List<String> items = [
    'New',
    "In Progress",
    "On Hold",
    "Completed",
    "Over Due",
    'Closed',
    "All"
  ];
  String? selectedValue;
  String searchvalue = "";
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The work-order fetch only; the filter selectedValue is left as the user
  /// set it, so a reload does not reset their view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureworkorder = WorkOrderRepository().fetchWorkOrders();
    });
  }

  @override
  void initState() {
    super.initState();
    futureworkorder = WorkOrderRepository().fetchWorkOrders();
    selectedValue = widget.filter;
    futureworkorder.then((workOrders) {
      printRentalData(workOrders);
    });
  }

  void handleEdit(WorkOrder property) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Edit_Workorder(workorderId: property.workOrderId!),
      ),
    );
    if (result == true) {
      setState(() {
        futureworkorder = WorkOrderRepository().fetchWorkOrders();
      });
    }
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

  List<WorkOrder> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<WorkOrder> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(WorkOrder d) getField, int columnIndex,
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

  void handleDelete(WorkOrder tenant) {
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
  //       child: InkWell(
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
  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(WorkOrder d)? getField) {
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                      fontSize: 18)),
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
  Widget _buildDataCell(String text, String id) {
    return TableCell(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => Workorder_summery(
                    workorder_id: id,
                  )));
        },
        child: Container(
          height: 60,
          padding: const EdgeInsets.only(top: 20.0, left: 16),
          child: Text(text, style: TextStyle(fontSize: 18, color: blueColor)),
        ),
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
  //             InkWell(
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
  //             InkWell(
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
  Widget _buildActionsCell(WorkOrder data) {
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
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {
          key.currentState!.openDrawer();
        },
      ),
      backgroundColor: Colors.white,
      // Gated here, not on the tab shell — see the note in the vendor
      // dashboard: blocking on the shell removed the app bar and with it the
      // only request that could report recovery.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: 20,
            ),
            /* //add propertytype
            Padding(
              padding: const EdgeInsets.only(left: 13, right: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) => Add_Workorder()));
                      if (result == true) {
                        setState(() {
                          futureworkorder =
                          WorkOrderRepository().fetchWorkOrders();
                        });
                      }
                    },
                    child: Container(
                      height: (MediaQuery.of(context).size.width < 500)
                          ? 40
                          : MediaQuery.of(context).size.width * 0.065,

                      // height:  MediaQuery.of(context).size.width * 0.07,
                      // height:  40,
                      width: MediaQuery.of(context).size.width * 0.4,
                      decoration: BoxDecoration(
                        color: blueColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Add Work Order",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize:
                                MediaQuery.of(context).size.width * 0.034,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (MediaQuery.of(context).size.width < 500)
                    SizedBox(width: 6),
                  if (MediaQuery.of(context).size.width > 500)
                    SizedBox(width: 22),
                ],
              ),
            ),
            SizedBox(height: 10),*/
            titleBar(
              width: MediaQuery.of(context).size.width > 500
                  ? MediaQuery.of(context).size.width * .88
                  : MediaQuery.of(context).size.width * .91,
              title: 'Work Orders',
            ),
            SizedBox(height: 15),
            //search

            Padding(
              padding: const EdgeInsets.only(left: 13, right: 13),
              child: Row(
                children: [
                  if (MediaQuery.of(context).size.width < 500)
                    SizedBox(width: 5),
                  if (MediaQuery.of(context).size.width > 500)
                    SizedBox(width: 32),
                  Material(
                    // elevation: 3,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      // height: 40,
                      height: MediaQuery.of(context).size.width < 500 ? 40 : 50,
                      width: MediaQuery.of(context).size.width < 500
                          ? MediaQuery.of(context).size.width * .52
                          : MediaQuery.of(context).size.width * .49,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          // border: Border.all(color: Colors.grey),
                          border: Border.all(color: Color(0xFF8A95A8))),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: TextField(
                              style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 500
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
                                  currentPage = 0; // reset to first page on search change
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
                                    // fontWeight: FontWeight.bold,
                                    color: Color(0xFF8A95A8),
                                  ),
                                  contentPadding: EdgeInsets.only(
                                      left: 5, bottom: 10, top: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  DropdownButtonHideUnderline(
                    child: Material(
                      // elevation: 3,
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
                                'Status',
                                style: TextStyle(
                                  fontSize: 14,
                                  // fontWeight: FontWeight.bold,
                                  color: Color(0xFF8A95A8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        items: items
                            .map((String item) => DropdownMenuItem<String>(
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
                            currentPage = 0; // reset to first page on filter change
                          });
                        },
                        buttonStyleData: ButtonStyleData(
                          height:
                              MediaQuery.of(context).size.width < 500 ? 40 : 50,
                          // width: 180,
                          width: MediaQuery.of(context).size.width < 500
                              ? MediaQuery.of(context).size.width * .35
                              : MediaQuery.of(context).size.width * .35,
                          padding: const EdgeInsets.only(left: 14, right: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              // color: Colors.black26,
                              color: Color(0xFF8A95A8),
                            ),
                            color: Colors.white,
                          ),
                          elevation: 0,
                        ),
                        dropdownStyleData: DropdownStyleData(
                          maxHeight: 250,
                          width: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            //color: Colors.redAccent,
                          ),
                          offset: const Offset(-20, 0),
                          scrollbarTheme: ScrollbarThemeData(
                            radius: const Radius.circular(40),
                            thickness: MaterialStateProperty.all(6),
                            thumbVisibility: MaterialStateProperty.all(true),
                          ),
                        ),
                        menuItemStyleData: const MenuItemStyleData(
                          height: 40,
                          padding: EdgeInsets.only(left: 14, right: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (MediaQuery.of(context).size.width > 500) SizedBox(height: 15),
           
             Container(
                padding: const EdgeInsets.symmetric(horizontal: 15.0,),
                child: FutureBuilder<List<WorkOrder>>(
                  future: futureworkorder,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Container(
                        margin: const EdgeInsets.only(top: 20.0),
                        child: ColabShimmerLoadingWidget(),
                      );
                    } else if (snapshot.hasError) {
                      return friendlyErrorState(snapshot.error);
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            _buildHeaders(),
                            const SizedBox(height: 10),
                            Container(
                              height: MediaQuery.of(context).size.height * .4,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      "assets/images/no_data.jpg",
                                      height: 200,
                                      width: 200,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      // CRM-4365: this branch is the API returning nothing, i.e. the
                                      // vendor genuinely has no work orders — distinct from a filter
                                      // matching nothing, which renders kNoSearchResults instead.
                                      "No Work Orders Yet",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Status and search are CUMULATIVE: status narrows the
                      // list first, then the search runs over what remains.
                      // These used to be exclusive else-if branches, so a search
                      // silently discarded the selected status (and "All"
                      // discarded the search).
                      var data = snapshot.data!;
                      if (selectedValue != null && selectedValue != "All") {
                        if (selectedValue == "Over Due") {
                          data = data.where((element) {
                            try {
                              if (element.date == null ||
                                  element.date!.isEmpty) {
                                return false; // Skip if no date
                              }
                              // Overdue = not in a terminal status AND the due
                              // day is strictly before today (calendar day, not
                              // the current time). Matches the web/server rule
                              // so anything due today or already Closed/Completed
                              // is not counted as overdue.
                              final DateTime now = DateTime.now();
                              final DateTime todayDay =
                                  DateTime(now.year, now.month, now.day);
                              final DateTime dueDate =
                                  DateTime.parse(element.date!);
                              final DateTime dueDay = DateTime(
                                  dueDate.year, dueDate.month, dueDate.day);
                              final bool isTerminal = const {
                                'Completed',
                                'Complete',
                                'Closed'
                              }.contains(element.status);
                              return !isTerminal && dueDay.isBefore(todayDay);
                            } catch (e) {
                              logError(
                                  'Error parsing date for work order ${element.workOrderId}: ${element.date} - $e');
                              return false; // Skip invalid dates
                            }
                          }).toList();
                        } else {
                          data = data
                              .where(
                                  (property) => property.status == selectedValue)
                              .toList();
                        }
                      }
                      if (searchvalue!.isNotEmpty) {
                        data = data
                            .where((property) =>
                                (property.workSubject ?? '')
                                    .toLowerCase()
                                    .contains(searchvalue!.toLowerCase()) ||
                                (property.rentalData?.rentalAddress ?? '')
                                    .toLowerCase()
                                    .contains(searchvalue!.toLowerCase()))
                            .toList();
                      }
                      if (data.isEmpty) {
                        // "No Work Order Added" is only true when the vendor
                        // genuinely has none. A search or status filter that
                        // matches nothing was showing the same message, which
                        // read to a vendor with active jobs as though their
                        // work orders had been removed.
                        final bool isFiltered =
                            (searchvalue?.isNotEmpty ?? false) ||
                                (selectedValue != null &&
                                    selectedValue != "All");
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              _buildHeaders(),
                              const SizedBox(height: 10),
                              if (isFiltered)
                                kNoSearchResults(context)
                              else
                                Container(
                                  height:
                                      MediaQuery.of(context).size.height * .4,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          "assets/images/no_data.jpg",
                                          height: 200,
                                          width: 200,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          "No Work Orders Yet",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: blueColor,
                                              fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      //sortData(data);
                      // print(data);
                      //   print(snapshot.data!.first.totalBalance);
                      final totalPages = (data.length / itemsPerPage).ceil();
                      final currentPageData = data
                          .skip(currentPage * itemsPerPage)
                          .take(itemsPerPage)
                          .toList();
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            _buildHeaders(),
                            SizedBox(height: 10),
                            Container(
                             
                              child: Column(
                                children: currentPageData
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  int index = entry.key;
                                  bool isExpanded = expandedIndex == index;
                                  WorkOrder workorder = entry.value;
                                  //print(Tenant_financial.totalBalance);
                                  //return CustomExpansionTile(data: Propertytype, index: index);
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    decoration: BoxDecoration(
                                      color: index % 2 == 0
                                          ? const Color(0xFFF4F8FF)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFDBE0E5)),
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
                                          flex: 4,
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
                                              '${workorder.workSubject!}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                .04),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                           '${workorder.ticketNumber ?? '-'}',
                                            // rentals.rentalOwnerPhoneNumber!.isEmpty ? 'N/A' :
                                            // '${rentals.rentalOwnerPhoneNumber}',
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      
                                         SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            .025),
                                      ],
                                    ),
                                  ),
                                ),
                               
                                        if (isExpanded)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12.0),
                                            margin: const EdgeInsets.only(
                                                bottom: 12, left: 5),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  const Divider(
                                                      thickness: 2),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: Table(
                                                          columnWidths: const {
                                                            0: FlexColumnWidth(),
                                                            1: FlexColumnWidth(),
                                                          },
                                                          children: [
                                                            _buildTableRow(
                                                              'Property :',
                                                              workorder.rentalData?.rentalAddress != null
                                                                  ? '${workorder.rentalData!.rentalAddress!}'
                                                                  : '',
                                                              'Category :',
                                                              workorder.workCategory ?? '-',
                                                            ),
                                                            _buildTableRow(
                                                              'Priority :',
                                                              workorder.priority ?? '-',
                                                              'Status :',
                                                              workorder.status ?? 'N/A',
                                                            ),
                                                            _buildTableRow(
                                                              'Created On :',
                                                              workorder.createdAt?.isNotEmpty == true
                                                                  ? (dateProvider.formatCurrentDate('${workorder.createdAt}') ?? 'N/A')
                                                                  : 'N/A',
                                                              'Due Date :',
                                                              workorder.date?.isNotEmpty == true
                                                                  ? (dateProvider.formatCurrentDate('${workorder.date}') ?? '-')
                                                                  : '-',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      /* Container(
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
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      InkWell(
                                                        onTap: () {
                                                          Navigator.of(context).push(
                                                              MaterialPageRoute(
                                                                  builder: (context) => Workorder_summery(
                                                                    workorder_id: workorder.workOrderId,
                                                                  )));
                                                        },
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration: BoxDecoration(
                                                            color: Colors.grey.shade200,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                                      SizedBox(width: 8),
                                                      InkWell(
                                                        onTap: () {
                                                          handleEdit(workorder);
                                                        },
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration: BoxDecoration(
                                                            color: Colors.green.shade50,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: const Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                              FaIcon(
                                                                FontAwesomeIcons.penToSquare,
                                                                size: 15,
                                                                color: Colors.green,
                                                              ),
                                                              SizedBox(width: 2),
                                                            ],
                                                          ),
                                                        ),
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
                            // Only show pagination when there's more than one page.
                            if (totalPages > 1) SizedBox(height: 20),
                            if (totalPages > 1)
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
                                          border:
                                              Border.all(color: Colors.grey),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: itemsPerPage,
                                            items: itemsPerPageOptions
                                                .map((int value) {
                                              return DropdownMenuItem<int>(
                                                value: value,
                                                child: Text(value.toString()),
                                              );
                                            }).toList(),
                                            onChanged: (newValue) {
                                              setState(() {
                                                itemsPerPage = newValue!;
                                                currentPage =
                                                    0; // Reset to first page when items per page change
                                              });
                                            },
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

  void printRentalData(List<WorkOrder> workOrders) {
    for (var workOrder in workOrders) {

      if (workOrder.rentalData != null) {
      } else {
      }
    }
  }
}

void main() => runApp(MaterialApp(home: WorkOrderTable()));
