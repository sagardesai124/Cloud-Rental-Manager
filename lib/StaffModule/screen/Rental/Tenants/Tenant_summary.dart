import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/AdminTenantInsuranceModel/adminTenantInsuranceModel.dart';
import 'package:three_zero_two_property/Model/lease_renter_insurance.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:three_zero_two_property/services/api_helpers.dart';
import '../../../repository/lease_rental_insurance_repo.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/SummeryPageLease.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../../../../StaffModule/screen/Rental/Tenants/Payments/Tenant_payments.dart';
import '../../../../StaffModule/screen/Rental/Tenants/Commnunication/communication.dart';

import '../../../../provider/dateProvider.dart';

import '../../../repository/AdminTenantInsuranceService/adminTenantinsuranceService.dart';
import '../../../repository/tenants.dart';

import '../../Communications/Send E-mail/send_mail.dart';
import 'AdminTenantInsurance/addAdminTenantInsurance.dart';
import 'AdminTenantInsurance/editAdminTenantInsurance.dart';
import '../../Leasing/RentalRoll/Renters Insurance/RentersInsuranceAdd.dart';
import '../../Leasing/RentalRoll/Renters Insurance/Edit_Renters_insurance.dart';
import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import 'package:email_validator/email_validator.dart';
import '../../../../Model/tenants.dart';
import '../../../model/rentalOwner.dart';

import '../../../repository/Rental_ownersData.dart';
import '../../../widgets/drawer_tiles.dart';
import '../../../widgets/custom_drawer.dart';
import 'edit_tenants.dart';
import '../../../../widgets/custom_history_table.dart';
import '../../../../enums/history_type.dart';
import 'package:three_zero_two_property/StaffModule/screen/Maintenance/Workorder/Workorder_table.dart'
    as staff_workorder;
import 'package:three_zero_two_property/TenantsModule/screen/financial/AddAchAccount/AddAchAccount.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/addcard/AddCard.dart';
import 'package:three_zero_two_property/StaffModule/repository/lease.dart';
import 'package:three_zero_two_property/Model/lease_term.dart';
import '../../Leasing/RentalRoll/Notes/Notes_table.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class ResponsiveTenantSummary extends StatefulWidget {
  Tenant? tenants;
  String tenantId;

  /// When set, mobile opens this tab (0=Summary, 1=Leases, …). Tablet scrolls to lease section if 1.
  final int? initialSummaryTabIndex;
  ResponsiveTenantSummary({
    super.key,
    required this.tenantId,
    this.tenants,
    this.initialSummaryTabIndex,
  });
  @override
  State<ResponsiveTenantSummary> createState() =>
      _ResponsiveTenantSummaryState();
}

class _ResponsiveTenantSummaryState extends State<ResponsiveTenantSummary> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 500) {
            return TenantSummaryTablet(
              tenants: widget.tenants,
              tenantId: widget.tenantId,
              initialSummaryTabIndex: widget.initialSummaryTabIndex,
            );
          } else {
            return TenantSummaryMobile(
              tenants: widget.tenants,
              tenantId: widget.tenantId,
              initialSummaryTabIndex: widget.initialSummaryTabIndex,
            );
          }
        },
      ),
    );
  }
}

class TenantSummaryMobile extends StatefulWidget {
  Tenant? tenants;
  String tenantId;
  final int? initialSummaryTabIndex;
  TenantSummaryMobile({
    super.key,
    required this.tenantId,
    this.tenants,
    this.initialSummaryTabIndex,
  });
  @override
  State<TenantSummaryMobile> createState() => _TenantSummaryMobileState();
}

