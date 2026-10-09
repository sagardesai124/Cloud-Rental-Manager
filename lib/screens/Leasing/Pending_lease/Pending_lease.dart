import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart'
    as staff_summary;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as staff_appbar;
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/SummeryPageLease.dart'
    as admin_summary;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:three_zero_two_property/widgets/appbar.dart' as admin_appbar;
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

/// Pending e-sign leases: matches web grouping using API [combined_document.signing_status].
///
/// **Unsigned** (same as backend `unsigned` filter):
/// - [combined_document] is null/absent, **or**
/// - [signing_status] is not exactly `"Signed"` (after normalizing: not `signed` case-insensitive).
///
/// **Signed**:
/// - [combined_document] exists **and** `signing_status` resolves to signed (tracking + doc fallback
///   is already applied on the server; the app only reads the returned object).
///
/// The server picks the “main” combined e-sign doc (non-deleted COMBINED_LEASE_DOCUMENT first, etc.)
/// and sets [combined_document.signing_status] from SignatureTracking or the document — the list
/// endpoint returns that shape; the Flutter UI does not re-run that query logic.
class Pending_lease extends StatefulWidget {
  /// When true: staff app bar, [CustomDrawerStaff], staff lease summary on view, and auth header
  /// `id: CRM <staff_id>` (fallback admin) like other staff lease APIs.
  final bool useStaffLayout;

  const Pending_lease({super.key, this.useStaffLayout = false});

  @override
  State<Pending_lease> createState() => _Pending_leaseState();
}

class _PendingLeaseRow {
  final String leaseId;
  final String propertyAddress;
  final String tenantNames;
  final String? startDate;
  final String? endDate;
  final String rentCycle;
  final num? amount;
  final Map<String, dynamic>? combinedDocument;

  _PendingLeaseRow({
    required this.leaseId,
    required this.propertyAddress,
    required this.tenantNames,
    this.startDate,
    this.endDate,
    required this.rentCycle,
    this.amount,
    this.combinedDocument,
  });

  static _PendingLeaseRow? fromJson(Map<String, dynamic> json) {
    final id = json['lease_id']?.toString();
    if (id == null || id.isEmpty) return null;
    Map<String, dynamic>? combined;
    final raw = json['combined_document'];
    if (raw is Map<String, dynamic>) combined = raw;

    return _PendingLeaseRow(
      leaseId: id,
      propertyAddress: json['property_address']?.toString() ?? '',
      tenantNames: json['tenantNames']?.toString() ?? 'N/A',
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      rentCycle: json['rent_cycle']?.toString() ?? 'N/A',
      amount: json['amount'] is num
          ? json['amount'] as num
          : num.tryParse(json['amount']?.toString() ?? ''),
      combinedDocument: combined,
    );
  }

  bool get isSigned {
    if (combinedDocument == null) return false;
    final s = combinedDocument!['signing_status']?.toString().trim() ?? '';
    return s.toLowerCase() == 'signed';
  }
}

