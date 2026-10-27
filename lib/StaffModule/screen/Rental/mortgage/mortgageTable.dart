import 'package:flutter/material.dart';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/mortgage_summery.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import 'Addmortgage.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/assign_properties_dialog.dart';

class MortgageTable extends StatefulWidget {
  const MortgageTable({Key? key}) : super(key: key);

  @override
  State<MortgageTable> createState() => _MortgageTableState();
}

class _MortgageTableState extends State<MortgageTable>
    with NetworkRetryState {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _mortgages = [];
  List<Map<String, dynamic>> _filteredMortgages = [];
  bool _isLoading = false;
  int? expandedIndex;
  String searchValue = "";
  int currentPage = 0;
  int itemsPerPage = 10;
  String selectedStatus = "All";
  final List<String> statusOptions = [
    "All",
    "Active",
    "Paid Off",
    "Defaulted",
    "Refinanced"
  ];

  List<int> itemsPerPageOptions = [10, 25, 50, 100];

  // Sorting variables
  bool sorting1 = false; // Bank name
  bool sorting2 = false; // Status
  bool ascending1 = false;
  bool ascending2 = false;

  void sortData(List<Map<String, dynamic>> data) {
    // Apply user-selected sorting only if explicitly chosen
    if (sorting1 && !sorting2) {
      data.sort((a, b) {
        final nameA = _getLenderName(a).toLowerCase();
        final nameB = _getLenderName(b).toLowerCase();
        final cmp = nameA.compareTo(nameB);
        return ascending1 ? cmp : -cmp;
      });
    } else if (sorting2 && !sorting1) {
      data.sort((a, b) => ascending2
          ? (a['status'] ?? '')
              .toString()
              .compareTo((b['status'] ?? '').toString())
          : (b['status'] ?? '')
              .toString()
              .compareTo((a['status'] ?? '').toString()));
    }
  }

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadMortgages();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadMortgages();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMortgages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString("staff_id");

      final response = await apiGet(
        Uri.parse('${Api_url}/api/mortgage/'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM $id',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _mortgages = List<Map<String, dynamic>>.from(data['data']);
            // Sort by mortgage number in descending order
            _mortgages.sort((a, b) {
              String mortgageA = (a['mortgage_no'] ?? '').toString();
              String mortgageB = (b['mortgage_no'] ?? '').toString();
              return mortgageB.compareTo(mortgageA);
            });
            _filteredMortgages = List.from(_mortgages);
          });
          // Web parity: web recomputes its filtered list on every render
          // (Mortgage.jsx `filterMortgagesBySearch`), so an active search
          // survives a data refresh. Re-apply the current search here
          // instead of dropping the user back to the unfiltered list while
          // their search text is still on screen.
          _filterMortgages();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No mortgages found in the response.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please login again.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _clearMortgages();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load mortgages: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _clearMortgages();
      }
    } catch (e) {
      if (mounted) {
        // A network failure already flips this screen to its offline state,
        // which says it better than a red banner stacked on top of it.
        if (!isNetworkError(e)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading mortgages: ${friendlyErrorMessage(e)}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      _clearMortgages();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Web parity (Mortgage.jsx): when the mortgages can't be loaded, web
  /// shows an empty list next to the error. This used to fill the list with
  /// made-up sample mortgages instead.
  void _clearMortgages() {
    if (!mounted) return;
    setState(() {
      _mortgages = [];
      _filteredMortgages = [];
    });
  }

  void _filterMortgages() {
    setState(() {
      if (searchValue.isEmpty && selectedStatus == "All") {
        _filteredMortgages = List.from(_mortgages);
      } else {
        _filteredMortgages = _mortgages.where((mortgage) {
          bool matchesSearch = true;
          bool matchesStatus = true;

          // Search filter
          if (searchValue.isNotEmpty) {
            final searchLower = searchValue.toLowerCase();
            matchesSearch = (mortgage['bank_name']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ??
                    false) ||
                (mortgage['mortgage_no']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ??
                    false) ||
                (mortgage['loan_amount']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ??
                    false) ||
                (mortgage['borrower_first_name']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ??
                    false) ||
                (mortgage['borrower_last_name']
                        ?.toString()
                        .toLowerCase()
                        .contains(searchLower) ??
                    false);
          }

          // Status filter
          if (selectedStatus != "All") {
            matchesStatus = (mortgage['status']?.toString().toLowerCase() ==
                selectedStatus.toLowerCase());
          }

          return matchesSearch && matchesStatus;
        }).toList();
      }

      // Reset to first page when filtering
      currentPage = 0;
    });
  }

  void _openAddMortgageForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMortgageScreen(
          drawerCurrentPage: 'Reports',
        ),
      ),
    ).then((_) {
      // Refresh the mortgage list when returning from the form
      _loadMortgages();
    });
  }

  void _deleteMortgage(String id) {
    TextEditingController reason = TextEditingController();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this Mortgage!",
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
            // Web (Mortgage.jsx handleDeleteMortgage) keeps Delete disabled
            // until a reason is entered, and the server stores it as
            // deletion_reason for the audit log, so it can't be skipped here.
            if (reason.text.trim().isEmpty) {
              Fluttertoast.showToast(msg: "Please enter a reason for deletion");
              return;
            }
            Navigator.pop(context);
            await _deleteMortgageRecord(id, reason.text.trim());
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

  /// The row used to be dropped from the in-memory list with a success toast
  /// and no request at all, so the mortgage returned on the next refresh and
  /// stayed live on web. Mirror web: only report success once the server
  /// confirms it, and refetch so the list and the count stay truthful.
  Future<void> _deleteMortgageRecord(String id, String reason) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? staffId = prefs.getString("staff_id");

      final response = await apiDelete(
        Uri.parse('${Api_url}/api/mortgage/$id'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM $staffId',
        },
        body: json.encode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Fluttertoast.showToast(
            msg: "Mortgage deleted successfully",
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
          await _loadMortgages();
        } else {
          Fluttertoast.showToast(
            msg: data['message'] ?? 'Failed to delete mortgage',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        // Web parity: `error.response?.data?.message || "Error deleting
        // mortgage"`. A rejected delete comes back as a non-200 (the server
        // answers 404 "Mortgage not found" for an already-deleted record), so
        // reading the message only on a 200 meant the server's own reason was
        // replaced by a generic line exactly when it mattered.
        String serverMessage = '';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['message'] != null) {
            serverMessage = body['message'].toString().trim();
          }
        } catch (_) {}
        Fluttertoast.showToast(
          msg: serverMessage.isNotEmpty
              ? serverMessage
              : 'Failed to delete mortgage',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      logError('Error deleting mortgage: $e');
      Fluttertoast.showToast(
        msg: 'Error deleting mortgage: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void _editMortgage(Map<String, dynamic> mortgage) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMortgageScreen(
          mortgageId: mortgage['_id'],
          mortgageData: mortgage,
          drawerCurrentPage: 'Reports',
        ),
      ),
    ).then((_) {
      // Refresh the mortgage list when returning from the form
      _loadMortgages();
    });
  }

  void _viewMortgage(Map<String, dynamic> mortgage) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => MortgageSummary(mortgageData: mortgage)),
    ).then((_) {
      // Refresh the mortgage list when returning from the summary. It can
      // edit the mortgage and upload documents, so the row behind it goes
      // stale without this — same treatment as the add and edit handlers.
      _loadMortgages();
    });
  }

  void _openAssignPropertiesDialog(Map<String, dynamic> mortgage) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AssignPropertiesDialog(
          mortgageId: mortgage['_id'] ?? '',
          mortgageNo: (mortgage['mortgage_no'] ?? '').toString(),
          initialPropertyIds: mortgage['properties'] is List ? mortgage['properties'] : null,
          initialPropertyAssignments: mortgage['property_assignments'] is List ? mortgage['property_assignments'] : null,
          fullScreen: true,
          isStaffModule: true,
        ),
      ),
    ).then((saved) {
      if (saved == true) _loadMortgages();
    });
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';
    final numValue = amount is String ? double.tryParse(amount) ?? 0 : amount;
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(numValue);
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${_getMonthAbbr(date.month)}/${date.year}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _getLenderName(Map<String, dynamic> m) {
    return (m['bank_name'] ?? 'N/A').toString().trim();
  }

  String _getPropertyDisplay(List<dynamic> properties) {
    if (properties.isEmpty) return 'No Properties';
    return '${properties.length} ${properties.length > 1 ? '' : ''}';
  }

  Widget _buildHeaders() {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting1 == true) {
                      sorting2 = false;
                      ascending1 = !ascending1;
                      ascending2 = false;
                    } else {
                      sorting1 = true;
                      sorting2 = false;
                      ascending1 = true;
                      ascending2 = false;
                    }
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "    Lender",
                      style: TextStyle(
                          color: blueColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 3),
                    sorting1
                        ? (ascending1
                            ? Padding(
                                padding: const EdgeInsets.only(top: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortUp,
                                  size: 20,
                                  color: blueColor,
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortDown,
                                  size: 20,
                                  color: blueColor,
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
                      ascending2 = !ascending2;
                      ascending1 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = true;
                      ascending2 = true;
                      ascending1 = false;
                    }
                  });
                },
                child: Row(
                  children: [
                    Text(
                      "    Status",
                      style: TextStyle(
                          color: blueColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 5),
                    sorting2
                        ? (ascending2
                            ? Padding(
                                padding: const EdgeInsets.only(top: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortUp,
                                  size: 20,
                                  color: blueColor,
                                ),
                              )
                            : Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 7, left: 2),
                                child: FaIcon(
                                  FontAwesomeIcons.sortDown,
                                  size: 20,
                                  color: blueColor,
                                ),
                              ))
                        : const SizedBox(width: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
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
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 2.0),
                Text(
                  leftValue,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rightLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                ),
                const SizedBox(height: 2.0),
                Text(
                  rightValue,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayValue(String? value) {
    return (value == null || value.trim().isEmpty) ? '' : value;
  }

  @override
  Widget build(BuildContext context) {
    // Apply sorting to filtered mortgages
    sortData(_filteredMortgages);
    final totalPages = (_filteredMortgages.isEmpty ? 1 : (_filteredMortgages.length / itemsPerPage).ceil());
    final currentPageData = _filteredMortgages
        .skip(currentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Reports",
        dropdown: true,
      ),
      // This screen had no offline state at all; a failed request used to
      // leave it blank or showing an error string with no way to retry.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header Section with Title and Add Button
            Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width > 500)
                  SizedBox(
                    width: 13,
                  ),
                // Back arrow, the same as the other reports' headers.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black87,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title styled like the other reports' headers.
                Expanded(
                  flex: 3,
                  child: Text(
                    'Mortgages',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                ),
                Flexible(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: GestureDetector(
                      onTap: _openAddMortgageForm,
                      child: Container(
                        height: 40,
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
                if (MediaQuery.of(context).size.width > 500)
                  const SizedBox(width: 18),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // Search and Filter Section
          Padding(
            padding: const EdgeInsets.only(left: 11, right: 11),
            child: Row(
              children: [
                if (MediaQuery.of(context).size.width < 500)
                  const SizedBox(width: 2),
                if (MediaQuery.of(context).size.width > 500)
                  const SizedBox(width: 20),
                Material(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: (MediaQuery.of(context).size.width < 768) ? 45 : 60,
                    width: MediaQuery.of(context).size.width * 0.49,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF8A95A8)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          searchValue = value;
                          _filterMortgages();
                        });
                      },
                      cursorColor: Colors.blue,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search here...",
                        hintStyle: TextStyle(color: Color(0xFF8A95A8)),
                        contentPadding: EdgeInsets.all(11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(text: 'Added : ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A2332))),
                          // Counts the filtered list, so the number agrees with the rows on
                          // screen once a search term or status filter is applied.
                          // With no filter active `_filteredMortgages` holds every
                          // record, so this still reads as the full total.
                          TextSpan(text: '${_filteredMortgages.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2332))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          SizedBox(height: 5),
          // Content Section
          _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: SpinKitFadingCircle(
                      color: Colors.black,
                      size: 50.0,
                    ),
                  ),
                )
              : _filteredMortgages.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // The standard empty state used across reports.
                            Image.asset(
                              "assets/images/no_data_transparent.png",
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
                    )
                  : Padding(
                      padding: EdgeInsets.all(
                          MediaQuery.of(context).size.width < 500 ? 14 : 28),
                      child: Column(
                        children: [
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
                                  Map<String, dynamic> mortgage = entry.value;

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
                                                            left: 5, right: 5),
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
                                                      color: const Color(
                                                          0xFF1E3A8A),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 8.0),
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
                                                      child: Text.rich(
                                                        TextSpan(
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  _getLenderName(mortgage),
                                                              style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 13,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Container(
                                                    margin: EdgeInsets.only(
                                                        left: 2, right: 8),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 0,
                                                        vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(
                                                              mortgage[
                                                                  'status'])
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: _getStatusColor(
                                                            mortgage['status']),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        (mortgage['status'] ??
                                                                'unknown')
                                                            .toString()
                                                            .toUpperCase(),
                                                        style: TextStyle(
                                                          color: _getStatusColor(
                                                              mortgage[
                                                                  'status']),
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 10,
                                                        ),
                                                      ),
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
                                            margin: const EdgeInsets.only(
                                                bottom: 2),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      FaIcon(
                                                        isExpanded
                                                            ? FontAwesomeIcons
                                                                .sortUp
                                                            : FontAwesomeIcons
                                                                .sortDown,
                                                        size: 40,
                                                        color:
                                                            Colors.transparent,
                                                      ),
                                                      Expanded(
                                                        child: Table(
                                                          columnWidths: const {
                                                            0: FlexColumnWidth(),
                                                            1: FlexColumnWidth(),
                                                          },
                                                          children: [
                                                            _buildTableRow(
                                                              'Loan Amount:',
                                                              _getDisplayValue(
                                                                  _formatCurrency(
                                                                      mortgage[
                                                                          'loan_amount'])),
                                                              'Interest Rate:',
                                                              _getDisplayValue(
                                                                  '${(mortgage['interest_rate'] ?? 0).toStringAsFixed(2)}%'),
                                                            ),
                                                            _buildTableRow(
                                                              'Loan Number',
                                                              _getDisplayValue(
                                                                  mortgage[
                                                                      'mortgage_no']),
                                                              'Balance',
                                                              _getDisplayValue(
                                                                  _formatCurrency(
                                                                      mortgage[
                                                                          'remaining_balance'])),
                                                            ),
                                                            _buildTableRow(
                                                              'Properties',
                                                              _getDisplayValue(_getPropertyDisplay(
                                                                  mortgage['properties'] is List
                                                                      ? mortgage['properties'] as List
                                                                      : [])),
                                                              '',
                                                              _getDisplayValue(''),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _viewMortgage(
                                                                mortgage),
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .grey.shade200,
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
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _editMortgage(
                                                                mortgage),
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            color: Colors
                                                                .green.shade50,
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
                                                                    .edit,
                                                                size: 15,
                                                                color: Colors
                                                                    .green,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _deleteMortgage(
                                                                mortgage[
                                                                    '_id']),
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration:
                                                              BoxDecoration(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            color: Colors
                                                                .red.shade50,
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
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 5),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            _openAssignPropertiesDialog(
                                                                mortgage),
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.grey
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
                                                                    .link,
                                                                size: 15,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 15),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 15),
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

                            // Pagination Controls
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
                                            onChanged: _filteredMortgages
                                                        .length >
                                                    itemsPerPageOptions.first
                                                ? (newValue) {
                                                    setState(() {
                                                      itemsPerPage = newValue!;
                                                      currentPage = 0;
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
                                            : const Color(0xFF1E3A8A),
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
                                        FontAwesomeIcons.circleChevronRight,
                                        color: currentPage < totalPages - 1
                                            ? const Color(0xFF1E3A8A)
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
                        ),
                    ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'paid off':
        return Colors.blue;
      case 'defaulted':
        return Colors.red;
      case 'refinanced':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
