import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/Model/applicant_summery_model.dart';

import 'package:three_zero_two_property/constant/constant.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/provider/lease_provider.dart';

import '../../../../repository/applicant_summery_repo.dart';
import 'ApplicantContent.dart';
import 'ContactInfoContent.dart';
import 'SummaryContent.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/newAddLease.dart';

import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';
// import 'package:three_zero_two_property/repository/properties_summery.dart';
import '../../../../widgets/appbar.dart';

import '../../../../widgets/drawer_tiles.dart';
import '../../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class applicant_summery extends StatefulWidget {
  String? applicant_id;
  applicant_summery({super.key, this.applicant_id});

  @override
  State<applicant_summery> createState() => _applicant_summeryState();
}

class _applicant_summeryState extends State<applicant_summery>
    with SingleTickerProviderStateMixin, NetworkRetryState {
  List<String> applicantCheckedChecklist = [
    "CreditCheck",
    "EmploymentVerification",
    "ApplicationFee",
    "IncomeVerification",
    "LandlordVerification"
  ];
  List<String> applicantChecklist = [];
  final Map<String, String> displayNames = {
    "CreditCheck": "Credit and background check",
    "EmploymentVerification": "Employment verification",
    "ApplicationFee": "Application fee collected",
    "IncomeVerification": "Income verification",
    "LandlordVerification": "Landlord verification",
  };

  bool addcheckbox = false;
  TextEditingController startdateController = TextEditingController();
  TextEditingController enddateController = TextEditingController();
  TextEditingController checkvalue = TextEditingController();
  List formDataRecurringList = [];
  late Future<applicant_summery_details> futureLeaseSummary;
  String? _selectedValue = "Select";
  TabController? _tabController;
  List<String> items = ["Select", "Approved", "Rejected"];
  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The data calls from `initState` only — controllers, listeners and
  /// filter defaults are not repeated, so a reload keeps the user's view.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      futureLeaseSummary = ApplicantSummeryRepository.getApplicantSummary(widget.applicant_id!);;
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    futureLeaseSummary =
        ApplicantSummeryRepository.getApplicantSummary(widget.applicant_id!);
    _tabController = TabController(length: 4, vsync: this);
    super.initState();
  }
  ConnectivityResult? _connectivityResult ;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    startdateController.dispose();
    enddateController.dispose();
    checkvalue.dispose();
    super.dispose();
  }
  void checkInternet()async{

    var connectiondata;
    connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus can report a stale `none` after the
    // connection is back; confirm before believing it.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    setState(() {
      _connectivityResult = connectiondata;
    });

  }

  /// Updates the applicant's status and hands the server's own message back
  /// to the caller.
  ///
  /// Single-owner messaging: this method deliberately shows no toast. It used
  /// to toast on every outcome while the call sites toasted again, so one tap
  /// put two messages on screen - and on failure the server's real reason was
  /// immediately followed by a generic one that contradicted it. The call site
  /// owns the message now; `message` carries the server's text so a failure can
  /// say why instead of just "Failed".
  Future<({bool ok, String? message})> updateApplicantStatus(
      String applicantId, String status, String rentalId, String unitId,
      {String rejectionReason = ''}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    final body = jsonEncode({
      // Web parity: statusUpdatedBy is NOT sent — the backend resolves the
      // real user from the auth token (hardcoding "Admin" mislabeled history).
      "status": status,
      "rental_id": rentalId,
      "unit_id": unitId,
      "rejection_reason": rejectionReason,
    });

    try {
      final response = await apiPut(
        Uri.parse('$Api_url/api/applicant/applicant/$applicantId/status'),
        headers: {
          'Content-Type': 'application/json',
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
        },
        body: body,
      );

      var responseData = jsonDecode(response.body);

      final String? serverMessage = responseData['message'] as String?;
      if (response.statusCode == 200 && responseData['statusCode'] == 200) {
        return (ok: true, message: serverMessage);
      }
      return (ok: false, message: serverMessage);
    } catch (error) {
      logError('Exception occurred: $error');
      return (ok: false, message: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return
      Scaffold(
      // appBar: widget302.,
      appBar: widget_302_Staff.App_Bar(context: context),
      backgroundColor: const Color(0xFFF4F6F9),
      drawer: CustomDrawerStaff(
        currentpage: "Applicants",
        dropdown: true,
      ),
      body: !isOffline ?
      SingleChildScrollView(
        child: FutureBuilder<applicant_summery_details>(
            future: futureLeaseSummary,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: MediaQuery.of(context).size.height/1.2,
                  child: const Center(
                    child: SpinKitSpinningLines(
                      color: Colors.black,
                      size: 55.0,
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data == null) {
                return const Center(child: Text('No data found.'));
              } else {
                final applicantSummary = snapshot.data!;
                if (snapshot.data!.applicantStatus != null &&
                    snapshot.data!.applicantStatus!.isNotEmpty) {
                  final status = snapshot.data!.applicantStatus!.last.status;
                  if (status == "Approved" || status == "Rejected") {
                    _selectedValue = status;
                  } else {
                    _selectedValue = 'Select';
                  }
                } else {
                  _selectedValue = 'Select';
                }
        
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(
                        height: 20,
                      ),
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFDBE0E5)),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                                color: blueColor,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Text(
                              '${snapshot.data!.applicantFirstName} ${snapshot.data!.applicantLastName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      // ── Web parity: show the stored rejection reason
                      // under the header when the applicant is rejected ──
                      Builder(
                        builder: (context) {
                          final statusList = snapshot.data!.applicantStatus;
                          final last =
                              (statusList != null && statusList.isNotEmpty)
                                  ? statusList.last
                                  : null;
                          final reason = last?.rejectionReason?.trim() ?? '';
                          if (last?.status != 'Rejected' || reason.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFDBE0E5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reason for rejection',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: Color(0xFF8A95A8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                      color: blueColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // ── Status action buttons (design swap of the old
                      // dropdown + MOVE IN; handlers unchanged) ──
                      Builder(
                        builder: (context) {
                          final statusList = snapshot.data!.applicantStatus;
                          final String? lastStatus =
                              (statusList != null && statusList.isNotEmpty)
                                  ? statusList.last.status
                                  : null;
                          final bool isMovedin =
                              snapshot.data!.isMovedin ?? false;

                          Future<void> changeStatus(String value,
                              {String rejectionReason = ''}) async {
                            setState(() {
                              _selectedValue = value;
                              _statusUpdating = true;
                              _updatingStatusValue = value;
                            });
                            final rentalId =
                                snapshot.data?.leaseData?.rentalId;
                            final unitId = snapshot.data?.leaseData?.unitId;

                            // Call the API to update the applicant status
                            // (web sends these empty when no lease data —
                            // never crash on a missing leaseData).
                            final result = await updateApplicantStatus(
                                widget.applicant_id!,
                                value,
                                rentalId ?? '',
                                unitId ?? '',
                                rejectionReason: rejectionReason);

                            if (result.ok) {
                              Fluttertoast.showToast(
                                msg:
                                    'The Applicant Status has been changed to $value',
                                backgroundColor: Colors.green,
                                textColor: Colors.white,
                              );
                              // Web parity: stay on the page and refresh so
                              // the buttons/tabs update in place.
                              setState(() {
                                futureLeaseSummary = ApplicantSummeryRepository
                                    .getApplicantSummary(widget.applicant_id!);
                              });
                            } else {
                              // Show the server's own reason when it sent
                              // one; the generic text is only a fallback for
                              // a transport failure with no body.
                              Fluttertoast.showToast(
                                msg: result.message ??
                                    'Failed to update applicant status',
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                            if (mounted) {
                              setState(() {
                                _statusUpdating = false;
                                _updatingStatusValue = '';
                              });
                            }
                          }

                          // Web parity: rejecting requires a reason, saved
                          // with the status entry in the history.
                          void openRejectDialog() {
                            TextEditingController reasonController =
                                TextEditingController();
                            Alert(
                              context: context,
                              type: AlertType.warning,
                              title: "Reject Applicant",
                              desc:
                                  "Please enter a reason for rejecting this applicant. This will be saved in the applicant history.",
                              content: Column(
                                children: <Widget>[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 45,
                                    child: TextField(
                                      controller: reasonController,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Enter reason for rejection',
                                        contentPadding: EdgeInsets.only(
                                            top: 8, left: 15),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              style: const AlertStyle(
                                backgroundColor: Colors.white,
                              ),
                              buttons: [
                                DialogButton(
                                  child: const Text(
                                    "Reject",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 18),
                                  ),
                                  onPressed: () {
                                    if (reasonController.text.trim().isEmpty) {
                                      Fluttertoast.showToast(
                                          msg:
                                              "Please enter a reason for rejection");
                                    } else {
                                      Navigator.pop(context);
                                      changeStatus('Rejected',
                                          rejectionReason:
                                              reasonController.text.trim());
                                    }
                                  },
                                  color: const Color(0xFFDC3545),
                                ),
                                DialogButton(
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                        color: blueColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  color: Colors.white,
                                  radius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: blueColor, width: 1.5),
                                ),
                              ],
                            ).show();
                          }

                          void openCreateLease() {
                            // Mirror admin + web: clear stale selections and
                            // pass leaseId so the add-lease form prefills
                            // (web staff route also carries lease_id).
                            Provider.of<SelectedCosignersProvider>(context,
                                    listen: false)
                                .clearCosigner();
                            Provider.of<SelectedTenantsProvider>(context,
                                    listen: false)
                                .clearTenant();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => addLease3(
                                  applicantId: widget.applicant_id,
                                  rentalId: snapshot.data?.leaseData?.rentalId,
                                  unitId: snapshot.data?.leaseData?.unitId,
                                  leaseId: snapshot.data?.leaseData?.leaseId,
                                ),
                              ),
                            );
                          }

                          Widget actionButton({
                            required Widget child,
                            required Color background,
                            Color? borderColor,
                            VoidCallback? onTap,
                          }) {
                            return GestureDetector(
                              onTap: onTap,
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: borderColor != null
                                      ? Border.all(
                                          color: borderColor, width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: child,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (lastStatus == 'Approved') {
                            // Web parity: once the lease exists the web
                            // shows a green "Lease Created" badge instead
                            // of the action buttons.
                            if (isMovedin) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFF4CAF50)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.check,
                                          color: Color(0xFF2E7D32),
                                          size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Lease Created',
                                        style: TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: actionButton(
                                      background:
                                          isMovedin ? Colors.grey : blueColor,
                                      onTap: (isMovedin || _statusUpdating)
                                          ? null
                                          : openCreateLease,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.description_outlined,
                                              color: Colors.white, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Create Lease',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: actionButton(
                                      background: Colors.white,
                                      borderColor: isMovedin
                                          ? Colors.grey
                                          : const Color(0xFFDC3545),
                                      onTap: (isMovedin || _statusUpdating)
                                          ? null
                                          : openRejectDialog,
                                      child: (_statusUpdating &&
                                              _updatingStatusValue ==
                                                  'Rejected')
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFFDC3545),
                                              ),
                                            )
                                          : Text(
                                              'Change to Reject',
                                              style: TextStyle(
                                                color: isMovedin
                                                    ? Colors.grey
                                                    : const Color(0xFFDC3545),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (lastStatus == 'Rejected') {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: actionButton(
                                      background: Colors.white,
                                      borderColor: isMovedin
                                          ? Colors.grey
                                          : const Color(0xFF28A745),
                                      onTap: (isMovedin || _statusUpdating)
                                          ? null
                                          : () => changeStatus('Approved'),
                                      child: (_statusUpdating &&
                                              _updatingStatusValue ==
                                                  'Approved')
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Color(0xFF28A745),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check,
                                                  color: isMovedin
                                                      ? Colors.grey
                                                      : const Color(
                                                          0xFF28A745),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Approve Applicant',
                                                  style: TextStyle(
                                                    color: isMovedin
                                                        ? Colors.grey
                                                        : const Color(
                                                            0xFF28A745),
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: actionButton(
                                      background: const Color(0xFFFDECEC),
                                      borderColor: const Color(0xFFF1AEB5),
                                      onTap: null,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.close,
                                              color: Color(0xFFDC3545),
                                              size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Rejected',
                                            style: TextStyle(
                                              color: Color(0xFFDC3545),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Undecided — no action buttons (Back button in
                          // the header is the only action).
                          return const SizedBox.shrink();
                        },
                      ),
                      // ── OLD status dropdown + MOVE IN button (kept for
                      // reference — replaced by the status buttons above) ──
                      /*
                      Row(
                        children: [
                          const SizedBox(
                            width: 10,
                          ),
                          DropdownButtonHideUnderline(
                            child: Material(
                              elevation: 3,
                              child: DropdownButton2<String>(
                                isExpanded: true,
                                hint: const Row(
                                  children: [
                                    SizedBox(
                                      width: 4,
                                    ),
                                    Expanded(
                                      child: Text(
                                        '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF8A95A8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                items: items
                                    .map((String item) => DropdownMenuItem<String>(
                                          value: item,
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                value: _selectedValue,
                                onChanged: snapshot.data!.isMovedin!
                                    ? null
                                    : (value) async {
                                        setState(() {
                                          _selectedValue = value;
                                        });
                                        if (value != null) {
                                          final rentalId =
                                              snapshot.data!.leaseData!.rentalId;
                                          final unitId =
                                              snapshot.data!.leaseData!.unitId;

                                          // Call the API to update the applicant status
                                          final result =
                                              await updateApplicantStatus(
                                                  widget.applicant_id!,
                                                  value,
                                                  rentalId!,
                                                  unitId!);

                                          if (result.ok) {
                                            Fluttertoast.showToast(
                                              msg:
                                                  'The Applicant Status has been changed to $value',
                                              backgroundColor: Colors.green,
                                              textColor: Colors.white,
                                            );
                                            Navigator.pop(context);
                                          } else {
                                            Fluttertoast.showToast(
                                              msg: result.message ??
                                                  'Failed to update applicant status',
                                              backgroundColor: Colors.red,
                                              textColor: Colors.white,
                                            );
                                          }
                                        }
                                      },
                                buttonStyleData: ButtonStyleData(
                                  height: MediaQuery.of(context).size.width < 500
                                      ? 40
                                      : 50,
                                  width: MediaQuery.of(context).size.width < 500
                                      ? MediaQuery.of(context).size.width * .35
                                      : MediaQuery.of(context).size.width * .4,
                                  padding:
                                      const EdgeInsets.only(left: 14, right: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: snapshot.data!.isMovedin!
                                          ? Colors.grey
                                          : Color(0xFF8A95A8),
                                    ),
                                    color: snapshot.data!.isMovedin!
                                        ? Colors.grey.shade300
                                        : Colors.white,
                                  ),
                                  elevation: 0,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 200,
                                  width: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  offset: const Offset(-20, 0),
                                  scrollbarTheme: ScrollbarThemeData(
                                    radius: const Radius.circular(40),
                                    thickness: MaterialStateProperty.all(6),
                                    thumbVisibility:
                                        MaterialStateProperty.all(true),
                                  ),
                                ),
                                menuItemStyleData: const MenuItemStyleData(
                                  height: 40,
                                  padding: EdgeInsets.only(left: 14, right: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 20,
                          ),
                          _selectedValue == 'Rejected'
                              ? Container()
                              : ElevatedButton(
                                  style: ButtonStyle(
                                    elevation: MaterialStateProperty.all(3),
                                    backgroundColor:
                                        MaterialStateProperty.resolveWith<Color>(
                                      (Set<MaterialState> states) {
                                        if (states
                                            .contains(MaterialState.disabled)) {
                                          return Colors.grey; // Disabled color
                                        }
                                        return blueColor; // Enabled color
                                      },
                                    ),
                                    shape: MaterialStateProperty.all(
                                      const RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.all(Radius.circular(5)),
                                      ),
                                    ),
                                    minimumSize: MaterialStateProperty.all(
                                        const Size(80, 40)),
                                  ),
                                  onPressed: snapshot.data!.isMovedin!
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => addLease3(
                                                applicantId: widget.applicant_id,
                                                rentalId: snapshot
                                                    .data?.leaseData?.rentalId,
                                                unitId: snapshot
                                                    .data?.leaseData?.unitId,
                                              ),
                                            ),
                                          );
                                        },
                                  child: const Center(
                                    child: Text(
                                      "MOVE IN",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                      */
                      /* Row(
                        children: [
                          SizedBox(
                            width: 10,
                          ),
                          Text(
                              '${determineStatus(snapshot.data!.data!.startDate, snapshot.data!.data!.endDate)}',
                              style: TextStyle(
                                  color: Color(0xFF8A95A8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ],
                      ),*/
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                        // 8 + the container's 4px inner gap = 12, so the
                        // pills line up exactly with the buttons above.
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EBF2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: (() {
                              // Tabs are built per-applicant: 'Contact Info'
                              // only exists once the latest status is
                              // Approved/Rejected (same rule as the web app).
                              final tabTitles = _tabTitles(snapshot.data!);
                              if (_selectedIndex >= tabTitles.length) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (mounted &&
                                      _selectedIndex >= tabTitles.length) {
                                    setState(() {
                                      _selectedIndex = 0;
                                    });
                                  }
                                });
                              }
                              final selectedIndex =
                                  _selectedIndex < tabTitles.length
                                      ? _selectedIndex
                                      : 0;
                              return List.generate(tabTitles.length, (index) {
                                final isSelected = selectedIndex == index;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedIndex = index;
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 250),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? blueColor : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Text(
                                          tabTitles[index],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isSelected ? Colors.white : const Color(0xFF8A95A8),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              });
                            })(),
                          ),
                        ),
                      ),

                      _buildTabContent(snapshot.data!),
                    ],
                  ),
                );
              }
            }),
      ): NoInternetView(onRetry: retryNow),
    );
  }
  int _selectedIndex = 0;
  // Web parity: disable the status buttons + show a spinner while the
  // status-update API call is in flight (prevents double-fire).
  bool _statusUpdating = false;
  String _updatingStatusValue = '';
  /// Latest applicant status decides whether the Contact Info tab exists
  /// (same rule as the web app's isApprovedOrRejected()).
  bool _isApprovedOrRejected(applicant_summery_details data) {
    if (data.applicantStatus == null || data.applicantStatus!.isEmpty) {
      return false;
    }
    final status = data.applicantStatus!.last.status;
    return status == 'Approved' || status == 'Rejected';
  }

  List<String> _tabTitles(applicant_summery_details data) {
    final tabs = <String>['Summary', 'Application'];
    if (_isApprovedOrRejected(data)) {
      tabs.add('Contact Info');
    }
    return tabs;
  }

  Widget _buildTabContent(applicant_summery_details data) {
    final tabTitles = _tabTitles(data);
    final index = _selectedIndex < tabTitles.length ? _selectedIndex : 0;
    switch (tabTitles[index]) {
      case 'Summary':
        return SummaryContent(
          applicant_id: widget.applicant_id!,
          summery: data,
        );
      case 'Application':
        return ApplicantContent(
          applicant_id: widget.applicant_id!,
          applicantDetail: data,
        );
      case 'Contact Info':
        return ContactInfoContent(
          // Remount (and refetch) whenever a new status entry is added so
          // the cards reflect the latest approve/reject without leaving.
          key: ValueKey('contact-info-${data.applicantStatus?.length ?? 0}'),
          applicantId: widget.applicant_id!,
          applicantDetail: data,
        );
      default:
        return Container();  // Fallback for safety
    }
  }
  Summery_page(applicant_summery_details summery) {
    applicantChecklist = List<String>.from(summery.applicantCheckedChecklist!);
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: applicantCheckedChecklist.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Checkbox(
                        activeColor: blueColor,
                        value:
                            summery.applicantCheckedChecklist!.contains(item),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value != false) {
                              summery.applicantCheckedChecklist!.add(item);
                              applicantChecklist.add(item);
                            } else {
                              summery.applicantCheckedChecklist!.remove(item);
                              applicantChecklist.remove(item);
                            }
                          });
                          updatecheckBox();
                        },
                      ),
                      Text(displayNames[item].toString()),
                    ],
                  ),
                );
              }).toList(),
            ),
            Column(
              children: summery.applicantChecklist!.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Checkbox(
                        activeColor: blueColor,
                        value:
                            summery.applicantCheckedChecklist!.contains(item),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value != false) {
                              summery.applicantCheckedChecklist!.add(item);
                              applicantChecklist.add(item);
                            } else {
                              summery.applicantCheckedChecklist!.remove(item);
                              applicantChecklist.remove(item);
                            }
                          });
                          updatecheckBox();
                        },
                      ),
                      Text(item),
                      InkWell(
                          onTap: () {
                            summery.applicantChecklist!.remove(item);
                            updatecheckBoxnew(summery.applicantChecklist!);
                          },
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                          )),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (addcheckbox)
              Row(
                children: [
                  SizedBox(
                    height: 50,
                    width: 150,
                    child: TextFormField(
                      controller: checkvalue,
                      decoration: const InputDecoration(
                          hintText: "Enter Value",
                          border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        summery.applicantChecklist!.add(checkvalue.text);
                        checkvalue.text = "";
                        addcheckbox = false;
                      });
                      updatecheckBoxnew(summery.applicantChecklist!);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.green)),
                      child: const Icon(
                        Icons.check,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  InkWell(
                    onTap: () {
                      setState(() {
                        checkvalue.text = "";
                      });
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration:
                          BoxDecoration(border: Border.all(color: Colors.red)),
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(
              height: 10,
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  addcheckbox = !addcheckbox;
                });
                //  Navigator.pop(context);
              },
              child: Material(
                elevation: 3,
                borderRadius: const BorderRadius.all(
                  Radius.circular(5),
                ),
                child: Container(
                  height: 40,
                  width: 150,
                  decoration: const BoxDecoration(
                    //color: blueColor,
                    borderRadius: BorderRadius.all(
                      Radius.circular(5),
                    ),
                  ),
                  child:  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add),
                      Center(
                          child: Text(
                        "Add Checklist",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: blueColor),
                      )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color:blueColor),
                ),
                //width: ,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                     Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        "Updates",
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: blueColor),
                      ),
                    ),
                    // The middle column used to print a const placeholder
                    // ("The New Rental Application Status") on every row, and
                    // the three headings were blank. ApplicantStatus carries
                    // only status / statusUpdatedBy / updateAt, so there was no
                    // per-row value that column could ever have shown — the
                    // detail column beside it already carries all three.
                    DataTable(
                      columnSpacing: 20,
                      dataRowHeight:
                          80, // Adjust spacing between columns as needed
                      columns: const [
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Updated')),
                      ],
                      rows: summery.applicantStatus!.map((status) {
                        final statusMessage =
                            '${status.status} by ${status.statusUpdatedBy} at ${status.updateAt}';
                        return DataRow(cells: [
                          DataCell(Text(status.status ?? '')),
                          DataCell(Text(statusMessage)),
                        ]);
                      }).toList(),
                    ),
                    // "View More" had an empty onTap and nothing further to
                    // show — the table above already lists every status change.
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color:blueColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 16, right: 16, top: 16, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${summery.applicantFirstName} ${summery.applicantLastName}',
                          style:  TextStyle(
                              fontSize: 16,
                              color: blueColor,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(
                        height: 5,
                      ),
                       Text('Applicant',
                          style: TextStyle(
                              color: blueColor,
                              fontWeight: FontWeight.normal)),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.home,
                            color: Color.fromRGBO(138, 149, 168, 1),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            formatPhoneNumber('${summery.applicantHomeNumber}'),
                            // "${summery.applicantHomeNumber}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color.fromRGBO(138, 149, 168, 1),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_center_outlined,
                            color: Color.fromRGBO(138, 149, 168, 1),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            formatPhoneNumber('${summery.applicantBusinessNumber}'),
                            // "${summery.applicantBusinessNumber}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color.fromRGBO(138, 149, 168, 1),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.mobile,
                            color: Color.fromRGBO(138, 149, 168, 1),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            formatPhoneNumber('${summery.applicantPhoneNumber}'),
                            // "${summery.applicantPhoneNumber}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color.fromRGBO(138, 149, 168, 1),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.mail,
                            color: Color.fromRGBO(138, 149, 168, 1),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            "${summery.applicantEmail}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color.fromRGBO(138, 149, 168, 1),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  updatecheckBox() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    var checkvalue = {"applicant_checkedChecklist": applicantChecklist};
    final response = await apiPut(
      Uri.parse('$Api_url/api/applicant/applicant/${widget.applicant_id}'),
      headers: <String, String>{
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(checkvalue),
    );
    if (response.statusCode == 200) {
      // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');

      setState(() {});
    } else {
      // Log the response body for debugging
      throw Exception('Failed to update applicant data');
    }
  }

  updatecheckBoxnew(List applicant) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    var checkvalue = {"applicant_checklist": applicant};
    final response = await apiPut(
      Uri.parse(
          '$Api_url/api/applicant/applicant/${widget.applicant_id}/checklist'),
      headers: <String, String>{
        "id": "CRM ${prefs.getString('staff_id') ?? id}",
        "authorization": "CRM $token",
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(checkvalue),
    );
    if (response.statusCode == 200) {
      // Fluttertoast.showToast(msg: 'Applicant Updated Successfully');

      setState(() {});
    } else {
      // Log the response body for debugging
      throw Exception('Failed to update applicant data');
    }
  }
}
