import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../provider/dateProvider.dart';
import '../../../../widgets/custom_drawer.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';
import 'AddEditAdditionalStat.dart';

class Additional_Stats_table extends StatefulWidget {
  const Additional_Stats_table({
    Key? key,
    required this.propertyId,
    this.showAppBar = false,
    this.showDrawer = false,
    this.showAddButton = true,
  }) : super(key: key);

  final String propertyId;
  final bool showAppBar;
  final bool showDrawer;
  final bool showAddButton;

  @override
  State<Additional_Stats_table> createState() => _Additional_Stats_tableState();
}

class _Additional_Stats_tableState extends State<Additional_Stats_table> {
  List<Map<String, dynamic>> _stats = [];
  List<Map<String, dynamic>> _filteredStats = [];
  bool _isLoading = false;
  int? expandedIndex;
  int currentPage = 0;
  int itemsPerPage = 10;
  List<int> itemsPerPageOptions = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? staffId = prefs.getString("staff_id");

      final response = await apiGet(
        Uri.parse(
            '${Api_url}/api/rentals/additional-stats/${widget.propertyId}'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM $staffId',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data']['additional_stats'] != null) {
          setState(() {
            _stats = List<Map<String, dynamic>>.from(
                data['data']['additional_stats']);
            _filteredStats = List.from(_stats);
          });
        } else {
          setState(() {
            _stats = [];
            _filteredStats = [];
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to load additional stats: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading additional stats: ${friendlyErrorMessage(e)}'),
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

  Future<void> _deleteStat(String statId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? staffId = prefs.getString("staff_id");

      final response = await apiDelete(
        Uri.parse(
            '${Api_url}/api/rentals/additional-stats/${widget.propertyId}/$statId'),
        headers: {
          'Content-Type': 'application/json',
          'authorization': 'CRM $token',
          'id': 'CRM $staffId',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Additional stat deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadStats(); // Reload the list
      } else {
        if (mounted) {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['message'] ?? 'Failed to delete additional stat';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting additional stat: ${friendlyErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteAlert(BuildContext context, String id) {
    // One tap = one delete; the button stays live until the dialog closes.
    var deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc:
          "Once deleted, you will not be able to recover this additional stat!",
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
            if (deleting) return;
            deleting = true;
            await _deleteStat(id);
            if (mounted) Navigator.pop(context);
          },
          color: blueColor,
        ),
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
              color: blueColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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

  void _handleEdit(Map<String, dynamic> stat) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAdditionalStat(
          propertyId: widget.propertyId,
          statId: stat['_id'],
          statData: stat,
        ),
      ),
    );

    // Reload stats if edit was successful
    if (result == true) {
      _loadStats();
    }
  }

  void _handleAdd() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditAdditionalStat(
          propertyId: widget.propertyId,
        ),
      ),
    );

    // Reload stats if add was successful
    if (result == true) {
      _loadStats();
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';
    final numValue = amount is String ? double.tryParse(amount) ?? 0 : amount;
    return formatMoney(numValue);
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
                width: 20, // Space for icon
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    "Year",
                    style: TextStyle(
                        color: const Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  margin: EdgeInsets.only(left: 50, right: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text(
                    "Date",
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
            padding: const EdgeInsets.only(
                left: 28.0, top: 4.0, bottom: 4.0, right: 4.0),
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
    final totalPages = (_filteredStats.length / itemsPerPage).ceil();
    final currentPageData = _filteredStats
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
                    "Additional Stats",
                    style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: _handleAdd,
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
              : _filteredStats.isEmpty
                  ? SizedBox(
                      height: 200,
                      child: Center(
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
                              'No additional stats available.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 10),
                          ],
                        ),
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
                                Map<String, dynamic> stat = entry.value;

                                String year = stat['year']?.toString() ?? '-';
                                String date = '-';
                                if (stat['date'] != null &&
                                    stat['date'].toString().isNotEmpty) {
                                  try {
                                    final dateProvider =
                                        Provider.of<DateProvider>(context,
                                            listen: false);
                                    // Try to parse different date formats
                                    DateTime? parsedDate;
                                    String dateStr = stat['date'].toString();
                                    try {
                                      // Try M/d/yyyy format first (API format)
                                      parsedDate =
                                          DateFormat('M/d/yyyy').parse(dateStr);
                                    } catch (e) {
                                      try {
                                        // Try yyyy-MM-dd format
                                        parsedDate = DateFormat('yyyy-MM-dd')
                                            .parse(dateStr);
                                      } catch (e2) {
                                        // Try other formats
                                        parsedDate = DateTime.tryParse(dateStr);
                                      }
                                    }
                                    if (parsedDate != null) {
                                      String apiFormatDate =
                                          DateFormat('yyyy-MM-dd')
                                              .format(parsedDate);
                                      date = dateProvider
                                          .formatCurrentDate(apiFormatDate);
                                    } else {
                                      date = dateStr;
                                    }
                                  } catch (e) {
                                    date = stat['date']?.toString() ?? '-';
                                  }
                                }
                                String value = stat['formatted_value']
                                        ?.toString() ??
                                    (stat['stat_value'] != null
                                        ? _formatCurrency(stat['stat_value'])
                                        : '-');

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
                                                    child: Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: year,
                                                            style: TextStyle(
                                                              color: blueColor,
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
                                                flex: 4,
                                                child: Container(
                                                  margin: EdgeInsets.only(
                                                      left: 50, right: 20),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 6),
                                                  child: Text(
                                                    date,
                                                    textAlign: TextAlign.start,
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
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      0.02),
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
                                                            'Value:',
                                                            value,
                                                            '',
                                                            '',
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
                                                          _showDeleteAlert(
                                                              context,
                                                              stat['_id']),
                                                      child: Container(
                                                        height: 35,
                                                        width: 35,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
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
                                                              color: Colors.red,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _handleEdit(stat),
                                                      child: Container(
                                                        height: 35,
                                                        width: 35,
                                                        decoration:
                                                            BoxDecoration(
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
                                                              color:
                                                                  Colors.green,
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
                        ),
                        const SizedBox(height: 20),
                        // Pagination Controls - Only show if data exceeds 10
                        if (_filteredStats.length > 10)
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
                                            onChanged: _filteredStats.length >
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
    if (widget.showAppBar) {
      return Scaffold(
        appBar: widget_302_Staff.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: widget.showDrawer
            ? CustomDrawerStaff(
                currentpage: "Properties",
                dropdown: true,
              )
            : null,
        body: SingleChildScrollView(
          child: _buildContent(),
        ),
      );
    } else {
      return _buildContent();
    }
  }
}
