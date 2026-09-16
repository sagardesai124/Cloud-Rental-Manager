import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/Add_applience.dart';
import 'package:three_zero_two_property/StaffModule/screen/Rental/Properties/applience/ApplianceSummary.dart';
import '../../../../model/properties.dart';
import '../../../../Model/unit.dart';
import '../../../../constant/constant.dart';
import '../../../../model/unitsummery_propeties.dart';
import '../../../../provider/dateProvider.dart';
import '../../../repository/unit_data.dart';
import '../../../repository/properties_summery.dart';

class InfrastructurePart extends StatefulWidget {
  Rentals? properties;
  List<unit_properties>? units; // Changed from single unit to list of units

  InfrastructurePart({
    this.units,
    this.properties,
  });

  @override
  _InfrastructurePartState createState() => _InfrastructurePartState();
}

class _InfrastructurePartState extends State<InfrastructurePart>
    with NetworkRetryState {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _installedDate = TextEditingController();
  final UnitData leaseRepository = UnitData();

  // Store appliances for each unit
  Map<String, List<unit_appliance>> unitAppliances = {};
  List<unit_appliance> allAppliances = [];

  // Selected unit for filtering
  unit_properties? selectedUnit;

  bool isLoading = false;

  Future<void> fetchLeasesForUnit(String unitId) async {
    try {
      final fetchedLeases = await leaseRepository.fetchApplianceData(unitId);
      setState(() {
        unitAppliances[unitId] = fetchedLeases;
        _updateAllAppliances();
        isLoading = false;
      });
    } catch (e) {
      logError('Error fetching appliances for unit $unitId: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchAllLeases() async {
    if (widget.units == null || widget.units!.isEmpty) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Fetch appliances for all units
      for (var unit in widget.units!) {
        await fetchLeasesForUnit(unit.unitId!);
      }
    } catch (e) {
      logError('Error fetching all appliances: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateAllAppliances() {
    allAppliances.clear();
    unitAppliances.forEach((unitId, appliances) {
      allAppliances.addAll(appliances);
    });
  }

  void _filterAppliancesByUnit() {
    // Show only appliances for selected unit
    allAppliances.clear();
    String unitId = selectedUnit!.unitId!;
    if (unitAppliances.containsKey(unitId)) {
      allAppliances.addAll(unitAppliances[unitId]!);
    }
    // Update the future
    futureAppliences = Future.value(allAppliances);
  }

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      fetchAllLeases();
    });
  }

  @override
  void initState() {
    super.initState();
    fetchAllLeases();
    // Set the first unit as selected by default
    if (widget.units != null && widget.units!.isNotEmpty) {
      selectedUnit = widget.units!.first;
    }
    // Initialize futureAppliences with all appliances
    futureAppliences = _getAllAppliancesFuture();
  }

  @override
  void didUpdateWidget(InfrastructurePart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.units != oldWidget.units) {
      fetchAllLeases();
      if (widget.units != null && widget.units!.isNotEmpty) {
        selectedUnit = widget.units!.first;
      }
      futureAppliences = _getAllAppliancesFuture();
    }
  }

  Future<List<unit_appliance>> _getAllAppliancesFuture() async {
    await fetchAllLeases();
    return allAppliances;
  }

  List<unit_appliance> get _currentFilteredData {
    if (selectedUnit == null) {
      return allAppliances;
    } else {
      String unitId = selectedUnit!.unitId!;
      return unitAppliances[unitId] ?? [];
    }
  }

  reload_screen() {
    setState(() {
      fetchAllLeases();
      futureAppliences = _getAllAppliancesFuture();
    });
  }

  DateTime? _selectedDate;
  bool iserror = false;

  // Helper functions
  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('MM/dd/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String reverseFormatDate(String dateString) {
    try {
      DateTime date = DateFormat('MM/dd/yyyy').parse(dateString);
      return date.toIso8601String();
    } catch (e) {
      return dateString;
    }
  }

  // Table functionality
  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(unit_appliance d)? getField) {
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

  Widget _buildActionsCell(unit_appliance data) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          height: 50,
          child: Row(
            children: [
              const SizedBox(width: 20),
              InkWell(
                onTap: () {
                  handleEdit(data);
                },
                child: const FaIcon(
                  FontAwesomeIcons.edit,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
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
    // Web parity: CommonPagination clamps the page count to a floor of 1
    // (Math.max(1, ...)), so an empty search result reads "Page 1 of 1".
    // This also gives the `= 1` initialiser above its intended effect.
    if (totalrecords > 0) numorpages = (totalrecords / _rowsPerPage).ceil();
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
                : const Color.fromRGBO(21, 43, 83, 1),
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

  // Table data management
  List<unit_appliance> _tableData = [];
  int totalrecords = 0;
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<unit_appliance> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0;
    });
  }

  void _sort<T>(Comparable<T> Function(unit_appliance d) getField,
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

  void handleEdit(unit_appliance rentalOwner) async {
    // Handle edit action for infrastructure
  }

  void _showDeleteAlert(BuildContext context, String id) {
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this applience!",
      style: const AlertStyle(
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
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            await Properies_summery_Repo().Deleteapplences(appliance_id: id);
            setState(() {
              fetchAllLeases();
              futureAppliences = _getAllAppliancesFuture();
            });
            Navigator.pop(context);
          },
          color: blueColor,
        ),
      ],
    ).show();
  }

  void handleDelete(unit_appliance rental) {
    _showDeleteAlert(context, rental.applianceId!);
  }

  // Mobile view variables
  late Future<List<unit_appliance>> futureAppliences;
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

  List<int> itemsPerPageOptions = [10, 25, 50, 100];
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;

  void sortData(List<unit_appliance> data) {
    if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.applianceName!.compareTo(b.applianceName!)
          : b.applianceName!.compareTo(a.applianceName!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.applianceDescription!.compareTo(b.applianceDescription!)
          : b.applianceDescription!.compareTo(a.applianceDescription!));
    }
  }

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
                        ? const Text("Name", style: TextStyle(color: Colors.white))
                        : const Text("Name", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                    ascending1
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
                  });
                },
                child: Row(
                  children: [
                    const Text("Description", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 5),
                    ascending2
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
                          ),
                  ],
                ),
              ),
            ),
            Expanded(
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
                child: Row(
                  children: [
                    const Text("   Action", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 5),
                    ascending3
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

  @override
  Widget build(BuildContext context) {
    // This view lives inside another screen's tab, so it shows the
    // compact offline state rather than taking over the whole page.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    final dateProvider = Provider.of<DateProvider>(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Infrastructure',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        if (widget.units != null && widget.units!.length > 1)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(left: 20),
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: blueColor.withOpacity(0.3),
                                    width: 1.5),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<unit_properties>(
                                  isExpanded:
                                  true, // Makes dropdown text responsive
                                  value: selectedUnit,
                                  icon: Icon(
                                    Icons.keyboard_arrow_down,
                                    color: blueColor,
                                    size: 20,
                                  ),
                                  elevation: 3,
                                  dropdownColor: Colors.white,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  items: widget.units!
                                      .map((unit) =>
                                      DropdownMenuItem<unit_properties>(
                                        value: unit,
                                        child: Text(
                                          unit.rentalunit ??
                                              'Unit ${unit.unitId}',
                                          overflow: TextOverflow
                                              .ellipsis, // Prevent overflow
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                      ))
                                      .toList(),
                                  onChanged: (unit) {
                                    setState(() {
                                      selectedUnit = unit;
                                      _filterAppliancesByUnit();
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8,),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddApplience(
                            unit: selectedUnit,
                            properties: widget.properties,
                          ),
                        ),
                      ).then((result) {
                        if (result == true) {
                          setState(() {
                            fetchAllLeases();
                            futureAppliences = _getAllAppliancesFuture();
                          });
                        }
                      });
                    },
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: blueColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: blueColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (MediaQuery.of(context).size.width < 500)
                Padding(
                  padding: const EdgeInsets.all(0.0),
                  child: FutureBuilder<List<unit_appliance>>(
                    future: futureAppliences,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: SpinKitFadingCircle(
                          color: Colors.black,
                          size: 40.0,
                        ));
                      } else if (snapshot.hasError) {
                        return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                            child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 15.0),
                          child: Text(
                              'You don\'t have any infrastructure for this unit right now ..'),
                        ));
                      } else {
                        var data = _currentFilteredData;
                        if (searchValue != null &&
                            searchValue.isNotEmpty &&
                            searchValue != "All") {
                          data = _currentFilteredData
                              .where((rentals) => (rentals.applianceName ?? '')
                                  .toLowerCase()
                                  .contains(searchValue.toLowerCase()))
                              .toList();
                        }
                        sortData(data);

                        final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                        final currentPageData = data
                            .skip(currentPage * itemsPerPage)
                            .take(itemsPerPage)
                            .toList();

                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 10),
                              Column(
                                children: currentPageData.isEmpty
                                    ? [kNoSearchResults(context)]
                                    : currentPageData
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  int index = entry.key;
                                  bool isExpanded = expandedIndex == index;
                                  unit_appliance rentals = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.08),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        // Header section
                                        Container(
                                          padding: const EdgeInsets.all(15),
                                          child: Row(
                                            children: [
                                              // Left section with dropdown and text
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () {
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
                                                        margin: const EdgeInsets.only(
                                                            left: 5, right: 2),
                                                        padding: !isExpanded
                                                            ? const EdgeInsets.only(
                                                                bottom: 10)
                                                            : const EdgeInsets.only(
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
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            rentals.applianceName ??
                                                                'N/A',
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade900,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 16,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Right section with brand button
                                              if (rentals.brand != null &&
                                                  rentals.brand != "")
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: blueColor
                                                        .withOpacity(0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: blueColor
                                                            .withOpacity(0.3),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    '${rentals.brand}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Expanded details section
                                        if (isExpanded)
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(16),
                                                bottomRight:
                                                    Radius.circular(16),
                                              ),
                                              border: Border(
                                                top: BorderSide(
                                                    color: Colors.grey.shade200,
                                                    width: 1),
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                // Details row
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Category',
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            '${rentals.categoryName}',
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade800,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Installed Date',
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              fontSize: 13,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            dateProvider
                                                                .formatCurrentDate(
                                                                '${ formatDate(rentals
                                                                    .installedDate ??
                                                                    '')}'),
                                                            style: TextStyle(
                                                              color: Colors.grey
                                                                  .shade800,
                                                              fontSize: 15,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 20),
                                                // Action buttons
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    // View button
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                ApplianceSummary(
                                                              appliance:
                                                                  rentals,
                                                              unit:
                                                                  selectedUnit,
                                                              properties: widget
                                                                  .properties,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors
                                                              .grey.shade100,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color: Colors.grey
                                                                  .shade300),
                                                        ),
                                                        child: Icon(
                                                          Icons.visibility,
                                                          color: Colors
                                                              .grey.shade700,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Edit button
                                                    GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                AddApplience(
                                                              unit:
                                                                  selectedUnit,
                                                              properties: widget
                                                                  .properties,
                                                              appliance:
                                                                  rentals,
                                                            ),
                                                          ),
                                                        ).then((result) {
                                                          // Refresh the data when returning from AddApplience
                                                          if (result == true) {
                                                            setState(() {
                                                              fetchAllLeases();
                                                              futureAppliences =
                                                                  _getAllAppliancesFuture();
                                                            });
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .green
                                                                  .withOpacity(
                                                                      0.3)),
                                                        ),
                                                        child: InkWell(
                                                          child: Icon(
                                                            Icons.edit,
                                                            color: Colors
                                                                .green.shade700,
                                                            size: 22,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    // Delete button
                                                    GestureDetector(
                                                      onTap: () {
                                                        _showDeleteAlert(
                                                            context,
                                                            rentals
                                                                .applianceId!);
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(12),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.red
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                          border: Border.all(
                                                              color: Colors.red
                                                                  .withOpacity(
                                                                      0.3)),
                                                        ),
                                                        child: Icon(
                                                          Icons.delete,
                                                          color: Colors
                                                              .red.shade700,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                              if (totalPages > 1)
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
                                              border: Border.all(
                                                  color: Colors.grey),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                value: itemsPerPage,
                                                items: itemsPerPageOptions
                                                    .map((int value) {
                                                  return DropdownMenuItem<int>(
                                                    value: value,
                                                    child:
                                                        Text(value.toString()),
                                                  );
                                                }).toList(),
                                                onChanged: (newValue) {
                                                  setState(() {
                                                    itemsPerPage = newValue!;
                                                    currentPage = 0;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (totalPages > 1)
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
                FutureBuilder<List<unit_appliance>>(
                  future: futureAppliences,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: SpinKitFadingCircle(
                        color: Colors.black,
                        size: 40.0,
                      ));
                    } else if (snapshot.hasError) {
                      return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                          child: Text(
                              'You don\'t have any infrastructure for this unit right now ..'));
                    } else {
                      List<unit_appliance>? filteredData = [];
                      _tableData = _currentFilteredData;
                      if (selectedRole == null && searchValue == "") {
                        filteredData = _currentFilteredData;
                      } else if (selectedRole == "All") {
                        filteredData = _currentFilteredData;
                      } else if (searchValue.isNotEmpty) {
                        filteredData = _currentFilteredData
                            .where((staff) =>
                                (staff.applianceName ?? '')
                                    .toLowerCase()
                                    .contains(searchValue.toLowerCase()) ||
                                (staff.applianceDescription ?? '')
                                    .toLowerCase()
                                    .contains(searchValue.toLowerCase()))
                            .toList();
                      }

                      _tableData = filteredData!;
                      totalrecords = _tableData.length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                width: MediaQuery.of(context).size.width * .91,
                                child: Table(
                                  defaultColumnWidth: const IntrinsicColumnWidth(),
                                  children: [
                                    TableRow(
                                      decoration:
                                          BoxDecoration(border: Border.all()),
                                      children: [
                                        _buildHeader('Name', 0,
                                            (rental) => rental.applianceName!),
                                        _buildHeader(
                                            'Description',
                                            1,
                                            (rental) =>
                                                rental.applianceDescription!),
                                        _buildHeader('InstalledDate', 2,
                                            (rental) => rental.installedDate!),
                                        _buildHeader('Actions', 3, null),
                                      ],
                                    ),
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        border: Border.symmetric(
                                            horizontal: BorderSide.none),
                                      ),
                                      children: List.generate(
                                          4,
                                          (index) => TableCell(
                                              child: Container(height: 20))),
                                    ),
                                    for (var i = 0; i < _pagedData.length; i++)
                                      TableRow(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(color: blueColor),
                                            right: BorderSide(color: blueColor),
                                            top: BorderSide(color: blueColor),
                                            bottom: i == _pagedData.length - 1
                                                ? BorderSide(color: blueColor)
                                                : BorderSide.none,
                                          ),
                                        ),
                                        children: [
                                          _buildDataCell(
                                              _pagedData[i].applianceName!),
                                          _buildDataCell(_pagedData[i]
                                              .applianceDescription!),
                                          _buildDataCell(formatDate(
                                              _pagedData[i].installedDate!)),
                                          _buildActionsCell(_pagedData[i]),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (_tableData.isEmpty)
                              const Text("No Search Records Found"),
                            const SizedBox(height: 25),
                            _buildPaginationControls(),
                          ],
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomTextFormField extends StatefulWidget {
  final String labelText;
  final String hintText;
  final TextInputType keyboardType;
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const CustomTextFormField({
    Key? key,
    required this.labelText,
    required this.hintText,
    required this.keyboardType,
    required this.controller,
    this.validator,
  }) : super(key: key);

  @override
  _CustomTextFormFieldState createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }
}
