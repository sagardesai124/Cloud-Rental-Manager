import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:csv/csv.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/StaffModule/repository/Payment_cronjob/Payment_cronjob_repo.dart';
import 'package:three_zero_two_property/StaffModule/screen/Leasing/RentalRoll/Edit_make_payment.dart';
import '../../../../provider/dateProvider.dart';
import '../../../repository/GetAdminAddressPdf.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/propertytype.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/Property_type.dart';
import '../../../repository/lease.dart';
import 'package:three_zero_two_property/screens/Leasing/Applicants/editApplicant.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import '../../../../Model/Preminum Plans/checkPlanPurchaseModel.dart';
import '../../../../Model/Preminum Plans/checkPlanPurchaseModel.dart';
import '../../../../provider/Plan Purchase/plancheckProvider.dart';
import 'make_payment.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:three_zero_two_property/screens/Property_Type/Edit_property_type.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../model/LeaseLedgerModel.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;

import 'addcard/AddCard.dart';
import 'enterCharge.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/TenantsModule/screen/financial/AddAchAccount/AddAchAccount.dart';
import '../scheduled_charges/ScheduledCharge.dart';
import 'package:three_zero_two_property/StaffModule/repository/ScheduledChargesRepository.dart';
import 'package:three_zero_two_property/Model/schduled_charge.dart';

class FinancialTable extends StatefulWidget {
  final String leaseId;
  final String tenantId;
  final String status;
  final String? rentalAddress;
  final String? rentalUnit;
  // Called on return from Scheduled Charges via the pending-charges link, so
  // the host screen can reload figures it shows outside this table.
  final VoidCallback? onScheduledChargesClosed;
  FinancialTable(
      {required this.leaseId,
      required this.status,
      required this.tenantId,
      this.rentalAddress,
      this.rentalUnit,
      this.onScheduledChargesClosed});
  @override
  _FinancialTableState createState() => _FinancialTableState();
}

