import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Model/team_member.dart';
import '../../repository/team_repo.dart';
import 'add_admin_screen.dart';
import 'add_staff_screen.dart';
import 'permission_matrix_view.dart';

const Color _navy = Color(0xFF152B51); // == blueColor RGBO(21,43,81,1)
const Color _muted = Color(0xFF8A95A8);
const Color _cardBorder = Color(0xFFE7EBF1);
const Color _emailBtnBg = Color(0xFFEFF3F8);
const Color _greenBg = Color(0xFFDFF3E4);
const Color _greenText = Color(0xFF2E7D45);
const Color _amberBg = Color(0xFFFFF3E0);
const Color _amberText = Color(0xFFB26A00);
const Color _cancelBtnBg = Color(0xFFFCEAEA);
const Color _cancelFg = Color(0xFFE03B3B);

/// Team & Access section, embedded inside Settings (Settings -> "Team & Access").
///
/// Three tabs:
///   - ADMINS       driven by GET /api/admin/team/team (admins[])
///   - STAFF        driven by GET /api/admin/team/team (staff[])
///   - PERMISSIONS  inline Staff / Vendor / Tenant matrix (PermissionService)
///
/// Intentionally non-scrolling (uses Columns, not inner ListViews) so it
/// composes cleanly inside the parent Settings ListView.
class TeamAccessSection extends StatefulWidget {
  const TeamAccessSection({super.key});

  @override
  State<TeamAccessSection> createState() => _TeamAccessSectionState();
}