class _TenantSummaryMobileState extends State<TenantSummaryMobile>
    with NetworkRetryState {
  late Future<List<TenantLeaseData>> futurePropertyLease;
  Future<List<TenantLeaseData>> fetchLeaseData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminid = prefs.getString("adminId");
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');
    String url = '$Api_url/api/tenant/tenant_details/${widget.tenantId}';
    final response = await apiGet(
      Uri.parse(url),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final tenantResponse = TenantResponse.fromJson(jsonResponse);
      // Collect all lease data from all tenant data
      List<TenantLeaseData> allLeaseData = [];
      if (tenantResponse.data != null) {
        for (var tenant in tenantResponse.data!) {
          if (tenant.leaseData != null) {
            allLeaseData.addAll(tenant.leaseData!);
          }
        }
      }
      if (mounted) {
        setState(() {
          _leaseData = allLeaseData;
          final data = tenantResponse.data;
          _tenantDetails =
              (data != null && data.isNotEmpty) ? data.first : null;
          if (widget.tenants != null) {
            widget.tenants!.leaseData = allLeaseData;
          }
        });
        // Lease data is in, so the lease id is now resolvable — load the
        // rental-owner acceptance that decides whether the ACH row exists.
        _ensureAchSettings();
        // Same reason: the balance is keyed on the lease id, which only becomes
        // resolvable here. Fetching it in initState used the tenant id fallback
        // and returned nothing, so the badge only appeared on a second visit.
        _fetchTenantBalance();
        // Term history per lease, for the Lease Details "inferred" marker and
        // the real current-term dates.
        _fetchLeaseTerms(allLeaseData);
      }
      return allLeaseData;
    } else {
      throw Exception('Failed to load lease data');
    }
  }

  /// Fetched lease data (used when widget.tenants is null or not yet updated). Ensures Lease tab has data in Staff.
  List<TenantLeaseData>? _leaseData;

  /// Fetched tenant details (includes emergency_contact + emergency_contacts) for merged emergency list.
  Tenant? _tenantDetails;

  int? expandedEmergencyIndex;
  bool expandedTenantInfo = false;

  Future<void> _refreshTenantDetails() async {
    // Every failure here used to be discarded: `catch (_) {}` ate the error and
    // an empty list simply fell through the `if`. Either way the screen kept
    // the pre-edit values while the caller had already shown "updated
    // successfully" — so a user saw a success message next to unchanged data
    // and had no way to tell whether the edit had saved. Callers can't cover
    // this either: their own catch never fires, because this method has
    // already swallowed the error.
    try {
      final list = await _tenantService.fetchTenantsummery(widget.tenantId);
      if (!mounted) return;
      if (list == null || list.isEmpty) {
        Fluttertoast.showToast(
            msg: "Couldn't reload tenant details. Pull down to refresh.");
        return;
      }
      setState(() {
        _tenantDetails = list.first;
        // Also refresh the passed-in tenant so every direct widget.tenants
        // read (e.g. the header name) reflects the edit immediately.
        widget.tenants = list.first;
      });
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(
          msg: friendlyErrorMessage(e,
              fallbackMessage: "Couldn't reload tenant details."));
    }
  }

  final TenantsRepository _tenantService = TenantsRepository();
  final TenantsRepository repo = TenantsRepository();

  // Web parity: "Show Deleted Policies" on the Renter's Insurance section,
  // persisted under the same key the web app uses in localStorage.
  static const String _showDeletedPrefKey =
      'rentersInsurance:embedded:showDeleted';
  bool _showDeleted = false;

  Future<List<lease_renter_insurance>> _fetchRenterPolicies() =>
      RentersInsuranceService()
          .fetchPoliciesByTenant(widget.tenantId, includeDeleted: _showDeleted);

  /// Read the persisted preference first so the initial fetch already includes
  /// deleted policies when the toggle was left on.
  Future<List<lease_renter_insurance>> _loadShowDeletedPrefAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final restored = prefs.getBool(_showDeletedPrefKey) ?? false;
    if (restored != _showDeleted) {
      _showDeleted = restored;
      // The checkbox sits outside this FutureBuilder, so completing the future
      // alone would not repaint it — it would read unchecked while deleted
      // rows were in the list. Rebuild explicitly.
      if (mounted) setState(() {});
    }
    return _fetchRenterPolicies();
  }

  Future<void> _onShowDeletedChanged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDeletedPrefKey, value);
    if (!mounted) return;
    setState(() {
      _showDeleted = value;
      currentPage = 0;
      _currentPage = 0;
      futureRenterPolicies = _fetchRenterPolicies();
    });
  }

  /// Rows shown in the Renter's Insurance section.
  ///
  /// Web parity: the tenant-scoped list renders every policy the endpoint
  /// returns — expired and future included, not just ACTIVE (see web
  /// 681b5d751). Only soft-deleted rows are gated, on the toggle.
  bool _isPolicyVisible(lease_renter_insurance p) =>
      _showDeleted || p.isDelete != true;

  /// Web parity: the "Show Deleted Policies" checkbox above the policy list.
  Widget _buildShowDeletedToggle() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _showDeleted,
            activeColor: blueColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) {
              if (value != null) {
                _onShowDeletedChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _onShowDeletedChanged(!_showDeleted),
          child: Text(
            'Show Deleted Policies',
            style: TextStyle(
              color: blueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Web parity: small grey DELETED badge next to a soft-deleted policy.
  Widget _buildDeletedBadge() {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Text(
        'DELETED',
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  int totalrecords = 0;
  late Future<List<lease_renter_insurance>> futureRenterPolicies;
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

  void sortData(List<lease_renter_insurance> data) {
    /*  if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.propertyType!.compareTo(b.propertyType!)
          : b.propertyType!.compareTo(a.propertyType!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.propertysubType!.compareTo(b.propertysubType!)
          : b.propertysubType!.compareTo(a.propertysubType!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.createdAt!.compareTo(b.createdAt!)
          : b.createdAt!.compareTo(a.createdAt!));
    }*/
  }

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
                    Padding(
                      padding: const EdgeInsets.only(left: 25.0),
                      child: Text("Company",
                          style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    // const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting2) {
                      sorting1 = false;
                      sorting2 = sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = !sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    }
                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 0,),
                      child: Text("Policy Id",
                          style: TextStyle(
                              color: blueColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 47),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaders_lease() {
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
            SizedBox(width: MediaQuery.of(context).size.width * .02),
            Expanded(
              flex: 2,
              child: Text("     Status",
                  style: TextStyle(
                      color: blueColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(
              flex: 2,
              child: Text("    Property",
                  style: TextStyle(
                      color: blueColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 25),
          ],
        ),
      ),
    );
  }

  final List<String> items = ['Residential', "Commercial", "All"];
  String? selectedValue;
  String searchvalue = "";
  late int _tenantSummaryTabIndex;
  int _historyRefreshKey = 0;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls from `initState` only — controllers, listeners and
  /// filter defaults are not repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureRenterPolicies = _loadShowDeletedPrefAndFetch();;
    });
  }

  @override
  void initState() {
    super.initState();
    _tenantSummaryTabIndex = (widget.initialSummaryTabIndex ?? 0).clamp(0, 5);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    futureRenterPolicies = _loadShowDeletedPrefAndFetch();
    // Balance is fetched from inside fetchLeaseData(), once the lease id is
    // actually known — see the note there.
    futurePropertyLease = fetchLeaseData();
  }

  /// Drives the transition while another route sits on top of this one.
  /// Watching it is how the badge notices the user coming back.
  Animation<double>? _coveringRouteAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A charge or payment is never recorded from this screen — it happens
    // further down the stack — so awaiting our own pushes cannot catch it.
    // Web stays correct because returning there is a route change that
    // remounts the page and refetches; here the State survives, so the badge
    // would keep its first-load value. `secondaryAnimation` returning to
    // dismissed means the route covering us has finished popping, i.e. the
    // user is looking at this screen again — the local equivalent of
    // RouteAware.didPopNext(), with no app-wide observer to register.
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (!identical(animation, _coveringRouteAnimation)) {
      _coveringRouteAnimation?.removeStatusListener(_onCoveringRouteChanged);
      _coveringRouteAnimation = animation;
      _coveringRouteAnimation?.addStatusListener(_onCoveringRouteChanged);
    }
  }

  void _onCoveringRouteChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _fetchTenantBalance();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _coveringRouteAnimation?.removeStatusListener(_onCoveringRouteChanged);
    super.dispose();
  }

  // ── Balance badge (web parity: "Balance: $X Balance Due" on the tenant
  // details header). The figure comes straight from the lease ledger endpoint
  // — the server already computes it (LeaseController.CalculateBalanceForLease),
  // so nothing is recalculated here.
  double? _tenantBalance;

  /// Pale-blue pill under the Summary header, mirroring the web badge.
  /// Hidden until the figure is known so no placeholder amount is ever shown.
  Widget _buildBalanceBadge() {
    final balance = _tenantBalance;
    // Hidden ONLY when the figure cannot be read — no active lease, or the
    // request failed. Web gates on `detailsBalance !== null` alone
    // (TenantDetailPage.jsx), so a settled lease still shows the badge.
    if (balance == null) return const SizedBox.shrink();

    // Same credit/due convention and colours as the lease Financial tab, so
    // the two screens never disagree about the same lease. A settled lease
    // carries no suffix — zero is neither owed nor credited — which is what
    // web renders too ("Balance: $0.00").
    final isSettled = balance.abs() < 1e-10;
    final isCredit = !isSettled && balance < 0;
    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 2,
    ).format(balance.abs());
    final label = isSettled
        ? 'Balance: \$0.00'
        : isCredit
            ? 'Balance: ($formatted) Credit'
            : 'Balance: $formatted Balance Due';

    return Padding(
      padding: const EdgeInsets.only(left: 15, right: 15, top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:
                isCredit ? const Color(0xFFD1FAE5) : const Color(0xFFEBF5FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isCredit
                    ? const Color(0xFF6EE7B7)
                    : const Color(0xFF8AAEE0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isCredit ? const Color(0xFF065F46) : blueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  // ── Lease term history (web parity: LeaseTermsTable) ──────────────────────
  // Terms per lease id, from GET /api/leases/{id}/terms. Entry 0 is the current
  // term. Terms the server rebuilt from rent charges are flagged "inferred".
  // Empty/missing means "fall back to the lease's own fields", which is exactly
  // what web does when the terms array is empty.
  final Map<String, List<LeaseTerm>> _leaseTerms = {};

  Future<void> _fetchLeaseTerms(List<TenantLeaseData> leases) async {
    final ids = leases
        .map((l) => l.leaseId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return;
    await Future.wait(ids.map((id) async {
      final terms = await LeaseRepository().fetchLeaseTerms(id);
      if (terms.isNotEmpty) _leaseTerms[id] = terms;
    }));
    if (mounted) setState(() {});
  }

  /// Current term for a lease, or null to fall back to the lease's own fields.
  LeaseTerm? _currentTerm(String? leaseId) {
    if (leaseId == null || leaseId.isEmpty) return null;
    final terms = _leaseTerms[leaseId];
    return (terms == null || terms.isEmpty) ? null : terms.first;
  }

  /// Amber "inferred" pill — same palette as web (#FCF3D6 / #8A6D3B), shown
  /// when the term was estimated from rent history rather than recorded.
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

  /// End date for display: month-to-month leases carry a far-future sentinel
  /// (year >= 2049), which web renders as "ongoing" rather than a 2050 date.
  String _displayEndDate(String? endDate, DateProvider dateProvider) {
    if (endDate == null || endDate.isEmpty) return 'N/A';
    final year =
        endDate.length >= 4 ? int.tryParse(endDate.substring(0, 4)) : null;
    if (year != null && year >= 2049) return 'ongoing';
    return dateProvider.formatCurrentDate(normalizeDateForDisplay(endDate));
  }

  Future<void> _fetchTenantBalance() async {
    try {
      // Staff repository — sends the staff_id header, matching web.
      final leaseId = _effectiveLeaseId;
      // No lease on file -> nothing to show; leave the badge hidden.
      if (leaseId == null) return;
      final ledger =
          await LeaseRepository().fetchLeaseLedger(leaseId: leaseId);
      if (!mounted) return;
      setState(() => _tenantBalance = ledger?.totalBalance);
    } catch (_) {
      // Badge simply stays hidden if the balance can't be read — it must never
      // block the rest of the summary from rendering.
    }
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
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

  static const List<String> _tenantSummaryTabTitles = [
    'Summary',
    'Leases',
    'Communications',
    'Payments',
    'Work Orders',
    'Notes',
  ];

  String _tenantSummaryTabIconAsset(String title) {
    switch (title) {
      case 'Summary':
        return 'assets/icons/summery.png';
      case 'Leases':
        return 'assets/icons/document.png';
      case 'Communications':
        return 'assets/icons/communication.png';
      case 'Payments':
        return 'assets/icons/financial.png';
      case 'Work Orders':
        return 'assets/icons/maintence.png';
      case 'Notes':
        return 'assets/icons/document.png';
      default:
        return 'assets/icons/summery.png';
    }
  }

  Widget _buildTenantSummaryTabDropdown(BuildContext context) {
    final tabTitles = _tenantSummaryTabTitles;
    final safeIndex = _tenantSummaryTabIndex.clamp(0, tabTitles.length - 1);
    final selectedTitle = tabTitles[safeIndex];

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButton2<String>(
        isExpanded: true,
        underline: const SizedBox(),
        value: selectedTitle,
        selectedItemBuilder: (BuildContext context) {
          return tabTitles.map((String title) {
            final iconPath = _tenantSummaryTabIconAsset(title);
            return Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Image.asset(iconPath, width: 20, height: 20),
                  const SizedBox(width: 12),
                  Text(
                    title,
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
          final index = entry.key;
          final title = entry.value;
          final iconPath = _tenantSummaryTabIconAsset(title);
          return DropdownMenuItem<String>(
            value: title,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: index < tabTitles.length - 1
                    ? Border(
                        bottom: BorderSide(
                          color: blueColor.withOpacity(0.2),
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Image.asset(iconPath,
                      width: 20, height: 20, color: blueColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: blueColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 25, color: blueColor),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (String? value) {
          if (value != null) {
            final idx = tabTitles.indexOf(value);
            if (idx >= 0) {
              setState(() => _tenantSummaryTabIndex = idx);
              // The Payments/Lease tabs read the ledger the badge is drawn
              // from, so re-read it on every tab change and the header can
              // never disagree with the tab the user just looked at.
              _fetchTenantBalance();
            }
          }
        },
        buttonStyleData: ButtonStyleData(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1,
            ),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          iconSize: 24,
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: MediaQuery.of(context).size.height * 0.54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            border: Border.all(
              color: Colors.grey.shade500,
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
            thumbVisibility: MaterialStateProperty.all(false),
          ),
        ),
        menuItemStyleData: MenuItemStyleData(
          height: 50,
          padding: EdgeInsets.zero,
          overlayColor: MaterialStateProperty.all(Colors.grey[100]),
        ),
      ),
    );
  }

  void handleEdit(lease_renter_insurance property) async {}

  void _showRenterInsuranceDeleteAlert(
      BuildContext context, String rentersInsuranceId) {
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this Insurance!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: Text(
            "Cancel",
            style: TextStyle(
                color: blueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(color: blueColor, width: 1.5),
        ),
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            try {
              await RentersInsuranceService()
                  .deleteInsurance(renters_insurance_id: rentersInsuranceId);
              if (mounted)
                setState(() {
                  futureRenterPolicies = _fetchRenterPolicies();
                });
            } catch (e) {
              if (mounted)
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
            }
            Navigator.pop(context);
          },
          color: blueColor,
        )
      ],
    ).show();
  }

  List<lease_renter_insurance> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<lease_renter_insurance> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0;
    });
  }

  void _sortRenterPolicies(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _tableData.sort((a, b) {
        int result;
        switch (columnIndex) {
          case 0:
            result =
                (a.insuranceCompany ?? '').compareTo(b.insuranceCompany ?? '');
            break;
          case 1:
            result = (a.policyId ?? '').compareTo(b.policyId ?? '');
            break;
          case 2:
            result = (a.effectiveDate ?? '').compareTo(b.effectiveDate ?? '');
            break;
          case 3:
            result = (a.expirationDate ?? '').compareTo(b.expirationDate ?? '');
            break;
          case 4:
            result = (a.policyStatus ?? '').compareTo(b.policyStatus ?? '');
            break;
          default:
            result = 0;
        }
        return _sortAscending ? result : -result;
      });
    });
  }

  void handleDelete(lease_renter_insurance property) {}

  void _sort<T>(Comparable<T> Function(lease_renter_insurance d) getField,
      int columnIndex, bool ascending) {
    // Desktop renter insurance table uses lease_renter_insurance; sorting is via _sortRenterPolicies when needed.
  }

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(lease_renter_insurance d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField!, columnIndex, !_sortAscending);
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

  Widget _buildDataCell(String text, {bool isDeleted = false}) {
    return TableCell(
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text,
            style: TextStyle(
              fontSize: 18,
              // Web parity: soft-deleted policies read greyed + struck through.
              color: isDeleted ? Colors.grey : null,
              decoration: isDeleted ? TextDecoration.lineThrough : null,
            )),
      ),
    );
  }

  Widget _buildActionsCell(lease_renter_insurance data) {
    // Web parity: a soft-deleted policy is read-only — no Edit/Delete.
    final bool isDeleted = data.isDelete == true;
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
              if (!isDeleted)
                InkWell(
                  onTap: () {
                    handleEdit(data);
                  },
                  child: const FaIcon(
                    FontAwesomeIcons.edit,
                    size: 30,
                  ),
                ),
              if (!isDeleted)
                const SizedBox(
                  width: 15,
                ),
              if (!isDeleted)
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

  Widget _buildRenterInsuranceActionsCell(lease_renter_insurance policy) {
    // Web parity: a soft-deleted policy is read-only — no Edit/Delete.
    final bool isDeleted = policy.isDelete == true;
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          height: 50,
          child: Row(
            children: [
              const SizedBox(width: 20),
              if (!isDeleted)
                InkWell(
                  onTap: () async {
                    var check = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditRentersInsurance(
                          tenantid: widget.tenantId,
                          leaseId: policy.leaseId ?? '',
                          renters_insurance_id: policy.rentersInsuranceId!,
                          embeddedInTenantSummary: true,
                        ),
                      ),
                    );
                    if (check == true) {
                      setState(() {
                        futureRenterPolicies = _fetchRenterPolicies();
                      });
                    }
                  },
                  child: const FaIcon(FontAwesomeIcons.edit, size: 30),
                ),
              if (!isDeleted) const SizedBox(width: 15),
              if (!isDeleted)
                InkWell(
                  onTap: () => _showRenterInsuranceDeleteAlert(
                      context, policy.rentersInsuranceId!),
                  child: const FaIcon(FontAwesomeIcons.trashCan, size: 30),
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

  //Tenant lease
  int totalrecordsTenantLease = 0;
  // late Future<List<TenantLeaseData>> futurePropertyTypes;
  int rowsPerPageTenantLease = 5;
  int sortColumnIndexTenantLease = 0;
  bool sortAscendingTenantLease = true;
  int currentPageTenantLease = 0;
  int itemsPerPageTenantLease = 10;
  List<int> itemsPerPageOptionsTenantLease = [
    10,
    25,
    50,
    100,
  ]; // Options for items per page

  void sortDataTenantLease(List<TenantLeaseData> data) {
    /*  if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.propertyType!.compareTo(b.propertyType!)
          : b.propertyType!.compareTo(a.propertyType!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.propertysubType!.compareTo(b.propertysubType!)
          : b.propertysubType!.compareTo(a.propertysubType!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.createdAt!.compareTo(b.createdAt!)
          : b.createdAt!.compareTo(a.createdAt!));
    }*/
  }

  int? expandedTenantLeaseIndex;
  Set<int> expandedTenantLeaseIndices = {};
  late bool isExpandedTenantLease;
  bool sorting1TenantLease = false;
  bool sorting2TenantLease = false;
  bool sorting3TenantLease = false;
  bool ascending1TenantLease = false;
  bool ascending2TenantLease = false;
  bool ascending3TenantLease = false;
  Widget _buildHeadersTenantLease() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
        color: blueColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting1TenantLease == true) {
                      sorting2TenantLease = false;
                      sorting3TenantLease = false;
                      ascending1TenantLease =
                          sorting1TenantLease ? !ascending1TenantLease : true;
                      ascending2TenantLease = false;
                      ascending3TenantLease = false;
                    } else {
                      sorting1TenantLease = !sorting1TenantLease;
                      sorting2TenantLease = false;
                      sorting3TenantLease = false;
                      ascending1TenantLease =
                          sorting1TenantLease ? !ascending1TenantLease : true;
                      ascending2TenantLease = false;
                      ascending3TenantLease = false;
                    }

                    // Sorting logic here
                  });
                },
                child: Row(
                  children: [
                    width < 400
                        ? const Padding(
                            padding: EdgeInsets.only(left: 20.0),
                            child: Text(
                              "Status",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const Text("     Insurance Company",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            textAlign: TextAlign.center),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting2TenantLease) {
                      sorting1TenantLease = false;
                      sorting2TenantLease = sorting2TenantLease;
                      sorting3TenantLease = false;
                      ascending2TenantLease = sorting2 ? !ascending2 : true;
                      ascending1TenantLease = false;
                      ascending3TenantLease = false;
                    } else {
                      sorting1TenantLease = false;
                      sorting2TenantLease = !sorting2TenantLease;
                      sorting3TenantLease = false;
                      ascending2TenantLease =
                          sorting2TenantLease ? !ascending2TenantLease : true;
                      ascending1TenantLease = false;
                      ascending3TenantLease = false;
                    }
                    // Sorting logic here
                  });
                },
                child: const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 0.0),
                      child: Text("Start Date",
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting3) {
                      sorting1TenantLease = false;
                      sorting2TenantLease = false;
                      sorting3TenantLease = sorting3TenantLease;
                      ascending3TenantLease =
                          sorting3TenantLease ? !ascending3TenantLease : true;
                      ascending2TenantLease = false;
                      ascending1TenantLease = false;
                    } else {
                      sorting1TenantLease = false;
                      sorting2TenantLease = false;
                      sorting3TenantLease = !sorting3TenantLease;
                      ascending3TenantLease =
                          sorting3TenantLease ? !ascending3TenantLease : true;
                      ascending2TenantLease = false;
                      ascending1TenantLease = false;
                    }

                    // Sorting logic here
                  });
                },
                child: const Row(
                  children: [
                    Text(
                      "End\nDate",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
    );
  }

  /// Lease whose balance the header badge shows.
  ///
  /// Web parity (TenantDetailPage.jsx:598-639): the ACTIVE lease wins — today
  /// between start_date and end_date, inclusive — falling back to the first
  /// lease on file. Taking the list's first entry unconditionally showed an old
  /// lease's balance whenever the active one was not first in the array, which
  /// is how the same tenant could read "Balance Due" on web and "Credit" here.
  ///
  /// Returns null when the tenant has no lease at all, so the badge stays
  /// hidden — the previous tenantId fallback queried the LEASE ledger with a
  /// TENANT id, which can only produce a meaningless figure or an error.
  String? get _effectiveLeaseId {
    final list = _leaseListForTab;
    if (list == null || list.isEmpty) return null;
    for (final lease in list) {
      if (_isLeaseActive(lease.startDate, lease.endDate)) return lease.leaseId;
    }
    return list.first.leaseId;
  }

  /// True if lease is active (today between start and end). Used for lease tab.
  bool _isLeaseActive(String? startDate, String? endDate) {
    if (startDate == null ||
        endDate == null ||
        startDate.isEmpty ||
        endDate.isEmpty) return false;
    try {
      final start = _parseLeaseDate(startDate);
      final end = _parseLeaseDate(endDate);
      final now = DateTime.now();
      return !now.isBefore(start) && !now.isAfter(end);
    } catch (_) {
      return false;
    }
  }

  DateTime _parseLeaseDate(String dateStr) {
    final formats = ['yyyy-MM-dd', 'dd-MM-yyyy', 'MM/dd/yyyy', 'M/d/yyyy'];
    for (final f in formats) {
      try {
        return DateFormat(f).parse(dateStr);
      } catch (_) {}
    }
    return DateTime.tryParse(dateStr) ?? DateTime.now();
  }

  /// Lease list for Lease tab: prefer fetched tenant details, then widget.tenants, then _leaseData.
  List<TenantLeaseData>? get _leaseListForTab =>
      _tenantDetails?.leaseData?.isNotEmpty == true
          ? _tenantDetails!.leaseData
          : widget.tenants?.leaseData?.isNotEmpty == true
              ? widget.tenants!.leaseData
              : (_leaseData?.isNotEmpty == true ? _leaseData : null);

  /// First *active* lease's ID for lease summary. Null if no lease data or no active lease.
  String? get _firstActiveLeaseId {
    final list = _leaseListForTab;
    if (list == null || list.isEmpty) return null;
    for (final lease in list) {
      if (_isLeaseActive(lease.startDate, lease.endDate) &&
          (lease.leaseId ?? '').isNotEmpty) {
        return lease.leaseId;
      }
    }
    return null;
  }

  String? get _leaseIdForAddCard {
    final active = _firstActiveLeaseId;
    if (active != null && active.isNotEmpty) return active;
    final list = _leaseListForTab;
    if (list == null || list.isEmpty) return null;
    final id = list.first.leaseId;
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<void> _onPaymentAllowAchChanged(bool value) async {
    final t = _tenantDetails ?? widget.tenants;
    if (t == null) return;
    final card = t.allowCard != false;
    final prevAch = t.allowAch;
    setState(() {
      if (_tenantDetails != null) _tenantDetails!.allowAch = value;
      if (widget.tenants != null) widget.tenants!.allowAch = value;
    });
    try {
      await repo.editTenantFromModel(
        _tenantDetails ?? widget.tenants!,
        allowAch: value,
        allowCard: card,
      );
      if (mounted) setState(() => _historyRefreshKey++);
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_tenantDetails != null) _tenantDetails!.allowAch = prevAch;
          if (widget.tenants != null) widget.tenants!.allowAch = prevAch;
        });
      }
    }
  }

  Future<void> _onPaymentAllowCardChanged(bool value) async {
    final t = _tenantDetails ?? widget.tenants;
    if (t == null) return;
    final ach = t.allowAch != false;
    final prevCard = t.allowCard;
    setState(() {
      if (_tenantDetails != null) _tenantDetails!.allowCard = value;
      if (widget.tenants != null) widget.tenants!.allowCard = value;
    });
    try {
      await repo.editTenantFromModel(
        _tenantDetails ?? widget.tenants!,
        allowAch: ach,
        allowCard: value,
      );
      if (mounted) setState(() => _historyRefreshKey++);
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_tenantDetails != null) _tenantDetails!.allowCard = prevCard;
          if (widget.tenants != null) widget.tenants!.allowCard = prevCard;
        });
      }
    }
  }

  /// Rental-owner acceptance for this tenant+lease, the same source web reads
  /// (`tenant/payment_settings`) to decide whether ACH exists as an option at
  /// all. Fail-closed: anything other than an explicit true hides ACH.
  bool _leaseAchAccepted = false;
  bool _achSettingsFetched = false;
  bool _achFetchInFlight = false;
  // Blocks a second tap while the first is still awaiting the settings call.
  bool _openingPaymentMethods = false;

  Future<void> _fetchAchAccepted(String leaseId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? sid = prefs.getString("staff_id");
      String? token = prefs.getString('token');
      final response = await apiGet(
        Uri.parse('$Api_url/api/tenant/payment_settings/${widget.tenantId}/$leaseId'),
        headers: {
          "authorization": "CRM $token",
          // Staff must send their OWN staff_id here (not adminId) — adminId
          // 401s for staff (CRM-4479), which would silently hide ACH.
          "id": "CRM $sid",
        },
      );
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
        _leaseAchAccepted = jsonData['data']['achAccepted'] == true;
        // Only a real answer counts as "known". Marking a failed call as
        // fetched would hide ACH for the rest of the screen's life with no
        // retry, since both entry points skip the call once this is true.
        _achSettingsFetched = true;
      }
    } catch (e) {
    } finally {
      _achFetchInFlight = false;
      // The ACH row's visibility depends on the answer, so repaint once it is
      // in — this is what removes the row for an owner that declines ACH.
      if (mounted) setState(() {});
    }
  }

  /// Loads the acceptance once, as soon as a lease id is available.
  void _ensureAchSettings() {
    if (_achSettingsFetched || _achFetchInFlight) return;
    final leaseId = _leaseIdForAddCard;
    if (leaseId == null || leaseId.isEmpty) return;
    _achFetchInFlight = true;
    _fetchAchAccepted(leaseId);
  }

  Future<void> _openManagePaymentMethods() async {
    // The button stays live across the settings await, so without this a
    // double tap can stack two dialogs or push two AddCard routes.
    if (_openingPaymentMethods) return;
    _openingPaymentMethods = true;
    try {
      await _handleManagePaymentMethods();
    } finally {
      _openingPaymentMethods = false;
    }
  }

  Future<void> _handleManagePaymentMethods() async {
    final leaseId = _leaseIdForAddCard;
    if (leaseId == null || leaseId.isEmpty) {
      Fluttertoast.showToast(
        msg:
            'This tenant needs at least one lease to add or manage saved payment methods.',
        backgroundColor: Colors.red,
      );
      return;
    }
    // Whether ACH exists at all is the rental owner's setting, not the tenant's
    // tick — web renders the ACH checkbox only when the owner accepts it.
    if (!_achSettingsFetched) {
      await _fetchAchAccepted(leaseId);
      if (!mounted) return;
    }
    // Read live from the tenant object so the chooser reflects the Card/ACH
    // toggles above, including a change made moments ago.
    final t = _tenantDetails ?? widget.tenants;
    // Card stays fail-open, the way the toggles above already read it: only an
    // explicit false turns it off.
    final allowCard = t?.allowCard != false;
    // ACH needs BOTH: the owner accepting it and the tenant's own tick, which
    // is what web's "Allowed Payment Methods" list encodes.
    final allowAch = _leaseAchAccepted && t?.allowAch == true;

    if (!allowCard && !allowAch) {
      Fluttertoast.showToast(
        msg: 'Turn on Card or ACH in Payment Options to add a payment method.',
        backgroundColor: Colors.red,
      );
      return;
    }
    // With only one method accepted the chooser would hold a single row, so go
    // straight to it — the tenant module hides the unavailable action the same
    // way rather than showing it disabled.
    if (!allowAch) {
      _openAddCard(leaseId);
      return;
    }
    if (!allowCard) {
      _openAddAch(leaseId);
      return;
    }
    _showPaymentMethodChooser(leaseId);
  }

  void _openAddCard(String leaseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCard(
          leaseId: leaseId,
          initialTenantId: widget.tenantId,
          useStaffIdHeader: true,
        ),
      ),
    );
  }

  void _openAddAch(String leaseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAchAccount(
          tenantId: widget.tenantId,
          leaseId: leaseId,
          authAsStaff: true,
        ),
      ),
    );
  }

  /// Centered chooser, matching the other dialogs in this screen.
  void _showPaymentMethodChooser(String leaseId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Manage Payment Methods',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: blueColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _paymentMethodOption(
              icon: Icons.credit_card,
              label: 'Add Card',
              onTap: () {
                Navigator.pop(dialogContext);
                _openAddCard(leaseId);
              },
            ),
            const SizedBox(height: 10),
            _paymentMethodOption(
              icon: Icons.account_balance,
              label: 'Add Bank Account (ACH)',
              onTap: () {
                Navigator.pop(dialogContext);
                _openAddAch(leaseId);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentMethodOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: blueColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: blueColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  String? get _tenantRentalId {
    final list = _leaseListForTab;
    if (list == null || list.isEmpty) return null;
    final activeLeaseId = _firstActiveLeaseId;
    if (activeLeaseId != null) {
      for (final l in list) {
        if (l.leaseId == activeLeaseId) {
          final id = l.rentalId?.toString().trim();
          if (id != null && id.isNotEmpty) return id;
        }
      }
    }
    for (final l in list) {
      final id = l.rentalId?.toString().trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  Widget _buildTenantWorkOrdersTab() {
    final rid = _tenantRentalId;
    if (rid == null || rid.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.45,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No Data Available',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ),
        ),
      );
    }
    final tabHeight =
        (MediaQuery.sizeOf(context).height - 220).clamp(320.0, 1200.0);
    return SizedBox(
      height: tabHeight,
      child: staff_workorder.Workorder_table(
        embeddedMode: true,
        rentalIdFilter: rid,
        showAddButton: false,
      ),
    );
  }

  List<MergedEmergencyContact> get _combinedEmergencyContacts =>
      getCombinedEmergencyContacts(_tenantDetails ?? widget.tenants);

  Widget _buildEmergencyContactSection() {
    final list = _combinedEmergencyContacts;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  "Emergency Contact (${list.length})",
                  style: TextStyle(
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              // Add button removed — emergency contacts are managed from the
              // Edit Tenant form; the details screen is read-only.
              // Material(
              //   color: blueColor,
              //   borderRadius: BorderRadius.circular(8),
              //   child: InkWell(
              //     onTap: () => _showEmergencyContactDialog(context, null),
              //     borderRadius: BorderRadius.circular(8),
              //     child: const Padding(
              //       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              //       child: Icon(Icons.add, color: Colors.white, size: 22),
              //     ),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF4F8FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBE0E5)),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(width: MediaQuery.of(context).size.width * .02),
                  Expanded(
                    flex: 2,
                    child: Text("     Contact Name",
                        style: TextStyle(
                            color: blueColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * .04),
                  Expanded(
                    flex: 2,
                    child: Text("Emergency Email",
                        style: TextStyle(
                            color: blueColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                  // Expanded(
                  //   child: Text("Email",
                  //       style: TextStyle(
                  //           color: blueColor,
                  //           fontSize: 13,
                  //           fontWeight: FontWeight.bold)),
                  // ),
                  // Expanded(
                  //   child: Text("Phone",
                  //       style: TextStyle(
                  //           color: blueColor,
                  //           fontSize: 13,
                  //           fontWeight: FontWeight.bold)),
                  // ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                  child: Text('No Data Available',
                      style: TextStyle(color: Colors.grey.shade600))),
            )
          else
            ...list.asMap().entries.map(
                (entry) => _buildEmergencyContactRow(entry.key, entry.value)),
        ],
      );
  }

  Widget _buildEmergencyContactRow(int index, MergedEmergencyContact c) {
    final isExpanded = expandedEmergencyIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: index % 2 != 0 ? const Color(0xFFF4F8FF) : Colors.white,
        border: Border.all(color: const Color(0xFFDBE0E5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (expandedEmergencyIndex == index) {
                        expandedEmergencyIndex = null;
                      } else {
                        expandedEmergencyIndex = index;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 5),
                    padding: !isExpanded
                        ? const EdgeInsets.only(bottom: 10)
                        : const EdgeInsets.only(top: 10),
                    child: FaIcon(
                      isExpanded
                          ? FontAwesomeIcons.sortUp
                          : FontAwesomeIcons.sortDown,
                      size: 20,
                      color: blueColor,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (expandedEmergencyIndex == index) {
                          expandedEmergencyIndex = null;
                        } else {
                          expandedEmergencyIndex = index;
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Text(
                        c.name.isEmpty ? '—' : c.name,
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * .02),
                Expanded(
                  flex: 2,
                  child: Text(
                    c.email.isEmpty ? '—' : c.email,
                    style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 25),
              ],
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * .02),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Relation : ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                  fontSize: 13),
                            ),
                            TextSpan(
                              text: '${c.relation.isEmpty ? '—' : c.relation}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(width: MediaQuery.of(context).size.width * .02),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Phone : ',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                  fontSize: 13),
                            ),
                            TextSpan(
                              text:
                                  '${c.phoneNumber.isEmpty ? '—' : formatPhoneNumber(c.phoneNumber)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Edit/Delete removed — emergency contacts are managed from
                  // the Edit Tenant form; the details screen is read-only.
                  /*
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () async =>
                            _showEmergencyContactDialog(context, c),
                        child: Container(
                          height: 35,
                          width: 35,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors
                                  .green.shade50), // color:Colors.grey[100],
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.edit,
                                size: 15,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      GestureDetector(
                        onTap: () => _confirmDeleteEmergencyContact(c),
                        child: Container(
                          height: 35,
                          width: 35,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.red.shade50),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              FaIcon(
                                FontAwesomeIcons.trashCan,
                                size: 15,
                                color: Colors.red,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                    ],
                  ),
                  */
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTenantInfoSection() {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    // Prefer freshly-fetched details so the card reflects edits immediately
    // (matches the Payment/Emergency sections in this screen).
    final t = _tenantDetails ?? widget.tenants;
    final phone = formatPhoneNumber(t?.tenantPhoneNumber ?? '');
    final email = (t?.tenantEmail ?? '').isEmpty
        ? '—'
        : (t?.tenantEmail ?? '');
    final birthDate = (t?.tenantBirthDate ?? '').isEmpty
        ? 'N/A'
        : dateProvider.formatCurrentDate(t?.tenantBirthDate ?? '');
    final notes = (t?.comments ?? '').isEmpty
        ? 'N/A'
        : (t?.comments ?? '');
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: blueColor, size: 22),
              const SizedBox(width: 8),
              Text("Tenant Information",
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child:
                      _tenantInfoField("Phone", phone.isEmpty ? '—' : phone)),
              const SizedBox(width: 16),
              Expanded(child: _tenantInfoField("Birth Date", birthDate)),
            ],
          ),
          const SizedBox(height: 16),
          _tenantInfoField("Email", email),
          const SizedBox(height: 16),
          _tenantInfoField("Notes", notes),
        ],
      );
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
    );
  }

  // Payment Options content (no card wrapper — sits inside the combined card).
  Widget _buildPaymentSection() {
    final t = _tenantDetails ?? widget.tenants;
    final allowAch = t?.allowAch != false;
    final allowCard = t?.allowCard != false;
    // Hidden only once we positively KNOW the owner declines ACH. A failed
    // settings call leaves _achSettingsFetched false, so the row stays.
    final showAchRow = !(_achSettingsFetched && !_leaseAchAccepted);
    final canEdit = t != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payment Options",
            style: TextStyle(
                color: blueColor, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 12),
        Text("Allowed Payment Methods",
            style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        const SizedBox(height: 8),
        // Web paints the ACH row first and removes it only once the
        // rental-owner settings come back saying ACH is not accepted — which
        // is why a lease-less tenant (no settings call possible) keeps it.
        // Visibility deliberately ignores the tenant's own tick, so unticking
        // ACH cannot hide the control that turns it back on.
        if (showAchRow) ...[
          Row(children: [
            SizedBox(
              width: 24,
              child: Checkbox(
                value: allowAch,
                onChanged: canEdit
                    ? (v) => _onPaymentAllowAchChanged(v == true)
                    : null,
                activeColor: blueColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Text("ACH",
                style: TextStyle(
                    color: allowAch ? blueColor : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 4),
        ],
        Row(children: [
          SizedBox(
            width: 24,
            child: Checkbox(
              value: allowCard,
              onChanged:
                  canEdit ? (v) => _onPaymentAllowCardChanged(v == true) : null,
              activeColor: blueColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 10),
          Text("Credit Card",
              style: TextStyle(
                  color: allowCard ? blueColor : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _openManagePaymentMethods,
            style: ElevatedButton.styleFrom(
              backgroundColor: blueColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Manage Payment Methods",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _tenantInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8A94A6),
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: blueColor, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  bool _sendingSetupEmail = false;

  Future<void> _sendSetupEmail() async {
    setState(() => _sendingSetupEmail = true);
    await repo.sendSetupEmail(widget.tenantId);
    if (mounted) setState(() => _sendingSetupEmail = false);
  }

  /// Formats an API timestamp the way web's `toLocaleString()` renders it
  /// (e.g. "7/15/2026, 6:22:35 PM"), converted to the device's local zone.
  String _formatAccountTimestamp(String raw) {
    try {
      return DateFormat('M/d/yyyy, h:mm:ss a')
          .format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  // Web-aligned "Account & Login" section: state-aware setup/resend/reset.
  Widget _buildAccountLoginSection() {
    // Read the DETAIL response first and only fall back to the list model:
    // has_password / password_set_at / welcome_email_sent_at come from
    // GET tenant_details (has_password is derived server-side there) and are
    // NOT in the tenants/v2 list payload. Reading widget.tenants alone made
    // every tenant look "never emailed", so the button showed "Send account
    // setup email" instead of "Resend setup email".
    final t = _tenantDetails ?? widget.tenants;
    final String passwordSetAt = (t?.passwordSetAt ?? '').trim();
    final bool hasPasswordFlag = t?.hasPassword == true;
    final String welcomeSentAt = (t?.welcomeEmailSentAt ?? '').trim();

    // Same 4-state priority as web's TenantDetailPage:
    //   1. password_set_at       -> reset (shows when it was set)
    //   2. has_password          -> reset (legacy rows with no timestamps)
    //   3. welcome_email_sent_at -> resend (emailed, setup not completed)
    //   4. none of the above     -> welcome (never emailed)
    final String buttonText;
    final String desc;
    if (passwordSetAt.isNotEmpty) {
      buttonText = 'Send password reset instructions';
      desc =
          'Password last set on ${_formatAccountTimestamp(passwordSetAt)}. Send the tenant a reset link if they cannot log in.';
    } else if (hasPasswordFlag) {
      buttonText = 'Send password reset instructions';
      desc =
          'This tenant already has a password on file. Send them a reset link if they cannot log in.';
    } else if (welcomeSentAt.isNotEmpty) {
      buttonText = 'Resend setup email';
      desc =
          'Setup email sent on ${_formatAccountTimestamp(welcomeSentAt)}. Tenant has not completed setup yet \u2014 send a fresh link.';
    } else {
      buttonText = 'Send account setup email';
      desc =
          'This tenant has never been emailed a setup link. Click to send the welcome email.';
    }
    // Web titles the card "Welcome Email" only in the never-emailed state.
    final String title =
        buttonText == 'Send account setup email' ? 'Welcome Email' : 'Reset Password';
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account & Login',
              style: TextStyle(
                  color: blueColor, fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Text(desc,
                    style: const TextStyle(
                        color: Color(0xFF8A94A6), fontSize: 14, height: 1.4)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _sendingSetupEmail ? null : _sendSetupEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blueColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _sendingSetupEmail
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: SpinKitFadingCircle(
                                color: Colors.white, size: 20))
                        : Text(buttonText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
  }

  // Kept for future reference — emergency edit/delete now lives in the Edit
  // Tenant form; the details screen is read-only.
  // ignore: unused_element
  void _confirmDeleteEmergencyContact(MergedEmergencyContact c) {
    if (c.contactId == 'primary') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Primary emergency contact cannot be deleted from here.")));
      return;
    }
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Delete emergency contact?",
      desc: "This contact will be removed from the list.",
      style: const AlertStyle(backgroundColor: Colors.white),
      buttons: [
        DialogButton(
          child: Text("Cancel",
              style: TextStyle(
                  color: blueColor, fontSize: 18, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(color: blueColor, width: 1.5),
        ),
        DialogButton(
          child: const Text("Delete",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await _tenantService.deleteEmergencyContact(
                  widget.tenantId, c.contactId);
              await _refreshTenantDetails();
              if (mounted) setState(() {});
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
              }
            }
          },
          color: Colors.red,
        ),
      ],
    ).show();
  }

  // Kept for future reference — add/edit dialog now lives in the Edit Tenant
  // form; the details screen is read-only.
  // ignore: unused_element
  void _showEmergencyContactDialog(
      BuildContext context, MergedEmergencyContact? editContact) {
    final isEdit = editContact != null;
    final initialName = editContact?.name.trim() ?? '';
    final initialRelation = editContact?.relation.trim() ?? '';
    final initialEmail = editContact?.email.trim() ?? '';
    final initialPhoneDigits =
        editContact?.phoneNumber.replaceAll(RegExp(r'\D'), '') ?? '';
    final nameController = TextEditingController(text: editContact?.name ?? '');
    final relationController =
        TextEditingController(text: editContact?.relation ?? '');
    final emailController =
        TextEditingController(text: editContact?.email ?? '');
    final phoneController = TextEditingController(
        text: isEdit ? formatPhoneNumberedit(editContact.phoneNumber) : '');
    final formKey = GlobalKey<FormState>();

    String? validateName(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      return null;
    }

    String? validateRelation(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      return null;
    }

    String? validateEmail(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      if (!EmailValidator.validate(value.trim())) {
        return "Enter a valid email";
      }
      return null;
    }

    String? validatePhone(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      final digits = value.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 10) return "Enter a valid 10-digit phone number";
      return null;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEdit ? "Edit Emergency Contact" : "Add Emergency Contact",
          style: TextStyle(
              color: blueColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Contact Name",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: "Enter contact name",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: validateName,
                ),
                const SizedBox(height: 16),
                const Text("Relationship to Tenant",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: relationController,
                  decoration: const InputDecoration(
                    hintText: "Enter relationship to tenant",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: validateRelation,
                ),
                const SizedBox(height: 16),
                const Text("Email",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: "Enter email",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                const Text("Phone Number",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberFormatter()],
                  decoration: const InputDecoration(
                    hintText: "(xxx) xxx-xxxx",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: validatePhone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL",
                style:
                    TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: blueColor),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) {
                if (!isEdit && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All fields are required")),
                  );
                }
                return;
              }
              final name = nameController.text.trim();
              final relation = relationController.text.trim();
              final email = emailController.text.trim();
              final phoneDigits =
                  phoneController.text.replaceAll(RegExp(r'\D'), '');
              final phone = formatPhoneNumberedit(phoneDigits);
              if (isEdit) {
                final currentPhoneDigits = phoneDigits;
                if (name == initialName &&
                    relation == initialRelation &&
                    email == initialEmail &&
                    currentPhoneDigits == initialPhoneDigits) {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No changes made")),
                    );
                  }
                  return;
                }
              }
              Navigator.pop(ctx);
              try {
                if (!isEdit) {
                  await _tenantService.addEmergencyContact(widget.tenantId,
                      name: name,
                      relation: relation,
                      email: email,
                      phoneNumber: phone);
                } else if (editContact.contactId == 'primary') {
                  await _tenantService.updateEmergencyContactPrimary(
                      widget.tenantId,
                      name: name,
                      relation: relation,
                      email: email,
                      phoneNumber: phone);
                } else {
                  await _tenantService.updateEmergencyContact(
                      widget.tenantId, editContact.contactId,
                      name: name,
                      relation: relation,
                      email: email,
                      phoneNumber: phone);
                }
                await _refreshTenantDetails();
                if (mounted) setState(() {});
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
                }
              }
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaseTabContent() {
    final list = _leaseListForTab;
    if (list == null || list.isEmpty) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height - 300,
        child: const Center(
          child: Text(
            'No lease data available for this tenant.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    final activeLeaseId = _firstActiveLeaseId;
    // TEMPORARY: previously showed empty state when no lease fell in the active
    // date window. Uncomment to restore "expired / not yet started" behavior.
    // if (activeLeaseId == null || activeLeaseId.isEmpty) {
    //   return SizedBox(
    //     height: MediaQuery.sizeOf(context).height - 300,
    //     child: const Center(
    //       child: Text(
    //         'No active lease. All leases are expired or not yet started.',
    //         style: TextStyle(fontSize: 13),
    //       ),
    //     ),
    //   );
    // }
    final TenantLeaseData activeLease;
    final String resolvedLeaseId;
    if (activeLeaseId != null && activeLeaseId.isNotEmpty) {
      activeLease = list.firstWhere((l) => l.leaseId == activeLeaseId);
      resolvedLeaseId = activeLeaseId;
    } else {
      // No "active" lease: still open lease summary (e.g. expired) for debugging / UX.
      activeLease = list.firstWhere(
        (l) => (l.leaseId ?? '').isNotEmpty,
        orElse: () => list.first,
      );
      resolvedLeaseId = activeLease.leaseId ?? widget.tenantId;
    }
    return SizedBox(
      height: MediaQuery.sizeOf(context).height - 300,
      child: SummeryPageLease(
        leaseId: resolvedLeaseId,
        enddate: activeLease.endDate,
        isredirectpayment: false,
        embeddedInTenantSummary: true,
      ),
    );
  }

  final List<String> itemsTenantLease = ['Residential', "Commercial", "All"];
  String? selectedValueTenantLease;
  String searchvalueTenantLease = "";
  void _showAddInsuranceAlert(BuildContext context, VoidCallback onConfirm) {
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Add New Insurance",
      desc:
          "If you add a new renter's insurance, the older one will get expired. Do you want to proceed?",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
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
        DialogButton(
          child: const Text(
            "Yes",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () {
            Navigator.pop(context); // Close the alert
            onConfirm(); // Execute the confirm action
          },
          color: Colors.red,
        ),
      ],
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      // appBar: widget302.,
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Tenants",
        dropdown: true,
      ),
      body: !isOffline
          ? Center(
              child: ListView(
                scrollDirection: Axis.vertical,
                children: [
                  const SizedBox(
                    height: 15,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.arrow_back_ios_new_sharp,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.tenants?.tenantFirstName ?? ''} ${widget.tenants?.tenantLastName ?? ''}'
                                    .trim(),
                                style: TextStyle(
                                  color: blueColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tenant',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8A95A8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.of(context)
                                        .push(MaterialPageRoute(
                                            builder: (context) => send_email(
                                                  lease: [
                                                    widget.tenants!.tenantId!
                                                  ],
                                                )));
                                  },
                                  child: Container(
                                    height: (MediaQuery.of(context).size.width <
                                            500)
                                        ? 35
                                        : MediaQuery.of(context).size.width *
                                            0.063,
                                    width: 100,
                                    decoration: BoxDecoration(
                                      color: blueColor,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "Send Mail",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14
                                              : 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    final updated = await Navigator.of(context)
                                        .push(MaterialPageRoute(
                                            builder: (context) => EditTenants(
                                                  tenantId: "",
                                                  tenants: widget.tenants!,
                                                )));
                                    // Reload summary after a successful edit so
                                    // the screen shows updated details immediately.
                                    if (updated == true && mounted) {
                                      await _refreshTenantDetails();
                                    }
                                  },
                                  child: Container(
                                    height: (MediaQuery.of(context).size.width <
                                            500)
                                        ? 35
                                        : MediaQuery.of(context).size.width *
                                            0.063,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      color: blueColor,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "Edit",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14
                                              : 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 5),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 15, right: 15, top: 4, bottom: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: Container(
                        height: 50.0,
                        padding: const EdgeInsets.only(top: 10, left: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5.0),
                          color: blueColor,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.grey,
                              offset: Offset(0.0, 1.0),
                              blurRadius: 6.0,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Summary',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildBalanceBadge(),
                  const SizedBox(height: 5),
                  _buildTenantSummaryTabDropdown(context),
                  // const SizedBox(
                  //   height: 20,
                  // ),
                  if (_tenantSummaryTabIndex == 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 5, right: 5),
                      child: Material(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          // decoration: BoxDecoration(
                          //   color: Colors.white,
                          //   borderRadius: BorderRadius.circular(10),
                          //   border: Border.all(color: blueColor),
                          // ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 10, right: 10, top: 2, bottom: 30),
                            child: Column(
                              children: [
                                //tenant info table

                                // Container(
                                //   padding: const EdgeInsets.all(16.0),
                                //   decoration: BoxDecoration(
                                //     border:
                                //         Border.all(color: Colors.grey.shade300),
                                //     borderRadius: BorderRadius.circular(12.0),
                                //   ),
                                //   child: Column(
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Contact Information',
                                //         style: TextStyle(
                                //             color: blueColor,
                                //             fontWeight: FontWeight.bold,
                                //             // fontSize: 18
                                //             fontSize: MediaQuery.of(context)
                                //                     .size
                                //                     .width *
                                //                 .045),
                                //       ),
                                //       const SizedBox(height: 16),
                                //       Row(
                                //         children: [
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('Name',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.tenantFirstName ?? '').isEmpty ? 'N/A' : widget.tenants?.tenantFirstName}',
                                //                   style: TextStyle(
                                //                       color:
                                //                           Colors.grey.shade700),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //           const Spacer(),
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('Phone Number',
                                //                     style: TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Color(0xFF101828),
                                //                     )),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   formatPhoneNumber(
                                //                       '${widget.tenants?.tenantPhoneNumber ?? 'N/A'}'),
                                //                   style: TextStyle(
                                //                       color:
                                //                           Colors.grey.shade700),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //         ],
                                //       ),
                                //       const SizedBox(height: 16),
                                //       Column(
                                //         crossAxisAlignment:
                                //             CrossAxisAlignment.start,
                                //         children: [
                                //           const Text('E-Mail Address',
                                //               style: TextStyle(
                                //                   fontWeight: FontWeight.bold,
                                //                   color: Color(0xFF101828))),
                                //           const SizedBox(height: 4),
                                //           Text(
                                //             '${(widget.tenants?.tenantEmail ?? '').isEmpty ? 'N/A' : widget.tenants?.tenantEmail}',
                                //             style: TextStyle(
                                //                 color: Colors.grey.shade700),
                                //           ),
                                //         ],
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                // const SizedBox(
                                //   height: 10,
                                // ),
                                // Container(
                                //   padding: const EdgeInsets.all(16),
                                //   decoration: BoxDecoration(
                                //     border:
                                //         Border.all(color: Colors.grey.shade300),
                                //     borderRadius: BorderRadius.circular(12),
                                //   ),
                                //   child: Column(
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         "Personal Information",
                                //         style: TextStyle(
                                //             color: blueColor,
                                //             fontWeight: FontWeight.bold,
                                //             // fontSize: 18
                                //             fontSize: MediaQuery.of(context)
                                //                     .size
                                //                     .width *
                                //                 .045),
                                //       ),
                                //       const SizedBox(height: 20),

                                //       // Birth Date & TaxPayer ID side-by-side
                                //       Row(
                                //         children: [
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('Birth Date',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.tenantBirthDate ?? '').isEmpty ? 'N/A' : dateProvider.formatCurrentDate('${widget.tenants?.tenantBirthDate}')}',
                                //                   style: const TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Colors.grey),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //           const Spacer(),
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('TaxPayer Id',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.taxPayerId ?? '').isEmpty ? 'N/A' : widget.tenants?.taxPayerId}',
                                //                   style: const TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Colors.grey),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //         ],
                                //       ),

                                //       const SizedBox(height: 20),

                                //       // Comments field full width
                                //       Column(
                                //         crossAxisAlignment:
                                //             CrossAxisAlignment.start,
                                //         children: [
                                //           const Text('Comments',
                                //               style: TextStyle(
                                //                   fontWeight: FontWeight.bold,
                                //                   color: Color(0xFF101828))),
                                //           const SizedBox(height: 4),
                                //           Text(
                                //             '${(widget.tenants?.comments ?? '').isEmpty ? 'N/A' : widget.tenants?.comments}',
                                //             style: const TextStyle(
                                //                 fontWeight: FontWeight.bold,
                                //                 color: Colors.grey),
                                //           ),
                                //         ],
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                // const SizedBox(
                                //   height: 10,
                                // ),
                                // Container(
                                //   padding: const EdgeInsets.all(16),
                                //   decoration: BoxDecoration(
                                //     border:
                                //         Border.all(color: Colors.grey.shade300),
                                //     borderRadius: BorderRadius.circular(12),
                                //   ),
                                //   child: Column(
                                //     crossAxisAlignment:
                                //         CrossAxisAlignment.start,
                                //     children: [
                                //       Text(
                                //         'Emergency Contact',
                                //         style: TextStyle(
                                //             color: blueColor,
                                //             fontWeight: FontWeight.bold,
                                //             // fontSize: 18
                                //             fontSize: MediaQuery.of(context)
                                //                     .size
                                //                     .width *
                                //                 .045),
                                //       ),
                                //       const SizedBox(height: 20),
                                //       // Contact Name & Relation side-by-side
                                //       Row(
                                //         children: [
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('Contact Name',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.emergencyContact?.name ?? '').isEmpty ? 'N/A' : widget.tenants?.emergencyContact!.name}',
                                //                   style: const TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Colors.grey),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //           const Spacer(),
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text(
                                //                     'Relation With Tenant',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.emergencyContact?.relation ?? '').isEmpty ? 'N/A' : widget.tenants?.emergencyContact!.relation}',
                                //                   style: const TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Colors.grey),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //         ],
                                //       ),
                                //       const SizedBox(height: 20),
                                //       // Email & Phone side-by-side
                                //       Row(
                                //         children: [
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('Emergency Email',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.emergencyContact?.email ?? '').isEmpty ? 'N/A' : widget.tenants?.emergencyContact!.email}',
                                //                   style: const TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Colors.grey),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //           const Spacer(),
                                //           Expanded(
                                //             child: Column(
                                //               crossAxisAlignment:
                                //                   CrossAxisAlignment.start,
                                //               children: [
                                //                 const Text('Emergency Phone',
                                //                     style: TextStyle(
                                //                         fontWeight:
                                //                             FontWeight.bold,
                                //                         color:
                                //                             Color(0xFF101828))),
                                //                 const SizedBox(height: 4),
                                //                 Text(
                                //                   '${(widget.tenants?.emergencyContact?.phoneNumber ?? '').isEmpty ? 'N/A' : formatPhoneNumber(widget.tenants?.emergencyContact!.phoneNumber ?? "")}',
                                //                   style: const TextStyle(
                                //                       fontWeight:
                                //                           FontWeight.bold,
                                //                       color: Colors.grey),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //         ],
                                //       ),
                                //     ],
                                //   ),
                                // ),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildTenantInfoSection(),
                                      _sectionDivider(),
                                      _buildPaymentSection(),
                                      _sectionDivider(),
                                      _buildEmergencyContactSection(),
                                      _sectionDivider(),
                                      _buildAccountLoginSection(),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(width: 2),
                                          Text(
                                            "Lease Details",
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        // padding: const EdgeInsets.symmetric(
                                        //     horizontal: 10.0),
                                        child: FutureBuilder<
                                            List<TenantLeaseData>>(
                                          future: futurePropertyLease,
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return Container(
                                                constraints:
                                                    const BoxConstraints(
                                                        minHeight: 140),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 24),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      SpinKitFadingCircle(
                                                          color: blueColor,
                                                          size: 36.0),
                                                      const SizedBox(
                                                          height: 12),
                                                      Text(
                                                          'Loading lease details...',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey
                                                                  .shade600)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            } else if (snapshot.hasError) {
                                              return Center(
                                                  child: Text(
                                                      friendlyErrorMessage(snapshot.error)));
                                            } else if (!snapshot.hasData ||
                                                snapshot.data!.isEmpty) {
                                              return Container(
                                                  height: 80,
                                                  child: const Center(
                                                      child: Text(
                                                          'No Data Available')));
                                            } else {
                                              var data = snapshot.data!;

                                              if (selectedValueTenantLease ==
                                                      null &&
                                                  searchvalueTenantLease!
                                                      .isEmpty) {
                                                data = snapshot.data!;
                                              } else if (selectedValueTenantLease ==
                                                  "All") {
                                                data = snapshot.data!;
                                              } else if (searchvalueTenantLease!
                                                  .isNotEmpty) {
                                                data = snapshot.data!
                                                    .where((property) =>
                                                        (property.startDate ?? '')
                                                        .toLowerCase()
                                                        .contains(
                                                            searchvalueTenantLease
                                                                .toLowerCase()))
                                                    .toList();
                                              }
                                              if (data.length == 0) {
                                                return const Column(
                                                  children: [
                                                    SizedBox(
                                                      height: 15,
                                                    ),
                                                    Center(
                                                      child:
                                                          Text('No Data Available'),
                                                    ),
                                                  ],
                                                );
                                              }
                                              sortDataTenantLease(data);
                                              final totalPages = (data.length /
                                                      itemsPerPageTenantLease)
                                                  .ceil();
                                              final currentPageData = data
                                                  .skip(currentPageTenantLease *
                                                      itemsPerPageTenantLease)
                                                  .take(itemsPerPageTenantLease)
                                                  .toList();
                                              return SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    const SizedBox(height: 20),
                                                    _buildHeaders_lease(),
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      // decoration: BoxDecoration(
                                                      //     border: Border.all(
                                                      //         color: Color
                                                      //             .fromRGBO(
                                                      //                 152,
                                                      //                 162,
                                                      //                 179,
                                                      //                 .5))),
                                                      // decoration: BoxDecoration(
                                                      //     border: Border.all(
                                                      //         color: blueColor)),
                                                      child: Column(
                                                        children:
                                                            currentPageData
                                                                .asMap()
                                                                .entries
                                                                .map((entry) {
                                                          int index = entry.key;
                                                          bool
                                                              isExpandedTenantLease =
                                                              expandedTenantLeaseIndex ==
                                                                  index;
                                                          TenantLeaseData
                                                              Propertytype =
                                                              entry.value;
                                                          //return CustomExpansionTile(data: Propertytype, index: index);
                                                          return Container(
                                                            margin:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        5),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: index %
                                                                          2 !=
                                                                      0
                                                                  ? const Color(
                                                                      0xFFF4F8FF)
                                                                  : Colors
                                                                      .white,
                                                              border: Border.all(
                                                                  color: const Color(
                                                                      0xFFDBE0E5)),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10),
                                                            ),
                                                            // decoration: BoxDecoration(
                                                            //   border: Border.all(
                                                            //       color: blueColor),
                                                            // ),
                                                            child: Column(
                                                              children: <Widget>[
                                                                ListTile(
                                                                  contentPadding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  title:
                                                                      Padding(
                                                                    padding:
                                                                        const EdgeInsets
                                                                            .all(
                                                                            2.0),
                                                                    child: Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .start,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .center,
                                                                      children: <Widget>[
                                                                        SizedBox(
                                                                            width:
                                                                                MediaQuery.of(context).size.width * .02),
                                                                        InkWell(
                                                                          onTap:
                                                                              () {
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
                                                                              if (expandedTenantLeaseIndex == index) {
                                                                                expandedTenantLeaseIndex = null;
                                                                              } else {
                                                                                expandedTenantLeaseIndex = index;
                                                                              }
                                                                            });
                                                                          },
                                                                          child:
                                                                              Container(
                                                                            margin:
                                                                                const EdgeInsets.only(left: 5),
                                                                            padding: !isExpandedTenantLease
                                                                                ? const EdgeInsets.only(bottom: 10)
                                                                                : const EdgeInsets.only(top: 10),
                                                                            child:
                                                                                FaIcon(
                                                                              isExpandedTenantLease ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                              size: 20,
                                                                              color: blueColor,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Expanded(
                                                                          flex: 2,
                                                                          child:
                                                                              InkWell(
                                                                            onTap:
                                                                                () {
                                                                              setState(() {
                                                                                if (expandedTenantLeaseIndex == index) {
                                                                                  expandedTenantLeaseIndex = null;
                                                                                } else {
                                                                                  expandedTenantLeaseIndex = index;
                                                                                }
                                                                              });
                                                                            },
                                                                            child:
                                                                                Padding(
                                                                              padding: const EdgeInsets.only(left: 5.0),
                                                                              child: Text(
                                                                                '${determineStatus(Propertytype.startDate, Propertytype.endDate)}',
                                                                                style: TextStyle(
                                                                                  color: blueColor,
                                                                                  fontWeight: FontWeight.bold,
                                                                                  fontSize: 13,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(width: 15),
                                                                        Expanded(
                                                                          flex: 2,
                                                                          child: Text(
                                                                            '${Propertytype.rentalAdress ?? ''}',
                                                                            style: TextStyle(
                                                                              color: blueColor,
                                                                              fontWeight: FontWeight.bold,
                                                                              fontSize: 12,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(width: 25),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                                if (isExpandedTenantLease)
                                                                  Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            8.0),
                                                                    margin: const EdgeInsets
                                                                        .only(
                                                                        bottom:
                                                                            20),
                                                                    child:
                                                                        SingleChildScrollView(
                                                                      child:
                                                                          Column(
                                                                        children: [
                                                                          Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.start,
                                                                            children: [
                                                                              FaIcon(
                                                                                isExpandedTenantLease ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                                size: 20,
                                                                                color: Colors.transparent,
                                                                              ),
                                                                              Expanded(
                                                                                child: Column(
                                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                                  children: <Widget>[
                                                                                    Text.rich(
                                                                                      TextSpan(
                                                                                        children: [
                                                                                          TextSpan(
                                                                                            text: 'Start Date : ',
                                                                                            style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                                                                                          ),
                                                                                          TextSpan(
                                                                                            text: dateProvider.formatCurrentDate(normalizeDateForDisplay(Propertytype.startDate)),
                                                                                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(height: 10),
                                                                                    Text.rich(
                                                                                      TextSpan(
                                                                                        children: [
                                                                                          TextSpan(
                                                                                            text: 'End Date : ',
                                                                                            style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                                                                                          ),
                                                                                          TextSpan(
                                                                                            // Web parity: month-to-month leases carry a
                                                                                            // far-future sentinel end date — show "ongoing".
                                                                                            text: _displayEndDate(_currentTerm(Propertytype.leaseId)?.endDate ?? Propertytype.endDate, dateProvider),
                                                                                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                                                                                          ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                    const SizedBox(height: 10),
                                                                                    Row(
                                                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                                                      children: [
                                                                                        Flexible(
                                                                                          child: Text.rich(
                                                                                            TextSpan(
                                                                                              children: [
                                                                                                TextSpan(
                                                                                                  text: 'Type : ',
                                                                                                  style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                                ),
                                                                                                TextSpan(
                                                                                                  text: _currentTerm(Propertytype.leaseId)?.leaseType ?? '${Propertytype.leaseType}',
                                                                                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey), // Light and grey
                                                                                                ),
                                                                                              ],
                                                                                            ),
                                                                                          ),
                                                                                        ),
                                                                                        // Web parity: mark a term the server estimated from rent
                                                                                        // history rather than one it has on record.
                                                                                        if (_currentTerm(Propertytype.leaseId)?.isInferred == true)
                                                                                          _inferredBadge(),
                                                                                      ],
                                                                                    ),
                                                                                    const SizedBox(
                                                                                      height: 10,
                                                                                    ),
                                                                                    Text.rich(
                                                                                      TextSpan(
                                                                                        children: [
                                                                                          TextSpan(
                                                                                            text: 'Rent Amount : ',
                                                                                            style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                          ),
                                                                                          TextSpan(
                                                                                            text: formatCurrency(Propertytype.rentAmount),
                                                                                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey), // Light and grey
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
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Renter’s Insurance Policy',
                                            style: TextStyle(
                                              color: blueColor,
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () async {
                                              // Match web/Admin: open the add
                                              // insurance form regardless of
                                              // lease (no "No lease found" gate).
                                              final result =
                                                  await Navigator.of(context)
                                                      .push(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AdminAddTenantInsurance(
                                                    tenantid: widget.tenantId,
                                                    leaseId:
                                                        _leaseIdForAddCard ??
                                                            widget.tenantId,
                                                    tenantName:
                                                        '${widget.tenants?.tenantFirstName ?? ''} ${widget.tenants?.tenantLastName ?? ''}'
                                                            .trim(),
                                                  ),
                                                ),
                                              );
                                              if (result == true && mounted)
                                                setState(() {
                                                  futureRenterPolicies =
                                                      _fetchRenterPolicies();
                                                });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                color: blueColor,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      _buildShowDeletedToggle(),
                                      // if (MediaQuery.of(context).size.width < 500)
                                      //   const SizedBox(height: 5),

                                      if (MediaQuery.of(context).size.width >
                                          500)
                                        const SizedBox(height: 25),
                                      if (MediaQuery.of(context).size.width <
                                          500)
                                        Container(
                                          // padding: const EdgeInsets.symmetric(
                                          //     horizontal: 10.0),
                                          child: FutureBuilder<
                                              List<lease_renter_insurance>>(
                                            future: futureRenterPolicies,
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                          minHeight: 140),
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 24),
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        SpinKitFadingCircle(
                                                            color: blueColor,
                                                            size: 36.0),
                                                        const SizedBox(
                                                            height: 12),
                                                        Text(
                                                            'Loading Renter\'s Insurance...',
                                                            style: TextStyle(
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .grey
                                                                    .shade600)),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              } else if (snapshot.hasError) {
                                                return Center(
                                                    child: Text(
                                                        friendlyErrorMessage(snapshot.error)));
                                              } else if (!snapshot.hasData ||
                                                  snapshot.data!.isEmpty) {
                                                return Column(
                                                  children: [
                                                    const SizedBox(height: 10),
                                                    _buildHeaders(),
                                                    const SizedBox(height: 20),
                                                    const Center(child: Text('No Data Available')),
                                                  ],
                                                );
                                              } else {
                                                var data = (snapshot.data!
                                                        as List<lease_renter_insurance>)
                                                    .where(_isPolicyVisible)
                                                    .toList();
                                                if (searchvalue!.isNotEmpty) {
                                                  data = data
                                                      .where((p) =>
                                                          (p.insuranceCompany ?? '')
                                                              .toLowerCase()
                                                              .contains(searchvalue!.toLowerCase()))
                                                      .toList();
                                                }
                                                if (data.isEmpty) {
                                                  return Column(
                                                    children: [
                                                      const SizedBox(height: 10),
                                                      _buildHeaders(),
                                                      const SizedBox(height: 20),
                                                      const Center(child: Text('No Data Available')),
                                                    ],
                                                  );
                                                }
                                                sortData(data);
                                                final totalPages =
                                                    (data.length / itemsPerPage)
                                                        .ceil();
                                                final currentPageData = data
                                                    .skip(currentPage *
                                                        itemsPerPage)
                                                    .take(itemsPerPage)
                                                    .toList();
                                                return SingleChildScrollView(
                                                  child: Column(
                                                    children: [
                                                      const SizedBox(
                                                          height: 10),
                                                      _buildHeaders(),
                                                      const SizedBox(
                                                          height: 10),
                                                      Container(
                                                        // decoration: BoxDecoration(
                                                        //     border: Border.all(
                                                        //         color: Color
                                                        //             .fromRGBO(
                                                        //                 152,
                                                        //                 162,
                                                        //                 179,
                                                        //                 .5))),
                                                        // decoration: BoxDecoration(
                                                        //     border: Border.all(
                                                        //         color: blueColor)),
                                                        child: Column(
                                                          children:
                                                              currentPageData
                                                                  .asMap()
                                                                  .entries
                                                                  .map((entry) {
                                                            int index =
                                                                entry.key;
                                                            bool isExpanded =
                                                                expandedIndex ==
                                                                    index;
                                                            lease_renter_insurance
                                                                policy =
                                                                entry.value;
                                                            // Web parity: soft-deleted policies are greyed + struck through,
                                                            // and their Edit/Delete actions are hidden.
                                                            final bool
                                                                isDeleted =
                                                                policy.isDelete ==
                                                                    true;
                                                            final TextDecoration?
                                                                rowDecoration =
                                                                isDeleted
                                                                    ? TextDecoration
                                                                        .lineThrough
                                                                    : null;
                                                            return Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      vertical:
                                                                          5),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: index %
                                                                            2 !=
                                                                        0
                                                                    ? const Color(
                                                                        0xFFF4F8FF)
                                                                    : Colors
                                                                        .white,
                                                                border: Border.all(
                                                                    color: const Color(
                                                                        0xFFDBE0E5)),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                              ),
                                                              child: Column(
                                                                children: <Widget>[
                                                                  ListTile(
                                                                    contentPadding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    title:
                                                                        Padding(
                                                                      padding: const EdgeInsets
                                                                          .all(
                                                                          2.0),
                                                                      child:
                                                                          Row(
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.start,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.center,
                                                                        children: <Widget>[
                                                                          InkWell(
                                                                            onTap:
                                                                                () {
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
                                                                                if (expandedIndex == index) {
                                                                                  expandedIndex = null;
                                                                                } else {
                                                                                  expandedIndex = index;
                                                                                }
                                                                              });
                                                                            },
                                                                            child:
                                                                                Container(
                                                                              margin: const EdgeInsets.only(left: 5),
                                                                              padding: !isExpanded ? const EdgeInsets.only(bottom: 10) : const EdgeInsets.only(top: 10),
                                                                              child: FaIcon(
                                                                                isExpanded ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                                size: 20,
                                                                                color: blueColor,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          Expanded(
                                                                            flex: 2,
                                                                            child:
                                                                                InkWell(
                                                                              onTap: () {
                                                                                // Navigator.of(context)
                                                                                //     .push(MaterialPageRoute(builder: (context) => summery_page(lease_id: Propertytype.leaseId,)));
                                                                              },
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.only(left: 5.0),
                                                                                child: Row(
                                                                                  children: [
                                                                                    Flexible(
                                                                                      child: Text(
                                                                                        '${policy.insuranceCompany ?? ''}',
                                                                                        style: TextStyle(
                                                                                          color: isDeleted ? Colors.grey : blueColor,
                                                                                          decoration: rowDecoration,
                                                                                          fontWeight: FontWeight.bold,
                                                                                          fontSize: 13,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                    if (isDeleted) _buildDeletedBadge(),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(width: 20),
                                                                          Expanded(
                                                                            flex: 2,
                                                                            child: Text(
                                                                              '${policy.policyId ?? ''}',
                                                                              style: TextStyle(
                                                                                color: isDeleted ? Colors.grey : blueColor,
                                                                                decoration: rowDecoration,
                                                                                fontWeight: FontWeight.bold,
                                                                                fontSize: 12,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          const SizedBox(width: 25),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  if (isExpanded)
                                                                    Container(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              8.0),
                                                                      margin: const EdgeInsets
                                                                          .only(
                                                                          bottom:
                                                                              5),
                                                                      child:
                                                                          SingleChildScrollView(
                                                                        child:
                                                                            Column(
                                                                          children: [
                                                                            Row(
                                                                              mainAxisAlignment: MainAxisAlignment.start,
                                                                              children: [
                                                                                FaIcon(
                                                                                  isExpanded ? FontAwesomeIcons.sortUp : FontAwesomeIcons.sortDown,
                                                                                  size: 20,
                                                                                  color: Colors.transparent,
                                                                                ),
                                                                                Expanded(
                                                                                  child: Column(
                                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                                    children: <Widget>[
                                                                                      Text.rich(
                                                                                        TextSpan(
                                                                                          children: [
                                                                                            TextSpan(
                                                                                              text: 'Liability Coverage : ',
                                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                            ),
                                                                                            TextSpan(
                                                                                              text: formatMoney(policy.liabilityCoverage),
                                                                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey), // Light and grey
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                      const SizedBox(
                                                                                        height: 10,
                                                                                      ),
                                                                                      Text.rich(
                                                                                        TextSpan(
                                                                                          children: [
                                                                                            TextSpan(
                                                                                              text: 'Status : ',
                                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor), // Bold and black
                                                                                            ),
                                                                                            TextSpan(
                                                                                              text: '${policy.policyStatus ?? ''}',
                                                                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey), // Light and grey
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                      const SizedBox(
                                                                                        height: 10,
                                                                                      ),
                                                                                      Text.rich(
                                                                                        TextSpan(
                                                                                          children: [
                                                                                            TextSpan(
                                                                                              text: 'Effective Date : ',
                                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                                                                                            ),
                                                                                            TextSpan(
                                                                                              text: dateProvider.formatCurrentDate('${policy.effectiveDate ?? ''}'),
                                                                                              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                      ),
                                                                                      const SizedBox(height: 10),
                                                                                      Text.rich(
                                                                                        TextSpan(
                                                                                          children: [
                                                                                            TextSpan(
                                                                                              text: 'Expiration Date : ',
                                                                                              style: TextStyle(fontWeight: FontWeight.bold, color: blueColor),
                                                                                            ),
                                                                                            TextSpan(
                                                                                              text: dateProvider.formatCurrentDate('${policy.expirationDate ?? ''}'),
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
                                                                            const SizedBox(
                                                                              height: 10,
                                                                            ),
                                                                            /* Container(
                                                                      width:
                                                                      40,
                                                                      child:
                                                                      Row(
                                                                        children: [
                                                                          Expanded(
                                                                            child: IconButton(
                                                                              icon: FaIcon(
                                                                                FontAwesomeIcons.edit,
                                                                                size: 20,
                                                                                color: blueColor,
                                                                              ),
                                                                              onPressed: () async {
                                                                                // handleEdit(Propertytype);

                                                                                var check = await Navigator.push(
                                                                                    context,
                                                                                    MaterialPageRoute(
                                                                                        builder: (context) => EditRentersInsurance(
                                                                                          tenantid: widget.tenantId,
                                                                                          leaseId: policy.leaseId ?? '',
                                                                                          renters_insurance_id: policy.rentersInsuranceId!,
                                                                                          embeddedInTenantSummary: true,
                                                                                        )));
                                                                                if (check == true) {
                                                                                  setState(() {
                                                                                    futureRenterPolicies = _fetchRenterPolicies();
                                                                                  });
                                                                                }
                                                                              },
                                                                            ),
                                                                          ),
                                                                          Expanded(
                                                                            child: IconButton(
                                                                              icon: FaIcon(
                                                                                FontAwesomeIcons.trashCan,
                                                                                size: 20,
                                                                                color: blueColor,
                                                                              ),
                                                                              onPressed: () {
                                                                                //handleDelete(Propertytype);
                                                                                _showRenterInsuranceDeleteAlert(context, policy.rentersInsuranceId!);
                                                                              },
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),*/
                                                                            const SizedBox(
                                                                              height: 10,
                                                                            ),
                                                                            Row(
                                                                              mainAxisAlignment: MainAxisAlignment.end,
                                                                              children: [
                                                                                // Web parity: a deleted policy is read-only — no Edit/Delete.
                                                                                if (!isDeleted)
                                                                                GestureDetector(
                                                                                  onTap: () async {
                                                                                    // handleEdit(Propertytype);

                                                                                    var check = await Navigator.push(
                                                                                        context,
                                                                                        MaterialPageRoute(
                                                                                            builder: (context) => EditRentersInsurance(
                                                                                                  tenantid: widget.tenantId,
                                                                                                  leaseId: policy.leaseId ?? '',
                                                                                                  renters_insurance_id: policy.rentersInsuranceId!,
                                                                                                  embeddedInTenantSummary: true,
                                                                                                )));
                                                                                    if (check == true) {
                                                                                      setState(() {
                                                                                        futureRenterPolicies = _fetchRenterPolicies();
                                                                                      });
                                                                                    }
                                                                                  },
                                                                                  child: Container(
                                                                                    height: 35,
                                                                                    width: 35,
                                                                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.green.shade50), // color:Colors.grey[100],
                                                                                    child: const Row(
                                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                                                      children: [
                                                                                        FaIcon(
                                                                                          FontAwesomeIcons.edit,
                                                                                          size: 15,
                                                                                          color: Colors.green,
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                if (!isDeleted)
                                                                                const SizedBox(
                                                                                  width: 10,
                                                                                ),
                                                                                if (!isDeleted)
                                                                                GestureDetector(
                                                                                  onTap: () {
                                                                                    _showRenterInsuranceDeleteAlert(context, policy.rentersInsuranceId!);
                                                                                  },
                                                                                  child: Container(
                                                                                    height: 35,
                                                                                    width: 35,
                                                                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.red.shade50),
                                                                                    child: const Row(
                                                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                                                      children: [
                                                                                        FaIcon(
                                                                                          FontAwesomeIcons.trashCan,
                                                                                          size: 15,
                                                                                          color: Colors.red,
                                                                                        ),
                                                                                      ],
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(
                                                                                  width: 5,
                                                                                ),
                                                                              ],
                                                                            ),

                                                                            const SizedBox(
                                                                              height: 5,
                                                                            ),
                                                                            // Row(
                                                                            //   //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                            //   children: [
                                                                            //     // Expanded(
                                                                            //     //   child: GestureDetector(
                                                                            //     //     onTap: () async {
                                                                            //     //       var check = await Navigator.push(
                                                                            //     //           context,
                                                                            //     //           MaterialPageRoute(
                                                                            //     //               builder: (context) => editAdminInsurance(
                                                                            //     //                 data: Propertytype,
                                                                            //     //               )));
                                                                            //     //       if (check == true) {
                                                                            //     //         setState(() {
                                                                            //     //           futurePropertyTypes = AdminTenantInsuranceRepository().fetchTenantInsurance(widget.tenantId);
                                                                            //     //         });
                                                                            //     //       }
                                                                            //     //     },
                                                                            //     //     child: Container(
                                                                            //     //       height: 40,
                                                                            //     //       decoration: BoxDecoration(
                                                                            //     //           color: Colors
                                                                            //     //               .grey[
                                                                            //     //           350]), // color:Colors.grey[100],
                                                                            //     //       child: Row(
                                                                            //     //         mainAxisAlignment:
                                                                            //     //         MainAxisAlignment
                                                                            //     //             .center,
                                                                            //     //         crossAxisAlignment:
                                                                            //     //         CrossAxisAlignment
                                                                            //     //             .center,
                                                                            //     //         children: [
                                                                            //     //           FaIcon(
                                                                            //     //             FontAwesomeIcons
                                                                            //     //                 .edit,
                                                                            //     //             size: 15,
                                                                            //     //             color:
                                                                            //     //             blueColor,
                                                                            //     //           ),
                                                                            //     //           SizedBox(
                                                                            //     //             width: 10,
                                                                            //     //           ),
                                                                            //     //           Text(
                                                                            //     //             "Edit",
                                                                            //     //             style: TextStyle(
                                                                            //     //                 color:
                                                                            //     //                 blueColor,
                                                                            //     //                 fontWeight:
                                                                            //     //                 FontWeight
                                                                            //     //                     .bold),
                                                                            //     //           ),
                                                                            //     //         ],
                                                                            //     //       ),
                                                                            //     //     ),
                                                                            //     //   ),
                                                                            //     // ),
                                                                            //     // SizedBox(
                                                                            //     //   width: 5,
                                                                            //     // ),
                                                                            //
                                                                            //     Expanded(
                                                                            //       child: GestureDetector(
                                                                            //         onTap: () {
                                                                            //           _showAlert(context, Propertytype.tenantInsuranceId!);
                                                                            //         },
                                                                            //         child: Container(
                                                                            //           height: 40,
                                                                            //           decoration: BoxDecoration(color: Colors.grey[350]),
                                                                            //           child: Row(
                                                                            //             mainAxisAlignment: MainAxisAlignment.center,
                                                                            //             crossAxisAlignment: CrossAxisAlignment.center,
                                                                            //             children: [
                                                                            //               FaIcon(
                                                                            //                 FontAwesomeIcons.trashCan,
                                                                            //                 size: 15,
                                                                            //                 color: blueColor,
                                                                            //               ),
                                                                            //               SizedBox(
                                                                            //                 width: 10,
                                                                            //               ),
                                                                            //               Text(
                                                                            //                 "Delete",
                                                                            //                 style: TextStyle(color: blueColor, fontWeight: FontWeight.bold),
                                                                            //               )
                                                                            //             ],
                                                                            //           ),
                                                                            //         ),
                                                                            //       ),
                                                                            //     ),
                                                                            //   ],
                                                                            // ),
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
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      if (MediaQuery.of(context).size.width >
                                          500)
                                        FutureBuilder<
                                            List<lease_renter_insurance>>(
                                          future: futureRenterPolicies,
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return Container(
                                                constraints:
                                                    const BoxConstraints(
                                                        minHeight: 160),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 32),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      SpinKitFadingCircle(
                                                          color: blueColor,
                                                          size: 40.0),
                                                      const SizedBox(
                                                          height: 14),
                                                      Text(
                                                          'Loading Renter\'s Insurance...',
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color: Colors.grey
                                                                  .shade600)),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            } else if (snapshot.hasError) {
                                              return Center(
                                                  child: Text(
                                                      friendlyErrorMessage(snapshot.error)));
                                            } else if (!snapshot.hasData ||
                                                snapshot.data!.isEmpty) {
                                              return const Center(
                                                  child: Text(
                                                      'No Data Available'));
                                            } else {
                                              _tableData = (snapshot.data!
                                                      as List<
                                                          lease_renter_insurance>)
                                                  .where(_isPolicyVisible)
                                                  .toList();

                                              totalrecords = _tableData.length;
                                              return SingleChildScrollView(
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal:
                                                                    20.0,
                                                                vertical: 5),
                                                        child: Column(
                                                          children: [
                                                            SingleChildScrollView(
                                                              scrollDirection:
                                                                  Axis.horizontal,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            20),
                                                                child: Table(
                                                                  defaultColumnWidth:
                                                                      const IntrinsicColumnWidth(),
                                                                  children: [
                                                                    TableRow(
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        border: Border.all(
                                                                            // color: blueColor
                                                                            ),
                                                                      ),
                                                                      children: [
                                                                        _buildHeader(
                                                                            'Insurance Company',
                                                                            0,
                                                                            null),

                                                                        _buildHeader(
                                                                            'Policy Id',
                                                                            2,
                                                                            null),
                                                                        _buildHeader(
                                                                            'Liability Coverage',
                                                                            2,
                                                                            null),
                                                                        _buildHeader(
                                                                            'Status',
                                                                            2,
                                                                            null),
                                                                        _buildHeader(
                                                                            'Effective Date',
                                                                            2,
                                                                            null),
                                                                        _buildHeader(
                                                                            'Expiration Date',
                                                                            3,
                                                                            null),
                                                                        _buildHeader(
                                                                            'Actions',
                                                                            3,
                                                                            null),
                                                                        // _buildHeader('Actions', 4, null),
                                                                      ],
                                                                    ),
                                                                    TableRow(
                                                                      decoration:
                                                                          const BoxDecoration(
                                                                        border: Border.symmetric(
                                                                            horizontal:
                                                                                BorderSide.none),
                                                                      ),
                                                                      children: List.generate(
                                                                          7,
                                                                          (index) =>
                                                                              TableCell(child: Container(height: 20))),
                                                                    ),
                                                                    for (var i =
                                                                            0;
                                                                        i < _pagedData.length;
                                                                        i++)
                                                                      TableRow(
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          border:
                                                                              Border(
                                                                            left:
                                                                                const BorderSide(color: Color.fromRGBO(21, 43, 81, 1)),
                                                                            right:
                                                                                const BorderSide(color: Color.fromRGBO(21, 43, 81, 1)),
                                                                            top:
                                                                                const BorderSide(color: Color.fromRGBO(21, 43, 81, 1)),
                                                                            bottom: i == _pagedData.length - 1
                                                                                ? const BorderSide(color: Color.fromRGBO(21, 43, 81, 1))
                                                                                : BorderSide.none,
                                                                          ),
                                                                        ),
                                                                        children: [
                                                                          _buildDataCell(
                                                                              '${_pagedData[i].insuranceCompany ?? ''}${_pagedData[i].isDelete == true ? '  (DELETED)' : ''}',
                                                                              isDeleted: _pagedData[i].isDelete == true),
                                                                          _buildDataCell(
                                                                            _pagedData[i].policyId ??
                                                                                '',
                                                                            isDeleted: _pagedData[i].isDelete == true,
                                                                          ),
                                                                          _buildDataCell(
                                                                            formatMoney(_pagedData[i].liabilityCoverage),
                                                                            isDeleted: _pagedData[i].isDelete == true,
                                                                          ),
                                                                          _buildDataCell(
                                                                            _pagedData[i].policyStatus ??
                                                                                '',
                                                                            isDeleted: _pagedData[i].isDelete == true,
                                                                          ),
                                                                          _buildDataCell(
                                                                            Provider.of<DateProvider>(context, listen: false).formatCurrentDate(_pagedData[i].effectiveDate ??
                                                                                ''),
                                                                            isDeleted: _pagedData[i].isDelete == true,
                                                                          ),
                                                                          _buildDataCell(
                                                                            Provider.of<DateProvider>(context, listen: false).formatCurrentDate(_pagedData[i].expirationDate ??
                                                                                ''),
                                                                            isDeleted: _pagedData[i].isDelete == true,
                                                                          ),
                                                                          _buildRenterInsuranceActionsCell(
                                                                              _pagedData[i]),
                                                                        ],
                                                                      ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 25),
                                                            _buildPaginationControls(),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 25),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 20),
                                  child: CustomHistoryTable(
                                    key: ValueKey(_historyRefreshKey),
                                    historyType: HistoryType.tenant,
                                    entityId: widget.tenantId,
                                    title: 'History',
                                    blueColor: blueColor,
                                    itemsPerPage: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_tenantSummaryTabIndex == 1) _buildLeaseTabContent(),
                  if (_tenantSummaryTabIndex == 2)
                    Tenant_communication(
                      lease_id: widget.tenantId,
                    ),
                  if (_tenantSummaryTabIndex == 3)
                    FinancialTable(
                      leaseId: widget.tenantId,
                    ),
                  if (_tenantSummaryTabIndex == 4) _buildTenantWorkOrdersTab(),
                  // Web parity: tenant-scoped notes (LeaseNote scope="tenant").
                  // Merges the tenant's own notes with those of every lease
                  // they are on; new notes attach to the tenant, so a tenant
                  // with no lease can still have notes.
                  if (_tenantSummaryTabIndex == 5)
                    FutureBuilder<List<TenantLeaseData>>(
                      future: futurePropertyLease,
                      builder: (context, snap) {
                         // Web parity: the Notes tab is gated on the tenant
                         // having lease data; without it web shows this message
                         // instead of the notes list.
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        final hasLease = (snap.data?.isNotEmpty ?? false);
                        if (!hasLease) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 32, horizontal: 16),
                            alignment: Alignment.center,
                            child: const Text(
                              'No lease data available for this tenant.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Color(0xFF6C757D), fontSize: 14),
                            ),
                          );
                        }
                         // NotesTable's own content starts at 7pt (a leading
                         // SizedBox), while the section dropdown above sits at
                         // 14pt. The extra 7 here lines the two edges up.
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 7),
                          child: NotesTable(tenantId: widget.tenantId),
                        );
                      },
                    ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }
}

class TenantSummaryTablet extends StatefulWidget {
  Tenant? tenants;
  String tenantId;
  final int? initialSummaryTabIndex;
  TenantSummaryTablet({
    super.key,
    required this.tenantId,
    this.tenants,
    this.initialSummaryTabIndex,
  });
  @override
  State<TenantSummaryTablet> createState() => _TenantSummaryTabletState();
}

class _TenantSummaryTabletState extends State<TenantSummaryTablet>
    with NetworkRetryState {
  final GlobalKey _leaseDetailsSectionKey = GlobalKey();
  bool _scheduledLeaseSectionScroll = false;

  Future<List<TenantLeaseData>> fetchLeaseData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Staff must send their OWN id (staff_id) in the id header — web parity
    // (CRM-4479). adminId 401s for staff at multi-co-admin companies. Matches
    // the phone-layout variant and the repository, which already use staff_id.
    String? id = prefs.getString("staff_id");
    String? token = prefs.getString('token');

    String url = '$Api_url/api/tenant/tenant_details/${widget.tenantId}';
    final response = await apiGet(
      Uri.parse(url),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final tenantResponse = TenantResponse.fromJson(jsonResponse);

      // Collect all lease data from all tenant data
      List<TenantLeaseData> allLeaseData = [];
      if (tenantResponse.data != null) {
        for (var tenant in tenantResponse.data!) {
          if (tenant.leaseData != null) {
            allLeaseData.addAll(tenant.leaseData!);
          }
        }
      }

      return allLeaseData;
    } else {
      throw Exception('Failed to load lease data');
    }
  }

  final TenantsRepository repo = TenantsRepository();

  // Web parity: "Show Deleted Policies" on the Renter's Insurance section,
  // persisted under the same key the web app uses in localStorage.
  static const String _showDeletedPrefKey =
      'rentersInsurance:embedded:showDeleted';
  bool _showDeleted = false;

  Future<List<lease_renter_insurance>> _fetchRenterPolicies() =>
      RentersInsuranceService()
          .fetchPoliciesByTenant(widget.tenantId, includeDeleted: _showDeleted);

  /// Read the persisted preference first so the initial fetch already includes
  /// deleted policies when the toggle was left on.
  Future<List<lease_renter_insurance>> _loadShowDeletedPrefAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final restored = prefs.getBool(_showDeletedPrefKey) ?? false;
    if (restored != _showDeleted) {
      _showDeleted = restored;
      // The checkbox sits outside this FutureBuilder, so completing the future
      // alone would not repaint it — it would read unchecked while deleted
      // rows were in the list. Rebuild explicitly.
      if (mounted) setState(() {});
    }
    return _fetchRenterPolicies();
  }

  Future<void> _onShowDeletedChanged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDeletedPrefKey, value);
    if (!mounted) return;
    setState(() {
      _showDeleted = value;
      currentPage = 0;
      _currentPage = 0;
      futureRenterPolicies = _fetchRenterPolicies();
    });
  }

  /// Rows shown in the Renter's Insurance section.
  ///
  /// Web parity: the tenant-scoped list renders every policy the endpoint
  /// returns — expired and future included, not just ACTIVE (see web
  /// 681b5d751). Only soft-deleted rows are gated, on the toggle.
  bool _isPolicyVisible(lease_renter_insurance p) =>
      _showDeleted || p.isDelete != true;

  /// Web parity: the "Show Deleted Policies" checkbox above the policy list.
  Widget _buildShowDeletedToggle() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _showDeleted,
            activeColor: blueColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (value) {
              if (value != null) {
                _onShowDeletedChanged(value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => _onShowDeletedChanged(!_showDeleted),
          child: Text(
            'Show Deleted Policies',
            style: TextStyle(
              color: blueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  int totalrecords = 0;
  late Future<List<lease_renter_insurance>> futureRenterPolicies;
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

  void sortData(List<lease_renter_insurance> data) {
    /*  if (sorting1) {
      data.sort((a, b) => ascending1
          ? a.propertyType!.compareTo(b.propertyType!)
          : b.propertyType!.compareTo(a.propertyType!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? a.propertysubType!.compareTo(b.propertysubType!)
          : b.propertysubType!.compareTo(a.propertysubType!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.createdAt!.compareTo(b.createdAt!)
          : b.createdAt!.compareTo(a.createdAt!));
    }*/
  }

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
        color: blueColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
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
                        ? const Padding(
                            padding: EdgeInsets.only(left: 20.0),
                            child: Text(
                              "Insurance \nCompany ",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const Text("     Insurance Company",
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            textAlign: TextAlign.center),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting2) {
                      sorting1 = false;
                      sorting2 = sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    } else {
                      sorting1 = false;
                      sorting2 = !sorting2;
                      sorting3 = false;
                      ascending2 = sorting2 ? !ascending2 : true;
                      ascending1 = false;
                      ascending3 = false;
                    }
                    // Sorting logic here
                  });
                },
                child: const Row(
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15.0),
                      child: Text("Policy Id",
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
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
                child: const Row(
                  children: [
                    Text(
                      "Expiration\nDate",
                      style: TextStyle(color: Colors.white, fontSize: 14),
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
    );
  }

  final List<String> items = ['Residential', "Commercial", "All"];
  String? selectedValue;
  String searchvalue = "";
  late Future<List<Tenant>> _futureTenantSummary;

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls from `initState` only — controllers, listeners and
  /// filter defaults are not repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _futureTenantSummary = repo.fetchTenantsummery(widget.tenantId) ?? Future.value([]);;
      futureRenterPolicies = _loadShowDeletedPrefAndFetch();;
    });
  }

  @override
  void initState() {
    super.initState();
    _futureTenantSummary =
        repo.fetchTenantsummery(widget.tenantId) ?? Future.value([]);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    futureRenterPolicies = _loadShowDeletedPrefAndFetch();
  }

  void _refreshTabletTenantSummary() {
    setState(() {
      _futureTenantSummary =
          repo.fetchTenantsummery(widget.tenantId) ?? Future.value([]);
    });
  }

  bool _tabletLeaseCoversNow(String? startDate, String? endDate) {
    final start = parseDateRobust(startDate);
    final end = parseDateRobust(endDate);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  String? _tabletLeaseIdForAddCard(Tenant tenant) {
    final list = tenant.leaseData;
    if (list == null || list.isEmpty) return null;
    for (final l in list) {
      final id = l.leaseId;
      if (id != null &&
          id.isNotEmpty &&
          _tabletLeaseCoversNow(l.startDate, l.endDate)) {
        return id;
      }
    }
    final firstId = list.first.leaseId;
    if (firstId != null && firstId.isNotEmpty) return firstId;
    return null;
  }

  Future<void> _tabletOnPaymentAch(Tenant t, bool value) async {
    final prev = t.allowAch;
    final card = t.allowCard != false;
    setState(() => t.allowAch = value);
    try {
      await repo.editTenantFromModel(t, allowAch: value, allowCard: card);
    } catch (_) {
      if (mounted) setState(() => t.allowAch = prev);
    }
  }

  Future<void> _tabletOnPaymentCard(Tenant t, bool value) async {
    final prev = t.allowCard;
    final ach = t.allowAch != false;
    setState(() => t.allowCard = value);
    try {
      await repo.editTenantFromModel(t, allowAch: ach, allowCard: value);
    } catch (_) {
      if (mounted) setState(() => t.allowCard = prev);
    }
  }

  // Mirrors the phone layout: the rental owner's acceptance decides whether
  // ACH exists, and the tenant's tick decides whether it is offered.
  bool _leaseAchAccepted = false;
  bool _achSettingsFetched = false;
  bool _achFetchInFlight = false;
  bool _openingPaymentMethods = false;

  Future<void> _fetchAchAccepted(String leaseId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("staff_id");
      String? token = prefs.getString('token');
      final response = await apiGet(
        Uri.parse(
            '$Api_url/api/tenant/payment_settings/${widget.tenantId}/$leaseId'),
        headers: {
          "authorization": "CRM $token",
          // Staff sends its OWN staff_id — adminId 401s for staff (CRM-4479).
          "id": "CRM $id",
        },
      );
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
        _leaseAchAccepted = jsonData['data']['achAccepted'] == true;
        _achSettingsFetched = true;
      }
    } catch (e) {
    } finally {
      _achFetchInFlight = false;
      if (mounted) setState(() {});
    }
  }

  /// Kicked off from the payment card's builder. The guards make it run at
  /// most once, and the post-frame hop keeps setState out of the build phase —
  /// this layout creates its lease future inside build, so a direct call would
  /// loop.
  void _tabletEnsureAchSettings(Tenant tenant) {
    if (_achSettingsFetched || _achFetchInFlight) return;
    final leaseId = _tabletLeaseIdForAddCard(tenant);
    if (leaseId == null || leaseId.isEmpty) return;
    _achFetchInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchAchAccepted(leaseId);
    });
  }

  Future<void> _tabletOpenAddCard(Tenant tenant) async {
    if (_openingPaymentMethods) return;
    _openingPaymentMethods = true;
    try {
      await _tabletHandleManagePaymentMethods(tenant);
    } finally {
      _openingPaymentMethods = false;
    }
  }

  Future<void> _tabletHandleManagePaymentMethods(Tenant tenant) async {
    final leaseId = _tabletLeaseIdForAddCard(tenant);
    if (leaseId == null || leaseId.isEmpty) {
      Fluttertoast.showToast(
        msg:
            'This tenant needs at least one lease to add or manage saved payment methods.',
        backgroundColor: Colors.red,
      );
      return;
    }
    if (!_achSettingsFetched && !_achFetchInFlight) {
      _achFetchInFlight = true;
      await _fetchAchAccepted(leaseId);
      if (!mounted) return;
    }
    final allowCard = tenant.allowCard != false;
    final allowAch = _leaseAchAccepted && tenant.allowAch == true;

    if (!allowCard && !allowAch) {
      Fluttertoast.showToast(
        msg: 'Turn on Card or ACH in Payment Options to add a payment method.',
        backgroundColor: Colors.red,
      );
      return;
    }
    if (!allowAch) {
      _tabletPushAddCard(leaseId);
      return;
    }
    if (!allowCard) {
      _tabletPushAddAch(leaseId);
      return;
    }
    _tabletShowChooser(leaseId);
  }

  void _tabletPushAddCard(String leaseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCard(
          leaseId: leaseId,
          initialTenantId: widget.tenantId,
          useStaffIdHeader: true,
        ),
      ),
    );
  }

  void _tabletPushAddAch(String leaseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAchAccount(
          tenantId: widget.tenantId,
          leaseId: leaseId,
          authAsStaff: true,
        ),
      ),
    );
  }

  void _tabletShowChooser(String leaseId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Manage Payment Methods',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: blueColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tabletMethodOption(
              icon: Icons.credit_card,
              label: 'Add Card',
              onTap: () {
                Navigator.pop(dialogContext);
                _tabletPushAddCard(leaseId);
              },
            ),
            const SizedBox(height: 10),
            _tabletMethodOption(
              icon: Icons.account_balance,
              label: 'Add Bank Account (ACH)',
              onTap: () {
                Navigator.pop(dialogContext);
                _tabletPushAddAch(leaseId);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: blueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabletMethodOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: blueColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: blueColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  TableCell _tableCellLabel(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF8A95A8),
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ),
    );
  }

  TableCell _tableCellValue(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: blueColor)),
      ),
    );
  }

  void _confirmTabletDeleteEmergency(MergedEmergencyContact c) {
    if (c.contactId == 'primary') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Primary emergency contact cannot be deleted from here.")));
      return;
    }
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Delete emergency contact?",
      desc: "This contact will be removed from the list.",
      style: const AlertStyle(backgroundColor: Colors.white),
      buttons: [
        DialogButton(
          child: Text("Cancel",
              style: TextStyle(
                  color: blueColor, fontSize: 18, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(color: blueColor, width: 1.5),
        ),
        DialogButton(
          child: const Text("Delete",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await repo.deleteEmergencyContact(widget.tenantId, c.contactId);
              _refreshTabletTenantSummary();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
              }
            }
          },
          color: Colors.red,
        ),
      ],
    ).show();
  }

  void _showTabletEmergencyDialog(
      BuildContext context, MergedEmergencyContact? editContact) {
    final isEdit = editContact != null;
    final initialName = editContact?.name.trim() ?? '';
    final initialRelation = editContact?.relation.trim() ?? '';
    final initialEmail = editContact?.email.trim() ?? '';
    final initialPhoneDigits =
        editContact?.phoneNumber.replaceAll(RegExp(r'\D'), '') ?? '';
    final nameController = TextEditingController(text: editContact?.name ?? '');
    final relationController =
        TextEditingController(text: editContact?.relation ?? '');
    final emailController =
        TextEditingController(text: editContact?.email ?? '');
    final phoneController = TextEditingController(
        text: isEdit ? formatPhoneNumberedit(editContact.phoneNumber) : '');
    final formKey = GlobalKey<FormState>();

    String? validateName(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      return null;
    }

    String? validateRelation(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      return null;
    }

    String? validateEmail(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      if (!EmailValidator.validate(value.trim())) return "Enter a valid email";
      return null;
    }

    String? validatePhone(String? value) {
      if (value == null || value.toString().trim().isEmpty) {
        return "This field is required";
      }
      if (value.replaceAll(RegExp(r'\D'), '').length != 10) {
        return "Enter a valid 10-digit phone number";
      }
      return null;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text(isEdit ? "Edit Emergency Contact" : "Add Emergency Contact"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Contact Name",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: "Enter contact name",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: validateName,
                ),
                const SizedBox(height: 16),
                const Text("Relationship to Tenant",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: relationController,
                  decoration: const InputDecoration(
                    hintText: "Enter relationship to tenant",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: validateRelation,
                ),
                const SizedBox(height: 16),
                const Text("Email",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                  decoration: const InputDecoration(
                    hintText: "Enter email",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Phone Number",
                    style: TextStyle(
                        color: Color(0xFF8A95A8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [PhoneNumberFormatter()],
                  validator: validatePhone,
                  decoration: const InputDecoration(
                    hintText: "(xxx) xxx-xxxx",
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCEL",
                style:
                    TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: blueColor),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) {
                if (!isEdit && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("All fields are required")),
                  );
                }
                return;
              }
              final name = nameController.text.trim();
              final relation = relationController.text.trim();
              final email = emailController.text.trim();
              final phoneDigits =
                  phoneController.text.replaceAll(RegExp(r'\D'), '');
              final phone = formatPhoneNumberedit(phoneDigits);
              if (isEdit) {
                if (name == initialName &&
                    relation == initialRelation &&
                    email == initialEmail &&
                    phoneDigits == initialPhoneDigits) {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No changes made")),
                    );
                  }
                  return;
                }
              }
              Navigator.pop(ctx);
              try {
                if (!isEdit) {
                  await repo.addEmergencyContact(widget.tenantId,
                      name: name,
                      relation: relation,
                      email: email,
                      phoneNumber: phone);
                } else if (editContact.contactId == 'primary') {
                  await repo.updateEmergencyContactPrimary(widget.tenantId,
                      name: name,
                      relation: relation,
                      email: email,
                      phoneNumber: phone);
                } else {
                  await repo.updateEmergencyContact(
                      widget.tenantId, editContact.contactId,
                      name: name,
                      relation: relation,
                      email: email,
                      phoneNumber: phone);
                }
                _refreshTabletTenantSummary();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: ${friendlyErrorMessage(e)}')));
                }
              }
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }
  void checkInternet() async {
    var connectiondata;
    connectiondata = await Connectivity().checkConnectivity();
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  void handleEdit(lease_renter_insurance property) async {}

  void _showAlert(BuildContext context, String id) {
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same record.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this Insurance!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
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
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            if (deleting) return;
            deleting = true;
            // The service toasts the server's own reason and then throws when
            // the delete is rejected. Nothing caught it, so Navigator.pop was
            // never reached — the dialog stayed open with no explanation and
            // the exception escaped into the framework. Close the dialog
            // either way; the message has already been shown.
            try {
              await RentersInsuranceService()
                  .deleteInsurance(renters_insurance_id: id);
              if (!mounted) return;
              // Only refresh when the delete actually succeeded.
              setState(() {
                futureRenterPolicies = _fetchRenterPolicies();
              });
              Navigator.pop(context);
            } catch (_) {
              deleting = false;
              if (!mounted) return;
              Navigator.pop(context);
            }
          },
          color: Colors.red,
        )
      ],
    ).show();
  }

  void _showRenterInsuranceDeleteAlert(
      BuildContext context, String rentersInsuranceId) {
    // The Delete button stayed live while the request was in flight, so a
    // double tap fired two DELETE calls for the same record.
    bool deleting = false;
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this Insurance!",
      style: const AlertStyle(backgroundColor: Colors.white),
      buttons: [
        DialogButton(
          child: Text("Cancel",
              style: TextStyle(
                  color: blueColor, fontSize: 18, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context),
          color: Colors.white,
          radius: BorderRadius.circular(8),
          border: Border.all(color: blueColor, width: 1.5),
        ),
        DialogButton(
          child: const Text("Delete",
              style: TextStyle(color: Colors.white, fontSize: 18)),
          onPressed: () async {
            if (deleting) return;
            deleting = true;
            // This checked the returned flag but not for a throw: the service
            // throws when the delete is rejected, so Navigator.pop was never
            // reached and the dialog stayed open with no explanation. Close it
            // either way; the message has already been shown.
            try {
              final ok = await RentersInsuranceService()
                  .deleteInsurance(renters_insurance_id: rentersInsuranceId);
              if (mounted && ok == true) {
                setState(() {
                  futureRenterPolicies = _fetchRenterPolicies();
                });
              }
              if (mounted) Navigator.pop(context);
            } catch (_) {
              deleting = false;
              if (mounted) Navigator.pop(context);
            }
          },
          color: Colors.red,
        ),
      ],
    ).show();
  }

  Widget _buildRenterInsuranceActionsCellTablet(lease_renter_insurance policy) {
    // Web parity: a soft-deleted policy is read-only — no Edit/Delete.
    final bool isDeleted = policy.isDelete == true;
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Container(
          height: 50,
          child: Row(
            children: [
              const SizedBox(width: 20),
              if (!isDeleted)
                InkWell(
                  onTap: () async {
                    var check = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditRentersInsurance(
                          tenantid: widget.tenantId,
                          leaseId: policy.leaseId ?? '',
                          renters_insurance_id: policy.rentersInsuranceId!,
                          embeddedInTenantSummary: true,
                        ),
                      ),
                    );
                    if (check == true) {
                      setState(() {
                        futureRenterPolicies = _fetchRenterPolicies();
                      });
                    }
                  },
                  child: const FaIcon(FontAwesomeIcons.edit, size: 30),
                ),
              if (!isDeleted) const SizedBox(width: 15),
              if (!isDeleted)
                InkWell(
                  onTap: () => _showRenterInsuranceDeleteAlert(
                      context, policy.rentersInsuranceId!),
                  child: const FaIcon(FontAwesomeIcons.trashCan, size: 30),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<lease_renter_insurance> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<lease_renter_insurance> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(lease_renter_insurance d) getField,
      int columnIndex, bool ascending) {
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

  void handleDelete(lease_renter_insurance property) {}

  Widget _buildHeader<T>(String text, int columnIndex,
      Comparable<T> Function(lease_renter_insurance d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField!, columnIndex, !_sortAscending);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Text(text,
                  style: TextStyle(
                      color: blueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
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

  Widget _buildDataCell(String text, {bool isDeleted = false}) {
    return TableCell(
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text,
            style: TextStyle(
                fontSize: 18,
                // Web parity: soft-deleted policies read greyed + struck through.
                color: isDeleted ? Colors.grey : const Color(0xFF8A95A8),
                decoration: isDeleted ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildActionsCell(lease_renter_insurance data) {
    // Web parity: a soft-deleted policy is read-only — no Edit/Delete.
    final bool isDeleted = data.isDelete == true;
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
              if (!isDeleted)
                InkWell(
                  onTap: () {
                    handleEdit(data);
                  },
                  child: const FaIcon(
                    FontAwesomeIcons.edit,
                    size: 30,
                  ),
                ),
              if (!isDeleted)
                const SizedBox(
                  width: 15,
                ),
              if (!isDeleted)
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

  final TenantsRepository _tenantService = TenantsRepository();

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      // appBar: widget302.,
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Tenants",
        dropdown: true,
      ),
      body: !isOffline
          ? Center(
              child: FutureBuilder<List<Tenant>>(
                future: _futureTenantSummary,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SpinKitFadingCircle(
                        color: Colors.black,
                        size: 40.0,
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center);
                  } else {
                    List<Tenant> tenantsummery = snapshot.data ?? [];
                    // `?? []` only turns a null into an empty list — every widget below
                    // this point reads tenantsummery.first (11 sites, through :6963),
                    // which throws StateError on an empty list. The isNotEmpty check just
                    // below only gates scroll scheduling; it does not return. Bail out here
                    // so one guard covers all of them. Mirrors the Admin copy.
                    if (tenantsummery.isEmpty) {
                      return const Center(child: Text('No Data Available'));
                    }
                    if (widget.initialSummaryTabIndex == 1 &&
                        tenantsummery.isNotEmpty &&
                        !_scheduledLeaseSectionScroll) {
                      _scheduledLeaseSectionScroll = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        final ctx = _leaseDetailsSectionKey.currentContext;
                        if (ctx != null) {
                          Scrollable.ensureVisible(
                            ctx,
                            alignment: 0.05,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      });
                    }
                    //   Provider.of<Tenants_counts>(context).setOwnerDetails(tenants.length);
                    return ListView(
                      scrollDirection: Axis.vertical,
                      children: [
                        const SizedBox(
                          height: 15,
                        ),
                        Row(
                          children: [
                            const SizedBox(
                              width: 30,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tenantsummery.first.tenantFirstName}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: blueColor,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                const Text(
                                  'Tenant',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF8A95A8)),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                SizedBox(
                                    width: MediaQuery.of(context).size.width *
                                        0.065),
                                GestureDetector(
                                  onTap: () async {
                                    // Navigator.push(
                                    //     context,
                                    //     MaterialPageRoute(
                                    //         builder: (context) => Edit_rentalowners(
                                    //             rentalOwner:
                                    //                 rentalownersummery.first)));
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5.0),
                                    child: Container(
                                      height: 42,
                                      width: MediaQuery.of(context).size.width *
                                          .15,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        color: blueColor,
                                        boxShadow: [
                                          const BoxShadow(
                                            color: Colors.grey,
                                            offset: Offset(0.0, 1.0), //(x,y)
                                            blurRadius: 6.0,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "Edit",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    Navigator.pop(context);
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5.0),
                                    child: Container(
                                      height: 42,
                                      width: MediaQuery.of(context).size.width *
                                          .15,
                                      decoration: BoxDecoration(
                                        borderRadius:
                                            BorderRadius.circular(5.0),
                                        color: blueColor,
                                        boxShadow: [
                                          const BoxShadow(
                                            color: Colors.grey,
                                            offset: Offset(0.0, 1.0), //(x,y)
                                            blurRadius: 6.0,
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "Back",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              width: 30,
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(25.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5.0),
                            child: Container(
                              height: 50.0,
                              padding: const EdgeInsets.only(top: 8, left: 10),
                              width: MediaQuery.of(context).size.width * .91,
                              margin: const EdgeInsets.only(bottom: 6.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.0),
                                color: blueColor,
                                boxShadow: [
                                  const BoxShadow(
                                    color: Colors.grey,
                                    offset: Offset(0.0, 1.0), //(x,y)
                                    blurRadius: 6.0,
                                  ),
                                ],
                              ),
                              child: const Text(
                                "Summary",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 25, right: 25),
                              child: Material(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: screenWidth * 0.45,
                                  height: 280,
                                  // width: 350,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: blueColor),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16,
                                        right: 25,
                                        top: 20,
                                        bottom: 30),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const SizedBox(
                                              width: 2,
                                            ),
                                            Text(
                                              "Contact Information",
                                              style: TextStyle(
                                                  color: blueColor,
                                                  fontWeight: FontWeight.bold,
                                                  // fontSize: 18
                                                  fontSize: 21),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        Divider(
                                          color: blueColor,
                                        ),
                                        //phonenumber
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        Table(
                                          children: [
                                            TableRow(children: [
                                              const TableCell(
                                                  child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: Text(
                                                  'Name',
                                                  style: TextStyle(
                                                      color: Color(0xFF8A95A8),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              )),
                                              TableCell(
                                                  child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12),
                                                child: Text(
                                                  '${(tenantsummery.first.tenantFirstName ?? '').isEmpty ? 'N/A' : tenantsummery.first.tenantFirstName}',
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: blueColor),
                                                ),
                                              )),
                                            ]),
                                            TableRow(children: [
                                              const TableCell(
                                                  child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: Text(
                                                  'Phone Number',
                                                  style: TextStyle(
                                                      color: Color(0xFF8A95A8),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              )),
                                              TableCell(
                                                  child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12),
                                                child: Text(
                                                  '${(tenantsummery.first.tenantPhoneNumber ?? '').isEmpty ? 'N/A' : tenantsummery.first.tenantPhoneNumber}',
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: blueColor),
                                                ),
                                              )),
                                            ]),
                                            TableRow(children: [
                                              const TableCell(
                                                  child: Padding(
                                                padding: EdgeInsets.all(12.0),
                                                child: Text(
                                                  'Email',
                                                  style: TextStyle(
                                                      color: Color(0xFF8A95A8),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16),
                                                ),
                                              )),
                                              TableCell(
                                                  child: Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 12),
                                                child: Text(
                                                  '${(tenantsummery.first.tenantEmail ?? '').isEmpty ? 'N/A' : tenantsummery.first.tenantEmail}',
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: blueColor),
                                                ),
                                              )),
                                            ]),
                                          ],
                                        ),
                                        //primary email
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            //Personal information
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 25),
                                child: Material(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: screenWidth * 0.45,
                                    //  height: 0,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: blueColor),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          left: 25,
                                          right: 25,
                                          top: 20,
                                          bottom: 30),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              const SizedBox(
                                                width: 2,
                                              ),
                                              Text(
                                                "Personal Information",
                                                style: TextStyle(
                                                    color: blueColor,
                                                    fontWeight: FontWeight.bold,
                                                    // fontSize: 18
                                                    fontSize: 21),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(
                                            height: 10,
                                          ),
                                          Divider(
                                            color: blueColor,
                                          ),
                                          //first name
                                          Table(
                                            children: [
                                              TableRow(children: [
                                                const TableCell(
                                                    child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Text(
                                                    'Birth Date',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF8A95A8),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                )),
                                                TableCell(
                                                    child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 12),
                                                  child: Text(
                                                    '${(tenantsummery.first.tenantBirthDate ?? '').isEmpty ? 'N/A' : tenantsummery.first.tenantBirthDate}',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor),
                                                  ),
                                                )),
                                              ]),
                                              TableRow(children: [
                                                const TableCell(
                                                    child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Text(
                                                    'TaxPayer Id',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF8A95A8),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                )),
                                                TableCell(
                                                    child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 12),
                                                  child: Text(
                                                    '${(tenantsummery.first.taxPayerId ?? '').isEmpty ? 'N/A' : tenantsummery.first.taxPayerId}',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor),
                                                  ),
                                                )),
                                              ]),
                                              TableRow(children: [
                                                const TableCell(
                                                    child: Padding(
                                                  padding: EdgeInsets.all(12.0),
                                                  child: Text(
                                                    'Comments',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF8A95A8),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                  ),
                                                )),
                                                TableCell(
                                                    child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 12),
                                                  child: Text(
                                                    '${(tenantsummery.first.comments ?? '').isEmpty ? 'N/A' : tenantsummery.first.comments}',
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor),
                                                  ),
                                                )),
                                              ]),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 25, right: 25),
                          child: Material(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: blueColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 25, right: 25, top: 20, bottom: 30),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Emergency Contact (${getCombinedEmergencyContacts(tenantsummery.first).length})",
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 21),
                                        ),
                                        Material(
                                          color: blueColor,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: InkWell(
                                            onTap: () =>
                                                _showTabletEmergencyDialog(
                                                    context, null),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              child: Icon(Icons.add,
                                                  color: Colors.white,
                                                  size: 22),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Divider(color: blueColor),
                                    const SizedBox(height: 10),
                                    Table(
                                      columnWidths: const {
                                        0: FlexColumnWidth(2),
                                        1: FlexColumnWidth(1),
                                        2: FlexColumnWidth(2),
                                        3: FlexColumnWidth(1),
                                        4: FlexColumnWidth(0.5),
                                      },
                                      children: [
                                        TableRow(
                                            decoration: BoxDecoration(
                                                color:
                                                    blueColor.withOpacity(0.1)),
                                            children: [
                                              _tableCellLabel("Contact Name"),
                                              _tableCellLabel(
                                                  "Relation With Tenants"),
                                              _tableCellLabel(
                                                  "Emergency Email"),
                                              _tableCellLabel(
                                                  "Emergency Phone"),
                                              _tableCellLabel("Action"),
                                            ]),
                                        ...getCombinedEmergencyContacts(
                                                tenantsummery.first)
                                            .map((c) => TableRow(
                                                  children: [
                                                    _tableCellValue(
                                                        c.name.isEmpty
                                                            ? '—'
                                                            : c.name),
                                                    _tableCellValue(
                                                        c.relation.isEmpty
                                                            ? '—'
                                                            : c.relation),
                                                    _tableCellValue(
                                                        c.email.isEmpty
                                                            ? '—'
                                                            : c.email),
                                                    _tableCellValue(
                                                        c.phoneNumber.isEmpty
                                                            ? '—'
                                                            : formatPhoneNumber(
                                                                c.phoneNumber)),
                                                    TableCell(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            InkWell(
                                                              onTap: () =>
                                                                  _showTabletEmergencyDialog(
                                                                      context,
                                                                      c),
                                                              child: const FaIcon(
                                                                  FontAwesomeIcons
                                                                      .pen,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .green),
                                                            ),
                                                            const SizedBox(
                                                                width: 12),
                                                            InkWell(
                                                              onTap: () =>
                                                                  _confirmTabletDeleteEmergency(
                                                                      c),
                                                              child: const FaIcon(
                                                                  FontAwesomeIcons
                                                                      .trashCan,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .red),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 25, right: 25),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: blueColor),
                            ),
                            child: Padding(
                                padding: const EdgeInsets.only(
                                    right: 10, bottom: 15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    //add propertytype
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16, top: 16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Renters Insurance Policy',
                                            style: TextStyle(
                                                color: blueColor,
                                                fontSize: 21,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              GestureDetector(
                                                onTap: () async {
                                                  // Match web/Admin: open the
                                                  // add insurance form
                                                  // regardless of lease.
                                                  final result = await Navigator
                                                          .of(context)
                                                      .push(MaterialPageRoute(
                                                          builder: (context) =>
                                                              AdminAddTenantInsurance(
                                                                tenantid: widget
                                                                    .tenantId,
                                                                leaseId: (widget.tenants?.leaseData?.isNotEmpty ==
                                                                            true
                                                                        ? widget
                                                                            .tenants!
                                                                            .leaseData!
                                                                            .first
                                                                            .leaseId
                                                                        : null) ??
                                                                    widget
                                                                        .tenantId,
                                                                tenantName:
                                                                    '${widget.tenants?.tenantFirstName ?? ''} ${widget.tenants?.tenantLastName ?? ''}'
                                                                        .trim(),
                                                              )));
                                                  if (result == true) {
                                                    setState(() {
                                                      futureRenterPolicies =
                                                          _fetchRenterPolicies();
                                                    });
                                                  }
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 20,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: blueColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            5),
                                                  ),
                                                  child: const Center(
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Text(
                                                          "Add Policy",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500)
                                                const SizedBox(width: 6),
                                              if (MediaQuery.of(context)
                                                      .size
                                                      .width >
                                                  500)
                                                const SizedBox(width: 16),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16),
                                      child: _buildShowDeletedToggle(),
                                    ),

                                    // const SizedBox(height: 10),
                                    const SizedBox(height: 10),
                                    if (MediaQuery.of(context).size.width > 500)
                                      FutureBuilder<
                                          List<lease_renter_insurance>>(
                                        future: futureRenterPolicies,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Container(
                                              constraints: const BoxConstraints(
                                                  minHeight: 160),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 32),
                                              child: Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SpinKitFadingCircle(
                                                        color: blueColor,
                                                        size: 40.0),
                                                    const SizedBox(height: 14),
                                                    Text(
                                                        'Loading Renter\'s Insurance...',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors.grey
                                                                .shade600)),
                                                  ],
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return Center(
                                                child: Text(
                                                    friendlyErrorMessage(snapshot.error)));
                                          } else if (!snapshot.hasData ||
                                              snapshot.data!.isEmpty) {
                                            return const Center(
                                                child:
                                                    Text('No Data Available'));
                                          } else {
                                            _tableData = (snapshot.data!
                                                    as List<lease_renter_insurance>)
                                                .where(_isPolicyVisible)
                                                .toList();

                                            totalrecords = _tableData.length;
                                            final dateProvider =
                                                Provider.of<DateProvider>(
                                                    context,
                                                    listen: false);
                                            return SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  Container(
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 0.0,
                                                          vertical: 5),
                                                      child: Column(
                                                        children: [
                                                          SingleChildScrollView(
                                                            scrollDirection:
                                                                Axis.horizontal,
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 20),
                                                              child: Table(
                                                                defaultColumnWidth:
                                                                    const IntrinsicColumnWidth(),
                                                                children: [
                                                                  TableRow(
                                                                    decoration:
                                                                        BoxDecoration(
                                                                      border: Border.all(
                                                                          // color: blueColor
                                                                          color: blueColor),
                                                                    ),
                                                                    children: [
                                                                      _buildHeader(
                                                                          'Insurance Company',
                                                                          0,
                                                                          null),

                                                                      _buildHeader(
                                                                          'Policy Id',
                                                                          2,
                                                                          null),
                                                                      _buildHeader(
                                                                          'Liability Coverage',
                                                                          2,
                                                                          null),
                                                                      _buildHeader(
                                                                          'Status',
                                                                          2,
                                                                          null),
                                                                      _buildHeader(
                                                                          'Effective Date',
                                                                          2,
                                                                          null),
                                                                      _buildHeader(
                                                                          'Expiration Date',
                                                                          3,
                                                                          null),
                                                                      _buildHeader(
                                                                          'Actions',
                                                                          3,
                                                                          null),
                                                                      // _buildHeader('Actions', 4, null),
                                                                    ],
                                                                  ),
                                                                  TableRow(
                                                                    decoration:
                                                                        const BoxDecoration(
                                                                      border: Border.symmetric(
                                                                          horizontal:
                                                                              BorderSide.none),
                                                                    ),
                                                                    children: List.generate(
                                                                        7,
                                                                        (index) =>
                                                                            TableCell(child: Container(height: 20))),
                                                                  ),
                                                                  for (var i =
                                                                          0;
                                                                      i <
                                                                          _pagedData
                                                                              .length;
                                                                      i++)
                                                                    TableRow(
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        border:
                                                                            Border(
                                                                          left:
                                                                              BorderSide(color: blueColor),
                                                                          right:
                                                                              BorderSide(color: blueColor),
                                                                          top: BorderSide(
                                                                              color: blueColor),
                                                                          bottom: i == _pagedData.length - 1
                                                                              ? const BorderSide(color: Color.fromRGBO(21, 43, 81, 1))
                                                                              : BorderSide.none,
                                                                        ),
                                                                      ),
                                                                      children: [
                                                                        _buildDataCell(
                                                                            '${_pagedData[i].insuranceCompany ?? ''}${_pagedData[i].isDelete == true ? '  (DELETED)' : ''}',
                                                                            isDeleted: _pagedData[i].isDelete == true),
                                                                        _buildDataCell(
                                                                          _pagedData[i].policyId ??
                                                                              '',
                                                                          isDeleted: _pagedData[i].isDelete == true,
                                                                        ),
                                                                        _buildDataCell(
                                                                          formatMoney(_pagedData[i].liabilityCoverage),
                                                                          isDeleted: _pagedData[i].isDelete == true,
                                                                        ),
                                                                        _buildDataCell(
                                                                          _pagedData[i].policyStatus ??
                                                                              '',
                                                                          isDeleted: _pagedData[i].isDelete == true,
                                                                        ),
                                                                        _buildDataCell(
                                                                          dateProvider.formatCurrentDate(_pagedData[i].effectiveDate ??
                                                                              ''),
                                                                          isDeleted: _pagedData[i].isDelete == true,
                                                                        ),
                                                                        _buildDataCell(
                                                                          dateProvider.formatCurrentDate(_pagedData[i].expirationDate ??
                                                                              ''),
                                                                          isDeleted: _pagedData[i].isDelete == true,
                                                                        ),
                                                                        _buildRenterInsuranceActionsCellTablet(
                                                                            _pagedData[i]),
                                                                      ],
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // const SizedBox(height: 25),
                                                          _buildPaginationControls(),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 25),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                  ],
                                )),
                          ),
                        ),
                        const SizedBox(
                          height: 16,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 25.0),
                          child: Builder(builder: (context) {
                            final tTab = tenantsummery.first;
                            final ach = tTab.allowAch != false;
                            final card = tTab.allowCard != false;
                            // Same rule as the phone layout: paint ACH, then remove it
                            // only once the owner's settings say it is not accepted.
                            _tabletEnsureAchSettings(tTab);
                            final showAchRow =
                                !(_achSettingsFetched && !_leaseAchAccepted);
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "Payments Details",
                                        style: TextStyle(
                                          color: blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 21,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    "Allowed Payment Methods",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (showAchRow)
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: ach,
                                          onChanged: (v) => _tabletOnPaymentAch(
                                              tTab, v == true),
                                          activeColor: blueColor,
                                        ),
                                        Text(
                                          "ACH",
                                          style: TextStyle(
                                            color: ach
                                                ? blueColor
                                                : Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: card,
                                        onChanged: (v) => _tabletOnPaymentCard(
                                            tTab, v == true),
                                        activeColor: blueColor,
                                      ),
                                      Text(
                                        "Card",
                                        style: TextStyle(
                                          color: card
                                              ? blueColor
                                              : Colors.grey.shade600,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => _tabletOpenAddCard(
                                          tenantsummery.first),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: blueColor,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          "Manage Payment Methods",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          key: _leaseDetailsSectionKey,
                          padding: const EdgeInsets.all(25.0),
                          child: Material(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: blueColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(0.0),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const SizedBox(width: 2),
                                          Text(
                                            "Lease Details",
                                            style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 21,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      FutureBuilder<List<TenantLeaseData>>(
                                        future: fetchLeaseData(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                              child: SpinKitFadingCircle(
                                                color: Colors.black,
                                                size: 40.0,
                                              ),
                                            );
                                          } else if (snapshot.hasError) {
                                            return Center(
                                              child: Text(
                                                  friendlyErrorMessage(snapshot.error)),
                                            );
                                          } else if (!snapshot.hasData ||
                                              snapshot.data!.isEmpty) {
                                            return Container(
                                              height: 80,
                                              child: const Center(
                                                child:
                                                    Text('No Data Available'),
                                              ),
                                            );
                                          } else {
                                            var data = snapshot.data!;

                                            return SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                                dataRowHeight: 35,
                                                headingRowHeight: 35,
                                                border: TableBorder.all(
                                                  width: 1,
                                                  color: const Color.fromRGBO(
                                                      21, 43, 83, 1),
                                                ),
                                                columns: [
                                                  DataColumn(
                                                      label: Text('Status',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16))),
                                                  DataColumn(
                                                      label: Text('Start - End',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16))),
                                                  DataColumn(
                                                      label: Text('Property',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16))),
                                                  DataColumn(
                                                      label: Text('Type',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16))),
                                                  DataColumn(
                                                      label: Text('Rent',
                                                          style: TextStyle(
                                                              color: blueColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 16))),
                                                ],
                                                rows: data.map((lease) {
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(Text(
                                                          determineStatus(
                                                              lease.startDate,
                                                              lease.endDate),
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              color: Color(
                                                                  0xFF8A95A8),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500))),
                                                      DataCell(Text(
                                                          '${Provider.of<DateProvider>(context, listen: false).formatCurrentDate(normalizeDateForDisplay(lease.startDate))} to ${Provider.of<DateProvider>(context, listen: false).formatCurrentDate(normalizeDateForDisplay(lease.endDate))}',
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              color: Color(
                                                                  0xFF8A95A8),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500))),
                                                      DataCell(Text(
                                                          lease.rentalAdress ??
                                                              '',
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              color: Color(
                                                                  0xFF8A95A8),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500))),
                                                      DataCell(Text(
                                                          lease.leaseType ?? '',
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              color: Color(
                                                                  0xFF8A95A8),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500))),
                                                      DataCell(Text(
                                                          formatCurrency(
                                                              lease.rentAmount),
                                                          style: const TextStyle(
                                                              fontSize: 16,
                                                              color: Color(
                                                                  0xFF8A95A8),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500))),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 20,
                        ),
                      ],
                    );
                  }
                },
              ),
            )
          : NoInternetView(onRetry: retryNow),
      // FutureBuilder<RentalOwnerSummey>(
      //   future: RentalOwnerService().fetchRentalOwnerSummary(rentalOwnerId),
      //   builder: (context, snapshot) {
      //     if (snapshot.connectionState == ConnectionState.waiting) {
      //       return CircularProgressIndicator();
      //     } else if (snapshot.hasError) {
      //       return Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center);
      //     } else if (!snapshot.hasData || snapshot.data == null) {
      //       return Text('No Data Available');
      //     } else {
      //       RentalOwnerSummey rentalOwner = snapshot.data!;
      //       return ListView(
      //         children: [
      //           ListTile(
      //             title: Text(rentalOwner.rentalOwnerName ?? 'No Name'),
      //             subtitle: Text(rentalOwner.rentalOwnerPrimaryEmail ?? 'No Email'),
      //             trailing: Text(rentalOwner.rentalOwnerPhoneNumber ?? 'No Phone'),
      //           ),
      //           // Add more ListTile widgets or other UI elements as needed
      //         ],
      //       );
      //     }
      //   },
      // ),
    );
  }
}

/// Robust date parser that handles multiple date formats and malformed strings
DateTime? parseDateRobust(String? dateString) {
  if (dateString == null || dateString.isEmpty) return null;

  // Clean the date string - remove extra text that might be present
  String cleaned = dateString.trim();

  // Try to extract date from malformed strings like "Trying to read - from 08/01/2026 at 3"
  // Look for common date patterns
  RegExp datePattern =
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})|(\d{4}-\d{1,2}-\d{1,2})');
  Match? match = datePattern.firstMatch(cleaned);
  if (match != null) {
    cleaned = match.group(0) ?? cleaned;
  }

  // List of date formats to try
  List<String> dateFormats = [
    'yyyy-MM-dd', // Standard format: 2028-01-01
    'yyyy-M-d', // Without leading zeros: 2028-1-1
    'MM/dd/yyyy', // US format: 08/01/2026
    'M/d/yyyy', // US format without leading zeros: 8/1/2026
    'dd-MM-yyyy', // European format: 01-08-2026
    'd-M-yyyy', // European format without leading zeros: 1-8-2026
    'MM-dd-yyyy', // US format with dashes: 08-01-2026
    'M-d-yyyy', // US format with dashes without leading zeros: 8-1-2026
  ];

  // Try each format
  for (String format in dateFormats) {
    try {
      return DateFormat(format).parse(cleaned);
    } catch (e) {
      continue;
    }
  }

  // If all formats fail, return null
  return null;
}

/// Normalizes a date string to yyyy-MM-dd format for display
/// Extracts date from malformed strings and converts to proper format
String normalizeDateForDisplay(String? dateString) {
  if (dateString == null || dateString.isEmpty) return '';

  // Try to parse the date
  DateTime? parsedDate = parseDateRobust(dateString);

  if (parsedDate != null) {
    // Convert to yyyy-MM-dd format so DateProvider can format it properly
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  }

  // If parsing fails, return original string (will be handled by DateProvider)
  return dateString;
}

String determineStatus(String? startDate, String? endDate) {
  if (startDate == null || endDate == null) return 'UNKNOWN';

  // Use robust date parser
  DateTime? start = parseDateRobust(startDate);
  DateTime? end = parseDateRobust(endDate);

  // If parsing fails, return UNKNOWN
  if (start == null || end == null) return 'UNKNOWN';

  // Set today to start of day to ensure accurate comparison
  DateTime today =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  // Set end to end of day (23:59:59) to keep lease active through the end date
  DateTime endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);

  if (today.isBefore(start)) {
    return 'FUTURE';
  } else if (today.isAfter(endOfDay)) {
    return 'PAST';
  } else {
    return 'ACTIVE';
  }
}

String formatCurrency(dynamic amount) {
  if (amount == null) return '\$0.00';
  try {
    // Handle both String and numeric types
    double value =
        amount is String ? (double.tryParse(amount) ?? 0.0) : amount.toDouble();
    // Format with currency symbol and 2 decimal places
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(value);
  } catch (e) {
    return '\$0.00';
  }
}