class _FinancialTableState extends State<FinancialTable>
    with NetworkRetryState {
  int totalrecords = 0;
  late Future<List<propertytype>> futurePropertyTypes;
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
  TextEditingController _dateController = TextEditingController();
  TextEditingController _amountController = TextEditingController();
  TextEditingController _memoController = TextEditingController();
  // void sortData(List<leaseLedger> data) {
  //   if (sorting1) {
  //     data.sort((a, b) => ascending1
  //         ? a.propertyType!.compareTo(b.propertyType!)
  //         : b.propertyType!.compareTo(a.propertyType!));
  //   } else if (sorting2) {
  //     data.sort((a, b) => ascending2
  //         ? a.propertysubType!.compareTo(b.propertysubType!)
  //         : b.propertysubType!.compareTo(a.propertysubType!));
  //   } else if (sorting3) {
  //     data.sort((a, b) => ascending3
  //         ? a.createdAt!.compareTo(b.createdAt!)
  //         : b.createdAt!.compareTo(a.createdAt!));
  //   }
  // }
  _showRefundDialog(BuildContext context, Data data) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isLoading = false; // Flag to show loading indicator

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Refund Amount'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5.0),
                      child: Container(
                        height:
                            (MediaQuery.of(context).size.width < 500) ? 50 : 60,
                        padding: EdgeInsets.only(
                            top:
                                MediaQuery.of(context).size.width < 500 ? 9 : 5,
                            left: 10),
                        width: 250,
                        margin: const EdgeInsets.only(bottom: 6.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5.0),
                          color: blueColor,
                          boxShadow: [
                            const BoxShadow(
                              color: Colors.grey,
                              offset: Offset(0.0, 1.0),
                              blurRadius: 6.0,
                            ),
                          ],
                        ),
                        child: Text(
                          "Make Refund",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: MediaQuery.of(context).size.width < 500
                                  ? 21
                                  : MediaQuery.of(context).size.width * 0.035),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text("Date"),
                    buildCustomTextField(
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                          locale: const Locale('en', 'US'),
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
                          bool isfuture = pickedDate.isAfter(DateTime.now());
                          String formattedDate =
                              "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                          _dateController.text = formattedDate;
                        }
                      },
                      controller: _dateController,
                      hintText: 'Enter refund Date',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    const Text("Refund Amount"),
                    buildCustomTextField(
                      controller: _amountController,
                      hintText: 'Enter refund amount',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    const Text("Memo"),
                    buildCustomTextField(
                      controller: _memoController,
                      hintText: 'Enter memo',
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () async {
                        // WEB parity (RentRollDetail.js: `if (paymentLoader) return;`)
                        // A second tap while the refund is in flight would submit
                        // a second real refund.
                        if (isLoading) return;
                        if (_amountController.text.trim().isEmpty ||
                            (double.tryParse(_amountController.text) ?? 0) <= 0) {
                          Fluttertoast.showToast(
                              msg: "Please enter a valid refund amount");
                          return;
                        }
                        setState(() {
                          isLoading =
                              true; // Set loading to true when starting the refund process
                        });
                        SharedPreferences prefs =
                            await SharedPreferences.getInstance();
                        String? adminId = prefs.getString("adminId");
                        if (adminId == null ||
                            adminId.isEmpty ||
                            data.paymentId == null ||
                            data.paymenttype == null) {
                          Fluttertoast.showToast(
                              msg: "Missing payment details for refund");
                          setState(() {
                            isLoading = false;
                          });
                          return;
                        }
                        final message = await processRefund(
                          paymentType: data.paymenttype!,
                          paymentId: data.paymentId!, // Add your paymentId here
                          responseData: data,
                          amount: double.tryParse(_amountController.text) ?? 0.0,
                          date: reverseFormatDate(_dateController.text),
                          memo: _memoController.text,
                          adminId: adminId!,
                        );
                        // WEB parity: close the dialog only on success, then refresh.
                        if (message == "success") {
                          Navigator.pop(context);
                          reload_screen();
                          return;
                        }
                        // WEB parity: on failure the dialog stays open so the
                        // amount can be corrected and retried.
                        setState(() {
                          isLoading = false;
                        });
                        Alert(
                          context: context,
                          type: AlertType.error,
                          title: "Refund Failed!",
                          desc: "${message}",
                          style: const AlertStyle(
                            backgroundColor: Colors.white,
                            //  overlayColor: Colors.black.withOpacity(.8)
                          ),
                          buttons: [
                            DialogButton(
                              child: const Text(
                                "Ok",
                                style: TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              color: blueColor,
                            ),
                          ],
                        ).show();
                      },
                      child: Container(
                        width: 120,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: blueColor,
                        ),
                        child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  ) // Show loading indicator when isLoading is true
                                : const Text(
                                    'Make Refund',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.white),
                                  )),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 120,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: Colors.white,
                        ),
                        child: const Center(child: Text('Cancel')),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAlertvoid(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure you want to void this payment?",
      desc: "A void can be issued on this payment until it is settled",
      content: Column(
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter reason for void',
                contentPadding: EdgeInsets.only(top: 8, left: 15),
              ),
            ),
          ),
          // if (_errorText)
          //   Text(
          //     "Please fill in all fields correctly.",
          //     style: TextStyle(color: Colors.redAccent),
          //   ),
        ],
      ),
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Void",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            if (reason.text.isEmpty) {
              // setState(() {
              //  _errorText == true;
              // });
              Fluttertoast.showToast(msg: "Please enter a reason for deletion");
            } else {
              var data = await PaymentCronjobRepository().VoidCron(
                  pay_id: id, void_reason: reason.text, context: context);
              // Add your delete logic here
              if (data != null) {
                setState(() {
                  _leaseLedgerFuture = LeaseRepository()
                      .fetchLeaseLedger(leaseId: widget.leaseId);
                });
              }
              Navigator.of(context).pop();
            }
          },
          color: blueColor,
        ),
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
      ],
    ).show();
  }

  // Refund API function
  Future<String> processRefund({
    required String paymentType,
    required String paymentId,
    required Data responseData,
    required double amount,
    required String date,
    required String memo,
    required String adminId,
  }) async {
    try {
      // Prepare the commonData based on payment type
      final Map<String, dynamic> commonData = paymentType == "Card"
          ? {
              'admin_id': adminId,
              'transactionId': responseData.transactionid,
              'customer_vault_id': responseData.customer_vault_id,
              'billing_id': responseData.billing_id,
              'amount': amount,
              'payment_type': responseData.paymenttype,
              'total_amount': amount,
              'tenant_firstName': (responseData.tenantData ?? {})["tenant_firstName"],
              'tenant_lastName': (responseData.tenantData ?? {})["tenant_lastName"],
              'tenant_id': (responseData.tenantData ?? {})["tenant_id"],
              'lease_id': responseData.leaseId,
              'email_name': (responseData.tenantData ?? {})["tenant_email"],
              'type': responseData.type,
              'entry': (responseData.entry ?? []).map((entry) {
                return {
                  'amount': entry.amount,
                  'account': entry.account,
                  'date': date,
                  'memo': memo,
                };
              }).toList(),
            }
          : {
              'admin_id': adminId,
              'transactionId': responseData.transactionid,
              'amount': amount,
              'payment_type': responseData.paymenttype,
              'total_amount': amount,
              'tenant_firstName': (responseData.tenantData ?? {})["tenant_firstName"],
              'tenant_lastName': (responseData.tenantData ?? {})["tenant_lastName"],
              'tenant_id': (responseData.tenantData ?? {})["tenant_id"],
              //'tenant_firstName': responseData.tenantData.firstName,
              //'tenant_lastName': responseData.tenantData.lastName,
              //'tenant_id': responseData.tenantId,
              'lease_id': responseData.leaseId,
              'email_name': (responseData.tenantData ?? {})["tenant_email"],
              'type': responseData.type,
              'entry': (responseData.entry ?? []).map((entry) {
                return {
                  'amount': entry.amount,
                  'account': entry.account,
                  'date': date,
                  'memo': memo,
                };
              }).toList(),
            };

      // API URLs based on payment type
      String apiUrl;
      if (paymentType == "Cash" || paymentType == "Check") {
        apiUrl = '$Api_url/api/nmipayment/manual-refund/$paymentId';
      } else if (paymentType == "Card" || paymentType == "ACH") {
        apiUrl = '$Api_url/api/nmipayment/new-refund';
      } else {
        throw Exception("Unsupported payment type: $paymentType");
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      //String? id = prefs.getString("rentalid");
      String? id = prefs.getString('adminId');
      String? sid = prefs.getString("staff_id");
      String? token = prefs.getString('token');
      // Perform the POST request
      final response = await apiPost(
        Uri.parse(apiUrl),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $sid",
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refundDetails': commonData}),
      );

      if (response.statusCode == 200) {
        // Handle successful refund response
        return "success";
      } else {
        // Handle error case safely (body may be empty/HTML on failure)
        try {
          final responsedata = jsonDecode(response.body);
          if (responsedata is Map) {
            final data = responsedata["data"];
            if (data is Map && data["error"] != null) {
              return data["error"].toString();
            }
            if (responsedata["message"] != null) {
              return responsedata["message"].toString();
            }
          }
        } catch (_) {}
        return "Refund failed";
      }
    } catch (e) {
      return e.toString();
      // Handle exceptions during API calls
      logError('Refund error: $e');
    }
  }

  reload_screen() {
    setState(() {
      _leaseLedgerFuture =
          LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
    });
  }

  Widget buildCustomTextField({
    required TextEditingController controller,
    required String hintText,
    final void Function()? onTap,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    String? errorText,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(4, 4),
              blurRadius: 3,
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: false,
          readOnly: false,
          decoration: InputDecoration(
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
            border: InputBorder.none,
            hintText: hintText,
            errorText: errorText,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $hintText';
            }
            return null;
          },
          onFieldSubmitted: (value) {
            if (value.isNotEmpty) {
              // setState(() {
              //   _errorMessage = null;
              // });
            }
            // Custom logic when the user submits
          },
          onChanged: (value) {
            if (value.isNotEmpty) {
              // setState(() {
              //   _errorMessage = null;
              // });
            }
          },
        ),
      ),
    );
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
        // leading: Container(
        //   child: Icon(
        //     Icons.expand_less,
        //     color: Colors.transparent,
        //   ),
        // ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
              child: const Icon(
                Icons.expand_less,
                color: Colors.transparent,
              ),
            ),
            Expanded(
              child: GestureDetector(
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
                        ? Text("Date",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15))
                        : Text("Date",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                    // Text("Property", style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 3),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
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
                    Text("      Type",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(width: 5),
                  ],
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text("   Balance    ",
                        style: TextStyle(
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
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

  /// Single empty state for the transaction table. Previously two independent
  /// checks both fired when a search matched nothing — `currentPageData.isEmpty`
  /// rendered kNoSearchResults ("No Results Found") and a second
  /// `if (data.isEmpty)` block right below it rendered "No Data Available" —
  /// so the two stacked on top of each other. Show one, chosen by whether a
  /// search or date range is active: a filtered-to-nothing list is not the
  /// same thing as a ledger with no transactions at all.
  Widget _ledgerEmptyState(BuildContext context) {
    final bool isFiltered = searchvalue.isNotEmpty ||
        _fromDateApiFormat.isNotEmpty ||
        _toDateApiFormat.isNotEmpty;
    if (isFiltered) return kNoSearchResults(context);
    return Container(
      height: MediaQuery.of(context).size.height * .3,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              "assets/images/no_data.jpg",
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 10),
            Text(
              "No Data Available",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
            )
          ],
        ),
      ),
    );
  }
  late Future<LeaseLedger?> _leaseLedgerFuture;
  List<bool> _expanded = [];
  bool _leaseAchAccepted = false;

  List<ScheduledCharges> _pendingScheduled = [];

  // Pending scheduled charges (future-dated, not yet posted to the ledger).
  // Surfaces the same banner the web shows on the Financial/Ledger tab.
  Future<void> _fetchPendingScheduled() async {
    try {
      final list = await ScheduledChargesRepository()
          .fetchScheduledCharges(leaseid: widget.leaseId);
      if (!mounted) return;
      setState(() => _pendingScheduled = list);
    } catch (_) {
      if (mounted) setState(() => _pendingScheduled = []);
    }
  }

  DateTime? _parseSchedDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final iso = DateTime.tryParse(s.trim());
    if (iso != null) return iso;
    final p = s.trim().split('/');
    if (p.length == 3) {
      final m = int.tryParse(p[0]),
          d = int.tryParse(p[1]),
          y = int.tryParse(p[2]);
      if (m != null && d != null && y != null) return DateTime(y, m, d);
    }
    return null;
  }

  String? _nextScheduledLabel() {
    DateTime? earliest;
    for (final c in _pendingScheduled) {
      final d = _parseSchedDate(c.actionDate);
      if (d == null) continue;
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    if (earliest == null) return null;
    // Render the date in the user's configured DateProvider format (same as the ledger).
    final iso = DateFormat('yyyy-MM-dd').format(earliest);
    return Provider.of<DateProvider>(context, listen: false)
        .formatCurrentDate(iso);
  }

  Widget _buildScheduledChargeBanner() {
    if (_pendingScheduled.isEmpty) return const SizedBox.shrink();
    final n = _pendingScheduled.length;
    final next = _nextScheduledLabel();
    return Container(
      width: double.infinity,
      // Tighter above, real gap below — the banner used to sit far from
      // the section header yet flush against the card beneath it.
      margin: const EdgeInsets.fromLTRB(11, 2, 11, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0E3B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF6E3A6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFF9A6B00)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '$n scheduled charge${n == 1 ? '' : 's'} pending — not yet posted to the ledger'
                    '${next != null ? ' (next on $next)' : ''}.',
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: Color(0xFF6B5416),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFEBD9A6)),
          ),
          InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ScheduledChargeTable(
                    leaseID: widget.leaseId,
                    leaseRentalAddress: widget.rentalAddress,
                  ),
                ),
              );
              // Charges may have been added from Scheduled Charges;
              // reload the ledger so they show on return.
              if (!mounted) return;
              setState(() {
                _leaseLedgerFuture = LeaseRepository()
                    .fetchLeaseLedger(leaseId: widget.leaseId);
              });
              _fetchPendingScheduled();
              // The lease page's Balance Overview sits outside this table.
              widget.onScheduledChargesClosed?.call();
            },
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View Scheduled Charges',
                    style: TextStyle(
                        fontSize: 13,
                        color: blueColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 16, color: blueColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAchAccepted() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? sid = prefs.getString("staff_id");
      String? token = prefs.getString('token');
      final response = await apiGet(
        Uri.parse(
            '$Api_url/api/tenant/payment_settings/${widget.tenantId}/${widget.leaseId}'),
        headers: {
          "authorization": "CRM $token",
          // Staff must send their OWN staff_id here (not adminId) — matches the
          // other calls in this file and the web auth contract (CRM-4479).
          // Using adminId 401s for staff, leaving _leaseAchAccepted false and
          // hiding the "Add ACH" quick action.
          "id": "CRM $sid",
        },
      );
      final jsonData = json.decode(response.body);
      if (jsonData["statusCode"] == 200 || jsonData["statusCode"] == 201) {
        if (mounted) {
          setState(() {
            _leaseAchAccepted = jsonData['data']['achAccepted'] == true;
          });
        }
      }
    } catch (e) {
      logError("Error fetching ACH settings: $e");
    }
  }

  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _leaseLedgerFuture = LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
      _fetchAchAccepted();
      _fetchPendingScheduled();
    });
  }

  @override
  void initState() {
    super.initState();
    _leaseLedgerFuture =
        LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
    _expanded = List.generate(_pagedData.length, (_) => false);
    _fromDateController = TextEditingController(text: '');
    _toDateController = TextEditingController(text: '');
    _fetchAchAccepted();
    _fetchPendingScheduled();
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }
  // @override
  // void initState() {
  //   super.initState();
  //   futurePropertyTypes = PropertyTypeRepository().fetchPropertyTypes();
  // }

  void handleEdit(Data? ledge) async {
    // Handle edit action
    // print('Edit ${applicant.sId}');
    // var check = await Navigator.push(
    //     context,
    //     MaterialPageRoute(
    //         builder: (context) => EditApplicant(
    //               applicant: ,
    //               applicantId: ,
    //             )));
    // if (check == true) {
    //   setState(() {});
    // }
  }

  void _showAlert(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this Charge!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      content: Column(
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for deletion',
                  contentPadding: EdgeInsets.only(top: 8, left: 15)),
            ),
          ),
        ],
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () => Navigator.pop(context),
          color: grey,
        ),
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            var data = await LeaseRepository().DeleteCharge(id, reason.text);
            // Add your delete logic here
            if (data == 200)
              setState(() {
                _leaseLedgerFuture =
                    LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
              });
            Navigator.pop(context);
          },
          color: blueColor,
        )
      ],
    ).show();
  }

  void _showAlertpayment(BuildContext context, String id) {
    TextEditingController reason = TextEditingController();
    Alert(
      context: context,
      type: AlertType.warning,
      title: "Are you sure?",
      desc: "Once deleted, you will not be able to recover this payment!",
      style: const AlertStyle(
        backgroundColor: Colors.white,
      ),
      content: Column(
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),
          SizedBox(
            height: 45,
            child: TextField(
              controller: reason,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for deletion',
                  contentPadding: EdgeInsets.only(top: 8, left: 15)),
            ),
          ),
        ],
      ),
      buttons: [
        DialogButton(
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () => Navigator.pop(context),
          color: grey,
        ),
        DialogButton(
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          onPressed: () async {
            var data = await LeaseRepository().DeletePayment(id, reason.text);
            // Add your delete logic here
            if (data == 200)
              setState(() {
                _leaseLedgerFuture =
                    LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
              });
            Navigator.pop(context);
          },
          color: Colors.red,
        )
      ],
    ).show();
  }

  List<Data?> _tableData = [];
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Data?> get _pagedData {
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

  void _sort<T>(Comparable<T> Function(Data? d) getField, int columnIndex,
      bool ascending) {
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

  void handleDelete(Data? ledge) {
    _showAlert(context, ledge!.leaseId!);
    // Handle delete action
    // print('Delete ${property.sId}');
  }

  Widget _buildHeader<T>(
      String text, int columnIndex, Comparable<T> Function(Data? d)? getField) {
    return TableCell(
      child: InkWell(
        onTap: getField != null
            ? () {
                _sort(getField, columnIndex, !_sortAscending);
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

  Widget _buildDataCell(String text) {
    return TableCell(
      child: Container(
        height: 60,
        padding: const EdgeInsets.only(top: 20.0, left: 16),
        child: Text(text, style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _buildActionsCell(Data? data) {
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
              InkWell(
                onTap: () {
                  handleEdit(data);
                },
                child: const FaIcon(
                  FontAwesomeIcons.edit,
                  size: 30,
                ),
              ),
              const SizedBox(
                width: 15,
              ),
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
              border: Border.all(color: grey),
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
            color: _currentPage == 0 ? grey : blueColor,
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
                ? grey
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

  int? _expandedIndex; // Track the expanded row index

  Future<LeaseLedger?> fetchLeaseLedgerData() async {
    // Implement your data fetching logic
    return null; // Replace with actual data fetching
  }

  void _toggleExpansion(int index) {
    setState(() {
      _expandedIndex = _expandedIndex == index ? null : index;
    });
  }

  final _scrollController = ScrollController();
  Widget _buildHeaderss(
      String title, int index, String? Function(Data?)? valueFormatter) {
    // Build your header cells here
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          title,
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildInteractiveCells(String content, VoidCallback onTap) {
    return TableCell(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
              height: 40,
              child: Center(
                  child: Text(
                content,
                style: const TextStyle(fontSize: 18, color: Colors.black),
              ))),
        ),
      ),
    );
  }

  String formatDate3(String date) {
    // Format your date here
    return date;
  }

  //for pdf xlsx and csv
  Future<void> generateWorkOrderPdf(List<Data> ledgerdata) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;
    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      // Handle error
      logError("Error fetching profile data: $e");
      return;
    }
    final pdf = pw.Document();
    final image = pw.MemoryImage(
      (await rootBundle.load('assets/images/applogo.png')).buffer.asUint8List(),
    );
    final currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 50, height: 50),
                // pw.SizedBox(width: 50),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Tenant Statement',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(children: [
                      pw.Text(
                        '${widget.rentalAddress}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      if (widget.rentalUnit != null)
                        pw.Text(
                          ' - ${widget.rentalUnit}',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ]),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      profileData?.companyName?.isNotEmpty == true
                          ? profileData!.companyName!
                          : 'N/A',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      profileData?.companyAddress?.isNotEmpty == true
                          ? profileData!.companyAddress!
                          : 'N/A',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${profileData?.companyCity?.isNotEmpty == true ? profileData!.companyCity! : 'N/A'}, '
                      '${profileData?.companyState?.isNotEmpty == true ? profileData!.companyState! : 'N/A'}, '
                      '${profileData?.companyCountry?.isNotEmpty == true ? profileData!.companyCountry! : 'N/A'}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      profileData?.companyPostalCode?.isNotEmpty == true
                          ? profileData!.companyPostalCode!
                          : 'N/A',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 15),
          ],
        ),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey),
            ),
          );
        },
        build: (pw.Context context) => [
          // pw.SizedBox(height: 15),
          pw.Table.fromTextArray(
            headers: [
              'Date',
              'Tenants',
              'Type',
              'Description',
              'Amount',
              'Balance'
            ],
            data: ledgerdata.reversed.map((ledger) {
              return [
                formatDate4('${ledger.entry?.first.date}') ?? "",
                ledger.tenantData != null
                    ? '${ledger.tenantData["tenant_firstName"] ?? ""} ${ledger.tenantData["tenant_lastName"] ?? ""}'
                    : 'N/A' ?? '',
                ledger.type ?? '',
                ledger.type == 'Charge'
                    ? ' ${ledger.entry?.first.memo}'
                    : 'Manual ${ledger.type} ${ledger.response} For ${ledger.paymenttype}' ??
                        '',
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    formatMoneyAccountingCredit(ledger.totalAmount ?? 0,
                        isCredit: !(ledger.type == "Refund" ||
                            ledger.type == "Charge")),
                  ),
                ),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(formatMoneyAccounting(ledger.balance)),
                ),
              ];
            }).toList(),
            border: pw.TableBorder.all(
              color: PdfColors.black,
              width: 1,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex("#5A86D5"),
              //color:PdfColor.fromRYB(90, 134, 213,)
            ),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
                color: PdfColors.white),
            headerAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(
              fontSize: 10,
            ),
            cellHeight: 30,
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Date
              1: const pw.FlexColumnWidth(1.4), // tenants
              2: const pw.FlexColumnWidth(1.3), // type
              3: const pw.FlexColumnWidth(2.2), // transaction
              4: const pw.FlexColumnWidth(1.3), // increase
              5: const pw.FlexColumnWidth(1.3), // decrease
              6: const pw.FlexColumnWidth(1.3), // balance
            },
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            children: [
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Balance Due',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                    formatMoneyAccounting(ledgerdata.first.balance),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(color: PdfColors.black),
          pw.Divider(color: PdfColors.black),
        ],
      ),
    );

    if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Financial.pdf');
    } else {
      await Printing.layoutPdf(
      format: PdfPageFormat.a4.landscape,
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    }
  }

  Future<void> generateWorkOrderExcel(List<Data> ledgerdata) async {
    ledgerdata = ledgerdata.reversed.toList();
    final syncXlsx.Workbook workbook = syncXlsx.Workbook();
    final syncXlsx.Worksheet sheet = workbook.worksheets[0];
    sheet.getRangeByName('A1:f1').columnWidth = 15;
    sheet.getRangeByName('D1').columnWidth = 45;

    final List<String> headers = [
      'Date',
      'Tenants',
      'Type',
      'Description',
      'Amount',
      'Balance',
    ];

    final syncXlsx.Style headerCellStyle = workbook.styles.add(
      'headerCellStyle',
    );
    headerCellStyle.fontSize = 14;
    headerCellStyle.bold = true;
    headerCellStyle.backColor = '#D3D3D3';
    headerCellStyle.hAlign = syncXlsx.HAlignType.left;

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.getRangeByIndex(1, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle = headerCellStyle;
    }

    for (int i = 0; i < ledgerdata.reversed.length; i++) {
      final ledger = ledgerdata[i];

      // Safe date parsing with default/fallback value
      String formattedDate;
      try {
        formattedDate = ledger != null
            ? DateFormat('yyyy-MM-dd').format(
                DateFormat('yyyy-MM-dd').parse(ledger.entry?.first.date! ?? ''))
            : 'Invalid Date';
      } catch (e) {
        formattedDate = 'Invalid Date';
      }
      sheet.getRangeByIndex(2 + i, 5).cellStyle.hAlign =
          syncXlsx.HAlignType.right;
      sheet.getRangeByIndex(2 + i, 6).cellStyle.hAlign =
          syncXlsx.HAlignType.right;

      sheet.getRangeByIndex(2 + i, 1).setText(ledger.entry?.first.date);

      sheet.getRangeByIndex(2 + i, 2).setText(ledger.tenantData != null
          ? '${ledger.tenantData["tenant_firstName"] ?? ""} ${ledger.tenantData["tenant_lastName"] ?? ""}'
          : 'N/A' ?? '');

      sheet.getRangeByIndex(2 + i, 3).setText(ledger.type ?? '');

      sheet.getRangeByIndex(2 + i, 4).setText(ledger.type == "Charge"
          ? "${ledger.entry?.first.memo}"
          : 'Manual ${ledger.type} ${ledger.response} For ${ledger.paymenttype}' ??
              '');

      sheet.getRangeByIndex(2 + i, 5).setText(
            formatMoneyAccountingCredit(ledger.totalAmount ?? 0,
                isCredit:
                    !(ledger.type == "Refund" || ledger.type == "Charge")),
          );

      sheet
          .getRangeByIndex(2 + i, 6)
          .setText(formatMoneyAccounting(ledger.balance));
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Tenant_statement.xlsx';
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);

    Fluttertoast.showToast(
      msg: 'Excel file saved to $path',
    );
  }

  Future<void> generateWorkOrderCsv(
    List<Data> ledgerdata,
  ) async {
    ledgerdata = ledgerdata.reversed.toList();

    // No need for workbook and worksheet objects in CSV generation

    final List<String> headers = [
      'Date',
      'Tenants',
      'Type',
      'Description',
      'Amount',
      'Balance',
    ];

    final List<List<String>> csvData = [];
    csvData.add(headers);

    for (int i = 0; i < ledgerdata.reversed.length; i++) {
      final ledger = ledgerdata[i];
      // Safe date parsing with default/fallback value
      String formattedDate;
      try {
        formattedDate = ledger != null
            ? DateFormat('yyyy-MM-dd').format(
                DateFormat('yyyy-MM-dd').parse(ledger.entry?.first.date! ?? ''))
            : 'Invalid Date';
      } catch (e) {
        formattedDate = 'Invalid Date';
      }
      final rowData = [
        formattedDate,
        ledger.tenantData != null
            ? '${ledger.tenantData["tenant_firstName"] ?? ""} ${ledger.tenantData["tenant_lastName"] ?? ""}'
            : 'N/A',
        ledger.type ?? '',
        ledger.type == "Charge"
            ? "${ledger.entry?.first.memo}"
            : 'Manual ${ledger.type} ${ledger.response} For ${ledger.paymenttype}',
        formatMoneyAccountingCredit(ledger.totalAmount ?? 0,
            isCredit: !(ledger.type == "Refund" || ledger.type == "Charge")),
        formatMoneyAccounting(ledger.balance),
      ];
      csvData.add(rowData);
    }

    final String csvContent = const ListToCsvConverter().convert(csvData);
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
    final String fileName = 'Tenant_statement.csv';
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName';
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File file = File(path);
    await file.writeAsString(csvContent);

    Fluttertoast.showToast(
      msg: 'CSV file saved to $path',
    );
  }

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fromDateController;
  late TextEditingController _toDateController;
  String fdate = "";
  String edate = "";
  String _fromDateApiFormat = ""; // Store API format (yyyy-MM-dd)
  String _toDateApiFormat = ""; // Store API format (yyyy-MM-dd)

  Future<void> _selectfromDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDateApiFormat.isNotEmpty
          ? DateTime.parse(_fromDateApiFormat)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: blueColor, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Store API format (yyyy-MM-dd)
        _fromDateApiFormat = DateFormat('yyyy-MM-dd').format(picked);
        // Display in DateProvider format
        controller.text = dateProvider.formatCurrentDate(_fromDateApiFormat);
        fdate = controller.text;

      });
    }
  }

  Future<void> _selectendDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDateApiFormat.isNotEmpty
          ? DateTime.parse(_toDateApiFormat)
          : (_fromDateApiFormat.isNotEmpty
              ? DateTime.parse(_fromDateApiFormat)
              : DateTime.now()),
      firstDate: _fromDateApiFormat.isNotEmpty
          ? DateTime.parse(_fromDateApiFormat)
          : DateTime.now(),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: blueColor, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: blueColor, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: blueColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Store API format (yyyy-MM-dd)
        _toDateApiFormat = DateFormat('yyyy-MM-dd').format(picked);
        // Display in DateProvider format
        controller.text = dateProvider.formatCurrentDate(_toDateApiFormat);
        edate = picked.toString();

      });
    }
  }

  void sortData(List<Data> data) {
    if (sorting1) {
      data.sort((a, b) {
        String aDate = (a.entry != null &&
                a.entry!.isNotEmpty &&
                a.entry!.first.date != null)
            ? a.entry!.first.date!
            : '';
        String bDate = (b.entry != null &&
                b.entry!.isNotEmpty &&
                b.entry!.first.date != null)
            ? b.entry!.first.date!
            : '';
        return ascending1 ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
      });
    } else if (sorting2) {
      data.sort((a, b) =>
          ascending2 ? a.type!.compareTo(b.type!) : b.type!.compareTo(a.type!));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.balance!.compareTo(b.balance!)
          : b.balance!.compareTo(a.balance!));
    }
  }

  final List<String> downloadOptions = ['PDF', 'Excel', 'CSV'];
  String? selectedTransactionType = 'All';
  List<String> transactionTypeOptions = ['All', 'Payment', 'Charge'];

  bool _quickActionsExpanded = false;
  List<Data> _cachedLedgerData = [];

  static const double _financeQuickActionHeight = 42;
  // Matches the light border used by the Lease Summary cards and the
  // Lease Details / History tables (#DBE0E5). The old #D1D5DB read darker
  // and made the Financial cards mismatch the rest of the lease screens.
  static const Color _financeBorderGray = Color(0xFFDBE0E5);

  InputDecoration _financeSheetFieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: Icon(Icons.calendar_today, color: blueColor.withOpacity(0.75), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _financeBorderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: blueColor, width: 1.2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _financeBorderGray),
      ),
    );
  }

  void _showFiltersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (BuildContext context) {
        String? tempTransactionType = selectedTransactionType;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: blueColor),
                  ),
                  const SizedBox(height: 18),
                  Text('From Date', style: TextStyle(fontWeight: FontWeight.w600, color: blueColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _fromDateController,
                    readOnly: true,
                    onTap: () async {
                      await _selectfromDate(context, _fromDateController);
                      setSheetState(() {});
                    },
                    decoration: _financeSheetFieldDecoration(hint: 'dd-mm-yyyy'),
                  ),
                  const SizedBox(height: 12),
                  Text('To Date', style: TextStyle(fontWeight: FontWeight.w600, color: blueColor)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _toDateController,
                    readOnly: true,
                    onTap: () async {
                      await _selectendDate(context, _toDateController);
                      setSheetState(() {});
                    },
                    decoration: _financeSheetFieldDecoration(hint: 'dd-mm-yyyy'),
                  ),
                  const SizedBox(height: 12),
                  Text('Transaction Type', style: TextStyle(fontWeight: FontWeight.w600, color: blueColor)),
                  const SizedBox(height: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton2<String>(
                      value: tempTransactionType,
                      isExpanded: true,
                      hint: Text('All Types', style: TextStyle(fontSize: 14, color: blueColor)),
                      items: transactionTypeOptions.map((String item) {
                        return DropdownMenuItem<String>(
                          value: item,
                          child: Text(item, style: TextStyle(fontSize: 14, color: blueColor, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          tempTransactionType = value;
                        });
                      },
                      buttonStyleData: ButtonStyleData(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _financeBorderGray),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      dropdownStyleData: DropdownStyleData(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _financeBorderGray),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blueColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              setState(() {
                                selectedTransactionType = tempTransactionType;
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Show Results', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              side: BorderSide(color: blueColor),
                            ),
                            onPressed: () {
                              setState(() {
                                _fromDateController.clear();
                                _toDateController.clear();
                                _fromDateApiFormat = '';
                                _toDateApiFormat = '';
                                selectedTransactionType = 'All';
                              });
                              Navigator.pop(context);
                            },
                            child: Text('Clear', style: TextStyle(color: blueColor, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _quickEnterChargeCell(BuildContext context) {
    return Container(
      height: _financeQuickActionHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: blueColor, width: 1),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          minimumSize: Size.fromHeight(_financeQuickActionHeight),
        ),
        onPressed: () async {
          final value = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => enterCharge(leaseId: widget.leaseId)),
          );
          if (value == true) {
            setState(() {
              _leaseLedgerFuture = LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
            });
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money, size: 18, color: blueColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Enter Charge',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: blueColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickMakePaymentButton(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: blueColor,
        backgroundColor: Colors.white,
        side: BorderSide(color: blueColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      onPressed: () async {
        final value = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MakePayment(
              leaseId: widget.leaseId,
              tenantId: widget.tenantId,
            ),
          ),
        );
        if (value == true) {
          setState(() {
            _leaseLedgerFuture = LeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
          });
        }
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.payment, size: 16, color: blueColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Make Payment',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: blueColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This view lives inside another screen's tab, so it shows the
    // compact offline state rather than taking over the whole page.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    double screenWidth = MediaQuery.of(context).size.width;
    final dateProvider = Provider.of<DateProvider>(context);
    bool isFreePlan = Provider.of<checkPlanPurchaseProiver>(context)
            .checkplanpurchaseModel
            ?.data
            ?.planDetail
            ?.planName ==
        'Free Plan';
    final financeShowAddCards =
        !isFreePlan && (widget.status == 'Active' || widget.status == 'Future');
    final financeShowAch = _leaseAchAccepted && financeShowAddCards;
    return Container(
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildScheduledChargeBanner(),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _financeBorderGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: FutureBuilder<LeaseLedger?>(
                      future: _leaseLedgerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data?.totalBalance != null) {
                          final totalBalance = snapshot.data!.totalBalance!;
                          final isCredit = totalBalance < 0;
                          final absAmount = totalBalance.abs();
                          final formatted = NumberFormat.currency(
                            locale: 'en_US',
                            symbol: '\$',
                            decimalDigits: 2,
                          ).format(absAmount);
                          final displayText = isCredit
                              ? '($formatted) Credit'
                              : totalBalance > 0
                                  ? '$formatted Balance Due'
                                  : '\$0.00';
                          final badgeColor = isCredit
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFEBF5FF);
                          final textColor = isCredit ? const Color(0xFF065F46) : blueColor;
                          final borderColor = isCredit
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF8AAEE0);
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                'Balance: $displayText',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _financeBorderGray),
                            ),
                            child: TextField(
                              onChanged: (value) => setState(() {
                                searchvalue = value;
                                if (currentPage != 0) currentPage = 0;
                              }),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Search here...',
                                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                suffixIcon:
                                    Icon(Icons.search, color: blueColor.withOpacity(0.7), size: 22),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                onTap: () => _showFiltersBottomSheet(context),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  height: 48,
                                  width: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: _financeBorderGray),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.filter_alt, color: blueColor, size: 22),
                                ),
                              ),
                            ),
                            if (_fromDateApiFormat.isNotEmpty ||
                                _toDateApiFormat.isNotEmpty ||
                                (selectedTransactionType != null && selectedTransactionType != 'All'))
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration:
                                      const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  // Breathing room under the divider so Quick Actions no
                  // longer butts straight into the search/filter row above.
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(() => _quickActionsExpanded = !_quickActionsExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Quick Action Buttons',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: blueColor,
                            ),
                          ),
                          Icon(
                            _quickActionsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: blueColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_quickActionsExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: Column(
                        children: [
                          // Row 1: Export | Add Cards (Add Cards omitted when plan/status disallows)
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: _financeQuickActionHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: blueColor, width: 1),
                                  ),
                                  child: PopupMenuButton<String>(
                                    offset: const Offset(0, 50),
                                    tooltip: 'Export',
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          FaIcon(FontAwesomeIcons.download, size: 14, color: blueColor),
                                          const SizedBox(width: 6),
                                          Text('Export', style: TextStyle(fontSize: 14, color: blueColor, fontWeight: FontWeight.bold)),
                                          Icon(Icons.arrow_drop_down, color: blueColor),
                                        ],
                                      ),
                                    ),
                                    itemBuilder: (BuildContext context) {
                                      return downloadOptions.map((String option) {
                                        return PopupMenuItem<String>(
                                          value: option,
                                          onTap: () async {
                                            if (option == 'PDF') generateWorkOrderPdf(_cachedLedgerData);
                                            if (option == 'Excel') generateWorkOrderExcel(_cachedLedgerData);
                                            if (option == 'CSV') generateWorkOrderCsv(_cachedLedgerData);
                                          },
                                          child: Text('Download as $option', style: TextStyle(fontSize: 14, color: blueColor)),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                              ),
                              if (financeShowAddCards) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: _financeQuickActionHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: blueColor, width: 1),
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                        backgroundColor: Colors.transparent,
                                        minimumSize: Size.fromHeight(_financeQuickActionHeight),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => AddCard(leaseId: widget.leaseId)),
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.credit_card, size: 18, color: blueColor),
                                          const SizedBox(width: 6),
                                          Text('Add Cards', style: TextStyle(fontSize: 14, color: blueColor, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (financeShowAch) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: _financeQuickActionHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: blueColor, width: 1),
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                        backgroundColor: Colors.transparent,
                                        minimumSize: Size.fromHeight(_financeQuickActionHeight),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AddAchAccount(
                                              tenantId: widget.tenantId,
                                              leaseId: widget.leaseId,
                                              authAsStaff: true,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.account_balance, size: 18, color: blueColor),
                                          const SizedBox(width: 6),
                                          Text('Add ACH', style: TextStyle(fontSize: 14, color: blueColor, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: _quickEnterChargeCell(context)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: _financeQuickActionHeight,
                                    child: _quickMakePaymentButton(context),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: SizedBox(height: _financeQuickActionHeight)),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: _quickEnterChargeCell(context)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: _financeQuickActionHeight,
                                    child: _quickMakePaymentButton(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            if (MediaQuery.of(context).size.width > 500)
              const SizedBox(height: 25),
            if (MediaQuery.of(context).size.width < 500)
              Padding(
                padding: const EdgeInsets.only(
                    left: 10.0, right: 10.0, bottom: 10.0),
                child: FutureBuilder<LeaseLedger?>(
                  future: _leaseLedgerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ColabShimmerLoadingWidget();
                    } else if (snapshot.hasError) {
                      return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                    } else if (!snapshot.hasData) {
                      return const Center(child: Text('No data found'));
                    } else {
                      final leaseLedger = snapshot.data!;
                      var data = leaseLedger.data?.toList() ?? [];

                      for (int i = 0;
                          i < (data.length > 5 ? 5 : data.length);
                          i++) {
                        if (data[i].entry != null &&
                            data[i].entry!.isNotEmpty) {
                        }
                      }

                      if (searchvalue != null &&
                          searchvalue!.isNotEmpty &&
                          searchvalue != "All") {
                        String searchLower = searchvalue!.toLowerCase();
                        data = data.where((lease) {
                          // Check Type
                          bool typeMatch = (lease.type?.toLowerCase() ?? "")
                              .contains(searchLower);

                          // Check CreatedAt
                          bool dateMatch = (lease.createdAt?.toLowerCase() ?? "")
                              .contains(searchLower);

                          // Check Balance
                          bool balanceMatch =
                              (lease.balance?.toString() ?? "").contains(searchLower);

                          // Check Total Amount
                          bool amountMatch =
                              (lease.totalAmount?.toString() ?? "").contains(searchLower);

                          // Check Tenant Name
                          String tenantName = "";
                          if (lease.tenantData != null) {
                            tenantName =
                                "${lease.tenantData['tenant_firstName'] ?? ''} ${lease.tenantData['tenant_lastName'] ?? ''}"
                                    .toLowerCase();
                          }
                          bool tenantMatch = tenantName.contains(searchLower);

                          // Check Entry details (Memo, Amount, Account)
                          bool entryMatch = false;
                          if (lease.entry != null) {
                            for (var entry in lease.entry!) {
                              if ((entry.memo?.toLowerCase() ?? "")
                                      .contains(searchLower) ||
                                  (entry.amount?.toString() ?? "")
                                      .contains(searchLower) ||
                                  (entry.account?.toLowerCase() ?? "")
                                      .contains(searchLower)) {
                                entryMatch = true;
                                break;
                              }
                            }
                          }

                          return typeMatch ||
                              dateMatch ||
                              balanceMatch ||
                              amountMatch ||
                              tenantMatch ||
                              entryMatch;
                        }).toList();
                      }

                      // Filter by Transaction Type
                      if (selectedTransactionType != null &&
                          selectedTransactionType != "All") {
                        data = data.where((lease) {
                          return lease.type == selectedTransactionType;
                        }).toList();
                      }
                      // if (_fromDateController.text.isNotEmpty && _toDateController.text.isNotEmpty) {
                      //   try {
                      //     DateTime fromDate = DateTime.parse(_fromDateController.text);
                      //     DateTime toDate = DateTime.parse(_toDateController.text);
                      //     print("From Date: $fromDate");
                      //     print("To Date: $toDate");
                      //     data = data.where((lease) {
                      //       DateTime leaseDate = DateTime.parse(lease.entry!.first.date!);
                      //       print("Lease Date: $leaseDate");
                      //       return leaseDate.isAfter(fromDate) && leaseDate.isBefore(toDate.add(Duration(days: 1)));
                      //     }).toList();
                      //   } catch (e) {
                      //
                      //     print("Date parsing error: $e");
                      //   }
                      // }

                      // Handle date filtering - show all data from fromDate onwards (inclusive)
                      String? filterFromDate;
                      String? filterToDate;

                      if (_fromDateApiFormat.isNotEmpty &&
                          _toDateApiFormat.isNotEmpty) {
                        // Both dates selected - show all data from fromDate onwards (inclusive)
                        filterFromDate = _fromDateApiFormat;
                        filterToDate =
                            null; // No upper limit - show all future dates
                      } else if (_fromDateApiFormat.isNotEmpty) {
                        // Only from date selected - show all data from fromDate onwards
                        filterFromDate = _fromDateApiFormat;
                        filterToDate =
                            null; // No upper limit - show all future dates
                      } else if (_toDateApiFormat.isNotEmpty) {
                        // Only to date selected - show all data up to toDate (inclusive)
                        filterFromDate = '2000-01-01';
                        filterToDate = _toDateApiFormat;
                      }

                      if (filterFromDate != null) {
                        try {

                          // Parse API format dates (yyyy-MM-dd)
                          DateTime fromDate =
                              DateFormat('yyyy-MM-dd').parse(filterFromDate);
                          DateTime? toDate = filterToDate != null
                              ? DateFormat('yyyy-MM-dd').parse(filterToDate)
                              : null;

                          // Filter: show all records >= fromDate (inclusive)
                          // If toDate is set, also filter <= toDate (inclusive)
                          // Normalize dates to midnight for accurate date-only comparison
                          DateTime normalizedFromDate = DateTime(
                              fromDate.year, fromDate.month, fromDate.day);
                          DateTime? normalizedToDate = toDate != null
                              ? DateTime(toDate.year, toDate.month, toDate.day)
                              : null;

                          int includedCount = 0;
                          int excludedCount = 0;

                          data = data.where((lease) {
                            if (lease.entry == null ||
                                lease.entry!.isEmpty ||
                                lease.entry!.first.date == null) {
                              excludedCount++;
                              return false;
                            }
                            try {
                              DateTime leaseDateParsed =
                                  DateFormat('yyyy-MM-dd')
                                      .parse(lease.entry!.first.date!);
                              // Normalize lease date to midnight for comparison
                              DateTime leaseDate = DateTime(
                                  leaseDateParsed.year,
                                  leaseDateParsed.month,
                                  leaseDateParsed.day);

                              // Check if leaseDate is >= fromDate (inclusive)
                              bool isAfterOrEqualFromDate =
                                  leaseDate.isAfter(normalizedFromDate) ||
                                      leaseDate
                                          .isAtSameMomentAs(normalizedFromDate);

                              // If toDate is set, also check if leaseDate is <= toDate (inclusive)
                              bool shouldInclude;
                              if (normalizedToDate != null) {
                                bool isBeforeOrEqualToDate =
                                    leaseDate.isBefore(normalizedToDate) ||
                                        leaseDate
                                            .isAtSameMomentAs(normalizedToDate);
                                shouldInclude = isAfterOrEqualFromDate &&
                                    isBeforeOrEqualToDate;
                              } else {
                                // No upper limit - show all future dates
                                shouldInclude = isAfterOrEqualFromDate;
                              }

                              if (shouldInclude) {
                                includedCount++;
                              } else {
                                excludedCount++;
                              }

                              return shouldInclude;
                            } catch (e) {
                              excludedCount++;
                              logError(
                                  "  EXCLUDED: Date parsing error - $e, Type: ${lease.type}");
                              return false;
                            }
                          }).toList();

                        } catch (e) {
                          logError("Date parsing error: $e");
                        }
                      } else {
                      }

                      sortData(data);
                      _cachedLedgerData = data;

                      final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                      final currentPageData = data
                          .skip(currentPage * itemsPerPage)
                          .take(itemsPerPage)
                          .toList();

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            if (data.isNotEmpty) _buildHeaders(),
                            const SizedBox(height: 20),
                            Container(
                              // decoration: BoxDecoration(
                              //     border: Border.all(
                              //         color:
                              //             const Color.fromRGBO(152, 162, 179, .5))),
                              // decoration: BoxDecoration(
                              //   border: Border.all(color: blueColor),
                              // ),
                              child: Column(
                                children: currentPageData.isEmpty
                                    ? [_ledgerEmptyState(context)]
                                    : currentPageData
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  int index = entry.key;
                                  bool isExpanded = expandedIndex == index;
                                  Data data = entry.value;
                                  double? surcharge = data?.surcharge;
                                  double? totalAmount = data?.totalAmount;

                                  String percentage = (surcharge != null &&
                                          totalAmount != null &&
                                          totalAmount > 0)
                                      ? ((surcharge /
                                                      (totalAmount -
                                                          surcharge)) *
                                                  100)
                                              .toStringAsFixed(2) +
                                          "%"
                                      : "N/A";
                                  final uniqueEntries =
                                      data.entry?.toSet().toList() ?? [];
                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    decoration: BoxDecoration(
                                      color: index % 2 != 0
                                          ? const Color(0xFFF4F8FF)
                                          : Colors.white,
                                      border: Border.all(
                                          color: const Color(0xFFDBE0E5)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    // decoration: BoxDecoration(
                                    //   border: Border.all(color: blueColor),
                                    // ),
                                    child: Column(
                                      children: <Widget>[
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: <Widget>[
                                                InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      if (expandedIndex ==
                                                          index) {
                                                        expandedIndex = null;
                                                      } else {
                                                        expandedIndex = index;
                                                      }
                                                    });
                                                  },
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 5),
                                                    padding: !isExpanded
                                                        ? const EdgeInsets.only(
                                                            bottom: 10)
                                                        : const EdgeInsets.only(
                                                            top: 10),
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
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            5.0),
                                                    child: Text(
                                                      dateProvider.formatCurrentDate(data
                                                                      .entry !=
                                                                  null &&
                                                              data.entry!
                                                                  .isNotEmpty
                                                          ? '${data.entry!.first.date}'
                                                          : 'N/A'),
                                                      style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      .08,
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            8.0),
                                                    child: Text(
                                                      ' ${data.type}' ?? "",
                                                      textAlign: TextAlign.left,
                                                      style: TextStyle(
                                                        color: blueColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: MediaQuery.of(context)
                                                          .size
                                                          .width *
                                                      .08,
                                                ),
                                                Expanded(
                                                  child: Align(
                                                    alignment:
                                                        Alignment.centerRight,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Text(
                                                        formatMoneyAccounting(
                                                            data.balance),
                                                        style: TextStyle(
                                                          color: blueColor,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: MediaQuery.of(context)
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                            margin: EdgeInsets.only(
                                                bottom: (data.type != "Refund")
                                                    ? 2
                                                    : 20),
                                            child: SingleChildScrollView(
                                              child: Column(
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      FaIcon(
                                                        isExpanded
                                                            ? FontAwesomeIcons
                                                                .sortUp
                                                            : FontAwesomeIcons
                                                                .sortDown,
                                                        size: 30,
                                                        color:
                                                            Colors.transparent,
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
                                                                    text:
                                                                        'Description : ',
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        color:
                                                                            blueColor), // Bold and black
                                                                  ),
                                                                  if (data.type !=
                                                                      "Charge")
                                                                    TextSpan(
                                                                      text:
                                                                          'Manual ${data.type} ${data.response} For ${data.paymenttype}',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .w700,
                                                                          color:
                                                                              grey), // Light and grey
                                                                    ),
                                                                  if (data.type ==
                                                                      "Charge")
                                                                    TextSpan(
                                                                      text:
                                                                          '${data.entry?.first.memo}',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .w700,
                                                                          color:
                                                                              grey), // Light and grey
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 5,
                                                            ),
                                                            Text.rich(
                                                              TextSpan(
                                                                children: [
                                                                  TextSpan(
                                                                    text:
                                                                        'Amount : ',
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          blueColor,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text: formatMoneyAccountingCredit(
                                                                        data.totalAmount,
                                                                        isCredit: !(data.type == "Refund" ||
                                                                            data.type ==
                                                                                "Charge")),
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color:
                                                                          grey,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Text.rich(
                                                              TextSpan(
                                                                children: [
                                                                  TextSpan(
                                                                    text:
                                                                        'Tenant : ',
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          blueColor,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text: data.tenantData !=
                                                                            null
                                                                        ? '${data.tenantData["tenant_firstName"] ?? ""} ${data.tenantData["tenant_lastName"] ?? ""}'
                                                                        : 'N/A',
                                                                    style:
                                                                        TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                      color:
                                                                          grey,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (data.type == "Payment" ||
                                                      data.type == "Charge")
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 10.0,
                                                              top: 10),
                                                      child: Row(
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
                                                            size: 20,
                                                            color: Colors
                                                                .transparent,
                                                          ),
                                                          Expanded(
                                                            flex: 4,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: <Widget>[
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            'Account : ',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              blueColor,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 2,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: <Widget>[
                                                                Text.rich(
                                                                  TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text:
                                                                            '  Amount : ',
                                                                        style:
                                                                            TextStyle(
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              blueColor,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  const SizedBox(
                                                    height: 10,
                                                  ),
                                                  if (data.type == "Payment" ||
                                                      data.type == "Charge")
                                                    Column(
                                                      children: uniqueEntries
                                                          .map((entry) {
                                                        return Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  left: 10.0,
                                                                  bottom: 10),
                                                          child: Row(
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
                                                                size: 20,
                                                                color: Colors
                                                                    .transparent,
                                                              ),
                                                              Expanded(
                                                                flex: 4,
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: <Widget>[
                                                                    Text.rich(
                                                                      TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                '${entry.account ?? "N/A"}',
                                                                            style:
                                                                                TextStyle(
                                                                              fontWeight: FontWeight.w700,
                                                                              color: grey,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 15,
                                                              ),
                                                              Expanded(
                                                                flex: 2,
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: <Widget>[
                                                                    Text.rich(
                                                                      TextSpan(
                                                                        children: [
                                                                          TextSpan(
                                                                            text:
                                                                                ' ${formatMoney(entry.amount ?? "N/A")}',
                                                                            style:
                                                                                TextStyle(
                                                                              fontWeight: FontWeight.w700,
                                                                              color: grey,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    // Add additional fields if needed
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  /* if (data.paymenttype ==
                                                        "Card" &&  data.type == "Payment")
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 10.0),
                                                        child: Row(
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
                                                              size: 20,
                                                              color: Colors
                                                                  .transparent,
                                                            ),
                                                            Expanded(flex: 4,
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: <Widget>[
                                                                  Text.rich(
                                                                    TextSpan(
                                                                      children: [
                                                                        TextSpan(
                                                                          text:
                                                                              '$percentage Surcharge applied on card',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color:
                                                                                grey,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            SizedBox(width: 15,),
                                                            Expanded(
                                                              flex: 2,
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: <Widget>[
                                                                  Text.rich(
                                                                    TextSpan(
                                                                      children: [
                                                                        TextSpan(
                                                                          text:
                                                                              ' ${formatMoney(data.surcharge ?? "N/A")}',
                                                                          style:
                                                                              TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w700,
                                                                            color:
                                                                                grey,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  // Add additional fields if needed
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),*/
                                                  if (data.type != "Refund" &&
                                                      data.type != "Charge" &&
                                                      (data.paymenttype ==
                                                              "Card" ||
                                                          data.paymenttype ==
                                                              "ACH") &&
                                                      data.response ==
                                                          "SUCCESS" &&
                                                      data.state == "settled")
                                                    Row(
                                                      //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _amountController
                                                                  .text = (data
                                                                      .totalAmount!)
                                                                  .toString();
                                                              _dateController
                                                                      .text =
                                                                  formatDate(DateTime
                                                                          .now()
                                                                      .toString());
                                                            });
                                                            _showRefundDialog(
                                                                context, data);
                                                            // Navigator.of(context)
                                                            //     .push(MaterialPageRoute(builder: (context) => Workorder_summery(workorder_id: workorder.workOrderId,)));
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .blue
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .wallet,
                                                                  size: 15,
                                                                  color:
                                                                      blueColor,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Container(
                                                          //   height: 40,
                                                          //   decoration:
                                                          //       BoxDecoration(
                                                          //           color: Colors
                                                          //                   .grey[
                                                          //               350]),
                                                          //   child: Row(
                                                          //     mainAxisAlignment:
                                                          //         MainAxisAlignment
                                                          //             .center,
                                                          //     crossAxisAlignment:
                                                          //         CrossAxisAlignment
                                                          //             .center,
                                                          //     children: [
                                                          //       const SizedBox(
                                                          //         width: 5,
                                                          //       ),
                                                          //       const Icon(Icons
                                                          //           .wallet),
                                                          //       // FaIcon(
                                                          //       //   FontAwesomeIcons.trashCan,
                                                          //       //   size: 15,
                                                          //       //   color:blueColor,
                                                          //       // ),
                                                          //       const SizedBox(
                                                          //         width: 8,
                                                          //       ),
                                                          //       Text(
                                                          //         "Refund",
                                                          //         style: TextStyle(
                                                          //             fontSize:
                                                          //                 12,
                                                          //             color:
                                                          //                 blueColor,
                                                          //             fontWeight:
                                                          //                 FontWeight.bold),
                                                          //       )
                                                          //     ],
                                                          //   ),
                                                          // ),
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final value = await Navigator
                                                                .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                        builder: (context) =>
                                                                            EditMakePayment(
                                                                              leaseId: widget.leaseId,
                                                                              tenantId: data.tenantData["tenant_id"],
                                                                              isEdit: true,
                                                                              data: data,
                                                                            )));
                                                            if (value == true) {
                                                              setState(() {
                                                                _leaseLedgerFuture =
                                                                    LeaseRepository().fetchLeaseLedger(
                                                                        leaseId:
                                                                            widget.leaseId);
                                                              });
                                                            }
                                                            // var check = await Navigator.push(
                                                            //   context,
                                                            //   MaterialPageRoute(
                                                            //     builder: (context) => Edit_properties(
                                                            //       properties: rentals,
                                                            //       rentalId: rentals.rentalId!,
                                                            //     ),
                                                            //   ),
                                                            // );
                                                            // if (check == true) {
                                                            //   setState(() {
                                                            //     futureRentalOwners = PropertiesRepository().fetchProperties();
                                                            //
                                                            //   });
                                                            //   // Update State
                                                            // }
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .green
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 15,
                                                        ),
                                                      ],
                                                    ),
                                                  if (data.type != "Refund" &&
                                                      data.type != "Charge" &&
                                                      (data.paymenttype ==
                                                              "Card" ||
                                                          data.paymenttype ==
                                                              "ACH") &&
                                                      data.response ==
                                                          "SUCCESS" &&
                                                      data.state == "settled")
                                                    SizedBox(
                                                      height: 14,
                                                    ),
                                                  if (data.type == "Charge")
                                                    Row(
                                                      //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final value = await Navigator
                                                                .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                        builder: (context) =>
                                                                            enterCharge(
                                                                              leaseId: widget.leaseId,
                                                                              chargeid: data.chargeId,
                                                                            )));
                                                            if (value == true) {
                                                              setState(() {
                                                                _leaseLedgerFuture =
                                                                    LeaseRepository().fetchLeaseLedger(
                                                                        leaseId:
                                                                            widget.leaseId);
                                                              });
                                                            }
                                                            // var check = await Navigator.push(
                                                            //   context,
                                                            //   MaterialPageRoute(
                                                            //     builder: (context) => Edit_properties(
                                                            //       properties: rentals,
                                                            //       rentalId: rentals.rentalId!,
                                                            //     ),
                                                            //   ),
                                                            // );
                                                            // if (check == true) {
                                                            //   setState(() {
                                                            //     futureRentalOwners = PropertiesRepository().fetchProperties();
                                                            //
                                                            //   });
                                                            //   // Update State
                                                            // }
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .green
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () {
                                                            _showAlert(context,
                                                                data.chargeId!);
                                                            //   _showAlert(context, rentals.rentalId!);
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .red
                                                                    .shade50),
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .trashCan,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 15,
                                                        ),
                                                      ],
                                                    ),
                                                  if (data.type == "Charge")
                                                    SizedBox(
                                                      height: 14,
                                                    ),
                                                  if (data.type == "Payment" &&
                                                      data.response ==
                                                          "PENDING")
                                                    Row(
                                                      //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final value = await Navigator
                                                                .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                        builder: (context) =>
                                                                            EditMakePayment(
                                                                              leaseId: widget.leaseId,
                                                                              tenantId: data.tenantData["tenant_id"],
                                                                              isEdit: true,
                                                                              data: data,
                                                                            )));
                                                            if (value == true) {
                                                              setState(() {
                                                                _leaseLedgerFuture =
                                                                    LeaseRepository().fetchLeaseLedger(
                                                                        leaseId:
                                                                            widget.leaseId);
                                                              });
                                                            }
                                                            // var check = await Navigator.push(
                                                            //   context,
                                                            //   MaterialPageRoute(
                                                            //     builder: (context) => Edit_properties(
                                                            //       properties: rentals,
                                                            //       rentalId: rentals.rentalId!,
                                                            //     ),
                                                            //   ),
                                                            // );
                                                            // if (check == true) {
                                                            //   setState(() {
                                                            //     futureRentalOwners = PropertiesRepository().fetchProperties();
                                                            //
                                                            //   });
                                                            //   // Update State
                                                            // }
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .green
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () {
                                                            _showAlertpayment(
                                                                context,
                                                                data.paymentId!);
                                                            //   _showAlert(context, rentals.rentalId!);
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .red
                                                                    .shade50),
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .trashCan,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 15,
                                                        ),
                                                      ],
                                                    ),
                                                  if (data.type == "Payment" &&
                                                      data.response ==
                                                          "PENDING")
                                                    SizedBox(
                                                      height: 14,
                                                    ),
                                                  if (data.type == "Payment" &&
                                                      data.response ==
                                                          "SUCCESS" &&
                                                      data.state == "settling")
                                                    Row(
                                                      //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () {
                                                            _showAlertvoid(
                                                                context,
                                                                data.paymentId!);
                                                            //   _showAlert(context, rentals.rentalId!);
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .blue
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                // FaIcon(
                                                                //   FontAwesomeIcons
                                                                //       .edit,
                                                                //   size: 15,
                                                                //   color: Colors
                                                                //       .green,
                                                                // ),
                                                                Icon(
                                                                  Icons
                                                                      .money_off,
                                                                  size: 20,
                                                                  color:
                                                                      blueColor,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Container(
                                                          //   height: 40,
                                                          //   decoration:
                                                          //       BoxDecoration(
                                                          //           color: Colors
                                                          //                   .grey[
                                                          //               350]),
                                                          //   child: Row(
                                                          //     mainAxisAlignment:
                                                          //         MainAxisAlignment
                                                          //             .center,
                                                          //     crossAxisAlignment:
                                                          //         CrossAxisAlignment
                                                          //             .center,
                                                          //     children: [
                                                          //       Icon(
                                                          //         Icons
                                                          //             .money_off,
                                                          //         size: 20,
                                                          //         color:
                                                          //             blueColor,
                                                          //       ),
                                                          //       const SizedBox(
                                                          //         width: 10,
                                                          //       ),
                                                          //       Text(
                                                          //         "Void",
                                                          //         style: TextStyle(
                                                          //             color:
                                                          //                 blueColor,
                                                          //             fontWeight:
                                                          //                 FontWeight
                                                          //                     .bold),
                                                          //       )
                                                          //     ],
                                                          //   ),
                                                          // ),
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final value = await Navigator
                                                                .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                        builder: (context) =>
                                                                            EditMakePayment(
                                                                              leaseId: widget.leaseId,
                                                                              tenantId: data.tenantData["tenant_id"],
                                                                              isEdit: true,
                                                                              data: data,
                                                                            )));
                                                            if (value == true) {
                                                              setState(() {
                                                                _leaseLedgerFuture =
                                                                    LeaseRepository().fetchLeaseLedger(
                                                                        leaseId:
                                                                            widget.leaseId);
                                                              });
                                                            }
                                                            // var check = await Navigator.push(
                                                            //   context,
                                                            //   MaterialPageRoute(
                                                            //     builder: (context) => Edit_properties(
                                                            //       properties: rentals,
                                                            //       rentalId: rentals.rentalId!,
                                                            //     ),
                                                            //   ),
                                                            // );
                                                            // if (check == true) {
                                                            //   setState(() {
                                                            //     futureRentalOwners = PropertiesRepository().fetchProperties();
                                                            //
                                                            //   });
                                                            //   // Update State
                                                            // }
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .green
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 15,
                                                        ),
                                                      ],
                                                    ),
                                                  if (data.type == "Payment" &&
                                                      data.response ==
                                                          "SUCCESS" &&
                                                      data.state == "settling")
                                                    SizedBox(
                                                      height: 14,
                                                    ),
                                                  if (data.type == "Payment" &&
                                                      data.paymenttype !=
                                                          "Card" &&
                                                      data.paymenttype != "ACH")
                                                    Row(
                                                      //mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final value = await Navigator
                                                                .push(
                                                                    context,
                                                                    MaterialPageRoute(
                                                                        builder: (context) =>
                                                                            EditMakePayment(
                                                                              leaseId: widget.leaseId,
                                                                              tenantId: data.tenantData["tenant_id"],
                                                                              isEdit: true,
                                                                              data: data,
                                                                            )));
                                                            if (value == true) {
                                                              setState(() {
                                                                _leaseLedgerFuture =
                                                                    LeaseRepository().fetchLeaseLedger(
                                                                        leaseId:
                                                                            widget.leaseId);
                                                              });
                                                            }
                                                            // var check = await Navigator.push(
                                                            //   context,
                                                            //   MaterialPageRoute(
                                                            //     builder: (context) => Edit_properties(
                                                            //       properties: rentals,
                                                            //       rentalId: rentals.rentalId!,
                                                            //     ),
                                                            //   ),
                                                            // );
                                                            // if (check == true) {
                                                            //   setState(() {
                                                            //     futureRentalOwners = PropertiesRepository().fetchProperties();
                                                            //
                                                            //   });
                                                            //   // Update State
                                                            // }
                                                          },
                                                          child: Container(
                                                            height: 35,
                                                            width: 35,
                                                            decoration: BoxDecoration(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                                color: Colors
                                                                    .green
                                                                    .shade50), // color:Colors.grey[100],
                                                            child: const Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .center,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                FaIcon(
                                                                  FontAwesomeIcons
                                                                      .edit,
                                                                  size: 15,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 15,
                                                        ),
                                                      ],
                                                    ),
                                                  if (data.type == "Payment" &&
                                                      data.paymenttype !=
                                                          "Card" &&
                                                      data.paymenttype != "ACH")
                                                    SizedBox(
                                                      height: 14,
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),


                            const SizedBox(height: 20),
                            if (data.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      // Text('Rows per page:'),
                                      const SizedBox(width: 10),
                                      Material(
                                        elevation: 3,
                                        child: Container(
                                          height: 40,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12.0),
                                          decoration: BoxDecoration(
                                            border:
                                                Border.all(color: Colors.grey),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: itemsPerPage,
                                              items: itemsPerPageOptions
                                                  .map((int value) {
                                                return DropdownMenuItem<int>(
                                                  value: value,
                                                  child: Text(value.toString()),
                                                );
                                              }).toList(),
                                              onChanged: data.length >
                                                      itemsPerPageOptions
                                                          .first // Condition to check if dropdown should be enabled
                                                  ? (newValue) {
                                                      setState(() {
                                                        itemsPerPage =
                                                            newValue!;
                                                        currentPage =
                                                            0; // Reset to first page when items per page change
                                                      });
                                                    }
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: FaIcon(
                                          FontAwesomeIcons.circleChevronLeft,
                                          color: currentPage == 0
                                              ? Colors.grey
                                              : blueColor,
                                        ),
                                        onPressed: currentPage == 0
                                            ? null
                                            : () {
                                                setState(() {
                                                  currentPage--;
                                                });
                                              },
                                      ),
                                      // IconButton(
                                      //   icon: Icon(Icons.arrow_back),
                                      //   onPressed: currentPage > 0
                                      //       ? () {
                                      //     setState(() {
                                      //       currentPage--;
                                      //     });
                                      //   }
                                      //       : null,
                                      // ),
                                      Text(
                                          'Page ${currentPage + 1} of $totalPages'),
                                      // IconButton(
                                      //   icon: Icon(Icons.arrow_forward),
                                      //   onPressed: currentPage < totalPages - 1
                                      //       ? () {
                                      //     setState(() {
                                      //       currentPage++;
                                      //     });
                                      //   }
                                      //       : null,
                                      // ),
                                      IconButton(
                                        icon: FaIcon(
                                          FontAwesomeIcons.circleChevronRight,
                                          color: currentPage < totalPages - 1
                                              ? blueColor
                                              : Colors.grey,
                                        ),
                                        onPressed: currentPage < totalPages - 1
                                            ? () {
                                                setState(() {
                                                  currentPage++;
                                                });
                                              }
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            if (MediaQuery.of(context).size.width > 500)
              FutureBuilder<LeaseLedger?>(
                future: _leaseLedgerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SpinKitSpinningLines(
                        color: Colors.black,
                        size: 55.0,
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                  } else if (!snapshot.hasData) {
                    return const Center(child: Text('No data available'));
                  } else {
                    _tableData = snapshot.data?.data ?? [];
                    totalrecords = _tableData.length;

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          Container(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 5),
                              child: Column(
                                children: [
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Container(
                                      child: Table(
                                        defaultColumnWidth:
                                            const IntrinsicColumnWidth(),
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                  // color: blueColor
                                                  ),
                                            ),
                                            children: [
                                              _buildHeader(
                                                  'Type',
                                                  0,
                                                  (property) => property!
                                                      .totalAmount
                                                      .toString()),
                                              _buildHeader(
                                                  'Tenant',
                                                  1,
                                                  (property) => property!
                                                      .totalAmount
                                                      .toString()),
                                              _buildHeader(
                                                  'Description', 2, null),
                                              _buildHeader('Increase', 3, null),
                                              _buildHeader('Decrease', 3, null),
                                              _buildHeader('Balance', 4, null),
                                              _buildHeader('Date', 4, null),
                                            ],
                                          ),
                                          TableRow(
                                            decoration: const BoxDecoration(
                                              border: Border.symmetric(
                                                  horizontal: BorderSide.none),
                                            ),
                                            children: List.generate(
                                                7,
                                                (index) => TableCell(
                                                    child:
                                                        Container(height: 20))),
                                          ),
                                          for (var i = 0;
                                              i < _pagedData.length;
                                              i++)
                                            TableRow(
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  left: BorderSide(
                                                      color: blueColor),
                                                  right: BorderSide(
                                                      color: blueColor),
                                                  top: BorderSide(
                                                      color: blueColor),
                                                  bottom: i ==
                                                          _pagedData.length - 1
                                                      ? const BorderSide(
                                                          color: Color.fromRGBO(
                                                              21, 43, 81, 1))
                                                      : BorderSide.none,
                                                ),
                                              ),
                                              children: [
                                                _buildDataCell(_pagedData[i]!
                                                    .type
                                                    .toString()),
                                                _buildDataCell(
                                                    '${_pagedData[i]!.tenantData["tenant_firstName"].toString()} ${_pagedData[i]!.tenantData["tenant_lastName"].toString()}'),
                                                _buildDataCell(
                                                    'Manual ${_pagedData[i]!.type.toString()} ${_pagedData[i]!.response} for ${_pagedData[i]!.paymenttype} (#${_pagedData[i]!.transactionid})'),
                                                _buildDataCell(
                                                  _pagedData[i]!.type ==
                                                              "Refund" &&
                                                          _pagedData[i]!.type ==
                                                              "Charge"
                                                      ? _pagedData[i]!
                                                          .totalAmount
                                                          .toString()
                                                      : 'N/A',
                                                ),
                                                _buildDataCell(
                                                  _pagedData[i]!.type !=
                                                              "Refund" &&
                                                          _pagedData[i]!.type !=
                                                              "Charge"
                                                      ? _pagedData[i]!
                                                          .totalAmount
                                                          .toString()
                                                      : 'N/A',
                                                ),
                                                _buildDataCell(
                                                  _pagedData[i]!
                                                      .balance!
                                                      .abs()
                                                      .toStringAsFixed(2),
                                                ),
                                                _buildDataCell(
                                                  formatDate3(_pagedData[i]!
                                                      .createdAt
                                                      .toString()),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 25),
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
            if (MediaQuery.of(context).size.width > 500)
              FutureBuilder<LeaseLedger?>(
                future: _leaseLedgerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ColabShimmerLoadingWidget();
                  } else if (snapshot.hasError) {
                    return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                  } else if (!snapshot.hasData ||
                      (snapshot.data?.data?.isEmpty ?? true)) {
                    return const Center(child: Text('No data available'));
                  } else {
                    _tableData = snapshot.data?.data ?? [];
                    totalrecords = _tableData.length;
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 5),
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Table(
                                defaultColumnWidth:
                                    const IntrinsicColumnWidth(),
                                //border: TableBorder.all(),
                                children: [
                                  // Header Row
                                  TableRow(
                                    decoration:
                                        BoxDecoration(border: Border.all()),
                                    children: List.generate(7, (index) {
                                      switch (index) {
                                        case 0:
                                          return _buildHeader(
                                              'Type',
                                              0,
                                              (property) => property!
                                                  .totalAmount
                                                  .toString());
                                        case 1:
                                          return _buildHeader(
                                              'Tenant',
                                              1,
                                              (property) => property!
                                                  .totalAmount
                                                  .toString());
                                        case 2:
                                          return _buildHeader(
                                              'Description', 2, null);
                                        case 3:
                                          return _buildHeader(
                                              'Increase', 3, null);
                                        case 4:
                                          return _buildHeader(
                                              'Decrease', 4, null);
                                        case 5:
                                          return _buildHeader(
                                              'Balance', 5, null);
                                        case 6:
                                          return _buildHeader('Date', 6, null);
                                        default:
                                          return Container();
                                      }
                                    }),
                                  ),
                                  // Empty Row for spacing
                                  TableRow(
                                    decoration: const BoxDecoration(
                                        border: Border.symmetric(
                                            horizontal: BorderSide.none)),
                                    children: List.generate(
                                        7,
                                        (index) => TableCell(
                                            child: Container(height: 20))),
                                  ),
                                  // Data Rows
                                  for (var i = 0;
                                      i < _pagedData.length;
                                      i++) ...[
                                    TableRow(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(color: blueColor),
                                          right: BorderSide(color: blueColor),
                                          top: BorderSide(color: blueColor),
                                          bottom: i == _pagedData.length - 1
                                              ? BorderSide(color: blueColor)
                                              : BorderSide.none,
                                        ),
                                      ),
                                      children: List.generate(7, (index) {
                                        switch (index) {
                                          case 0:
                                            return _buildInteractiveCells(
                                                _pagedData[i]!.type.toString(),
                                                () => _toggleExpansion(i));
                                          case 1:
                                            return _buildInteractiveCells(
                                              '${_pagedData[i]!.tenantData["tenant_firstName"]} ${_pagedData[i]!.tenantData["tenant_lastName"]}',
                                              () => _toggleExpansion(i),
                                            );
                                          case 2:
                                            return _buildInteractiveCells(
                                              'Manual ${_pagedData[i]!.type.toString()} ${_pagedData[i]!.response} for ${_pagedData[i]!.paymenttype} (#${_pagedData[i]!.transactionid})',
                                              () => _toggleExpansion(i),
                                            );
                                          case 3:
                                            return _buildInteractiveCells(
                                              (_pagedData[i]!.type ==
                                                          "Refund" ||
                                                      _pagedData[i]!.type ==
                                                          "Charge")
                                                  ? _pagedData[i]!
                                                      .totalAmount
                                                      .toString()
                                                  : 'N/A',
                                              () => _toggleExpansion(i),
                                            );
                                          case 4:
                                            return _buildInteractiveCells(
                                              (_pagedData[i]!.type !=
                                                          "Refund" &&
                                                      _pagedData[i]!.type !=
                                                          "Charge")
                                                  ? _pagedData[i]!
                                                      .totalAmount
                                                      .toString()
                                                  : 'N/A',
                                              () => _toggleExpansion(i),
                                            );
                                          case 5:
                                            return _buildInteractiveCells(
                                              _pagedData[i]!
                                                  .balance!
                                                  .abs()
                                                  .toStringAsFixed(2),
                                              () => _toggleExpansion(i),
                                            );
                                          case 6:
                                            return _buildInteractiveCells(
                                              formatDate3(_pagedData[i]!
                                                  .createdAt
                                                  .toString()),
                                              () => _toggleExpansion(i),
                                            );
                                          default:
                                            return Container();
                                        }
                                      }),
                                    ),
                                    // Expanded Row (if any)
                                    if (_expandedIndex != null &&
                                        _expandedIndex == i)
                                      TableRow(
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: blueColor,
                                              width: 1.0,
                                            ),
                                            bottom: (i == _pagedData.length - 1)
                                                ? BorderSide(
                                                    color: blueColor,
                                                    width: 1.0,
                                                  )
                                                : BorderSide.none,
                                          ),
                                        ),
                                        children: List.generate(7, (index) {
                                          if (index == 1) {
                                            return TableCell(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Container(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .start,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text('Account',
                                                                    style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize:
                                                                            16,
                                                                        color:
                                                                            blueColor)),
                                                                ...?_pagedData[
                                                                            _expandedIndex!]!
                                                                        .entry
                                                                        ?.map((entry) =>
                                                                            Row(
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Text('${entry.account ?? "N/A"}', style: TextStyle(fontWeight: FontWeight.bold, color: grey, fontSize: 16)),
                                                                                ),
                                                                              ],
                                                                            ))
                                                                        .toList() ??
                                                                    [],
                                                                // Add more details as needed
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Container(
                                                            child: Column(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .start,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              30),
                                                                  child: Text(
                                                                      'Amount',
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          color:
                                                                              blueColor)),
                                                                ),
                                                                ...?_pagedData[
                                                                            _expandedIndex!]!
                                                                        .entry
                                                                        ?.map((entry) =>
                                                                            Row(
                                                                              children: [
                                                                                Expanded(
                                                                                  child: Padding(
                                                                                    padding: const EdgeInsets.only(left: 5),
                                                                                    child: Center(
                                                                                      child: Text('${entry.amount ?? "N/A"}',
                                                                                          style: TextStyle(
                                                                                            fontWeight: FontWeight.bold,
                                                                                            color: grey,
                                                                                            fontSize: 15,
                                                                                          )),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ))
                                                                        .toList() ??
                                                                    [],
                                                                // Add more details as needed
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          } else {
                                            return TableCell(
                                                child:
                                                    Container()); // Empty cells for alignment
                                          }
                                        }),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              ),
            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCell(String text, VoidCallback onTap) {
    return TableCell(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(text),
        ),
      ),
    );
  }
}
