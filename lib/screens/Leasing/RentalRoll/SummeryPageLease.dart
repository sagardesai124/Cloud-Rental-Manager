import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/Model/lease_term.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Document_Rental/Add_DocumentRental.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Recurringpayment.dart';

import 'package:three_zero_two_property/screens/Leasing/RentalRoll/RenewLease.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/Renters%20Insurance/Renters_Insurance_table.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
import 'package:three_zero_two_property/Model/tenants.dart';

import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/lease.dart';

import 'package:three_zero_two_property/screens/Leasing/RentalRoll/newModel.dart';
// import 'package:three_zero_two_property/repository/properties_summery.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';

import '../../../../Model/RentalOwnersData.dart';
import '../../../../model/lease.dart';
import '../../../../repository/Rental_ownersData.dart';
import '../../../../repository/properties_summery.dart';
import '../../../../widgets/drawer_tiles.dart';
import '../../../model/LeaseLedgerModel.dart';
import '../../../model/LeaseSummary.dart';
import '../../../model/LeaseChargesModel.dart';
import '../../../provider/dateProvider.dart';
import '../../../widgets/CustomTableShimmer.dart';
import '../../Communications/Send E-mail/send_mail.dart';
import '../../Rental/Properties/moveout/lease_end_decision.dart';
import '../../Rental/Properties/moveout/lease_end_decision_box.dart';
import '../../Rental/Properties/moveout/moveout_form_ui.dart';
import '../../Rental/Properties/moveout/repository.dart';
import '../Scheduled_Payments/Scheduled_Payments_table.dart';
import '../scheduled_charges/ScheduledCharge.dart';
import 'Commnunication/communication.dart';
import 'Document_Rental/Document_rental_table.dart';
import 'Evict_tenant.dart';
import 'Financial.dart';
import '../../../widgets/custom_drawer.dart';
import '../../../widgets/custom_history_table.dart';
import '../../../enums/history_type.dart';

import 'Move_out_lease/Moveout_lease.dart';
import 'Notes/Notes_table.dart';
import 'edit_lease.dart';
import 'make_payment.dart';
import 'RecurringChargeDialog.dart';
// Lease → Tenants card actions (View Details / Edit / 2FA / setup email).
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/repository/tenants.dart';
// Prefixed: this screen declares a section-builder METHOD named Tenant(...)
// which shadows the model class inside the State.
import 'package:three_zero_two_property/Model/tenants.dart' as tenant_model;
import 'package:three_zero_two_property/screens/Rental/Tenants/Tenant_summary.dart'
    show ResponsiveTenantSummary;
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class SummeryPageLease extends StatefulWidget {
  bool? isredirectpayment;
  String leaseId;
  String? enddate;
  /// When true, hides app bar and drawer (e.g. when embedded in Tenant Summary).
  bool embeddedInTenantSummary;
  /// Opens a specific tab on entry, given by its title (e.g. 'Lease').
  /// A title is used rather than an index so the deep link keeps working if the
  /// tab order ever changes.
  final String? initialTabTitle;

  SummeryPageLease(
      {super.key,
      required this.leaseId,
      this.isredirectpayment = false,
      this.enddate,
      this.embeddedInTenantSummary = false,
      this.initialTabTitle});
  @override
  State<SummeryPageLease> createState() => _SummeryPageLeaseState();
}

