import 'package:three_zero_two_property/services/app_log.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../../constant/constant.dart';
import '../../../../../provider/dateProvider.dart';
import '../../../../../Model/PropertyInsuranceModel.dart';
import 'AddEditInsurancePolicy.dart';

class Insurance_Policies_Table extends StatefulWidget {
  final String propertyId;
  final bool showAppBar;
  final bool showDrawer;
  final bool showAddButton;

  const Insurance_Policies_Table({
    Key? key,
    required this.propertyId,
    this.showAppBar = false,
    this.showDrawer = false,
    this.showAddButton = true,
  }) : super(key: key);

  @override
  State<Insurance_Policies_Table> createState() =>
      _Insurance_Policies_TableState();
}

class _Insurance_Policies_TableState extends State<Insurance_Policies_Table>
    with NetworkRetryState {
  List<PropertyInsuranceData> _policies = [];
  List<PropertyInsuranceData> _filteredPolicies = [];
  bool _isLoading = false;
  int? expandedIndex;
  int currentPage = 0;
  int itemsPerPage = 10;

  List<int> itemsPerPageOptions = [10, 25, 50, 100];

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadInsurancePolicies();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadInsurancePolicies();
  }

  Future<void> _loadInsurancePolicies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? id = prefs.getString('adminId');


      final response = await apiGet(
        Uri.parse('${Api_url}/api/property-insurance/${widget.propertyId}'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM ${prefs.getString("staff_id") ?? id}',
        },
      ).timeout(const Duration(seconds: 30));


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _policies = (data['data'] as List)
                .map((item) => PropertyInsuranceData.fromJson(item))
                .where((policy) => policy.isDelete != true)
                .toList();
            _filteredPolicies = List.from(_policies);
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No insurance policies found for this property.'),
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to load insurance policies: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading insurance policies: ${friendlyErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _openAddPolicyForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditInsurancePolicy(
          propertyId: widget.propertyId,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadInsurancePolicies();
      }
    });
  }

  void _deletePolicy(String id) {
    _showDeleteAlert(context, id);
  }

  void _showDeleteAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this insurance policy!",
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
        //  overlayColor: Colors.black.withOpacity(.8)
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
            } else {
              await _deletePolicyRecord(id, reason.text);
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

  Future<void> _deletePolicyRecord(String id, String reason) async {
    try {
      setState(() {
        _isLoading = true;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString('adminId');


      final response = await http
          .delete(
            Uri.parse('${Api_url}/api/property-insurance/$id'),
            headers: {
              'Content-Type': 'application/json',
              'authorization': 'CRM $token',
              'id': 'CRM ${prefs.getString("staff_id") ?? adminId}',
            },
            body: json.encode({
              'reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 30));


      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _policies
                .removeWhere((policy) => policy.id != null && policy.id == id);
            _filteredPolicies
                .removeWhere((policy) => policy.id != null && policy.id == id);
          });

          Fluttertoast.showToast(
            msg: "Insurance policy deleted successfully",
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        } else {
          Fluttertoast.showToast(
            msg: data['message'] ?? 'Failed to delete insurance policy',
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: 'Failed to delete insurance policy',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      logError('Error deleting insurance policy: $e');
      Fluttertoast.showToast(
        msg: 'Error deleting insurance policy: ${friendlyErrorMessage(e)}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _editPolicy(PropertyInsuranceData policy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditInsurancePolicy(
          propertyId: widget.propertyId,
          policyId: policy.id,
          policyData: policy,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadInsurancePolicies();
      }
    });
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';
    final numValue = amount is String ? double.tryParse(amount) ?? 0 : amount;
    return formatMoney(numValue);
  }

  String _formatDate(String? dateValue) {
    if (dateValue == null || dateValue.trim().isEmpty || dateValue == 'null') {
      return 'N/A';
    }

    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    try {
      String formattedDate = dateProvider.formatCurrentDate(dateValue);

      // If the formatted date is the same as the original (meaning parsing failed),
      // try to parse it as ISO 8601 format manually
      if (formattedDate == dateValue && dateValue.contains('T')) {
        try {
          // Extract just the date part from ISO 8601 format (before 'T')
          String dateOnly = dateValue.split('T')[0];
          DateTime parsedDate = DateTime.parse(dateOnly);
          return DateFormat(dateProvider.dateFormat).format(parsedDate);
        } catch (e) {
          return 'N/A';
        }
      }

      return formattedDate;
    } catch (e) {
      return 'N/A';
    }
  }

  String _getStatusBadge(PropertyInsuranceData policy) {
    // If no expiration date, return "Active"
    if (policy.expirationDate == null || policy.expirationDate!.isEmpty) {
      return 'Active';
    }

    try {
      // Parse expiration date - handle ISO 8601 format
      String dateString = policy.expirationDate!;
      if (dateString.contains('T')) {
        dateString = dateString.split('T')[0];
      }
      final parsedExpirationDate = DateTime.parse(dateString);

      // Normalize both dates to start of day (like moment().startOf('day'))
      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final expirationDate = DateTime(parsedExpirationDate.year,
          parsedExpirationDate.month, parsedExpirationDate.day);

      // Calculate difference in days (like exp.diff(today, 'days'))
      final diffDays = expirationDate.difference(today).inDays;

      // If difference is 0 or less → "Expired"
      if (diffDays <= 0) {
        return 'Expired';
      }
      // If difference is 14 days or less → "Expiring Soon"
      if (diffDays <= 14) {
        return 'Expiring Soon';
      }
      // Otherwise → "Active"
      return 'Active';
    } catch (e) {
      // If date parsing fails, return "Active"
      logError('Error parsing expiration date: $e');
      return 'Active';
    }
  }

  Color _getStatusColor(PropertyInsuranceData policy) {
    final status = _getStatusBadge(policy);
    if (status.toLowerCase() == 'expired') {
      return Colors.red;
    }
    if (status.toLowerCase() == 'expiring soon') {
      return Colors.orange;
    }
    if (status.toLowerCase() == 'active') {
      return Colors.green;
    }
    return Colors.orange;
  }

  Widget _buildHeaders() {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 20,
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    "Insurance\nCompany",
                    style: TextStyle(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  margin: EdgeInsets.only(left: 20, right: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "  Status",
                    textAlign: TextAlign.start,
                    style: TextStyle(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
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

  Widget _buildContent() {
    final totalPages = (_filteredPolicies.length / itemsPerPage).ceil();
    final List<PropertyInsuranceData> currentPageData = _filteredPolicies
        .skip(currentPage * itemsPerPage)
        .take(itemsPerPage)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          // Header Section with Title and Add Button
          if (widget.showAddButton)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                children: [
                  Text(
                    "Insurance Policies",
                    style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: _openAddPolicyForm,
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
                            fontSize: MediaQuery.of(context).size.width < 500
                                ? 16
                                : 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // Content Section
          _isLoading
              ? SizedBox(
                  height: 200,
                  child: Center(
                    child: SpinKitFadingCircle(
                      color: Colors.black,
                      size: 45,
                    ),
                  ),
                )
              : _filteredPolicies.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                            'No insurance records available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: _buildHeaders(),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Container(
                            child: Column(
                              children:
                                  currentPageData.asMap().entries.map((entry) {
                                int index = entry.key;
                                bool isExpanded = expandedIndex == index;
                                PropertyInsuranceData policy = entry.value;

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
                                                  margin: const EdgeInsets.only(
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
                                                    color:
                                                        const Color(0xFF1E3A8A),
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
                                                          expandedIndex = null;
                                                        } else {
                                                          expandedIndex = index;
                                                        }
                                                      });
                                                    },
                                                    child: Text(
                                                      policy.insuranceCompanyName ??
                                                          'N/A',
                                                      style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 4,
                                                child: Container(
                                                  margin: EdgeInsets.only(
                                                      left: 20, right: 20),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: _getStatusColor(
                                                              policy)
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: _getStatusColor(
                                                            policy),
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      _getStatusBadge(policy),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        color: _getStatusColor(
                                                            policy),
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
                                      if (isExpanded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 2.0),
                                          margin:
                                              const EdgeInsets.only(bottom: 2),
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
                                                          'Policy Number:',
                                                          policy.policyNumber ??
                                                              'N/A',
                                                          'Effective Date:',
                                                          _formatDate(policy
                                                              .effectiveDate),
                                                        ),
                                                        _buildTableRow(
                                                          'Expiration Date:',
                                                          _formatDate(policy
                                                              .expirationDate),
                                                          'Premium Amount:',
                                                          _formatCurrency(policy
                                                              .premiumAmount),
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
                                                        _editPolicy(policy),
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
                                                    onTap: () {
                                                      if (policy.id != null) {
                                                        _deletePolicy(
                                                            policy.id!);
                                                      }
                                                    },
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
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Pagination Controls - Only show if data exceeds itemsPerPage
                        if (_filteredPolicies.length > itemsPerPage)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
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
                                            onChanged: _filteredPolicies
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
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: Icon(Icons.chevron_left,
                                          color: currentPage == 0
                                              ? Colors.grey
                                              : blueColor),
                                      onPressed: currentPage == 0
                                          ? null
                                          : () {
                                              setState(() {
                                                currentPage--;
                                              });
                                            },
                                    ),
                                    Text(
                                      'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.chevron_right,
                                          color: currentPage >= totalPages - 1
                                              ? Colors.grey
                                              : blueColor),
                                      onPressed: currentPage >= totalPages - 1
                                          ? null
                                          : () {
                                              setState(() {
                                                currentPage++;
                                              });
                                            },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
        ],
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
    return _buildContent();
  }
}
