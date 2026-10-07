import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../../../../widgets/no_internet_view.dart';
import '../../../../provider/network_retry_state.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:three_zero_two_property/Model/propertytype.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/repository/Property_type.dart';
import '../../../../widgets/CustomTableShimmer.dart';
import '../../../model/staffpermission.dart';
import '../../../repository/staffpermission_provider.dart';
import '../../../repository/repository/workorder.dart';
import 'Add_workorder.dart';
import 'Edit_workorders.dart';
import 'workorder_summery.dart';
import 'package:three_zero_two_property/screens/Property_Type/Add_property_type.dart';
import 'package:three_zero_two_property/screens/Property_Type/Edit_property_type.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../../constant/constant.dart';
import '../../../../model/workordr.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../widgets/custom_drawer.dart';

class Workorder_table extends StatefulWidget {
  final String? filter;
  final bool embeddedMode;
  final String? rentalIdFilter;
  final bool showAddButton;

  Workorder_table({
    super.key,
    this.filter,
    this.embeddedMode = false,
    this.rentalIdFilter,
    this.showAddButton = true,
  });

  @override
  State<Workorder_table> createState() => _Workorder_tableState();
}

class _Workorder_tableState extends State<Workorder_table>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<Map<String, dynamic>> futureworkorders;
  int rowsPerPage = 5;
  int sortColumnIndex = 0;
  bool sortAscending = true;
  int currentPage = 0;
  int itemsPerPage = 10;
  Map<String, dynamic>? paginationInfo;
  List<int> itemsPerPageOptions = [
    10,
    25,
    50,
    100,
  ]; // Options for items per page
  List<String> selectedStatuses = ['All']; // Default: all statuses selected

  void sortData(List<Data> data) {
    if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.workOrderData!.workSubject!
              .compareTo(b.workOrderData!.workSubject!)
          : b.workOrderData!.workSubject!
              .compareTo(a.workOrderData!.workSubject!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.workOrderData!.status!.compareTo(b.workOrderData!.status!)
          : b.workOrderData!.status!.compareTo(a.workOrderData!.status!));
    }
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
  bool isChecked = false;
  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: blueColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
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
                      ascending1 = true;
                      ascending2 = false;
                      ascending3 = false;
                    }

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? const Text("Work Order ",
                            style: TextStyle(color: Colors.white))
                        : const Text("Work Order",
                            style: TextStyle(color: Colors.white)),
                    // Text("Property", style: TextStyle(color: Colors.white)),

                    sorting1
                        ? (ascending1
                            ? const Padding(
                                padding: EdgeInsets.only(top: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortUp,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.only(bottom: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortDown,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ))
                        : const SizedBox(width: 22),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting2 == true) {
                      sorting1 = false;
                      sorting3 = false;
                      ascending2 = !ascending2;
                      ascending1 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = true;
                      sorting3 = false;
                      ascending2 = true;
                      ascending1 = false;
                      ascending3 = false;
                    }
                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    const Text("       Status",
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 5),
                    sorting2
                        ? (ascending2
                            ? const Padding(
                                padding: EdgeInsets.only(top: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortUp,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.only(bottom: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortDown,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ))
                        : const SizedBox(width: 22),
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

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    const Text("      Billable ",
                        style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 5),
                    /*ascending3
                        ? const Padding(
                            padding: EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 20,
                              color: Colors.white,
                            ),
                          )
                        : const Padding(
                            padding: EdgeInsets.only(bottom: 7, left: 2),
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

  final List<String> items = [
    "All",
    'Closed',
    "Completed",
    "In Progress",
    'New',
    "On Hold",
    "Over Due"
  ];
  String? selectedValue;
  String searchvalue = "";
  // Lets _reloadAsFreshList() empty the search box too.
  final TextEditingController _searchController = TextEditingController();

  Widget _mobileWorkOrderColumnHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        border: Border.all(color: const Color(0xFFDBE0E5)),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: 25),
          Expanded(
            flex: 3,
            child: Text(
              "Work Order",
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
         SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              "Ticket #",
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.start,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _workOrdersEmptyPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/no_data.jpg",
              height: 160,
              width: 160,
            ),
            const SizedBox(height: 10),
            Text(
              "No Data Available",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadWorkOrders() async {
    setState(() {
      futureworkorders = WorkOrderRepository().fetchWorkOrdersPaginated(
        page: currentPage + 1,
        limit: itemsPerPage,
        sortBy: 'createdAt',
        sortOrder: 'desc',
        status: selectedStatuses.contains('All') ? null : selectedStatuses,
        search: searchvalue.isEmpty ? null : searchvalue,
        billable: isChecked ? true : null,
        rentalId: widget.rentalIdFilter,
      );
    });
    final result = await futureworkorders;
    setState(() {
      paginationInfo = result['pagination'];
    });
  }

  /// Back from a work order's Summary. Web re-opens its list fresh there
  /// (all statuses, page 1, 10 per page, empty search, billable off,
  /// default sort, no card open), so reset the same way and reload.
  void _reloadAsFreshList() {
    _searchController.clear();
    setState(() {
      searchvalue = "";
      selectedStatuses = ['All'];
      isChecked = false;
      currentPage = 0;
      itemsPerPage = 10;
      expandedIndex = null;
      sorting1 = false;
      sorting2 = false;
      sorting3 = false;
      ascending1 = false;
      ascending2 = false;
      ascending3 = false;
    });
    _loadWorkOrders();
  }

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// Lifted from the hand-written _retryAfterOffline this replaces, so it
  /// reloads exactly what that button already reloaded.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    await _loadWorkOrders();
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
    _loadWorkOrders();
    Provider.of<StaffPermissionProvider>(context, listen: false)
        .fetchPermissions();
    if (widget.filter != null) {
      selectedValue = widget.filter;
      if (widget.filter != 'All') {
        selectedStatuses = [widget.filter!];
      }
    }
  }

  Widget _buildMultiSelectDropdown() {
    return Material(
    //  elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: MediaQuery.of(context).size.width < 500 ? 45 : 50,
        width: MediaQuery.of(context).size.width < 500
            ? MediaQuery.of(context).size.width * .38
            : MediaQuery.of(context).size.width * .4,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color(0xFFDBE0E5)),
          color: Colors.white,
        ),
        child: PopupMenuButton<String>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedStatuses.isEmpty
                      ? 'Status'
                      : selectedStatuses.contains('All')
                          ? 'All'
                          : selectedStatuses.length == 1
                              ? selectedStatuses.first
                              : '${selectedStatuses.length} Selected',
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedStatuses.isEmpty
                        ? const Color(0xFF8A95A8)
                        : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Color(0xFF8A95A8)),
            ],
          ),
          itemBuilder: (BuildContext context) {
            return items.map((String item) {
              final isSelected = selectedStatuses.contains(item) ||
                  (item == 'All' && selectedStatuses.contains('All'));
              return PopupMenuItem<String>(
                value: item,
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (item == 'All') {
                            if (value == true) {
                              selectedStatuses = ['All'];
                            } else {
                              selectedStatuses = [];
                            }
                          } else {
                            if (selectedStatuses.contains('All')) {
                              selectedStatuses.remove('All');
                            }
                            if (value == true) {
                              if (!selectedStatuses.contains(item)) {
                                selectedStatuses.add(item);
                              }
                            } else {
                              selectedStatuses.remove(item);
                            }
                            if (selectedStatuses.isEmpty) {
                              selectedStatuses = ['All'];
                            }
                          }
                          currentPage = 0;
                          _loadWorkOrders();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  DateTime parseDate(String dateString) {
    try {
      // List of common date formats to try
      List<String> formats = [
        'yyyy-MM-dd', // Example: 2024-11-25
        'MM/dd/yyyy', // Example: 11/25/2024
        'dd/MM/yyyy', // Example: 25/11/2024
        'yyyy-MM-dd HH:mm', // Example: 2024-11-25 14:30
        'yyyy/MM/dd', // Example: 2024/11/25
        'MMMM dd, yyyy', // Example: November 25, 2024
      ];

      for (String format in formats) {
        try {
          return DateFormat(format).parse(dateString);
        } catch (e) {
          // Continue trying other formats
        }
      }

      // If none of the formats match, throw an error
      throw FormatException("Unsupported date format: $dateString");
    } catch (e) {
      logError("Error parsing date: $e");
      return DateTime.now(); // Fallback to current date if parsing fails
    }
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  // Owned by the State, not by each dialog. Disposing these the moment
  // Alert.show() resolved killed them while the dialog was still playing its
  // exit animation, and the TextField rebuilding mid-animation then attached a
  // listener to a dead controller.
  final TextEditingController _deleteReasonController = TextEditingController();
  final TextEditingController _closeReasonController = TextEditingController();

  @override
  void dispose() {
    _deleteReasonController.dispose();
    _closeReasonController.dispose();
    _searchController.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }
  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back; confirm before
    // believing it, or this screen strands itself offline.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  void handleEdit(Data property) async {
    // Handle edit action
    //print('Edit ${property.sId}');
    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => ResponsiveEditWorkOrder(
                  workorderId: property.workOrderData!.workOrderId!,
                )));
    if (check == true) {
      setState(() {});
    }
    // final result = await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => Edit_property_type(
    //               property: property,
    //             )));
    /* if (result == true) {
      setState(() {
        futureDatas = DataRepository().fetchDatas();
      });
    }*/
  }

  void _showAlert(BuildContext context, String id) {
    final reason = _deleteReasonController..clear();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same record.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this Workorder!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      content: Column(
        children: <Widget>[
          SizedBox(
            height: 10,
          ),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: InputDecoration(
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
            // The DELETE was fired without being awaited, so the list refresh
            // raced it and usually came back with the row still present; it
            // only vanished on the next visit. Await it, refresh only on
            // success, and send the reason the user typed (it was dropped).
            // Close the dialog either way — the repository has already
            // toasted the server's own message.
            try {
              await WorkOrderRepository()
                  .DeleteWorkOrder(workOrderid: id, reason: reason.text);
              if (!mounted) return;
              _loadWorkOrders();
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
 
  void handleClose(Data workorder) {
    _showCloseAlert(context, workorder.workOrderData!.workOrderId!);
  }

  void _showCloseAlert(BuildContext context, String workOrderId) {
    final reason = _closeReasonController..clear();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Close Work Order?",
      desc:
          "This work order will be marked as closed. You can add a reason below.",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      content: Column(
        children: [
          const SizedBox(height: 10),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reason for closing',
                contentPadding: EdgeInsets.only(top: 8, left: 15),
              ),
            ),
          ),
        ],
      ),
      buttons: [
        DialogButton(
          child: const Text("Close",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          onPressed: () async {
            final text = reason.text.trim();
            if (text.isEmpty) {
              Fluttertoast.showToast(
                  msg: "Please enter a reason for closing");
              return;
            }
            Navigator.pop(context);
            try {
              await WorkOrderRepository().closeWorkOrder(
                workOrderId: workOrderId,
                message: text,
                publicNotes: text,
              );
              if (mounted) _loadWorkOrders();
            } catch (_) {}
          },
          color: blueColor,
          radius: BorderRadius.circular(8),
          border: Border.all(
            color: blueColor,
            width: 1.5,
          ),
        ),
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(
            color: blueColor,
            width: 1.5,
          ),
        ),
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

  void handleDelete(Data workorder) {
    _showAlert(context, workorder.workOrderData!.workOrderId!);
    // Handle delete action
  }

  // Widget _buildHeader<T>(String text, int columnIndex,
  //     Comparable<T> Function(Data d)? getField) {
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
  Widget _buildHeader<T>(
      String text, int columnIndex, Comparable<T> Function(Data d)? getField) {
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

  Widget _buildDataCell(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildDataCellBillable(bool isBillable) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Row(
          children: [
            if (isBillable) Icon(Icons.check, color: blueColor),
            if (!isBillable) Icon(Icons.close, color: blueColor),
          ],
        ),
      ),
    );
  }

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

  final _scrollController = ScrollController();

  Widget _noInternetBody() {
    return NoInternetView(onRetry: retryNow);
  }

  // Swipe-down on the offline state: re-check the connection first, then let
  // the screen load itself again. Nothing to load while still offline.
  Future<void> _retryAfterOffline() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back; confirm before
    // believing it, or this screen strands itself offline.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    // The event is only a trigger: checkInternet() verifies
    // against the network before deciding.
    checkInternet();
    if (connectiondata == ConnectivityResult.none) return;
    await _loadWorkOrders();
  }

  Widget build(BuildContext context) {
    final permissionProvider = Provider.of<StaffPermissionProvider>(context);
    StaffPermission? permissions = permissionProvider.permissions;
    final dateProvider = Provider.of<DateProvider>(context);
    final scrollBody = SingleChildScrollView(
      child: Column(
        children: [
          if (!widget.embeddedMode) const SizedBox(height: 20),
        //  if (widget.embeddedMode) const SizedBox(height: 4),
          //add Data
          // Header Section with Title and Add Button
          if (!widget.embeddedMode)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(
                      width: 13,
                    ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: titleBar(
                        width: double.infinity,
                        title: 'Work Orders',
                      ),
                    ),
                  ),
                  if (widget.showAddButton)
                    Flexible(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: GestureDetector(
                          onTap: () async {
                            final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ResponsiveAddWorkOrder()));
                            if (result == true) {
                              _loadWorkOrders();
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
                            child: const Center(
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
                  if (widget.showAddButton &&
                      MediaQuery.of(context).size.width < 500)
                    const SizedBox(width: 3),
                  if (widget.showAddButton &&
                      MediaQuery.of(context).size.width > 500)
                    const SizedBox(width: 18),
                ],
              ),
            ),
          if (!widget.embeddedMode) const SizedBox(height: 10),
          if (widget.embeddedMode) const SizedBox(height: 6),
                  //search
                  Padding(
                    padding: const EdgeInsets.only(left: 11, right: 11),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 18),
                        Material(
                        //  elevation: 3,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            // height: 40,
                            height: MediaQuery.of(context).size.width < 500
                                ? 45
                                : 50,
                            width: MediaQuery.of(context).size.width < 500
                                ? MediaQuery.of(context).size.width * .52
                                : MediaQuery.of(context).size.width * .49,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                // border: Border.all(color: Colors.grey),
                                border:
                                    Border.all(color: Color(0xFFDBE0E5))),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: TextField(
                                    style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 12
                                                : 14),
                                    // onChanged: (value) {
                                    //   setState(() {
                                    //     cvverror = false;
                                    //   });
                                    // },
                                    // controller: cvv,
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        searchvalue = value;
                                        currentPage = 0;
                                        _loadWorkOrders();
                                      });
                                    },
                                    cursorColor: blueColor,
                                    decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Search here...",
                                        hintStyle: TextStyle(
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14
                                              : 18,
                                          // fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8A95A8),
                                        ),
                                        contentPadding: const EdgeInsets.only(
                                            left: 5, bottom: 11, top: 5)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        _buildMultiSelectDropdown(),
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 20),
                      ],
                    ),
                  ),
                  if (MediaQuery.of(context).size.width < 500)
                    const SizedBox(height: 10),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(height: 20),
                  //billable
                  Padding(
                    padding: const EdgeInsets.only(left: 11, right: 11),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 5),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 25),
                        Row(
                          children: [
                            Text(
                              "Billable To Tenants",
                              style: TextStyle(
                                  color: Colors.grey.shade900,
                                  fontSize:
                                      MediaQuery.of(context).size.width > 500
                                          ? 20
                                          : 12),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            SizedBox(
                              width: 24.0, // Standard width for checkbox
                              height: 24.0,
                              child: Checkbox(
                                value: isChecked,
                                onChanged: (value) {
                                  setState(() {
                                    isChecked = value ?? false;
                                    currentPage = 0;
                                  });
                                  _loadWorkOrders();
                                },
                                activeColor:
                                    isChecked ? blueColor : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 25),
                  // if (MediaQuery.of(context).size.width < 500)
                  Padding(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 500 ? 14 : 28),
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: futureworkorders,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _mobileWorkOrderColumnHeader(),
                              const SizedBox(height: 8),
                              ColabShimmerLoadingWidget(),
                            ],
                          );
                        } else if (!snapshot.hasData ||
                            (snapshot.data!['data'] as List).isEmpty) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _mobileWorkOrderColumnHeader(),
                              _workOrdersEmptyPlaceholder(),
                            ],
                          );
                        } else {
                          final List<Data> data =
                              (snapshot.data!['data'] as List)
                                  .map((item) => item as Data)
                                  .toList();

                          // Filter by search value (including ticket number)
                          List<Data> searchFilteredData = data;
                          if (searchvalue.isNotEmpty) {
                            searchFilteredData = data.where((workorder) {
                              final ticketNumber =
                                  workorder.workOrderData?.ticketNumber ?? '';
                              final rentalAddress =
                                  workorder.rentalAddress?.rentalAdress ?? '';
                              final workSubject =
                                  workorder.workOrderData?.workSubject ?? '';
                              final searchLower = searchvalue.toLowerCase();

                              return ticketNumber
                                      .toLowerCase()
                                      .contains(searchLower) ||
                                  rentalAddress
                                      .toLowerCase()
                                      .contains(searchLower) ||
                                  workSubject
                                      .toLowerCase()
                                      .contains(searchLower);
                            }).toList();
                          }

                          // Billable filter is applied via API (billable=true param)
                          final List<Data> filteredData = searchFilteredData;

                          if (filteredData.isEmpty) {
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _mobileWorkOrderColumnHeader(),
                                  _workOrdersEmptyPlaceholder(),
                                ],
                              ),
                            );
                          }

                          final currentPageData = filteredData;
                          final totalPages = paginationInfo != null
                              ? paginationInfo!['totalPages'] as int
                              : 1;
                          Widget workOrderCard(
                            Data workOrder,
                            bool isExpanded,
                            VoidCallback onExpandTap,
                            BuildContext context,
                            DateProvider dateProvider,
                            VoidCallback onEdit,
                            VoidCallback onDelete,
                            VoidCallback onViewSummary,
                            VoidCallback? onClose,
                          ) {
                            return GestureDetector(
                              onTap: onExpandTap,
                              child: Container(
                                margin: EdgeInsets.symmetric(vertical: 8),
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color:
                                      currentPageData.indexOf(workOrder) % 2 ==
                                              0
                                          ? Color(0xFFF4F8FF)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Color(0xFFDBE0E5)),
                                  // boxShadow: [
                                  //   BoxShadow(
                                  //     color: Colors.black12,
                                  //     blurRadius: 8,
                                  //     offset: Offset(0, 2),
                                  //   ),
                                  // ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: onExpandTap,
                                          child: Container(
                                            width: 20,
                                            height: 20,
                                            child: Icon(
                                              isExpanded
                                                  ? Icons.expand_less
                                                  : Icons.expand_more,
                                              color: blueColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 5),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                [
                                                  workOrder.rentalAddress?.rentalAdress,
                                                  workOrder.rentalUnit?.rentalUnit,
                                                ].where((v) => v != null && v.isNotEmpty).join(' - '),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: blueColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                              if ((workOrder.workOrderData?.workSubject ?? '').isNotEmpty)
                                                Text(
                                                  workOrder.workOrderData!.workSubject!,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.lightBlue,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            workOrder.workOrderData
                                                    ?.ticketNumber ??
                                                'N/A',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.start,
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isExpanded)
                                      Column(
                                        children: [
                                          Divider(thickness: 2),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 25,
                                              ),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Assigned:',
                                                        style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      workOrder.staffMember
                                                              ?.staffmemberName ??
                                                          "N/A",
                                                      style: TextStyle(
                                                          fontSize: 12),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text('Due Date:',
                                                        style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      (workOrder.workOrderData
                                                                      ?.date ==
                                                                  null ||
                                                              workOrder
                                                                      .workOrderData
                                                                      ?.date
                                                                      .toString()
                                                                      .isEmpty ==
                                                                  true)
                                                          ? "N/A"
                                                          : (dateProvider
                                                                      .formatCurrentDate(
                                                                          '${workOrder.workOrderData?.date}')
                                                                      ?.isEmpty ==
                                                                  true
                                                              ? "N/A"
                                                              : dateProvider
                                                                      .formatCurrentDate(
                                                                          '${workOrder.workOrderData?.date}') ??
                                                                  "N/A"),
                                                      style: TextStyle(
                                                          fontSize: 12),
                                                    ),
                                                    SizedBox(height: 8),
                                                    Text('Created:',
                                                        style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13)),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      (workOrder.workOrderData
                                                                      ?.createdAt ==
                                                                  null ||
                                                              workOrder
                                                                      .workOrderData
                                                                      ?.createdAt
                                                                      .toString()
                                                                      .isEmpty ==
                                                                  true)
                                                          ? "N/A"
                                                          : (dateProvider
                                                                      .formatCurrentDate(
                                                                          '${workOrder.workOrderData?.createdAt}')
                                                                      ?.isEmpty ==
                                                                  true
                                                              ? "N/A"
                                                              : dateProvider
                                                                      .formatCurrentDate(
                                                                          '${workOrder.workOrderData?.createdAt}') ??
                                                                  "N/A"),
                                                      style: TextStyle(
                                                          fontSize: 12),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 35),
                                              Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 20),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text('Status:',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13)),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        workOrder.workOrderData
                                                                ?.status ??
                                                            "N/A",
                                                        style: TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text('Billable:',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13)),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        workOrder.workOrderData
                                                                    ?.isBillable ==
                                                                true
                                                            ? "Yes"
                                                            : "No",
                                                        style: TextStyle(
                                                            fontSize: 12),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 4,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              GestureDetector(
                                                onTap: onViewSummary,
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Row(
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
                                              SizedBox(
                                                width: 5,
                                              ),
                                              GestureDetector(
                                                onTap: onEdit,
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      color: Colors.green
                                                          .shade50), // color:Colors.grey[100],
                                                  child: Row(
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
                                              SizedBox(
                                                width: 5,
                                              ),
                                              GestureDetector(
                                                onTap: onDelete,
                                                child: Container(
                                                  height: 35,
                                                  width: 35,
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      color:
                                                          Colors.red.shade50),
                                                  child: Row(
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
                                            if (onClose != null) ...[
                                                const SizedBox(width: 5),
                                                GestureDetector(
                                                  onTap: onClose,
                                                  child: Container(
                                                    height: 35,
                                                    width: 35,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade200,
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .center,
                                                      children: [
                                                        FaIcon(
                                                          FontAwesomeIcons
                                                              .arrowRightFromBracket,
                                                          size: 15,
                                                          color: Colors.black,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                              ],
                                           
                                            ],
                                          ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                _mobileWorkOrderColumnHeader(),
                                ...currentPageData.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  Data workOrder = entry.value;
                                  bool isExpanded = expandedIndex == index;
                                  return workOrderCard(
                                    workOrder,
                                    isExpanded,
                                    () {
                                      setState(() {
                                        expandedIndex =
                                            isExpanded ? null : index;
                                      });
                                    },
                                    context,
                                    dateProvider,
                                    () async {
                                      var check = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              ResponsiveEditWorkOrder(
                                            workorderId: workOrder
                                                .workOrderData!.workOrderId!,
                                          ),
                                        ),
                                      );
                                      if (check == true) {
                                        _loadWorkOrders();
                                      }
                                    },
                                    () {
                                      _showAlert(
                                          context,
                                          workOrder
                                              .workOrderData!.workOrderId!);
                                    },
                                    () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              Workorder_summery(
                                            workorder_id: workOrder
                                                .workOrderData?.workOrderId,
                                          ),
                                        ),
                                      );
                                      // A status changed on the Summary must
                                      // show here on return.
                                      if (mounted) _reloadAsFreshList();
                                    },
                                    (workOrder.workOrderData?.status ?? '')
                                            .trim()
                                            .toLowerCase() ==
                                        'closed'
                                        ? null
                                        : () => handleClose(workOrder),
                                  );
                                }).toList(),
                                if (paginationInfo != null &&
                                    (paginationInfo!['totalPages'] as int) > 1)
                                  SizedBox(height: 20),
                                if (paginationInfo != null &&
                                    (paginationInfo!['totalPages'] as int) > 1)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
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
                                                  onChanged: (newValue) {
                                                    setState(() {
                                                      itemsPerPage = newValue!;
                                                      currentPage = 0;
                                                      _loadWorkOrders();
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
                                                      _loadWorkOrders();
                                                    });
                                                  },
                                          ),
                                          Text(
                                              'Page ${currentPage + 1} of $totalPages'),
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
                                                          _loadWorkOrders();
                                                        });
                                                      }
                                                    : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                SizedBox(
                                  height: 10,
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
            );

    if (widget.embeddedMode) {
      return !isOffline
          ? scrollBody
          : _noInternetBody();
    }

    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Work Orders",
        dropdown: true,
      ),
      body: !isOffline
          ? scrollBody
          : _noInternetBody(),
    );
  }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leftLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                SizedBox(height: 2.0), // Space between label and value
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
            padding: EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rightLabel,
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                ),
                SizedBox(height: 2.0), // Space between label and value
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
}
