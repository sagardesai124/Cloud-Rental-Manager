import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/StaffModule/repository/properties_summery.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision_box.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/repository.dart';

import '../../../../../model/properties.dart';
import '../../../../../model/properties_summery.dart';
import '../../../../../model/unitsummery_propeties.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/custom_drawer.dart';

class Moveout_properties extends StatefulWidget {
  Rentals properties;

  String moveOutDate;
  String leaseId;
  TenantData tenant;
  final List<TenantData> tenants;

  Moveout_properties(
      {required this.properties,
      required this.tenants,
      required this.moveOutDate,
      required this.leaseId,
      required this.tenant});

  @override
  State<Moveout_properties> createState() => _Moveout_propertiesState();
}

class _Moveout_propertiesState extends State<Moveout_properties> {
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();

  // Built once: a page rebuild (keyboard, rotation) must keep the dates and
  // tenants the user picked.
  final Map<String, TextEditingController> startDateControllers = {};
  final Map<String, TextEditingController> moveoutDateControllers = {};
  bool _moveoutDefaultsSet = false;
  LeaseEndAnswer _leaseEnd = const LeaseEndAnswer();

  @override
  void dispose() {
    startdateController.dispose();
    enddateController.dispose();
    for (final c in startDateControllers.values) {
      c.dispose();
    }
    for (final c in moveoutDateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
  late Future<List<unit_properties>> futureUnitsummery;
  late Future<List<TenantData>> futurePropertysummery;

  bool isMovedOut = false;
  bool isLoading = false;
  @override
  void initState() {
    futureUnitsummery =
        Properies_summery_Repo().fetchunit(widget.properties.rentalId ?? "");
    futureUnitsummery =
        Properies_summery_Repo().fetchunit(widget.properties.rentalId ?? "");

    futurePropertysummery = Properies_summery_Repo()
        .fetchPropertiessummery(widget.properties.rentalId!);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: MoveoutColors.pageBg,
      drawer: CustomDrawerStaff(
        currentpage: "Leases",
        dropdown: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          key: const Key('moveout-page'),
          padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width < 500 ? 16 : 24,
              16,
              MediaQuery.of(context).size.width < 500 ? 16 : 24,
              24),
          child: buildMoveout(widget.tenant, tenants: widget.tenants),
        ),
      ),
    );
  }

  Widget buildMoveout(TenantData tenant, {List<TenantData>? tenants}) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    widget.moveOutDate = dateProvider.formatCurrentDate(tenant.endDate!);
    startdateController.text = dateProvider
        .formatCurrentDate(DateTime.now().toIso8601String().split('T')[0]);
    // Convert to stateful list to track selection changes
    final TenantData leaseTenant = tenant;

    //List<TenantData> selectedTenants = tenants ?? [];
    List<TenantData> selectedTenants =
        tenants!.where((t) => t.moveoutDate == null).toList();

    for (var t in _moveoutDefaultsSet ? <TenantData>[] : selectedTenants) {
      if (!startDateControllers.containsKey(t.tenantId)) {
        startDateControllers[t.tenantId!.first] = TextEditingController();
      }
      if (!moveoutDateControllers.containsKey(t.tenantId)) {
        moveoutDateControllers[t.tenantId!.first] = TextEditingController();
      }

      // Set default values for each tenant
      startDateControllers[t.tenantId!.first]!.text = dateProvider
          .formatCurrentDate(DateTime.now().toIso8601String().split('T')[0]);
      moveoutDateControllers[t.tenantId!.first]!.text =
          dateProvider.formatCurrentDate(t.endDate!);

      // Set default selection
      t.isSelected = (t.tenantId == tenant.tenantId);
    }
    _moveoutDefaultsSet = true;

    // Web 2.2: a move-out that leaves nobody on a fixed-term lease asks
    // whether the lease ends (lease_end_decision.dart). Only this lease's
    // tenants count; the list holds every tenant of the rental.
    String? idOf(TenantData t) =>
        (t.tenantId ?? []).isNotEmpty ? t.tenantId!.first : null;
    List<String> selectedMoveOutDates() => selectedTenants
        .where((t) => t.isSelected)
        .map((t) => reverseFormatDate(moveoutDateControllers[idOf(t)]!.text))
        .toList();
    // Web's check before sending: a tenant is ticked and each ticked
    // tenant has both dates.
    bool moveOutDatesMissing() {
      final ticked = selectedTenants.where((t) => t.isSelected).toList();
      return moveoutDatesMissing(
        ticked.map((t) => startDateControllers[idOf(t)]?.text ?? '').toList(),
        ticked.map((t) => moveoutDateControllers[idOf(t)]?.text ?? '').toList(),
      );
    }
    bool askLeaseEnd() => shouldAskLeaseEnd(
          leaseType: leaseTenant.leaseType,
          leaseEndDate: leaseTenant.endDate,
          activeTenantIds: tenants
              .where((t) =>
                  t.leaseId == leaseTenant.leaseId &&
                  (t.moveoutDate ?? '').isEmpty &&
                  (t.moveoutNoticeGivenDate ?? '').isEmpty)
              .map(idOf),
          selectedTenantIds:
              selectedTenants.where((t) => t.isSelected).map(idOf),
          selectedMoveOutDates: selectedMoveOutDates(),
        );

    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MoveoutHeader(),
              const SizedBox(height: 14),
              const MoveoutInfoBanner(),
              const SizedBox(height: 14),
              MoveoutPropertyDetails(
                address: '${widget.properties.rentalAddress}',
                leaseType: '${tenant.leaseType}',
                startEnd:
                    '${dateProvider.formatCurrentDate(tenant.startDate!)} to ${dateProvider.formatCurrentDate(tenant.endDate!)}',
              ),
              const SizedBox(height: 14),
              MoveoutCard(
                title: 'Tenant Details',
                child: Column(
                  children: selectedTenants.map((tenant) {
                    return MoveoutTenantTile(
                      name: '${tenant.firstName} ${tenant.lastName}',
                      selected: tenant.isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          tenant.isSelected = value ?? false;
                        });
                      },
                      noticeField: buildDateField(
                        startDateControllers[tenant.tenantId!.first]!,
                        enabled: tenant.isSelected,
                      ),
                      moveOutField: buildDateField(
                        moveoutDateControllers[tenant.tenantId!.first]!,
                        enabled: tenant.isSelected,
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
                busy: isLoading,
                onCancel: () {
                  Navigator.pop(context);
                },
                onMoveOut: () async {
                  if (isLoading) return;
                  if (moveOutDatesMissing()) {
                    Fluttertoast.showToast(msg: moveoutDatesRequiredMessage);
                    return;
                  }
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
                  setState(() => isLoading = true);
                  final leaseEndPayload = buildLeaseEndPayload(
                    ask: askEnd,
                    answer: _leaseEnd,
                    selectedMoveOutDates: selectedMoveOutDates(),
                  );
                  String? tenantId =
                      tenant.tenantId != null && tenant.tenantId!.isNotEmpty
                          ? tenant.tenantId!.first
                          : null;
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  String? id = prefs.getString("adminId");

                  List<Map<String, dynamic>> multipletenant = [];
                  for (tenant in selectedTenants) {
                    if (tenant.isSelected) {
                      String moveoutNoticeGivenDate =
                          startDateControllers[tenant.tenantId!.first]!
                              .text;
                      String moveoutdate =
                          moveoutDateControllers[tenant.tenantId!.first]!
                              .text;
                      multipletenant.add({
                        'admin_id': id,
                        'tenant_id': tenant.tenantId!.first,
                        'lease_id': tenant.leaseId,
                        'moveout_notice_given_date':
                            reverseFormatDate(moveoutNoticeGivenDate!),
                        'moveout_date': reverseFormatDate(moveoutdate!),
                      });
                    }
                  }

                  await LeaseMoveoutRepository()
                      .addMoveoutTenant(
                          adminId: id!,
                          tenantId: tenantId,
                          leaseId: leaseTenant.leaseId,
                          moveoutDate:
                              reverseFormatDate(widget.moveOutDate),
                          moveoutNoticeGivenDate:
                              reverseFormatDate(startdateController.text),
                          multitenantdata: multipletenant,
                          leaseEnd: leaseEndPayload)
                      .then((value) {
                    if (!mounted) return;
                    setState(() {
                      isLoading = false;
                      isMovedOut = true;
                    });
                    reload_Screen();
                    Navigator.pop(context, true);
                  }).catchError((e) {
                    if (!mounted) return;
                    setState(() {
                      isLoading = false;
                    });
                  });
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget buildTableCell(Widget child) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: child,
      ),
    );
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
                      initialDate: moveoutPickerInitialDate(controller.text),
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
                      final dateProvider =
                          Provider.of<DateProvider>(context, listen: false);
                      controller.text = dateProvider.formatCurrentDate(
                          pickedDate.toIso8601String().split('T')[0]);
                      //});
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

  reload_Screen() {
    setState(() {
      futureUnitsummery =
          Properies_summery_Repo().fetchunit(widget.properties.rentalId ?? "");
    });
  }
}
