import 'package:flutter/material.dart';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/mortgage/mortgage_summery.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';
import '../../../provider/dateProvider.dart';
import 'Addmortgage.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

class PropertyMortgageTable extends StatefulWidget {
  final String propertyId;
  final bool showAppBar;
  final bool showDrawer;
  final bool showAddButton;

  const PropertyMortgageTable({
    Key? key,
    required this.propertyId,
    this.showAppBar = false,
    this.showDrawer = false,
    this.showAddButton = true,
  }) : super(key: key);

  @override
  State<PropertyMortgageTable> createState() => _PropertyMortgageTableState();
}

class _PropertyMortgageTableState extends State<PropertyMortgageTable>
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
      String? id = prefs.getString('adminId');

      // Use property-specific API endpoint
      final response = await apiGet(
        Uri.parse('${Api_url}/api/mortgage/${widget.propertyId}'),
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
            _filteredMortgages = List.from(_mortgages);
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No mortgages found for this property.'),
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
        builder: (context) => AddMortgageScreen(
          propertyId: widget.propertyId,
          drawerCurrentPage: 'Properties',
        ),
      ),
    ).then((_) {
      // Refresh the mortgage list when returning from the form
      _loadMortgages();
    });
  }

  void _deleteMortgage(String id) {
    final TextEditingController reason = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Mortgage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this mortgage?'),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for deletion',
                  contentPadding: EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Web (Mortgage.jsx handleDeleteMortgage) keeps Delete
                // disabled until a reason is entered, and the server stores
                // it as deletion_reason for the audit log.
                if (reason.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a reason for deletion'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop();
                await _deleteMortgageRecord(id, reason.text.trim());
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  /// The row used to be dropped from the in-memory list with a success
  /// message and no request at all, so the mortgage returned on the next
  /// refresh and stayed live on web. Mirror web: only report success once the
  /// server confirms it, and refetch so the list stays truthful.
  Future<void> _deleteMortgageRecord(String id, String reason) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString('adminId');

      final response = await apiDelete(
        Uri.parse('${Api_url}/api/mortgage/$id'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM $adminId',
        },
        body: json.encode({'reason': reason}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mortgage deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadMortgages();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(data['message'] ?? 'Failed to delete mortgage'),
              backgroundColor: Colors.red,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverMessage.isNotEmpty
                ? serverMessage
                : 'Failed to delete mortgage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      logError('Error deleting mortgage: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error deleting mortgage: ${friendlyErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
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
          drawerCurrentPage: 'Properties',
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

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';
    final numValue = amount is String ? double.tryParse(amount) ?? 0 : amount;
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(numValue);
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
            Text(
              "    Borrower",
              style: TextStyle(
                  color: const Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
            ),
            Text(
              "Status      ",
              style: TextStyle(
                  color: const Color(0xFF1E3A8A), fontWeight: FontWeight.bold),
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

  Widget _buildContent() {
    final dateProvider = Provider.of<DateProvider>(context);
    final totalPages = (_filteredMortgages.length / itemsPerPage).ceil();
    final currentPageData = _filteredMortgages
        .skip(currentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return Column(
      children: [
        const SizedBox(height: 20),
        // Header Section with Title and Add Button
        if (widget.showAddButton)
          Padding(
            padding: const EdgeInsets.all(0),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                ),
                Text(
                  "Mortgage Information",
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17),
                ),
                Spacer(),
                GestureDetector(
                  onTap: _openAddMortgageForm,
                  child: Container(
                    height: (MediaQuery.of(context).size.width < 500)
                        ? 50
                        : MediaQuery.of(context).size.width * 0.063,
                    width: (MediaQuery.of(context).size.width < 500)
                        ? MediaQuery.of(context).size.width * 0.23
                        : MediaQuery.of(context).size.width * 0.2,
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
                          fontSize:
                          MediaQuery.of(context).size.width < 500 ? 16 : 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // Search and Filter Section
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 11),
        //   child: Row(
        //     children: [
        //       const SizedBox(width: 10),
        //       Material(
        //         elevation: 0,
        //         borderRadius: BorderRadius.circular(8),
        //         child: Container(
        //           height: 50,
        //           width: MediaQuery.of(context).size.width * 0.49,
        //           decoration: BoxDecoration(
        //             color: Colors.white,
        //             borderRadius: BorderRadius.circular(8),
        //             border: Border.all(color: const Color(0xFF8A95A8)),
        //           ),
        //           child: TextField(
        //             controller: _searchController,
        //             onChanged: (value) {
        //               setState(() {
        //                 searchValue = value;
        //                 _filterMortgages();
        //               });
        //             },
        //             cursorColor: Colors.blue,
        //             decoration: const InputDecoration(
        //               border: InputBorder.none,
        //               hintText: "Search here...",
        //               hintStyle: TextStyle(color: Color(0xFF8A95A8)),
        //               contentPadding: EdgeInsets.all(11),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 10),
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 25),

        // Content Section
        _isLoading
            ? const Center(
          child: SpinKitFadingCircle(
            color: Colors.black,
            size: 50.0,
          ),
        )
            : _filteredMortgages.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No mortgages found for this property',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or add a new mortgage',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              _buildHeaders(),
              const SizedBox(height: 10),
              Container(
                child: Column(
                  children:
                  currentPageData.asMap().entries.map((entry) {
                    int index = entry.key;
                    bool isExpanded = expandedIndex == index;
                    Map<String, dynamic> mortgage = entry.value;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
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
                                            : FontAwesomeIcons
                                            .sortDown,
                                        size: 20,
                                        color:
                                        const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 8.0),
                                      child: InkWell(
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
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text:
                                                '${mortgage['borrower_first_name'] ?? 'N/A'} ${mortgage['borrower_last_name'] ?? 'N/A'}',
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight:
                                                  FontWeight.bold,
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
                                    flex: 2,
                                    child: Container(
                                      margin: EdgeInsets.only(
                                          left: 36, right: 5),
                                      padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                            mortgage['status'])
                                            .withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(10),
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
                                                mortgage['status']),
                                            fontWeight:
                                            FontWeight.w600,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ListTile(
                          //   contentPadding: EdgeInsets.zero,
                          //   title: Padding(
                          //     padding: const EdgeInsets.all(2.0),
                          //     child: Row(
                          //       mainAxisAlignment:
                          //           MainAxisAlignment.start,
                          //       crossAxisAlignment:
                          //           CrossAxisAlignment.center,
                          //       children: <Widget>[
                          //         InkWell(
                          //           onTap: () {
                          //             setState(() {
                          //               if (expandedIndex == index) {
                          //                 expandedIndex = null;
                          //               } else {
                          //                 expandedIndex = index;
                          //               }
                          //             });
                          //           },
                          //           child: Container(
                          //             margin: const EdgeInsets.only(
                          //                 left: 5, right: 5),
                          //             padding: !isExpanded
                          //                 ? const EdgeInsets.only(
                          //                     bottom: 10)
                          //                 : const EdgeInsets.only(
                          //                     top: 10),
                          //             child: FaIcon(
                          //               isExpanded
                          //                   ? FontAwesomeIcons.sortUp
                          //                   : FontAwesomeIcons
                          //                       .sortDown,
                          //               size: 20,
                          //               color:
                          //                   const Color(0xFF1E3A8A),
                          //             ),
                          //           ),
                          //         ),
                          //         Flexible(
                          //           flex: 3,
                          //           child: Padding(
                          //             padding: const EdgeInsets.only(
                          //                 left: 8.0),
                          //             child: InkWell(
                          //               onTap: () {
                          //                 setState(() {
                          //                   if (expandedIndex ==
                          //                       index) {
                          //                     expandedIndex = null;
                          //                   } else {
                          //                     expandedIndex = index;
                          //                   }
                          //                 });
                          //               },
                          //               child: Text.rich(
                          //                 TextSpan(
                          //                   children: [
                          //                     TextSpan(
                          //                       text:
                          //                           '${mortgage['bank_name'] ?? 'N/A'}',
                          //                       style: TextStyle(
                          //                         color: blueColor,
                          //                         fontWeight:
                          //                             FontWeight.bold,
                          //                         fontSize: 13,
                          //                       ),
                          //                     ),
                          //                   ],
                          //                 ),
                          //               ),
                          //             ),
                          //           ),
                          //         ),
                          //         Flexible(
                          //           flex: 2,
                          //           child: Container(
                          //             margin: EdgeInsets.only(
                          //                 left: 50, right: 5),
                          //             padding:
                          //                 const EdgeInsets.symmetric(
                          //                     horizontal: 8,
                          //                     vertical: 6),
                          //             decoration: BoxDecoration(
                          //               color: _getStatusColor(
                          //                       mortgage['status'])
                          //                   .withOpacity(0.1),
                          //               borderRadius:
                          //                   BorderRadius.circular(12),
                          //               border: Border.all(
                          //                 color: _getStatusColor(
                          //                     mortgage['status']),
                          //                 width: 1,
                          //               ),
                          //             ),
                          //             child: Center(
                          //               child: Text(
                          //                 (mortgage['status'] ??
                          //                         'unknown')
                          //                     .toString()
                          //                     .toUpperCase(),
                          //                 style: TextStyle(
                          //                   color: _getStatusColor(
                          //                       mortgage['status']),
                          //                   fontWeight:
                          //                       FontWeight.w600,
                          //                   fontSize: 10,
                          //                 ),
                          //               ),
                          //             ),
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          //   ),
                          // ),
                          if (isExpanded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2.0),
                              margin:
                              const EdgeInsets.only(bottom: 2),
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
                                          color: Colors.transparent,
                                        ),
                                        Flexible(
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
                                                    '${mortgage['interest_rate'] ?? 0}%'),
                                              ),
                                              _buildTableRow(
                                                'Mortgage#',
                                                _getDisplayValue(
                                                    mortgage[
                                                    'mortgage_no']),
                                                'Start Date',
                                                _getDisplayValue(dateProvider.formatCurrentDate(mortgage['start_date'])),
                                              ),
                                              _buildTableRow(
                                                'End Date',
                                                _getDisplayValue(dateProvider.formatCurrentDate(mortgage[
                                                'end_date'])),
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
                                              _viewMortgage(mortgage),
                                          child: Container(
                                            height: 35,
                                            width: 35,
                                            decoration: BoxDecoration(
                                              color: Colors
                                                  .grey.shade200,
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
                                                      .eye,
                                                  size: 15,
                                                  color: Colors.black,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        GestureDetector(
                                          onTap: () =>
                                              _editMortgage(mortgage),
                                          child: Container(
                                            height: 35,
                                            width: 35,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(8),
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
                                                  color: Colors.green,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        GestureDetector(
                                          onTap: () =>
                                              _deleteMortgage(
                                                  mortgage['_id']),
                                          child: Container(
                                            height: 35,
                                            width: 35,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                              BorderRadius
                                                  .circular(8),
                                              color:
                                              Colors.red.shade50,
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
                            border: Border.all(color: Colors.grey),
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
                              onChanged: _filteredMortgages.length >
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
                      Text('Page ${currentPage + 1} of $totalPages'),
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
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAppBar) {
      return Scaffold(
        appBar: widget_302.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: widget.showDrawer
            ? CustomDrawer(
          currentpage: "Mortgage",
          dropdown: true,
        )
            : null,
        // This screen had no offline state at all; a failed request used to
        // leave it blank or showing an error string with no way to retry.
        body: isOffline
            ? NoInternetView(onRetry: retryNow)
            : _buildContent(),
      );
    } else {
      return _buildContent();
    }
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
