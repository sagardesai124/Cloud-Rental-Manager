import 'package:three_zero_two_property/services/app_log.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/Model/All_categories_model.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/applience/Add_applience.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';

import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import '../../../../Model/unit.dart';
import '../../../../constant/constant.dart';
import '../../../../model/properties.dart';
import '../../../../model/unitsummery_propeties.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../repository/appliance_details_service.dart';
import '../summery_page.dart';
import 'AddMaintenanceHistoryDialog.dart';
import 'AddNoteDialog.dart';
import 'package:three_zero_two_property/screens/Maintenance/Workorder/workorder_summery.dart'
    as wo;

class ApplianceSummary extends StatefulWidget {
  final unit_appliance appliance;
  final unit_properties? unit;
  final Rentals? properties;

  ApplianceSummary({
    required this.appliance,
    this.unit,
    this.properties,
  });

  @override
  _ApplianceSummaryState createState() => _ApplianceSummaryState();
}

class _ApplianceSummaryState extends State<ApplianceSummary>
    with NetworkRetryState {
  Map<String, bool> _expandedItems = {};
  bool _isRefreshing = false;
  bool _isLoading = true;
  unit_appliance? _liveAppliance;
  ApplianceDetailsService _applianceService = ApplianceDetailsService();

  String formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return dateString;
    }
  }

  void _toggleExpanded(String key) {
    setState(() {
      _expandedItems[key] = !(_expandedItems[key] ?? false);
    });
  }

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _loadApplianceData();
    });
  }

  @override
  void initState() {
    super.initState();
    _loadApplianceData();
  }

  Future<void> _loadApplianceData() async {
    if (widget.appliance.applianceId != null) {
      try {
        setState(() {
          _isLoading = true;
        });
        final appliance = await _applianceService.fetchApplianceDetails(
          widget.appliance.applianceId!,
        );

        setState(() {
          _liveAppliance = appliance;
          _isLoading = false;
        });
      } catch (e) {
        logError('Error loading appliance data: $e');
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _refreshApplianceData() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      final appliance = await _applianceService.refreshApplianceDetails(
        widget.appliance.applianceId!,
      );

      setState(() {
        _liveAppliance = appliance;
        _isRefreshing = false;
      });
    } catch (e) {
      logError('Error refreshing appliance data: $e');
      setState(() {
        _isRefreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing data: ${friendlyErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddDialog(String sectionTitle) {
    final appliance = _liveAppliance ?? widget.appliance;

    if (sectionTitle == 'Maintenance History') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AddMaintenanceHistoryDialog(
            applianceId: appliance.applianceId ?? '',
          );
        },
      ).then((result) {
        if (result == true) {
          // Refresh the data
          _refreshApplianceData();
        }
      });
    } else if (sectionTitle == 'Maintenance Notes') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AddNoteDialog(
            applianceId: appliance.applianceId ?? '',
            onNoteAdded: _refreshApplianceData,
          );
        },
      ).then((result) {
        if (result == true) {
          // The callback will handle the refresh
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    // Use live data if available, otherwise fall back to widget data
    final appliance = _liveAppliance ?? widget.appliance;
    // print(appliance.categoryName);

    if (_isLoading) {
      return Scaffold(
        appBar: widget_302.App_Bar(context: context),
        backgroundColor: Colors.white,
        drawer: CustomDrawer(
          currentpage: "Properties",
          dropdown: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CircularProgressIndicator(
              //   valueColor: AlwaysStoppedAnimation<Color>(blueColor),
              // ),
              SpinKitFadingCircle(
                color: Colors.black,
                size: 40.0,
              ),
              SizedBox(height: 16),
              Text(
                'Loading appliance details...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Properties",
        dropdown: true,
      ),
      // This screen had no offline state at all; a failed request used to
      // leave it blank or showing an error string with no way to retry.
      body: isOffline
          ? NoInternetView(onRetry: retryNow)
          : SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar

            // Appliance Header
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliance.applianceName ?? 'N/A',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.appliance.categoryName ?? 'N/A',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (widget.properties != null) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Summery_page(
                              properties: widget.properties!,
                              unit: widget.unit,
                            ),
                          ),
                        );
                      } else {
                        Navigator.pop(context, true);
                      }
                    }, // Pass true back to refresh parent page
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isRefreshing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // CircularProgressIndicator(
                          //   valueColor:
                          //       AlwaysStoppedAnimation<Color>(blueColor),
                          // ),
                          SpinKitFadingCircle(
                            color: Colors.black,
                            size: 40.0,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Refreshing data...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Appliance Details Card
                          _buildDetailCard(
                            'Appliance Details',
                            [
                              // Values are resolved with _detailValue(): the
                              // detail response wins, but each field falls back
                              // to the row we were opened with. The detail
                              // endpoint omits some fields the list carries
                              // (e.g. category_name), so a per-field fallback
                              // keeps every row populated.
                              _buildDetailRowPair(
                                  'Name',
                                  _detailValue((a) => a.applianceName),
                                  'Category',
                                  _detailValue((a) => a.categoryName)),
                              _buildDetailRowPair(
                                  'Type',
                                  _resolveType(),
                                  'Status',
                                  _detailValue((a) => a.status),
                                  valueColor2: _getStatusColor(
                                      _detailValue((a) => a.status))),
                              _buildDetailRowPair(
                                  'Model',
                                  _detailValue((a) => a.model),
                                  'Brand',
                                  _detailValue((a) => a.brand)),
                              _buildDetailRowPair(
                                  'Description',
                                  _detailValue((a) => a.applianceDescription),
                                  'Serial Number',
                                  _detailValue((a) => a.serialNumber)),
                              _buildDetailRowPair(
                                  'Installed Date',
                                  appliance.installedDate != null
                                      ? dateProvider.formatCurrentDate(
                                          '${formatDate(appliance.installedDate!)}')
                                      : '',
                                  'Warranty Expiry',
                                  appliance.warrantyExpiry != null
                                      ? dateProvider.formatCurrentDate(
                                          '${formatDate(appliance.warrantyExpiry!)}')
                                      : ''),
                              if (appliance.lastMaintenanceDate != null &&
                                  appliance.lastMaintenanceDate!.isNotEmpty)
                                _buildDetailRowPair(
                                    'Last Maintenance',
                                    dateProvider.formatCurrentDate(
                                        '${formatDate(appliance.lastMaintenanceDate!)}'),
                                    '',
                                    ''),
                            ],
                            showEdit: true,
                          ),
                          SizedBox(height: 16),
                          if (appliance.filters != null &&
                              appliance.filters!.isNotEmpty)
                            // Filters Card
                            _buildDetailCard(
                              'Filters',
                              appliance.filters != null &&
                                      appliance.filters!.isNotEmpty
                                  ? appliance.filters!
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                      int index = entry.key;
                                      dynamic filter = entry.value;
                                      return _buildDetailRowPair(
                                        'Filter Name',
                                        filter['filter_name'] ?? '',
                                        'Filter Size',
                                        filter['filter_size'] ?? '',
                                      );
                                    }).toList()
                                  : [
                                      _buildDetailRowPair('Filter Name',
                                          'No filters', 'Filter Size', ''),
                                    ],
                            ),
                          SizedBox(height: 16),
                          // if(widget.appliance.maintenanceHistory != null && widget.appliance.maintenanceHistory!.isNotEmpty)
                          // Maintenance History Card
                          _buildDetailCard(
                            'Maintenance History',
                            appliance.maintenanceHistory != null &&
                                    appliance.maintenanceHistory!.isNotEmpty
                                ? appliance.maintenanceHistory!
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                    int index = entry.key;
                                    dynamic history = entry.value;
                                    return _buildMaintenanceItem(
                                      formatDate(history['timestamp'] ?? ''),
                                      history['event'] ?? 'Maintenance',
                                      'Vendor: ${history['vendor'] ?? ''}',
                                      // Like web, the entry links to its
                                      // work order through `workorder_id`.
                                      (history['workorder_id'] ?? '')
                                          .toString(),
                                      'history_$index',
                                    );
                                  }).toList()
                                : [
                                    _buildNoDataMessage(
                                        'No maintenance history available'),
                                  ],
                            showAdd: true,
                            showSearch: true,
                          ),
                          SizedBox(height: 16),

                          // Maintenance Notes Card
                          // _buildDetailCard(
                          //   'Maintenance Notes',
                          //   appliance.notes != null && appliance.notes!.isNotEmpty
                          //       ? appliance.notes!.asMap().entries.map((entry) {
                          //
                          //           int index = entry.key;
                          //           dynamic note = entry.value;
                          //           return _buildNoteItem(
                          //             formatDate(note['timestamp'] ?? ''),
                          //             note['user_name'] ?? '',
                          //             note['note'] ?? '',
                          //             'note_$index',
                          //             note['_id'] ?? '',
                          //           );
                          //         }).toList()
                          //       : appliance.maintenanceNotes != null && appliance.maintenanceNotes!.isNotEmpty
                          //           ? [
                          //               _buildNoteItem('Current', 'System', appliance.maintenanceNotes!, 'current_note',''),
                          //             ]
                          //           : [
                          //               _buildNoDataMessage('No maintenance notes available'),
                          //             ],
                          //   showAdd: true,
                          //   showSearch: true,
                          // ),
                          _buildDetailCard(
                            'Maintenance Notes',
                            appliance!.notes != null &&
                                    appliance!.notes!.isNotEmpty
                                ? appliance!.notes!
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                    int index = entry.key;
                                    dynamic note = entry.value;
                                    return _buildNoteItem(
                                      formatDate(note['timestamp'] ?? ''),
                                      note['user_name'] ?? '',
                                      note['note'] ?? '',
                                      'note_$index',
                                      note['_id'] ?? '',
                                    );
                                  }).toList()
                                : [
                                    _buildNoDataMessage(
                                        'No maintenance notes available'),
                                  ],
                            showAdd: true,
                            showSearch: true,
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children,
      {bool showEdit = false, bool showAdd = false, bool showSearch = false}) {
    final dateProvider = Provider.of<DateProvider>(context);
    final appliance = _liveAppliance ?? widget.appliance;

    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Row(
                  children: [
                    if (showAdd)
                      Container(
                        margin: EdgeInsets.only(right: 8),
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: IconButton(
                            icon:
                                Icon(Icons.add, color: Colors.green, size: 20),
                            onPressed: () {
                              _showAddDialog(title);
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ),
                      ),
                    if (showEdit)
                      GestureDetector(
                        onTap: () {
                          // Navigator.push(
                          //     context,
                          //     MaterialPageRoute(
                          //         builder: (context) =>
                          //             AddApplience(appliance: appliance)));
                          //Edit functionality

                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddApplience(
                                  unit: widget.unit,
                                  properties: widget.properties,
                                  appliance: appliance,
                                ),
                              )).then((value) {
                            if (value == true) {
                              // Refresh the data when returning from edit screen
                              _refreshApplianceData();
                            }
                          });
                        },
                        child: Text(
                          'Edit',
                          style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves a display value for the Appliance Details card.
  ///
  /// Prefers the freshly fetched detail record, then falls back to the
  /// appliance row this screen was opened with. The two payloads are not
  /// identical — GET appliance_details returns the raw document (no
  /// `category_name`), while the unit appliance LIST adds it — so reading a
  /// single source blanked out whichever fields that source happens to omit.
  String _detailValue(String? Function(unit_appliance a) get) =>
      _rawDetail(get) ?? '-';

  /// Same resolution as [_detailValue] but returns null instead of a placeholder
  /// so callers can branch on "no value at all".
  String? _rawDetail(String? Function(unit_appliance a) get) {
    final fromDetail = (_liveAppliance == null ? null : get(_liveAppliance!));
    if ((fromDetail ?? '').trim().isNotEmpty) return fromDetail!.trim();
    final fromList = get(widget.appliance);
    if ((fromList ?? '').trim().isNotEmpty) return fromList!.trim();
    return null;
  }

  /// Categories that count as a Major System rather than an Appliance — same
  /// list the Add/Edit form and the Home System Report use.
  static const List<String> _majorSystemCategories = [
    'Roof',
    'Electrical',
    'Plumbing',
    'Exterior',
    'Water Heater',
    'HVAC',
  ];

  /// Resolves the "Type" shown on this card.
  ///
  /// Web parity (HomeSystemDetails.js): Type is 'Major System' or 'Appliance',
  /// derived from the appliance's category — it is NOT the legacy free-text
  /// `type` column. The Add/Edit form dropdown writes `system_type`, while the
  /// old `type` field is no longer bound to any input and therefore comes back
  /// empty for anything created through the current form, which is why this row
  /// used to render "-". Prefer the stored system_type, then derive from the
  /// category, and only then fall back to the legacy value.
  String _resolveType() {
    final stored = _rawDetail((a) => a.systemType);
    if (stored != null) {
      return stored.toLowerCase().contains('major')
          ? 'Major System'
          : 'Appliance';
    }
    final category = _rawDetail((a) => a.categoryName);
    if (category != null) {
      return _majorSystemCategories
              .any((m) => m.toLowerCase() == category.toLowerCase())
          ? 'Major System'
          : 'Appliance';
    }
    return _rawDetail((a) => a.type) ?? '-';
  }

  Widget _buildDetailRowPair(
      String label1, String value1, String label2, String value2,
      {Color? valueColor1, Color? valueColor2}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Labels row
          Row(
            children: [
              Expanded(
                child: Text(
                  label1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  label2,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          // Values row
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatValue(value1),
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor1 ?? Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatValue(value2),
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor2 ?? Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(String value) {
    if (value == null ||
        value.isEmpty ||
        value.trim() == '' ||
        value == 'N/A') {
      return '-'; // Using a dash instead of "Not specified" for a cleaner look
    }
    return value;
  }

  Widget _buildNoDataMessage(String message) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey.shade600,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceItem(String date, String eventType, String vendor,
      String workOrderId, String key) {
    bool isExpanded = _expandedItems[key] ?? false;
    final dateProvider = Provider.of<DateProvider>(context);
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: () => _toggleExpanded(key),
            child: Container(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    dateProvider.formatCurrentDate('${date}'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: eventType == 'Install'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      eventType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: eventType == 'Install'
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded)
            Container(
              padding: EdgeInsets.only(left: 38, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Labels row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Vendor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Work Order',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Values row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatValue(vendor.replaceAll('Vendor: ', '')),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        // Like web: a linked entry opens its work order, the
                        // rest say "No WO".
                        child: workOrderId.isEmpty
                            ? Text(
                                'No WO',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => wo.Workorder_summery(
                                        workorder_id: workOrderId),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.open_in_new,
                                        size: 16, color: blueColor),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'View Work Order',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: blueColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
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
  }

  Widget _buildNoteItem(
      String date, String addedBy, String note, String key, String noteId) {
    bool isExpanded = _expandedItems[key] ?? false;
    final dateProvider = Provider.of<DateProvider>(context);
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: () => _toggleExpanded(key),
            child: Container(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    dateProvider.formatCurrentDate('${date}'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Spacer(),
                  Row(
                    children: [
                      SizedBox(width: 8),
                      // Edit Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.green.withOpacity(0.3), width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AddNoteDialog(
                                  applianceId:
                                      widget.appliance.applianceId ?? '',
                                  noteId: noteId,
                                  initialText: note,
                                  onNoteAdded: _refreshApplianceData,
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.edit_outlined,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Delete Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.red.withOpacity(0.3), width: 1),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Confirm Delete',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      'Are you sure you want to delete this maintenance note? This action cannot be undone.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: Text(
                                          'Cancel',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirmed == true) {
                                await _applianceService.deleteNote(
                                  noteId,
                                  widget.appliance.applianceId ?? '',
                                );
                                _refreshApplianceData();
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 16,
                              ),
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
          // Expanded content
          if (isExpanded)
            Container(
              padding: EdgeInsets.only(left: 38, right: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Labels row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Added By',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Note',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Values row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatValue(addedBy),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatValue(note),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
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
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'working':
        return Colors.green;
      case 'needs repair':
        return Colors.orange;
      case 'out of service':
        return Colors.red;
      default:
        return Colors.grey.shade800;
    }
  }
}