class _SummeryPageLeaseState extends State<SummeryPageLease>
    with SingleTickerProviderStateMixin, NetworkRetryState {
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();
  late Future<LeaseSummary> futureLeaseSummary;
  String? _leaseRentalAddress;
  late Future<List<LeaseTenant>> futureLeasetenant;
  late Future<LeaseLedger?> _leaseLedgerFuture;
  late Future<LeaseCharges?> _leaseChargesFuture;
  // Bumped after returning from Scheduled Charges so the Financial tab's
  // ledger is re-created and reloads (charges may have been added there).
  int _financialRefreshTick = 0;
  late Future<List<Map<String, dynamic>>> _lateFeesFuture;
  late Future<List<Map<String, dynamic>>> _leaseHistoryFuture;
  TabController? _tabController;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  // Pagination variables for Lease History
  int _currentPage = 1;
  int _itemsPerPage = 10;
  List<Map<String, dynamic>> _allLeaseHistory = [];
  int? leaseHistoryExpandedIndex; // Separate variable for lease history table
  //String moveOutDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  String? moveOutDate;
  LeaseEndAnswer _leaseEnd = const LeaseEndAnswer();

  // Web (LeaseTenantsTab.jsx): tenants who moved out (or were evicted) are
  // listed after the current ones, in a grey card headed "Moved out <date>",
  // with the notice date in the company's date format.
  static const Color _movedOutCardBg = Color(0xFFEDEFF2);

  bool _tenantInactive(LeaseTenant t) =>
      (t.moveoutDate ?? '').isNotEmpty || t.isEvicted == true;

  /// Current tenants first, then the others, each group in its own order.
  void _orderTenants(List<LeaseTenant> tenants) {
    final current = tenants.where((t) => !_tenantInactive(t)).toList();
    final past = tenants.where(_tenantInactive).toList();
    tenants
      ..clear()
      ..addAll([...current, ...past]);
  }

  List<Widget> _movedOutHeader(LeaseTenant t) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    return [
      Text(
        (t.moveoutDate ?? '').isNotEmpty
            ? 'Moved out ${dateProvider.formatCurrentDate(t.moveoutDate!)}'
            : 'Evicted',
        style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: mutedClr),
      ),
      const SizedBox(height: 12),
    ];
  }

  Widget _noticeDateRow(LeaseTenant t) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    return Row(
      children: [
        const Text('Notice date:  ',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A4A57))),
        Text(dateProvider.formatCurrentDate(t.moveoutNoticeGivenDate ?? ''),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500, color: mutedClr)),
      ],
    );
  }

  bool _moveControls(LeaseTenant t) => showMoveControls(
        leaseStartDate: t.startDate,
        leaseEndDate: t.endDate,
        isEvicted: t.isEvicted,
      );

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls from `initState` only — controllers, listeners and
  /// filter defaults are not repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureLeasetenant = LeaseRepository.fetchLeaseTenants(widget.leaseId);;
      _leaseLedgerFuture = LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);;
      _leaseChargesFuture = LeaseRepository().fetchLeaseCharges(widget.leaseId);;
      _lateFeesFuture = fetchLateFees();;
      _leaseHistoryFuture = fetchLeaseHistory();;
    });
  }

  @override
  void initState() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    // Term history for the Lease Details row — supplies the "inferred" marker
    // and the current term's real dates (web: RentRollDetail/LeaseTermsTable).
    _loadLeaseTerms();
    // TODO: implement initState
    futureLeaseSummary = LeaseRepository.fetchLeaseSummary(widget.leaseId);
    // Cache the lease's property address for screens (Scheduled Charges) whose
    // lease-scoped API doesn't return it.
    futureLeaseSummary.then((summary) {
      final addr = summary.data?.rentalAddress;
      if (addr != null && addr.trim().isNotEmpty && mounted) {
        _leaseRentalAddress = addr;
      }
    }).catchError((_) {});
    futureLeasetenant = LeaseRepository.fetchLeaseTenants(widget.leaseId);
    _leaseLedgerFuture =
        LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
    _leaseChargesFuture = LeaseRepository().fetchLeaseCharges(widget.leaseId);
    _lateFeesFuture = fetchLateFees();
    _leaseHistoryFuture = fetchLeaseHistory();
    _tabController = TabController(length: 3, vsync: this);
    // moveOutDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    // moveOutDate = widget.enddate!;
    // Initialize moveOutDate with the end date or current date
    //  moveOutDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(widget.enddate!));

    if (widget.isredirectpayment != null && widget.isredirectpayment!) {
      _tabController!.animateTo(1);
      _selectedIndex = 1;
    }
    // Deep link straight to a named tab (used by lease-document notifications,
    // which web opens on the Lease tab rather than Financial). Only the
    // dropdown-driven _selectedIndex needs setting — the legacy 3-tab
    // _tabController no longer renders anything, so animateTo is skipped.
    final String? requestedTab = widget.initialTabTitle;
    if (requestedTab != null && requestedTab.isNotEmpty) {
      final int requestedIndex = tabTitles.indexOf(requestedTab);
      if (requestedIndex >= 0) {
        _selectedIndex = requestedIndex;
      }
    }
    fetchLeaseTenants();
    super.initState();
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back (reliably so on the
    // iOS simulator), which made this screen declare itself offline
    // while requests actually succeed. Confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  List<LeaseTenant> leaseTenants = [];


  // ── Lease → Tenants card actions ──────────────────────────────────────────
  // WEB PARITY (LeaseTenantsTab.jsx renders TenantCardWithActions): each tenant
  // card carries a kebab menu beside Move out with View Details / Edit /
  // Enable-Disable 2FA / Send account setup email.
  // 2FA state is cached per tenant so the label reflects reality once known;
  // before that it reads "Enable 2FA", matching web's default prior to its own
  // lazy status fetch.
  final Map<String, bool> _leaseTenant2Fa = {};
  final Set<String> _leaseTenantBusy = {};


  // Admins always hold the tenant-edit right (web: canEdit = admin || ...).
  bool get _canEditLeaseTenant => true;

  Future<void> _viewLeaseTenantDetails(String tenantId) async {
    if (tenantId.isEmpty || _leaseTenantBusy.contains(tenantId)) return;
    // The summary's header renders from the passed record
    // (`widget.tenants?.tenantFirstName ?? 'Loading...'`), so opening it with
    // only an id leaves the name stuck on "Loading...". Load the full record
    // first, exactly as the Edit action does.
    setState(() => _leaseTenantBusy.add(tenantId));
    final List<tenant_model.Tenant> data =
        await TenantsRepository().fetchTenantsummery(tenantId) ?? [];
    if (!mounted) return;
    setState(() => _leaseTenantBusy.remove(tenantId));
    // Web keeps this sub-tab inside the tenant page, so switching tenants there
    // never leaves the lease behind. Mobile's lease is its own screen, so we
    // PUSH rather than replace: back returns to the lease with every tenant
    // card still there, which is what makes viewing a second tenant practical.
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResponsiveTenantSummary(
              tenantId: tenantId,
              tenants: data.isNotEmpty ? data.first : null,
            )));
  }

  // Web's Edit opens the tenant's own page (in edit mode) rather than a
  // separate form, so mobile lands on the same tenant screen and the user
  // edits from there. Opening the edit form directly from here is deliberately
  // avoided — it would bypass the tenant page the web flow goes through.
  Future<void> _editLeaseTenant(String tenantId) async {
    await _viewLeaseTenantDetails(tenantId);
  }

  Future<void> _sendLeaseTenantSetupEmail(LeaseTenant t) async {
    if (t.tenantId.isEmpty || _leaseTenantBusy.contains(t.tenantId)) return;
    if (t.tenantEmail.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Tenant has no email on file.');
      return;
    }
    setState(() => _leaseTenantBusy.add(t.tenantId));
    final ok = await TenantsRepository().sendSetupEmail(t.tenantId);
    if (!mounted) return;
    setState(() => _leaseTenantBusy.remove(t.tenantId));
    // No toast here on purpose. sendSetupEmail() in the tenants repository
    // already reports both outcomes, and it must keep doing so because
    // Tenant_summary.dart and Tenants_table.dart call it without any message of
    // their own. Reporting here as well put TWO toasts on screen at once, so
    // this screen defers to the repository rather than the other way round.
  }

  Future<void> _toggleLeaseTenant2Fa(LeaseTenant t) async {
    if (t.tenantId.isEmpty || _leaseTenantBusy.contains(t.tenantId)) return;
    final bool enable = !(_leaseTenant2Fa[t.tenantId] ?? false);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(enable ? 'Enable 2FA' : 'Disable 2FA',
            style: TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
        content: Text(
            '${enable ? 'Enable' : 'Disable'} two-factor authentication for '
            '${t.tenantFirstName} ${t.tenantLastName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: blueColor))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(enable ? 'Enable' : 'Disable',
                  style: TextStyle(
                      color: blueColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _leaseTenantBusy.add(t.tenantId));
    final ok = await TenantsRepository().setTenant2FA(
      tenantId: t.tenantId,
      enable: enable,
      email: t.tenantEmail,
      phoneNumber: t.tenantPhoneNumber,
    );
    if (!mounted) return;
    setState(() {
      _leaseTenantBusy.remove(t.tenantId);
      if (ok) _leaseTenant2Fa[t.tenantId] = enable;
    });
    // No toast here on purpose. setTenant2FA() in the tenants repository
    // already reports both outcomes, and it must keep doing so because
    // Tenants_table.dart calls it without any message of its own. Reporting
    // here as well put TWO toasts on screen at once, so this screen defers to
    // the repository rather than the other way round.
  }

  // Lazily learn the tenant's current 2FA state so the menu label is truthful,
  // the same way web's card fetches the status per tenant. Cached per id; the
  // first open may briefly show the default "Enable 2FA", correcting itself.
  Future<void> _loadLeaseTenant2Fa(String tenantId) async {
    if (tenantId.isEmpty || _leaseTenant2Fa.containsKey(tenantId)) return;
    final List<tenant_model.Tenant> data =
        await TenantsRepository().fetchTenantsummery(tenantId) ?? [];
    if (!mounted || data.isEmpty) return;
    setState(() => _leaseTenant2Fa[tenantId] = data.first.twoFactorEnabled);
  }

  Widget _leaseTenantActionsMenu(LeaseTenant t) {
    final bool twoFaOn = _leaseTenant2Fa[t.tenantId] ?? false;
    // WEB PARITY (useTenantActions.jsx): Edit needs the edit permission
    // (admins always have it), 2FA and the setup email are hidden on trial
    // accounts, and the setup email needs an email on file. Delete is hidden
    // on this screen because the lease tab passes no delete handler on web.
    final bool isTrial = t.adminId == "is_trial";
    final bool hasEmail = (t.tenantEmail).trim().isNotEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      color: Colors.white,
      surfaceTintColor: Colors.white,
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, size: 20, color: blueColor),
      onSelected: (value) {
        switch (value) {
          case 'view':
            _viewLeaseTenantDetails(t.tenantId);
            break;
          case 'edit':
            _editLeaseTenant(t.tenantId);
            break;
          case '2fa':
            _toggleLeaseTenant2Fa(t);
            break;
          case 'setup':
            _sendLeaseTenantSetupEmail(t);
            break;
        }
      },
      itemBuilder: (_) {
        _loadLeaseTenant2Fa(t.tenantId);
        return [
          _leaseTenantMenuItem('view', Icons.remove_red_eye_outlined,
              'View Details', const Color(0xFF152B51)),
          if (_canEditLeaseTenant)
            _leaseTenantMenuItem(
                'edit', Icons.edit_outlined, 'Edit', const Color(0xFF2E7D32)),
          if (!isTrial)
            _leaseTenantMenuItem('2fa', Icons.shield_outlined,
                twoFaOn ? 'Disable 2FA' : 'Enable 2FA', const Color(0xFF152B51)),
          if (!isTrial && hasEmail)
            _leaseTenantMenuItem('setup', Icons.mail_outline,
                'Send account setup email', const Color(0xFF152B51)),
        ];
      },
    );
  }

  PopupMenuItem<String> _leaseTenantMenuItem(
      String value, IconData icon, String label, Color iconColor) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: blueColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void fetchLeaseTenants() async {
    try {
      List<LeaseTenant> tenants =
          await LeaseRepository.fetchLeaseTenants(widget.leaseId);
      setState(() {
        leaseTenants = tenants;
        isLoading = false;
      });
    } catch (e) {
      logError('Error fetching tenants: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to fetch late fees from Financial table data
  Future<List<Map<String, dynamic>>> fetchLateFees() async {
    try {
      // Get lease ledger data (same data used in Financial table)
      final leaseLedger = await _leaseLedgerFuture;

      if (leaseLedger == null || leaseLedger.data == null) {
        return [];
      }

      List<Map<String, dynamic>> lateFees = [];

      // Filter for Charge type entries
      final chargeEntries =
          leaseLedger.data!.where((data) => data.type == "Charge").toList();

      // Filter for late fee income entries from charge entries
      for (var chargeData in chargeEntries) {
        if (chargeData.entry != null && chargeData.entry!.isNotEmpty) {
          for (var entry in chargeData.entry!) {
            // Filter for late fee income entries - check chargeType == "Late Fee Income"
            if (entry.chargeType == 'Late Fee Income') {
              lateFees.add({
                'date': entry.date ?? '',
                'amount': entry.amount ?? 0.0,
                'entry_id': entry.entryId ?? '',
              });
            }
          }
        }
      }

      return lateFees;
    } catch (e) {
      logError('Error fetching late fees: $e');
      throw Exception('Error fetching late fees: $e');
    }
  }

  // Function to fetch lease history from API
  Future<List<Map<String, dynamic>>> fetchLeaseHistory() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      String? adminId = prefs.getString("adminId");

      final url =
          Uri.parse('$Api_url/api/leases/lease_history/${widget.leaseId}');

      final response = await apiGet(
        url,
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $adminId",
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        List<Map<String, dynamic>> leaseHistory = [];

        // Handle different response structures
        if (jsonData['data'] != null) {
          List<dynamic> data =
              jsonData['data'] is List ? jsonData['data'] : [jsonData['data']];

          for (var entry in data) {
            leaseHistory.add({
              'date': entry['date'] ??
                  entry['createdAt'] ??
                  entry['updatedAt'] ??
                  '',
              'type': entry['type'] ?? entry['category'] ?? 'N/A',
              'action': entry['action'] ??
                  entry['type'] ??
                  entry['category'] ??
                  'N/A',
              'description': entry['description'] ?? entry['notes'] ?? '',
              'amount': (entry['amount'] ?? 0).toDouble(),
              'entry_id': entry['id'] ?? entry['entry_id'] ?? '',
              'performed_by': entry['performed_by'] ??
                  entry['updated_by'] ??
                  entry['updated_by_user'] ??
                  entry['updated_by_name'] ??
                  entry['user_name'] ??
                  entry['created_by'] ??
                  entry['created_by_user'] ??
                  entry['created_by_name'] ??
                  '',
            });
          }
        }

        // Store all data for pagination
        setState(() {
          _allLeaseHistory = leaseHistory;
          _currentPage = 1; // Reset to first page when data is fetched
        });

        return leaseHistory;
      } else {
        throw Exception('Failed to load lease history: ${response.statusCode}');
      }
    } catch (e) {
      logError('Error fetching lease history: $e');
      throw Exception('Error fetching lease history: $e');
    }
  }

  // Get paginated lease history data
  List<Map<String, dynamic>> getPaginatedLeaseHistory() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _allLeaseHistory.length > startIndex
        ? _allLeaseHistory.sublist(
            startIndex,
            endIndex > _allLeaseHistory.length
                ? _allLeaseHistory.length
                : endIndex)
        : [];
  }

  // Get total pages
  int getTotalPages() {
    return (_allLeaseHistory.length / _itemsPerPage).ceil();
  }

  // Format date and time with AM/PM
  String _formatDateTimeWithAMPM(String dateTimeString) {
    if (dateTimeString.isEmpty) return '';

    try {
      // List of possible date formats
      List<String> dateFormats = [
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd h:mm:ss a',
        'yyyy-MM-dd h:mm a',
        'yyyy-MM-dd',
        'yyyy-M-d HH:mm:ss',
        'yyyy-M-d HH:mm',
        'MM/dd/yyyy HH:mm:ss',
        'MM/dd/yyyy HH:mm',
        'MM/dd/yyyy h:mm:ss a',
        'MM/dd/yyyy h:mm a',
        'MM/dd/yyyy',
        'dd-MM-yyyy HH:mm:ss',
        'dd-MM-yyyy HH:mm',
        'dd-MM-yyyy h:mm:ss a',
        'dd-MM-yyyy h:mm a',
        'dd-MM-yyyy',
        'M/d/yyyy, h:mm:ss a',
        'M/d/yyyy, h:mm a',
        'yyyy-MM-ddTHH:mm:ss',
        'yyyy-MM-ddTHH:mm:ssZ',
        'yyyy-MM-ddTHH:mm:ss.SSSZ',
      ];

      DateTime? parsedDate;

      // Try to parse with different formats
      for (String format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(dateTimeString);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate == null) {
        // If parsing fails, return original string
        return dateTimeString;
      }

      // Format with date and time to match web format exactly
      // Web format: YYYY-MM-DD HH:mm:ss (24-hour format, zero-padded, with seconds)
      // Example: "2026-01-06 08:00:03"

      // Handle verbose JavaScript date format FIRST
      // Format: "Mon Dec 08 2025 08:00:03 GMT+0000 (Coordinated Universal Time)"
      if (dateTimeString.contains('GMT') && dateTimeString.contains('(')) {
        try {
          String datePart = dateTimeString.split('(')[0].trim();
          try {
            final verboseFormat = DateFormat("EEE MMM dd yyyy HH:mm:ss 'GMT'Z");
            parsedDate = verboseFormat.parse(datePart);
          } catch (e) {
            // Alternative: Extract components manually
            final altPattern = RegExp(
                r'(\w{3})\s+(\w{3})\s+(\d{1,2})\s+(\d{4})\s+(\d{2}:\d{2}:\d{2})');
            final match = altPattern.firstMatch(dateTimeString);
            if (match != null) {
              final month = match.group(2)!;
              final day = match.group(3)!;
              final year = match.group(4)!;
              final time = match.group(5)!;
              final altFormat = DateFormat("MMM dd yyyy HH:mm:ss");
              parsedDate = altFormat.parse("$month $day $year $time");
            }
          }
        } catch (e) {
          logError('Failed to parse verbose date format: $e');
        }
      }

      // If parsedDate is still null, try to parse common formats
      if (parsedDate == null) {
        // If already in YYYY-MM-DD HH:mm:ss format, return as-is (matches web format)
        if (RegExp(r'^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$')
            .hasMatch(dateTimeString)) {
          return dateTimeString;
        }
        // Try to parse with common formats
        try {
          parsedDate = DateTime.parse(dateTimeString);
        } catch (e) {
          // Try DateFormat parsing
          List<String> dateFormats = [
            'yyyy-MM-dd HH:mm:ss',
            'yyyy-MM-dd HH:mm',
            'yyyy-MM-dd',
            'MM/dd/yyyy HH:mm:ss',
            'MM/dd/yyyy HH:mm',
            'MM/dd/yyyy',
          ];
          for (String format in dateFormats) {
            try {
              parsedDate = DateFormat(format).parse(dateTimeString);
              break;
            } catch (e) {
              continue;
            }
          }
        }
      }

      // If still null, return original string
      if (parsedDate == null) {
        return dateTimeString;
      }

      // Format to match web: YYYY-MM-DD HH:mm:ss (always 24-hour format, zero-padded, with seconds)
      String formattedDateTime =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(parsedDate);

      return formattedDateTime;
    } catch (e) {
      logError('Error formatting date: $e');
      return dateTimeString;
    }
  }

  final TextEditingController startDateController = TextEditingController();
  DateTime? _startDate;
  final TextEditingController endDateController = TextEditingController();
  List<String> tabTitles = [
    "Summary",
    "Financial",
    "Tenant",
    "Communication",
    "Renter's Insurance",
    "Lease",
    "Notes"
    //"Documents", // You can add more tabs here
    // "New Tab", ...
  ];
  bool isLoading = false;
  bool isMovedOut = false;
  int _selectedIndex = 0;
  String? _selectedLeaseType;
  final List<String> leaseTypeitems = [
    'Fixed',
    'Fixed w/rollover',
    'At-will(month to month)',
  ];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // When embedded inside a parent scroll (e.g. Tenant Summary ListView),
    // skip Scaffold + SingleChildScrollView so the outer scroll handles everything.
    if (widget.embeddedInTenantSummary) {
      return _connectivityResult != ConnectivityResult.none
          ? FutureBuilder<LeaseSummary>(
              future: futureLeaseSummary,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                } else if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text('No data found.'));
                }
                return _buildLeaseContent(snapshot.data!, context, screenWidth);
              },
            )
          : _buildNoInternetWidget();
    }

    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Leases",
        dropdown: true,
      ),
      body: !isOffline
          ? SingleChildScrollView(
              child: FutureBuilder<LeaseSummary>(
                  future: futureLeaseSummary,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 300),
                        child: SpinKitSpinningLines(
                          color: blueColor,
                          size: 55.0,
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                    } else if (!snapshot.hasData || snapshot.data == null) {
                      return const Center(child: Text('No data found.'));
                    } else {
                      return _buildLeaseContent(snapshot.data!, context, screenWidth);
                    }
                  }),
            )
          : _buildNoInternetWidget(),
    );
  }

  Widget _buildNoInternetWidget() {
    return NoInternetView(onRetry: retryNow);
  }

  Widget _buildLeaseContent(LeaseSummary lease, BuildContext context, double screenWidth) {
    return Column(
                        children: <Widget>[
                          if (!widget.embeddedInTenantSummary) ...[
                            const SizedBox(
                              height: 20,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Icon(
                                      Icons.arrow_back_ios_new_sharp,
                                      size: 24,
                                      color: blueColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Lease',
                                      style: TextStyle(
                                        color: blueColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await Navigator.of(context)
                                          .push(MaterialPageRoute(
                                              builder: (context) => send_email(
                                                    lease: lease.data!.tenantId!,
                                                    leaseID: lease.data!.leaseId!,
                                                  )));
                                    },
                                    child: Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: blueColor,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        "Send Mail",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => Edit_lease(
                                                    leaseId: lease.data!.leaseId!,
                                                  )));
                                    },
                                    child: Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: blueColor,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        "Edit",
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
                          const SizedBox(
                            height: 10,
                          ),
                          ],
                          Container(
                            height: 60,
                            margin: const EdgeInsets.symmetric(
                                vertical: 5, horizontal: 0),
                            child:

                                // Dropdown Tab Selector
                                Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              // remove the dropdown default border which have underline
                              child: DropdownButton2<String>(
                                isExpanded: true,
                                underline: const SizedBox(),
                                hint: Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: tabTitles[_selectedIndex],
                                selectedItemBuilder: (BuildContext context) {
                                  return tabTitles.map((String item) {
                                    int index = tabTitles.indexOf(item);
                                    IconData iconData;
                                    String iconPath = 'assets/icons/$item.png';
                                    switch (index) {
                                      case 0: // Summary
                                        iconData = Icons.menu;
                                        iconPath = 'assets/icons/summery.png';
                                        break;
                                      case 1: // Financial
                                        iconData = Icons.attach_money;
                                        iconPath = 'assets/icons/financial.png';
                                        break;
                                      case 2: // Tenant
                                        iconData = Icons.people;
                                        iconPath = 'assets/icons/tenants.png';
                                        break;
                                      case 3: // Communication
                                        iconData = Icons.chat_bubble_outline;
                                        iconPath =
                                            'assets/icons/communication.png';
                                        break;
                                      case 4: // Renter's Insurance
                                        iconData = Icons.shield;
                                        iconPath = 'assets/icons/renter.png';
                                        break;
                                      case 5: // Documents
                                        iconData = Icons.description;
                                        iconPath = 'assets/icons/document.png';
                                        break;
                                      case 6: // Notes
                                        iconData = Icons.note;
                                        iconPath = 'assets/icons/note.png';
                                        break;
                                      default:
                                        iconData = Icons.circle;
                                        iconPath = 'assets/icons/summary.png';
                                    }

                                    return Container(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          index == 6
                                              ? Icon(
                                                  Icons.sticky_note_2_outlined,
                                                  size: 22,
                                                  color: blueColor)
                                              : Image.asset(iconPath,
                                                  width: 20, height: 20),
                                          const SizedBox(width: 12),
                                          Text(
                                            item,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: blueColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList();
                                },
                                items: tabTitles.asMap().entries.map((entry) {
                                  int index = entry.key;
                                  String item = entry.value;
                                  // icon data to image which have store in the assets/icons
                                  String iconPath = 'assets/icons/$item.png';
                                  IconData iconData;
                                  switch (index) {
                                    case 0: // Summary
                                      iconData = Icons.menu;
                                      iconPath = 'assets/icons/summery.png';
                                      break;
                                    case 1: // Financial
                                      iconData = Icons.attach_money;
                                      iconPath = 'assets/icons/financial.png';
                                      break;
                                    case 2: // Tenant
                                      iconData = Icons.people;
                                      iconPath = 'assets/icons/tenants.png';
                                      break;
                                    case 3: // Communication
                                      iconData = Icons.chat_bubble_outline;
                                      iconPath =
                                          'assets/icons/communication.png';
                                      break;
                                    case 4: // Renter's Insurance
                                      iconData = Icons.shield;
                                      iconPath = 'assets/icons/renter.png';
                                      break;
                                    case 5: // Documents
                                      iconData = Icons.description;
                                      iconPath = 'assets/icons/document.png';
                                      break;
                                    case 6: // Notes
                                      iconData = Icons.note;
                                      iconPath = 'assets/icons/note.png';
                                      break;
                                    default:
                                      iconData = Icons.circle;
                                      iconPath = 'assets/icons/summary.png';
                                  }

                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        // color: Colors.green.withOpacity(0.1),
                                        border: index < tabTitles.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                  color: blueColor
                                                      .withOpacity(0.2),
                                                  width: 0.5,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          index == 6
                                              ? Icon(
                                                  Icons.sticky_note_2_outlined,
                                                  size: 22,
                                                  color: blueColor)
                                              : Image.asset(iconPath,
                                                  width: 20, height: 20),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: blueColor,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 25,
                                            color: blueColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedIndex = tabTitles.indexOf(value);
                                    });
                                  }
                                },
                                buttonStyleData: ButtonStyleData(
                                  height: 50,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFDBE0E5)!,
                                      width: 1,
                                    ),
                                    color: Colors.white,
                                  ),
                                ),
                                iconStyleData: IconStyleData(
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                  iconSize: 24,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 380,
                                  //padding: const EdgeInsets.symmetric(horizontal: 5),
                                  //  offset: const Offset(0, -5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                    border: Border.all(
                                      color: const Color(0xFFDBE0E5)!,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(10, 10),
                                      ),
                                    ],
                                  ),
                                  scrollbarTheme: ScrollbarThemeData(
                                    radius: const Radius.circular(40),
                                    thickness: MaterialStateProperty.all(6),
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                  ),
                                ),
                                menuItemStyleData: MenuItemStyleData(
                                  height: 50,
                                  padding: EdgeInsets.zero,
                                  overlayColor: MaterialStateProperty.all(
                                      Colors.grey[100]),
                                ),
                              ),
                            ),
                          ),
                          _buildTabContent(lease, context),
                          /*  Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              SummaryPage(),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: FinancialTable(
                                  rentalUnit: snapshot.data!.data?.rentalUnit,
                                  rentalAddress:
                                      snapshot.data!.data?.rentalAddress,
                                  leaseId: widget.leaseId,
                                  status:
                                      '${determineStatus(snapshot.data!.data?.startDate, snapshot.data!.data?.endDate).toString()}',
                                  tenantId: snapshot.data!.data?.tenantId?.isNotEmpty == true ? snapshot.data!.data!.tenantId!.first : '',
                                ),
                              ),
                              Tenant(context),
                            ],
                          ),
                        ),*/
                        ],
                      );
  }

  Widget _buildTabContent(LeaseSummary snapshot, BuildContext context) {
    switch (_selectedIndex) {
      case 0:
        return SummaryPage();
      case 1:
        // Web parity (LeaseFinancialTab.jsx): the Financial tab opens with the
        // same Property Details + Balance Overview pair the Summary tab shows,
        // above the ledger. Web renders both cards unconditionally here; the
        // balance card keeps its own Active-only rule, which is where mobile
        // already differs from web on the Summary tab too.
        // Vertical inset only: every child below carries its own 15pt side
        // inset (the cards and the quick-actions panel bring theirs with
        // them), so adding a horizontal one here would inset them twice and
        // leave the ledger sitting wider than everything above it.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _propertyDetailsCard(snapshot),
              const SizedBox(height: 10),
              // _balanceOverviewCard deliberately has no horizontal margin of
              // its own — the caller supplies the shared 15pt inset.
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15),
                child: _balanceOverviewCard(snapshot.data),
              ),
              // Web parity: LeaseFinanceBlock renders on the Financial tab as
              // well as the Summary tab — same component, same gating.
              _leaseQuickActions(snapshot),
              const SizedBox(height: 10),
              // FinancialTable brings its own 11pt side margin (Financial.dart,
              // and it is shared with Applicant/Tenant summaries so that value
              // is not ours to change). Add only the 4pt difference so the
              // ledger lands on the same 15pt edge as the cards above it.
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 4),
                child: KeyedSubtree(
                  key: ValueKey('financial_$_financialRefreshTick'),
                  child: FinancialTable(
                rentalUnit: snapshot.data?.rentalUnit,
                rentalAddress: snapshot.data?.rentalAddress,
                leaseId: widget.leaseId,
                status: determineStatus(
                        snapshot.data?.startDate, snapshot.data?.endDate)
                    .toString(),
                  tenantId: snapshot.data?.tenantId?.isNotEmpty == true ? snapshot.data!.tenantId!.first : '',
                  onScheduledChargesClosed: _reloadBalanceOverview,
                ),
                ),
              ),
            ],
          ),
        );
      case 2:
        return Tenant(context);
      case 5:
        return DocumentRentalTable(
          leaseId: widget.leaseId,
        );
      case 6:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: NotesTable(
            leaseid: widget.leaseId,
          ),
        );
      case 4:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Renters_Insurance_table(
            leaseId: widget.leaseId,
            status: determineStatus(
                    snapshot.data?.startDate, snapshot.data?.endDate)
                .toString(),
            tenantId: snapshot.data?.tenantId?.isNotEmpty == true ? snapshot.data!.tenantId!.first : '',
          ),
        );
      case 3:
        return Padding(
            padding: const EdgeInsets.all(8.0),
            child: lease_communication(lease_id: widget.leaseId));
      default:
        return Container(); // Fallback for safety
    }
  }

  int? expandedIndex;
  int?
      renewableHistoryExpandedIndex; // Separate variable for renewable history table
  bool isExpanded = false;

  // Web parity: an At-will (month-to-month) lease has no fixed expiry, so web
  // shows its end as "At Will" and always treats it as Active — it never reads
  // "Expired" by date (RentRoll.js: lease_type === "At-will(month to month)").
  // ── Lease term history (web: RentRollDetail/LeaseTermsTable) ──────────────
  // GET /api/leases/{id}/terms returns the term history newest-first. Terms the
  // server reconstructed from rent charges come back source:"inferred" so an
  // estimate is never mistaken for a recorded renewal. Empty means "fall back
  // to the lease's own fields", exactly as web does.
  List<LeaseTerm> _leaseTerms = const [];

  LeaseTerm? get _currentTerm =>
      _leaseTerms.isEmpty ? null : _leaseTerms.first;

  Future<void> _loadLeaseTerms() async {
    final terms = await LeaseRepository().fetchLeaseTerms(widget.leaseId);
    if (!mounted || terms.isEmpty) return;
    setState(() => _leaseTerms = terms);
  }

  /// The "Renewable History" table below has no counterpart on web: web's
  /// Summary tab surfaces renewals inside the Lease History audit trail, and
  /// the current term (with its inferred badge) in Lease Details. Suppressed
  /// for parity and to stop the same renewal data appearing twice; the block is
  /// kept in the tree so it can be restored by flipping this flag.
  static const bool _showRenewableHistory = false;

  /// WEB PARITY (LeaseSummaryTab.jsx): web renders FinancialSummaryCard ONCE
  /// near the top of the Summary tab, then passes `showSummaryCard={false}` to
  /// the finance block below so a second copy is never drawn. The older inline
  /// balance section on this screen is that second copy — kept in the tree
  /// (it is a 500+ line nested block) but suppressed by this flag, exactly as
  /// web suppresses its own.
  static const bool _showLegacyBalanceSection = false;

  // ── Balance Overview (web: RentRollDetail/FinancialSummaryCard) ───────────
  // Five rows from three sources the page already fetches: charges_payments
  // (balance), lease_summary (rent + due date), lease-charges (deposit + late
  // payments). Nothing is recalculated here.
  //
  // Web gates the whole card on getStatus(...) == "Active" on the Summary tab
  // (LeaseSummaryTab.jsx) — and getStatus treats an At-will lease as Active
  // regardless of its end date, which _leaseStatusWithType already mirrors.

  Widget _balanceRow(String label, String value,
      {Color? valueColor, VoidCallback? onTap}) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF495160),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? blueColor,
            ),
          ),
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }

  /// Accounting-style currency, matching web's `currencySign: "accounting"` —
  /// negatives render as ($1,234.56) and zero always as $0.00.
  String _accountingCurrency(num? amount) {
    final value = (amount ?? 0).toDouble();
    final formatted =
        NumberFormat('#,##0.00', 'en_US').format(value.abs());
    return value < 0 ? '(${formatMoney(formatted)})' : formatMoney(formatted);
  }

  Widget _balanceOverviewCard(dynamic lease) {
    // Web parity: hidden unless the lease reads Active (At-will counts as
    // Active). On a genuinely expired lease web shows no finance card at all.
    final status = _leaseStatusWithType(
        lease.startDate, lease.endDate, lease.leaseType, lease.isEvicted);
    if (status != 'Active') return const SizedBox.shrink();

    final rentLabel = '${(lease.rentCycle?.trim().isNotEmpty == true) ? lease.rentCycle!.trim() : 'Monthly'} Rent';
    final dueDate = (lease.rentDueDate?.trim().isNotEmpty == true)
        ? Provider.of<DateProvider>(context, listen: false)
            .formatCurrentDate(lease.rentDueDate!)
        : 'N/A';

    return Container(
      // No horizontal margin: the caller wraps this card in the same 15pt
      // side Padding the Property Details card uses, so the two line up.
      // Adding margin here would inset it twice.
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDBE0E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: blueColor, size: 24),
              const SizedBox(width: 6),
              Text(
                'Balance Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: blueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<LeaseLedger?>(
            future: _leaseLedgerFuture,
            builder: (context, snap) => _balanceRow(
              'Current Balance',
              _accountingCurrency(snap.data?.totalBalance),
            ),
          ),
          _balanceRow(rentLabel, _accountingCurrency(lease.amount)),
          FutureBuilder<LeaseCharges?>(
            future: _leaseChargesFuture,
            builder: (context, snap) => Column(
              children: [
                _balanceRow(
                  'Security Deposit',
                  _accountingCurrency(
                      snap.data?.data?.securityDeposits?.totalAmount),
                ),
                _balanceRow(
                  'Late Payments (Last 12 Months)',
                  '${snap.data?.data?.lateRentPayments?.totalEntries ?? 0}',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFCED4DA)),
          const SizedBox(height: 12),
          _balanceRow('Due Date', dueDate,
              valueColor: const Color(0xFFC25B33)),
        ],
      ),
    );
  }

  // ── Lease Details card: stacked label/value layout ────────────────────────
  // The old three-column row (Property | Status | Type) squeezed a long lease
  // type such as "At-will(month to month)" into a narrow cell, where it broke
  // mid-word. Labels now sit above their values so each value gets the width
  // it needs — and the "inferred" pill has room beside the type.

  /// Start–End for the Lease Details card, matching web's LeaseTermsTable.
  ///
  /// Two rules copied from `fmtRange`/`isOngoingEnd` there:
  ///  * dates come from the CURRENT TERM when term history is available, and
  ///    fall back to the lease record itself when it is not;
  ///  * a month-to-month / open-ended term stores a far-future sentinel end
  ///    (year >= 2049), which reads as "ongoing" rather than a confusing 2060
  ///    date. Judged per term, so a prior FIXED term still shows its real end.
  String _leaseTermRange(
      String? leaseStart, String? leaseEnd, DateProvider dateProvider) {
    // Web picks the term WHOLESALE (`current ? fmtRange(current) : lease dates`)
    // rather than per field. Falling back field-by-field would mix a term's
    // start with the lease record's end and show a figure web never shows.
    final LeaseTerm? term = _currentTerm;
    final String? start = term != null ? term.startDate : leaseStart;
    final String? end = term != null ? term.endDate : leaseEnd;

    final String startText = (start == null || start.isEmpty)
        ? 'N/A'
        : dateProvider.formatCurrentDate('$start');

    String endText;
    if (end == null || end.isEmpty) {
      endText = 'N/A';
    } else {
      final int? year =
          end.length >= 4 ? int.tryParse(end.substring(0, 4)) : null;
      endText = (year != null && year >= 2049)
          ? 'ongoing'
          : dateProvider.formatCurrentDate('$end');
    }
    return '$startText – $endText';
  }

  /// Small grey uppercase field label.
  Widget _leaseFieldLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8A95A8),
          letterSpacing: 0.6,
        ),
      );

  /// Label above value, optionally with a trailing widget (the inferred pill).
  Widget _leaseField(String label, String value, {Widget? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _leaseFieldLabel(label),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ],
    );
  }

  /// Status with a coloured dot — red when the lease has ended, green while it
  /// is running, amber for anything upcoming.
  Widget _leaseStatusField(String status) {
    final s = status.toLowerCase();
    // A lease that has not started yet reports its status as "Future" (see
    // the status helper below); "upcoming" is accepted as an alias so a
    // reworded status still lands on amber rather than silently reading as
    // running.
    final Color dot = s.contains('expired') || s.contains('evict')
        ? const Color(0xFFDC2626)
        : s.contains('future') || s.contains('upcoming')
            ? const Color(0xFFD97706)
            : const Color(0xFF16A34A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _leaseFieldLabel('Status'),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: dot,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Amber "inferred" pill — same palette as web (#FCF3D6 / #8A6D3B).
  Widget _inferredBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF3D6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'inferred',
        style: TextStyle(
          fontSize: 11,
          color: Color(0xFF8A6D3B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isAtWill(String? leaseType) =>
      (leaseType ?? '').toLowerCase().trim() == 'at-will(month to month)';

  String _leaseStatusWithType(
      String? startDate, String? endDate, String? leaseType,
      [bool? isEvicted]) {
    // Web parity (CRM-4201): an evicted lease reads EVICTED regardless of dates
    // — eviction shortens end_date to today, which would otherwise read Active.
    if (isEvicted == true) return 'EVICTED';
    if (_isAtWill(leaseType)) return 'Active';
    return determineStatus(startDate, endDate);
  }

  String determineStatus(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return 'Unknown';

    // Compare by calendar date only, matching web's getStatus (which formats to
    // YYYY-MM-DD). Using DateTime.now() with its time made a lease ending *today*
    // read as Expired (now > midnight end); date-only keeps end-of-today Active.
    final rawStart = formatDates(startDate);
    final rawEnd = formatDates(endDate);
    final rawToday = DateTime.now();
    DateTime start = DateTime(rawStart.year, rawStart.month, rawStart.day);
    DateTime end = DateTime(rawEnd.year, rawEnd.month, rawEnd.day);
    DateTime today = DateTime(rawToday.year, rawToday.month, rawToday.day);

    if (today.isBefore(start)) {
      return 'Future';
    } else if (today.isAfter(end)) {
      return 'Expired';
    } else {
      return 'Active';
    }
  }

  String determineStatusrenew(
      String? startDate, String? endDate, bool? isRenewed) {
    if (startDate == null ||
        endDate == null ||
        startDate.isEmpty ||
        endDate.isEmpty) {
      return 'Unknown';
    }
    if (isRenewed == null) {
      isRenewed = false;
    }

    DateTime start;
    DateTime end;
    try {
      start = formatDates(startDate);
      end = formatDates(endDate);
    } catch (e) {
      return 'Unknown';
    }
    // Compare by calendar date only (match web's getStatus / determineStatus):
    // a lease ending today must read Active, not Expired.
    start = DateTime(start.year, start.month, start.day);
    end = DateTime(end.year, end.month, end.day);
    final rawToday = DateTime.now();
    DateTime today = DateTime(rawToday.year, rawToday.month, rawToday.day);

    if (isRenewed) {
      // Renewed lease logic
      if (today.isBefore(start)) {
        return 'Future'; // Lease starts in the future
      } else if (today.isAfter(end)) {
        return 'Expired'; // Lease is expired
      } else {
        return 'Active'; // Lease is currently active
      }
    } else {
      // Non-renewed lease logic
      if (today.isBefore(start)) {
        return 'Future'; // Lease starts in the future
      } else if (today.isAfter(end)) {
        return 'Not Renewed'; // Lease expired and not renewed
      } else {
        return 'Not Renewed'; // Lease is ongoing but not renewed
      }
    }
  }

  DateTime formatDates(String dateTime) {
    List<String> dateFormats = [
      'yyyy-MM-dd',
      'yyyy-M-d',
      'dd-MM-yyyy',
      'd-M-yyyy',
      'M/d/yyyy',
      'MM/dd/yyyy',
      'M/d/yyyy, h:mm:ss a',
      'M/d/yyyy, h:mm a'
    ];

    DateTime? parsedDate;

    for (String format in dateFormats) {
      try {
        parsedDate = DateFormat(format).parse(dateTime);
        break;
      } catch (e) {
        continue;
      }
    }

    // If no format worked, return current date as fallback
    return parsedDate ?? DateTime.now();
  }

  Color _getStatusColor(String status) {
    if (status == 'EVICTED') {
      return const Color(0xFFD32F2F); // web parity: red for EVICTED
    }
    if (status == 'Active') {
      return Colors.green; // Green color for 'Active'
    } else if (status == 'Expired') {
      return Colors.grey; // Grey color for 'Expired'
    } else {
      return const Color(0xFF8A95A8); // Default color for other statuses
    }
  }

  /// Web parity (LeaseFinancialTab.jsx): the Property Details card is
  /// shared by the Summary tab and the Financial tab, so it lives in one
  /// place rather than being duplicated per tab.
  Widget _propertyDetailsCard(LeaseSummary lease) {
    final dateProvider = Provider.of<DateProvider>(context);
    var width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15),
      child: Material(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDBE0E5)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
                left: 15, right: 15, top: 15, bottom: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      "Property Details",
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const Spacer(),
                    Container(
                      decoration: const BoxDecoration(
                        color: Color.fromRGBO(235, 245, 255,
                            1), // Background color of the circle
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(
                          5), // Padding around the icon
                      child: Icon(
                        Icons.home_outlined, // Home Icon
                        color: Colors.grey.shade600, // Icon color
                        size: 24, // Icon size
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Property address (web parity: no "Unit"
                      /// label — the address line is the heading).
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context)
                                        .size
                                        .width -
                                    100,
                                child: Text(
                                  formatLeasePropertyLine(
                                    lease.data!.rentalAddress,
                                    lease.data!.rentalUnit,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// Lease status + Active date range (web parity)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_leaseStatusWithType(lease.data!.startDate, lease.data!.endDate, lease.data!.leaseType, lease.data!.isEvicted)}'
                              '${(lease.data!.renewLeases != null && lease.data!.renewLeases!.isNotEmpty) ? " - Renewed" : ""}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(
                                    _leaseStatusWithType(
                                        lease.data!.startDate,
                                        lease.data!.endDate,
                                        lease.data!.leaseType, lease.data!.isEvicted)),
                              ),
                            ),
                            if (lease.data!.startDate !=
                                    null &&
                                lease.data!.endDate !=
                                    null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${dateProvider.formatCurrentDate(lease.data!.startDate!)} – ${_isAtWill(lease.data!.leaseType) ? "At Will" : dateProvider.formatCurrentDate(lease.data!.endDate!)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Rental Owner & Tenants
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Rental Owner
                          Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Rental Owner",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lease.data!.rentalOwnerName ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),

                          const SizedBox(width: 30),

                          /// Tenants
                        ],
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Tenants",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lease.data!.tenantData!
                                .map((tenant) =>
                                    '${tenant.tenantFirstName ?? ''} ${tenant.tenantLastName ?? ''}')
                                .join(', '),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Charges can be added from the Scheduled Charges screen, so on return
  // reload the Balance card (ledger + charges) and re-create the Financial
  // ledger table — the same data a fresh open of the lease would load.
  void _refreshAfterScheduledCharges() {
    if (!mounted) return;
    setState(() {
      _leaseLedgerFuture =
          LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
      _leaseChargesFuture = LeaseRepository().fetchLeaseCharges(widget.leaseId);
      _financialRefreshTick++;
    });
  }

  // The Financial tab's pending-charges link reloads the ledger table itself;
  // this keeps the Balance Overview card above it in step.
  void _reloadBalanceOverview() {
    if (!mounted) return;
    setState(() {
      _leaseLedgerFuture =
          LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
      _leaseChargesFuture = LeaseRepository().fetchLeaseCharges(widget.leaseId);
    });
  }

  /// Web parity (LeaseFinanceBlock): the lease quick actions render on
  /// BOTH the Summary and Financial tabs — web mounts the same shared
  /// component in each. The card shell lives here too, so the two tabs
  /// cannot drift apart visually.
  Widget _leaseQuickActions(LeaseSummary leasesummery) {
    var width = MediaQuery.of(context).size.width;
    return Padding(
      padding:
          const EdgeInsets.only(left: 15, right: 15),
      child: Material(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFDBE0E5)),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
                left: 15,
                right: 15,
                top: 15,
                bottom: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: 10),
                    Text(
                      "Quick Actions",
                      style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Make Payment Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MakePayment(
                                  leaseId: widget.leaseId,
                                  tenantId:
                                      '${leasesummery.data?.tenantId}',
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.grey[300]!),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Make Payment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w500,
                                      color:
                                          Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Configure Recurring Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    RecurringPayment(
                                  leaseData:
                                      leasesummery.data!,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.grey[300]!),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.refresh,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Configure Autopay',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w500,
                                        color: Colors
                                            .grey[700],
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Scheduled Charges Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ScheduledChargeTable(
                                  leaseID: widget.leaseId,
                                  leaseRentalAddress:
                                      _leaseRentalAddress,
                                ),
                              ),
                            );
                            _refreshAfterScheduledCharges();
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.grey[300]!),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Scheduled Charges',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w500,
                                      color:
                                          Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Scheduled Payments Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            // Add your navigation here
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.grey[300]!),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Scheduled Payments',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w500,
                                      color:
                                          Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Add Recurring Charges Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            showRecurringChargeDialog(
                              context: context,
                              leaseId: widget.leaseId,
                              onSuccess: () {
                                setState(() {
                                  _leaseChargesFuture =
                                      LeaseRepository()
                                          .fetchLeaseCharges(
                                              widget
                                                  .leaseId);
                                });
                              },
                            );
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Colors.grey[300]!),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets
                                  .symmetric(
                                  horizontal: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Add Recurring Charges',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight:
                                          FontWeight.w500,
                                      color:
                                          Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                                        
                                        
              const SizedBox(height: 5),
                                      
              ],
            ),
          ),
        ),
      ),
    );
  }

  SummaryPage() {
    final dateProvider = Provider.of<DateProvider>(context);
    // final prefs = await SharedPreferences.getInstance();
    var width = MediaQuery.of(context).size.width;
    return FutureBuilder<LeaseSummary>(
      future: futureLeaseSummary,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SpinKitFadingCircle(
            color: blueColor,
            size: 40.0,
          );
        } else if (snapshot.hasError) {
          return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('No data found.'));
        } else {
          final leasesummery = snapshot.data!;

          // prefs.setDouble('rent', leasesummery.data!.amount.toString());
          //prefs.setString('dueDate', leasesummery.data?.date ?? '');

          return Column(
            children: [
              const SizedBox(
                height: 00,
              ),
              _propertyDetailsCard(leasesummery),
              const SizedBox(
                height: 10,
              ),
              // WEB PARITY (LeaseSummaryTab.jsx): Balance Overview sits with
              // Property Details — side by side on a wide screen, stacked
              // underneath on a phone — and only while the lease reads Active.
              if (determineStatus(snapshot.data?.data?.startDate,
                      snapshot.data?.data?.endDate) ==
                  'Active')
                // Same 15pt side inset as the Property Details card above, so
                // the two cards line up rather than this one running edge to
                // edge.
                Padding(
                  padding: const EdgeInsets.only(left: 15, right: 15),
                  child: _balanceOverviewCard(snapshot.data?.data),
                ),
              if (determineStatus(snapshot.data?.data?.startDate,
                      snapshot.data?.data?.endDate) ==
                  'Active')
                Padding(
                  padding: const EdgeInsets.only(
                      left: 0.0, right: 0.0, bottom: 10.0),
                  child: FutureBuilder<List<dynamic>>(
                    future:
                        Future.wait([_leaseLedgerFuture, _leaseChargesFuture]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container();
                        //   SpinKitFadingCircle(
                        //   color: blueColor,
                        //   size: 40.0,
                        // );
                      } else if (snapshot.hasError) {
                        return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                      } else if (!snapshot.hasData ||
                          snapshot.data!.length < 2) {
                        return const Center(child: Text('No data found'));
                      } else {
                        final leaseLedger = snapshot.data![0] as LeaseLedger?;
                        final leaseCharges = snapshot.data![1] as LeaseCharges?;

                        //final data = leaseLedger.data!.toList();
                        return SingleChildScrollView(
                          child: Column(
                            children: [
                              // Legacy duplicate of Balance Overview — see _showLegacyBalanceSection.
                              if (_showLegacyBalanceSection)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 15, right: 15),
                                child: Material(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFFDBE0E5)),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 15,
                                          right: 15,
                                          top: 15,
                                          bottom: 20),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.attach_money,
                                                color: blueColor,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Balance Overview",
                                                style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 0.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 15),

                                                // Total Balance
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Total Balance",
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${formatCurrency(leaseLedger?.data != null && leaseLedger!.data!.length > 0 ? leaseLedger.data!.first.balance : 0.0)}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(height: 12),

                                                // Monthly Rent
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Monthly Rent",
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${formatCurrency(leasesummery.data?.amount?.toDouble())}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(height: 12),

                                                // Security Deposit
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Security Deposit",
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${formatCurrency(leaseCharges?.data?.securityDeposits?.totalAmount ?? 0.0)}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(height: 12),

                                                // Late Payments
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Late Payments (Last 12 Months)",
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${leaseCharges?.data?.lateRentPayments?.totalEntries ?? 0}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(height: 12),

                                                // Divider
                                                Container(
                                                  height: 1,
                                                  color: Colors.grey[300],
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                ),

                                                const SizedBox(height: 12),

                                                // Due Date
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text(
                                                        "Due Date",
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black,
                                                        ),
                                                      ),
                                                      Text(
                                                        (leasesummery.data?.date == null ||
                                                                leasesummery.data!.date!.trim().isEmpty)
                                                            ? "N/A"
                                                            : dateProvider.formatCurrentDate(leasesummery.data!.date!),
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.orange,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                // Row(
                                                // mainAxisAlignment: MainAxisAlignment.start,
                                                //   crossAxisAlignment: CrossAxisAlignment.start,
                                                //   children: [
                                                //     Expanded(
                                                //       flex:3,
                                                //
                                                //       child: GestureDetector(
                                                //         onTap: () async {
                                                //           final value = await Navigator
                                                //               .push(
                                                //               context,
                                                //               MaterialPageRoute(
                                                //                   builder:
                                                //                       (context) =>
                                                //                       MakePayment(
                                                //                         leaseId: widget.leaseId,
                                                //                         tenantId: ' ${leasesummery.data?.tenantId}',
                                                //                       )));
                                                //           if (value == true) {
                                                //             setState(() {
                                                //               _leaseLedgerFuture =
                                                //                   LeaseRepository()
                                                //                       .fetchLeaseLedger(
                                                //                       leaseId:
                                                //                       widget.leaseId);
                                                //             });
                                                //           }
                                                //         },
                                                //         child: Container(
                                                //           height: 52,
                                                //             padding: EdgeInsets.all(2),
                                                //             decoration: BoxDecoration(
                                                //                 color: blueColor,
                                                //                 border: Border.all(
                                                //                     width: 1,
                                                //                     color: blueColor),
                                                //                 borderRadius:
                                                //                 BorderRadius.circular(
                                                //                     5.0)),
                                                //             child: Center(
                                                //               child: Text(
                                                //                 'Make Payment',
                                                //                 style: TextStyle(
                                                //                     fontSize: MediaQuery.of(
                                                //                         context)
                                                //                         .size
                                                //                         .width <
                                                //                         500
                                                //                         ? 14
                                                //                         : 18,
                                                //                     color: Colors.white,
                                                //                     fontWeight:
                                                //                     FontWeight
                                                //                         .bold),
                                                //               ),
                                                //             )),
                                                //       ),
                                                //     ),
                                                //     SizedBox(width: 10),
                                                //     Expanded(
                                                //       flex:4,
                                                //       child: GestureDetector(
                                                //         onTap: () {
                                                //           setState(() {
                                                //
                                                //             // if (_tabController !=
                                                //             //     null) {
                                                //             //   _tabController!
                                                //             //       .animateTo(1);
                                                //             // }
                                                //             Navigator.of(context).push(
                                                //                 MaterialPageRoute(
                                                //                     builder:
                                                //                         (context) =>
                                                //                         RecurringPayment(
                                                //                           leaseData: leasesummery.data!,
                                                //                         )));
                                                //           });
                                                //         },
                                                //         child: Container(
                                                //           padding: EdgeInsets.symmetric(horizontal: 6),
                                                //             height: MediaQuery.of(context)
                                                //                 .size
                                                //                 .width <
                                                //                 500
                                                //                 ? 55
                                                //                 : 45,
                                                //             decoration: BoxDecoration(
                                                //                 color: Colors.white,
                                                //                 border: Border.all(
                                                //                     width: 1,
                                                //                     color: Colors.grey),
                                                //                 borderRadius:
                                                //                 BorderRadius.circular(
                                                //                     5.0)),
                                                //             child: Row(
                                                //
                                                //               children: [
                                                //                 if (leaseTenants
                                                //                     .any((tenant) =>
                                                //                 tenant
                                                //                     .recurring ==
                                                //                     false))
                                                //                   SizedBox(
                                                //                     width: 12,
                                                //                   ),
                                                //                 Expanded(
                                                //                   child: Text(
                                                //                     'Configure Recurring Payment',
                                                //                     style: TextStyle(
                                                //                         fontSize:
                                                //                         MediaQuery.of(context).size.width <
                                                //                             500
                                                //                             ? 13
                                                //                             : 18,
                                                //                         color:
                                                //                         blueColor,
                                                //                         fontWeight:
                                                //                         FontWeight
                                                //                             .bold),
                                                //                   ),
                                                //                 ),
                                                //                 if (leaseTenants.any(
                                                //                         (tenant) => tenant
                                                //                         .recurring!))
                                                //                   Icon(
                                                //                       CupertinoIcons
                                                //                           .check_mark_circled_solid,
                                                //                       color: Colors
                                                //                           .green),
                                                //               ],
                                                //             )),
                                                //       ),
                                                //     ),
                                                //
                                                //     // Expanded(
                                                //     //   child: Container(
                                                //     //       height: MediaQuery.of(context)
                                                //     //           .size
                                                //     //           .width <
                                                //     //           500
                                                //     //           ? 45
                                                //     //           : 45,
                                                //     //       decoration: BoxDecoration(
                                                //     //           color: Colors.white,
                                                //     //           border: Border.all(
                                                //     //               width: 1,
                                                //     //               color: blueColor
                                                //     //
                                                //     //
                                                //     //           ),
                                                //     //           borderRadius:
                                                //     //           BorderRadius.circular(
                                                //     //               5.0)),
                                                //     //       child: ElevatedButton(
                                                //     //           style: ElevatedButton.styleFrom(
                                                //     //               shape: RoundedRectangleBorder(
                                                //     //                   borderRadius:
                                                //     //                   BorderRadius.circular(5.0)),
                                                //     //               elevation: 0,
                                                //     //               backgroundColor: Colors.white),
                                                //     //           onPressed: () async {
                                                //     //             final value =
                                                //     //             await Navigator.push(
                                                //     //                 context,
                                                //     //                 MaterialPageRoute(
                                                //     //                     builder:
                                                //     //                         (context) =>
                                                //     //                         RecurringPayment(leaseId: widget.leaseId,)
                                                //     //                 ));
                                                //     //             // if (value == true) {
                                                //     //             //   setState(() {
                                                //     //             //     _leaseLedgerFuture =
                                                //     //             //         LeaseRepository()
                                                //     //             //             .fetchLeaseLedger(
                                                //     //             //             widget
                                                //     //             //                 .leaseId);
                                                //     //             //   });
                                                //     //             // }
                                                //     //           },
                                                //     //           child: Text(
                                                //     //             'Configure Recurring Payment',
                                                //     //             style: TextStyle(
                                                //     //                 fontSize: MediaQuery.of(
                                                //     //                     context)
                                                //     //                     .size
                                                //     //                     .width <
                                                //     //                     500
                                                //     //                     ? 14
                                                //     //                     : 18,
                                                //     //                 color: blueColor
                                                //     //
                                                //     //
                                                //     //             ),
                                                //     //           ))),
                                                //     // ),
                                                //   ],
                                                // ),
                                                // SizedBox(height: 10,),
                                                // Row(
                                                //   children: [
                                                //     Row(
                                                //       mainAxisAlignment: MainAxisAlignment.start,
                                                //       children: [
                                                //
                                                //         GestureDetector(
                                                //           onTap: () {
                                                //             setState(() {
                                                //
                                                //               // if (_tabController !=
                                                //               //     null) {
                                                //               //   _tabController!
                                                //               //       .animateTo(1);
                                                //               // }
                                                //               Navigator.of(context).push(
                                                //                   MaterialPageRoute(
                                                //                       builder:
                                                //                           (context) =>
                                                //                           ScheduledChargeTable(leaseID: widget.leaseId,)));
                                                //             });
                                                //           },
                                                //           child: Container(
                                                //               padding: EdgeInsets.symmetric(horizontal: 6),
                                                //               height: MediaQuery.of(context)
                                                //                   .size
                                                //                   .width <
                                                //                   500
                                                //                   ? 55
                                                //                   : 45,
                                                //               decoration: BoxDecoration(
                                                //                   color: Colors.white,
                                                //                   border: Border.all(
                                                //                       width: 1,
                                                //                       color: Colors.grey),
                                                //                   borderRadius:
                                                //                   BorderRadius.circular(
                                                //                       5.0)),
                                                //               child: Row(
                                                //
                                                //                 children: [
                                                //                   if (leaseTenants
                                                //                       .any((tenant) =>
                                                //                   tenant
                                                //                       .recurring ==
                                                //                       false))
                                                //                     SizedBox(
                                                //                       width: 12,
                                                //                     ),
                                                //                   Text(
                                                //                     'Scheduled Charges',
                                                //                     style: TextStyle(
                                                //                         fontSize:
                                                //                         MediaQuery.of(context).size.width <
                                                //                             500
                                                //                             ? 13
                                                //                             : 18,
                                                //                         color:
                                                //                         blueColor,
                                                //                         fontWeight:
                                                //                         FontWeight
                                                //                             .bold),
                                                //                   ),
                                                //
                                                //                 ],
                                                //               )),
                                                //         ),
                                                //         GestureDetector(
                                                //           onTap: () {
                                                //             // Navigator.of(context).push(
                                                //             //     MaterialPageRoute(
                                                //             //         builder: (context) =>
                                                //             //             Scheduled_Payments_table(leaseId: widget.leaseId)
                                                //             //     )
                                                //             // );
                                                //           },
                                                //           child: Container(
                                                //             padding: EdgeInsets.symmetric(horizontal: 6),
                                                //             height: MediaQuery.of(context).size.width < 500 ? 55 : 45,
                                                //             decoration: BoxDecoration(
                                                //                 color: Colors.white,
                                                //                 border: Border.all(
                                                //                     width: 1,
                                                //                     color: Colors.grey
                                                //                 ),
                                                //                 borderRadius: BorderRadius.circular(5.0)
                                                //             ),
                                                //             child: Row(
                                                //               children: [
                                                //                 Text(
                                                //                   'Scheduled Payments',
                                                //                   style: TextStyle(
                                                //                       fontSize: MediaQuery.of(context).size.width < 500 ? 14 : 16,
                                                //                       color: blueColor
                                                //                   ),
                                                //                 ),
                                                //               ],
                                                //             ),
                                                //           ),
                                                //         ),
                                                //
                                                //       ],
                                                //     )
                                                //   ],
                                                // )
                                                // Quick Actions Title
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _leaseQuickActions(leasesummery),

                              // Padding(
                              //   padding:
                              //       const EdgeInsets.only(left: 15, right: 15),
                              //   child: Material(
                              //     borderRadius: BorderRadius.circular(10),
                              //     child: Container(
                              //       decoration: BoxDecoration(
                              //         color: Colors.white,
                              //         borderRadius: BorderRadius.circular(10),
                              //         border: Border.all(color: blueColor),
                              //       ),
                              //       child: Padding(
                              //         padding: const EdgeInsets.only(
                              //             left: 25,
                              //             right: 25,
                              //             top: 20,
                              //             bottom: 30),
                              //         child: Column(
                              //           children: [
                              //             Table(
                              //               children: [
                              //                 TableRow(children: [
                              //                   TableCell(
                              //                       child: Padding(
                              //                     padding: const EdgeInsets.all(
                              //                         12.0),
                              //                     child: Text(
                              //                       'Balance',
                              //                       style: TextStyle(
                              //                           color: const Color(
                              //                               0xFF8A95A8),
                              //                           fontWeight:
                              //                               FontWeight.bold,
                              //                           fontSize: 16),
                              //                     ),
                              //                   )),
                              //                   TableCell(
                              //                       child: Padding(
                              //                     padding:
                              //                         const EdgeInsets.only(
                              //                             top: 12),
                              //                     child: Text(
                              //                       '\$ ${leaseLedger.data!.length > 0 ? leaseLedger.data?.first.balance!.toStringAsFixed(2) : 0.0}',
                              //                       style: TextStyle(
                              //                           fontSize: 15,
                              //                           fontWeight:
                              //                               FontWeight.bold,
                              //                           color: blueColor),
                              //                     ),
                              //                   )),
                              //                 ]),
                              //                 TableRow(children: [
                              //                   TableCell(
                              //                       child: Padding(
                              //                     padding: const EdgeInsets.all(
                              //                         12.0),
                              //                     child: Text(
                              //                       'Rent',
                              //                       style: TextStyle(
                              //                           color: const Color(
                              //                               0xFF8A95A8),
                              //                           fontWeight:
                              //                               FontWeight.bold,
                              //                           fontSize: 16),
                              //                     ),
                              //                   )),
                              //                   TableCell(
                              //                       child: Padding(
                              //                     padding:
                              //                         const EdgeInsets.only(
                              //                             top: 12),
                              //                     child: Text(
                              //                       '\$ ${leasesummery.data?.amount}',
                              //                       style: TextStyle(
                              //                           fontSize: 15,
                              //                           fontWeight:
                              //                               FontWeight.bold,
                              //                           color: blueColor),
                              //                     ),
                              //                   )),
                              //                 ]),
                              //                 TableRow(children: [
                              //                   TableCell(
                              //                       child: Padding(
                              //                     padding: const EdgeInsets.all(
                              //                         12.0),
                              //                     child: Text(
                              //                       'Due date',
                              //                       style: TextStyle(
                              //                           color: const Color(
                              //                               0xFF8A95A8),
                              //                           fontWeight:
                              //                               FontWeight.bold,
                              //                           fontSize: 16),
                              //                     ),
                              //                   )),
                              //                   TableCell(
                              //                       child: Padding(
                              //                     padding:
                              //                         const EdgeInsets.only(
                              //                             top: 12),
                              //                     child: Text(
                              //                       '${dateProvider.formatCurrentDate(leasesummery.data!.date!)}',
                              //                       style: TextStyle(
                              //                           fontSize: 15,
                              //                           fontWeight:
                              //                               FontWeight.bold,
                              //                           color: blueColor),
                              //                     ),
                              //                   )),
                              //                 ]),
                              //               ],
                              //             ),
                              //             SizedBox(
                              //               height: 15,
                              //             ),
                              //             Row(
                              //               children: [
                              //                 Container(
                              //                     height: MediaQuery.of(context)
                              //                                 .size
                              //                                 .width <
                              //                             500
                              //                         ? 75
                              //                         : 45,
                              //                     decoration: BoxDecoration(
                              //                         color: Colors.white,
                              //                         border: Border.all(
                              //                             width: 1,
                              //                             color: blueColor),
                              //                         borderRadius:
                              //                             BorderRadius.circular(
                              //                                 5.0)),
                              //                     child: ElevatedButton(
                              //                         style: ElevatedButton.styleFrom(
                              //                             shape: RoundedRectangleBorder(
                              //                                 borderRadius:
                              //                                     BorderRadius
                              //                                         .circular(
                              //                                             5.0)),
                              //                             elevation: 0,
                              //                             backgroundColor:
                              //                                 Colors.white),
                              //                         onPressed: () async {
                              //                           final value = await Navigator
                              //                               .push(
                              //                                   context,
                              //                                   MaterialPageRoute(
                              //                                       builder:
                              //                                           (context) =>
                              //                                               MakePayment(
                              //                                                 leaseId: widget.leaseId,
                              //                                                 tenantId: ' ${leasesummery.data?.tenantId}',
                              //                                               )));
                              //                           if (value == true) {
                              //                             setState(() {
                              //                               _leaseLedgerFuture =
                              //                                   LeaseRepository()
                              //                                       .fetchLeaseLedger(
                              //                                           leaseId:
                              //                                               widget.leaseId);
                              //                             });
                              //                           }
                              //                         },
                              //                         child: Text(
                              //                           'Make Payment',
                              //                           style: TextStyle(
                              //                               fontSize: MediaQuery.of(
                              //                                               context)
                              //                                           .size
                              //                                           .width <
                              //                                       500
                              //                                   ? 15
                              //                                   : 18,
                              //                               color: blueColor,
                              //                               fontWeight:
                              //                                   FontWeight
                              //                                       .bold),
                              //                         ))),
                              //                 SizedBox(width: 15),
                              //                 Expanded(
                              //                   child: Container(
                              //                       height: MediaQuery.of(context)
                              //                                   .size
                              //                                   .width <
                              //                               500
                              //                           ? 75
                              //                           : 45,
                              //                       decoration: BoxDecoration(
                              //                           color: Colors.white,
                              //                           border: Border.all(
                              //                               width: 1,
                              //                               color: blueColor),
                              //                           borderRadius:
                              //                               BorderRadius.circular(
                              //                                   5.0)),
                              //                       child: ElevatedButton(
                              //                           style: ElevatedButton.styleFrom(
                              //                               shape: RoundedRectangleBorder(
                              //                                   borderRadius:
                              //                                       BorderRadius
                              //                                           .circular(
                              //                                               5.0)),
                              //                               elevation: 0,
                              //                               backgroundColor:
                              //                                   Colors.white),
                              //                           onPressed: () {
                              //                             setState(() {
                              //
                              //                               // if (_tabController !=
                              //                               //     null) {
                              //                               //   _tabController!
                              //                               //       .animateTo(1);
                              //                               // }
                              //                               Navigator.of(context).push(
                              //                                   MaterialPageRoute(
                              //                                       builder:
                              //                                           (context) =>
                              //                                               RecurringPayment(
                              //                                                 leaseData: leasesummery.data!,
                              //                                               )));
                              //                             });
                              //                           },
                              //                           child: Row(
                              //                             children: [
                              //                               if (leaseTenants
                              //                                   .any((tenant) =>
                              //                                       tenant
                              //                                           .recurring ==
                              //                                       false))
                              //                                 SizedBox(
                              //                                   width: 12,
                              //                                 ),
                              //                               Expanded(
                              //                                 child: Text(
                              //                                   'Configure Recurring Payment',
                              //                                   style: TextStyle(
                              //                                       fontSize:
                              //                                           MediaQuery.of(context).size.width <
                              //                                                   500
                              //                                               ? 13
                              //                                               : 18,
                              //                                       color:
                              //                                           blueColor,
                              //                                       fontWeight:
                              //                                           FontWeight
                              //                                               .bold),
                              //                                 ),
                              //                               ),
                              //                               if (leaseTenants.any(
                              //                                   (tenant) => tenant
                              //                                       .recurring!))
                              //                                 Icon(
                              //                                     CupertinoIcons
                              //                                         .check_mark_circled_solid,
                              //                                     color: Colors
                              //                                         .green),
                              //                             ],
                              //                           ))),
                              //                 ),
                              //
                              //                 // Expanded(
                              //                 //   child: Container(
                              //                 //       height: MediaQuery.of(context)
                              //                 //           .size
                              //                 //           .width <
                              //                 //           500
                              //                 //           ? 45
                              //                 //           : 45,
                              //                 //       decoration: BoxDecoration(
                              //                 //           color: Colors.white,
                              //                 //           border: Border.all(
                              //                 //               width: 1,
                              //                 //               color: blueColor
                              //                 //
                              //                 //
                              //                 //           ),
                              //                 //           borderRadius:
                              //                 //           BorderRadius.circular(
                              //                 //               5.0)),
                              //                 //       child: ElevatedButton(
                              //                 //           style: ElevatedButton.styleFrom(
                              //                 //               shape: RoundedRectangleBorder(
                              //                 //                   borderRadius:
                              //                 //                   BorderRadius.circular(5.0)),
                              //                 //               elevation: 0,
                              //                 //               backgroundColor: Colors.white),
                              //                 //           onPressed: () async {
                              //                 //             final value =
                              //                 //             await Navigator.push(
                              //                 //                 context,
                              //                 //                 MaterialPageRoute(
                              //                 //                     builder:
                              //                 //                         (context) =>
                              //                 //                         RecurringPayment(leaseId: widget.leaseId,)
                              //                 //                 ));
                              //                 //             // if (value == true) {
                              //                 //             //   setState(() {
                              //                 //             //     _leaseLedgerFuture =
                              //                 //             //         LeaseRepository()
                              //                 //             //             .fetchLeaseLedger(
                              //                 //             //             widget
                              //                 //             //                 .leaseId);
                              //                 //             //   });
                              //                 //             // }
                              //                 //           },
                              //                 //           child: Text(
                              //                 //             'Configure Recurring Payment',
                              //                 //             style: TextStyle(
                              //                 //                 fontSize: MediaQuery.of(
                              //                 //                     context)
                              //                 //                     .size
                              //                 //                     .width <
                              //                 //                     500
                              //                 //                     ? 14
                              //                 //                     : 18,
                              //                 //                 color: blueColor
                              //                 //
                              //                 //
                              //                 //             ),
                              //                 //           ))),
                              //                 // ),
                              //               ],
                              //             ),
                              //           ],
                              //         ),
                              //       ),
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              
              
              Padding(
                padding: const EdgeInsets.only(
                    left: 15, right: 15, top: 8, bottom: 25),
                child: Material(
                  //elevation: 6,
                  //borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      // border: Border.all(
                      //     color:blueColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 2, right: 2, top: 5, bottom: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Balance Overview now renders with Property Details
                          // above (web parity), so it is not repeated here.
                          if (MediaQuery.of(context).size.width < 500)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 2,
                                ),
                                Text(
                                  "Lease Details",
                                  style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                // Show Expanded only when renew button is visible, otherwise use Spacer to push evict to end
                                if (leasesummery.data!.is_renewing ?? true)
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    Evict_tenant(
                                                      leaseId: widget.leaseId,
                                                      lease: leasesummery,
                                                      startdate: leasesummery
                                                          .data!.startDate,
                                                      enddate: leasesummery
                                                          .data!.endDate,
                                                      leasetype: leasesummery
                                                          .data!.leaseType,
                                                      rentamount: leasesummery
                                                          .data!.amount
                                                          .toString(),
                                                    )));
                                      },
                                      child: Container(
                                          height: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 35
                                              : 45,
                                          decoration: BoxDecoration(
                                              color: blueColor,
                                              borderRadius:
                                                  BorderRadius.circular(5.0)),
                                          child: Center(
                                            child: Text(
                                              'Evict Tenants',
                                              style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 14
                                                          : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                          )),
                                    ),
                                  )
                                else ...[
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  Evict_tenant(
                                                    leaseId: widget.leaseId,
                                                    lease: leasesummery,
                                                    startdate: leasesummery
                                                        .data!.startDate,
                                                    enddate: leasesummery
                                                        .data!.endDate,
                                                    leasetype: leasesummery
                                                        .data!.leaseType,
                                                    rentamount: leasesummery
                                                        .data!.amount
                                                        .toString(),
                                                  )));
                                    },
                                    child: Container(
                                        height:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 35
                                                : 45,
                                        width:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 120
                                                : 165,
                                        decoration: BoxDecoration(
                                            color: blueColor,
                                            borderRadius:
                                                BorderRadius.circular(5.0)),
                                        child: Center(
                                          child: Text(
                                            'Evict Tenants',
                                            style: TextStyle(
                                                fontSize: MediaQuery.of(context)
                                                            .size
                                                            .width <
                                                        500
                                                    ? 14
                                                    : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                        )),
                                  ),
                                ],
                                if (leasesummery.data!.is_renewing ?? true) ...[
                                  const SizedBox(
                                    width: 5,
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) =>
                                                    Renewlease(
                                                      leaseId: widget.leaseId,
                                                      lease: leasesummery,
                                                      startdate: leasesummery
                                                          .data!.startDate,
                                                      enddate: leasesummery
                                                          .data!.endDate,
                                                      leasetype: leasesummery
                                                          .data!.leaseType,
                                                      rentamount: leasesummery
                                                          .data!.amount
                                                          .toString(),
                                                    )));
                                      },
                                      child: Container(
                                          height: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 35
                                              : 45,
                                          decoration: BoxDecoration(
                                              color: blueColor,
                                              borderRadius:
                                                  BorderRadius.circular(5.0)),
                                          child: Center(
                                            child: Text(
                                              'Renew Lease',
                                              style: TextStyle(
                                                  fontSize:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              500
                                                          ? 14
                                                          : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white),
                                            ),
                                          )),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          if (MediaQuery.of(context).size.width < 500)
                            const SizedBox(
                              height: 10,
                            ),
                          if (MediaQuery.of(context).size.width < 500)
                            Column(
                              children: [
                                // Column-header strip removed: each field now
                                // carries its own label inside the expanded
                                // panel, so a shared header no longer applies.
                                StatefulBuilder(
                                  builder: (context, setRowState) {
                                    return Container(
                                      // decoration: BoxDecoration(
                                      //     // color: index %2 != 0 ? Colors.white : blueColor.withOpacity(0.09),
                                      //     border: Border.all(
                                      //         color: const Color.fromRGBO(
                                      //             152, 162, 179, .5))),
                                      // // decoration: BoxDecoration(
                                      // //   border: Border.all(color: blueColor),
                                      // // ),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: const Color(0xFFDBE0E5)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
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
                                                      setRowState(() {
                                                        isExpanded =
                                                            !isExpanded;
                                                      });
                                                    },
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              left: 5),
                                                      padding: !isExpanded
                                                          ? const EdgeInsets
                                                              .only(bottom: 10)
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
                                                  // Collapsed row shows only the
                                                  // address; status/type/dates
                                                  // move into the expanded panel
                                                  // where they have full width.
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 5.0),
                                                      child: Text(
                                                        '${snapshot.data!.data!.rentalAddress}',
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width *
                                                            .02,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (isExpanded)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 20),
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
                                                          size: 50,
                                                          color: Colors
                                                              .transparent,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: <Widget>[
                                                              // STATUS + TYPE side by side
                                                              Row(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Expanded(
                                                                    // WEB PARITY (LeaseTermsTable.jsx):
                                                                    // `currentStatus = current?.status
                                                                    // || fallbackStatus` — the status
                                                                    // describes the TERM shown in this
                                                                    // row, not the lease overall. A
                                                                    // renewed at-will lease reads
                                                                    // Active at lease level while the
                                                                    // term listed here has ended.
                                                                    child: _leaseStatusField(
                                                                        _currentTerm?.status ??
                                                                            '${determineStatus(snapshot.data!.data!.startDate, snapshot.data!.data!.endDate)}'),
                                                                  ),
                                                                  const SizedBox(
                                                                      width: 12),
                                                                  Expanded(
                                                                    child: _leaseField(
                                                                      'Type',
                                                                      // Same source as the rest of the
                                                                      // row: the term's own type when
                                                                      // history exists.
                                                                      _currentTerm?.leaseType ??
                                                                          '${snapshot.data!.data!.leaseType}',
                                                                      // Web parity: flag a term the
                                                                      // server estimated from rent
                                                                      // history rather than recorded.
                                                                      trailing: _currentTerm
                                                                                  ?.isInferred ==
                                                                              true
                                                                          ? _inferredBadge()
                                                                          : null,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                  height: 14),
                                                              _leaseField(
                                                                'Start – End',
                                                                _leaseTermRange(
                                                                  snapshot.data!.data!.startDate,
                                                                  snapshot.data!.data!.endDate,
                                                                  dateProvider,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 14),
                                                              _leaseField(
                                                                'Rent',
                                                                // WEB PARITY (LeaseTermsTable.jsx): rent comes from the
                                                                // CURRENT TERM, falling back to the lease record — an
                                                                // inferred term carries the real rent where the lease
                                                                // row itself may hold none.
                                                                formatCurrency(
                                                                  (_currentTerm != null
                                                                          ? _currentTerm!.rent
                                                                          : snapshot.data!.data!.amount)
                                                                      ?.toDouble() ??
                                                                      0.0,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          if (MediaQuery.of(context).size.width > 500)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                ),
                                Text(
                                  "Lease Details",
                                  style: TextStyle(
                                      color: blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                ),
                              ],
                            ),
                          const SizedBox(
                            height: 10,
                          ),
                          if (MediaQuery.of(context).size.width > 500)
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Expanded(
                                  child: Container(
                                    child: DataTable(
                                      dataRowHeight: 50,
                                      headingRowHeight: 50,
                                      border: TableBorder.all(
                                        width: 1,
                                        color: blueColor,
                                      ),
                                      columns: [
                                        const DataColumn(
                                          label: Text('Status'),
                                        ),
                                        const DataColumn(
                                          label: Text('Start - End'),
                                        ),
                                        const DataColumn(
                                          label: Text('Property'),
                                        ),
                                        const DataColumn(
                                          label: Text('Type'),
                                        ),
                                        const DataColumn(
                                          label: Text('Rent'),
                                        ),
                                      ],
                                      rows: [
                                        DataRow(cells: <DataCell>[
                                          DataCell(Text(
                                              '${determineStatus(snapshot.data!.data!.startDate, snapshot.data!.data!.endDate)}')),
                                          DataCell(Text(
                                              ' ${snapshot.data!.data!.startDate} to ${snapshot.data!.data!.endDate}')),
                                          DataCell(Text(
                                              '${snapshot.data!.data!.rentalAddress}')),
                                          DataCell(Text(
                                              '${snapshot.data!.data!.leaseType}')),
                                          DataCell(Text(
                                              '${formatCurrency(snapshot.data!.data!.amount?.toDouble() ?? 0.0)}')),
                                        ]),
                                        // Add more rows as needed
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // const SizedBox(
                          //   height: 10,
                          // ),
                          // if (MediaQuery.of(context).size.width < 500)
                          //   if (leasesummery.data?.entry != null &&
                          //       leasesummery.data!.entry!.length > 0)
                          //     Column(
                          //       children: [
                          //         Row(
                          //           children: [
                          //             const SizedBox(
                          //               width: 2,
                          //             ),
                          //             Text(
                          //               "Recuring Charges",
                          //               style: TextStyle(
                          //                   color: blueColor,
                          //                   fontWeight: FontWeight.bold,
                          //                   fontSize: 16),
                          //             ),
                          //           ],
                          //         ),
                          //         const SizedBox(
                          //           height: 10,
                          //         ),
                          //         Container(
                          //           // decoration: BoxDecoration(
                          //           //
                          //           //   color: blueColor,
                          //           //   borderRadius: const BorderRadius.only(
                          //           //     topLeft: Radius.circular(13),
                          //           //     topRight: Radius.circular(13),
                          //           //   ),
                          //           //
                          //           // ),
                          //           decoration: BoxDecoration(
                          //               color: const Color(0xFFF4F8FF),
                          //               borderRadius: BorderRadius.circular(10),
                          //               border: Border.all(
                          //                   color: const Color(0xFFDBE0E5))),
                          //           child: ListTile(
                          //             contentPadding: EdgeInsets.zero,
                          //             title: Row(
                          //               mainAxisAlignment:
                          //                   MainAxisAlignment.start,
                          //               children: <Widget>[
                          //                 Expanded(
                          //                   flex: 3,
                          //                   child: InkWell(
                          //                     onTap: () {},
                          //                     child: Row(
                          //                       children: [
                          //                         width < 400
                          //                             ? Padding(
                          //                                 padding:
                          //                                     EdgeInsets.only(
                          //                                         left: 20.0),
                          //                                 child: Text(
                          //                                   "Date",
                          //                                   style: TextStyle(
                          //                                       color:
                          //                                           blueColor,
                          //                                       fontWeight:
                          //                                           FontWeight
                          //                                               .bold,
                          //                                       fontSize: 14),
                          //                                   textAlign: TextAlign
                          //                                       .center,
                          //                                 ),
                          //                               )
                          //                             : Text("     Date",
                          //                                 style: TextStyle(
                          //                                     color: blueColor,
                          //                                     fontWeight:
                          //                                         FontWeight
                          //                                             .bold,
                          //                                     fontSize: 14),
                          //                                 textAlign:
                          //                                     TextAlign.center),
                          //                         // Text("Property", style: TextStyle(color: Colors.white)),
                          //                       ],
                          //                     ),
                          //                   ),
                          //                 ),
                          //                 Expanded(
                          //                   flex: 2,
                          //                   child: InkWell(
                          //                     onTap: () {},
                          //                     child: Row(
                          //                       children: [
                          //                         Padding(
                          //                           padding: EdgeInsets.only(
                          //                               left: 0.0),
                          //                           child: Text("Acount",
                          //                               style: TextStyle(
                          //                                   color: blueColor,
                          //                                   fontWeight:
                          //                                       FontWeight.bold,
                          //                                   fontSize: 14)),
                          //                         ),
                          //                         SizedBox(width: 5),
                          //                       ],
                          //                     ),
                          //                   ),
                          //                 ),
                          //                 Expanded(
                          //                   flex: 2,
                          //                   child: InkWell(
                          //                     onTap: () {},
                          //                     child: Row(
                          //                       children: [
                          //                         Text(
                          //                           "Amount",
                          //                           style: TextStyle(
                          //                               color: blueColor,
                          //                               fontWeight:
                          //                                   FontWeight.bold,
                          //                               fontSize: 14),
                          //                           textAlign: TextAlign.center,
                          //                         ),
                          //                         SizedBox(width: 5),
                          //                       ],
                          //                     ),
                          //                   ),
                          //                 ),
                          //               ],
                          //             ),
                          //           ),
                          //         ),
                          //         Container(
                          //           // decoration: BoxDecoration(
                          //           //     // color: index %2 != 0 ? Colors.white : blueColor.withOpacity(0.09),
                          //           //     border: Border.all(
                          //           //         color: const Color.fromRGBO(
                          //           //             152, 162, 179, .5))),
                          //           // decoration: BoxDecoration(
                          //           //   border: Border.all(color: blueColor),
                          //           // ),
                          //           child: Column(
                          //             children: snapshot.data!.data!.entry!
                          //                 .asMap()
                          //                 .entries
                          //                 .map((entry) {
                          //               int index = entry.key;
                          //               RecurringEntry lease = entry.value;
                          //               //return CustomExpansionTile(data: Propertytype, index: index);
                          //               return StatefulBuilder(
                          //                 builder: (context, setRowState) {
                          //                   bool isExpandedLocal =
                          //                       recurringChargeExpandedIndex ==
                          //                           index;
                          //                   return Container(
                          //                     margin:
                          //                         const EdgeInsets.symmetric(
                          //                             vertical: 6),
                          //                     decoration: BoxDecoration(
                          //                       color: index % 2 != 0
                          //                           ? const Color(0xFFF4F8FF)
                          //                           : Colors.white,
                          //                       border: Border.all(
                          //                           color: const Color(
                          //                               0xFFDBE0E5)),
                          //                       borderRadius:
                          //                           BorderRadius.circular(10),
                          //                     ),
                          //                     child: Column(
                          //                       children: <Widget>[
                          //                         ListTile(
                          //                           contentPadding:
                          //                               EdgeInsets.zero,
                          //                           title: Padding(
                          //                             padding:
                          //                                 const EdgeInsets.all(
                          //                                     2.0),
                          //                             child: Row(
                          //                               mainAxisAlignment:
                          //                                   MainAxisAlignment
                          //                                       .start,
                          //                               crossAxisAlignment:
                          //                                   CrossAxisAlignment
                          //                                       .center,
                          //                               children: <Widget>[
                          //                                 InkWell(
                          //                                   onTap: () {
                          //                                     setRowState(() {
                          //                                       if (recurringChargeExpandedIndex ==
                          //                                           index) {
                          //                                         recurringChargeExpandedIndex =
                          //                                             null;
                          //                                       } else {
                          //                                         recurringChargeExpandedIndex =
                          //                                             index;
                          //                                       }
                          //                                     });
                          //                                   },
                          //                                   child: Container(
                          //                                     margin:
                          //                                         const EdgeInsets
                          //                                             .only(
                          //                                             left: 5),
                          //                                     padding: !isExpandedLocal
                          //                                         ? const EdgeInsets
                          //                                             .only(
                          //                                             bottom:
                          //                                                 10)
                          //                                         : const EdgeInsets
                          //                                             .only(
                          //                                             top: 10),
                          //                                     child: FaIcon(
                          //                                       isExpandedLocal
                          //                                           ? FontAwesomeIcons
                          //                                               .sortUp
                          //                                           : FontAwesomeIcons
                          //                                               .sortDown,
                          //                                       size: 20,
                          //                                       color:
                          //                                           blueColor,
                          //                                     ),
                          //                                   ),
                          //                                 ),
                          //                                 Expanded(
                          //                                   flex: 4,
                          //                                   child: InkWell(
                          //                                     onTap: () {
                          //                                       setRowState(() {
                          //                                         if (recurringChargeExpandedIndex ==
                          //                                             index) {
                          //                                           recurringChargeExpandedIndex =
                          //                                               null;
                          //                                         } else {
                          //                                           recurringChargeExpandedIndex =
                          //                                               index;
                          //                                         }
                          //                                       });
                          //                                     },
                          //                                     child: Padding(
                          //                                       padding:
                          //                                           const EdgeInsets
                          //                                               .only(
                          //                                               left:
                          //                                                   5.0),
                          //                                       child: Text(
                          //                                         '${dateProvider.formatCurrentDate(lease.date!)}',
                          //                                         style:
                          //                                             TextStyle(
                          //                                           color:
                          //                                               blueColor,
                          //                                           fontWeight:
                          //                                               FontWeight
                          //                                                   .bold,
                          //                                           fontSize:
                          //                                               13,
                          //                                         ),
                          //                                       ),
                          //                                     ),
                          //                                   ),
                          //                                 ),
                          //                                 SizedBox(
                          //                                   width: MediaQuery.of(
                          //                                               context)
                          //                                           .size
                          //                                           .width *
                          //                                       .08,
                          //                                 ),
                          //                                 Expanded(
                          //                                   flex: 4,
                          //                                   child: Text(
                          //                                     '${lease.account}',
                          //                                     style: TextStyle(
                          //                                       color:
                          //                                           blueColor,
                          //                                       fontWeight:
                          //                                           FontWeight
                          //                                               .bold,
                          //                                       fontSize: 12,
                          //                                     ),
                          //                                   ),
                          //                                 ),
                          //                                 SizedBox(
                          //                                   width: MediaQuery.of(
                          //                                               context)
                          //                                           .size
                          //                                           .width *
                          //                                       .03,
                          //                                 ),
                          //                                 Expanded(
                          //                                   flex: 4,
                          //                                   child: Text(
                          //                                     '${formatCurrency(lease.amount?.toDouble() ?? 0.0)}',
                          //                                     style: TextStyle(
                          //                                       color:
                          //                                           blueColor,
                          //                                       fontWeight:
                          //                                           FontWeight
                          //                                               .bold,
                          //                                       fontSize: 12,
                          //                                     ),
                          //                                   ),
                          //                                 ),
                          //                                 SizedBox(
                          //                                   width: MediaQuery.of(
                          //                                               context)
                          //                                           .size
                          //                                           .width *
                          //                                       .02,
                          //                                 ),
                          //                               ],
                          //                             ),
                          //                           ),
                          //                         ),
                          //                         if (isExpandedLocal)
                          //                           Container(
                          //                             margin:
                          //                                 const EdgeInsets.only(
                          //                                     bottom: 20),
                          //                             child:
                          //                                 SingleChildScrollView(
                          //                               child: Column(
                          //                                 children: [
                          //                                   Row(
                          //                                     mainAxisAlignment:
                          //                                         MainAxisAlignment
                          //                                             .start,
                          //                                     children: [
                          //                                       FaIcon(
                          //                                         isExpandedLocal
                          //                                             ? FontAwesomeIcons
                          //                                                 .sortUp
                          //                                             : FontAwesomeIcons
                          //                                                 .sortDown,
                          //                                         size: 50,
                          //                                         color: Colors
                          //                                             .transparent,
                          //                                       ),
                          //                                       Expanded(
                          //                                         child: Column(
                          //                                           crossAxisAlignment:
                          //                                               CrossAxisAlignment
                          //                                                   .start,
                          //                                           children: <Widget>[
                          //                                             Text.rich(
                          //                                               TextSpan(
                          //                                                 children: [
                          //                                                   TextSpan(
                          //                                                     text: 'Memo :- ',
                          //                                                     style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                          //                                                   ),
                          //                                                   TextSpan(
                          //                                                     text: '${lease.memo}',
                          //                                                     style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                          //                                                   ),
                          //                                                 ],
                          //                                               ),
                          //                                             ),
                          //                                           ],
                          //                                         ),
                          //                                       ),
                          //                                     ],
                          //                                   ),
                          //                                 ],
                          //                               ),
                          //                             ),
                          //                           ),
                          //                         //SizedBox(height: 13,),
                          //                       ],
                          //                     ),
                          //                   );
                          //                 },
                          //               );
                          //             }).toList(),
                          //           ),
                          //         ),
                          //       ],
                          //     ),
                          
                          const SizedBox(
                            height: 10,
                          ),
                          if (MediaQuery.of(context).size.width < 500)
                            if (_showRenewableHistory &&
                                leasesummery.data?.renewLeases != null &&
                                leasesummery.data!.renewLeases!.length > 0)
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 2,
                                      ),
                                      Text(
                                        "Renewable History",
                                        style: TextStyle(
                                            color: blueColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF4F8FF),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFDBE0E5))),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            flex: 3,
                                            child: InkWell(
                                              onTap: () {},
                                              child: Row(
                                                children: [
                                                  width < 400
                                                      ? Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  left: 20.0),
                                                          child: Text(
                                                            "Property",
                                                            style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        )
                                                      : Text("     Property",
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 14),
                                                          textAlign:
                                                              TextAlign.center),
                                                  // Text("Property", style: TextStyle(color: Colors.white)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: InkWell(
                                              onTap: () {},
                                              child: Row(
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 0.0),
                                                    child: Text("Status",
                                                        style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 14)),
                                                  ),
                                                  SizedBox(width: 5),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: InkWell(
                                              onTap: () {},
                                              child: Row(
                                                children: [
                                                  Text(
                                                    "Type",
                                                    style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  SizedBox(width: 5),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    // decoration: BoxDecoration(
                                    //     // color: index %2 != 0 ? Colors.white : blueColor.withOpacity(0.09),
                                    //     border: Border.all(
                                    //         color: const Color.fromRGBO(
                                    //             152, 162, 179, .5))),
                                    // decoration: BoxDecoration(
                                    //   border: Border.all(color: blueColor),
                                    // ),
                                    child: Column(
                                      children: snapshot.data!.data!.renewLeases!
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        int index = entry.key;
                                        RenewLeases lease = entry.value;
                                        //return CustomExpansionTile(data: Propertytype, index: index);
                                        return StatefulBuilder(
                                          builder: (context, setRowState) {
                                            bool isExpandedLocal =
                                                renewableHistoryExpandedIndex ==
                                                    index;
                                            return Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                color: index % 2 != 0
                                                    ? const Color(0xFFF4F8FF)
                                                    : Colors.white,
                                                border: Border.all(
                                                    color: const Color(
                                                        0xFFDBE0E5)),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),

                                              // decoration: BoxDecoration(
                                              //   border: Border.all(color: blueColor),
                                              // ),
                                              child: Column(
                                                children: <Widget>[
                                                  ListTile(
                                                    contentPadding:
                                                        EdgeInsets.zero,
                                                    title: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              2.0),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: <Widget>[
                                                          InkWell(
                                                            onTap: () {
                                                              setRowState(() {
                                                                if (renewableHistoryExpandedIndex ==
                                                                    index) {
                                                                  renewableHistoryExpandedIndex =
                                                                      null;
                                                                } else {
                                                                  renewableHistoryExpandedIndex =
                                                                      index;
                                                                }
                                                              });
                                                            },
                                                            child: Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5),
                                                              padding: !isExpandedLocal
                                                                  ? const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          10)
                                                                  : const EdgeInsets
                                                                      .only(
                                                                      top: 10),
                                                              child: FaIcon(
                                                                isExpandedLocal
                                                                    ? FontAwesomeIcons
                                                                        .sortUp
                                                                    : FontAwesomeIcons
                                                                        .sortDown,
                                                                size: 20,
                                                                color:
                                                                    blueColor,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 5,
                                                            child: InkWell(
                                                              onTap: () {
                                                                setRowState(() {
                                                                  if (renewableHistoryExpandedIndex ==
                                                                      index) {
                                                                    renewableHistoryExpandedIndex =
                                                                        null;
                                                                  } else {
                                                                    renewableHistoryExpandedIndex =
                                                                        index;
                                                                  }
                                                                });
                                                              },
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            5.0),
                                                                child: Text(
                                                                  '${snapshot.data!.data!.rentalAddress}',
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        blueColor,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    fontSize:
                                                                        13,
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
                                                                .06,
                                                          ),
                                                          Expanded(
                                                            flex: 4,
                                                            child: Text(
                                                              '${determineStatusrenew(lease.startDate ?? "", lease.endDate ?? "", lease.isrenewed ?? false)}',
                                                              style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .01,
                                                          ),
                                                          Expanded(
                                                            flex: 4,
                                                            child: Text(
                                                              '${lease.leaseType}',
                                                              style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(
                                                            width: MediaQuery.of(
                                                                        context)
                                                                    .size
                                                                    .width *
                                                                .02,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (isExpandedLocal)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              bottom: 20),
                                                      child:
                                                          SingleChildScrollView(
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .start,
                                                              children: [
                                                                FaIcon(
                                                                  isExpandedLocal
                                                                      ? FontAwesomeIcons
                                                                          .sortUp
                                                                      : FontAwesomeIcons
                                                                          .sortDown,
                                                                  size: 50,
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
                                                                              text: 'Start - End   ',
                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                                                                            ),
                                                                            TextSpan(
                                                                              text: '${dateProvider.formatCurrentDate('${lease.startDate}')} to ${dateProvider.formatCurrentDate('${lease.endDate}')}',
                                                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            4,
                                                                      ),
                                                                      Text.rich(
                                                                        TextSpan(
                                                                          children: [
                                                                            TextSpan(
                                                                              text: 'Amount : ',
                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                                                                            ),
                                                                            TextSpan(
                                                                              text: '${formatCurrency(lease.amount ?? 0.0)}',
                                                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
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
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                          SizedBox(
                            height: 0,
                          ),
                          // Late Fees Table — commented out for web parity.
                          // Web's lease detail page has no late-fee list: it shows a
                          // single "Late Payments (Last 12 Months)" count in the
                          // Financial Summary card and nothing more. Restore this block
                          // if the itemised fees are wanted back on mobile.
//                          // Late Fees Table
//                          FutureBuilder<List<Map<String, dynamic>>>(
//                            future: _lateFeesFuture,
//                            builder: (context, lateFeeSnapshot) {
//                              if (lateFeeSnapshot.connectionState ==
//                                  ConnectionState.waiting) {
//                                return const SizedBox(
//                                  height: 50,
//                                  child: Center(
//                                    child: CircularProgressIndicator(),
//                                  ),
//                                );
//                              } else if (lateFeeSnapshot.hasError) {
//                                return Padding(
//                                  padding: const EdgeInsets.all(8.0),
//                                  child: Text(
//                                    'Error loading late fees: ${lateFeeSnapshot.error}',
//                                    style: const TextStyle(color: Colors.red),
//                                  ),
//                                );
//                              } else if (!lateFeeSnapshot.hasData ||
//                                  lateFeeSnapshot.data!.isEmpty) {
//                                return const SizedBox.shrink();
//                              } else {
//                                final lateFees = lateFeeSnapshot.data!;
//                                return RepaintBoundary(
//                                  child: Column(
//                                    children: [
//                                      Row(
//                                        children: [
//                                          const SizedBox(
//                                            width: 2,
//                                          ),
//                                          Text(
//                                            "Late Fees",
//                                            style: TextStyle(
//                                                color: blueColor,
//                                                fontWeight: FontWeight.bold,
//                                                fontSize: 16),
//                                          ),
//                                          Spacer(),
//                                          Text(
//                                            "Late Fee Count : ${lateFees.length}",
//                                            style: TextStyle(
//                                                color: blueColor,
//                                                fontWeight: FontWeight.bold,
//                                                fontSize: 13),
//                                          ),
//                                        ],
//                                      ),
//                                      const SizedBox(
//                                        height: 10,
//                                      ),
//                                      Container(
//                                        decoration: BoxDecoration(
//                                            color: const Color(0xFFF4F8FF),
//                                            borderRadius:
//                                                BorderRadius.circular(10),
//                                            border: Border.all(
//                                                color:
//                                                    const Color(0xFFDBE0E5))),
//                                        child: ListTile(
//                                          contentPadding: EdgeInsets.zero,
//                                          title: Row(
//                                            mainAxisAlignment:
//                                                MainAxisAlignment.start,
//                                            children: <Widget>[
//                                              Expanded(
//                                                flex: 3,
//                                                child: InkWell(
//                                                  onTap: () {},
//                                                  child: Row(
//                                                    children: [
//                                                      width < 400
//                                                          ? Padding(
//                                                              padding: EdgeInsets
//                                                                  .only(
//                                                                      left:
//                                                                          20.0),
//                                                              child: Text(
//                                                                "Date",
//                                                                style: TextStyle(
//                                                                    color:
//                                                                        blueColor,
//                                                                    fontWeight:
//                                                                        FontWeight
//                                                                            .bold,
//                                                                    fontSize:
//                                                                        14),
//                                                                textAlign:
//                                                                    TextAlign
//                                                                        .center,
//                                                              ),
//                                                            )
//                                                          : Text("     Date",
//                                                              style: TextStyle(
//                                                                  color:
//                                                                      blueColor,
//                                                                  fontWeight:
//                                                                      FontWeight
//                                                                          .bold,
//                                                                  fontSize: 14),
//                                                              textAlign:
//                                                                  TextAlign
//                                                                      .center),
//                                                    ],
//                                                  ),
//                                                ),
//                                              ),
//                                              Expanded(
//                                                flex: 2,
//                                                child: InkWell(
//                                                  onTap: () {},
//                                                  child: Row(
//                                                    children: [
//                                                      Padding(
//                                                        padding:
//                                                            EdgeInsets.only(
//                                                                left: 0.0),
//                                                        child: Text("Amount",
//                                                            style: TextStyle(
//                                                                color:
//                                                                    blueColor,
//                                                                fontWeight:
//                                                                    FontWeight
//                                                                        .bold,
//                                                                fontSize: 14)),
//                                                      ),
//                                                      SizedBox(width: 5),
//                                                    ],
//                                                  ),
//                                                ),
//                                              ),
//                                            ],
//                                          ),
//                                        ),
//                                      ),
//                                      Container(
//                                        child: Column(
//                                          children: lateFees
//                                              .asMap()
//                                              .entries
//                                              .map((entry) {
//                                            int index = entry.key;
//                                            Map<String, dynamic> lateFee =
//                                                entry.value;
//                                            return Container(
//                                              margin:
//                                                  const EdgeInsets.symmetric(
//                                                      vertical: 6),
//                                              decoration: BoxDecoration(
//                                                color: index % 2 != 0
//                                                    ? const Color(0xFFF4F8FF)
//                                                    : Colors.white,
//                                                border: Border.all(
//                                                    color: const Color(
//                                                        0xFFDBE0E5)),
//                                                borderRadius:
//                                                    BorderRadius.circular(10),
//                                              ),
//                                              child: ListTile(
//                                                contentPadding: EdgeInsets.zero,
//                                                title: Padding(
//                                                  padding:
//                                                      const EdgeInsets.all(2.0),
//                                                  child: Row(
//                                                    mainAxisAlignment:
//                                                        MainAxisAlignment.start,
//                                                    crossAxisAlignment:
//                                                        CrossAxisAlignment
//                                                            .center,
//                                                    children: <Widget>[
//                                                      Expanded(
//                                                        flex: 3,
//                                                        child: Padding(
//                                                          padding:
//                                                              const EdgeInsets
//                                                                  .only(
//                                                                  left: 20.0),
//                                                          child: Text(
//                                                            lateFee['date'] !=
//                                                                        null &&
//                                                                    lateFee['date']
//                                                                        .toString()
//                                                                        .isNotEmpty
//                                                                ? dateProvider
//                                                                    .formatCurrentDate(
//                                                                        lateFee['date']
//                                                                            .toString())
//                                                                : '',
//                                                            style: TextStyle(
//                                                              color: blueColor,
//                                                              fontWeight:
//                                                                  FontWeight
//                                                                      .bold,
//                                                              fontSize: 13,
//                                                            ),
//                                                          ),
//                                                        ),
//                                                      ),
//                                                      Expanded(
//                                                        flex: 2,
//                                                        child: Text(
//                                                          formatCurrency(lateFee[
//                                                                  'amount'] ??
//                                                              0.0),
//                                                          style: TextStyle(
//                                                            color:
//                                                                Colors.orange,
//                                                            fontWeight:
//                                                                FontWeight.bold,
//                                                            fontSize: 13,
//                                                          ),
//                                                        ),
//                                                      ),
//                                                    ],
//                                                  ),
//                                                ),
//                                              ),
//                                            );
//                                          }).toList(),
//                                        ),
//                                      ),
//                                    ],
//                                  ),
//                                );
//                              }
//                            },
//                          ),
                          SizedBox(
                            height: 10,
                          ),
                          // Lease History Table - OLD CODE
                          // CustomHistoryTable commented out - using old implementation
                          Builder(
                            builder: (context) {
                              return CustomHistoryTable(
                                historyType: HistoryType.lease,
                                entityId: widget.leaseId,
                                title: 'Lease History',
                                // Match the "Lease Details" heading above.
                                titleFontSize: 18,
                                blueColor: blueColor,
                                itemsPerPage: 10,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
           
            ],
          );
        }
      },
    );
  }

  Tenant(context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isTablet = constraints.maxWidth > 600;
        return FutureBuilder<List<LeaseTenant>>(
          future: futureLeasetenant,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SpinKitFadingCircle(
                color: blueColor,
                size: 40.0,
              );
            } else if (snapshot.hasError) {
              return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
            } else if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('No data found.'));
            } else {
              final leasetenant = snapshot.data!;
              _orderTenants(snapshot.data!);

              return isTablet
                  ? SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 35,
                          right: 35,
                          top: 30,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: MediaQuery.of(context).size.width * 0.03,
                          runSpacing: MediaQuery.of(context).size.width * 0.035,
                          children: List.generate(
                            snapshot.data!.length,
                            (index) {
                              final fn =
                                  '${snapshot.data![index].tenantFirstName ?? ''}'
                                      .trim();
                              final ln =
                                  '${snapshot.data![index].tenantLastName ?? ''}'
                                      .trim();
                              final initials = ((fn.isNotEmpty ? fn[0] : '') +
                                      (ln.isNotEmpty ? ln[0] : ''))
                                  .toUpperCase();
                              return Container(
                                height: _tenantInactive(snapshot.data![index])
                                    ? 280
                                    : 245,
                                width: MediaQuery.of(context).size.width * .44,
                                decoration: BoxDecoration(
                                  color: _tenantInactive(snapshot.data![index])
                                      ? _movedOutCardBg
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderClr),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_tenantInactive(snapshot.data![index]))
                                        ..._movedOutHeader(
                                            snapshot.data![index]),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            height: 48,
                                            width: 48,
                                            decoration: BoxDecoration(
                                              color: blueColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: initials.isEmpty
                                                  ? const FaIcon(
                                                      FontAwesomeIcons.user,
                                                      size: 18,
                                                      color: Colors.white,
                                                    )
                                                  : Text(
                                                      initials,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '$fn $ln',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: blueColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (_moveControls(snapshot.data![index]) &&
                                              !hasMoveOutNotice(snapshot
                                                  .data![index]
                                                  .moveoutNoticeGivenDate))
                                          InkWell(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  bool isChecked =
                                                      false; // Moved isChecked inside the StatefulBuilder
                                                  return StatefulBuilder(
                                                    builder: (BuildContext
                                                            context,
                                                        StateSetter setState) {
                                                      return Dialog(
                                                        backgroundColor:
                                                            MoveoutColors.pageBg,
                                                        surfaceTintColor:
                                                            MoveoutColors.pageBg,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20.0)),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 16,
                                                                  right: 16,
                                                                  top: 10,
                                                                  bottom: 10),
                                                          child: Container(
                                                              // width: MediaQuery.of(context).size.width - 10,
                                                              width: 900,
                                                              child: buildMoveout(
                                                                  snapshot.data![
                                                                      index],
                                                                  tenants:
                                                                      snapshot
                                                                          .data)),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                              );
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                FaIcon(
                                                  FontAwesomeIcons
                                                      .rightFromBracket,
                                                  size: 16,
                                                  color: blueColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Move out",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: blueColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_moveControls(snapshot.data![index]) &&
                                              hasMoveOutNotice(snapshot
                                                  .data![index]
                                                  .moveoutNoticeGivenDate))
                                            InkWell(
                                              onTap: () async {
                                                SharedPreferences prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                String? id =
                                                    prefs.getString("adminId");
                                                LeaseMoveoutRepository()
                                                    .addMoveInTenant(
                                                  adminId: id!,
                                                  tenantId: snapshot
                                                      .data![index].tenantId,
                                                  leaseId: snapshot
                                                      .data![index].leaseId,
                                                )
                                                    .then((value) {
                                                  setState(() {
                                                    futureLeasetenant =
                                                        LeaseRepository
                                                            .fetchLeaseTenants(
                                                                widget.leaseId);
                                                    isLoading = false;
                                                  });
                                                  Navigator.pop(context, true);
                                                }).catchError((e) {
                                                  setState(() {
                                                    isLoading = false;
                                                  });
                                                });
                                              },
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  FaIcon(
                                                    FontAwesomeIcons
                                                        .circleArrowLeft,
                                                    size: 16,
                                                    color: blueColor,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "Move In",
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: blueColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          _leaseTenantActionsMenu(
                                              snapshot.data![index]),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        '${dateProvider.formatCurrentDate('${snapshot.data![index].startDate}')} to ${dateProvider.formatCurrentDate('${snapshot.data![index].endDate}')}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: mutedClr,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          const FaIcon(
                                            FontAwesomeIcons.phone,
                                            size: 16,
                                            color: mutedClr,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              formatPhoneNumber(
                                                  '${snapshot.data![index].tenantPhoneNumber}'),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: mutedClr,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          const FaIcon(
                                            FontAwesomeIcons.envelope,
                                            size: 16,
                                            color: mutedClr,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              '${snapshot.data![index].tenantEmail}',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                color: mutedClr,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        children: [
                          Wrap(
                            alignment: WrapAlignment.start,
                            spacing: MediaQuery.of(context).size.width * 0.03,
                            runSpacing:
                                MediaQuery.of(context).size.width * 0.02,
                            children:
                                List.generate(snapshot.data!.length, (index) {
                              DateTime currentDate = DateTime.now();
                              DateTime moveoutDate;
                              bool? ismove = false;
                              if (snapshot.data![index].moveoutDate! != "") {
                                moveoutDate = DateFormat('yyyy-MM-dd')
                                    .parse(snapshot.data![index].moveoutDate!);
                                ismove =
                                    moveoutDate.difference(currentDate).inDays <
                                        1;
                              }
                              final fn =
                                  '${snapshot.data![index].tenantFirstName ?? ''}'
                                      .trim();
                              final ln =
                                  '${snapshot.data![index].tenantLastName ?? ''}'
                                      .trim();
                              final initials = ((fn.isNotEmpty ? fn[0] : '') +
                                      (ln.isNotEmpty ? ln[0] : ''))
                                  .toUpperCase();

                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 20,
                                  right: 20,
                                  top: 20,
                                ),
                                child: Container(
                                    decoration: BoxDecoration(
                                      color: _tenantInactive(
                                              snapshot.data![index])
                                          ? _movedOutCardBg
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: borderClr),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (_tenantInactive(
                                              snapshot.data![index]))
                                            ..._movedOutHeader(
                                                snapshot.data![index]),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                height: 48,
                                                width: 48,
                                                decoration: BoxDecoration(
                                                  color: blueColor,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: initials.isEmpty
                                                      ? const FaIcon(
                                                          FontAwesomeIcons.user,
                                                          size: 18,
                                                          color: Colors.white,
                                                        )
                                                      : Text(
                                                          initials,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight
                                                                .bold,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  '$fn $ln',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: blueColor,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Web: no Move out / Move In once the lease
                                              // expired or was evicted; Move In after a notice.
                                              if (_moveControls(snapshot.data![index]) &&
                                                  !hasMoveOutNotice(snapshot
                                                      .data![index]
                                                      .moveoutNoticeGivenDate))
                                                InkWell(
                                                  onTap: () async {
                                                    // showDialog(
                                                    //   context: context,
                                                    //   builder: (BuildContext
                                                    //       context) {
                                                    //     bool isChecked =
                                                    //         false; // Moved isChecked inside the StatefulBuilder
                                                    //     return StatefulBuilder(
                                                    //       builder: (BuildContext
                                                    //               context,
                                                    //           StateSetter
                                                    //               setState) {
                                                    //         return Dialog(
                                                    //           backgroundColor:
                                                    //               Colors.white,
                                                    //           surfaceTintColor:
                                                    //               Colors.white,
                                                    //           shape: RoundedRectangleBorder(
                                                    //               borderRadius:
                                                    //                   BorderRadius
                                                    //                       .circular(
                                                    //                           10.0)),
                                                    //           child: Padding(
                                                    //             padding:
                                                    //                 const EdgeInsets
                                                    //                     .only(
                                                    //                     left:
                                                    //                         16,
                                                    //                     right:
                                                    //                         16,
                                                    //                     top: 10,
                                                    //                     bottom:
                                                    //                         10),
                                                    //             child:
                                                    //                 Container(
                                                    //                     // width: MediaQuery.of(context).size.width - 10,
                                                    //                     width:
                                                    //                         900,
                                                    //                     child: buildMoveout(
                                                    //                         snapshot.data![
                                                    //                             index],
                                                    //                         tenants:
                                                    //                             snapshot.data)),
                                                    //           ),
                                                    //         );
                                                    //       },
                                                    //     );
                                                    //   },
                                                    // );
                                                    final result =
                                                        await Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            MoveoutScreen(
                                                          tenant: snapshot
                                                              .data![index],
                                                          leaseId:
                                                              widget.leaseId,
                                                          tenants: leasetenant,
                                                          enddate:
                                                              widget.enddate ??
                                                                  "",
                                                          moveOutDate:
                                                              moveOutDate ?? "",
                                                        ),
                                                      ),
                                                    );
                                                    if (result == true) {
                                                      setState(() {
                                                        futureLeasetenant =
                                                            LeaseRepository
                                                                .fetchLeaseTenants(
                                                                    widget
                                                                        .leaseId);
                                                      });
                                                    }
                                                  },
                                                  child: Row(
                                                    children: [
                                                      FaIcon(
                                                        FontAwesomeIcons
                                                            .rightFromBracket,
                                                        size: 17,
                                                        color: blueColor,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        "Move out",
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              _leaseTenantActionsMenu(
                                                  snapshot.data![index]),
                                              //   if(isMovedOut || status == 'Expired')
                                              if (_moveControls(snapshot.data![index]) &&
                                                  hasMoveOutNotice(snapshot
                                                      .data![index]
                                                      .moveoutNoticeGivenDate))
                                                InkWell(
                                                  onTap: () async {
                                                    String? tenantId = snapshot
                                                                .data?[index]
                                                                .tenantId !=
                                                            null
                                                        ? snapshot.data![index]
                                                            .tenantId
                                                        : null;
                                                    SharedPreferences prefs =
                                                        await SharedPreferences
                                                            .getInstance();
                                                    String? id = prefs
                                                        .getString("adminId");
                                                    LeaseMoveoutRepository()
                                                        .addMoveInTenant(
                                                      adminId: id!,
                                                      tenantId: tenantId,
                                                      leaseId: snapshot
                                                          .data![index].leaseId,
                                                    )
                                                        .then((value) {
                                                      setState(() {
                                                        futureLeasetenant =
                                                            LeaseRepository
                                                                .fetchLeaseTenants(
                                                                    widget
                                                                        .leaseId);
                                                        isLoading = false;
                                                        // isMovedOut = true;
                                                      });

                                                      Navigator.pop(
                                                          context, true);
                                                    }).catchError((e) {
                                                      setState(() {
                                                        isLoading = false;
                                                      });
                                                    });
                                                  },
                                                  child: Row(
                                                    children: [
                                                      FaIcon(
                                                        FontAwesomeIcons
                                                            .circleArrowLeft,
                                                        size: 17,
                                                        color: blueColor,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        "Move In",
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: blueColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              // if(MediaQuery.of(context).size.width < 350)
                                              //   SizedBox(width: 5),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            '${dateProvider.formatCurrentDate('${snapshot.data![index].startDate}')} to ${dateProvider.formatCurrentDate('${snapshot.data![index].endDate}')}',
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: mutedClr,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              const FaIcon(
                                                FontAwesomeIcons.phone,
                                                size: 16,
                                                color: mutedClr,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  formatPhoneNumber(
                                                      '${snapshot.data![index].tenantPhoneNumber}'),
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    color: mutedClr,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Row(
                                            children: [
                                              const FaIcon(
                                                FontAwesomeIcons.envelope,
                                                size: 16,
                                                color: mutedClr,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${snapshot.data![index].tenantEmail}',
                                                  maxLines:
                                                      3, // Set maximum number of lines
                                                  overflow: TextOverflow
                                                      .ellipsis, // Handle overflow with ellipsis
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      color: mutedClr,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (hasMoveOutNotice(snapshot
                                              .data![index]
                                              .moveoutNoticeGivenDate)) ...[
                                            const SizedBox(height: 14),
                                            _noticeDateRow(
                                                snapshot.data![index]),
                                          ],
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                              );
                            }),
                          ),
                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      ),
                    );
            }
          },
        );
      },
    );
  }

  Widget buildMoveout(LeaseTenant tenant, {List<LeaseTenant>? tenants}) {
    // moveOutDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
    // moveOutDate = DateFormat('dd-MM-yyyy').format(DateTime.parse(widget.enddate!));

    // Convert to stateful list to track selection changes
    Map<String, TextEditingController> startDateControllers = {};
    Map<String, TextEditingController> moveoutDateControllers = {};
    Map<String, String> moveOutDates = {};

    List<LeaseTenant> selectedTenants =
        tenants!.where((t) => t.moveoutDate == "").toList();

    for (var t in selectedTenants!) {
      if (!startDateControllers.containsKey(t.tenantId)) {
        startDateControllers[t.tenantId!] = TextEditingController();
      }
      if (!moveoutDateControllers.containsKey(t.tenantId)) {
        moveoutDateControllers[t.tenantId!] = TextEditingController();
      }

      // Set default values for each tenant
      startDateControllers[t.tenantId!]!.text =
          DateFormat('yyyy-MM-dd').format(DateTime.now());
      moveoutDateControllers[t.tenantId!]!.text = formatDate(t.endDate!);

      // Set default selection
      t!.isSelected = (t.tenantId == tenant.tenantId);
    }

    moveOutDate =
        formatDate(widget.enddate ?? ''); // Store the original format

    //startdateController.text = moveOutDate;
    startdateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Web 2.2: a move-out that leaves nobody on a fixed-term lease asks
    // whether the lease ends (lease_end_decision.dart).
    final LeaseTenant leaseTenant = tenant;
    _leaseEnd = const LeaseEndAnswer();
    List<String> selectedMoveOutDates() => selectedTenants
        .where((t) => t.isSelected == true)
        .map((t) => reverseFormatDate(moveoutDateControllers[t.tenantId]!.text))
        .toList();
    bool askLeaseEnd() => shouldAskLeaseEnd(
          leaseType: leaseTenant.leaseType,
          leaseEndDate: leaseTenant.endDate,
          activeTenantIds: tenants
              .where((t) =>
                  (t.moveoutDate ?? '').isEmpty &&
                  (t.moveoutNoticeGivenDate ?? '').isEmpty &&
                  t.isEvicted != true)
              .map((t) => t.tenantId),
          selectedTenantIds: selectedTenants
              .where((t) => t.isSelected == true)
              .map((t) => t.tenantId),
          selectedMoveOutDates: selectedMoveOutDates(),
        );
    return StatefulBuilder(builder: (context, setState) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MoveoutHeader(),
            const SizedBox(height: 14),
            const MoveoutInfoBanner(),
            const SizedBox(height: 14),
            MoveoutPropertyDetails(
              address: '${tenant.rentalAddress}',
              leaseType: '${tenant.leaseType}',
              startEnd:
                  '${Provider.of<DateProvider>(context, listen: false).formatCurrentDate(tenant.startDate)} to ${Provider.of<DateProvider>(context, listen: false).formatCurrentDate(tenant.endDate)}',
            ),
            const SizedBox(height: 14),
            MoveoutCard(
              title: 'Tenant Details',
              child: Column(
                children: selectedTenants.map((tenant) {
                  return MoveoutTenantTile(
                    name: '${tenant.tenantFirstName} ${tenant.tenantLastName}',
                    selected: tenant.isSelected ?? false,
                    onChanged: (bool? value) {
                      setState(() {
                        tenant.isSelected = value ?? false;
                      });
                    },
                    noticeField: buildDateField(
                      startDateControllers[tenant.tenantId]!,
                      enabled: tenant.isSelected!,
                    ),
                    moveOutField: buildDateField(
                      moveoutDateControllers[tenant.tenantId]!,
                      enabled: tenant.isSelected!,
                      // The lease-end question uses this date.
                      onPicked: () => setState(() {}),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (askLeaseEnd()) ...[
              const SizedBox(height: 14),
              LeaseEndDecisionBox(
                value: _leaseEnd,
                onChanged: (next) => setState(() => _leaseEnd = next),
                leaseStartDate: leaseTenant.startDate,
                leaseEndDate: leaseTenant.endDate,
                selectedMoveOutDates: selectedMoveOutDates(),
              ),
            ],
            const SizedBox(height: 20),
            MoveoutActions(
              onCancel: () {
                Navigator.pop(context);
              },
              onMoveOut: () async {
                final askEnd = askLeaseEnd();
                final leaseEndError = leaseEndValidationError(
                  ask: askEnd,
                  answer: _leaseEnd,
                  leaseStartDate: leaseTenant.startDate,
                  leaseEndDate: leaseTenant.endDate,
                  selectedMoveOutDates: selectedMoveOutDates(),
                );
                if (leaseEndError.isNotEmpty) {
                  setState(() {});
                  Fluttertoast.showToast(msg: leaseEndError);
                  return;
                }
                final leaseEndPayload = buildLeaseEndPayload(
                  ask: askEnd,
                  answer: _leaseEnd,
                  selectedMoveOutDates: selectedMoveOutDates(),
                );
                String? tenantId =
                    tenant.tenantId != null ? tenant.tenantId! : null;
                SharedPreferences prefs =
                    await SharedPreferences.getInstance();
                String? id = prefs.getString("adminId");
                List<Map<String, dynamic>> multipletenant = [];
                for (tenant in selectedTenants) {
                  if (tenant.isSelected!) {
                    // A picked date is dd-MM-yyyy; the server reads
                    // "05-10-2026" as May 10, so send yyyy-MM-dd.
                    String moveoutNoticeGivenDate = reverseFormatDate(
                        startDateControllers[tenant.tenantId!]!.text);
                    String moveoutdate = reverseFormatDate(
                        moveoutDateControllers[tenant.tenantId!]!.text);
                    multipletenant.add({
                      'admin_id': id,
                      'tenant_id': tenant.tenantId!,
                      'lease_id': tenant.leaseId,
                      'moveout_notice_given_date': moveoutNoticeGivenDate!,
                      'moveout_date': moveoutdate!,
                    });
                  }
                }

                await LeaseMoveoutRepository()
                    .addMoveoutTenant(
                        adminId: id!,
                        tenantId: tenantId,
                        leaseId: tenant.leaseId,
                        moveoutDate: moveOutDate,
                        moveoutNoticeGivenDate: startdateController.text,
                        multitenantdata: multipletenant,
                        leaseEnd: leaseEndPayload)
                    .then((value) {
                  setState(() {
                    futureLeasetenant =
                        LeaseRepository.fetchLeaseTenants(widget.leaseId);

                    isLoading = false;
                    isMovedOut = true;
                  });

                  reload_screen();
                  Navigator.pop(context, true);
                }).catchError((e) {
                  setState(() {
                    isLoading = false;
                  });
                });
              },
            ),
          ],
        ),
      );
    });
  }

  Widget buildTableCell(Widget child) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: child,
      ),
    );
  }

  reload_screen() {
    setState(() {});
  }

  Widget buildDateField(TextEditingController controller,
      {bool enabled = false, VoidCallback? onPicked}) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: moveoutDateBoxDecoration(enabled: enabled),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: moveoutDateTextStyle(enabled: enabled),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Select Date',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined,
                      size: 20, color: MoveoutColors.muted),
                  onPressed: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2101),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color.fromRGBO(
                                  21, 43, 83, 1), // header background color
                              onPrimary: Colors.white, // header text color
                              onSurface: Color.fromRGBO(
                                  21, 43, 83, 1), // body text color
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color.fromRGBO(
                                    21, 43, 83, 1), // button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (pickedDate != null) {
                      // setState(() {
                      controller.text = moveOutDate!;
                      controller.text =
                          DateFormat('dd-MM-yyyy').format(pickedDate);
                      //  });
                      onPicked?.call();
                    }
                  },
                ),
              ),
              readOnly: true,
            ),
          ),
        ),
      ),
    );
  }
}
