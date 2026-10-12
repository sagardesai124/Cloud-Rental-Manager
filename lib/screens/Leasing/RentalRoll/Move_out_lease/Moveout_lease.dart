import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/lease_end_decision_box.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/moveout_form_ui.dart';
import 'package:three_zero_two_property/screens/Rental/Properties/moveout/repository.dart';

import '../../../../model/LeaseSummary.dart';
import '../../../../provider/dateProvider.dart';
import '../../../../repository/lease.dart';
import '../../../../widgets/appbar.dart';
import '../../../../widgets/custom_drawer.dart';

class MoveoutScreen extends StatefulWidget {
  final LeaseTenant tenant;
  String enddate;
  String moveOutDate;
  String leaseId;

  final List<LeaseTenant> tenants;

  MoveoutScreen(
      {required this.tenant,
      required this.tenants,
      required this.enddate,
      required this.moveOutDate,
      required this.leaseId});

  @override
  State<MoveoutScreen> createState() => _MoveoutScreenState();
}

class _MoveoutScreenState extends State<MoveoutScreen> {
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();

  // Built once: a page rebuild (date picker, file description, keyboard)
  // must keep the dates and tenants the user picked.
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
  late Future<List<LeaseTenant>> futureLeasetenant;
  bool isMovedOut = false;
  bool isLoading = false;
  @override
  void initState() {
    futureLeasetenant = LeaseRepository.fetchLeaseTenants(widget.leaseId);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: MoveoutColors.pageBg,
      drawer: CustomDrawer(
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

  Widget buildMoveout(LeaseTenant tenant, {List<LeaseTenant>? tenants}) {
    // moveOutDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // moveOutDate = DateFormat('yyyy-MM-dd').format(DateTime.parse(widget.enddate!));

    // Convert to stateful list to track selection changes
    Map<String, String> moveOutDates = {};
    final LeaseTenant leaseTenant = tenant;

    List<LeaseTenant> selectedTenants =
        tenants!.where((t) => t.moveoutDate == "").toList();

    for (var t in _moveoutDefaultsSet ? <LeaseTenant>[] : selectedTenants) {
      if (!startDateControllers.containsKey(t.tenantId)) {
        startDateControllers[t.tenantId!] = TextEditingController();
      }
      if (!moveoutDateControllers.containsKey(t.tenantId)) {
        moveoutDateControllers[t.tenantId!] = TextEditingController();
      }

      // Set default values for each tenant
      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      startDateControllers[t.tenantId!]!.text = dateProvider
          .formatCurrentDate(DateFormat('yyyy-MM-dd').format(DateTime.now()));
      moveoutDateControllers[t.tenantId!]!.text =
          dateProvider.formatCurrentDate(t.endDate!);

      // Set default selection
      t!.isSelected = (t.tenantId == tenant.tenantId);
    }
    _moveoutDefaultsSet = true;

    // Web 2.2: a move-out that leaves nobody on a fixed-term lease asks
    // whether the lease ends (lease_end_decision.dart).
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

    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    widget.moveOutDate = dateProvider
        .formatCurrentDate(widget.enddate!); // Store the original format
    //startdateController.text = moveOutDate;
    startdateController.text = dateProvider
        .formatCurrentDate(DateFormat('yyyy-MM-dd').format(DateTime.now()));
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
                  '${Provider.of<DateProvider>(context, listen: false).formatCurrentDate(tenant.startDate!)} to ${Provider.of<DateProvider>(context, listen: false).formatCurrentDate(tenant.endDate!)}',
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
            const SizedBox(height: 14),
            MoveoutUploadCard(
              onTap: pickFiles,
              // Picked-file list keeps working as before; its redesign is
              // planned as its own task.
              files: selectedFiles.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SingleChildScrollView(
                child: Column(
                  children: selectedFiles.asMap().entries.map((entry) {
                    int index = entry.key;
                    FileData fileData = entry.value;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fileData.file.path.split('/').last,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey),
                                onPressed: () => removeFile(index),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Enter description',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            onChanged: (value) =>
                                updateDescription(index, value),
                          ),
                          const SizedBox(height: 10),
                          Divider(thickness: 1),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
                    ),
            ),
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
                List<String> descriptions =
                    selectedFiles.map((file) => file.description).toList();
                for (tenant in selectedTenants) {
                  if (tenant.isSelected!) {
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
                List<File> selectfiles =
                    selectedFiles.map((file) => file.file).toList();

                await LeaseMoveoutRepository()
                    .addMoveoutTenantfromlease(
                  adminId: id!,
                  tenantId: tenantId,
                  leaseId: tenant.leaseId,
                  moveoutDate: reverseFormatDate(widget.moveOutDate),
                  moveoutNoticeGivenDate:
                      reverseFormatDate(startdateController.text),
                  fileDescriptions: descriptions,
                  selectedFiles: selectfiles,
                  multitenantdata: multipletenant,
                  leaseEnd: leaseEndPayload,
                )
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
            const SizedBox(height: 8),
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

  final List<FileData> selectedFiles = [];

  Future<void> pickFiles() async {
    if (selectedFiles.length >= 10) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Maximum 10 files allowed')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (result != null) {
      for (var file in result.files) {
        if (selectedFiles.length >= 10) break;

        if (file.size > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} exceeds 5MB limit')),
          );
          continue;
        }

        final fileObj = File(file.path!);

        setState(() {
          selectedFiles.add(FileData(file: fileObj));
        });
      }
    }
  }

  void removeFile(int index) {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  void updateDescription(int index, String description) {
    setState(() {
      selectedFiles[index].description = description;
    });
  }

  reload_screen() {
    setState(() {});
  }

  Widget buildDateField(TextEditingController controller,
      {bool enabled = false}) {
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
                hintText: Provider.of<DateProvider>(context, listen: false)
                    .dateFormat
                    .toUpperCase(),
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
                      setState(() {
                        final dateProvider =
                            Provider.of<DateProvider>(context, listen: false);
                        String apiFormatDate =
                            DateFormat('yyyy-MM-dd').format(pickedDate);
                        controller.text =
                            dateProvider.formatCurrentDate(apiFormatDate);
                      });
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

class FileData {
  final File file;
  String description;

  FileData({required this.file, this.description = ''});
}
