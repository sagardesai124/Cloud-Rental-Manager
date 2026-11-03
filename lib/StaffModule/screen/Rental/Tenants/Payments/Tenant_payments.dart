import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:three_zero_two_property/StaffModule/repository/GetAdminAddressPdf.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/propertytype.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/Property_type.dart';

import 'package:three_zero_two_property/screens/Leasing/Applicants/editApplicant.dart';
import 'package:three_zero_two_property/widgets/CustomDateField.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import 'package:three_zero_two_property/Model/profile.dart';
import 'package:printing/printing.dart';
import 'package:three_zero_two_property/screens/Property_Type/Edit_property_type.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;

import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';

import '../../../../../Model/LeaseLedgerModel.dart';
import '../../../../../provider/dateProvider.dart';
import '../../../../repository/tenantDetail_payment/tenant_payment_repo.dart';
import 'package:three_zero_two_property/services/app_date_format.dart';

class FinancialTable extends StatefulWidget {
  final String leaseId;

  FinancialTable({
    required this.leaseId,
  });
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

  int? expandedIndex;
  Set<int> expandedIndices = {};
  late bool isExpanded;
  bool sorting1 = false;
  bool sorting2 = false;
  bool sorting3 = false;
  bool ascending1 = false;
  bool ascending2 = false;
  bool ascending3 = false;
  TextEditingController _dateController = TextEditingController();
  TextEditingController _amountController = TextEditingController();
  TextEditingController _memoController = TextEditingController();

