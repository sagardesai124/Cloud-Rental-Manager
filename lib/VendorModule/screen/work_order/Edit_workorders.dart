import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../screens/Maintenance/Vendor/add_vendor.dart';
import '../../../widgets/VideoPlayerWidget.dart';
import '../../model/Edit_workorder.dart';
import '../../repository/edit_workorder.dart';

import '../../../constant/constant.dart';
import '../../widgets/appbar.dart';
import '../../widgets/drawer_tiles.dart';
import '../../../widgets/titleBar.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../Model/All_categories_model.dart';
import '../../../repository/fetch_allcategories.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';

class Edit_Workorder extends StatefulWidget {
  EditData? property;
  final String workorderId;
  Edit_Workorder({super.key, required this.workorderId, this.property});
  @override
  State<Edit_Workorder> createState() => _Edit_WorkorderState();
}

class _Edit_WorkorderState extends State<Edit_Workorder> {
  final TextEditingController subject = TextEditingController();

  final TextEditingController other = TextEditingController();

  final TextEditingController perform = TextEditingController();
  final TextEditingController vendornote = TextEditingController();

  GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  bool form_valid = false;
  bool _isLoading = false;
  bool _isLoadingvendors = true;
  bool _isLoadingstaff = false;
  bool _isLoadingtenant = false;
  bool _Loading = false;
  bool _isLoadingCategories = false;
  Map<String, String> properties = {}; // Mapping of rental_id to rental_address
  Map<String, String> units = {}; // Mapping of unit_id to rental_unit
  String? _selectedPropertyId;
  String? _selectedProperty;
  String? _selectedUnitId;
  String? _selectedUnit;

  //for vendor
  Map<String, String> vendors = {};
  String? _selectedvendorsId;
  String? _selectedVendors;

