import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../Model/All_categories_model.dart';
import '../../../../constant/constant.dart';
import '../../../../model/properties.dart';
import '../../../../model/unitsummery_propeties.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../repository/fetch_allcategories.dart';
import '../../../../repository/properties_summery.dart';
import '../../../../repository/unit_data.dart';
import '../../../../Model/unit.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'ApplianceSummary.dart';
import 'edit_appliences.dart';
import '../summery_page.dart';


class AppliancesPart extends StatefulWidget {
  Rentals? properties;
  unit_properties? unit;

  AppliancesPart({
    this.unit,
    this.properties,
  });
  @override
  _AppliancesPartState createState() => _AppliancesPartState();
}

class _AppliancesPartState extends State<AppliancesPart>
    with NetworkRetryState {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _installedDate = TextEditingController();

  TextEditingController _type = TextEditingController();
  TextEditingController _model = TextEditingController();
  TextEditingController _serialNumber = TextEditingController();

  TextEditingController _warrantyExpiry = TextEditingController();
  TextEditingController _lastMaintenanceDate = TextEditingController();
  TextEditingController _maintenanceNotes = TextEditingController();

  @override
  void dispose() {
    _type.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _warrantyExpiry.dispose();
    _lastMaintenanceDate.dispose();
    _maintenanceNotes.dispose();
    super.dispose();
  }

  final UnitData leaseRepository = UnitData();
  List<unit_appliance> leases = [];

  bool isLoading = false;
  Future<void> fetchLeases() async {
    //  try {
    final fetchedLeases =
        await leaseRepository.fetchApplianceData(widget.unit!.unitId!);
    setState(() {
      leases = fetchedLeases;
      isLoading = false;
    });
    //} catch (e) {
    setState(() {
      isLoading = false;
    });
    //print('Failed to load leases: $e');
    //}
  }

  Future<void> _loadDropdownCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await FetchAllcategories().fetchAllCategories();
      setState(() {
        _dropdownCategories = cats;
        _isLoadingCategories = false;
      });
    } catch (e) {
      logError('Error fetching categories in AddWorkOrderForMobile: ' +
          e.toString());
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadDropdownCategories();
      fetchLeases();
      futureAppliences = UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadDropdownCategories();
    fetchLeases();
    futureAppliences = UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
  }

  reload_screen() {
    setState(() {
      futureAppliences =
          UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
    });
  }

  DateTime? _selectedDate;
  //bool isLoading = false;
  bool iserror = false;

  //for table

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
        padding: const EdgeInsets.only(top: 20.0, left: 16, bottom: 10),
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
    // Web parity: CommonPagination clamps the page count to a floor of 1
    // (Math.max(1, ...)), so an empty search result reads "Page 1 of 1".
    // This also gives the `= 1` initialiser above its intended effect.
    if (totalrecords > 0) numorpages = (totalrecords / _rowsPerPage).ceil();
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

  //

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
      _currentPage = 0; // Reset to the first page when changing rows per page
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

  void handleEdit(unit_appliance appliance) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Edit_applience(
          unit: widget.unit,
          properties: widget.properties,
          appliance: appliance, // Pass the appliance data
        ),
      ),
    );

    // Refresh the table if changes were made
    if (result == true) {
      setState(() {
        futureAppliences =
            UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
        // Force a rebuild of the table
        _tableData.clear();
        isLoading = true;
      });
      await fetchLeases(); // Refresh the lease data
    }
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
              futureAppliences =
                  UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
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
    // Handle delete action
  }

  String? rentalOwnersid;
  int rentalownerCount = 0;
  int rentalOwnerCountLimit = 0;
  Future<void> fetchRentalOwneradded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/rental_owner/limitation/$id'),
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
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Name",
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
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
            //         Text("Description", style: TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
            //         SizedBox(width: 5),
            //       ],
            //     ),
            //   ),
            // ),
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

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    Text("           Category",
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

  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  bool _isLoadingCategories = false;

  List<String> brandList = [
    'Amana',
    'Badger',
    'Bosch',
    'Carrier',
    'Daikin',
    'Frigidaire',
    'GE',
    'Goodman',
    'InSinkErator',
    'KitchenAid',
    'Lennox',
    'LG',
    'Maytag',
    'Mitsubishi Electric',
    'Moen',
    'Rheem',
    'Samsung',
    'Trane',
    'Waste King',
    'Whirlpool',
    'York',
    'Other',
  ];
  List<String> statusList = ['Working', 'Needs Repair', "Out of Service"];

  String? _selectedBrand;
  String? _selectedStatus;
  // Add these to your state class
  List<Map<String, TextEditingController>> filterControllers = [];
  bool showFilters = false;

// Add this method to handle adding new filter
  void addNewFilter() {
    setState(() {
      filterControllers.add({
        'name': TextEditingController(),
        'size': TextEditingController(),
      });
    });
  }

// Add this method to remove filter
  void removeFilter(int index) {
    setState(() {
      filterControllers[index]['name']?.dispose();
      filterControllers[index]['size']?.dispose();
      filterControllers.removeAt(index);
    });
  }

  bool showFiltersSection = false;
  @override
  Widget build(BuildContext context) {
    // This view lives inside another screen's tab, so it shows the
    // compact offline state rather than taking over the whole page.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    final dateProvider = Provider.of<DateProvider>(context);
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  if (MediaQuery.of(context).size.width < 500)
                    const SizedBox(
                      width: 10,
                    ),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(
                      width: 20,
                    ),
                  Text(
                    'Unit Infrastructure',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 500 ? 17 : 20,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),

                  // SizedBox(
                  //   width: 10,
                  // ),
                  // Padding(
                  //   padding: const EdgeInsets.all(8.0),
                  //   child: GestureDetector(
                  //     // onTap: () {
                  //     //   _name.clear();
                  //     //   _description.clear();
                  //     //   _installedDate.clear();
                  //     //   _serialNumber.clear();
                  //     //   _model.clear();
                  //     //   _type.clear();
                  //     //   _warrantyExpiry.clear();
                  //     //   _lastMaintenanceDate.clear();
                  //     //   _maintenanceNotes.clear();
                  //     //   _selectedDropdownCategory = null;
                  //     //   _selectedBrand = null;
                  //     //   _selectedStatus = null;
                  //     //   // Clear filters
                  //     //   for (var controllers in filterControllers) {
                  //     //     controllers['name']?.dispose();
                  //     //     controllers['size']?.dispose();
                  //     //   }
                  //     //   filterControllers.clear();
                  //     //   showFiltersSection = false;
                  //     //
                  //     //   showDialog(
                  //     //     context: context,
                  //     //     builder: (BuildContext context) {
                  //     //       return StatefulBuilder(
                  //     //         builder:
                  //     //             (BuildContext context, StateSetter setState) {
                  //     //           return Dialog(
                  //     //             backgroundColor: Colors.white,
                  //     //             surfaceTintColor: Colors.white,
                  //     //             child:
                  //     //             SingleChildScrollView(
                  //     //               child: SizedBox(
                  //     //                 width: 800,
                  //     //                 child: Padding(
                  //     //                   padding: const EdgeInsets.all(8.0),
                  //     //                   child: Form(
                  //     //                     key: _formKey,
                  //     //                     child: Column(
                  //     //                       crossAxisAlignment:
                  //     //                           CrossAxisAlignment.start,
                  //     //                       mainAxisSize: MainAxisSize.min,
                  //     //                       children: [
                  //     //                         Row(
                  //     //                           children: [
                  //     //                             Text(
                  //     //                               "Add Home Systems",
                  //     //                               style: TextStyle(
                  //     //                                   fontWeight:
                  //     //                                       FontWeight.bold,
                  //     //                                   fontSize: 16,
                  //     //                                   color: blueColor),
                  //     //                             ),
                  //     //                           ],
                  //     //                         ),
                  //     //                         SizedBox(
                  //     //                           height: 20,
                  //     //                         ),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Name',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         CustomTextFormField(
                  //     //                           labelText: '',
                  //     //                           hintText: 'Enter Name',
                  //     //                           controller: _name,
                  //     //                           keyboardType:
                  //     //                               TextInputType.text,
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Description',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         CustomTextFormField(
                  //     //                           labelText: '',
                  //     //                           hintText: 'Enter description',
                  //     //                           controller: _description,
                  //     //                           keyboardType:
                  //     //                               TextInputType.text,
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Category',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         SizedBox(height: 4),
                  //     //                         //categories dropdwoun
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               const EdgeInsets.all(8.0),
                  //     //                           child:
                  //     //                               DropdownButtonHideUnderline(
                  //     //                             child: DropdownButton2<
                  //     //                                 allcategories_model>(
                  //     //                               isExpanded: true,
                  //     //                               hint: Text(_isLoadingCategories
                  //     //                                   ? 'Loading categories...'
                  //     //                                   : 'Select Category'),
                  //     //                               value: _dropdownCategories
                  //     //                                       .contains(
                  //     //                                           _selectedDropdownCategory)
                  //     //                                   ? _selectedDropdownCategory
                  //     //                                   : null,
                  //     //                               items: _dropdownCategories
                  //     //                                   .map((cat) {
                  //     //                                 return DropdownMenuItem<
                  //     //                                     allcategories_model>(
                  //     //                                   value: cat,
                  //     //                                   child: Text(
                  //     //                                       cat.name ?? ''),
                  //     //                                 );
                  //     //                               }).toList(),
                  //     //                               // onChanged: _isLoadingCategories
                  //     //                               //     ? null // disables dropdown while loading
                  //     //                               //     : (allcategories_model? newValue) {
                  //     //                               //   setState(() {
                  //     //                               //     _selectedDropdownCategory = newValue;
                  //     //                               //     // _showTextField =
                  //     //                               //     //     newValue?.name == 'Other';
                  //     //                               //   });
                  //     //                               // },
                  //     //                               onChanged:
                  //     //                                   _isLoadingCategories
                  //     //                                       ? null // disables dropdown while loading
                  //     //                                       : (allcategories_model?
                  //     //                                           newValue) {
                  //     //                                           setState(() {
                  //     //                                             _selectedDropdownCategory =
                  //     //                                                 newValue;
                  //     //                                             // Don't show filters section immediately for HVAC
                  //     //                                             showFiltersSection =
                  //     //                                                 false;
                  //     //                                             // Clear any existing filters
                  //     //                                             for (var controllers
                  //     //                                                 in filterControllers) {
                  //     //                                               controllers[
                  //     //                                                       'name']
                  //     //                                                   ?.dispose();
                  //     //                                               controllers[
                  //     //                                                       'size']
                  //     //                                                   ?.dispose();
                  //     //                                             }
                  //     //                                             filterControllers
                  //     //                                                 .clear();
                  //     //                                           });
                  //     //                                         },
                  //     //                               buttonStyleData:
                  //     //                                   ButtonStyleData(
                  //     //                                 height: 45,
                  //     //                                 padding:
                  //     //                                     const EdgeInsets.only(
                  //     //                                         left: 14,
                  //     //                                         right: 14),
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(6),
                  //     //                                   color: Colors.white,
                  //     //                                 ),
                  //     //                                 elevation: 2,
                  //     //                               ),
                  //     //                               iconStyleData:
                  //     //                                   const IconStyleData(
                  //     //                                 icon: Icon(Icons
                  //     //                                     .arrow_drop_down),
                  //     //                                 iconSize: 24,
                  //     //                                 iconEnabledColor:
                  //     //                                     Color(0xFFb0b6c3),
                  //     //                                 iconDisabledColor:
                  //     //                                     Colors.grey,
                  //     //                               ),
                  //     //                               dropdownStyleData:
                  //     //                                   DropdownStyleData(
                  //     //                                 maxHeight: 250,
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(6),
                  //     //                                   color: Colors.white,
                  //     //                                 ),
                  //     //                                 scrollbarTheme:
                  //     //                                     ScrollbarThemeData(
                  //     //                                   radius: const Radius
                  //     //                                       .circular(6),
                  //     //                                   thickness:
                  //     //                                       MaterialStateProperty
                  //     //                                           .all(6),
                  //     //                                   thumbVisibility:
                  //     //                                       MaterialStateProperty
                  //     //                                           .all(true),
                  //     //                                 ),
                  //     //                               ),
                  //     //                               menuItemStyleData:
                  //     //                                   const MenuItemStyleData(
                  //     //                                 height: 50,
                  //     //                                 padding: EdgeInsets.only(
                  //     //                                     left: 14, right: 14),
                  //     //                               ),
                  //     //                             ),
                  //     //                           ),
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Type',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         CustomTextFormField(
                  //     //                           labelText: '',
                  //     //                           hintText: 'Enter type',
                  //     //                           controller: _type,
                  //     //                           keyboardType:
                  //     //                               TextInputType.name,
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Brand',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               const EdgeInsets.all(8.0),
                  //     //                           child:
                  //     //                               DropdownButtonHideUnderline(
                  //     //                             child:
                  //     //                                 DropdownButton2<String>(
                  //     //                               isExpanded: true,
                  //     //                               hint: const Text(
                  //     //                                   'Select Brand'),
                  //     //                               value: brandList.contains(
                  //     //                                       _selectedBrand)
                  //     //                                   ? _selectedBrand
                  //     //                                   : null,
                  //     //                               items:
                  //     //                                   brandList.map((brand) {
                  //     //                                 return DropdownMenuItem<
                  //     //                                     String>(
                  //     //                                   value: brand,
                  //     //                                   child: Text(brand),
                  //     //                                 );
                  //     //                               }).toList(),
                  //     //                               onChanged:
                  //     //                                   (String? newValue) {
                  //     //                                 setState(() {
                  //     //                                   _selectedBrand =
                  //     //                                       newValue;
                  //     //                                 });
                  //     //                               },
                  //     //                               buttonStyleData:
                  //     //                                   ButtonStyleData(
                  //     //                                 height: 45,
                  //     //                                 padding: const EdgeInsets
                  //     //                                     .symmetric(
                  //     //                                     horizontal: 14),
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(6),
                  //     //                                   color: Colors.white,
                  //     //                                 ),
                  //     //                                 elevation: 2,
                  //     //                               ),
                  //     //                               iconStyleData:
                  //     //                                   const IconStyleData(
                  //     //                                 icon: Icon(Icons
                  //     //                                     .arrow_drop_down),
                  //     //                                 iconSize: 24,
                  //     //                                 iconEnabledColor:
                  //     //                                     Color(0xFFb0b6c3),
                  //     //                                 iconDisabledColor:
                  //     //                                     Colors.grey,
                  //     //                               ),
                  //     //                               dropdownStyleData:
                  //     //                                   DropdownStyleData(
                  //     //                                 maxHeight: 250,
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(6),
                  //     //                                   color: Colors.white,
                  //     //                                 ),
                  //     //                                 scrollbarTheme:
                  //     //                                     ScrollbarThemeData(
                  //     //                                   radius: const Radius
                  //     //                                       .circular(6),
                  //     //                                   thickness:
                  //     //                                       MaterialStateProperty
                  //     //                                           .all(6),
                  //     //                                   thumbVisibility:
                  //     //                                       MaterialStateProperty
                  //     //                                           .all(true),
                  //     //                                 ),
                  //     //                               ),
                  //     //                               menuItemStyleData:
                  //     //                                   const MenuItemStyleData(
                  //     //                                 height: 50,
                  //     //                                 padding:
                  //     //                                     EdgeInsets.symmetric(
                  //     //                                         horizontal: 14),
                  //     //                               ),
                  //     //                             ),
                  //     //                           ),
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding: const EdgeInsets.only(
                  //     //                               left: 10),
                  //     //                           child: Text(
                  //     //                             'Model',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         CustomTextFormField(
                  //     //                           labelText: '',
                  //     //                           hintText: 'Enter model',
                  //     //                           controller: _model,
                  //     //                           keyboardType:
                  //     //                               TextInputType.text,
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Serial Number',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         CustomTextFormField(
                  //     //                           labelText: '',
                  //     //                           hintText: 'Enter serial number',
                  //     //                           controller: _serialNumber,
                  //     //                           keyboardType:
                  //     //                               TextInputType.text,
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Installed Date',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         dateField(
                  //     //                             'Installed Date',
                  //     //                             _installedDate,
                  //     //                             context,
                  //     //                             setState),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Warranty Expiry',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         dateField(
                  //     //                             'Warranty Expiry',
                  //     //                             _warrantyExpiry,
                  //     //                             context,
                  //     //                             setState),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Last Maintenance Date',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         dateField(
                  //     //                             'Last Maintenance Date',
                  //     //                             _lastMaintenanceDate,
                  //     //                             context,
                  //     //                             setState),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Status',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               const EdgeInsets.all(8.0),
                  //     //                           child:
                  //     //                               DropdownButtonHideUnderline(
                  //     //                             child:
                  //     //                                 DropdownButton2<String>(
                  //     //                               isExpanded: true,
                  //     //                               hint: const Text(
                  //     //                                   'Select Status'),
                  //     //                               value: statusList.contains(
                  //     //                                       _selectedStatus)
                  //     //                                   ? _selectedStatus
                  //     //                                   : null,
                  //     //                               items: statusList
                  //     //                                   .map((status) {
                  //     //                                 return DropdownMenuItem<
                  //     //                                     String>(
                  //     //                                   value: status,
                  //     //                                   child: Text(status),
                  //     //                                 );
                  //     //                               }).toList(),
                  //     //                               onChanged:
                  //     //                                   (String? newValue) {
                  //     //                                 setState(() {
                  //     //                                   _selectedStatus =
                  //     //                                       newValue;
                  //     //                                 });
                  //     //                               },
                  //     //                               buttonStyleData:
                  //     //                                   ButtonStyleData(
                  //     //                                 height: 45,
                  //     //                                 padding: const EdgeInsets
                  //     //                                     .symmetric(
                  //     //                                     horizontal: 14),
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(6),
                  //     //                                   color: Colors.white,
                  //     //                                 ),
                  //     //                                 elevation: 2,
                  //     //                               ),
                  //     //                               iconStyleData:
                  //     //                                   const IconStyleData(
                  //     //                                 icon: Icon(Icons
                  //     //                                     .arrow_drop_down),
                  //     //                                 iconSize: 24,
                  //     //                                 iconEnabledColor:
                  //     //                                     Color(0xFFb0b6c3),
                  //     //                                 iconDisabledColor:
                  //     //                                     Colors.grey,
                  //     //                               ),
                  //     //                               dropdownStyleData:
                  //     //                                   DropdownStyleData(
                  //     //                                 maxHeight: 250,
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(6),
                  //     //                                   color: Colors.white,
                  //     //                                 ),
                  //     //                                 scrollbarTheme:
                  //     //                                     ScrollbarThemeData(
                  //     //                                   radius: const Radius
                  //     //                                       .circular(6),
                  //     //                                   thickness:
                  //     //                                       MaterialStateProperty
                  //     //                                           .all(6),
                  //     //                                   thumbVisibility:
                  //     //                                       MaterialStateProperty
                  //     //                                           .all(true),
                  //     //                                 ),
                  //     //                               ),
                  //     //                               menuItemStyleData:
                  //     //                                   const MenuItemStyleData(
                  //     //                                 height: 50,
                  //     //                                 padding:
                  //     //                                     EdgeInsets.symmetric(
                  //     //                                         horizontal: 14),
                  //     //                               ),
                  //     //                             ),
                  //     //                           ),
                  //     //                         ),
                  //     //                         SizedBox(height: 8),
                  //     //                         Padding(
                  //     //                           padding:
                  //     //                               EdgeInsets.only(left: 10),
                  //     //                           child: Text(
                  //     //                             'Maintenance Notes',
                  //     //                             style: TextStyle(
                  //     //                                 fontWeight:
                  //     //                                     FontWeight.bold),
                  //     //                           ),
                  //     //                         ),
                  //     //                         CustomTextFormField(
                  //     //                           labelText: '',
                  //     //                           hintText: 'Enter notes',
                  //     //                           controller: _maintenanceNotes,
                  //     //                           keyboardType:
                  //     //                               TextInputType.text,
                  //     //                         ),
                  //     //                         const SizedBox(height: 16),
                  //     //                         // Add this after your Status dropdown
                  //     //                         if (_selectedDropdownCategory
                  //     //                                 ?.name ==
                  //     //                             'HVAC') ...[
                  //     //                           SizedBox(height: 16),
                  //     //                           Row(
                  //     //                             mainAxisAlignment:
                  //     //                                 MainAxisAlignment
                  //     //                                     .spaceBetween,
                  //     //                             children: [
                  //     //                               Text(
                  //     //                                 'Filters',
                  //     //                                 style: TextStyle(
                  //     //                                   fontWeight:
                  //     //                                       FontWeight.bold,
                  //     //                                   fontSize: 16,
                  //     //                                 ),
                  //     //                               ),
                  //     //                               ElevatedButton(
                  //     //                                 onPressed: () {
                  //     //                                   setState(() {
                  //     //                                     showFiltersSection =
                  //     //                                         true;
                  //     //                                     // Always add a new filter when button is clicked
                  //     //                                     filterControllers
                  //     //                                         .add({
                  //     //                                       'name':
                  //     //                                           TextEditingController(),
                  //     //                                       'size':
                  //     //                                           TextEditingController(),
                  //     //                                     });
                  //     //                                   });
                  //     //                                 },
                  //     //                                 style: ElevatedButton
                  //     //                                     .styleFrom(
                  //     //                                   backgroundColor:
                  //     //                                       blueColor,
                  //     //                                   shape:
                  //     //                                       RoundedRectangleBorder(
                  //     //                                     borderRadius:
                  //     //                                         BorderRadius
                  //     //                                             .circular(8),
                  //     //                                   ),
                  //     //                                 ),
                  //     //                                 child: Text('Add Filter',
                  //     //                                     style: TextStyle(
                  //     //                                         color: Colors
                  //     //                                             .white)),
                  //     //                               ),
                  //     //                             ],
                  //     //                           ),
                  //     //                           Text(
                  //     //                             'Optional: Add filters for HVAC systems',
                  //     //                             style: TextStyle(
                  //     //                               color: Colors.grey,
                  //     //                               fontSize: 12,
                  //     //                             ),
                  //     //                           ),
                  //     //                           SizedBox(height: 8),
                  //     //                           if (showFiltersSection) ...[
                  //     //                             ...filterControllers
                  //     //                                 .asMap()
                  //     //                                 .entries
                  //     //                                 .map((entry) {
                  //     //                               int index = entry.key;
                  //     //                               var controllers =
                  //     //                                   entry.value;
                  //     //                               return Container(
                  //     //                                 margin: EdgeInsets.only(
                  //     //                                     bottom: 16),
                  //     //                                 padding:
                  //     //                                     EdgeInsets.all(16),
                  //     //                                 decoration: BoxDecoration(
                  //     //                                   border: Border.all(
                  //     //                                       color: Colors
                  //     //                                           .grey.shade300),
                  //     //                                   borderRadius:
                  //     //                                       BorderRadius
                  //     //                                           .circular(8),
                  //     //                                 ),
                  //     //                                 child: Column(
                  //     //                                   children: [
                  //     //                                     Row(
                  //     //                                       mainAxisAlignment:
                  //     //                                           MainAxisAlignment
                  //     //                                               .spaceBetween,
                  //     //                                       children: [
                  //     //                                         Text(
                  //     //                                             'Filter ${index + 1}'),
                  //     //                                         IconButton(
                  //     //                                           icon: Icon(
                  //     //                                               Icons
                  //     //                                                   .remove_circle_outline,
                  //     //                                               color: Colors
                  //     //                                                   .red),
                  //     //                                           onPressed: () {
                  //     //                                             setState(() {
                  //     //                                               removeFilter(
                  //     //                                                   index);
                  //     //                                             });
                  //     //                                           },
                  //     //                                         ),
                  //     //                                       ],
                  //     //                                     ),
                  //     //                                     SizedBox(height: 8),
                  //     //                                     CustomTextFormField(
                  //     //                                       labelText: '',
                  //     //                                       hintText:
                  //     //                                           'Filter Name',
                  //     //                                       controller:
                  //     //                                           controllers[
                  //     //                                               'name']!,
                  //     //                                       keyboardType:
                  //     //                                           TextInputType
                  //     //                                               .text,
                  //     //                                     ),
                  //     //                                     SizedBox(height: 8),
                  //     //                                     CustomTextFormField(
                  //     //                                       labelText: '',
                  //     //                                       hintText:
                  //     //                                           'Filter Size (e.g., 16x20x1)',
                  //     //                                       controller:
                  //     //                                           controllers[
                  //     //                                               'size']!,
                  //     //                                       keyboardType:
                  //     //                                           TextInputType
                  //     //                                               .text,
                  //     //                                     ),
                  //     //                                   ],
                  //     //                                 ),
                  //     //                               );
                  //     //                             }).toList(),
                  //     //                           ]
                  //     //                         ],
                  //     //                         const SizedBox(height: 16),
                  //     //                         Row(
                  //     //                           mainAxisAlignment:
                  //     //                               MainAxisAlignment.start,
                  //     //                           children: [
                  //     //                             SizedBox(
                  //     //                               width: 10,
                  //     //                             ),
                  //     //                             Expanded(
                  //     //                               child: ElevatedButton(
                  //     //                                 style: ElevatedButton
                  //     //                                     .styleFrom(
                  //     //                                   backgroundColor:
                  //     //                                       blueColor,
                  //     //                                   shape:
                  //     //                                       RoundedRectangleBorder(
                  //     //                                     borderRadius:
                  //     //                                         BorderRadius
                  //     //                                             .circular(8),
                  //     //                                   ),
                  //     //                                 ),
                  //     //                                 onPressed: () async {
                  //     //                                   if (_name
                  //     //                                           .text.isEmpty ||
                  //     //                                       _description
                  //     //                                           .text.isEmpty ||
                  //     //                                       _installedDate
                  //     //                                           .text.isEmpty ||
                  //     //                                       _selectedDropdownCategory ==
                  //     //                                           null || // Add validation for required fields
                  //     //                                       _selectedStatus ==
                  //     //                                           null ||
                  //     //                                       _selectedBrand ==
                  //     //                                           null) {
                  //     //                                     setState(() =>
                  //     //                                         iserror = true);
                  //     //                                   } else {
                  //     //                                     setState(() {
                  //     //                                       isLoading = true;
                  //     //                                       iserror = false;
                  //     //                                     });
                  //     //
                  //     //                                     SharedPreferences
                  //     //                                         prefs =
                  //     //                                         await SharedPreferences
                  //     //                                             .getInstance();
                  //     //                                     String? id =
                  //     //                                         prefs.getString(
                  //     //                                             "adminId");
                  //     //                                     List<
                  //     //                                             Map<String,
                  //     //                                                 dynamic>>
                  //     //                                         filters =
                  //     //                                         showFiltersSection
                  //     //                                             ? filterControllers
                  //     //                                                 .map(
                  //     //                                                     (controller) {
                  //     //                                                 return {
                  //     //                                                   "filter_name":
                  //     //                                                       controller['name']?.text ??
                  //     //                                                           '',
                  //     //                                                   "filter_size":
                  //     //                                                       controller['size']?.text ??
                  //     //                                                           '',
                  //     //                                                 };
                  //     //                                               }).toList()
                  //     //                                             : [];
                  //     //
                  //     //                                     // Generate filters list based on category
                  //     //                                     List<
                  //     //                                             Map<String,
                  //     //                                                 dynamic>>
                  //     //                                         finalFilters = [];
                  //     //
                  //     //                                     if (_selectedDropdownCategory
                  //     //                                                 ?.name ==
                  //     //                                             'HVAC' &&
                  //     //                                         showFiltersSection) {
                  //     //                                       for (int i = 0;
                  //     //                                           i <
                  //     //                                               filterControllers
                  //     //                                                   .length;
                  //     //                                           i++) {
                  //     //                                         // Add a delay to ensure unique timestamps
                  //     //                                         await Future.delayed(
                  //     //                                             Duration(
                  //     //                                                 milliseconds:
                  //     //                                                     2));
                  //     //                                         final uniqueId =
                  //     //                                             DateTime.now()
                  //     //                                                 .millisecondsSinceEpoch
                  //     //                                                 .toString();
                  //     //                                         final controller =
                  //     //                                             filterControllers[
                  //     //                                                 i];
                  //     //                                         finalFilters.add({
                  //     //                                           "filter_id":
                  //     //                                               uniqueId,
                  //     //                                           "filter_name":
                  //     //                                               controller['name']
                  //     //                                                       ?.text ??
                  //     //                                                   '',
                  //     //                                           "filter_size":
                  //     //                                               controller['size']
                  //     //                                                       ?.text ??
                  //     //                                                   '',
                  //     //                                         });
                  //     //                                       }
                  //     //                                     }
                  //     //
                  //     //                                     // Single API call with the correct filters
                  //     //                                     await Properies_summery_Repo()
                  //     //                                         .addappliances(
                  //     //                                       adminId: id,
                  //     //                                       unitId: widget
                  //     //                                           .unit?.unitId,
                  //     //                                       appliancename:
                  //     //                                           _name.text,
                  //     //                                       appliancedescription:
                  //     //                                           _description
                  //     //                                               .text,
                  //     //                                       installeddate:
                  //     //                                           _installedDate
                  //     //                                               .text,
                  //     //                                       type: _type.text,
                  //     //                                       brand:
                  //     //                                           _selectedBrand,
                  //     //                                       model: _model.text,
                  //     //                                       serialNumber:
                  //     //                                           _serialNumber
                  //     //                                               .text,
                  //     //                                       warrantyExpiry:
                  //     //                                           _warrantyExpiry
                  //     //                                                   .text
                  //     //                                                   .isNotEmpty
                  //     //                                               ? _warrantyExpiry
                  //     //                                                   .text
                  //     //                                               : null,
                  //     //                                       lastMaintenanceDate:
                  //     //                                           _lastMaintenanceDate
                  //     //                                                   .text
                  //     //                                                   .isNotEmpty
                  //     //                                               ? _lastMaintenanceDate
                  //     //                                                   .text
                  //     //                                               : null,
                  //     //                                       maintenanceNotes:
                  //     //                                           _maintenanceNotes
                  //     //                                               .text,
                  //     //                                       status:
                  //     //                                           _selectedStatus,
                  //     //                                       categoryId:
                  //     //                                           _selectedDropdownCategory
                  //     //                                                   ?.categoryId ??
                  //     //                                               "",
                  //     //                                       filters:
                  //     //                                           finalFilters,
                  //     //                                     )
                  //     //                                         .then((value) {
                  //     //                                       setState(() {
                  //     //                                         isLoading = false;
                  //     //                                         leases.add(
                  //     //                                             unit_appliance(
                  //     //                                           applianceName:
                  //     //                                               _name.text,
                  //     //                                           applianceDescription:
                  //     //                                               _description
                  //     //                                                   .text,
                  //     //                                           installedDate:
                  //     //                                               _installedDate
                  //     //                                                   .text,
                  //     //                                           adminId: id,
                  //     //                                           unitId: widget
                  //     //                                               .unit
                  //     //                                               ?.unitId,
                  //     //                                           type:
                  //     //                                               _type.text,
                  //     //                                           brand:
                  //     //                                               _selectedBrand,
                  //     //                                           model:
                  //     //                                               _model.text,
                  //     //                                           serialNumber:
                  //     //                                               _serialNumber
                  //     //                                                   .text,
                  //     //                                           warrantyExpiry:
                  //     //                                               _warrantyExpiry
                  //     //                                                   .text,
                  //     //                                           lastMaintenanceDate:
                  //     //                                               _lastMaintenanceDate
                  //     //                                                   .text,
                  //     //                                           maintenanceNotes:
                  //     //                                               _maintenanceNotes
                  //     //                                                   .text,
                  //     //                                           status:
                  //     //                                               _selectedStatus,
                  //     //                                           categoryId:
                  //     //                                               _selectedDropdownCategory
                  //     //                                                   ?.categoryId,
                  //     //                                           filters:
                  //     //                                               filters,
                  //     //                                         ));
                  //     //                                       });
                  //     //                                       reload_screen();
                  //     //                                       Navigator.pop(
                  //     //                                           context, true);
                  //     //                                     }).catchError((e) {
                  //     //                                       setState(() =>
                  //     //                                           isLoading =
                  //     //                                               false);
                  //     //                                       // Show error message to user
                  //     //                                       ScaffoldMessenger
                  //     //                                               .of(context)
                  //     //                                           .showSnackBar(
                  //     //                                         SnackBar(
                  //     //                                             content: Text(
                  //     //                                                 'Failed to add appliance: ${e.toString()}')),
                  //     //                                       );
                  //     //                                     });
                  //     //                                   }
                  //     //                                 },
                  //     //                                 child: const Text('Save',
                  //     //                                     style: TextStyle(
                  //     //                                         color: Colors
                  //     //                                             .white)),
                  //     //                               ),
                  //     //                             ),
                  //     //                             SizedBox(width: 10),
                  //     //                             Expanded(
                  //     //                               child: TextButton(
                  //     //                                 onPressed: () =>
                  //     //                                     Navigator.of(context)
                  //     //                                         .pop(),
                  //     //                                 child:
                  //     //                                     const Text('Cancel'),
                  //     //                               ),
                  //     //                             ),
                  //     //                           ],
                  //     //                         ),
                  //     //                         if (iserror)
                  //     //                           const Padding(
                  //     //                             padding:
                  //     //                                 EdgeInsets.only(top: 8.0),
                  //     //                             child: Text(
                  //     //                               "Please fill in all fields correctly.",
                  //     //                               style: TextStyle(
                  //     //                                   color:
                  //     //                                       Colors.redAccent),
                  //     //                             ),
                  //     //                           )
                  //     //                       ],
                  //     //                     ),
                  //     //                   ),
                  //     //                 ),
                  //     //               ),
                  //     //             ),
                  //     //           );
                  //     //         },
                  //     //       );
                  //     //     },
                  //     //   );
                  //     // },
                  //     onTap: () async {
                  //       final result =
                  //           await Navigator.of(context).push(MaterialPageRoute(
                  //               builder: (context) => AddApplience(
                  //                     unit: widget.unit,
                  //                   )));
                  //       if (result == true) {
                  //         setState(() {
                  //           futureAppliences = UnitData()
                  //               .fetchApplianceData(widget.unit?.unitId ?? "");
                  //         });
                  //       }
                  //     },
                  //     child: Container(
                  //       decoration: BoxDecoration(
                  //         borderRadius: BorderRadius.circular(10),
                  //         border: Border.all(
                  //           color: blueColor,
                  //           width: 1,
                  //         ),
                  //       ),
                  //       height:
                  //           MediaQuery.of(context).size.width < 500 ? 40 : 50,
                  //       width:
                  //           MediaQuery.of(context).size.width < 500 ? 70 : 80,
                  //       child: Center(
                  //         child: Text(
                  //           'Add',
                  //           style: TextStyle(
                  //               fontWeight: FontWeight.bold,
                  //               fontSize:
                  //                   MediaQuery.of(context).size.width < 500
                  //                       ? 14
                  //                       : 20,
                  //               color: blueColor),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              if (MediaQuery.of(context).size.width < 500)
                const SizedBox(
                  height: 1,
                ),
              if (MediaQuery.of(context).size.width > 500)
                const SizedBox(
                  height: 7,
                ),
              if (MediaQuery.of(context).size.width < 500)
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
                      return  Center(
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              _buildHeaders(),
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'No records found',style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: blueColor),),
                              ),
                              SizedBox(height: 10),
                            ],
                          ));
                    } else {
                      var data = snapshot.data!;
                      if (searchValue == null || searchValue!.isEmpty) {
                        data = snapshot.data!;
                      } else if (searchValue == "All") {
                        data = snapshot.data!;
                      } else if (searchValue!.isNotEmpty) {
                        data = snapshot.data!
                            .where((rentals) => (rentals.applianceName ?? '')
                                .toLowerCase()
                                .contains(searchValue!.toLowerCase()))
                            .toList();
                      } else {
                        data = snapshot.data!
                            .where((rentals) =>
                                rentals.applianceName == searchValue)
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
                            const SizedBox(height: 5),
                            _buildHeaders(),
                            const SizedBox(height: 10),
                            Container(
                              // decoration: BoxDecoration(
                              //     border: Border.all(
                              //         color:
                              //             Color.fromRGBO(152, 162, 179, .5))),
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
                                  bool isExpanded = expandedIndex == index;
                                  unit_appliance rentals = entry.value;
                                  //return CustomExpansionTile(data: Propertytype, index: index);
                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: index % 2 != 0
                                          ? const Color(0xFFF4F8FF)
                                          : Colors.white,
                                      border: Border.all(
                                          color: const Color(0xFFDBE0E5)),
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
                                                      if (expandedIndex ==
                                                          index) {
                                                        expandedIndex = null;
                                                      } else {
                                                        expandedIndex = index;
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 5),
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
                                                Expanded(
                                                  flex: 2,
                                                  child: InkWell(
                                                    onTap: () {
                                                      // Navigator.push(
                                                      //     context,
                                                      //     MaterialPageRoute(
                                                      //         builder: (context) =>
                                                      //             Rentalowners_summery(
                                                      //               rentalOwnersid: rentals.rentalownerId!,)));
                                                    },
                                                    child: Text(
                                                      '   ${rentals.applianceName}',
                                                      style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            .09),
                                                Expanded(
                                                  flex: 1,
                                                  child: Text(
                                                    '${rentals.categoryName}',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            .08),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isExpanded)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                            margin: const EdgeInsets.only(
                                                bottom: 20),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      FaIcon(
                                                        isExpanded
                                                            ? FontAwesomeIcons
                                                                .sortUp
                                                            : FontAwesomeIcons
                                                                .sortDown,
                                                        size: 50,
                                                        color:
                                                            Colors.transparent,
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
                                                                        'Install Date : ',
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color:
                                                                            blueColor), // Bold and black
                                                                  ),
                                                                  TextSpan(
                                                                    text: dateProvider
                                                                        .formatCurrentDate(
                                                                            '${rentals.installedDate}'),
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w700,
                                                                        color: Colors
                                                                            .grey), // Light and grey
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              height: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  .01,
                                                            ),
                                                            Text.rich(
                                                              TextSpan(
                                                                children: [
                                                                  TextSpan(
                                                                    text:
                                                                        'Brand : ',
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color:
                                                                            blueColor), // Bold and black
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        '${rentals.brand}',
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w700,
                                                                        color: Colors
                                                                            .grey), // Light and grey
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 15,
                                                            ),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .end,
                                                              children: [
                                                                GestureDetector(
                                                                  onTap: () {
                                                                    _showDeleteAlert(
                                                                        context,
                                                                        rentals
                                                                            .applianceId!);
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
                                                                          color:
                                                                              Colors.red,
                                                                        ),
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
                                                                    var check = await Navigator.push(
                                                                        context,
                                                                        MaterialPageRoute(
                                                                            builder: (context) => Edit_applience(
                                                                                  unit: widget.unit,
                                                                                  appliance: rentals,
                                                                                )));
                                                                    if (check ==
                                                                        true) {
                                                                      setState(
                                                                          () {
                                                                        futureAppliences =
                                                                            UnitData().fetchApplianceData(widget.unit?.unitId ??
                                                                                "");
                                                                      });
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
                                                                          color:
                                                                              Colors.green,
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
                                                                    Navigator
                                                                        .push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (context) =>
                                                                                ApplianceSummary(
                                                                          appliance:
                                                                              rentals,
                                                                          unit:
                                                                              widget.unit,
                                                                          properties:
                                                                              widget.properties,
                                                                        ),
                                                                      ),
                                                                    ).then(
                                                                        (value) {
                                                                      if (value ==
                                                                          true) {
                                                                        setState(
                                                                            () {
                                                                          futureAppliences =
                                                                              UnitData().fetchApplianceData(widget.unit?.unitId ?? "");
                                                                        });
                                                                      }
                                                                    });
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
                                                                          BorderRadius.circular(
                                                                              8),
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
                                                                          color:
                                                                              Colors.black,
                                                                        ),
                                                                        SizedBox(
                                                                            width:
                                                                                2),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 15,
                                                                ),
                                                              ],
                                                            ),
                                                          ],
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
                      return  Center(
                          child: Column(
                            children: [
                              SizedBox(height: 10),
                              _buildHeaders(),
                              SizedBox(height: 10),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  'No records found',style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: blueColor),),
                              ),
                              SizedBox(height: 10),
                            ],
                          ));
                    } else {
                      List<unit_appliance>? filteredData = [];
                      _tableData = snapshot.data!;
                      if (selectedRole == null && searchValue == "") {
                        filteredData = snapshot.data;
                      } else if (selectedRole == "All") {
                        filteredData = snapshot.data;
                      } else if (searchValue.isNotEmpty) {
                        filteredData = snapshot.data!
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
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                width: MediaQuery.of(context).size.width * .91,
                                child: Table(
                                  defaultColumnWidth:
                                      const IntrinsicColumnWidth(),
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
                                          // _buildDataCell('${_pagedData[i].rentalOwnerFirstName ?? ''} ${_pagedData[i].rentalOwnerLastName ?? ''}'),
                                          _buildDataCell(_pagedData[i]
                                              .applianceDescription!),
                                          _buildDataCell(
                                              _pagedData[i].installedDate!),
                                          Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const SizedBox(
                                                height: 14,
                                              ),
                                              Row(
                                                children: [
                                                  const SizedBox(
                                                    width: 25,
                                                  ),
                                                  InkWell(
                                                    onTap: () async {
                                                      _name.text = _tableData
                                                          .first.applianceName!;
                                                      _description.text = _tableData
                                                          .first
                                                          .applianceDescription!;
                                                      _installedDate.text =
                                                          _tableData.first
                                                              .installedDate!;
                                                      showDialog(
                                                        context: context,
                                                        builder: (BuildContext
                                                            context) {
                                                          return StatefulBuilder(
                                                            builder: (BuildContext
                                                                    context,
                                                                StateSetter
                                                                    setState) {
                                                              return AlertDialog(
                                                                backgroundColor:
                                                                    Colors
                                                                        .white,
                                                                surfaceTintColor:
                                                                    Colors
                                                                        .white,
                                                                title: const Text(
                                                                    'Edit Appliances'),
                                                                content: Form(
                                                                  key: _formKey,
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      CustomTextFormField(
                                                                        labelText:
                                                                            'Name',
                                                                        hintText:
                                                                            'Enter Name',
                                                                        keyboardType:
                                                                            TextInputType.text,
                                                                        controller:
                                                                            _name,
                                                                        // validator: (value) {
                                                                        //   if (value == null || value.isEmpty) {
                                                                        //     return 'Please enter name';
                                                                        //   }
                                                                        //   return null;
                                                                        // },
                                                                      ),
                                                                      CustomTextFormField(
                                                                        labelText:
                                                                            'Description',
                                                                        hintText:
                                                                            'Enter description',
                                                                        keyboardType:
                                                                            TextInputType.text,
                                                                        controller:
                                                                            _description,
                                                                        // validator: (value) {
                                                                        //   if (value == null || value.isEmpty) {
                                                                        //     return 'Please enter description';
                                                                        //   }
                                                                        //   return null;
                                                                        // },
                                                                      ),
                                                                      GestureDetector(
                                                                        onTap:
                                                                            () {
                                                                          showDatePicker(
                                                                            context:
                                                                                context,
                                                                            initialDate:
                                                                                DateTime.now(),
                                                                            firstDate:
                                                                                DateTime(2000),
                                                                            lastDate:
                                                                                DateTime(2100),
                                                                            builder:
                                                                                (BuildContext context, Widget? child) {
                                                                              return Theme(
                                                                                data: ThemeData.light().copyWith(
                                                                                  // primaryColor: blueColor,
                                                                                  //  hintColor: blueColor,
                                                                                  colorScheme: ColorScheme.light(
                                                                                    primary: blueColor,
                                                                                    // onPrimary:blueColor,
                                                                                    //  surface: blueColor,
                                                                                    onSurface: Colors.black,
                                                                                  ),
                                                                                  buttonTheme: const ButtonThemeData(
                                                                                    textTheme: ButtonTextTheme.primary,
                                                                                  ),
                                                                                ),
                                                                                child: child!,
                                                                              );
                                                                            },
                                                                          ).then(
                                                                              (date) {
                                                                            if (date !=
                                                                                null) {
                                                                              setState(() {
                                                                                _selectedDate = date;
                                                                                _installedDate.text = formatDate(date.toString());
                                                                              });
                                                                            }
                                                                          });
                                                                        },
                                                                        child:
                                                                            AbsorbPointer(
                                                                          child:
                                                                              CustomTextFormField(
                                                                            labelText:
                                                                                'Date',
                                                                            hintText:
                                                                                'Select Date',
                                                                            keyboardType:
                                                                                TextInputType.datetime,
                                                                            controller:
                                                                                _installedDate,
                                                                            // validator: (value) {
                                                                            //   if (value == null ||
                                                                            //       value.isEmpty) {
                                                                            //     return 'Please select date';
                                                                            //   }
                                                                            //   return null;
                                                                            // },
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.center,
                                                                        children: [
                                                                          Padding(
                                                                            padding:
                                                                                const EdgeInsets.all(8.0),
                                                                            child:
                                                                                Container(
                                                                              height: 42,
                                                                              width: 80,
                                                                              child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(backgroundColor: blueColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
                                                                                onPressed: () async {
                                                                                  if (_name.text.isEmpty || _description.text.isEmpty || _installedDate.text.isEmpty) {
                                                                                    setState(() {
                                                                                      iserror = true;
                                                                                    });
                                                                                  } else {
                                                                                    setState(() {
                                                                                      isLoading = true;
                                                                                      iserror = false;
                                                                                    });
                                                                                    SharedPreferences prefs = await SharedPreferences.getInstance();
                                                                                    String? id = prefs.getString("adminId");
                                                                                    Properies_summery_Repo()
                                                                                        .Editappliances(
                                                                                      applianceid: _tableData.first.applianceId,
                                                                                      adminId: id,
                                                                                      unitId: widget.unit?.unitId,
                                                                                      rentalId: widget.unit?.rentalId ?? widget.properties?.rentalId ?? "",
                                                                                      appliancename: _name.text,
                                                                                      appliancedescription: _description.text,
                                                                                      installeddate: reverseFormatDate(_installedDate.text),
                                                                                    )
                                                                                        .then((value) {
                                                                                      setState(() {
                                                                                        isLoading = false;
                                                                                      });
                                                                                      reload_screen();

                                                                                      Navigator.pop(context, true);
                                                                                    }).catchError((e) {
                                                                                      setState(() {
                                                                                        isLoading = false;
                                                                                      });
                                                                                    });
                                                                                  }
                                                                                },
                                                                                child: const Text(
                                                                                  'Save',
                                                                                  style: TextStyle(fontSize: 14, color: Colors.white),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          Padding(
                                                                            padding:
                                                                                const EdgeInsets.all(8.0),
                                                                            child:
                                                                                Container(
                                                                              decoration: BoxDecoration(
                                                                                color: Colors.white,
                                                                                borderRadius: BorderRadius.circular(8),
                                                                                boxShadow: [
                                                                                  BoxShadow(
                                                                                    color: Colors.black.withOpacity(0.25),
                                                                                    spreadRadius: 0,
                                                                                    blurRadius: 15,
                                                                                    offset: const Offset(0.5, 0.5), // Shadow moved to the right and bottom
                                                                                  )
                                                                                ],
                                                                              ),
                                                                              height: 40,
                                                                              width: 70,
                                                                              child: Center(
                                                                                child: GestureDetector(
                                                                                  onTap: () {
                                                                                    Navigator.of(context).pop();
                                                                                  },
                                                                                  child: const Text('Cancel'),
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      if (iserror)
                                                                        const Text(
                                                                          "Please fill in all fields correctly.",
                                                                          style:
                                                                              TextStyle(color: Colors.redAccent),
                                                                        )
                                                                    ],
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        },
                                                      );
                                                    },
                                                    child: Container(
                                                      child: FaIcon(
                                                        FontAwesomeIcons.edit,
                                                        size: 20,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: 10,
                                                  ),
                                                  InkWell(
                                                    onTap: () async {
                                                      _showDeleteAlert(
                                                          context,
                                                          _tableData.first
                                                              .applianceId!);
                                                    },
                                                    child: Container(
                                                      child: FaIcon(
                                                        FontAwesomeIcons
                                                            .trashCan,
                                                        size: 20,
                                                        color: blueColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
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

  Widget dateField(String label, TextEditingController controller,
      BuildContext context, StateSetter setState) {
    return GestureDetector(
      onTap: () {
        showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: ColorScheme.light(
                  primary: blueColor,
                  onSurface: Colors.black,
                ),
              ),
              child: child!,
            );
          },
        ).then((date) {
          if (date != null) {
            setState(() {
              controller.text = formatDate(date.toString());
            });
          }
        });
      },
      child: AbsorbPointer(
        child: CustomTextFormField(
          labelText: label,
          hintText: 'Select $label',
          controller: controller,
          keyboardType: TextInputType.datetime,
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
  final bool obscureText;
  final Widget? suffixIcon;

  const CustomTextFormField({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.keyboardType,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isFocused
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: TextFormField(
          focusNode: _focusNode,
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            // labelText: widget.labelText,
            hintText: widget.hintText,
            suffixIcon: widget.suffixIcon,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}