  _showRefundDialog(BuildContext context, Data data) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isLoading = false; // Flag to show loading indicator

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Refund Amount'),
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
                            BoxShadow(
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
                    SizedBox(height: 10),
                    Text("Date"),
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
                              AppDateFormat.format(pickedDate);
                          _dateController.text = formattedDate;
                        }
                      },
                      controller: _dateController,
                      hintText: 'Enter refund Date',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    Text("Refund Amount"),
                    buildCustomTextField(
                      controller: _amountController,
                      hintText: 'Enter refund amount',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 10),
                    Text("Memo"),
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
                    GestureDetector(
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
                          style: AlertStyle(
                            backgroundColor: Colors.white,
                            //  overlayColor: Colors.black.withOpacity(.8)
                          ),
                          buttons: [
                            DialogButton(
                              child: Text(
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
                                ? CircularProgressIndicator(
                                    color: Colors.white,
                                  ) // Show loading indicator when isLoading is true
                                : Text(
                                    'Make Refund',
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.white),
                                  )),
                      ),
                    ),
                    GestureDetector(
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
                        child: Center(child: Text('Cancel')),
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
      String? token = prefs.getString('token');
      // Perform the POST request
      final response = await apiPost(
        Uri.parse(apiUrl),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM ${prefs.getString('staff_id') ?? id}",
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
    }
  }

  reload_screen() {
    setState(() {
      _leaseLedgerFuture =
          TenantLeaseRepository().fetchLeaseLedger(leaseId: widget.leaseId);
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
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: Offset(4, 4),
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
            hintStyle: TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
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

  Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Container(
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
                        ? Text("Type",
                            style: TextStyle(
                                color: blueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15))
                        : Text("Type",
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
                    Text(
                        "    Amount",
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
                  children: [
                    Text("    Date",
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
    ));
  }

  final List<String> items = ['Residential', "Commercial", "All"];
  String? selectedValue;
  String searchvalue = "";
  late Future<LeaseLedger?> _leaseLedgerFuture;
  List<bool> _expanded = [];
  /// Required by [NetworkRetryState]: re-issue this view's own load.
  /// The data calls `initState` makes; controllers and defaults are not
  /// repeated, so a reload keeps what the user was looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _leaseLedgerFuture = TenantLeaseRepository().fetchLeaseLedger( leaseId: widget.leaseId, );
    });
  }

  @override
  void initState() {
    super.initState();
    _leaseLedgerFuture = TenantLeaseRepository().fetchLeaseLedger(
      leaseId: widget.leaseId,
    );
    _expanded = List.generate(_pagedData.length, (_) => false);
    _fromDateController = TextEditingController(text: '');
    _toDateController = TextEditingController(text: '');
    filteredData = allData;
  }

  @override
  void dispose() {
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  void handleEdit(Data? ledge) async {}

  List<Data?> _tableData = [];
  int _rowsPerPage = 10;

  String fdate = "";
  String edate = "";
  int _currentPage = 0;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  List<Data?> get _pagedData {
    int startIndex = _currentPage * _rowsPerPage;
    int endIndex = startIndex + _rowsPerPage;
    return _tableData.sublist(startIndex,
        endIndex > _tableData.length ? _tableData.length : endIndex);
  }

  /// Total amount from current table data (for header display).
  double get _totalAmount =>
      _tableData.fold(0.0, (sum, d) => sum + (d?.totalAmount ?? 0));

  String _formatAmountHeader(double amount) {
    if (amount < 0) return '(${formatMoney(amount.abs())})';
    return formatMoney(amount);
  }

  void sortData(List<Data> data) {
    if (sorting1) {
      data.sort((a, b) =>
          ascending1 ? a.type!.compareTo(b.type!) : b.type!.compareTo(a.type!));
    } else if (sorting2) {
      data.sort((a, b) => ascending2
          ? (a.totalAmount ?? 0).compareTo(b.totalAmount ?? 0)
          : (b.totalAmount ?? 0).compareTo(a.totalAmount ?? 0));
    } else if (sorting3) {
      data.sort((a, b) => ascending3
          ? a.createdAt!.compareTo(b.createdAt!)
          : b.createdAt!.compareTo(a.createdAt!));
    }
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
    //  _showAlert(context, ledge!.leaseId!);
    // Handle delete action
    // print('Delete ${property.sId}');
  }

  Widget _buildHeader<T>(
      String text, int columnIndex, Comparable<T> Function(Data? d)? getField) {
    return TableCell(
      child: GestureDetector(
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

  /// Amount column header with total from backend.
  Widget _buildAmountHeader() {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Amount',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Total: ${_formatAmountHeader(_totalAmount)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
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
              GestureDetector(
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
              GestureDetector(
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
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }

  Widget _buildInteractiveCells(String content, VoidCallback onTap) {
    return TableCell(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
              height: 40,
              child: Center(
                  child: Text(
                content,
                style: TextStyle(fontSize: 18, color: Colors.black),
              ))),
        ),
      ),
    );
  }

  final List<String> downloadOptions = ['PDF', 'Excel', 'CSV'];
  String formatDate3(String date) {
    // Format your date here
    return date;
  }

  /// Format amount for table: negative values shown in parentheses.
  String _formatAmountForTable(double? amount) {
    if (amount == null) return '0.00';
    if (amount < 0) return '(${amount.abs().toStringAsFixed(2)})';
    return amount.toStringAsFixed(2);
  }

  //for pdf xlsx and csv
  Future<void> generateWorkOrderPdf(List<Data> ledgerdata) async {
    final GetAddressAdminPdfService service = GetAddressAdminPdfService();
    profile? profileData;
    try {
      profileData = await service.fetchAdminAddress();
    } catch (e) {
      // Handle error
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
          children: [],
        ),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(color: PdfColors.grey),
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
            ],
            data: ledgerdata.reversed.map((ledger) {
              final amt = ledger.totalAmount ?? 0;
              final amountStr = amt < 0
                  ? '(${formatMoney(amt.abs())})'
                  : formatMoney(amt);
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
                  child: pw.Text(amountStr),
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
            cellStyle: pw.TextStyle(
              fontSize: 10,
            ),
            cellHeight: 30,
            columnWidths: {
              0: pw.FlexColumnWidth(1.2), // Date
              1: pw.FlexColumnWidth(1.4), // tenants
              2: pw.FlexColumnWidth(1.3), // type
              3: pw.FlexColumnWidth(2.2), // transaction
              4: pw.FlexColumnWidth(1.3), // Amount
            },
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            children: [
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text('Total Amount',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                    ledgerdata.isNotEmpty
                        ? formatMoney(ledgerdata.fold<double>(0, (s, d) => s + (d.totalAmount ?? 0)))
                        : '\$0.00',
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
          bytes: await pdf.save(), filename: 'Tenant_payments.pdf');
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

      sheet.getRangeByIndex(2 + i, 1).setText(ledger.entry?.first.date);

      sheet.getRangeByIndex(2 + i, 2).setText(ledger.tenantData != null
          ? '${ledger.tenantData["tenant_firstName"] ?? ""} ${ledger.tenantData["tenant_lastName"] ?? ""}'
          : 'N/A' ?? '');

      sheet.getRangeByIndex(2 + i, 3).setText(ledger.type ?? '');

      sheet.getRangeByIndex(2 + i, 4).setText(ledger.type == "Charge"
          ? "${ledger.entry?.first.memo}"
          : 'Manual ${ledger.type} ${ledger.response} For ${ledger.paymenttype}' ??
              '');

      final amt = ledger.totalAmount ?? 0;
      final amountStr = amt < 0
          ? '(${formatMoney(amt.abs())})'
          : formatMoney(amt);
      sheet.getRangeByIndex(2 + i, 5).setText(amountStr);
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
      final amt = ledger.totalAmount ?? 0;
      final amountStr = amt < 0
          ? '(${formatMoney(amt.abs())})'
          : formatMoney(amt);
      final rowData = [
        formattedDate,
        ledger.tenantData != null
            ? '${ledger.tenantData["tenant_firstName"] ?? ""} ${ledger.tenantData["tenant_lastName"] ?? ""}'
            : 'N/A',
        ledger.type ?? '',
        ledger.type == "Charge"
            ? "${ledger.entry?.first.memo}"
            : 'Manual ${ledger.type} ${ledger.response} For ${ledger.paymenttype}',
        amountStr,
      ];
      csvData.add(rowData);
    }

    final String csvContent = ListToCsvConverter().convert(csvData);
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

  void _fetchData() {
    final fromD = _fromDateController.text;
    final toD = _toDateController.text;
    if (fromD.isNotEmpty && toD.isNotEmpty) {
      final fromApi = reverseFormatDate(fromD);
      final toApi = reverseFormatDate(toD);
      if (fromApi.isNotEmpty && toApi.isNotEmpty) {
        _leaseLedgerFuture = TenantLeaseRepository().fetchLeaseLedger(
          leaseId: widget.leaseId,
          fromDate: fromApi,
          toDate: toApi,
        );
      } else {
        _leaseLedgerFuture = TenantLeaseRepository().fetchLeaseLedger(
          leaseId: widget.leaseId,
        );
      }
    } else {
      _leaseLedgerFuture = TenantLeaseRepository().fetchLeaseLedger(
        leaseId: widget.leaseId,
      );
    }
    setState(() {});
  }

  void _onDateChanged() {
    setState(() {
      _fetchData();
    });
  }

  Future<void> _selectfromDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        controller.text = dateProvider.formatCurrentDate(apiFormatDate);
        fdate = apiFormatDate; // Keep API format for filtering
      });
      if (_fromDateController.text.isNotEmpty &&
          _toDateController.text.isNotEmpty) {
        _fetchData();
      }
    }
  }

  Future<void> _selectendDate(
      BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
        // Get dateProvider to format the date according to user's preference
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        // Display format: Use provider's format for user display
        String apiFormatDate = DateFormat('yyyy-MM-dd').format(picked);
        controller.text = dateProvider.formatCurrentDate(apiFormatDate);
        edate = apiFormatDate; // Keep API format for filtering
      });
      if (_fromDateController.text.isNotEmpty &&
          _toDateController.text.isNotEmpty) {
        _fetchData();
      }
    }
  }

  List<Data> allData = []; // Assume this is your complete dataset
  List<Data> filteredData = [];

  // Helper function to convert display format back to API format (yyyy-MM-dd)
  String _convertToApiFormat(String displayDate) {
    if (displayDate.isEmpty) return "";
    // The company's own date format first (strict), like web, so a custom
    // format such as "DD/MMM/YYYY" reads back correctly (AppDateFormat).
    final inCompanyFormat = AppDateFormat.parseShownToApi(displayDate);
    if (inCompanyFormat != null) return inCompanyFormat;
    final viaReverse = reverseFormatDate(displayDate);
    if (viaReverse.isNotEmpty) return viaReverse;
    try {
      DateTime? parsedDate;

      List<String> dateFormats = [
        'yyyy-MM-dd',
        'yyyy-MMM-dd',
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'dd/MM/yyyy',
        'dd-MM-yyyy'
      ];

      for (String format in dateFormats) {
        try {
          parsedDate = DateFormat(format).parse(displayDate);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }

      return displayDate;
    } catch (e) {
      return displayDate;
    }
  }

  /// Payment date for filtering; prefer [Data.createdAt] to match the Date column.
  DateTime? _leasePaymentDateOnly(Data lease) {
    try {
      final raw = lease.createdAt;
      if (raw != null && raw.isNotEmpty) {
        final s = raw.contains(' ') ? raw.split(' ')[0] : raw;
        return DateTime.parse(s);
      }
      if (lease.entry != null &&
          lease.entry!.isNotEmpty &&
          (lease.entry!.first.date ?? '').isNotEmpty) {
        return DateFormat('yyyy-MM-dd').parse(lease.entry!.first.date!);
      }
    } catch (_) {}
    return null;
  }

  bool _paymentInDateRange(
    DateTime? paymentDay,
    DateTime fromDay,
    DateTime toDay,
  ) {
    if (paymentDay == null) return false;
    final p = DateTime(paymentDay.year, paymentDay.month, paymentDay.day);
    final f = DateTime(fromDay.year, fromDay.month, fromDay.day);
    final t = DateTime(toDay.year, toDay.month, toDay.day);
    return !p.isBefore(f) && !p.isAfter(t);
  }

  List<Data> _filterLeasePaymentRows(List<Data> rows) {
    var list = rows.toList();
    final sv = searchvalue;
    if (sv.isNotEmpty && sv != 'All') {
      final q = sv.toLowerCase();
      list = list.where((lease) {
        if ((lease.type ?? '').toLowerCase().contains(q)) return true;
        if ((lease.balance?.toString() ?? '').toLowerCase().contains(q)) {
          return true;
        }
        if ((lease.totalAmount?.toString() ?? '').toLowerCase().contains(q)) {
          return true;
        }
        if ((lease.transactionid ?? '').toLowerCase().contains(q)) {
          return true;
        }
        if ((lease.paymenttype ?? '').toLowerCase().contains(q)) return true;
        if ((lease.response ?? '').toLowerCase().contains(q)) return true;
        if ((lease.createdAt ?? '').toLowerCase().contains(q)) return true;
        final td = lease.tenantData;
        if (td is Map) {
          final fn =
              '${td['tenant_firstName'] ?? ''} ${td['tenant_lastName'] ?? ''}'
                  .toLowerCase();
          if (fn.contains(q)) return true;
        }
        return false;
      }).toList();
    }

    if (_fromDateController.text.isNotEmpty &&
        _toDateController.text.isNotEmpty) {
      try {
        final fromDateStr = _convertToApiFormat(_fromDateController.text);
        final toDateStr = _convertToApiFormat(_toDateController.text);
        if (fromDateStr.isEmpty || toDateStr.isEmpty) return list;
        final fromDate = DateFormat('yyyy-MM-dd').parse(fromDateStr);
        final toDate = DateFormat('yyyy-MM-dd').parse(toDateStr);
        list = list.where((lease) {
          final pd = _leasePaymentDateOnly(lease);
          return _paymentInDateRange(pd, fromDate, toDate);
        }).toList();
      } catch (e) {
      }
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    // This view lives inside another screen's tab, so it shows the
    // compact offline state rather than taking over the whole page.
    if (isOffline) {
      return NoInternetView(compact: true, onRetry: retryNow);
    }
    double screenWidth = MediaQuery.of(context).size.width;
    final dateProvider = Provider.of<DateProvider>(context, listen: true);
    final dateFormatHint =
        dateProvider.fixDateFormat(dateProvider.dateFormat).toUpperCase();

    return Container(
      child: SingleChildScrollView(
        child: Column(
          children: [
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
                      return Container(
                        height: MediaQuery.of(context).size.height * .2,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Image.asset(
                                "assets/images/no_data.jpg",
                                height: 200,
                                width: 200,
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Text(
                                "No Data Available",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: blueColor,
                                    fontSize: 16),
                              )
                            ],
                          ),
                        ),
                      );
                    } else {
                      final leaseLedger = snapshot.data!;
                      var data = _filterLeasePaymentRows(
                          leaseLedger.data!.toList());

                      sortData(data);
                      final totalPages = (data.isEmpty ? 1 : (data.length / itemsPerPage).ceil());
                      final currentPageData = data
                          .skip(currentPage * itemsPerPage)
                          .take(itemsPerPage)
                          .toList();

                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            Expanded(
                              flex: 0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5.0, vertical: 5),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Material(
                                        elevation: 0,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          height: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 48
                                              : 50,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: const Color(0xFF8A95A8)),
                                          ),
                                          child: TextField(
                                            onChanged: (value) {
                                              setState(() {
                                                searchvalue = value;
                                                currentPage = 0; // reset to first page on search change
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: "Search here...",
                                              hintStyle: TextStyle(
                                                  color: Color(0xFF8A95A8)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // SizedBox(height: 10),
                            Container(
                              // width: double.infinity,
                              // decoration: BoxDecoration(
                              //   border: Border.all(
                              //     color: blueColor,
                              //   ),
                              //   borderRadius: BorderRadius.circular(10.0),
                              // ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 5, horizontal: 5),
                                child: Form(
                                  key: _formKey,
                                  child: screenWidth > 500
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('From',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  SizedBox(height: 5),
                                                  Container(
                                                    child: TextFormField(
                                                      controller:
                                                          _fromDateController,
                                                      readOnly: true,
                                                      onTap: () => _selectfromDate(
                                                          context,
                                                          _fromDateController),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: dateFormatHint,
                                                        suffixIcon: Icon(Icons
                                                            .calendar_today),
                                                        border:
                                                            OutlineInputBorder(),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: 40),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text('To',
                                                      style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  SizedBox(height: 5),
                                                  TextFormField(
                                                    controller:
                                                        _toDateController,
                                                    readOnly: true,
                                                    onTap: () => _selectendDate(
                                                        context,
                                                        _toDateController),
                                                    decoration: InputDecoration(
                                                      hintText: dateFormatHint,
                                                      suffixIcon: Icon(
                                                          Icons.calendar_today),
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Container(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        // Text('From',
                                                        //     style: TextStyle(
                                                        //         color: blueColor,
                                                        //         fontSize: 15,
                                                        //         fontWeight: FontWeight.w600)),
                                                        // SizedBox(height: 4),

                                                        Material(
                                                          elevation: 0,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                          child: Container(
                                                            height: 50,
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        10.0,
                                                                    vertical:
                                                                        0),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8.0),
                                                              border: Border.all(
                                                                  color: const Color(
                                                                      0xFF8A95A8)),
                                                            ),
                                                            child:
                                                                TextFormField(
                                                              controller:
                                                                  _fromDateController,
                                                              // initialValue: fdate,
                                                              readOnly: true,
                                                              onTap: () =>
                                                                  _selectfromDate(
                                                                      context,
                                                                      _fromDateController),
                                                              decoration:
                                                                  InputDecoration(
                                                                // contentPadding: EdgeInsets.all(8.0),
                                                                // contentPadding: EdgeInsets.symmetric(),
                                                                suffixIconConstraints:
                                                                    BoxConstraints(
                                                                        maxWidth:
                                                                            20,
                                                                        maxHeight:
                                                                            20,
                                                                        minHeight:
                                                                            20,
                                                                        minWidth:
                                                                            20),
                                                                hintStyle: TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    color: Color(
                                                                        0xFFb0b6c3)),
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                hintText:
                                                                    dateFormatHint,
                                                                suffixIcon:
                                                                    IconButton(
                                                                  padding: EdgeInsets
                                                                      .symmetric(
                                                                          vertical:
                                                                              1),
                                                                  iconSize: 20,
                                                                  icon: Icon(Icons
                                                                      .calendar_today),
                                                                  onPressed:
                                                                      () {},
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 16,
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        // Text('To',
                                                        //     style: TextStyle(
                                                        //         color: blueColor,
                                                        //         fontSize: 15,
                                                        //         fontWeight: FontWeight.w600)),
                                                        // SizedBox(height: 4),

                                                        Material(
                                                          elevation: 0,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                          child: Container(
                                                            height: 50,
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        10.0,
                                                                    vertical:
                                                                        0),
                                                            decoration:
                                                                BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8.0),
                                                              border: Border.all(
                                                                  color: const Color(
                                                                      0xFF8A95A8)),
                                                            ),
                                                            child:
                                                                TextFormField(
                                                              controller:
                                                                  _toDateController,
                                                              readOnly: true,
                                                              onTap: () {
                                                                _selectendDate(
                                                                    context,
                                                                    _toDateController);
                                                              },
                                                              decoration:
                                                                  InputDecoration(
                                                                // contentPadding: EdgeInsets.all(8.0),
                                                                // contentPadding: EdgeInsets.symmetric(),
                                                                suffixIconConstraints:
                                                                    BoxConstraints(
                                                                        maxWidth:
                                                                            20,
                                                                        maxHeight:
                                                                            20,
                                                                        minHeight:
                                                                            20,
                                                                        minWidth:
                                                                            20),
                                                                hintStyle: TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    color: Color(
                                                                        0xFFb0b6c3)),
                                                                border:
                                                                    InputBorder
                                                                        .none,
                                                                hintText:
                                                                    dateFormatHint,
                                                                suffixIcon:
                                                                    IconButton(
                                                                  padding: EdgeInsets
                                                                      .symmetric(
                                                                          vertical:
                                                                              1),
                                                                  iconSize: 20,
                                                                  icon: Icon(Icons
                                                                      .calendar_today),
                                                                  onPressed:
                                                                      () {},
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 10,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                            // SizedBox(height: 5),
                            if (data.isNotEmpty)
                              if (currentPageData.length > 0) _buildHeaders(),
                            const SizedBox(height: 10),
                            Container(
                              child: Column(
                                children: currentPageData.isEmpty
                                    ? [kNoSearchResults(context)]
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
                                        const EdgeInsets.symmetric(vertical: 6,horizontal: 5),
                                    decoration: BoxDecoration(
                                      color: index % 2 != 0
                                          ? const Color(0xFFF4F8FF)
                                          : Colors.white,
                                      border: Border.all(
                                          color: const Color(0xFFDBE0E5)),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
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
                                                GestureDetector(
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
                                                            8.0),
                                                    child: Text(
                                                      ' ${data.type}' ?? "",
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
                                                  child: Text(
                                                    data.totalAmount != null
                                                        ? (data.type == "Payment"
                                                            ? '(${formatMoney((data.totalAmount!).abs())})'
                                                            : formatMoney((data.totalAmount!).abs()))
                                                        : 'N/A',
                                                        textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
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
                                                  child: Text(
                                                    (data.entry != null &&
                                                            data.entry!
                                                                .isNotEmpty)
                                                        ? dateProvider
                                                            .formatCurrentDate(
                                                                '${data.entry!.first.date}')
                                                        : 'N/A',
                                                    style: TextStyle(
                                                      color: blueColor,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
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
                                                                  if (data.type != "Charge" &&
                                                                      data.response !=
                                                                          "VOID" &&
                                                                      data.state !=
                                                                          "settling")
                                                                    TextSpan(
                                                                      text:
                                                                          '${data.paymenttype} ${data.type} ${data.response} ',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .w700,
                                                                          color:
                                                                              grey), // Light and grey
                                                                    ),
                                                                  if (data.type != "Charge" &&
                                                                      data.response !=
                                                                          "VOID" &&
                                                                      data.state ==
                                                                          "settling")
                                                                    TextSpan(
                                                                      text:
                                                                          '${data.paymenttype} ${data.type} ${data.response}  :Awaiting Settlement ',
                                                                      style: TextStyle(
                                                                          fontWeight: FontWeight
                                                                              .w700,
                                                                          color:
                                                                              grey), // Light and grey
                                                                    ),
                                                                  if (data.type !=
                                                                          "Charge" &&
                                                                      data.response ==
                                                                          "VOID")
                                                                    TextSpan(
                                                                      text:
                                                                          'Card Payment VOID ${data.responseText}',
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
                                                            SizedBox(
                                                              height: 5,
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
                                                  SizedBox(
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
                                                              SizedBox(
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
                                                      children: [
                                                        Expanded(
                                                          child:
                                                              GestureDetector(
                                                            onTap: () {
                                                              setState(() {
                                                                _amountController
                                                                    .text = (data
                                                                        .totalAmount!)
                                                                    .toString();
                                                                // The payment's own date, like web's refund modal (today when
                                                                // a payment has none: there is no Required check here).
                                                                _dateController.text = AppDateFormat.format(
                                                                    AppDateFormat.parseCalendarDate(data.paymentDate,
                                                                            dayFirstToo: true) ??
                                                                        DateTime.now());
                                                              });
                                                              _showRefundDialog(
                                                                  context,
                                                                  data);
                                                              // Navigator.of(context)
                                                              //     .push(MaterialPageRoute(builder: (context) => Workorder_summery(workorder_id: workorder.workOrderId,)));
                                                            },
                                                            child: Container(
                                                              height: 40,
                                                              decoration:
                                                                  BoxDecoration(
                                                                      color: Colors
                                                                              .grey[
                                                                          350]),
                                                              child: Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  SizedBox(
                                                                    width: 5,
                                                                  ),
                                                                  Icon(Icons
                                                                      .wallet),
                                                                  // FaIcon(
                                                                  //   FontAwesomeIcons.trashCan,
                                                                  //   size: 15,
                                                                  //   color:blueColor,
                                                                  // ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    "Refund",
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        color:
                                                                            blueColor,
                                                                        fontWeight:
                                                                            FontWeight.bold),
                                                                  )
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 5,
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
                                }).toList(),
                              ),
                            ),
                            if (data.isEmpty)
                              Container(
                                // height: MediaQuery.of(context).size.height * .3,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        "assets/images/no_data.jpg",
                                        height: 200,
                                        width: 200,
                                      ),
                                      SizedBox(
                                        height: 10,
                                      ),
                                      Text(
                                        "No Data Available",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: blueColor,
                                            fontSize: 16),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(height: 20),
                            if (data.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      // Text('Rows per page:'),
                                      SizedBox(width: 10),
                                      Material(
                                        elevation: 3,
                                        child: Container(
                                          height: 40,
                                          padding: EdgeInsets.symmetric(
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
                    final filtered =
                        _filterLeasePaymentRows(snapshot.data!.data!);
                    _tableData = List<Data?>.from(filtered);
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
                                                  'Transaction', 2, null),
                                              _buildHeader('Increase', 3, null),
                                              _buildHeader('Decrease', 3, null),
                                              _buildAmountHeader(),
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
                                                  _formatAmountForTable(
                                                      _pagedData[i]!
                                                          .totalAmount),
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
                      snapshot.data!.data!.isEmpty) {
                    return const Center(child: Text('No data available'));
                  } else {
                    final filtered =
                        _filterLeasePaymentRows(snapshot.data!.data!);
                    _tableData = List<Data?>.from(filtered);
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
                                          return _buildAmountHeader();
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
                                              _formatAmountForTable(
                                                  _pagedData[i]!.totalAmount),
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
            SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