  //for Staffmember
  Map<String, String> staffs = {};
  String? _selectedstaffId;
  String? _selectedStaffs;
  //for tenants
  Map<String, String> tenants = {};
  String? _selectedtenantId;
  String? _selectedTenants;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //_loadProperties();
    //  _loadVendor();
    // _loadStaff();
    // _loadTenant();
    fetchWorkordersDetails(widget.workorderId);
    _loadDropdownCategories();
    partsAndLabor.clear();
    // The two free-text fields a vendor can edit; typing has to re-evaluate
    // whether anything actually changed.
    vendornote.addListener(_onDirtyFieldChanged);
    _dateController.addListener(_onDirtyFieldChanged);
  }

  @override
  void dispose() {
    // Controllers handed to CustomTextField are released by that widget
    // (CustomTextFieldState in screens/Maintenance/Vendor/add_vendor.dart
    // disposes whatever controller it is given), so releasing them here as
    // well threw "used after being disposed" on close. Only the ones this
    // screen owns outright are released below.
    other.dispose();
    _dateController.removeListener(_onDirtyFieldChanged);
    _dateController.dispose();
    // Each parts-and-labour row owns its own controllers (addRow creates six,
    // the API mapping in fetchWorkordersDetails creates four), and the qty /
    // price ones carry listeners. They live in this list, so they have to be
    // released here too, not just the fields above.
    for (final row in partsAndLabor) {
      for (final value in row.values) {
        if (value is TextEditingController) {
          value.removeListener(_onDirtyFieldChanged);
          value.dispose();
        }
      }
    }
    super.dispose();
  }

  Future<void> fetchWorkordersDetails(String workorderId) async {
    //try {
    // await _loadProperties();
    EditData fetchedDetails =
    await WorkOrderRepository().fetchWorkordersDetails(workorderId);


    String? entryAllowedString;
    if (fetchedDetails.entryAllowed != null) {
      entryAllowedString = fetchedDetails.entryAllowed! ? 'Yes' : 'No';
    }
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      if (fetchedDetails.propertyData != null) {
        properties.addAll({
          "${fetchedDetails.propertyData!.rental_id}":
          "${fetchedDetails.propertyData!.address}"
        });
      }

      if (fetchedDetails.staffData != null)
        staffs.addAll({
          "${fetchedDetails.staffData!.staffmember_id}":
          "${fetchedDetails.staffData!.staffName}"
        });
      if (fetchedDetails.workOrderImages != null) {
        _imageUrls = fetchedDetails.workOrderImages!.map((fileName) {
          return '$fileName'; // Adjust the path as needed
        }).toList();
      }
      // print(fetchedDetails.rental.rentalAddress);
      subject.text = fetchedDetails.workSubject ?? '';
      _selectedstaffId = fetchedDetails.staffData?.staffName;
      // Set the selected dropdown category if it matches
      if (fetchedDetails.workCategory != null &&
          _dropdownCategories.isNotEmpty) {
        final match = _dropdownCategories
            .where((cat) => cat.name == fetchedDetails.workCategory)
            .firstOrNull;
        if (match != null) {
          _selectedDropdownCategory = match;
        }
      }
      perform.text = fetchedDetails.workPerformed ?? '';
      // Keep the status exactly as stored. Legacy orders carry values outside
      // the canonical list (e.g. "Pending"); _statusOptions widens the dropdown
      // to include it so the screen opens AND saving does not clear it.
      _selectedStatus = fetchedDetails.status;
      vendornote.text = fetchedDetails.vendorNotes ?? '';
      _dateController.text = fetchedDetails.date ?? '';
      _selectedOption = fetchedDetails.priority ?? 'Normal';
      _selectedPropertyId = fetchedDetails.rentalId;
      renderId = fetchedDetails.rentalId ?? '';
      _selectedUnitId = fetchedDetails.unitId;
      isChecked = fetchedDetails.isBillable ?? false;
      _selectedvendorsId =
      fetchedDetails.vendorId == null || fetchedDetails.vendorId!.isEmpty
          ? null
          : fetchedDetails.vendorId;
      _selectedstaffId = fetchedDetails.staffmemberId;
      _selectedtenantId =
      fetchedDetails.tenantId == null ? null : fetchedDetails.tenantId;
      _selectedEntry = entryAllowedString;

      // Whatever rows were on screen are about to be replaced wholesale; keep
      // them so their controllers get released instead of orphaned.
      final replacedRows = List<Map<String, dynamic>>.from(partsAndLabor);
      partsAndLabor =
          fetchedDetails.partsandchargeData?.map<Map<String, dynamic>>((data) {
            return {
              "parts_id": data.partsId,
              "qtyController": TextEditingController(
                  text: data.partsQuantity?.toString() ?? '0'),
              "selectedAccount": data.account ?? '',
              "descriptionController":
              TextEditingController(text: data.description ?? ''),
              "priceController": TextEditingController(
                  text: data.partsPrice?.toString() ?? '0.0'),
              "totalController": TextEditingController(
                  text: data.amount?.toString() ?? '0.0'),
            };
          }).toList() ??
              [];
      //partsAndLabor.clear();
      _disposeRowsAfterFrame(replacedRows);
      // The fetched rows carry no calculateTotal listener, so the dirty flag
      // has to be driven straight off their controllers.
      for (final row in partsAndLabor) {
        (row['qtyController'] as TextEditingController)
            .addListener(_onDirtyFieldChanged);
        (row['priceController'] as TextEditingController)
            .addListener(_onDirtyFieldChanged);
        (row['descriptionController'] as TextEditingController)
            .addListener(_onDirtyFieldChanged);
      }
      updateTotalAmount();

      // Snapshot for the no-op guard, taken from the same values that were
      // just seeded above (parts as plain strings, no controllers).
      initialVendorNote = fetchedDetails.vendorNotes ?? '';
      initialDate = fetchedDetails.date ?? '';
      initialSelectedStatus = fetchedDetails.status;
      initialSelectedpriority = fetchedDetails.priority ?? 'Normal';
      initialSelectedCategory = _selectedDropdownCategory?.name;
      initialSelectedimage = List<String>.from(_imageUrls);
      initialSelectedparts = fetchedDetails.partsandchargeData
              ?.map<Map<String, String>>((data) {
            return {
              'qty': data.partsQuantity?.toString() ?? '0',
              'account': data.account ?? '',
              'description': data.description ?? '',
              'price': data.partsPrice?.toString() ?? '0.0',
              'total': data.amount?.toString() ?? '0.0',
            };
          }).toList() ??
          <Map<String, String>>[];
      _dirtySnapshotReady = true;

      // totalAmount = calculateTotalAmount(partsAndLabor);
    });

    if (_selectedPropertyId != null) {
      _loadUnits(_selectedPropertyId!);
      if (_selectedUnitId != null) {
        _loadTenant(_selectedPropertyId!, _selectedUnitId!);
      }
    }
    // _loadUnits(renderId)
    /* if (_selectedProperty != null) {
      await _loadUnits(_selectedProperty!);
    }*/
    setState(() {
      _selectedUnit = fetchedDetails.unitId;
    });
    //} catch (e) {
    //print('Failed to fetch lease details: ${friendlyErrorMessage(e)}');
    //}
  }

  Future<void> _loadProperties() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http
          .get(Uri.parse('${Api_url}/api/rentals/rentals/$id'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> addresses = {};
        jsonResponse.forEach((data) {
          addresses[data['rental_id'].toString()] =
              data['rental_adress'].toString();
        });
        setState(() {
          properties = addresses;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch properties: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadUnits(String rentalId) async {
    /*setState(() {
      _isLoading = true;
    });*/
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    try {
      final response = await http
          .get(Uri.parse('$Api_url/api/unit/rental_unit/$rentalId'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> unitAddresses = {};
        jsonResponse.forEach((data) {
          unitAddresses[data['unit_id'].toString()] =
              data['rental_unit'].toString();
        });
        //  200 no hoy tyare _loadtennant
        setState(() {
          units = unitAddresses;
          _isLoading = false;
        });
      } else {
        _loadTenant(rentalId, unitId);
        throw Exception('Failed to load units');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      /*   ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch units: ${friendlyErrorMessage(e)}')),
      );*/
    }
  }

  //for vendor
  Future<void> _loadVendor() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingvendors = true;
    });
    try {
      final response = await http
          .get(Uri.parse('${Api_url}/api/vendor/vendors/$id'), headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> names = {};
        jsonResponse.forEach((data) {
          names[data['vendor_id'].toString()] = data['vendor_name'].toString();
        });

        setState(() {
          vendors = names;
          _isLoadingvendors = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingvendors = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadStaff() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingstaff = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/staffmember/staff_member/$id'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> staffnames = {};
        jsonResponse.forEach((data) {
          staffnames[data['staffmember_id'].toString()] =
              data['staffmember_name'].toString();
        });

        setState(() {
          staffs = staffnames;
          _isLoadingstaff = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingstaff = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch vendors: ${friendlyErrorMessage(e)}')),
      );
    }
  }

  Future<void> _loadTenant(String rentalId, String unitId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("vendor_id");
    String? token = prefs.getString('token');
    setState(() {
      _isLoadingtenant = true;
    });
    try {
      final response = await apiGet(
          Uri.parse('${Api_url}/api/leases/get_tenants/$rentalId/$unitId'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          });
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body)['data'];
        Map<String, String> tenantsnames = {};
        jsonResponse.forEach((data) {
          tenantsnames[data['tenant_id'].toString()] =
              data['tenant_firstName'].toString() +
                  " " +
                  data['tenant_lastName'].toString();
        });
        setState(() {
          tenants = tenantsnames;
          _isLoadingtenant = false;
        });
      } else {
        throw Exception('Failed to load data');
      }
    } catch (e) {
      setState(() {
        _isLoadingtenant = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch tenants: ${friendlyErrorMessage(e)}')),
      );
    }
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
      logError('Error fetching categories in EditWorkOrder: ' + e.toString());
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  // Snapshot of the loaded work order, scoped to the fields this screen lets a
  // vendor change. The PUT mails the manager, staff, vendor and tenant on every
  // success and has no server-side no-op detection, so the client has to refuse
  // an unchanged save (web parity: VendorAddWork.jsx checkForChanges).
  String? initialVendorNote;
  String? initialDate;
  String? initialSelectedCategory;
  String? initialSelectedStatus;
  String? initialSelectedpriority;
  List<String>? initialSelectedimage;
  // Plain values, not controllers: a controller snapshot could never compare
  // equal to the live row and would leak four controllers per part.
  List<Map<String, String>>? initialSelectedparts;
  bool _dirtySnapshotReady = false;
  bool _lastDirty = false;

  String _normDirty(dynamic v) => v == null ? '' : v.toString().trim();

  bool _imagesDiffer() {
    final cur = _imageUrls;
    final was = initialSelectedimage ?? const <String>[];
    if (cur.length != was.length) return true;
    for (var i = 0; i < cur.length; i++) {
      if (_normDirty(cur[i]) != _normDirty(was[i])) return true;
    }
    return false;
  }

  bool _partsDiffer() {
    final was = initialSelectedparts ?? const <Map<String, String>>[];
    if (partsAndLabor.length != was.length) return true;
    for (var i = 0; i < partsAndLabor.length; i++) {
      final c = partsAndLabor[i];
      final w = was[i];
      if (_normDirty(c['qtyController']?.text) != _normDirty(w['qty'])) {
        return true;
      }
      if (_normDirty(c['selectedAccount']) != _normDirty(w['account'])) {
        return true;
      }
      if (_normDirty(c['descriptionController']?.text) !=
          _normDirty(w['description'])) {
        return true;
      }
      if (_normDirty(c['priceController']?.text) != _normDirty(w['price'])) {
        return true;
      }
      if (_normDirty(c['totalController']?.text) != _normDirty(w['total'])) {
        return true;
      }
    }
    return false;
  }

  /// Only the fields a vendor can actually edit here. Subject, work performed,
  /// property, unit, assigned-to and entry-allowed are hard-disabled, and the
  /// billable / tenant block is commented out in both layouts, so none of them
  /// can differ.
  bool _hasWorkOrderChanges() {
    if (!_dirtySnapshotReady) return false; // nothing loaded yet => not dirty
    return _normDirty(_selectedDropdownCategory?.name) !=
            _normDirty(initialSelectedCategory) ||
        _normDirty(_selectedStatus) != _normDirty(initialSelectedStatus) ||
        _normDirty(_selectedOption) != _normDirty(initialSelectedpriority) ||
        _normDirty(vendornote.text) != _normDirty(initialVendorNote) ||
        _normDirty(_dateController.text) != _normDirty(initialDate) ||
        _imagesDiffer() ||
        _partsDiffer();
  }

  /// Text fields do not rebuild the screen on a keystroke, so the Update
  /// button would stay disabled while typing without this.
  void _onDirtyFieldChanged() {
    final v = _hasWorkOrderChanges();
    if (v != _lastDirty) {
      _lastDirty = v;
      if (mounted) setState(() {});
    }
  }

  List<allcategories_model> _dropdownCategories = [];
  allcategories_model? _selectedDropdownCategory;
  String? _selectedEntry;
  final List<String> _entry = [
    'Yes',
    'No',
  ];
  String? _selectedStatus;
  final List<String> _status = ['New', 'In Progress', 'On Hold', 'Completed', 'Closed'];

  /// The canonical statuses, widened to include whatever the work order is
  /// currently set to. A DropdownButton throws when its `value` is absent from
  /// `items`, so legacy statuses (e.g. "Pending") must be represented here or
  /// the screen cannot open.
  List<String> get _statusOptions => <String>{
        ..._status,
        if (_selectedStatus != null && _selectedStatus!.isNotEmpty)
          _selectedStatus!,
      }.toList();
  final List<String> _account = [
    'Advertising',
    'Association Fees',
    //'Association fees',
    'Auto and Travel',
    'Bank Fees',
    'Cleaning and Maintenance',
    'Commissions',
    'Depreciation Expense',
    'Insurance',
    'Legal and Professional Fees',
    'Licenses and Permits',
    'Management Fees',
    'Mortgage Interest',
    'Other Expenses',
    'Postage and Delivery',
    'Repairs',
  ];
  List<Map<String, dynamic>> rows = [];
  bool _showTextField = false;
  String renderId = '';
  String unitId = '';
  String vendorId = '';
  String StaffId = '';
  String tenantId = '';
  bool isChecked = false;
  //for parts and lebours
  List<Map<String, dynamic>> partsAndLabor = [];

  void addRow() {
    setState(() {
      TextEditingController qtyController = TextEditingController();
      TextEditingController priceController = TextEditingController();
      TextEditingController totalController = TextEditingController();
      TextEditingController subtotalcontroller = TextEditingController();
      TextEditingController descriptionController = TextEditingController();

      qtyController.addListener(() {
        calculateTotal(qtyController, priceController, totalController,
            subtotalcontroller);
      });
      priceController.addListener(() {
        calculateTotal(qtyController, priceController, totalController,
            subtotalcontroller);
      });
      // Same dirty tracking the fetched rows get, for rows added later.
      qtyController.addListener(_onDirtyFieldChanged);
      priceController.addListener(_onDirtyFieldChanged);
      descriptionController.addListener(_onDirtyFieldChanged);

      partsAndLabor.add({
        'parts_id': null,
        'qtyController': qtyController,
        'accountController': TextEditingController(),
        'descriptionController': descriptionController,
        'priceController': priceController,
        'totalController': totalController,
        'subtotalcontroller': subtotalcontroller,
        'selectedAccount': null,
      });
    });
  }

  /// Releases every controller held by [rows], after the current frame.
  /// Deferring matters: the row's TextFields are still mounted during the
  /// frame that drops them, and disposing a controller they still reference
  /// throws "used after being disposed". By the next frame they are gone.
  void _disposeRowsAfterFrame(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final row in rows) {
        for (final value in row.values) {
          if (value is TextEditingController) value.dispose();
        }
      }
    });
  }

  void deleteRow(int index) {
    // Held before the removal so its controllers can be released — removeAt
    // alone orphaned them, listeners and all.
    final removed = partsAndLabor[index];
    setState(() {
      partsAndLabor.removeAt(index);
      updateTotalAmount();
    });
    _disposeRowsAfterFrame([removed]);
  }

  void calculateTotal(
      TextEditingController qtyController,
      TextEditingController priceController,
      TextEditingController totalController,
      TextEditingController subtotalcontroller) {
    double quantity = double.tryParse(qtyController.text) ?? 0;
    double price = double.tryParse(priceController.text) ?? 0;
    double total = quantity * price;
    totalController.text = total.toStringAsFixed(2);
    double subtotal = total += total;
    subtotalcontroller.text = subtotal.toStringAsFixed(2);
    updateTotalAmount();
  }

  double totalAmount = 0.0;
  void updateTotalAmount() {
    double total = 0.0;
    for (var item in partsAndLabor) {
      double itemTotal = double.tryParse(item['totalController'].text) ?? 0;
      total += itemTotal;
    }
    setState(() {
      totalAmount = total;
    });
  }

  Widget buildRow(int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () {
                deleteRow(index);
              },
            ),
          ),
          Text(
            "Quantity",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: blueColor),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
            hintText: 'Quantity',
            controller: partsAndLabor[index]['qtyController'],
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Text(
            "Account",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: blueColor),
          ),
          const SizedBox(height: 5),
          DropdownButtonHideUnderline(
            child: DropdownButton2<String>(
              isExpanded: true,
              hint: const Text('Select'),
              value: _account.contains(partsAndLabor[index]['selectedAccount'])
                  ? partsAndLabor[index]['selectedAccount']
                  : null,
              items: _account.map((method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(method),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  partsAndLabor[index]['selectedAccount'] = newValue;
                });
              },
              buttonStyleData: ButtonStyleData(
                height: 45,
                // width: 300,
                padding: const EdgeInsets.only(left: 14, right: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                ),
                elevation: 0,
              ),
              iconStyleData: const IconStyleData(
                icon: Icon(
                  Icons.arrow_drop_down,
                ),
                iconSize: 24,
                iconEnabledColor: Color(0xFFb0b6c3),
                iconDisabledColor: Colors.grey,
              ),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
                scrollbarTheme: ScrollbarThemeData(
                  radius: const Radius.circular(6),
                  thickness: MaterialStateProperty.all(6),
                  thumbVisibility: MaterialStateProperty.all(true),
                ),
              ),
              menuItemStyleData: const MenuItemStyleData(
                height: 50,
                padding: EdgeInsets.only(left: 14, right: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Description",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: blueColor),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
            hintText: 'Description',
            controller: partsAndLabor[index]['descriptionController'],
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 10),
          Text(
            "Price",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: blueColor),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
            hintText: 'Price',
            controller: partsAndLabor[index]['priceController'],
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Text(
            "Total",
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: blueColor),
          ),
          const SizedBox(height: 5),
          CustomTextField(
            showElevation: false,
            borderColor: const Color(0xFFCED4DA),
            borderWidth: 1.5,
            hintText: 'Total',
            controller: partsAndLabor[index]['totalController'],
            keyboardType: TextInputType.number,
            readOnnly: true,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String _selectedOption = 'Normal';

  void _handleRadioValueChange(String? value) {
    setState(() {
      _selectedOption = value!;
    });
  }

  //for tenants
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  File? _image;
  List<File> _images = [];
  String? _uploadedFileName;
  List<String> _uploadedFileNames = [];
  Future<String?> uploadImage(File imageFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          uploadUrl,
        ));
    request.files
        .add(await http.MultipartFile.fromPath('files', imageFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickMedia();

    if (image != null) {
      setState(() {
        _image = File(image.path);
        _images.add(File(image.path));
      });
      _uploadImage(File(image.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      String? fileName = await uploadImage(imageFile);
      setState(() {
        _uploadedFileNames.add(fileName!);
        _uploadedFileName = fileName;
        _imageUrls.add(fileName!);
      });
    } catch (e) {
      logError('Image upload failed: $e');
    }
  }

  List<String> _imageUrls = [];

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

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    // Update stays disabled until something actually changed (web parity).
    final bool canSave = _hasWorkOrderChanges();
    _lastDirty = canSave;
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.height;
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {
          key.currentState!.openDrawer();
        },
      ),
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          return Form(
            key: _formkey,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 25,
                    ),
                    titleBar(
                      width: MediaQuery.of(context).size.width * .91,
                      title: 'Edit Work Order',
                    ),
                    const SizedBox(
                      height: 15,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * .04),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Container(
                              width: double.infinity,
                              // height: !form_valid ? 860 : 830,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: const Color(0xFFDBE0E5),
                                  )),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Subject *',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    CustomTextField(
                                      showElevation: false,
                                      borderColor: const Color(0xFFCED4DA),
                                      borderWidth: 1.5,
                                      readOnnly: true,
                                      keyboardType: TextInputType.text,
                                      hintText: 'Add subject',
                                      controller: subject,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'please enter the subject';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    _imageUrls.isNotEmpty
                                        ? Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            child: Wrap(
                                              spacing:
                                              8.0, // Horizontal spacing between items
                                              runSpacing:
                                              8.0, // Vertical spacing between rows
                                              children: List.generate(
                                                _imageUrls.length,
                                                    (index) {
                                                  bool isMp4 = isVideo(
                                                      _imageUrls[index]);
                                                  return Container(
                                                    width: 85,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .start,
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            const SizedBox(
                                                                width:
                                                                60),
                                                            GestureDetector(
                                                              onTap: () {
                                                                setState(
                                                                        () {
                                                                      _imageUrls
                                                                          .removeAt(index);
                                                                    });
                                                              },
                                                              child:
                                                              const Icon(
                                                                Icons
                                                                    .close,
                                                                color: Colors
                                                                    .grey,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                          crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                          children: [
                                                            isMp4
                                                                ? GestureDetector(
                                                              onTap:
                                                                  () {
                                                                _showVideoDialog('$image_url${_imageUrls[index]}');
                                                              },
                                                              child:
                                                              Stack(
                                                                alignment:
                                                                Alignment.center,
                                                                children: [
                                                                  // Image.file(
                                                                  // File(snapshot.data!),
                                                                  // height:80,
                                                                  // width: 80,
                                                                  // fit: BoxFit.cover,
                                                                  // ),
                                                                  VideoItem(url: '$image_url${_imageUrls[index]}'),
                                                                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                                                                ],
                                                              ),
                                                            )
                                                                : Container(
                                                              child:
                                                              Image.network(
                                                                "$image_url${_imageUrls[index]}",
                                                                height:
                                                                80,
                                                                width:
                                                                80,
                                                                fit:
                                                                BoxFit.cover,
                                                                errorBuilder: (context,
                                                                    error,
                                                                    stackTrace) {
                                                                  return const Icon(Icons.error); // Placeholder for errors
                                                                },
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                        : const Center(
                                        child: Text("No images selected.")),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Property *',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor)),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButtonFormField2<
                                                    String>(
                                                  decoration:
                                                  const InputDecoration(
                                                      border:
                                                      InputBorder.none),
                                                  isExpanded: true,
                                                  hint: const Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Select Property',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                            FontWeight.w400,
                                                            color: Color(
                                                                0xFFb0b6c3),
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  items: properties.keys
                                                      .map((rentalId) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: rentalId,
                                                      child: Text(
                                                        properties[rentalId]!,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                          FontWeight.w400,
                                                          color: Colors.black87,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                  value: _selectedPropertyId,
                                                  onChanged: null,
                                                  /*(value) {
                                                    setState(() {
                                                      _selectedUnitId = null;
                                                      _selectedPropertyId = value;
                                                      _selectedProperty = properties[
                                                      value]; // Store selected rental_adress

                                                      renderId = value.toString();
                                                      print(
                                                          'Selected Property: $_selectedProperty');
                                                      // _loadUnits(
                                                      //     value!);
                                                      if (value != null) {
                                                        _loadUnits(value);
                                                      }
                                                    });
                                                  },*/
                                                  buttonStyleData:
                                                  ButtonStyleData(
                                                    height: 45,
                                                    width: 160,
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 14,
                                                        right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                  const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                    ),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                    Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                  DropdownStyleData(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                    ScrollbarThemeData(
                                                      radius:
                                                      const Radius.circular(
                                                          6),
                                                      thickness:
                                                      MaterialStateProperty
                                                          .all(6),
                                                      thumbVisibility:
                                                      MaterialStateProperty
                                                          .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                  const MenuItemStyleData(
                                                    height: 40,
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Please select an option';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 20,
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              units.isNotEmpty
                                                  ? Text('Unit',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor))
                                                  : Container(),
                                              const SizedBox(height: 0),
                                              units.isNotEmpty
                                                  ? DropdownButtonHideUnderline(
                                                child:
                                                DropdownButtonFormField2<
                                                    String>(
                                                  decoration:
                                                  const InputDecoration(
                                                      border:
                                                      InputBorder
                                                          .none),
                                                  isExpanded: true,
                                                  hint: const Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Select Unit',
                                                          style:
                                                          TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                            FontWeight
                                                                .w400,
                                                            color: Color(
                                                                0xFFb0b6c3),
                                                          ),
                                                          overflow:
                                                          TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  items: units.keys
                                                      .map((unitId) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: unitId,
                                                      child: Text(
                                                        units[unitId]!,
                                                        style:
                                                        const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                          FontWeight
                                                              .w400,
                                                          color: Colors
                                                              .black87,
                                                        ),
                                                        overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    );
                                                  }).toList(),
                                                  value: _selectedUnitId ==
                                                      null ||
                                                      _selectedUnitId!
                                                          .isEmpty ||
                                                      !units.containsKey(
                                                          _selectedUnitId)
                                                      ? null
                                                      : _selectedUnitId,
                                                  onChanged:
                                                  null /*(value) {
                                                setState(() {
                                                  unitId = value.toString();
                                                  _selectedUnitId = value;
                                                  _selectedUnit = units[
                                                  value]; // Store selected rental_unit
                                                  _loadTenant(_selectedPropertyId!, unitId);
                                                  print(
                                                      'Selected Unit: $_selectedUnit');

                                                });
                                              }*/
                                                  ,
                                                  buttonStyleData:
                                                  ButtonStyleData(
                                                    height: 45,
                                                    width: 160,
                                                    padding:
                                                    const EdgeInsets
                                                        .only(
                                                        left: 14,
                                                        right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                  const IconStyleData(
                                                    icon: Icon(Icons
                                                        .arrow_drop_down),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                    Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                  DropdownStyleData(
                                                    decoration:
                                                    BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                          6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                    ScrollbarThemeData(
                                                      radius: const Radius
                                                          .circular(6),
                                                      thickness:
                                                      MaterialStateProperty
                                                          .all(6),
                                                      thumbVisibility:
                                                      MaterialStateProperty
                                                          .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                  const MenuItemStyleData(
                                                    height: 40,
                                                    padding:
                                                    EdgeInsets.only(
                                                        left: 14,
                                                        right: 14),
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Please select an option';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              )
                                                  : Container(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 2,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Category',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor)),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton2<
                                                    allcategories_model>(
                                                  isExpanded: true,
                                                  hint: Text(_isLoadingCategories
                                                      ? 'Loading categories...'
                                                      : 'Select Category'),
                                                  value: _dropdownCategories
                                                      .contains(
                                                      _selectedDropdownCategory)
                                                      ? _selectedDropdownCategory
                                                      : null,
                                                  items: _dropdownCategories
                                                      .map((cat) {
                                                    return DropdownMenuItem<
                                                        allcategories_model>(
                                                      value: cat,
                                                      child:
                                                      Text(cat.name ?? ''),
                                                    );
                                                  }).toList(),
                                                  // Read-only for vendors, like web (VendorAddWork.jsx).
                                                  onChanged: null,
                                                  buttonStyleData:
                                                  ButtonStyleData(
                                                    height: 45,
                                                    width: 250,
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 14,
                                                        right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                  const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                    ),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                    Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                  DropdownStyleData(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                    ScrollbarThemeData(
                                                      radius:
                                                      const Radius.circular(
                                                          6),
                                                      thickness:
                                                      MaterialStateProperty
                                                          .all(6),
                                                      thumbVisibility:
                                                      MaterialStateProperty
                                                          .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                  const MenuItemStyleData(
                                                    height: 50,
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 20,
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Entry Allowed',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor)),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton2<String>(
                                                  isExpanded: true,
                                                  hint: const Text('Select'),
                                                  value: _selectedEntry,
                                                  items: _entry.map((method) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: method,
                                                      child: Text(method),
                                                    );
                                                  }).toList(),
                                                  onChanged:
                                                  null /*(String? newValue) {
                                                                                  setState(() {
                                              _selectedEntry = newValue;
                                              //_selectedPaymentMethod = addRow();
                                              // if(_selectedCategory == 'Other')
                                              // addRow();

                                                                                  });
                                                                                }*/
                                                  ,
                                                  buttonStyleData:
                                                  ButtonStyleData(
                                                    height: 45,
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 14,
                                                        right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                  const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                    ),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                    Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                  DropdownStyleData(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                    ScrollbarThemeData(
                                                      radius:
                                                      const Radius.circular(
                                                          6),
                                                      thickness:
                                                      MaterialStateProperty
                                                          .all(6),
                                                      thumbVisibility:
                                                      MaterialStateProperty
                                                          .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                  const MenuItemStyleData(
                                                    height: 40,
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Assigned To *',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor)),
                                              const SizedBox(
                                                height: 2,
                                              ),
                                              _isLoadingstaff
                                                  ? const Center(
                                                child:
                                                SpinKitFadingCircle(
                                                  color: Colors.black,
                                                  size: 50.0,
                                                ),
                                              )
                                                  : Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                                children: [
                                                  DropdownButtonHideUnderline(
                                                    child:
                                                    DropdownButtonFormField2<
                                                        String>(
                                                      decoration:
                                                      const InputDecoration(
                                                          border:
                                                          InputBorder
                                                              .none),
                                                      isExpanded: true,
                                                      hint: const Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              'Select here',
                                                              style:
                                                              TextStyle(
                                                                fontSize:
                                                                14,
                                                                fontWeight:
                                                                FontWeight
                                                                    .w400,
                                                                color: Color(
                                                                    0xFFb0b6c3),
                                                              ),
                                                              overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      items: staffs.keys.map(
                                                              (staffmember_id) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value:
                                                              staffmember_id,
                                                              child: Text(
                                                                staffs[
                                                                staffmember_id]!,
                                                                style:
                                                                const TextStyle(
                                                                  fontSize:
                                                                  14,
                                                                  fontWeight:
                                                                  FontWeight
                                                                      .w400,
                                                                  color: Colors
                                                                      .black87,
                                                                ),
                                                                overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                              ),
                                                            );
                                                          }).toList(),
                                                      value:
                                                      _selectedstaffId,
                                                      onChanged:
                                                      null /*(value) {
                                                setState(() {
                                                  // _selectedUnitId = null;
                                                  _selectedstaffId = value;
                                                  _selectedStaffs = staffs[
                                                  value]; // Store selected rental_adress

                                                  StaffId = value.toString();
                                                  print(
                                                      'Selected Staffs: $_selectedStaffs');
                                                  _loadUnits(
                                                      value!); // Fetch units for the selected property
                                                });
                                              }*/
                                                      ,
                                                      buttonStyleData:
                                                      ButtonStyleData(
                                                        height: 45,
                                                        width: 160,
                                                        padding:
                                                        const EdgeInsets
                                                            .only(
                                                            left: 14,
                                                            right:
                                                            14),
                                                        decoration: BoxDecoration(
                                                          borderRadius: BorderRadius.circular(8),
                                                          color: Colors.white,
                                                          border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                        ),
                                                        elevation: 0,
                                                      ),
                                                      iconStyleData:
                                                      const IconStyleData(
                                                        icon: Icon(
                                                          Icons
                                                              .arrow_drop_down,
                                                        ),
                                                        iconSize: 24,
                                                        iconEnabledColor:
                                                        Color(
                                                            0xFFb0b6c3),
                                                        iconDisabledColor:
                                                        Colors.grey,
                                                      ),
                                                      dropdownStyleData:
                                                      DropdownStyleData(
                                                        decoration:
                                                        BoxDecoration(
                                                          borderRadius:
                                                          BorderRadius
                                                              .circular(
                                                              6),
                                                          color: Colors
                                                              .white,
                                                        ),
                                                        scrollbarTheme:
                                                        ScrollbarThemeData(
                                                          radius:
                                                          const Radius
                                                              .circular(
                                                              6),
                                                          thickness:
                                                          MaterialStateProperty
                                                              .all(6),
                                                          thumbVisibility:
                                                          MaterialStateProperty
                                                              .all(
                                                              true),
                                                        ),
                                                      ),
                                                      menuItemStyleData:
                                                      const MenuItemStyleData(
                                                        height: 40,
                                                        padding: EdgeInsets
                                                            .only(
                                                            left: 14,
                                                            right:
                                                            14),
                                                      ),
                                                      validator: (value) {
                                                        if (value ==
                                                            null ||
                                                            value
                                                                .isEmpty) {
                                                          return 'Please select an option';
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text('Work To Be Performed',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    CustomTextField(
                                      showElevation: false,
                                      borderColor: const Color(0xFFCED4DA),
                                      borderWidth: 1.5,
                                      readOnnly: true,
                                      keyboardType: TextInputType.text,
                                      hintText: 'Enter here',
                                      controller: perform,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Container(
                              width: double.infinity,
                              // height: !form_valid ? 860 : 830,
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: const Color(0xFFDBE0E5),
                                  )),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text('Parts And Labou ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    /*   ...partsAndLabor.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      return buildRow(index);
                                    }).toList(),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        // SizedBox(width: 10),
                                        Text('Total :',
                                            style:
                                            TextStyle(fontWeight: FontWeight.bold,)),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child:
                                          Text('\$${totalAmount.toStringAsFixed(2)}'),
                                        ),
                                      ],
                                    ),*/
                                    const SizedBox(
                                      height: 10,
                                    ),
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
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('Account',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('Description',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('Price',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('Amount',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text('',
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                        ]),
                                        /* ...summery.partsandchargeData!.asMap().entries.map((entry) {
                                          int index = entry.key;
                                          PartsandchargeData row = entry.value;
                                          grandTotal += (row.partsQuantity! * row.partsPrice!);
                                          return TableRow(children: [
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child:Text("${row.partsQuantity}"),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child:Text("${row.account}"),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child:Text("${row.description}"),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child:Text("\$${(row.partsPrice ?? 0).toStringAsFixed(2)}"),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(8.0),
                                              child:Text("\$${(row.partsPrice! * row.partsQuantity!).toStringAsFixed(2)}"),
                                            ),
                                          ]);
                                        }).toList(),*/
                                        ...partsAndLabor
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          int index = entry.key;
                                          return TableRow(children: [
                                            Padding(
                                              padding:
                                              const EdgeInsets.all(8.0),
                                              child: CustomTextField(
                                                showElevation: false,
                                                borderColor: const Color(0xFFCED4DA),
                                                borderWidth: 1.5,
                                                hintText: 'Quantity',
                                                controller: partsAndLabor[index]
                                                ['qtyController'],
                                                keyboardType:
                                                TextInputType.number,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                              const EdgeInsets.all(8.0),
                                              child:
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton2<String>(
                                                  isExpanded: true,
                                                  hint: const Text('Select'),
                                                  value: partsAndLabor[index]
                                                  ['selectedAccount'],
                                                  items: _account.map((method) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: method,
                                                      child: Text(method),
                                                    );
                                                  }).toList(),
                                                  onChanged:
                                                      (String? newValue) {
                                                    setState(() {
                                                      partsAndLabor[index][
                                                      'selectedAccount'] =
                                                          newValue;
                                                    });
                                                  },
                                                  buttonStyleData:
                                                  ButtonStyleData(
                                                    height: 45,
                                                    // width: 300,
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 14,
                                                        right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                  const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                    ),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                    Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                  DropdownStyleData(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                    ScrollbarThemeData(
                                                      radius:
                                                      const Radius.circular(
                                                          6),
                                                      thickness:
                                                      MaterialStateProperty
                                                          .all(6),
                                                      thumbVisibility:
                                                      MaterialStateProperty
                                                          .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                  const MenuItemStyleData(
                                                    height: 50,
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                              const EdgeInsets.all(8.0),
                                              child: CustomTextField(
                                                showElevation: false,
                                                borderColor: const Color(0xFFCED4DA),
                                                borderWidth: 1.5,
                                                hintText: 'Description',
                                                controller: partsAndLabor[index]
                                                ['descriptionController'],
                                                keyboardType:
                                                TextInputType.text,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                              const EdgeInsets.all(8.0),
                                              child: CustomTextField(
                                                showElevation: false,
                                                borderColor: const Color(0xFFCED4DA),
                                                borderWidth: 1.5,
                                                hintText: 'Price',
                                                controller: partsAndLabor[index]
                                                ['priceController'],
                                                keyboardType:
                                                TextInputType.number,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                              const EdgeInsets.all(8.0),
                                              child: CustomTextField(
                                                showElevation: false,
                                                borderColor: const Color(0xFFCED4DA),
                                                borderWidth: 1.5,
                                                hintText: 'Total',
                                                controller: partsAndLabor[index]
                                                ['totalController'],
                                                keyboardType:
                                                TextInputType.number,
                                                readOnnly: true,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                              const EdgeInsets.all(8.0),
                                              child: IconButton(
                                                icon: const Icon(Icons.close,
                                                    color: Colors.black),
                                                onPressed: () {
                                                  deleteRow(index);
                                                },
                                              ),
                                            ),
                                            /* Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text("\$${grandTotal.toStringAsFixed(2)}",style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                          ),*/

                                            /* Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                  '\$${totalAmount.toStringAsFixed(2)}'),
                            ),*/
                                          ]);
                                        }).toList(),
                                        TableRow(children: [
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('Total',
                                                style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('',
                                                style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('',
                                                style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('',
                                                style: TextStyle(
                                                    fontWeight:
                                                    FontWeight.bold)),
                                          ),
                                          /* const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text('',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold)),
                                          ),*/
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                                '\$${totalAmount.toStringAsFixed(2)}'),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.all(8.0),
                                            child: Text(''),
                                          ),

                                          /* Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                  '\$${totalAmount.toStringAsFixed(2)}'),
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
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: blueColor),
                                      onPressed: addRow,
                                      child: const Text('Add Row'),
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text('Vendors Note *',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor)),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    CustomTextField(
                                      showElevation: false,
                                      borderColor: const Color(0xFFCED4DA),
                                      borderWidth: 1.5,
                                      keyboardType: TextInputType.text,
                                      hintText: 'Enter here',
                                      controller: vendornote,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'please enter the note here';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(
                                      height: 20,
                                    ),
                                    /* Row(
                                  children: [
                                    Text("Billable To Tenants",style: TextStyle(
                                        color: Colors.grey
                                    ),),
                                    SizedBox(width: 10,),
                                    SizedBox(
                                      width: 24.0, // Standard width for checkbox
                                      height: 24.0,
                                      child: Checkbox(
                                        value: isChecked,
                                        onChanged: (value) {
                                          setState(() {
                                            isChecked = value ?? false;
                                          });
                                        },
                                        activeColor: isChecked
                                            ? blueColor
                                            : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                if(isChecked)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      _isLoadingtenant
                                          ? const Center(
                                        child: SpinKitFadingCircle(
                                          color: Colors.black,
                                          size: 50.0,
                                        ),
                                      )
                                          : tenants.isNotEmpty
                                          ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Tenant',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: blueColor)),
                                          SizedBox(height: 2),
                                          DropdownButtonHideUnderline(
                                            child: DropdownButtonFormField2<String>(
                                              decoration: InputDecoration(border: InputBorder.none),
                                              isExpanded: true,
                                              hint: const Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Select Tenant',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w400,
                                                        color: Color(0xFFb0b6c3),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              items: tenants.keys.map((tenantId) {
                                                return DropdownMenuItem<String>(
                                                  value: tenantId,
                                                  child: Text(
                                                    tenants[tenantId]!,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                      color: Colors.black87,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                              value: _selectedtenantId,
                                              onChanged: (value) {
                                                setState(() {
                                                  tenantId = value.toString();
                                                  _selectedtenantId = value;
                                                  _selectedTenants = tenants[value]; // Store selected tenant name
                                                });
                                              },
                                              buttonStyleData: ButtonStyleData(
                                                height: 45,
                                                width: 160,
                                                padding: const EdgeInsets.only(left: 14, right: 14),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  color: Colors.white,
                                                  border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                ),
                                                elevation: 0,
                                              ),
                                              iconStyleData: const IconStyleData(
                                                icon: Icon(Icons.arrow_drop_down),
                                                iconSize: 24,
                                                iconEnabledColor: Color(0xFFb0b6c3),
                                                iconDisabledColor: Colors.grey,
                                              ),
                                              dropdownStyleData: DropdownStyleData(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(6),
                                                  color: Colors.white,
                                                ),
                                                scrollbarTheme: ScrollbarThemeData(
                                                  radius: const Radius.circular(6),
                                                  thickness: MaterialStateProperty.all(6),
                                                  thumbVisibility: MaterialStateProperty.all(true),
                                                ),
                                              ),
                                              menuItemStyleData: const MenuItemStyleData(
                                                height: 40,
                                                padding: EdgeInsets.only(left: 14, right: 14),
                                              ),
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return 'Please select an option';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      )
                                          : Container(),
                                    ],
                                  ),
                                SizedBox(
                                  height: 15,
                                ),*/
                                    Row(
                                      children: [
                                        Text(
                                          "Priority",
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: blueColor),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.start,
                                      crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: ListTile(
                                            title: const Text('High'),
                                            leading: Radio<String>(
                                              value: 'High',
                                              groupValue: _selectedOption,
                                              onChanged:
                                              _handleRadioValueChange,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: ListTile(
                                            title: const Text('Normal'),
                                            leading: Radio<String>(
                                              value: 'Normal',
                                              groupValue: _selectedOption,
                                              onChanged:
                                              _handleRadioValueChange,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: ListTile(
                                            title: const Text('Low'),
                                            leading: Radio<String>(
                                              value: 'Low',
                                              groupValue: _selectedOption,
                                              onChanged:
                                              _handleRadioValueChange,
                                            ),
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 1,
                                          child: ListTile(
                                            title: Text(''),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Status *',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor)),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              DropdownButtonHideUnderline(
                                                child: DropdownButton2<String>(
                                                  isExpanded: true,
                                                  hint: const Text('New'),
                                                  value: _selectedStatus,
                                                  items:
                                                      _statusOptions.map((method) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: method,
                                                      child: Text(method),
                                                    );
                                                  }).toList(),
                                                  onChanged:
                                                      (String? newValue) {
                                                    setState(() {
                                                      _selectedStatus =
                                                          newValue;
                                                    });
                                                  },
                                                  buttonStyleData:
                                                  ButtonStyleData(
                                                    height: 45,
                                                    width: 200,
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 14,
                                                        right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.white,
                                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                                    ),
                                                    elevation: 0,
                                                  ),
                                                  iconStyleData:
                                                  const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                    ),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                    Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                    Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                  DropdownStyleData(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                      BorderRadius.circular(
                                                          6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                    ScrollbarThemeData(
                                                      radius:
                                                      const Radius.circular(
                                                          6),
                                                      thickness:
                                                      MaterialStateProperty
                                                          .all(6),
                                                      thumbVisibility:
                                                      MaterialStateProperty
                                                          .all(true),
                                                    ),
                                                  ),
                                                  menuItemStyleData:
                                                  const MenuItemStyleData(
                                                    height: 40,
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 15,
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Column(
                                            mainAxisAlignment:
                                            MainAxisAlignment.start,
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Due Date',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: blueColor)),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              Container(
                                                height: 46,
                                                padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12.0,
                                                    vertical: 0),
                                                decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    boxShadow: [
                                                      const BoxShadow(
                                                        color: Colors.black26,
                                                        offset: Offset(1.0,
                                                            1.0), // Shadow offset to the bottom right
                                                        blurRadius:
                                                        8.0, // How much to blur the shadow
                                                        spreadRadius:
                                                        0.0, // How much the shadow should spread
                                                      ),
                                                    ],
                                                    border: Border.all(
                                                        width: 0,
                                                        color: Colors.white),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                        6.0)),
                                                child: InkWell(
                                              // Read-only for vendors, like web and the phone layout.
                                              onTap: null,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _dateController.text.trim().isEmpty
                                                          ? 'dd-mm-yyyy'
                                                          : dateProvider.formatCurrentDate(_dateController.text.trim()),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(0xFF8898aa),
                                                      ),
                                                    ),
                                                  ),
                                                  const Icon(Icons.calendar_today,
                                                      size: 20, color: Color(0xFF8898aa)),
                                                ],
                                              ),
                                            ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Expanded(
                                          flex: 2,
                                          child: ListTile(
                                            title: Text(''),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  height: 50,
                                  width: 180,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: canSave
                                          ? blueColor
                                          : const Color(0xFFE5E8ED),
                                      disabledBackgroundColor:
                                      const Color(0xFFE5E8ED),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(8.0),
                                      ),
                                    ),
                                    onPressed: (isloading || !canSave)
                                        ? null
                                        : _submitForm,
                                    child: isloading
                                        ? const Center(
                                      child: SpinKitFadingCircle(
                                        color: Colors.white,
                                        size: 55.0,
                                      ),
                                    )
                                        : Text(
                                      'Update Work Order',
                                      style: TextStyle(
                                          color: canSave
                                              ? const Color(0xFFf7f8f9)
                                              : const Color(0xFF9AA3B0)),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Container(
                                    height: 50,
                                    width: 120,
                                    decoration: BoxDecoration(
                                        borderRadius:
                                        BorderRadius.circular(8.0)),
                                    child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                            const Color(0xFFffffff),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(
                                                    8.0))),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: const Text(
                                          'Cancel',
                                          style: TextStyle(
                                              color: Color(0xFF748097)),
                                        )))
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          return Form(
            key: _formkey,
            child: Container(
              color: Colors.white,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 25,
                    ),
                    titleBar(
                      width: MediaQuery.of(context).size.width * .91,
                      title: 'Edit Work Order',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        width: double.infinity,
                        // height: !form_valid ? 860 : 830,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: const Color(0xFFDBE0E5),
                            )),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Subject *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                borderWidth: 1.5,
                                readOnnly: true,
                                keyboardType: TextInputType.text,
                                hintText: 'Add subject',
                                controller: subject,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'please enter the subject';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              /*  Text('Photo ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              SizedBox(
                                height: 10,
                              ),*/
                              // Container(
                              //   height: 50,
                              //   width: 150,
                              //   decoration: BoxDecoration(
                              //     borderRadius: BorderRadius.circular(8.0),
                              //   ),
                              //   child: ElevatedButton(
                              //     style: ElevatedButton.styleFrom(
                              //       backgroundColor: blueColor,
                              //       shape: RoundedRectangleBorder(
                              //         borderRadius: BorderRadius.circular(8.0),
                              //       ),
                              //     ),
                              //     onPressed: () async {
                              //
                              //     },
                              //     child: isLoading
                              //         ? Center(
                              //       child: SpinKitFadingCircle(
                              //         color: Colors.white,
                              //         size: 55.0,
                              //       ),
                              //     )
                              //         : Text(
                              //       'Upload here',
                              //       style: TextStyle(color: Color(0xFFf7f8f9)),
                              //     ),
                              //   ),
                              // ),
                              _imageUrls.isNotEmpty
                                  ? Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      child: Wrap(
                                        spacing:
                                        8.0, // Horizontal spacing between items
                                        runSpacing:
                                        8.0, // Vertical spacing between rows
                                        children: List.generate(
                                          _imageUrls.length,
                                              (index) {
                                            bool isMp4 = isVideo(
                                                _imageUrls[index]);
                                            return Container(
                                              width: 85,
                                              child: Column(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .start,
                                                crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                                children: [
                                                  // Row(
                                                  //   children: [
                                                  //     SizedBox(width: 60),
                                                  //     GestureDetector(
                                                  //       onTap: () {
                                                  //         setState(() {
                                                  //           _imageUrls.removeAt(index);
                                                  //         });
                                                  //       },
                                                  //       child: Icon(
                                                  //         Icons.close,
                                                  //         color: Colors.grey,
                                                  //       ),
                                                  //     ),
                                                  //   ],
                                                  // ),
                                                  Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .start,
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                    children: [
                                                      isMp4
                                                          ? Container(
                                                        height: 80,
                                                        width: 80,
                                                        child:
                                                        GestureDetector(
                                                          onTap:
                                                              () {
                                                            _showVideoDialog(
                                                                '$image_url${_imageUrls[index]}');
                                                          },
                                                          child:
                                                          Stack(
                                                            alignment:
                                                            Alignment.center,
                                                            children: [
                                                              // Image.file(
                                                              //   File(snapshot.data!),
                                                              //   height: 80,
                                                              //   width: 80,
                                                              //   fit: BoxFit.cover,
                                                              // ),
                                                              VideoItem(
                                                                  url: '$image_url${_imageUrls[index]}'),
                                                              const Icon(
                                                                  Icons.play_circle_fill,
                                                                  color: Colors.white,
                                                                  size: 40),
                                                            ],
                                                          ),
                                                        ),
                                                      )
                                                          : Container(
                                                        child: Image
                                                            .network(
                                                          "$image_url${_imageUrls[index]}",
                                                          height:
                                                          80,
                                                          width: 80,
                                                          fit: BoxFit
                                                              .cover,
                                                          errorBuilder: (context,
                                                              error,
                                                              stackTrace) {
                                                            return const Icon(
                                                                Icons.error); // Placeholder for errors
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                                  : const Center(child: Text("")),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Property *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 2,
                              ),
                              _isLoading
                                  ? const Center(
                                child: SpinKitFadingCircle(
                                  color: Colors.black,
                                  size: 50.0,
                                ),
                              )
                                  : Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonHideUnderline(
                                    child:
                                    DropdownButtonFormField2<String>(
                                      decoration: const InputDecoration(
                                          border: InputBorder.none),
                                      isExpanded: true,
                                      hint: const Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Select Property',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                FontWeight.w400,
                                                color: Color(0xFFb0b6c3),
                                              ),
                                              overflow:
                                              TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items:
                                      properties.keys.map((rentalId) {
                                        return DropdownMenuItem<String>(
                                          value: rentalId,
                                          child: Text(
                                            properties[rentalId]!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: _selectedPropertyId,
                                      onChanged: null,
                                      /*(value) {
                                        setState(() {
                                          _selectedUnitId = null;
                                          _selectedPropertyId = value;
                                          _selectedProperty = properties[
                                          value]; // Store selected rental_adress

                                          renderId = value.toString();
                                          print(
                                              'Selected Property: $_selectedProperty');
                                          // _loadUnits(
                                          //     value!);
                                          if (value != null) {
                                            _loadUnits(value);
                                          }
                                        });
                                      },*/
                                      buttonStyleData: ButtonStyleData(
                                        height: 45,
                                        width: 160,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                          border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData: const IconStyleData(
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                        ),
                                        iconSize: 24,
                                        iconEnabledColor:
                                        Color(0xFFb0b6c3),
                                        iconDisabledColor: Colors.grey,
                                      ),
                                      dropdownStyleData:
                                      DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme:
                                        ScrollbarThemeData(
                                          radius:
                                          const Radius.circular(6),
                                          thickness:
                                          MaterialStateProperty.all(
                                              6),
                                          thumbVisibility:
                                          MaterialStateProperty.all(
                                              true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                      const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty) {
                                          return 'Please select an option';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  units.isNotEmpty
                                      ? Text('Unit',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor))
                                      : Container(),
                                  const SizedBox(height: 0),
                                  units.isNotEmpty
                                      ? DropdownButtonHideUnderline(
                                    child: DropdownButtonFormField2<
                                        String>(
                                      decoration:
                                      const InputDecoration(
                                          border:
                                          InputBorder.none),
                                      isExpanded: true,
                                      hint: const Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Select Unit',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                FontWeight.w400,
                                                color: Color(
                                                    0xFFb0b6c3),
                                              ),
                                              overflow: TextOverflow
                                                  .ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items:
                                      units.keys.map((unitId) {
                                        return DropdownMenuItem<
                                            String>(
                                          value: unitId,
                                          child: Text(
                                            units[unitId]!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow
                                                .ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: _selectedUnitId ==
                                          null ||
                                          _selectedUnitId!
                                              .isEmpty ||
                                          !units.containsKey(
                                              _selectedUnitId)
                                          ? null
                                          : _selectedUnitId,
                                      onChanged:
                                      null /*(value) {
                                        setState(() {
                                          unitId = value.toString();
                                          _selectedUnitId = value;
                                          _selectedUnit = units[
                                          value]; // Store selected rental_unit
                                          _loadTenant(_selectedPropertyId!, unitId);
                                          print(
                                              'Selected Unit: $_selectedUnit');

                                        });
                                      }*/
                                      ,
                                      buttonStyleData:
                                      ButtonStyleData(
                                        height: 45,
                                        width: 160,
                                        padding:
                                        const EdgeInsets.only(
                                            left: 14,
                                            right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                          border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData:
                                      const IconStyleData(
                                        icon: Icon(
                                            Icons.arrow_drop_down),
                                        iconSize: 24,
                                        iconEnabledColor:
                                        Color(0xFFb0b6c3),
                                        iconDisabledColor:
                                        Colors.grey,
                                      ),
                                      dropdownStyleData:
                                      DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(
                                              6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme:
                                        ScrollbarThemeData(
                                          radius:
                                          const Radius.circular(
                                              6),
                                          thickness:
                                          MaterialStateProperty
                                              .all(6),
                                          thumbVisibility:
                                          MaterialStateProperty
                                              .all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                      const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                    ),
                                  )
                                      : Container(),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Category',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton2<allcategories_model>(
                                  isExpanded: true,
                                  hint: Text(_isLoadingCategories
                                      ? 'Loading categories...'
                                      : 'Select Category'),
                                  value: _dropdownCategories
                                      .contains(_selectedDropdownCategory)
                                      ? _selectedDropdownCategory
                                      : null,
                                  items: _dropdownCategories.map((cat) {
                                    return DropdownMenuItem<
                                        allcategories_model>(
                                      value: cat,
                                      child: Text(cat.name ?? ''),
                                    );
                                  }).toList(),
                                  // Read-only for vendors, like web (VendorAddWork.jsx).
                                  onChanged: null,
                                  buttonStyleData: ButtonStyleData(
                                    height: 45,
                                    padding: const EdgeInsets.only(
                                        left: 1, right: 14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                    ),
                                    elevation: 0,
                                  ),
                                  iconStyleData: const IconStyleData(
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                    ),
                                    iconSize: 24,
                                    iconEnabledColor: Color(0xFFb0b6c3),
                                    iconDisabledColor: Colors.grey,
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarTheme: ScrollbarThemeData(
                                      radius: const Radius.circular(6),
                                      thickness: MaterialStateProperty.all(6),
                                      thumbVisibility:
                                      MaterialStateProperty.all(true),
                                    ),
                                  ),
                                  menuItemStyleData: const MenuItemStyleData(
                                    height: 50,
                                    padding:
                                    EdgeInsets.only(left: 14, right: 14),
                                  ),
                                ),
                              ),
                              _showTextField
                                  ? Padding(
                                padding: const EdgeInsets.only(
                                    top: 10, bottom: 10),
                                child: buildTextField('Other Category',
                                    'Enter Other Category', other),
                              )
                                  : Container(),
                              const SizedBox(
                                height: 10,
                              ),
                              /* Text('Vendors *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              SizedBox(
                                height: 2,
                              ),
                              _isLoadingvendors
                                  ? const Center(
                                child: SpinKitFadingCircle(
                                  color: Colors.black,
                                  size: 50.0,
                                ),
                              )
                                  : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonHideUnderline(
                                    child: DropdownButtonFormField2<String>(
                                      decoration: InputDecoration(
                                          border: InputBorder.none),
                                      isExpanded: true,
                                      hint: const Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Select here',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w400,
                                                color: Color(0xFFb0b6c3),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: vendors.keys.map((vender_id) {
                                        return DropdownMenuItem<String>(
                                          value: vender_id,
                                          child: Text(
                                            vendors[vender_id]!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: _selectedvendorsId,
                                      onChanged: (value) {
                                        setState(() {
                                          // _selectedUnitId = null;
                                          _selectedvendorsId = value;
                                          _selectedVendors = vendors[
                                          value]; // Store selected rental_adress

                                          vendorId = value.toString();
                                          print(
                                              'Selected Vendors: $_selectedVendors');
                                          _loadUnits(
                                              value!); // Fetch units for the selected property
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 45,
                                        width: 160,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                          border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData: const IconStyleData(
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                        ),
                                        iconSize: 24,
                                        iconEnabledColor: Color(0xFFb0b6c3),
                                        iconDisabledColor: Colors.grey,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(6),
                                          thickness:
                                          MaterialStateProperty.all(6),
                                          thumbVisibility:
                                          MaterialStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                      const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select an option';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 10,
                              ),*/
                              Text('Entry Allowed',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              DropdownButtonHideUnderline(
                                child: DropdownButton2<String>(
                                  isExpanded: true,
                                  hint: const Text('Select'),
                                  value: _selectedEntry,
                                  items: _entry.map((method) {
                                    return DropdownMenuItem<String>(
                                      value: method,
                                      child: Text(method),
                                    );
                                  }).toList(),
                                  onChanged:
                                  null /*(String? newValue) {
                                    setState(() {
                                      _selectedEntry = newValue;
                                      //_selectedPaymentMethod = addRow();
                                      // if(_selectedCategory == 'Other')
                                      // addRow();

                                    });
                                  }*/
                                  ,
                                  buttonStyleData: ButtonStyleData(
                                    height: 45,
                                    padding: const EdgeInsets.only(
                                        left: 1, right: 14),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                      border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                    ),
                                    elevation: 0,
                                  ),
                                  iconStyleData: const IconStyleData(
                                    icon: Icon(
                                      Icons.arrow_drop_down,
                                    ),
                                    iconSize: 24,
                                    iconEnabledColor: Color(0xFFb0b6c3),
                                    iconDisabledColor: Colors.grey,
                                  ),
                                  dropdownStyleData: DropdownStyleData(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Colors.white,
                                    ),
                                    scrollbarTheme: ScrollbarThemeData(
                                      radius: const Radius.circular(6),
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
                                ),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Assigned To *',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 2,
                              ),
                              _isLoadingstaff
                                  ? const Center(
                                child: SpinKitFadingCircle(
                                  color: Colors.black,
                                  size: 50.0,
                                ),
                              )
                                  : Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  DropdownButtonHideUnderline(
                                    child:
                                    DropdownButtonFormField2<String>(
                                      decoration: const InputDecoration(
                                          border: InputBorder.none),
                                      isExpanded: true,
                                      hint: const Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Select here',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                FontWeight.w400,
                                                color: Color(0xFFb0b6c3),
                                              ),
                                              overflow:
                                              TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      items: staffs.keys
                                          .map((staffmember_id) {
                                        return DropdownMenuItem<String>(
                                          value: staffmember_id,
                                          child: Text(
                                            staffs[staffmember_id]!,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87,
                                            ),
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      value: _selectedstaffId,
                                      onChanged:
                                      null /*(value) {
                                        setState(() {
                                          // _selectedUnitId = null;
                                          _selectedstaffId = value;
                                          _selectedStaffs = staffs[
                                          value]; // Store selected rental_adress

                                          StaffId = value.toString();
                                          print(
                                              'Selected Staffs: $_selectedStaffs');
                                          _loadUnits(
                                              value!); // Fetch units for the selected property
                                        });
                                      }*/
                                      ,
                                      buttonStyleData: ButtonStyleData(
                                        height: 45,
                                        width: 160,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                          border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData: const IconStyleData(
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                        ),
                                        iconSize: 24,
                                        iconEnabledColor:
                                        Color(0xFFb0b6c3),
                                        iconDisabledColor: Colors.grey,
                                      ),
                                      dropdownStyleData:
                                      DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme:
                                        ScrollbarThemeData(
                                          radius:
                                          const Radius.circular(6),
                                          thickness:
                                          MaterialStateProperty.all(
                                              6),
                                          thumbVisibility:
                                          MaterialStateProperty.all(
                                              true),
                                        ),
                                      ),
                                      menuItemStyleData:
                                      const MenuItemStyleData(
                                        height: 40,
                                        padding: EdgeInsets.only(
                                            left: 14, right: 14),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.isEmpty) {
                                          return 'Please select an option';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Work To Be Performed',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                borderWidth: 1.5,
                                readOnnly: true,
                                optional: true,
                                keyboardType: TextInputType.text,
                                hintText: 'Enter here',
                                controller: perform,
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        width: double.infinity,
                        // height: !form_valid ? 860 : 830,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(
                              color: const Color(0xFFDBE0E5),
                            )),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('Parts And Labour :',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              ...partsAndLabor.asMap().entries.map((entry) {
                                int index = entry.key;
                                return buildRow(index);
                              }).toList(),
                              const SizedBox(
                                height: 10,
                              ),
                              Row(
                                children: [
                                  // SizedBox(width: 10),
                                  const Text('Total :',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      )),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                        '\$${totalAmount.toStringAsFixed(2)}'),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              ElevatedButton(
                                onPressed: addRow,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: blueColor),
                                child: const Text('Add Row'),
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Text('Vendors Note ',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                              const SizedBox(
                                height: 10,
                              ),
                              CustomTextField(
                                showElevation: false,
                                borderColor: const Color(0xFFCED4DA),
                                borderWidth: 1.5,
                                keyboardType: TextInputType.text,
                                hintText: 'Enter here',
                                controller: vendornote,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'please enter the note here';
                                  }
                                  return null;
                                },
                                optional: true,
                              ),
                              const SizedBox(
                                height: 20,
                              ),
                              /* Row(
                                children: [
                                  Text("Billable To Tenants",style: TextStyle(
                                      color: Colors.grey
                                  ),),
                                  SizedBox(width: 10,),
                                  SizedBox(
                                    width: 24.0, // Standard width for checkbox
                                    height: 24.0,
                                    child: Checkbox(
                                      value: isChecked,
                                      onChanged: (value) {
                                        setState(() {
                                          isChecked = value ?? false;
                                        });
                                      },
                                      activeColor: isChecked
                                          ? blueColor
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              if(isChecked)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    _isLoadingtenant
                                        ? const Center(
                                      child: SpinKitFadingCircle(
                                        color: Colors.black,
                                        size: 50.0,
                                      ),
                                    )
                                        : tenants.isNotEmpty
                                        ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tenant',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: blueColor)),
                                        SizedBox(height: 2),
                                        DropdownButtonHideUnderline(
                                          child: DropdownButtonFormField2<String>(
                                            decoration: InputDecoration(border: InputBorder.none),
                                            isExpanded: true,
                                            hint: const Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Select Tenant',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w400,
                                                      color: Color(0xFFb0b6c3),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            items: tenants.keys.map((tenantId) {
                                              return DropdownMenuItem<String>(
                                                value: tenantId,
                                                child: Text(
                                                  tenants[tenantId]!,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.black87,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            value: _selectedtenantId,
                                            onChanged: (value) {
                                              setState(() {
                                                tenantId = value.toString();
                                                _selectedtenantId = value;
                                                _selectedTenants = tenants[value]; // Store selected tenant name
                                              });
                                            },
                                            buttonStyleData: ButtonStyleData(
                                              height: 45,
                                              width: 160,
                                              padding: const EdgeInsets.only(left: 14, right: 14),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                color: Colors.white,
                                                border: Border.all(color: const Color(0xFFCED4DA), width: 1.5),
                                              ),
                                              elevation: 0,
                                            ),
                                            iconStyleData: const IconStyleData(
                                              icon: Icon(Icons.arrow_drop_down),
                                              iconSize: 24,
                                              iconEnabledColor: Color(0xFFb0b6c3),
                                              iconDisabledColor: Colors.grey,
                                            ),
                                            dropdownStyleData: DropdownStyleData(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(6),
                                                color: Colors.white,
                                              ),
                                              scrollbarTheme: ScrollbarThemeData(
                                                radius: const Radius.circular(6),
                                                thickness: MaterialStateProperty.all(6),
                                                thumbVisibility: MaterialStateProperty.all(true),
                                              ),
                                            ),
                                            menuItemStyleData: const MenuItemStyleData(
                                              height: 40,
                                              padding: EdgeInsets.only(left: 14, right: 14),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please select an option';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    )
                                        : Container(),
                                  ],
                                ),
                              SizedBox(
                                height: 15,
                              ),*/
                              Row(
                                children: [
                                  Text(
                                    "Priority",
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: blueColor),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /*  Expanded(
                                    child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                      title: const Text(' High'),
                                      leading: Radio<String>(
                                        value: 'High',
                                        groupValue: _selectedOption,
                                        onChanged: _handleRadioValueChange,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(' Normal'),
                                      leading: Radio<String>(
                                        value: 'Normal',
                                        groupValue: _selectedOption,
                                        onChanged: _handleRadioValueChange,
                                      ),
                                    ),
                                  ),*/
                                  Row(
                                    children: [
                                      Container(
                                        width: 25,
                                        child: Radio<String>(
                                          value: 'High',
                                          groupValue: _selectedOption,
                                          onChanged: _handleRadioValueChange,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      const Text(' High')
                                    ],
                                  ),
                                  const SizedBox(
                                    width: 20,
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 25,
                                        child: Radio<String>(
                                          value: 'Normal',
                                          groupValue: _selectedOption,
                                          onChanged: _handleRadioValueChange,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      const Text(' Normal')
                                    ],
                                  ),
                                  const SizedBox(
                                    width: 20,
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        width: 25,
                                        child: Radio<String>(
                                          value: 'Low',
                                          groupValue: _selectedOption,
                                          onChanged: _handleRadioValueChange,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 5,
                                      ),
                                      const Text(' Low')
                                    ],
                                  )
                                  /* ListTile(

                                    tileColor: Colors.amber,
                                    contentPadding: EdgeInsets.only(left:5),
                                    title: Container(
                                    color: Colors.cyan,
                                      child: const Text(' Low')),
                                    leading: Container(
                                      color: Colors.grey,
                                      width: 25,
                                      child: Radio<String>(
                                        value: 'Low',
                                        groupValue: _selectedOption,
                                        onChanged: _handleRadioValueChange,
                                      ),
                                    ),
                                  ),*/
                                ],
                              ),
                              const SizedBox(
                                height: 10,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status *',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor)),
                                  const SizedBox(height: 10),
                                  DropdownButtonHideUnderline(
                                    child: DropdownButton2<String>(
                                      isExpanded: true,
                                      hint: const Text('New'),
                                      value: _selectedStatus,
                                      items: _statusOptions.map((method) {
                                        return DropdownMenuItem<String>(
                                          value: method,
                                          child: Text(method),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedStatus = newValue;
                                        });
                                      },
                                      buttonStyleData: ButtonStyleData(
                                        height: 48,
                                        width: double.infinity,
                                        padding: const EdgeInsets.only(
                                            left: 14, right: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.white,
                                          border: Border.all(
                                              color: const Color(0xFFCED4DA),
                                              width: 1.5),
                                        ),
                                        elevation: 0,
                                      ),
                                      iconStyleData: const IconStyleData(
                                        icon: Icon(Icons.arrow_drop_down),
                                        iconSize: 24,
                                        iconEnabledColor: Color(0xFFb0b6c3),
                                        iconDisabledColor: Colors.grey,
                                      ),
                                      dropdownStyleData: DropdownStyleData(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: Colors.white,
                                        ),
                                        scrollbarTheme: ScrollbarThemeData(
                                          radius: const Radius.circular(6),
                                          thickness:
                                              MaterialStateProperty.all(6),
                                          thumbVisibility:
                                              MaterialStateProperty.all(true),
                                        ),
                                      ),
                                      menuItemStyleData: const MenuItemStyleData(
                                        height: 40,
                                        padding:
                                            EdgeInsets.only(left: 14, right: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Due Date',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: blueColor)),
                                  const SizedBox(height: 10),
                                  Container(
                                    height: 48,
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF1F3F6),
                                        border: Border.all(
                                            width: 1.5,
                                            color: const Color(0xFFCED4DA)),
                                        borderRadius:
                                            BorderRadius.circular(8.0)),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _dateController.text.trim().isEmpty
                                                ? 'dd-mm-yyyy'
                                                : dateProvider.formatCurrentDate(
                                                    _dateController.text.trim()),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF8898aa),
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.calendar_today,
                                            size: 20, color: Color(0xFF8898aa)),
                                      ],
                                    ),
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
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canSave
                                      ? blueColor
                                      : const Color(0xFFE5E8ED),
                                  disabledBackgroundColor:
                                      const Color(0xFFE5E8ED),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                onPressed:
                                    (isloading || !canSave) ? null : _submitForm,
                                child: isloading
                                    ? const Center(
                                        child: SpinKitFadingCircle(
                                          color: Colors.white,
                                          size: 24.0,
                                        ),
                                      )
                                    : Text(
                                        'Edit Work Order',
                                        style: TextStyle(
                                            color: canSave
                                                ? const Color(0xFFf7f8f9)
                                                : const Color(0xFF9AA3B0),
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFffffff),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        side: BorderSide(color: blueColor),
                                        borderRadius:
                                            BorderRadius.circular(8.0))),
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold),
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
            ),
          );
        }
      }),
    );
  }

  Widget buildTextField(
      String label, String hintText, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8.0),
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
            ),
            child: TextFormField(
              controller: controller,
              focusNode: FocusNode(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool isLoading = false;
  bool isloading = false;
  bool formValid = true;

  void _submitForm() async {
    if (_formkey.currentState!.validate()) {
      setState(() {
        isloading = true;
      });

      // The PUT mails everyone and appends a history row on every success, so
      // a save with nothing changed is refused here (web parity:
      // VendorAddWork.jsx editworkorder).
      if (!_hasWorkOrderChanges()) {
        setState(() {
          isloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please change at least one field to update the Work Order')),
        );
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? rentalId = _selectedPropertyId;
      String? unitId = _selectedUnitId;

      List<Map<String, dynamic>> parts = partsAndLabor.map((part) {
        return {
          'parts_id': part["parts_id"],
          "parts_quantity": int.tryParse(part['qtyController'].text) ?? 0,
          "account": part['selectedAccount'],
          "description": part['descriptionController'].text,
          "charge_type": "Workorder Charge",
          "parts_price": double.tryParse(part['priceController'].text) ?? 0.0,
          "amount": double.tryParse(part['totalController'].text) ?? 0.0,
        };
      }).toList();
      WorkOrderRepository()
          .EditWorkOrder(
        adminId: id,
        workOrderid: widget.workorderId,
        workSubject: subject.text.trim(),
        staffMemberName: _selectedStaffs,
        workCategory: _selectedDropdownCategory?.name,
        workPerformed: perform.text.trim(),
        status: _selectedStatus,
        rentalAddress: properties[_selectedPropertyId],
        rentalUnit: units[_selectedUnitId],
        tenant: _selectedtenantId,
        rentalid: rentalId,
        unitid: unitId,
        workOrderImages: _imageUrls,
        vendorId: _selectedvendorsId,
        vendorNotes: vendornote.text.trim(),
        priority: _selectedOption,
        isBillable: isChecked,
        // Web parity (AddWorkorder.jsx): the string "Tenant" when billable,
        // otherwise "". This compared a bool to a String, which is always
        // false, so work_charge_to was stored as false every time.
        workChargeTo: isChecked ? 'Tenant' : '',
        date: _dateController.text.trim(),
        entry: _selectedEntry == 'Yes',
        parts: parts,
        notificationTime:
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      )
          .then((value) {
        setState(() {
          widget.property?.workSubject = subject.text;
        });
        // Success
        Fluttertoast.showToast(
          msg: "Work order updated successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        Navigator.pop(context, true);
      }).catchError((e) {
        // Error
        Fluttertoast.showToast(
          msg: "Failed to edit work order: ${friendlyErrorMessage(e)}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }).whenComplete(() {
        // Final cleanup
        setState(() {
          isloading = false;
        });
      });
    } else {
      setState(() {
        formValid = false;
      });
    }
  }
}
