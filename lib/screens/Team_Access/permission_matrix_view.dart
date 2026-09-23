import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:three_zero_two_property/Model/AdminUser%20Permission/adminUserPermissionModel.dart';
import 'package:three_zero_two_property/repository/AdminUser%20Permission/adminUserPermissionService.dart';

const Color _navy = Color(0xFF152B51); // == blueColor RGBO(21,43,81,1)
const Color _muted = Color(0xFF8A95A8);
const Color _cardBorder = Color(0xFFE7EBF1);

// Width of each checkbox column in the permission matrix tables.
const double _colW = 46;

/// Inline Staff / Vendor / Tenant permission matrix.
///
/// Self-contained: loads via [PermissionService.fetchPermissions] on mount and
/// saves the whole [UserPermissionData] via [PermissionService.postUserPermissionData]
/// (same API as the original User Permission screen — UI only is new).
///
/// Returns a non-scrolling Column so it can be embedded inside any scroll view
/// (the Settings ListView, or a full-screen SingleChildScrollView).
class PermissionMatrixView extends StatefulWidget {
  const PermissionMatrixView({super.key});

  @override
  State<PermissionMatrixView> createState() => _PermissionMatrixViewState();
}

class _PermissionMatrixViewState extends State<PermissionMatrixView>
    with NetworkRetryState {
  final PermissionService _permService = PermissionService();
  UserPermissionData? _perm;
  bool _loading = true;
  bool _error = false;
  // Which section's Save is in flight ('Staff' | 'Vendor' | 'Tenant'), or
  // null when idle. Per-section so pressing one Save doesn't spin all three
  // buttons — matches web's savingSection.
  String? _savingSection;
  int _jump = 0; // active "Jump to" pill: 0 = Staff, 1 = Vendor, 2 = Tenant
  final GlobalKey _staffKey = GlobalKey();
  final GlobalKey _vendorKey = GlobalKey();
  final GlobalKey _tenantKey = GlobalKey();

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _load();
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final p = await _permService.fetchPermissions() ?? UserPermissionData();
      p.staffPermission ??= StaffPermission();
      p.vendorPermission ??= VendorPermission();
      p.tenantPermission ??= TenantPermission();
      _applyDefaults(p);
      if (!mounted) return;
      setState(() {
        _perm = p;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  // Default every boolean to false (matches the existing screen's contract so
  // saves always send true/false, never null).
  void _applyDefaults(UserPermissionData p) {
    final s = p.staffPermission!;
    s.propertyView ??= false;
    s.propertyAdd ??= false;
    s.propertyEdit ??= false;
    s.propertyDelete ??= false;
    s.tenantView ??= false;
    s.tenantAdd ??= false;
    s.tenantEdit ??= false;
    s.tenantDelete ??= false;
    s.leaseView ??= false;
    s.leaseAdd ??= false;
    s.leaseEdit ??= false;
    s.leaseDelete ??= false;
    s.workorderView ??= false;
    s.workorderAdd ??= false;
    s.workorderEdit ??= false;
    s.workorderDelete ??= false;
    s.propertytypeView ??= false;
    s.propertytypeAdd ??= false;
    s.propertytypeEdit ??= false;
    s.propertytypeDelete ??= false;
    s.rentalownerView ??= false;
    s.rentalownerAdd ??= false;
    s.rentalownerEdit ??= false;
    s.rentalownerDelete ??= false;
    s.applicantView ??= false;
    s.applicantAdd ??= false;
    s.applicantEdit ??= false;
    s.applicantDelete ??= false;
    s.vendorView ??= false;
    s.vendorAdd ??= false;
    s.vendorEdit ??= false;
    s.vendorDelete ??= false;
    s.setting ??= false;
    s.propertydetailView ??= false;
    s.workorderdetailView ??= false;
    s.leasedetailView ??= false;
    s.paymentView ??= false;
    s.paymentAdd ??= false;
    s.paymentEdit ??= false;
    s.paymentDelete ??= false;

    final v = p.vendorPermission!;
    v.workorderView ??= false;
    v.workorderEdit ??= false;

    final t = p.tenantPermission!;
    t.propertyView ??= false;
    t.financialView ??= false;
    t.financialAdd ??= false;
    t.financialEdit ??= false;
    t.workorderView ??= false;
    t.workorderAdd ??= false;
    t.workorderEdit ??= false;
    t.workorderDelete ??= false;
    t.documentsView ??= false;
    t.documentsAdd ??= false;
    t.documentsEdit ??= false;
    t.documentsDelete ??= false;
  }

  /// Saves every section in one request — web posts the whole payload from each
  /// section's Save too, so only the spinner and the toast are per-section.
  Future<void> _save(String section) async {
    if (_perm == null || _savingSection != null) return;
    setState(() => _savingSection = section);
    try {
      // Stamp admin_id from prefs before posting (matches the existing screen).
      final prefs = await SharedPreferences.getInstance();
      _perm!.adminId = prefs.getString('adminId');
      final code = await _permService.postUserPermissionData(_perm!);
      if (!mounted) return;
      setState(() => _savingSection = null);
      Fluttertoast.showToast(
          msg: code == 200
              ? '$section permissions saved.'
              : 'Failed to save permissions.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingSection = null);
      Fluttertoast.showToast(msg: 'Failed to save permissions.');
    }
  }

  void _jumpTo(int idx, GlobalKey key) {
    setState(() => _jump = idx);
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        alignment: 0.02,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Full-size, so this reads the same as every other screen's offline state.
    // Safe inside this screen's SingleChildScrollView because NoInternetView
    // now drops its RefreshIndicator when the height is unbounded.
    if (isOffline) {
      return NoInternetView(onRetry: retryNow);
    }
    if (_loading) return _buildLoading();

    if (_error) {
      return Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            const Text(
              'Could not load permissions',
              style: TextStyle(
                  color: _navy, fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            _smallButton('Retry', _load),
          ],
        ),
      );
    }

    if (_perm == null) return _buildLoading();

    final s = _perm!.staffPermission!;
    final v = _perm!.vendorPermission!;
    final t = _perm!.tenantPermission!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: _navy, size: 22),
            SizedBox(width: 8),
            Text(
              'User Permissions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "Toggle each capability. Disabling a row's View turns off "
          "Add / Edit / Delete for that module.",
          style: TextStyle(fontSize: 13.5, height: 1.45, color: _muted),
        ),
        const SizedBox(height: 16),
        _jumpBar(),
        const SizedBox(height: 18),
        KeyedSubtree(key: _staffKey, child: _staffSection(s)),
        const SizedBox(height: 24),
        KeyedSubtree(key: _vendorKey, child: _vendorSection(v)),
        const SizedBox(height: 24),
        KeyedSubtree(key: _tenantKey, child: _tenantSection(t)),
      ],
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: SpinKitFadingCircle(color: _navy, size: 40)),
    );
  }

  // "Jump to: Staff / Vendor / Tenant" pill bar (scrolls to each section).
  Widget _jumpBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text(
            'Jump to:',
            style: TextStyle(
                fontSize: 14, color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          _jumpPill('Staff', 0, _staffKey),
          const SizedBox(width: 8),
          _jumpPill('Vendor', 1, _vendorKey),
          const SizedBox(width: 8),
          _jumpPill('Tenant', 2, _tenantKey),
        ],
      ),
    );
  }

  Widget _jumpPill(String label, int idx, GlobalKey key) {
    final bool active = _jump == idx;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _jumpTo(idx, key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? _navy : _cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _navy,
          ),
        ),
      ),
    );
  }

  // Navy-header card wrapping a matrix table + its Save button.
  Widget _permCard({
    required String title,
    required String subtitle,
    required String section,
    required Widget table,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: const BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                    color: Color(0xFFB9C2D4),
                    fontSize: 13,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        table,
        const SizedBox(height: 14),
        _saveButton(section),
      ],
    );
  }

  Widget _matrixTable({
    required List<String> columns,
    required List<Widget> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(color: Color(0xFFF1F5FB)),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'MODULE',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        letterSpacing: 0.3),
                  ),
                ),
                ...columns.map(
                  (c) => SizedBox(
                    width: _colW,
                    child: Text(
                      c,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _muted,
                          letterSpacing: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  // One matrix row. cells[0] is always the View toggle and controls the rest:
  // turning View off clears + disables Add/Edit/Delete. A null cell renders "—".
  Widget _matrixRow(String label, List<_Cell?> cells) {
    final bool viewOn = cells[0]!.value;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _cardBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: _navy),
            ),
          ),
          ...List.generate(cells.length, (i) {
            final cell = cells[i];
            if (cell == null) {
              return const SizedBox(
                width: _colW,
                child: Text(
                  '—',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
              );
            }
            final bool isView = i == 0;
            return SizedBox(
              width: _colW,
              child: Center(
                child: _checkbox(
                  value: cell.value,
                  enabled: isView || viewOn,
                  onChanged: (b) {
                    setState(() {
                      cell.onSet(b);
                      if (isView && !b) {
                        for (int j = 1; j < cells.length; j++) {
                          cells[j]?.onSet(false);
                        }
                      }
                    });
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _checkbox({
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    return Checkbox(
      value: value,
      onChanged: enabled ? (v) => onChanged(v ?? false) : null,
      activeColor: _navy,
      checkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: _muted, width: 1.4),
    );
  }

  // ---- Staff ----
  Widget _staffSection(StaffPermission s) {
    return _permCard(
      title: 'Staff Permissions',
      section: 'Staff',
      subtitle: 'Applies to every staff member in this company.',
      table: _matrixTable(
        columns: const ['VIEW', 'ADD', 'EDIT', 'DELETE'],
        rows: [
          _matrixRow('Properties', [
            _Cell(s.propertyView ?? false, (b) => s.propertyView = b),
            _Cell(s.propertyAdd ?? false, (b) => s.propertyAdd = b),
            _Cell(s.propertyEdit ?? false, (b) => s.propertyEdit = b),
            _Cell(s.propertyDelete ?? false, (b) => s.propertyDelete = b),
          ]),
          _matrixRow('Tenants', [
            _Cell(s.tenantView ?? false, (b) => s.tenantView = b),
            _Cell(s.tenantAdd ?? false, (b) => s.tenantAdd = b),
            _Cell(s.tenantEdit ?? false, (b) => s.tenantEdit = b),
            _Cell(s.tenantDelete ?? false, (b) => s.tenantDelete = b),
          ]),
          _matrixRow('Leases', [
            _Cell(s.leaseView ?? false, (b) => s.leaseView = b),
            _Cell(s.leaseAdd ?? false, (b) => s.leaseAdd = b),
            _Cell(s.leaseEdit ?? false, (b) => s.leaseEdit = b),
            _Cell(s.leaseDelete ?? false, (b) => s.leaseDelete = b),
          ]),
          _matrixRow('Work Orders', [
            _Cell(s.workorderView ?? false, (b) => s.workorderView = b),
            _Cell(s.workorderAdd ?? false, (b) => s.workorderAdd = b),
            _Cell(s.workorderEdit ?? false, (b) => s.workorderEdit = b),
            _Cell(s.workorderDelete ?? false, (b) => s.workorderDelete = b),
          ]),
          _matrixRow('Property Types', [
            _Cell(s.propertytypeView ?? false, (b) => s.propertytypeView = b),
            _Cell(s.propertytypeAdd ?? false, (b) => s.propertytypeAdd = b),
            _Cell(s.propertytypeEdit ?? false, (b) => s.propertytypeEdit = b),
            _Cell(
                s.propertytypeDelete ?? false, (b) => s.propertytypeDelete = b),
          ]),
          _matrixRow('Rental Owners', [
            _Cell(s.rentalownerView ?? false, (b) => s.rentalownerView = b),
            _Cell(s.rentalownerAdd ?? false, (b) => s.rentalownerAdd = b),
            _Cell(s.rentalownerEdit ?? false, (b) => s.rentalownerEdit = b),
            _Cell(s.rentalownerDelete ?? false, (b) => s.rentalownerDelete = b),
          ]),
          _matrixRow('Applicants', [
            _Cell(s.applicantView ?? false, (b) => s.applicantView = b),
            _Cell(s.applicantAdd ?? false, (b) => s.applicantAdd = b),
            _Cell(s.applicantEdit ?? false, (b) => s.applicantEdit = b),
            _Cell(s.applicantDelete ?? false, (b) => s.applicantDelete = b),
          ]),
          _matrixRow('Vendors', [
            _Cell(s.vendorView ?? false, (b) => s.vendorView = b),
            _Cell(s.vendorAdd ?? false, (b) => s.vendorAdd = b),
            _Cell(s.vendorEdit ?? false, (b) => s.vendorEdit = b),
            _Cell(s.vendorDelete ?? false, (b) => s.vendorDelete = b),
          ]),
          _matrixRow('Settings', [
            _Cell(s.setting ?? false, (b) => s.setting = b),
            null,
            null,
            null,
          ]),
        ],
      ),
    );
  }

  // ---- Vendor ----
  Widget _vendorSection(VendorPermission v) {
    return _permCard(
      title: 'Vendor Permissions',
      section: 'Vendor',
      subtitle: 'Applies to every vendor invited to this company.',
      table: _matrixTable(
        columns: const ['VIEW', 'EDIT'],
        rows: [
          _matrixRow('Work Orders', [
            _Cell(v.workorderView ?? false, (b) => v.workorderView = b),
            _Cell(v.workorderEdit ?? false, (b) => v.workorderEdit = b),
          ]),
        ],
      ),
    );
  }

  // ---- Tenant ----
  Widget _tenantSection(TenantPermission t) {
    return _permCard(
      title: 'Tenant Permissions',
      section: 'Tenant',
      subtitle: 'Applies to every tenant in this company.',
      table: _matrixTable(
        columns: const ['VIEW', 'ADD', 'EDIT'],
        rows: [
          _matrixRow('Properties', [
            _Cell(t.propertyView ?? false, (b) => t.propertyView = b),
            null,
            null,
          ]),
          _matrixRow('Financials', [
            _Cell(t.financialView ?? false, (b) => t.financialView = b),
            _Cell(t.financialAdd ?? false, (b) => t.financialAdd = b),
            _Cell(t.financialEdit ?? false, (b) => t.financialEdit = b),
          ]),
          _matrixRow('Work Orders', [
            _Cell(t.workorderView ?? false, (b) => t.workorderView = b),
            _Cell(t.workorderAdd ?? false, (b) => t.workorderAdd = b),
            _Cell(t.workorderEdit ?? false, (b) => t.workorderEdit = b),
          ]),
          _matrixRow('Documents', [
            _Cell(t.documentsView ?? false, (b) => t.documentsView = b),
            _Cell(t.documentsAdd ?? false, (b) => t.documentsAdd = b),
            _Cell(t.documentsEdit ?? false, (b) => t.documentsEdit = b),
          ]),
        ],
      ),
    );
  }

  Widget _saveButton(String section) {
    final bool busy = _savingSection == section;
    return Material(
      color: _navy,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _savingSection != null ? null : () => _save(section),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          child: busy
              ? const SpinKitFadingCircle(color: Colors.white, size: 24)
              : const Text(
                  'Save',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback onTap) {
    return Material(
      color: _navy,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// A single permission checkbox cell: its current [value] plus an [onSet]
/// callback that writes the new value back onto the permission model.
class _Cell {
  final bool value;
  final void Function(bool) onSet;
  _Cell(this.value, this.onSet);
}
