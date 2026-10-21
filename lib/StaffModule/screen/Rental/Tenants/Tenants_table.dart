import 'dart:async';
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
import '../../../../provider/dateProvider.dart';
import '../../../model/staffpermission.dart';
import '../../../repository/staffpermission_provider.dart';
import '../../../repository/tenants.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/AdminTenantInsurance/AdminTenantInsuranceTable.dart';
import 'add_tenants.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../../Model/tenants.dart';
import '../../../../constant/constant.dart';

import '../../../widgets/drawer_tiles.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import 'Tenant_summary.dart';
import 'edit_tenants.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class Tenants_table extends StatefulWidget {
  @override
  _Tenants_tableState createState() => _Tenants_tableState();
}

class _Tenants_tableState extends State<Tenants_table>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<TenantsV2ListResult> futureTenants;
  Timer? _searchDebounce;
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

  // Filter checkbox
  bool includeFormerTenants = false;

  // Show every tenant the server returns for this page (current + former),
  // matching the web. The "Include Former" checkbox drives the server query
  // (tenantType=current vs all) via _tenantsPageFuture — we must NOT re-filter
  // client-side, otherwise rows get hidden and disagree with the page count.
  List<Tenant> getFilteredData(Map<String, List<Tenant>> categorizedData) {
    List<Tenant> filteredData = [];

    filteredData.addAll(categorizedData['currentTenants'] ?? []);
    filteredData.addAll(categorizedData['formerTenants'] ?? []);

    return filteredData;
  }

  Future<TenantsV2ListResult> _tenantsPageFuture() {
    return TenantsRepository().fetchTenantsV2Page(
      page: currentPage + 1,
      limit: itemsPerPage,
      search: searchvalue,
      tenantType: includeFormerTenants ? 'all' : 'current',
      sortBy: 'createdAt',
      sortOrder: 'desc',
    );
  }

  void _scheduleTenantsLoad() {
    setState(() {
      futureTenants = _tenantsPageFuture();
    });
  }

  void sortData(List<Tenant> data) {
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
          ? a.tenantFirstName!.compareTo(b.tenantFirstName!)
          : b.tenantFirstName!.compareTo(a.tenantFirstName!));
    } else if (sorting2 && !sorting1 && !sorting3) {
      data.sort((a, b) => ascending2
          ? a.rentalAddress!.compareTo(b.rentalAddress!)
          : b.rentalAddress!.compareTo(a.rentalAddress!));
    } else if (sorting3 && !sorting1 && !sorting2) {
      data.sort((a, b) => ascending3
          ? a.tenantPhoneNumber!.compareTo(b.tenantPhoneNumber!)
          : b.tenantPhoneNumber!.compareTo(a.tenantPhoneNumber!));
    }
  }

  String? selectedRole;
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
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold))
                        : Text("Name",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: blueColor, fontWeight: FontWeight.bold)),
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
            // Expanded(
            //   flex: 3,
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
            //         Text("   Phone", style: TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
            //         SizedBox(width: 5),
            //         ascending2
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
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
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
                    Text("Property",
                        textAlign: TextAlign.center,
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

  final List<String> items = ['Residential', "Commercial", "All"];

  String searchvalue = "";
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureTenants = _tenantsPageFuture();;
      fetchtenantsadded();;
      fetchCompany();;
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
    futureTenants = _tenantsPageFuture();
    fetchtenantsadded();
    fetchCompany();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
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
    Provider.of<StaffPermissionProvider>(context, listen: false)
        .fetchPermissions();
  }

  void handleEdit(Tenant tenants) async {
    //Handle edit action
    //
    // final result = await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => EditTenants(
    //            tenants: tenants,
    //         )));
    var check = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => EditTenants(
                  tenants: tenants,
                  tenantId: '',
                )));
    if (check == true) {
      _scheduleTenantsLoad();
    }
    /* if (result == true) {
      setState(() {
        futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
      });
    }*/
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
      desc: "Once deleted, you will not be able to recover this Tenants!",
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
              await TenantsRepository().deleteTenant(
                  tenantId: id,
                  companyName: companyName,
                  tenantEmail: '',
                  reason: reason.text);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              _scheduleTenantsLoad();
              fetchtenantsadded();
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

  List<Tenant> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Tenant> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(Tenant d) getField, int columnIndex,
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

  void handleDelete(Tenant tenants) {
    _showDeleteAlert(context, tenants.tenantId!);

    // Handle delete action
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(Tenant d)? getField) {
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

  Widget _buildDataCell(String text, Tenant tenants) {
    return TableCell(
      child: InkWell(
        onTap: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ResponsiveTenantSummary(
                      tenants: tenants, tenantId: tenants.tenantId!)));
        },
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0, left: 16),
          child: Text(text.isEmpty ? "N/A" : text,
              style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  // Resend setup / password-reset email from the tenant table (web parity).
  // The server picks the right template (setup / resend / reset) from the
  // tenant's welcome_email_sent_at / password_set_at state.
  Future<void> _handleResendSetupEmail(Tenant data) async {
    await TenantsRepository().sendSetupEmail(data.tenantId ?? '');
  }

  // Web parity (TenantsTable.js): per-tenant Enable/Disable 2FA from the row
  // actions. Enable posts method "email"; takes effect on the tenant's next
  // login. The set guards against double taps while a call is in flight.
  final Set<String> _twoFaBusy = {};

  Future<void> _handleToggle2FA(Tenant data) async {
    final String id = data.tenantId ?? '';
    if (id.isEmpty || _twoFaBusy.contains(id)) return;
    final bool enable = !data.twoFactorEnabled;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          enable ? 'Enable 2FA' : 'Disable 2FA',
          style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${enable ? 'Enable' : 'Disable'} two-factor authentication for '
          '${data.tenantFirstName ?? ''} ${data.tenantLastName ?? ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: blueColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              enable ? 'Enable' : 'Disable',
              style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _twoFaBusy.add(id));
    final bool ok = await TenantsRepository().setTenant2FA(
      tenantId: id,
      enable: enable,
      email: data.tenantEmail,
      phoneNumber: data.tenantPhoneNumber,
    );
    if (!mounted) return;
    setState(() {
      _twoFaBusy.remove(id);
      if (ok) data.twoFactorEnabled = enable;
    });
  }

  Widget _buildActionsCell(Tenant data) {
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
                onTap: () => _handleResendSetupEmail(data),
                child: const FaIcon(
                  FontAwesomeIcons.envelope,
                  size: 27,
                ),
              ),
              const SizedBox(
                width: 15,
              ),
              // Web hides the 2FA action for trial accounts.
              if (data.adminId != "is_trial") ...[
                InkWell(
                  onTap: () => _handleToggle2FA(data),
                  child: _twoFaBusy.contains(data.tenantId)
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FaIcon(
                          FontAwesomeIcons.shieldHalved,
                          size: 26,
                          color: data.twoFactorEnabled
                              ? const Color(0xFFB55B3D)
                              : blueColor,
                        ),
                ),
                const SizedBox(
                  width: 15,
                ),
              ],
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

  int rentalCount = 0;
  int propertyCountLimit = 0;
  Future<void> fetchtenantsadded() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    final response = await apiGet(
      Uri.parse('${Api_url}/api/tenant/limitation/$adminid'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final jsonData = json.decode(response.body);
    if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
      setState(() {
        rentalCount = jsonData['rentalCount'];
        //propertyCountLimit = jsonData['propertyCountLimit'];
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
          "The limit for adding tenants according to the plan has been reached.",
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

  final _scrollController = ScrollController();

  String companyName = '';
  Future<void> fetchCompany() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");

    if (adminId != null) {
      try {
        String fetchedCompanyName =
            await TenantsRepository().fetchCompanyName(adminId);
        setState(() {
          companyName = fetchedCompanyName;
        });
      } catch (e) {
        // Handle error state, e.g., show error message to user
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    final permissionProvider = Provider.of<StaffPermissionProvider>(context);
    StaffPermission? permissions = permissionProvider.permissions;
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Tenants",
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
                            // The gap only separates the title from + Add; without Add the title
                            // runs to where the button ended.
                            padding: EdgeInsets.only(right: permissions?.tenantAdd == true ? 8.0 : 0),
                            child: titleBar(
                              width: double.infinity,
                              title: 'Tenants',
                            ),
                          ),
                        ),
                        // Web shows Add only with the Tenant Add permission.
                        if (permissions?.tenantAdd == true)
                        Flexible(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () async {
                                final result = await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (context) => AddTenant()));
                                if (result == true) {
                                  _scheduleTenantsLoad();
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
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 12, right: 10),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 20),
                        Expanded(
                          child: Material(
                          //  elevation: 3,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
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
                                  border: Border.all(color: Color(0xFFDBE0E5))),
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
                                        });
                                        _searchDebounce?.cancel();
                                        _searchDebounce = Timer(
                                            const Duration(milliseconds: 400),
                                            () {
                                          if (!mounted) return;
                                          setState(() {
                                            currentPage = 0;
                                            futureTenants = _tenantsPageFuture();
                                          });
                                        });
                                      },
                                      cursorColor: blueColor,
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "Search here...",
                                        hintStyle: TextStyle(
                                            // fontWeight: FontWeight.bold,
                                            color: Color(0xFF8A95A8),
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 14
                                                : 18),
                                        contentPadding: (EdgeInsets.only(
                                            left: 8, bottom: 10, top: 5)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Spacer(),
                        // Expanded(
                        //   child: Container(
                        //     child: Text(
                        //       'Added : ${rentalCount.toString()} Total: ${propertyCountLimit.toString()}',
                        //       style: TextStyle(
                        //         fontWeight: FontWeight.bold,
                        //         color: Color(0xFF8A95A8),
                        //         fontSize:
                        //             MediaQuery.of(context).size.width < 500 ? 13 : 21,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // Column(
                        //   mainAxisAlignment: MainAxisAlignment.end,
                        //   crossAxisAlignment: CrossAxisAlignment.end,
                        //   children: [
                        //     Container(
                        //       child: Text(
                        //         'Added : ${rentalCount.toString()}',
                        //         style: TextStyle(
                        //           fontWeight: FontWeight.bold,
                        //           color: Color(0xFF8A95A8),
                        //           fontSize:
                        //           MediaQuery.of(context).size.width < 500 ? 14 : 21,
                        //         ),
                        //       ),
                        //     ),
                        //     SizedBox(
                        //       height: 5,
                        //     ),
                        //     Container(
                        //       child: Text(
                        //         'Total : ${propertyCountLimit.toString()}',
                        //         style: TextStyle(
                        //           fontWeight: FontWeight.bold,
                        //           color: Color(0xFF8A95A8),
                        //           fontSize:
                        //           MediaQuery.of(context).size.width < 500 ? 14 : 21,
                        //         ),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        if (MediaQuery.of(context).size.width < 500)
                          SizedBox(width: 8),
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 20),
                      ],
                    ),
                  ),
                  // Count display and filter section
                  Padding(
                    padding: const EdgeInsets.only(left: 17, right: 17,top: 10,),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Count display
                              FutureBuilder<TenantsV2ListResult>(
                                future: futureTenants,
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    final c = snapshot.data!.counts;
                                    int currentCount = c['currentCount'] ??
                                        snapshot.data!.categorized[
                                                'currentTenants']?.length ??
                                        0;
                                    int formerCount = c['formerCount'] ??
                                        snapshot.data!.categorized[
                                                'formerTenants']?.length ??
                                        0;
                                    int applicantCount =
                                        c['applicantCount'] ?? 0;
                                    int totalCount = currentCount + formerCount;

                                    return Row(
                                      children: [
                                        Text(
                                          'Current: $currentCount | ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        Text(
                                          'Former: $formerCount | ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (applicantCount > 0)
                                          Text(
                                            'Applicants: $applicantCount | ',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        Text(
                                          'Total: $totalCount',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                  return Text(
                                    'Loading...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                              //SizedBox(height: 12),
                              // Include Former Tenants checkbox
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: Checkbox(
                                      value: includeFormerTenants,
                                      onChanged: (value) {
                                        setState(() {
                                          includeFormerTenants = value!;
                                          currentPage =
                                              0; // Reset to first page
                                          futureTenants = _tenantsPageFuture();
                                        });
                                      },
                                      activeColor: blueColor,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Include Former Tenants',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 20),
                      ],
                    ),
                  ),
                  // if (MediaQuery.of(context).size.width > 500)
                  //   const SizedBox(height: 25),
                  // if (MediaQuery.of(context).size.width < 500)
                  //for phone
                  Padding(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 500 ? 14 : 28),
                    child: FutureBuilder<TenantsV2ListResult>(
                      future: futureTenants,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ColabShimmerLoadingWidget();
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                        } else if (!snapshot.hasData) {
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
                                  SizedBox(
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
                          // Get filtered data based on checkbox selections
                          var data =
                              getFilteredData(snapshot.data!.categorized);

                          if (data.isEmpty) {
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
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "No Data Available for Selected Filters",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 16),
                                    )
                                  ],
                                ),
                              ),
                            );
                          }

                          sortData(data);
                          if (data.isNotEmpty) {
                          }
                          final totalPages = (snapshot.data!.pagination
                                      ?.totalPages ??
                                  1)
                              .clamp(1, 1 << 30);
                          final currentPageData = data;
                          final bool canChangePageSize = data.isNotEmpty;
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                // const SizedBox(height: 10),
                                _buildHeaders(),
                                const SizedBox(height: 10),
                                Container(
                                  child: Column(
                                    children: currentPageData.isEmpty
                                        ? [kNoSearchResults(context)]
                                        : currentPageData
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      int index = entry.key;
                                      bool isExpanded = expandedIndex == index;
                                      Tenant tenants = entry.value;
                                      //return CustomExpansionTile(data: Propertytype, index: index);
                                      return Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        decoration: BoxDecoration(
                                          color: index % 2 != 0
                                              ? const Color(0xFFF4F8FF)
                                              : Colors.white,
                                          border: Border.all(
                                              color: const Color(0xFFDBE0E5)),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        // decoration: BoxDecoration(
                                        //   border: Border.all(color: blueColor),
                                        // ),
                                        child: Column(
                                          children: <Widget>[
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Padding(
                                                padding:
                                                    const EdgeInsets.all(2.0),
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
                                                            expandedIndex =
                                                                null;
                                                          } else {
                                                            expandedIndex =
                                                                index;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .only(left: 5),
                                                        padding: !isExpanded
                                                            ? const EdgeInsets
                                                                .only(
                                                                bottom: 10)
                                                            : const EdgeInsets
                                                                .only(top: 10),
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
                                                      child: InkWell(
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
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(10.0),
                                                          child: Text(
                                                            '${tenants.tenantFirstName ?? ''} ${tenants.tenantLastName ?? ''}',
                                                            style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            .05),
                                                    Expanded(
                                                      flex: 3,
                                                      child: Text(
                                                        // Address + unit like web's Tenants list.
                                                        tenantPropertyLine(tenants),
                                                        textAlign:
                                                            TextAlign.start,
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
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
                                                    const EdgeInsets.all(16),
                                                decoration: const BoxDecoration(
                                                  border: Border(
                                                    top: BorderSide(
                                                        color:
                                                            Color(0xFFDBE0E5),
                                                        width: 1),
                                                  ),
                                                ),
                                                child: SingleChildScrollView(
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
                                                            size: 40,
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
                                                                            'Email : ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${tenants.tenantEmail}',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            'Created On : ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text:
                                                                            '${tenants.createdAt != null && tenants.createdAt!.isNotEmpty ? (dateProvider.formatCurrentDate(tenants.createdAt!) ?? 'Invalid date') : 'Invalid date'}',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 5,
                                                                ),
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            'Phone : ',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color: blueColor), // Bold and black
                                                                      ),
                                                                      TextSpan(
                                                                        text: formatPhoneNumber(
                                                                            '${tenants.tenantPhoneNumber}'),
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color: grey), // Light and grey
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .end,
                                                        children: [
                                                           GestureDetector(
                                                            onTap: () async {
                                                              await Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder: (context) => ResponsiveTenantSummary(
                                                                          tenants:
                                                                              tenants,
                                                                          tenantId:
                                                                              tenants.tenantId!)));
                                                              // An edit made on the Summary must show here on return.
                                                              if (mounted) _scheduleTenantsLoad();
                                                            },
                                                            child: Container(
                                                              height: 35,
                                                              width: 35,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .grey
                                                                    .shade200,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
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
                                                                        .eye,
                                                                    size: 15,
                                                                    color: Colors
                                                                        .black,
                                                                  ),
                                                                  SizedBox(
                                                                      width: 2),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                      
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          // Web shows Edit only with the Tenant Edit permission.
                                                          if (permissions?.tenantEdit == true) ...[
                                                          GestureDetector(
                                                            onTap: () async {
                                                              var check = await Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder: (context) => EditTenants(
                                                                            tenants:
                                                                                tenants,
                                                                            tenantId:
                                                                                '',
                                                                          )));
                                                              if (check ==
                                                                  true) {
                                                                _scheduleTenantsLoad();
                                                              }
                                                            },
                                                            child: Container(
                                                              height: 35,
                                                              width: 35,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  color: Colors
                                                                      .green
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
                                                                    FontAwesomeIcons
                                                                        .edit,
                                                                    size: 15,
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
                                                          ],
                                                          // Web hides the whole row-actions menu without Tenant Edit or Delete.
                                                          if (permissions?.tenantEdit == true ||
                                                              permissions?.tenantDelete == true) ...[
                                                          GestureDetector(
                                                            onTap: () => _handleResendSetupEmail(tenants),
                                                            child: Container(
                                                              height: 35,
                                                              width: 35,
                                                              decoration: BoxDecoration(
                                                                  borderRadius: BorderRadius.circular(8),
                                                                  color: Colors.blue.shade50),
                                                              child: const Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  FaIcon(
                                                                    FontAwesomeIcons.envelope,
                                                                    size: 15,
                                                                    color: Colors.blue,
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Web hides the 2FA action for trial accounts.
                                                          if (tenants.adminId != "is_trial") ...[
                                                            const SizedBox(
                                                              width: 5,
                                                            ),
                                                            GestureDetector(
                                                              onTap: () => _handleToggle2FA(tenants),
                                                              child: Container(
                                                                height: 35,
                                                                width: 35,
                                                                decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    color: tenants.twoFactorEnabled
                                                                        ? const Color(0xFFF9EDE7)
                                                                        : const Color(0xFFEAF0FB)),
                                                                child: Row(
                                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                                  children: [
                                                                    _twoFaBusy.contains(tenants.tenantId)
                                                                        ? const SizedBox(
                                                                            height: 15,
                                                                            width: 15,
                                                                            child: CircularProgressIndicator(strokeWidth: 2),
                                                                          )
                                                                        : FaIcon(
                                                                            FontAwesomeIcons.shieldHalved,
                                                                            size: 15,
                                                                            color: tenants.twoFactorEnabled
                                                                                ? const Color(0xFFB55B3D)
                                                                                : blueColor,
                                                                          ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                          ],
                                                          if (permissions?.tenantDelete == true) ...[
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                           GestureDetector(
                                                            onTap: () {
                                                              _showDeleteAlert(
                                                                  context,
                                                                  tenants
                                                                      .tenantId!);
                                                            },
                                                            child: Container(
                                                              height: 35,
                                                              width: 35,
                                                              decoration: BoxDecoration(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                  color: Colors
                                                                      .red
                                                                      .shade50),
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
                                                                    color: Colors
                                                                        .red,
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
                                if (totalPages > 1)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          // Text('Rows per page:'),
                                          const SizedBox(width: 10),
                                          Material(
                                            elevation:
                                                canChangePageSize ? 3 : 0,
                                            color: canChangePageSize
                                                ? null
                                                : const Color(0xFFF0F0F0),
                                            child: Container(
                                              height: 40,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12.0),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: canChangePageSize
                                                        ? Colors.grey
                                                        : Colors.grey
                                                            .shade400),
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
                                                  onChanged: canChangePageSize
                                                      ? (newValue) {
                                                          setState(() {
                                                            itemsPerPage =
                                                                newValue!;
                                                            currentPage = 0;
                                                            futureTenants =
                                                                _tenantsPageFuture();
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
                                              color: totalPages > 1 &&
                                                      currentPage > 0
                                                  ? blueColor
                                                  : Colors.grey,
                                            ),
                                            onPressed: totalPages > 1 &&
                                                    currentPage > 0
                                                ? () {
                                                    setState(() {
                                                      currentPage--;
                                                      futureTenants =
                                                          _tenantsPageFuture();
                                                    });
                                                  }
                                                : null,
                                          ),
                                          Text(
                                            'Page ${currentPage + 1} of $totalPages',
                                            style: TextStyle(
                                              color: totalPages > 1
                                                  ? Colors.black87
                                                  : Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          IconButton(
                                            icon: FaIcon(
                                              FontAwesomeIcons
                                                  .circleChevronRight,
                                              color: totalPages > 1 &&
                                                      currentPage <
                                                          totalPages - 1
                                                  ? blueColor
                                                  : Colors.grey,
                                            ),
                                            onPressed: totalPages > 1 &&
                                                    currentPage <
                                                        totalPages - 1
                                                ? () {
                                                    setState(() {
                                                      currentPage++;
                                                      futureTenants =
                                                          _tenantsPageFuture();
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
                  // if (MediaQuery.of(context).size.width > 500)
                  //   //for teblet
                  //   FutureBuilder<List<Tenant>>(
                  //     future: futureTenants,
                  //     builder: (context, snapshot) {
                  //       if (snapshot.connectionState ==
                  //           ConnectionState.waiting) {
                  //         return ShimmerTabletTable();
                  //       } else if (snapshot.hasError) {
                  //         return Center(
                  //             child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                  //       } else if (!snapshot.hasData ||
                  //           snapshot.data!.isEmpty) {
                  //         return Container(
                  //           height: MediaQuery.of(context).size.height * .5,
                  //           child: Center(
                  //             child: Column(
                  //               mainAxisAlignment: MainAxisAlignment.center,
                  //               crossAxisAlignment: CrossAxisAlignment.center,
                  //               children: [
                  //                 Image.asset(
                  //                   "assets/images/no_data.jpg",
                  //                   height: 200,
                  //                   width: 200,
                  //                 ),
                  //                 const SizedBox(
                  //                   height: 10,
                  //                 ),
                  //                 Text(
                  //                   "No Data Available",
                  //                   style: TextStyle(
                  //                       fontWeight: FontWeight.bold,
                  //                       color: blueColor,
                  //                       fontSize: 16),
                  //                 )
                  //               ],
                  //             ),
                  //           ),
                  //         );
                  //       } else {
                  //         List<Tenant>? filteredData = [];
                  //         _tableData = snapshot.data!;
                  //         if (selectedRole == null && searchvalue == "") {
                  //           filteredData = snapshot.data;
                  //         } else if (selectedRole == "All") {
                  //           filteredData = snapshot.data;
                  //         } else if (searchvalue.isNotEmpty) {
                  //           filteredData = snapshot.data!
                  //               .where((rentals) =>
                  //                   rentals.tenantFirstName!
                  //                       .toLowerCase()
                  //                       .contains(searchvalue.toLowerCase()) ||
                  //                   rentals.tenantLastName!
                  //                       .toLowerCase()
                  //                       .contains(searchvalue.toLowerCase()))
                  //               .toList();
                  //         }
                  //         _tableData = _tableData.reversed.toList();
                  //         _tableData = filteredData!;
                  //         totalrecords = _tableData.length;
                  //         return SingleChildScrollView(
                  //           child: Column(
                  //             children: [
                  //               Container(
                  //                 child: Padding(
                  //                   padding: const EdgeInsets.symmetric(
                  //                       horizontal: 20.0, vertical: 5),
                  //                   child: Column(
                  //                     children: [
                  //                       SingleChildScrollView(
                  //                         scrollDirection: Axis.horizontal,
                  //                         child: Padding(
                  //                           padding: const EdgeInsets.only(
                  //                               left: 20, right: 20),
                  //                           child: Container(
                  //                             // width: MediaQuery.of(context).size.width *
                  //                             //     .91,
                  //                             child: Table(
                  //                               defaultColumnWidth:
                  //                                   const IntrinsicColumnWidth(),
                  //                               children: [
                  //                                 TableRow(
                  //                                   decoration: BoxDecoration(
                  //                                     border: Border.all(
                  //                                         // color: blueColor
                  //                                         ),
                  //                                   ),
                  //                                   children: [
                  //                                     // _buildHeader(
                  //                                     //     'Tenant Name',
                  //                                     //     0,
                  //                                     //     (tenants) =>
                  //                                     //         tenants.tenantFirstName! ) ,
                  //                                     _buildHeader(
                  //                                         'Tenant Name',
                  //                                         0,
                  //                                         (tenants) =>
                  //                                             '${tenants.tenantFirstName ?? ''} ${tenants.tenantLastName ?? ''}'
                  //                                                 .trim()),
                  //                                     _buildHeader(
                  //                                         'Property',
                  //                                         1,
                  //                                         (tenants) => tenants
                  //                                             .rentalAddress!),
                  //                                     _buildHeader(
                  //                                         'Phone',
                  //                                         2,
                  //                                         (tenants) => tenants
                  //                                             .tenantPhoneNumber!),
                  //                                     _buildHeader(
                  //                                         'Email',
                  //                                         3,
                  //                                         (tenants) => tenants
                  //                                             .tenantAlternativeEmail!),
                  //                                     _buildHeader(
                  //                                         'Created At',
                  //                                         4,
                  //                                         (tenants) => tenants
                  //                                             .createdAt!),
                  //                                     _buildHeader(
                  //                                         'Actions', 5, null),
                  //                                   ],
                  //                                 ),
                  //                                 TableRow(
                  //                                   decoration: const BoxDecoration(
                  //                                     border: Border.symmetric(
                  //                                         horizontal:
                  //                                             BorderSide.none),
                  //                                   ),
                  //                                   children: List.generate(
                  //                                       6,
                  //                                       (index) => TableCell(
                  //                                           child: Container(
                  //                                               height: 20))),
                  //                                 ),
                  //                                 for (var i = 0;
                  //                                     i < _pagedData.length;
                  //                                     i++)
                  //                                   TableRow(
                  //                                     decoration: BoxDecoration(
                  //                                       border: Border(
                  //                                         left: BorderSide(
                  //                                             color: blueColor),
                  //                                         right: BorderSide(
                  //                                             color: blueColor),
                  //                                         top: BorderSide(
                  //                                             color: blueColor),
                  //                                         bottom: i ==
                  //                                                 _pagedData
                  //                                                         .length -
                  //                                                     1
                  //                                             ? const BorderSide(
                  //                                                 color: Color
                  //                                                     .fromRGBO(
                  //                                                         21,
                  //                                                         43,
                  //                                                         81,
                  //                                                         1))
                  //                                             : BorderSide.none,
                  //                                       ),
                  //                                     ),
                  //                                     children: [
                  //                                       _buildDataCell(
                  //                                           '${_pagedData[i].tenantFirstName ?? ''} ${_pagedData[i].tenantLastName ?? ''}'
                  //                                               .trim(),
                  //                                           _pagedData[i]),
                  //                                       _buildDataCell(
                  //                                           _pagedData[i]
                  //                                                   .rentalAddress! ??
                  //                                               '',
                  //                                           _pagedData[i]),
                  //                                       // _buildDataCell(''),
                  //                                       _buildDataCell(
                  //                                           _pagedData[i]
                  //                                               .tenantPhoneNumber!
                  //                                               .toString(),
                  //                                           _pagedData[i]),
                  //                                       _buildDataCell(
                  //                                           _pagedData[i]
                  //                                               .tenantAlternativeEmail!
                  //                                               .toString(),
                  //                                           _pagedData[i]),
                  //                                       _buildDataCell(
                  //                                           _pagedData[i]
                  //                                               .createdAt!
                  //                                               .toString(),
                  //                                           _pagedData[i]),
                  //                                       _buildActionsCell(
                  //                                           _pagedData[i]),
                  //                                     ],
                  //                                   ),
                  //                               ],
                  //                             ),
                  //                           ),
                  //                         ),
                  //                       ),
                  //                       const SizedBox(height: 25),
                  //                       _buildPaginationControls(),
                  //                     ],
                  //                   ),
                  //                 ),
                  //               ),
                  //               const SizedBox(height: 25),
                  //             ],
                  //           ),
                  //         );
                  //       }
                  //     },
                  //   ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}
