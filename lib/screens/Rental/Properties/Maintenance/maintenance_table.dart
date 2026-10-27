import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/widgets/appbar.dart' as admin_bar;
import 'package:three_zero_two_property/widgets/custom_drawer.dart' as admin_drawer;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart' as staff_bar;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    as staff_drawer;

import 'Add_Edit_maintenance.dart';

/// Property maintenance-by-year list with expandable rows (year / amount;
/// expand for edit & delete). Used on the summary page and as a standalone route.
class MaintenanceTable extends StatefulWidget {
  const MaintenanceTable({
    super.key,
    required this.propertyId,
    this.useStaffModule = false,
    this.showAppBar = false,
    this.showDrawer = false,
    this.showAddButton = true,
    this.showOuterSectionTitle = true,
  });

  final String propertyId;
  final bool useStaffModule;
  final bool showAppBar;
  final bool showDrawer;
  final bool showAddButton;
  /// When false (e.g. under Annual Expenses), hides the top "Maintenance" title.
  final bool showOuterSectionTitle;

  @override
  State<MaintenanceTable> createState() => _MaintenanceTableState();
}

class _MaintenanceTableState extends State<MaintenanceTable>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  int? _expandedIndex;
  int _loadGeneration = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: true);
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final id = widget.useStaffModule
        ? (prefs.getString('staff_id') ?? '')
        : (prefs.getString('adminId') ?? '');
    return {
      'Content-Type': 'application/json',
      'authorization': 'CRM $token',
      'id': 'CRM $id',
    };
  }

  /// [showSpinner] false after add/edit/delete updates rows without the full
  /// loading placeholder (lighter refresh for this section only).
  Future<void> _load({bool showSpinner = true}) async {
    if (widget.propertyId.isEmpty) return;
    final gen = ++_loadGeneration;
    if (showSpinner && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final headers = await _headers();
      final response = await http
          .get(
            Uri.parse(
                '${Api_url}/api/rentals/maintenance/${widget.propertyId}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted || gen != _loadGeneration) return;

      List<Map<String, dynamic>> next = [];
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data']['maintenance'] != null) {
          next = List<Map<String, dynamic>>.from(data['data']['maintenance']);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load maintenance (${response.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _items = next;
        _isLoading = false;
        if (_expandedIndex != null && _expandedIndex! >= next.length) {
          _expandedIndex = null;
        }
      });
    } catch (e) {
      if (!mounted || gen != _loadGeneration) return;
      setState(() {
        _items = [];
        _isLoading = false;
        _expandedIndex = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading maintenance: ${friendlyErrorMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _delete(String entryId) async {
    try {
      final headers = await _headers();
      final response = await http
          .delete(
            Uri.parse(
                '${Api_url}/api/rentals/maintenance/${widget.propertyId}/$entryId'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maintenance entry deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _load(showSpinner: false);
      } else {
        if (mounted) {
          String msg = 'Delete failed';
          try {
            msg = json.decode(response.body)['message']?.toString() ?? msg;
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(Map<String, dynamic> row) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.priority_high, color: Colors.orange.shade800, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: blueColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This maintenance entry will be removed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _delete(row['_id']?.toString() ?? '');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      side: BorderSide(color: Colors.red.shade200),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: blueColor,
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '\$0.00';
    final n = amount is num ? amount.toDouble() : double.tryParse(amount.toString()) ?? 0;
    return formatMoney(n);
  }

  Future<void> _openAdd() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => Add_Edit_maintenance(
          propertyId: widget.propertyId,
          useStaffModule: widget.useStaffModule,
        ),
      ),
    );
    if (ok == true) _load(showSpinner: false);
  }

  Future<void> _openEdit(Map<String, dynamic> row) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => Add_Edit_maintenance(
          propertyId: widget.propertyId,
          useStaffModule: widget.useStaffModule,
          entryId: row['_id']?.toString(),
          maintenanceData: row,
        ),
      ),
    );
    if (ok == true) _load(showSpinner: false);
  }

  /// Same layout pattern as [Insurance_premium_Table._buildHeaders].
  Widget _buildHeaders() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 8,
        title: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(width: 20),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    'Year',
                    style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.only(left: 24, right: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showOuterSectionTitle) ...[
          Text(
            'Maintenance',
            style: TextStyle(
              color: blueColor,
              fontWeight: FontWeight.bold,
              fontSize: MediaQuery.of(context).size.width < 500 ? 17 : 20,
            ),
          ),
          Divider(color: Colors.grey.shade300, thickness: 1),
          const SizedBox(height: 8),
        ],
        Padding(padding: const EdgeInsets.only(left: 13,right: 13,top: 10,bottom: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(left: 15,right: 15,top: 12,bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDBE0E5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showAddButton)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14,),
                  child: Row(
                    children: [
                      Text(
                        'Maintenance by Year',
                        style: TextStyle(
                          color: blueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: blueColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '+ Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoading)
                const SizedBox(
                  height: 180,
                  child: Center(
                    child: SpinKitFadingCircle(color: Colors.black, size: 40),
                  ),
                )
              else if (_items.isEmpty)
                SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'No maintenance entries yet.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                    ),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildHeaders(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: _items.asMap().entries.map((e) {
                      final index = e.key;
                      final row = e.value;
                      final expanded = _expandedIndex == index;
                      final year = row['year']?.toString() ?? '-';
                      final amt = _formatAmount(row['amount']);

                      void toggleExpand() {
                        setState(() {
                          _expandedIndex = expanded ? null : index;
                        });
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: index % 2 != 0
                              ? const Color(0xFFF4F8FF)
                              : Colors.white,
                          border: Border.all(color: const Color(0xFFDBE0E5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: <Widget>[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              minVerticalPadding: 8,
                              title: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    InkWell(
                                      onTap: toggleExpand,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            left: 5, right: 5),
                                        padding: expanded
                                            ? const EdgeInsets.only(top: 10)
                                            : const EdgeInsets.only(
                                                bottom: 10),
                                        child: FaIcon(
                                          expanded
                                              ? FontAwesomeIcons.sortUp
                                              : FontAwesomeIcons.sortDown,
                                          size: 20,
                                          color: const Color(0xFF1E3A8A),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(left: 8.0),
                                        child: InkWell(
                                          onTap: toggleExpand,
                                          child: Text(
                                            year,
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: InkWell(
                                        onTap: toggleExpand,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              left: 24, right: 5),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 6),
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            amt,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (expanded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 2.0),
                                margin: const EdgeInsets.only(bottom: 2),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        FaIcon(
                                          expanded
                                              ? FontAwesomeIcons.sortUp
                                              : FontAwesomeIcons.sortDown,
                                          size: 40,
                                          color: Colors.transparent,
                                        ),
                                        const Spacer(),
                                      ],
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                         GestureDetector(
                                          onTap: () => _openEdit(row),
                                          child: Container(
                                            height: 35,
                                            width: 35,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: Colors.green.shade50,
                                            ),
                                            child: const Center(
                                              child: FaIcon(
                                                FontAwesomeIcons.edit,
                                                size: 15,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ),
                                       SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () => _confirmDelete(row),
                                          child: Container(
                                            height: 35,
                                            width: 35,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              color: Colors.red.shade50,
                                            ),
                                            child: const Center(
                                              child: FaIcon(
                                                FontAwesomeIcons.trashCan,
                                                size: 15,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 10),
                                      ]
                                      ,
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
              ],
            ],
          ),
        ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _sectionContent(),
      ),
    );

    if (widget.showAppBar) {
      if (widget.useStaffModule) {
        return Scaffold(
          appBar: staff_bar.widget_302_Staff.App_Bar(context: context),
          backgroundColor: Colors.white,
          drawer: widget.showDrawer
              ? staff_drawer.CustomDrawerStaff(
                  currentpage: 'Properties',
                  dropdown: true,
                )
              : null,
          body: content,
        );
      }
      return Scaffold(
        appBar: admin_bar.widget_302.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: widget.showDrawer
            ? admin_drawer.CustomDrawer(
                currentpage: 'Properties',
                dropdown: true,
              )
            : null,
        body: content,
      );
    }

    return content;
  }
}