class _TeamAccessSectionState extends State<TeamAccessSection>
    with NetworkRetryState {
  final TeamRepository _repo = TeamRepository();

  bool _loading = true;
  TeamData _data = TeamData();
  bool _isStaff = false; // staff users can't manage the team (admins/staff tabs)

  int _selectedTab = 0; // 0 = Admins, 1 = Staff, 2 = Permissions, 3 = Activity

  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  bool _staffSortAsc = true;
  bool _adminSortAsc = true;

  String? _expandedKey; // only one card expanded at a time (accordion)

  // --- Activity tab ------------------------------------------------------
  // Mirrors the web CRM's Activity Log (TeamAccess.jsx): fetched only when the
  // tab is first opened (never in the background), re-fetched on filter/page
  // change, and paged server-side.
  bool _activityLoading = false;
  List<TeamActivityEntry> _activity = const [];
  int _activityTotal = 0;
  int _activityPage = 1;
  static const int _activityPageSize = 25;
  String _activityAction = ''; // '' = All actions
  bool _activityNewestFirst = true; // the server already sorts newest-first

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _init();
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  // Staff users can't manage team members, so skip the team fetch for them and
  // show a message on the Admins/Staff tabs (the Permissions tab still works).
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString('staff_id');
    final isStaff = prefs.getString('role') == 'Staffmember' &&
        staffId != null &&
        staffId.isNotEmpty;
    if (!mounted) return;
    setState(() {
      _isStaff = isStaff;
      if (isStaff) _loading = false; // no team API call for staff
    });
    if (!isStaff) _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repo.fetchTeam();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      // Never leave the screen stuck on the spinner — show the empty state
      // and a message instead (e.g. a network error or a bad field type).
      if (!mounted) return;
      setState(() => _loading = false);
      Fluttertoast.showToast(msg: "Couldn't load team. Please try again.");
    }
  }

  // Kept for future use (the email button currently shows the reset dialog).
  // ignore: unused_element
  Future<void> _sendEmail(String? email) async {
    if (email == null || email.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'No email address available');
      return;
    }
    final uri = Uri(scheme: 'mailto', path: email.trim());
    try {
      final ok = await launchUrl(uri);
      if (!ok) Fluttertoast.showToast(msg: 'Could not open mail app');
    } catch (_) {
      Fluttertoast.showToast(msg: 'Could not open mail app');
    }
  }

  @override
  Widget build(BuildContext context) {
    // This view lives inside another screen's tab, so it shows the
    // compact offline state rather than taking over the whole page.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildActionButtons(),
        const SizedBox(height: 18),
        _buildTabBar(),
        const SizedBox(height: 18),
        if (_selectedTab == 2)
          _buildPermissionsTab() // loads on its own — never waits for the team API
        else if (_isStaff)
          // Admins/Staff/Activity are all admin-only. The activity route is
          // guarded server-side by requireAdminCaller, and web hides the whole
          // Team & Access entry for non-admins, so a staff caller gets the same
          // restricted view here rather than an empty list.
          _buildStaffRestricted()
        else if (_selectedTab == 3)
          _buildActivityTab() // loads on its own when the tab is opened
        else if (_loading)
          _buildLoading()
        else if (_selectedTab == 0)
          _buildAdminsTab()
        else
          _buildStaffTab(),
        const SizedBox(height: 24),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons (Add Admin / Add Staff)
  // ---------------------------------------------------------------------------
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton('Add Admin', () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddAdminScreen()),
            );
            if (result == true) _load(); // refresh after a successful invite
          }),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _actionButton('Add Staff', () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddStaffScreen()),
            );
            if (result == true) _load();
          }),
        ),
      ],
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return Material(
      color: _navy,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab bar
  // ---------------------------------------------------------------------------
  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _cardBorder, width: 1)),
      ),
      child: Row(
        children: [
          _tab('ADMINS (${_data.admins.length})', 0),
          _tab('STAFF (${_data.staff.length})', 1),
          _tab('PERMISSIONS', 2),
          _tab('ACTIVITY', 3),
        ],
      ),
    );
  }

  Widget _tab(String label, int index) {
    final bool active = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedTab = index);
          // Activity is fetched when the tab is opened and refreshed on every
          // re-open, matching the web CRM — an audit trail should not go stale
          // behind a tab. It is never fetched in the background.
          if (index == 3 && !_isStaff) _loadActivity();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _navy : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          // Four equal-width tabs: scaleDown lets the longest label shrink to
          // fit its share of the row instead of overflowing on a narrow screen.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.3,
                fontWeight: FontWeight.w700,
                color: active ? _navy : _muted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Admins tab
  // ---------------------------------------------------------------------------
  Widget _buildAdminsTab() {
    final admins = [..._data.admins]..sort((a, b) => _adminSortAsc
        ? a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase())
        : b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Total admins: '),
            TextSpan(
              text: '${_data.admins.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
            ),
            const TextSpan(text: '  ·  Full company access'),
          ]),
          style: const TextStyle(fontSize: 13.5, color: _muted),
        ),
        const SizedBox(height: 14),
        _listHeader(
          sortAsc: _adminSortAsc,
          onSort: () => setState(() => _adminSortAsc = !_adminSortAsc),
        ),
        const SizedBox(height: 12),
        if (admins.isEmpty)
          _sectionEmptyState(
            icon: Icons.shield_outlined,
            title: 'No admins yet',
            subtitle: 'Use Add Admin above to invite a co-administrator.',
          )
        else
          ...admins.map(_buildAdminCard),
      ],
    );
  }

  Widget _buildAdminCard(TeamAdmin a) {
    final key = 'admin_${a.sId ?? a.email ?? a.fullName}';
    final name = a.fullName.isEmpty ? 'N/A' : a.fullName;
    return _expandableCard(
      cardKey: key,
      name: name,
      isPending: a.isPending ?? false,
      details: [
        _detailRow('Email', a.email),
        _detailRow('Phone', a.phoneNumber),
        _detailRow('Role', 'Owner / Admin'),
      ],
      email: a.email,
      userType: 'admin',
      userId: a.sId,
    );
  }

  // ---------------------------------------------------------------------------
  // Staff tab
  // ---------------------------------------------------------------------------
  Widget _buildStaffTab() {
    final q = _search.trim().toLowerCase();
    final staff = _data.staff.where((s) {
      if (q.isEmpty) return true;
      return (s.staffmemberName ?? '').toLowerCase().contains(q) ||
          (s.staffmemberEmail ?? '').toLowerCase().contains(q) ||
          (s.staffmemberDesignation ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => _staffSortAsc
          ? (a.staffmemberName ?? '')
              .toLowerCase()
              .compareTo((b.staffmemberName ?? '').toLowerCase())
          : (b.staffmemberName ?? '')
              .toLowerCase()
              .compareTo((a.staffmemberName ?? '').toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(),
        const SizedBox(height: 12),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Total: '),
            TextSpan(
              text: '${_data.staff.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
            ),
            const TextSpan(text: '  ·  Showing '),
            TextSpan(
              text: '${staff.length}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
            ),
          ]),
          style: const TextStyle(fontSize: 13.5, color: _muted),
        ),
        const SizedBox(height: 14),
        _listHeader(
          sortAsc: _staffSortAsc,
          onSort: () => setState(() => _staffSortAsc = !_staffSortAsc),
        ),
        const SizedBox(height: 12),
        if (staff.isEmpty)
          _sectionEmptyState(
            icon: Icons.people_outline,
            title: _search.trim().isEmpty
                ? 'No staff members yet'
                : 'No matching staff members',
            subtitle: _search.trim().isEmpty
                ? 'Use Add Staff above to invite a team member.'
                : 'No staff members match your search.',
          )
        else
          ...staff.map(_buildStaffCard),
      ],
    );
  }

  Widget _buildStaffCard(TeamStaff s) {
    final key = 'staff_${s.sId ?? s.staffmemberEmail ?? s.staffmemberName}';
    final name =
        (s.staffmemberName ?? '').isEmpty ? 'N/A' : s.staffmemberName!;
    return _expandableCard(
      cardKey: key,
      name: name,
      isPending: s.isPending ?? false,
      details: [
        _detailRow('Title', s.staffmemberDesignation),
        _detailRow('Email', s.staffmemberEmail),
        _detailRow('Phone', s.staffmemberPhoneNumber),
      ],
      email: s.staffmemberEmail,
      userType: 'staffmember',
      userId: s.staffmemberId,
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        cursorColor: _navy,
        style: const TextStyle(color: _navy, fontSize: 15),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search here...',
          hintStyle: const TextStyle(color: _muted, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: _muted, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchCtrl.clear();
                      _search = '';
                    });
                    FocusScope.of(context).unfocus();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Permissions tab — full inline Staff / Vendor / Tenant matrix (shared widget,
  // also used by the standalone User Permission screen).
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Activity tab — the team audit trail, matching the web CRM's Activity Log.
  //
  // Data: GET /api/admin/team/activity (admin-only, paged, action-filtered).
  // Layout is phone-first: the web renders a 5-column table (When / Action /
  // Performed by / Target / Details), which cannot fit a phone without a
  // sideways scroll, so the two identifying columns stay on the row and the
  // remaining three move into the expanded body — the same accordion pattern
  // the Admins and Staff tabs already use.
  // ---------------------------------------------------------------------------

  /// Label/code pairs for the filter chips, in the same order as the web CRM's
  /// ACTION_FILTERS. An empty code means "no filter".
  static const List<List<String>> _activityFilters = [
    ['', 'All actions'],
    ['TEAM_UPDATE_NAME', 'Renamed'],
    ['TEAM_UPDATE_EMAIL', 'Email changed'],
    ['TEAM_INVITE_RESEND', 'Invite resent'],
    ['TEAM_INVITE_COADMIN', 'Invited co-admin'],
    ['TEAM_INVITE_STAFF', 'Invited staff'],
    ['TEAM_INVITE_CANCELLED', 'Cancelled invite'],
    ['TEAM_RESET_LINK_SENT', 'Reset link sent'],
    ['TEAM_MOVE_ROLE', 'Changed role'],
    ['TEAM_ACTIVATE', 'Reactivated'],
    ['TEAM_DEACTIVATE', 'Disabled'],
  ];

  Future<void> _loadActivity() async {
    setState(() {
      _activityLoading = true;
    });
    try {
      final page = await _repo.fetchActivity(
        page: _activityPage,
        pageSize: _activityPageSize,
        action: _activityAction,
      );
      if (!mounted) return;
      setState(() {
        _activity = page.items;
        _activityTotal = page.total;
        _activityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Leave whatever was on screen and stop the spinner; the empty state
      // covers a first-load failure.
      setState(() => _activityLoading = false);
    }
  }

  /// "2026-07-10T22:07:44.000Z" -> "Jul 10, 10:07 PM". Falls back to the raw
  /// value if it is not parseable, and to an em dash when absent.
  String _formatWhen(String iso) {
    if (iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final int h24 = local.hour;
    final int h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final String mm = local.minute.toString().padLeft(2, '0');
    final String ampm = h24 < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, $h12:$mm $ampm';
  }

  Widget _buildActivityTab() {
    // The server returns newest-first; the toggle reverses the page in place so
    // the arrow behaves like the Name sort on the other tabs.
    final rows = _activityNewestFirst ? _activity : _activity.reversed.toList();
    final int shown = _activity.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _activityFilterChips(),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Showing '),
            TextSpan(
              text: '$shown',
              style: const TextStyle(fontWeight: FontWeight.w700, color: _navy),
            ),
            TextSpan(text: ' of $_activityTotal event${_activityTotal == 1 ? '' : 's'}'),
          ]),
          style: const TextStyle(fontSize: 13.5, color: _muted),
        ),
        const SizedBox(height: 14),
        if (_activityLoading)
          _buildLoading()
        else ...[
          _activityHeader(),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            _sectionEmptyState(
              icon: Icons.history,
              title: _activityAction.isEmpty
                  ? 'No team activity yet'
                  : 'No matching activity',
              subtitle: _activityAction.isEmpty
                  ? 'Team changes will appear here as they happen.'
                  : 'No events match this filter.',
            )
          else ...[
            ...rows.map(_activityCard),
            _activityPager(),
          ],
        ],
      ],
    );
  }

  /// The 11 action filters. A [Wrap] lets them flow onto as many lines as the
  /// screen needs instead of overflowing sideways.
  Widget _activityFilterChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _activityFilters.map((f) {
        final String code = f[0];
        final String label = f[1];
        final bool active = _activityAction == code;
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            if (active) return;
            setState(() {
              _activityAction = code;
              _activityPage = 1; // a new filter always starts at page 1
            });
            _loadActivity();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: active ? _navy : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: active ? _navy : _cardBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : _navy,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Same shell as [_listHeader], with this tab's own two columns.
  Widget _activityHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          // Invisible leading matching each row's expand arrow, so the columns
          // line up with the cards below.
          const Icon(Icons.arrow_drop_down,
              color: Colors.transparent, size: 24),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: () => setState(
                  () => _activityNewestFirst = !_activityNewestFirst),
              child: Row(
                children: [
                  const Flexible(
                    child: Text(
                      'When',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                  Icon(
                    _activityNewestFirst
                        ? Icons.arrow_drop_down
                        : Icons.arrow_drop_up,
                    color: _navy,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            flex: 5,
            child: Text(
              'Performed by',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(TeamActivityEntry e) {
    final String key = 'activity_${e.id}';
    final bool expanded = _expandedKey == key;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(
                () => _expandedKey = expanded ? null : key),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: _navy,
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 5,
                    child: Text(
                      _formatWhen(e.when),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      e.byName.isEmpty ? '—' : e.byName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: _cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action carries its own pill so it reads as a status, the
                  // way the web CRM chips it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(
                        width: 86,
                        child: Text(
                          'Action',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),
                      Expanded(child: _activityActionPill(e.actionLabel)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _activityDetail(
                    'Target',
                    e.targetEmail.isEmpty
                        ? '—'
                        : (e.targetRole.isEmpty
                            ? e.targetEmail
                            : '${e.targetEmail} (${e.targetRole})'),
                  ),
                  const SizedBox(height: 12),
                  _activityDetail(
                      'Details', e.description.isEmpty ? '—' : e.description),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Label above, value beside it — kept as a Row with a fixed label column so
  /// Action / Target / Details line up, and the value wraps instead of
  /// overflowing when it is a long sentence.
  Widget _activityDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14.5, color: _muted),
          ),
        ),
      ],
    );
  }

  Widget _activityActionPill(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _amberBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE8C89A)),
        ),
        child: Text(
          label.isEmpty ? '—' : label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _amberText,
          ),
        ),
      ),
    );
  }

  /// The empty state used by every tab in this section.
  ///
  /// The older [_emptyState] paints a 200x200 JPG whose own white background
  /// shows as a hard white square against the page. This uses the soft circle
  /// + icon treatment already used by [_buildStaffRestricted] — same palette,
  /// no image asset, and a far smaller block of empty space.
  Widget _sectionEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              color: _emailBtnBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _navy, size: 44),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _navy,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Only rendered when the result actually spans more than one page.
  Widget _activityPager() {
    final int totalPages =
        _activityTotal == 0 ? 1 : (_activityTotal / _activityPageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: _activityPage <= 1 ? _muted : _navy,
            onPressed: _activityPage <= 1
                ? null
                : () {
                    setState(() => _activityPage--);
                    _loadActivity();
                  },
          ),
          Text(
            'Page $_activityPage of $totalPages',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _navy,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: _activityPage >= totalPages ? _muted : _navy,
            onPressed: _activityPage >= totalPages
                ? null
                : () {
                    setState(() => _activityPage++);
                    _loadActivity();
                  },
          ),
        ],
      ),
    );
  }


  Widget _buildPermissionsTab() {
    return const PermissionMatrixView();
  }

  // Shown on the Admins / Staff tabs when the signed-in user is a staff member
  // (they can't manage the team). The Permissions tab is unaffected.
  Widget _buildStaffRestricted() {
    return Container(
      height: MediaQuery.of(context).size.height * .5,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              color: _emailBtnBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: _navy, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            'Only an Admin can manage team members.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _cancelFg,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared building blocks
  // ---------------------------------------------------------------------------
  Widget _listHeader({required bool sortAsc, required VoidCallback onSort}) {
    // Matches the Tenant table header (light blue fill + border + navy text) so
    // it reads clearly against the page background.
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          // Invisible leading to mirror each row's expand arrow so the
          // Name / Status columns line up exactly with the cards below.
          const Icon(Icons.arrow_drop_down,
              color: Colors.transparent, size: 24),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: InkWell(
              onTap: onSort,
              child: Row(
                children: [
                  const Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: _navy,
                    ),
                  ),
                  Icon(
                    sortAsc ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                    color: _navy,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            flex: 4,
            child: Text(
              'Status',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandableCard({
    required String cardKey,
    required String name,
    required bool isPending,
    required List<Widget> details,
    required String? email,
    required String userType,
    required String? userId,
  }) {
    final bool expanded = _expandedKey == cardKey;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              // Tapping the open card closes it; tapping another opens it and
              // collapses the previous one (one at a time).
              _expandedKey = expanded ? null : cardKey;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: _navy,
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 5,
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _statusPill(isPending),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, thickness: 1, color: _cardBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 1) Email = send password / reset link (LIVE).
                  //    Calls send-reset-link, then shows the "Reset link sent"
                  //    dialog on success.
                  _iconBtn(
                    icon: Icons.mail_outline,
                    bg: _emailBtnBg,
                    fg: _navy,
                    onTap: () => _sendReset(
                        userType: userType,
                        userId: userId,
                        email: email,
                        name: name),
                  ),

                  // 2) Cancel pending invitation — only when is_pending == true.
                  //    Shows a confirm dialog, then cancels via the API and
                  //    refreshes the list.
                  if (isPending) ...[
                    const SizedBox(width: 12),
                    _iconBtn(
                      icon: Icons.close,
                      bg: _cancelBtnBg,
                      fg: _cancelFg,
                      onTap: () => _confirmCancel(
                          name: name, userType: userType, userId: userId),
                    ),
                  ],

                  // 3) Promote (staff -> admin) / demote (admin -> staff).
                  const SizedBox(width: 12),
                  _iconBtn(
                    icon: Icons.swap_vert,
                    bg: _emailBtnBg,
                    fg: _navy,
                    onTap: () => _confirmMoveRole(
                        name: name, userType: userType, userId: userId),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(bool isPending) {
    final Color bg = isPending ? _amberBg : _greenBg;
    final Color fg = isPending ? _amberText : _greenText;
    final String label = isPending ? 'Pending' : 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    final String shown = (value == null || value.isEmpty) ? 'N/A' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: '$label : ',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: _navy,
            ),
          ),
          TextSpan(
            text: shown,
            style: const TextStyle(fontSize: 14.5, color: _muted),
          ),
        ]),
      ),
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 46,
          alignment: Alignment.center,
          child: Icon(icon, color: fg, size: 22),
        ),
      ),
    );
  }

  // Sends the set/reset-password link, then shows the success dialog.
  Future<void> _sendReset({
    required String userType,
    required String? userId,
    required String? email,
    required String name,
  }) async {
    if (userId == null || userId.isEmpty) {
      Fluttertoast.showToast(msg: 'Missing user id');
      return;
    }
    try {
      await _repo.sendResetLink(
          userType: userType, userId: userId, email: email);
      if (!mounted) return;
      _showResetSentDialog(name, email);
    } catch (_) {
      // failure already surfaced via toast in the repository
    }
  }

  void _showResetSentDialog(String name, String? email) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _greenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: _greenText, size: 38),
              ),
              const SizedBox(height: 18),
              const Text(
                'Reset link sent',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'An email has been sent to $name'
                '${(email != null && email.isNotEmpty) ? ' ($email)' : ''}.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.4, color: _muted),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: _navy,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Future<void> _confirmCancel({
    required String name,
    required String userType,
    required String? userId,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDEFE0),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: const Color(0xFFE8973A), width: 2),
                ),
                child: const Icon(Icons.priority_high,
                    color: Color(0xFFE8973A), size: 42),
              ),
              const SizedBox(height: 20),
              Text(
                'Cancel invitation for $name?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "They won't be able to activate this account anymore.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.4, color: _muted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x80152B51)),
                        ),
                        child: const Text(
                          'Keep',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _cancelBtnBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cancel invitation',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _cancelFg,
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
    );
    if (confirmed != true) return;
    if (userId == null || userId.isEmpty) {
      Fluttertoast.showToast(msg: 'Missing user id');
      return;
    }
    try {
      await _repo.cancelInvite(userType: userType, userId: userId);
      if (!mounted) return;
      _load(); // refresh — the cancelled invite drops off the list
    } catch (_) {
      // failure already surfaced via toast in the repository
    }
  }

  // Promote a staff member to admin, or demote an admin to staff, via
  // POST /api/admin/team/move-role. Shows a confirmation dialog, then on
  // success a "Moved / Promoted" dialog (matching the web), and refreshes so
  // the member moves tabs.
  Future<void> _confirmMoveRole({
    required String name,
    required String userType,
    required String? userId,
  }) async {
    final bool promote = userType == 'staffmember'; // staff -> admin
    final String targetRole = promote ? 'admin' : 'staff';
    final String body = promote
        ? 'They will gain full Administrator access to this company. Their '
            'email and password stay the same.'
        : 'They will lose Administrator access and become a Staff member. '
            'Their email and password stay the same.';
    final String confirmLabel =
        promote ? 'Promote to Administrator' : 'Move to Staff';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFFB7C2D0), size: 72),
              const SizedBox(height: 18),
              Text(
                '$confirmLabel : $name ?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 19.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: _navy),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, height: 1.55, color: Color(0xFF6B7688)),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x80152B51)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _navy),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: _navy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          confirmLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
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
    );
    if (confirmed != true) return;
    if (userId == null || userId.isEmpty) {
      Fluttertoast.showToast(msg: 'Missing user id');
      return;
    }
    try {
      await _repo.moveRole(userId: userId, targetRole: targetRole);
      if (!mounted) return;
      _load(); // refresh so the member moves to the other tab (behind dialog)
      _showMoveRoleSuccessDialog(name: name, promote: promote);
    } catch (_) {
      // failure already surfaced via toast in the repository
    }
  }

  // Success confirmation after a role change (matches the web "Moved /
  // Promoted" dialog). OK just closes — the list refreshed underneath.
  void _showMoveRoleSuccessDialog(
      {required String name, required bool promote}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _greenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: _greenText, size: 38),
              ),
              const SizedBox(height: 18),
              Text(
                promote ? 'Promoted to Administrator' : 'Moved to Staff',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: _navy),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  promote
                      ? '$name is now an Administrator.'
                      : '$name is now a Staff member.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14, height: 1.5, color: Color(0xFF6B7688)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: _navy,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: SpinKitFadingCircle(color: _navy, size: 40)),
    );
  }
}
