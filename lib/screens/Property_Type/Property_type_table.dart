import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/property_type_image_field.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../Model/propertytype.dart';
import '../../constant/constant.dart';
import '../../provider/color_theme.dart';
import '../../provider/dateProvider.dart';
import '../../repository/Property_type.dart';
import '../../widgets/drawer_tiles.dart';
import 'Edit_property_type.dart';
import 'Add_property_type.dart';
import '../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class PropertyTable extends StatefulWidget {
  final bool
      isEmbedded; // When true, shows only table content without Scaffold/AppBar/Drawer

  const PropertyTable({super.key, this.isEmbedded = false});

  @override
  _PropertyTableState createState() => _PropertyTableState();
}

class _PropertyTableState extends State<PropertyTable>
    with NetworkRetryState {
  int totalrecords = 0;
  Future<List<propertytype>>? futurePropertyTypes;
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

  void sortData(List<propertytype> data) {
    // Always apply default sort by createdAt in descending order (newest first)
    data.sort((a, b) {
      if (a.createdAt == null && b.createdAt == null) return 0;
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return b.createdAt!.compareTo(a.createdAt!); // Descending order
    });

    // Apply user-selected sorting only if explicitly chosen
    if (sorting1 && !sorting2 && !sorting3) {
      data.sort((a, b) => ascending1
          ? (a.propertyType ?? '')
              .toLowerCase()
              .compareTo((b.propertyType ?? '').toLowerCase())
          : (b.propertyType ?? '')
              .toLowerCase()
              .compareTo((a.propertyType ?? '').toLowerCase()));
    } else if (sorting2 && !sorting1 && !sorting3) {
      data.sort((a, b) => ascending2
          ? (a.propertysubType ?? '')
              .toLowerCase()
              .compareTo((b.propertysubType ?? '').toLowerCase())
          : (b.propertysubType ?? '')
              .toLowerCase()
              .compareTo((a.propertysubType ?? '').toLowerCase()));
    } else if (sorting3 && !sorting1 && !sorting2) {
      data.sort((a, b) => ascending3
          ? a.createdAt!.compareTo(b.createdAt!)
          : b.createdAt!.compareTo(a.createdAt!));
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
            // Leading block mirrors the row exactly: 30 for the chevron column
            // (was a transparent icon standing in at a different width), then 70
            // for the thumbnail the "Image" heading sits over. Matching these is
            // what keeps every heading directly above its own values.
            // 32 = the row's 30pt chevron column plus the 2pt padding wrapped
            // around the row's Row, which this header does not have.
            const SizedBox(width: 32),
            SizedBox(
              width: 82,
              child: Text("Image",
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
            Expanded(
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
                        ? Text("Main Type ",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15))
                        : Text("Main Type",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
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
                    Text("Sub Type",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
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

  final List<String> items = ['All', 'Commercial', 'Residential'];
  String? selectedValue;
  String searchvalue = "";
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes — including the one it parks inside
  /// the connectivity listener — and nothing that sets up controllers or
  /// filter defaults, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
    });
  }

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      if (!mounted) return;
      // The event is only a trigger — a stale `none` from the
      // plugin would strand this screen offline while requests
      // succeed, so verify against the network first.
      if (result == ConnectivityResult.none &&
          await hasNetworkNow()) {
        result = ConnectivityResult.wifi;
      }
      if (!mounted) return;
      setState(() {
        _connectivityResult = result;
        if (_connectivityResult != ConnectivityResult.none)
          futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
      });
    });
    checkInternet();
  }

  void checkInternet() async {
    var connectiondata;
    connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus can report a stale `none` after the
    // connection is back; confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    setState(() {
      _connectivityResult = connectiondata;
    });

    if (_connectivityResult != ConnectivityResult.none)
      futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
  }

  void handleEdit(propertytype property) async {
    // Handle edit action

    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Edit_property_type(
                  property: property,
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
        futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
      });
    }*/
  }

  bool _errorText = false;
  void _showAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same id.
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
                contentPadding: EdgeInsets.only(top: 8, left: 15),
              ),
            ),
          ),
          // if (_errorText)
          //   Text(
          //     "Please fill in all fields correctly.",
          //     style: TextStyle(color: Colors.redAccent),
          //   ),
        ],
      ),
      style: const AlertStyle(
        backgroundColor: Colors.white,
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
            // when the delete is rejected (e.g. the type is still in use).
            // Nothing caught it, so Navigator.pop was never reached — the
            // dialog stayed open with no explanation and the exception escaped
            // into the framework. Close the dialog either way; the message has
            // already been shown.
            try {
              await PropertyTypeRepository()
                  .DeletePropertyType(pro_id: id, reason: reason.text);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              setState(() {
                futurePropertyTypes =
                    PropertyTypeRepository().fetchPropertyTypes();
              });
              Navigator.pop(context);
            } catch (e) {
              deleting = false;
              if (!mounted) return;
              Navigator.pop(context);
              // Shown here rather than by the repository: a SnackBar wraps, so
              // the server's full reason stays readable where a toast cut it
              // off after two lines.
              final String reason = e is PropertyTypeDeleteException
                  ? e.serverMessage
                  : friendlyErrorMessage(e,
                      fallbackMessage: 'Failed to delete property type');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(reason.isNotEmpty
                      ? reason
                      : 'Failed to delete property type'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
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

  List<propertytype> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<propertytype> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(propertytype d) getField,
      int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _tableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);

        // For string fields, perform case-insensitive comparison
        if (aValue is String && bValue is String) {
          final result = (aValue as String)
              .toLowerCase()
              .compareTo((bValue as String).toLowerCase());
          return _sortAscending ? result : -result;
        } else {
          final result = aValue.compareTo(bValue as T);
          return _sortAscending ? result : -result;
        }
      });
    });
  }

  void handleDelete(propertytype property) {
    _showAlert(context, property.propertyId!);
    // Handle delete action
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
      Comparable<T> Function(propertytype d)? getField) {
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
  Widget _buildActionsCell(propertytype data) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          height: 50,
          child: Row(
            children: [
              const SizedBox(
                width: 20,
              ),
              InkWell(
                onTap: () {
                  handleEdit(data);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[350], // Light green background
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const FaIcon(
                    FontAwesomeIcons.edit,
                    size: 30,
                    color: Colors.green, // Green icon
                  ),
                ),
              ),
              const SizedBox(
                width: 15,
              ),
              InkWell(
                onTap: () {
                  handleDelete(data);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.red[350], // Light red background
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: const FaIcon(
                    FontAwesomeIcons.trashCan,
                    size: 30,
                    color: Colors.red, // Red icon
                  ),
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

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
  final _scrollController = ScrollController();

  Widget _buildTableContent(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    Widget content = Column(
      children: [
        // Always show original design
        const SizedBox(height: 20),
        // Header Section with Title and Add Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Row(
            children: [
              if (MediaQuery.of(context).size.width > 500) SizedBox(width: 13),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: widget.isEmbedded
                      ? Text(
                          'Manage Property Type',
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
                          title: 'Property Type',
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
                              builder: (context) => const Add_property()));
                      if (result == true) {
                        setState(() {
                          futurePropertyTypes =
                              PropertyTypeRepository().fetchPropertyTypes();
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
        const SizedBox(height: 20),
        // Search and Filter Section - Original Design
        Padding(
          padding: EdgeInsets.only(
              left: MediaQuery.of(context).size.width < 500 ? 0 : 0,
              right: MediaQuery.of(context).size.width < 500 ? 0 : 0),
          child: Row(
            children: [
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
                                fontSize:
                                    MediaQuery.of(context).size.width < 500
                                        ? 15
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
                                    left: 5, bottom: 12, top: 5)),
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
                    elevation: 0,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: DropdownButton2<String>(
                      isExpanded: true,
                      hint: const Row(
                        children: [
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Type',
                              style: TextStyle(
                                fontSize: 14,
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
                        });
                      },
                      buttonStyleData: ButtonStyleData(
                        height:
                            MediaQuery.of(context).size.width < 500 ? 45 : 50,
                        padding: const EdgeInsets.only(left: 14, right: 14),
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        // if (MediaQuery.of(context).size.width > 500)
        //  const SizedBox(height: 22),
        //if (MediaQuery.of(context).size.width < 500)
        Padding(
          padding:
              EdgeInsets.all(MediaQuery.of(context).size.width < 500 ? 0 : 0),
          child: FutureBuilder<List<propertytype>>(
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

                // Apply type filter first (if selected and not "All")
                if (selectedValue != null && selectedValue != "All") {
                  data = data
                      .where(
                          (property) => property.propertyType == selectedValue)
                      .toList();
                }

                // Apply search filter on top of type filter (if search is not empty)
                if (searchvalue!.isNotEmpty) {
                  data = data
                      .where((property) =>
                          (property.propertyType ?? '')
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()) ||
                          property.propertysubType
                              .toString()
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()) ||
                          property.createdAt
                              .toString()
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()) ||
                          property.updatedAt
                              .toString()
                              .toLowerCase()
                              .contains(searchvalue!.toLowerCase()))
                      .toList();
                }
                sortData(data);
                // final totalPages =
                // (data.length / itemsPerPage).ceil();
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
                      // decoration: BoxDecoration(
                      //     border: Border.all(
                      //         color: Color.fromRGBO(
                      //             152, 162, 179, .5))),
                      // decoration: BoxDecoration(
                      //     border: Border.all(color: blueColor)),
                      child: Column(
                        children: currentPageData.isEmpty
                            ? [kNoSearchResults(context)]
                            : currentPageData.asMap().entries.map((entry) {
                          int index = entry.key;
                          bool isExpanded = expandedIndex == index;
                          propertytype Propertytype = entry.value;
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
                            // decoration: BoxDecoration(
                            //   border: Border.all(color: blueColor),
                            // ),
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
                                            // Fixed 30 wide: FaIcon lays out at its
                                            // glyph's advance width, not the `size`
                                            // given, so this column came out narrower
                                            // than the header assumed and pushed every
                                            // heading right of its values.
                                            width: 30,
                                            alignment: Alignment.center,
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
                                        Padding(
                                          padding:
                                              // 22, not 10: the header gained a 12pt gap between the Image label
                                              // and Main Type, so the row matches it or the headings sit right
                                              // of the values they label.
                                              const EdgeInsets.only(right: 34),
                                          child: PropertyTypeImageField.preview(
                                            value: Propertytype.propertyTypeImage,
                                            propertyType:
                                                Propertytype.propertyType,
                                            isMultiUnit:
                                                Propertytype.isMultiunit ?? false,
                                            size: 48,
                                            radius: 6,
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
                                            child: Text(
                                              '${Propertytype.propertyType}',
                                              style: TextStyle(
                                                color: blueColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${Propertytype.propertysubType}',
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
                                          const SizedBox(height: 12),
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
                                                    // Created On used to be a column in the collapsed row; it moved
                                                    // here so the row shows only Image, Main Type and Sub Type.
                                                    Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text:
                                                                'Created On : ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    blueColor), // Bold and black
                                                          ),
                                                          TextSpan(
                                                            // text: formatDate(
                                                            //     '${Propertytype.createdAt}'),
                                                            text: Propertytype
                                                                        .createdAt
                                                                        ?.isNotEmpty ==
                                                                    true
                                                                ? dateProvider
                                                                    .formatCurrentDate(
                                                                        '${Propertytype.createdAt}')
                                                                : 'N/A',
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
                                                    const SizedBox(height: 4),
                                                    Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text:
                                                                'Updated On : ',
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color:
                                                                    blueColor), // Bold and black
                                                          ),
                                                          TextSpan(
                                                            // text: formatDate(
                                                            //     '${Propertytype.updatedAt}'),
                                                            text: Propertytype
                                                                        .updatedAt
                                                                        ?.isNotEmpty ==
                                                                    true
                                                                ? dateProvider
                                                                    .formatCurrentDate(
                                                                        '${Propertytype.updatedAt}')
                                                                : 'N/A',
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
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    var check =
                                                        await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                                builder:
                                                                    (context) =>
                                                                        Edit_property_type(
                                                                          property:
                                                                              Propertytype,
                                                                        )));
                                                    if (check == true) {
                                                      setState(() {
                                                        futurePropertyTypes =
                                                            PropertyTypeRepository()
                                                                .fetchPropertyTypes();
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
                                                          FontAwesomeIcons.edit,
                                                          size: 15,
                                                          color: Colors.green,
                                                        ),
                                                        SizedBox(
                                                          width: 10,
                                                        ),
                                                        Text(
                                                          "Edit",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.green,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(
                                                width: 5,
                                              ),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    _showAlert(
                                                        context,
                                                        Propertytype
                                                            .propertyId!);
                                                  },
                                                  child: Container(
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                          color: Colors.red,
                                                          width: 1.5),
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
                                                              color: Colors.red,
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
                                //SizedBox(height: 13,),
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

    return !isOffline
        ? SingleChildScrollView(child: content)
        : NoInternetView(onRetry: retryNow);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildTableContent(context);
    }
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Property Type",
        dropdown: true,
      ),
      body: _buildTableContent(context),
    );
  }
}

void main() => runApp(MaterialApp(home: PropertyTable()));