class _Pending_leaseState extends State<Pending_lease>
    with NetworkRetryState {
  static const double _kFontSize = 14;

  /// Shared leading geometry so the list header and each row line up exactly.
  static const double _kLeadingIconWidth = 26;
  static const double _kRowLeftInset = 6;

  /// Left inset applied to every column's text (header, collapsed rows, and the
  /// expanded detail table) so both columns line up across all three. Matches
  /// the detail table's cell padding (4).
  static const double _kCellLeftPad = 4;

  List<_PendingLeaseRow> _raw = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  int _unsignedPage = 0;
  int _signedPage = 0;
  int _rowsPerPage = 10;

  /// At most one expanded row per section (matched by [lease_id]).
  String? _expandedUnsignedLeaseId;
  String? _expandedSignedLeaseId;

  static final NumberFormat _money =
      NumberFormat.currency(locale: 'en_US', symbol: r'$');

  TextStyle get _styleSectionTitle => TextStyle(
        fontSize: _kFontSize,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF152B53),
      );

  TextStyle get _styleLabel => TextStyle(
        fontSize: _kFontSize,
        fontWeight: FontWeight.bold,
        color: blueColor,
      );

  TextStyle get _styleValue => TextStyle(
        fontSize: _kFontSize,
        fontWeight: FontWeight.w600,
        color: grey,
      );

  TextStyle get _styleRowPrimary => TextStyle(
        fontSize: _kFontSize,
        fontWeight: FontWeight.bold,
        color: blueColor,
      );

  TextStyle get _styleRowAddress =>  TextStyle(
        fontSize: _kFontSize,
        fontWeight: FontWeight.w600,
        color: blueColor,
      );

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The one load initState makes; the search text and page numbers _load()
  /// resets are its own business, so a reload behaves exactly like reopening.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('adminId');
      final token = prefs.getString('token');
      final staffId = prefs.getString('staff_id');
      final headerUserId =
          widget.useStaffLayout ? (staffId ?? adminId) : adminId;

      if (adminId == null ||
          adminId.isEmpty ||
          token == null ||
          token.isEmpty) {
        setState(() {
          _raw = [];
          _loading = false;
          _error = 'Not signed in or missing account id.';
        });
        return;
      }

      final uri = Uri.parse('$Api_url/api/leases/pending-leases-list/$adminId');
      final response = await apiGet(
        uri,
        headers: {
          'authorization': 'CRM $token',
          'id': 'CRM ${headerUserId ?? adminId}',
        },
      );

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Unexpected response');
      }
      final code = decoded['statusCode'];
      if (code != 200 && code != 201) {
        throw Exception(decoded['message']?.toString() ?? 'Request failed');
      }
      final list = decoded['data'];
      final rows = <_PendingLeaseRow>[];
      if (list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final row = _PendingLeaseRow.fromJson(e);
            if (row != null) rows.add(row);
          }
        }
      }
      setState(() {
        _raw = rows;
        _loading = false;
        _unsignedPage = 0;
        _signedPage = 0;
        _expandedUnsignedLeaseId = null;
        _expandedSignedLeaseId = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<_PendingLeaseRow> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _raw;
    return _raw.where((r) {
      final amt = r.amount?.toString() ?? '';
      return r.propertyAddress.toLowerCase().contains(q) ||
          r.tenantNames.toLowerCase().contains(q) ||
          amt.contains(q);
    }).toList();
  }

  List<_PendingLeaseRow> get _unsignedLeases =>
      _filtered.where((r) => !r.isSigned).toList();

  List<_PendingLeaseRow> get _signedLeases =>
      _filtered.where((r) => r.isSigned).toList();

  String _formatDate(String? raw, DateProvider dateProvider) {
    if (raw == null || raw.trim().isEmpty || raw == 'null') return 'N/A';
    try {
      final parsed = DateTime.parse(raw);
      return DateFormat('MM/dd/yyyy').format(parsed);
    } catch (_) {
      final via = dateProvider.formatCurrentDate(raw);
      if (via.toLowerCase().contains('invalid')) return 'N/A';
      return via;
    }
  }

  void _viewLease(String leaseId) {
    if (widget.useStaffLayout) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              staff_summary.SummeryPageLease(leaseId: leaseId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              admin_summary.SummeryPageLease(leaseId: leaseId),
        ),
      );
    }
  }

  Widget _circlePageButton({
    required bool enabled,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: enabled ? blueColor : const Color(0xFFBDBDBD),
      shape: const CircleBorder(),
      elevation: enabled ? 1 : 0,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 25,
          height: 25,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _paginationBar({
    required int total,
    required int pageIndex,
    required void Function(int) onPageChanged,
  }) {
    final pages = total == 0 ? 1 : (total / _rowsPerPage).ceil();
    final safePage = pageIndex.clamp(0, pages - 1);
    final canPrev = safePage > 0;
    final canNext = safePage < pages - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 16, right: 4, bottom: 12, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD0D5DD)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _rowsPerPage,
                isDense: true,
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                style: TextStyle(
                  fontSize: _kFontSize,
                  color: Colors.grey.shade800,
                ),
                items: [10, 25, 50, 100]
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child:
                            Text('$n', style: TextStyle(fontSize: _kFontSize)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _rowsPerPage = v;
                    _unsignedPage = 0;
                    _signedPage = 0;
                    _expandedUnsignedLeaseId = null;
                    _expandedSignedLeaseId = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 20),
          _circlePageButton(
            enabled: canPrev,
            icon: Icons.chevron_left,
            onPressed: () => onPageChanged(safePage - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Page ${safePage + 1} of $pages',
              style: TextStyle(
                fontSize: _kFontSize,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _circlePageButton(
            enabled: canNext,
            icon: Icons.chevron_right,
            onPressed: () => onPageChanged(safePage + 1),
          ),
        ],
      ),
    );
  }

  String _displayValue(String? value) =>
      (value == null || value.trim().isEmpty) ? 'N/A' : value;

  /// Same pattern as [lease_table._buildTableRow]: two label/value pairs per row.
  TableRow _pendingDetailTableRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leftLabel, style: _styleLabel),
                const SizedBox(height: 4),
                Text(leftValue, style: _styleValue),
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
                Text(rightLabel, style: _styleLabel),
                const SizedBox(height: 4),
                Text(rightValue, style: _styleValue),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingListHeaders() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      padding: const EdgeInsets.fromLTRB(_kRowLeftInset, 12, 2, 12),
      child: Row(
        children: [
          const SizedBox(width: _kLeadingIconWidth),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: _kCellLeftPad),
              child: Text('Sr No', style: _styleLabel),
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: _kCellLeftPad),
              child: Text('Address', style: _styleLabel),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty list: illustration-style icon + copy (headers stay visible above).
  Widget _buildNoDataPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            "assets/images/no_data.jpg",
            height: 200,
            width: 200,
          ),
          const SizedBox(
            height: 10,
          ),
          const SizedBox(height: 8),
          Text(
            'No Data Available',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: blueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpandPendingRow(String leaseId, bool forUnsignedSection) {
    setState(() {
      if (forUnsignedSection) {
        _expandedUnsignedLeaseId =
            _expandedUnsignedLeaseId == leaseId ? null : leaseId;
      } else {
        _expandedSignedLeaseId =
            _expandedSignedLeaseId == leaseId ? null : leaseId;
      }
    });
  }

  Widget _leaseTable({
    required List<_PendingLeaseRow> source,
    required int pageIndex,
    required void Function(int) onPageChanged,
    required DateProvider dateProvider,
    required bool forUnsignedSection,
    required String? expandedLeaseId,
  }) {
    final pages = source.isEmpty ? 1 : (source.length / _rowsPerPage).ceil();
    var effectivePage = pageIndex.clamp(0, pages - 1);
    if (effectivePage != pageIndex) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        onPageChanged(effectivePage);
      });
    }
    final start = effectivePage * _rowsPerPage;
    final pageItems = source.skip(start).take(_rowsPerPage).toList();

    void changePage(int p) {
      setState(() {
        if (forUnsignedSection) {
          _expandedUnsignedLeaseId = null;
        } else {
          _expandedSignedLeaseId = null;
        }
      });
      onPageChanged(p);
    }

    final listRows = source.isEmpty
        ? <Widget>[]
        : pageItems.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            final sr = start + i + 1;
            final isExpanded = expandedLeaseId == r.leaseId;
            final signingStatus = r.combinedDocument == null
                ? 'N/A'
                : _displayValue(
                    r.combinedDocument!['signing_status']?.toString(),
                  );

            return GestureDetector(
              onTap: () =>
                  _toggleExpandPendingRow(r.leaseId, forUnsignedSection),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: i % 2 != 0 ? const Color(0xFFF4F8FF) : Colors.white,
                  border: Border.all(color: const Color(0xFFDBE0E5)),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _kRowLeftInset,
                          2,
                          2,
                          2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: _kLeadingIconWidth,
                              child: InkWell(
                                onTap: () => _toggleExpandPendingRow(
                                  r.leaseId,
                                  forUnsignedSection,
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  padding: !isExpanded
                                      ? const EdgeInsets.only(bottom: 10)
                                      : const EdgeInsets.only(top: 10),
                                  child: FaIcon(
                                    isExpanded
                                        ? FontAwesomeIcons.sortUp
                                        : FontAwesomeIcons.sortDown,
                                    size: 18,
                                    color: blueColor,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: _kCellLeftPad,
                                ),
                                child: Text('$sr', style: _styleRowPrimary),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: InkWell(
                                onTap: () => _toggleExpandPendingRow(
                                  r.leaseId,
                                  forUnsignedSection,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: _kCellLeftPad,
                                    right: 8,
                                  ),
                                  child: Text(
                                    r.propertyAddress.isEmpty
                                        ? 'N/A'
                                        : r.propertyAddress,
                                    style: _styleRowAddress,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _kRowLeftInset,
                          0,
                          2,
                          8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: _kLeadingIconWidth),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Table(
                                    columnWidths: const {
                                      0: FlexColumnWidth(),
                                      1: FlexColumnWidth(),
                                    },
                                    children: [
                                      _pendingDetailTableRow(
                                        'Tenant Name:',
                                        _displayValue(r.tenantNames),
                                        'Lease Start:',
                                        _formatDate(
                                          r.startDate,
                                          dateProvider,
                                        ),
                                      ),
                                      _pendingDetailTableRow(
                                        'Lease End:',
                                        _formatDate(r.endDate, dateProvider),
                                        'Rent Cycle:',
                                        _displayValue(r.rentCycle),
                                      ),
                                      _pendingDetailTableRow(
                                        'Lease Amount:',
                                        r.amount != null
                                            ? _money.format(r.amount)
                                            : 'N/A',
                                        'Signing status:',
                                        signingStatus,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _viewLease(r.leaseId),
                                        child: Container(
                                          height: 35,
                                          width: 35,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              FaIcon(
                                                FontAwesomeIcons.eye,
                                                size: 15,
                                                color: Colors.black,
                                              ),
                                              SizedBox(width: 2),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        _buildPendingListHeaders(),
        const SizedBox(height: 8),
        if (source.isEmpty)
          _buildNoDataPlaceholder()
        else
          Column(children: listRows),
        if (source.isNotEmpty)
          _paginationBar(
            total: source.length,
            pageIndex: effectivePage,
            onPageChanged: changePage,
          ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData titleIcon,
    required Color iconColor,
    required List<_PendingLeaseRow> items,
    required int pageIndex,
    required void Function(int) onPageChanged,
    required DateProvider dateProvider,
    required bool forUnsignedSection,
    bool initiallyExpanded = false,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          controlAffinity: ListTileControlAffinity.trailing,
          iconColor: blueColor,
          collapsedIconColor: blueColor,
          leading: Icon(titleIcon, color: iconColor, size: 22),
          title: Text(
            '$title (${items.length})',
            style: _styleSectionTitle,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: _leaseTable(
                source: items,
                pageIndex: pageIndex,
                onPageChanged: onPageChanged,
                dateProvider: dateProvider,
                forUnsignedSection: forUnsignedSection,
                expandedLeaseId: forUnsignedSection
                    ? _expandedUnsignedLeaseId
                    : _expandedSignedLeaseId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context, listen: true);

    return Scaffold(
      appBar: widget.useStaffLayout
          ? staff_appbar.widget_302_Staff.App_Bar(context: context)
          : admin_appbar.widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: widget.useStaffLayout
          ? CustomDrawerStaff(
              currentpage: 'Pending Leases',
              dropdown: true,
            )
          : CustomDrawer(
              currentpage: 'Pending Leases',
              dropdown: true,
            ),
      // A network failure gets the app's standard offline state; anything else
      // keeps this screen's own message, run through friendlyErrorMessage so
      // the raw exception text is never shown to the user.
      body: _error != null && isNetworkError(_error)
          ? NoInternetView(onRetry: retryNow)
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      friendlyErrorMessage(_error),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: _kFontSize),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'Retry',
                        style: TextStyle(fontSize: _kFontSize),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          titleBar(
                            title: 'Pending Leases',
                            width: double.infinity,
                            size: _kFontSize,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Manage and track unsigned and signed leases.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: _kFontSize,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 45,
                            child: TextField(
                              controller: _searchController,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(fontSize: _kFontSize),
                              decoration: InputDecoration(
                                hintText: 'Search here...',
                                hintStyle: TextStyle(
                                  fontSize: _kFontSize,
                                  color: Colors.grey.shade600,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 0,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  size: 22,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              onChanged: (_) => setState(() {
                                _unsignedPage = 0;
                                _signedPage = 0;
                                _expandedUnsignedLeaseId = null;
                                _expandedSignedLeaseId = null;
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: SpinKitFadingCircle(
                          color: blueColor,
                          size: 40.0,
                        ),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: _section(
                          title: 'Unsigned Leases',
                          titleIcon: Icons.info_outline,
                          iconColor: Colors.deepOrange,
                          items: _unsignedLeases,
                          pageIndex: _unsignedPage,
                          onPageChanged: (p) =>
                              setState(() => _unsignedPage = p),
                          dateProvider: dateProvider,
                          forUnsignedSection: true,
                          initiallyExpanded: true,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _section(
                          title: 'Signed Leases',
                          titleIcon: Icons.check_circle_outline,
                          iconColor: Colors.green,
                          items: _signedLeases,
                          pageIndex: _signedPage,
                          onPageChanged: (p) => setState(() => _signedPage = p),
                          dateProvider: dateProvider,
                          forUnsignedSection: false,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ],
                ],
              ),
            ),
    );
  }
}
