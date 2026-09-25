import 'package:three_zero_two_property/services/app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/repository/setting.dart';
import 'package:three_zero_two_property/screens/Leasing/RentalRoll/enterCharge.dart';
import '../../../constant/constant.dart';
import '../../../model/LeaseSummary.dart';
import '../../../model/get_lease.dart';
import '../../../provider/dateProvider.dart';
import '../../../repository/lease.dart';
import '../../../widgets/CustomTableShimmer.dart';
import '../../../widgets/appbar.dart';
import '../../../widgets/custom_drawer.dart';
import 'package:three_zero_two_property/screens/Rental/Tenants/add_tenants.dart';

import 'SummeryPageLease.dart';
import 'newAddLease.dart';

class Renewlease extends StatefulWidget {
  LeaseSummary? lease;
  String leaseId;
  String? startdate;
  String? enddate;

  String? leasetype;
  String? rentamount;
  Renewlease(
      {super.key,
      required this.leaseId,
      this.lease,
      this.rentamount,
      this.startdate,
      this.enddate,
      this.leasetype});

  @override
  State<Renewlease> createState() => _RenewleaseState();
}

class _RenewleaseState extends State<Renewlease> {
  List formDataRecurringList = [];
  late Future<LeaseSummary> futureLeaseSummary;
  final GlobalKey<FormState> _subFormKey = GlobalKey<FormState>();
  TabController? _tabController;
  bool isError = false;
  late LeaseSummary leasegetdata;

  @override
  void initState() {
    // TODO: implement initState
    futureLeaseSummary = LeaseRepository.fetchLeaseSummary(widget.leaseId);
    // _tabController = TabController(length: 3, vsync: this);
    _selectedLeaseType = widget.leasetype;

    // Use formatDate4 to get dd-MM-yyyy format for display
    startDateController.text = formatDate4(widget.enddate!) ?? "";
    DateTime endDate = formatDates(widget.enddate!);
    DateTime startDate = endDate;
    DateTime newEndDate =
        DateTime(endDate.year, endDate.month + 1, endDate.day);

    // Use formatDate4 to get dd-MM-yyyy format for display
    endDateController.text =
        formatDate4(DateFormat('yyyy-MM-dd').format(newEndDate));
    rent.text = widget.rentamount ?? "";

    // if(widget.renewfileName != "")
    //   _uploadedFileNames.add(widget.renewfileName!);

    fetchDropdownData();
    leaseData();

    super.initState();

    // bool isLeaseRenewed = widget.lease.data.startDate. != null && widget.renewLeases!.isNotEmpty;
    //
    // // Set the start date based on lease status
    // if (isLeaseRenewed) {
    //   // If the lease is renewed, set the start date to the formatted end date
    //   startDateController.text = DateFormat('yyyy-MM-dd').format(endDate);
    // } else {
    //   // If the lease is expired, set the start date to the current date
    //   startDateController.text = formatDate(DateTime.now().toString());
    // }
  }

  void _refreshAccounts() {
    setState(() {
      fetchDropdownData();
    });
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

    return parsedDate!;
  }

  leaseData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = prefs.getString("adminId");

    final response = await apiGet(
      Uri.parse('$Api_url/api/leases/lease_summary/${widget.leaseId}'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        leasegetdata = LeaseSummary.fromJson(jsonDecode(response.body));
        if (determineStatus(
            leasegetdata.data!.startDate, leasegetdata.data!.endDate)) {
          // Lease is expired
          startDateController.text = formatDate4(DateTime.now().toString());

          // Set the end date to one month from today's date
          DateTime newEndDate = DateTime(DateTime.now().year,
              DateTime.now().month + 1, DateTime.now().day);
          endDateController.text =
              formatDate4(DateFormat('yyyy-MM-dd').format(newEndDate));
        }
        if (leasegetdata.data!.renewLeases != null &&
            leasegetdata.data!.renewLeases!.isNotEmpty) {
          // Lease is active
          if (!determineStatus(leasegetdata.data!.renewLeases!.last.startDate!,
              leasegetdata.data!.renewLeases!.last.endDate!)) {
            DateTime endDate =
                formatDates(leasegetdata.data!.renewLeases!.last.endDate!);

            // Set start date to the current lease's end date
            startDateController.text =
                formatDate4(DateFormat('yyyy-MM-dd').format(endDate));

            // Extend the lease for one month from the current lease's end date
            DateTime newEndDate =
                DateTime(endDate.year, endDate.month + 1, endDate.day);
            endDateController.text =
                formatDate4(DateFormat('yyyy-MM-dd').format(newEndDate));
          }
        }
      });
    } else {
      throw Exception('Failed to load lease summary');
    }
  }

  TextEditingController rent = TextEditingController();
  TextEditingController securitydeposit = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  DateTime? _startDate;
  final TextEditingController endDateController = TextEditingController();
  String moveOutDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  bool isLoading = false;
  bool isMovedOut = false;
  String? _selectedLeaseType;
  final List<String> leaseTypeitems = [
    'Fixed',
    'Fixed w/rollover',
    'At-will(month to month)',
  ];

  bool hasError = false;
  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      keyboardBarColor: Colors.grey[200],
      nextFocus: true,
      actions: [
        KeyboardActionsItem(
          focusNode: _nodeText1,
        ),
        // Add actions for table amount fields
        ...focusNodes
            .map((focusNode) => KeyboardActionsItem(
                  focusNode: focusNode,
                ))
            .toList(),
      ],
    );
  }

  List<FocusNode> focusNodes = [];
  Map<String, List<String>> categorizedData = {};
  final FocusNode _nodeText1 = FocusNode();
  List<Map<String, dynamic>> rows = [];
  double totalAmount = 0.0;
  void addRow() {
    setState(() {
      rows.add({
        'account': null,
        'charge_type': null,
        'amount': "0",
        'memo': "",
      });
      focusNodes.add(FocusNode());
    });
  }

  void deleteRow(int index) {
    setState(() {
      if (rows[index]['amount'].runtimeType == String) {
        totalAmount -= double.tryParse(rows[index]['amount']) ?? 0.0;
      } else {
        totalAmount -= rows[index]['amount'];
      }

      rows.removeAt(index);
      focusNodes.removeAt(index);
    });

    validateAmounts();
  }

  void updateAmount(int index, String value) {
    setState(() {
      double oldAmount = 0.0;
      if (rows[index]['amount'].toString().isNotEmpty) {
        oldAmount = double.tryParse(rows[index]['amount'].toString()) ?? 0.0;
      }

      totalAmount -= oldAmount;

      double newAmount = double.tryParse(value) ?? 0.0;
      rows[index]['amount'] = value;
      totalAmount += newAmount;
    });
    validateAmounts();
  }

  final TextEditingController Amount = TextEditingController();
  String? validationMessage;
  void validateAmounts() {
    double enteredAmount = double.tryParse(Amount.text) ?? 0.0;
    double roundedEntered = double.parse(enteredAmount.toStringAsFixed(2));
    double roundedTotal = double.parse(totalAmount.toStringAsFixed(2));
    if (roundedEntered != roundedTotal) {
      setState(() {
        validationMessage =
            "The charge's amount must match the total applied to balance. The difference is ${(roundedEntered - roundedTotal).abs().toStringAsFixed(2)}";
      });
    } else {
      setState(() {
        validationMessage = null;
      });
    }
  }

  Future<void> fetchDropdownData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String adminId = prefs.getString('adminId') ?? '';
      String? token = prefs.getString('token');
      String? id = prefs.getString("adminId");

      final response = await apiGet(
        Uri.parse('$Api_url/api/accounts/accounts/$adminId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['data'] != null) {
          List<dynamic> data = jsonResponse['data'];
          Map<String, List<String>> fetchedData = {};

          // Initialize with static liability accounts
          fetchedData["Liability Account"] = [
            "Late Fee Income",
            "Pre-payments",
          ];

          // Group accounts by charge_type
          for (var item in data) {
            String chargeType = item['charge_type'] ?? 'Other';
            String account = item['account'] ?? '';

            if (account.isNotEmpty) {
              if (!fetchedData.containsKey(chargeType)) {
                fetchedData[chargeType] = [];
              }
              if (!fetchedData[chargeType]!.contains(account)) {
                fetchedData[chargeType]!.add(account);
              }
            }
          }

          setState(() {
            categorizedData = fetchedData;
            isLoading = false;

            // Initialize first row if rows is empty
            if (rows.isEmpty) {
              rows.add({
                'account': null,
                'charge_type': null,
                'amount': "",
              });
              focusNodes.add(FocusNode());
            }
          });
        } else {
          setState(() {
            hasError = true;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      logError('Error in fetchDropdownData: $e');
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  Future<void> updatenewrenewallease(Map<String, dynamic> renewlease) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String adminId = prefs.getString('adminId') ?? '';
      String? token = prefs.getString('token');
      String? id = prefs.getString("adminId");


      // Test if the API endpoint is reachable
      try {
        final testResponse = await apiGet(
          Uri.parse('$Api_url/api/leases/lease_summary/${widget.leaseId}'),
          headers: {
            "authorization": "CRM $token",
            "id": "CRM $id",
          },
        );
      } catch (e) {
        logError('Test API call failed: $e');
      }

      final response =
          await apiPost(Uri.parse('$Api_url/api/leases/renew_lease'),
              headers: {
                "authorization": "CRM $token",
                "id": "CRM $id",
                'Content-Type': 'application/json',
              },
              body: json.encode(renewlease));


      if (response.statusCode == 200) {
        Fluttertoast.showToast(msg: "Lease Renewal Successfully");
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (context) => SummeryPageLease(
                  leaseId: widget.leaseId,
                )));
      } else {
        Fluttertoast.showToast(msg: "Lease renewal failed: ${response.body}");
      }
    } catch (e) {
      logError('EXCEPTION: $e');
      Fluttertoast.showToast(msg: "Network error: ${friendlyErrorMessage(e)}");
    }
  }

  String? _selectedAccountType;
  String? _selectedFundType;
  final TextEditingController _accountNameController = TextEditingController();
  String? _selectedProperty;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  bool _isInvalid = true;
  List<String> items = []; // Example items

  List<String> accountTypeItems = [
    'Income',
    'Non Operating Income ',
    'Liability Account',
  ]; // Example items
  List<String> fundTypeItems = [
    'Reverse',
    'Operating',
  ]; // Example items

  List<String> accounts = [];
  //for upload file

  List<File> _pdfFiles = [];

  List<String> _uploadedFileNames = [];

  Future<void> _pickPdfFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );

    if (result != null) {
      List<File> files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();

      if (files.length > 10) {
        Fluttertoast.showToast(msg: 'You can only select up to 10 files.');
        return; // Exit the method if more than 10 files are selected
      }

      setState(() {
        _pdfFiles = files;
      });

      for (var file in _pdfFiles) {
        await _uploadPdf(file);
      }
    }
  }

  Future<void> _uploadPdf(File pdfFile) async {
    try {
      String? fileName = await uploadPdf(pdfFile);
      setState(() {
        if (fileName != null) {
          if (_uploadedFileNames.isNotEmpty) {
            _uploadedFileNames.clear();
          }
          _uploadedFileNames.add(fileName);
        }
      });
    } catch (e) {
      logError('PDF upload failed: $e');
    }
  }

  Future<String?> uploadPdf(File pdfFile) async {
    final String uploadUrl = '${image_upload_url}/api/images/upload';

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('files', pdfFile.path));

    var response = await apiSend(request);
    var responseData = await http.Response.fromStream(response);

    var responseBody = json.decode(responseData.body);
    if (responseBody['status'] == 'ok') {
      Fluttertoast.showToast(msg: 'PDF added successfully');
      List file = responseBody['files'];
      return file.first["filename"];
    } else {
      throw Exception('Failed to upload file: ${responseBody['message']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateProvider = Provider.of<DateProvider>(context);
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Leases",
        dropdown: true,
      ),
      body: ListView(
        children: [
          const SizedBox(
            height: 25,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5.0),
              child: Container(
                height: 50.0,
                padding: const EdgeInsets.only(top: 10, left: 10),
                width: MediaQuery.of(context).size.width * .91,
                margin: const EdgeInsets.only(bottom: 6.0),
                //Same as `blurRadius` i guess
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5.0),
                  color: blueColor,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.grey,
                      offset: Offset(0.0, 1.0), //(x,y)
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: const Text(
                  "Renew Lease",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Container(
            child: FutureBuilder<LeaseSummary>(
              future: futureLeaseSummary,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).size.height * .35),
                    child: Center(
                        child: SpinKitFadingCircle(
                      color: blueColor,
                      size: 40.0,
                    )),
                  );
                } else if (snapshot.hasError) {
                  return Center(child: Text(friendlyErrorMessage(snapshot.error), textAlign: TextAlign.center));
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No data found'));
                } else {
                  final leasesummery = snapshot.data!;
                  // if (determineStatus(snapshot.data!.data!.startDate, snapshot.data!.data!.endDate)) {
                  //   // Lease is expired
                  //   startDateController.text = formatDate(DateTime.now().toString());
                  //
                  //   // Set the end date to one month from today's date
                  //   DateTime newEndDate = DateTime(
                  //       DateTime.now().year,
                  //       DateTime.now().month + 1,
                  //       DateTime.now().day
                  //   );
                  //   endDateController.text = formatDate(
                  //       DateFormat('yyyy-MM-dd').format(newEndDate).toString());
                  // } else if (snapshot.data!.data!.renewLeases != null &&
                  //     snapshot.data!.data!.renewLeases!.isNotEmpty) {
                  //   // Lease is active
                  //   DateTime endDate = formatDates(snapshot.data!.data!.renewLeases!.last.endDate!);
                  //
                  //   // Set start date to the current lease's end date
                  //   startDateController.text = formatDate(
                  //       DateFormat('yyyy-MM-dd').format(endDate).toString()
                  //   );
                  //
                  //   // Extend the lease for one month from the current lease's end date
                  //   DateTime newEndDate = DateTime(endDate.year, endDate.month + 1, endDate.day);
                  //   endDateController.text = formatDate(
                  //       DateFormat('yyyy-MM-dd').format(newEndDate).toString());
                  // }

                  // if (determineStatus(snapshot.data!.data!.startDate,
                  //     snapshot.data!.data!.endDate)) {
                  //   startDateController.text =
                  //       formatDate(DateTime.now().toString());
                  //
                  //   if (snapshot.data!.data!.renewLeases != null &&
                  //       snapshot.data!.data!.renewLeases!.isNotEmpty){
                  //     DateTime endDate = formatDates(
                  //         snapshot.data!.data!.renewLeases!.last.endDate!);
                  //     DateTime startDate = endDate;
                  //     DateTime newEndDate =
                  //     DateTime(endDate.year + 1, endDate.month, endDate.day);
                  //     endDateController.text = formatDate(
                  //         DateFormat('yyyy-MM-dd').format(newEndDate).toString());
                  //   }
                  //
                  //   // DateTime endDate = formatDates(
                  //   //     snapshot.data!.data!.renewLeases!.last.endDate!);
                  //   // DateTime startDate = endDate;
                  //   // DateTime newEndDate =
                  //   //     DateTime(endDate.year + 1, endDate.month, endDate.day);
                  //   // endDateController.text = formatDate(
                  //   //     DateFormat('yyyy-MM-dd').format(newEndDate).toString());
                  // }
                  // else if (snapshot.data!.data!.renewLeases!.length > 0) {
                  //   startDateController.text = formatDate(
                  //       snapshot.data!.data!.renewLeases!.last.endDate!);
                  //   DateTime endDate = formatDates(
                  //       snapshot.data!.data!.renewLeases!.last.endDate!);
                  //   DateTime startDate = endDate;
                  //   DateTime newEndDate =
                  //       DateTime(endDate.year + 1, endDate.month, endDate.day);
                  //   endDateController.text = formatDate(
                  //       DateFormat('yyyy-MM-dd').format(newEndDate).toString());
                  // }

                  //final data = leaseLedger.data!.toList();
                  return Padding(
                    padding: const EdgeInsets.only(
                        left: 20, right: 20, top: 10, bottom: 20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${leasesummery.data?.rentalAddress}',
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: blueColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: 5,
                          ),
                          Material(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: blueColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, right: 8, top: 10, bottom: 30),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: grey,
                                          borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8))),
                                      child: const Column(
                                        // crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 10,
                                              ),
                                              Text(
                                                "Current terms",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Colors.black),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Table(
                                      children: [
                                        TableRow(children: [
                                          const TableCell(
                                              child: Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Text(
                                              'Lease Type',
                                              style: TextStyle(
                                                  color:
                                                      Color(0xFF8A95A8),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          )),
                                          TableCell(
                                              child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(
                                              '${leasesummery.data?.leaseType}',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: blueColor),
                                            ),
                                          )),
                                        ]),
                                        TableRow(children: [
                                          const TableCell(
                                              child: Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Text(
                                              'Start - End ',
                                              style: TextStyle(
                                                  color:
                                                      Color(0xFF8A95A8),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          )),
                                          TableCell(
                                              child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(
                                              '${dateProvider.formatCurrentDate('${leasesummery.data?.startDate}')} to ${dateProvider.formatCurrentDate('${leasesummery.data?.endDate}')}',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: blueColor),
                                            ),
                                          )),
                                        ]),
                                        TableRow(children: [
                                          const TableCell(
                                              child: Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: Text(
                                              'Rent',
                                              style: TextStyle(
                                                  color:
                                                      Color(0xFF8A95A8),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16),
                                            ),
                                          )),
                                          TableCell(
                                              child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 12),
                                            child: Text(
                                              '${leasesummery.data?.amount}',
                                              style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
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
                          const SizedBox(
                            height: 15,
                          ),
                          Material(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: blueColor),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(
                                    left: 8, right: 8, top: 10, bottom: 30),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: grey,
                                          borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8))),
                                      child: const Column(
                                        // crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                width: 10,
                                              ),
                                              Text(
                                                "Offer",
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Colors.black),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          'Lease Type',
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Expanded(
                                          child: FormField<String>(
                                            initialValue: _selectedLeaseType,
                                            builder:
                                                (FormFieldState<String> state) {
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButton2<String>(
                                                      isExpanded: true,
                                                      hint: const Row(
                                                        children: [
                                                          SizedBox(
                                                            width: 4,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              'Type',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black,
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      items: leaseTypeitems
                                                          .map(
                                                            (String item) =>
                                                                DropdownMenuItem<
                                                                    String>(
                                                              value: item,
                                                              child: Text(
                                                                item,
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: Colors
                                                                      .black,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                      value: _selectedLeaseType,
                                                      onChanged: (value) {
                                                        // Update the FormField state
                                                        setState(() {
                                                          _selectedLeaseType =
                                                              value;
                                                          state
                                                              .didChange(value);
                                                        });
                                                        state.reset();
                                                      },
                                                      buttonStyleData:
                                                          ButtonStyleData(
                                                        height: 50,
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 14,
                                                                right: 14),
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                            color:
                                                                Colors.black26,
                                                          ),
                                                          color: Colors.white,
                                                        ),
                                                        elevation: 3,
                                                      ),
                                                      dropdownStyleData:
                                                          DropdownStyleData(
                                                        maxHeight: 200,
                                                        width: 200,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(14),
                                                        ),
                                                        offset: const Offset(
                                                            -20, 0),
                                                        scrollbarTheme:
                                                            ScrollbarThemeData(
                                                          radius: const Radius
                                                              .circular(40),
                                                          thickness:
                                                              MaterialStateProperty
                                                                  .all(6),
                                                          thumbVisibility:
                                                              MaterialStateProperty
                                                                  .all(true),
                                                        ),
                                                      ),
                                                      menuItemStyleData:
                                                          const MenuItemStyleData(
                                                        height: 40,
                                                        padding:
                                                            EdgeInsets.only(
                                                                left: 14,
                                                                right: 14),
                                                      ),
                                                    ),
                                                  ),
                                                  if (state.hasError)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 14, top: 8),
                                                      child: Text(
                                                        state.errorText!,
                                                        style: const TextStyle(
                                                          color: Colors.red,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                            validator: (value) {
                                              if (_selectedLeaseType == null) {
                                                return 'Please select a lease type';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 5,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text('Start Date *',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: blueColor)),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: CustomTextField(
                                        onTap: () async {
                                          DateTime? pickedDate =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2101),
                                            locale: const Locale('en', 'US'),
                                            builder: (BuildContext context,
                                                Widget? child) {
                                              return Theme(
                                                data:
                                                    ThemeData.light().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                    primary: Color.fromRGBO(
                                                        21,
                                                        43,
                                                        83,
                                                        1), // header background color
                                                    onPrimary: Colors
                                                        .white, // header text color
                                                    onSurface: Color.fromRGBO(
                                                        21,
                                                        43,
                                                        83,
                                                        1), // body text color
                                                  ),
                                                  textButtonTheme:
                                                      TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.white,
                                                      backgroundColor: const Color
                                                          .fromRGBO(21, 43, 83,
                                                          1), // button text color
                                                    ),
                                                  ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );

                                          if (pickedDate != null) {
                                            String formattedStartDate =
                                                "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                                            DateTime endDate = DateTime(
                                                pickedDate.year,
                                                pickedDate.month + 1,
                                                pickedDate.day);

                                            setState(() {
                                              startDateController.text =
                                                  formattedStartDate;
                                              _startDate = pickedDate;
                                            });
                                          }
                                        },
                                        readOnnly: true,
                                        suffixIcon: IconButton(
                                            onPressed: () async {
                                              DateTime? pickedDate =
                                                  await showDatePicker(
                                                context: context,
                                                initialDate: DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2101),
                                                locale:
                                                    const Locale('en', 'US'),
                                                builder: (BuildContext context,
                                                    Widget? child) {
                                                  return Theme(
                                                    data: ThemeData.light()
                                                        .copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .light(
                                                        primary: Color.fromRGBO(
                                                            21,
                                                            43,
                                                            83,
                                                            1), // header background color
                                                        onPrimary: Colors
                                                            .white, // header text color
                                                        onSurface: Color.fromRGBO(
                                                            21,
                                                            43,
                                                            83,
                                                            1), // body text color
                                                      ),
                                                      textButtonTheme:
                                                          TextButtonThemeData(
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              Colors.white,
                                                          backgroundColor:
                                                              const Color
                                                                  .fromRGBO(
                                                                  21,
                                                                  43,
                                                                  83,
                                                                  1), // button text color
                                                        ),
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );

                                              if (pickedDate != null) {
                                                String formattedStartDate =
                                                    "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                                                DateTime endDate = DateTime(
                                                    pickedDate.year,
                                                    pickedDate.month + 1,
                                                    pickedDate.day);

                                                setState(() {
                                                  startDateController.text =
                                                      formattedStartDate;
                                                  _startDate = pickedDate;
                                                });
                                              }
                                            },
                                            icon: const Icon(
                                                Icons.date_range_rounded)),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please select start date';
                                          }
                                          return null;
                                        },
                                        keyboardType: TextInputType.text,
                                        hintText: 'dd-mm-yyyy',
                                        controller: startDateController,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text('End Date *',
                                            style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: blueColor)),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: CustomTextField(
                                        onTap: () async {
                                          DateTime? pickedDate =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2101),
                                            locale: const Locale('en', 'US'),
                                            builder: (BuildContext context,
                                                Widget? child) {
                                              return Theme(
                                                data:
                                                    ThemeData.light().copyWith(
                                                  colorScheme:
                                                      const ColorScheme.light(
                                                    primary: Color.fromRGBO(
                                                        21,
                                                        43,
                                                        83,
                                                        1), // header background color
                                                    onPrimary: Colors
                                                        .white, // header text color
                                                    onSurface: Color.fromRGBO(
                                                        21,
                                                        43,
                                                        83,
                                                        1), // body text color
                                                  ),
                                                  textButtonTheme:
                                                      TextButtonThemeData(
                                                    style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.white,
                                                      backgroundColor: const Color
                                                          .fromRGBO(21, 43, 83,
                                                          1), // button text color
                                                    ),
                                                  ),
                                                ),
                                                child: child!,
                                              );
                                            },
                                          );

                                          // if (pickedDate != null) {
                                          //   // String formattedDate =
                                          //   //     "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                                          //   String formattedDate =
                                          //       "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                                          //   setState(() {
                                          //     endDateController.text =
                                          //         formattedDate;
                                          //   });
                                          // }

                                          if (pickedDate != null) {
                                            String formattedStartDate =
                                                "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";

                                            // Calculate the end date by adding one month
                                            DateTime endDate = DateTime(
                                                pickedDate.year,
                                                pickedDate.month + 1,
                                                pickedDate.day);
                                            String formattedEndDate =
                                                "${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}";

                                            setState(() {
                                              startDateController.text =
                                                  formattedStartDate;
                                              endDateController.text =
                                                  formattedEndDate; // Set the end date
                                              _startDate = pickedDate;
                                            });
                                          }
                                        },
                                        readOnnly: true,
                                        suffixIcon: IconButton(
                                            onPressed: () async {
                                              DateTime? pickedDate =
                                                  await showDatePicker(
                                                context: context,
                                                initialDate: DateTime.now(),
                                                firstDate: DateTime(2000),
                                                lastDate: DateTime(2101),
                                                locale:
                                                    const Locale('en', 'US'),
                                                builder: (BuildContext context,
                                                    Widget? child) {
                                                  return Theme(
                                                    data: ThemeData.light()
                                                        .copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .light(
                                                        primary: Color.fromRGBO(
                                                            21,
                                                            43,
                                                            83,
                                                            1), // header background color
                                                        onPrimary: Colors
                                                            .white, // header text color
                                                        onSurface: Color.fromRGBO(
                                                            21,
                                                            43,
                                                            83,
                                                            1), // body text color
                                                      ),
                                                      textButtonTheme:
                                                          TextButtonThemeData(
                                                        style: TextButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              Colors.white,
                                                          backgroundColor:
                                                              const Color
                                                                  .fromRGBO(
                                                                  21,
                                                                  43,
                                                                  83,
                                                                  1), // button text color
                                                        ),
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );

                                              // if (pickedDate != null) {
                                              //   // String formattedDate =
                                              //   //     "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                                              //   String formattedDate =
                                              //       "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";
                                              //   setState(() {
                                              //     endDateController.text =
                                              //         formattedDate;
                                              //   });
                                              // }

                                              if (pickedDate != null) {
                                                String formattedStartDate =
                                                    "${pickedDate.day.toString().padLeft(2, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.year}";

                                                // Calculate the end date by adding one month
                                                DateTime endDate = DateTime(
                                                    pickedDate.year,
                                                    pickedDate.month + 1,
                                                    pickedDate.day);
                                                String formattedEndDate =
                                                    "${endDate.day.toString().padLeft(2, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.year}";

                                                setState(() {
                                                  startDateController.text =
                                                      formattedStartDate;
                                                  endDateController.text =
                                                      formattedEndDate; // Set the end date
                                                  _startDate = pickedDate;
                                                });
                                              }
                                            },
                                            icon: const Icon(
                                                Icons.date_range_rounded)),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please select end date';
                                          }
                                          return null;
                                        },
                                        optional: true,
                                        keyboardType: TextInputType.text,
                                        hintText: 'dd-mm-yyyy',
                                        controller: endDateController,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 8,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          'Rent',
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    CustomTextField(
                                      keyboardType: TextInputType.number,
                                      hintText: 'Enter rent',
                                      controller: rent,
                                      onChanged: (value) {
                                        // Sanitize input to allow only numbers and a single decimal point
                                        String sanitizedValue = value
                                            .replaceAll(RegExp(r'[^0-9.]'), '');
                                        sanitizedValue =
                                            sanitizedValue.replaceAll(
                                                RegExp(r'(\..*?)\..*'), r'$1');

                                        // Update the rent value
                                        rent.text = sanitizedValue;

                                        // Calculate renewAmount
                                        double enteredAmount =
                                            double.tryParse(sanitizedValue) ??
                                                0.0;
                                        num existingAmount =
                                            leasesummery.data?.amount ?? 00;

                                        double renewAmount =
                                            enteredAmount - existingAmount > 0
                                                ? enteredAmount - existingAmount
                                                : 0.0;

                                        // Update your state (if you're using setState or a state management solution)
                                        setState(() {
                                          // renewLeaseData['amount'] = enteredAmount;
                                          // renewLeaseData['renewAmount'] = renewAmount;

                                          // Update Security Deposit field dynamically
                                          securitydeposit.text =
                                              renewAmount.toStringAsFixed(2);
                                        });

                                        // Move the cursor to the end of the text field
                                        rent.selection =
                                            TextSelection.fromPosition(
                                                TextPosition(
                                                    offset: rent.text.length));
                                      },
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          'Security Deposit',
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    CustomTextField(
                                      keyboardType: TextInputType.number,
                                      hintText: 'Enter Security Deposit',
                                      controller: securitydeposit,
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Text(
                                          'Upload File',
                                          style: TextStyle(
                                              color: blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 5,
                                        ),
                                        Container(
                                          height: 40,
                                          width: 140,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: blueColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                            ),
                                            onPressed: _pickPdfFiles,
                                            child: const Text('Choose Files'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            top: 8, bottom: 8),
                                        child: Column(
                                          children: _uploadedFileNames
                                              .map((fileName) {
                                            int index = _uploadedFileNames
                                                .indexOf(fileName);
                                            return ListTile(
                                              title: Text(
                                                fileName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF748097),
                                                ),
                                              ),
                                              trailing: IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _uploadedFileNames
                                                        .removeAt(index);
                                                  });
                                                },
                                                icon: const FaIcon(
                                                  FontAwesomeIcons.remove,
                                                  color: Color(0xFF748097),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 20,
                                    ),
                                    isLoading
                                        ? const Center(
                                            child: SpinKitFadingCircle(
                                              color: Colors.black,
                                              size: 50.0,
                                            ),
                                          )
                                        : hasError
                                            ? const Center(
                                                child:
                                                    Text('Failed to load data'))
                                            : Table(
                                                border:
                                                    TableBorder.all(width: 1),
                                                columnWidths: const {
                                                  0: FlexColumnWidth(2),
                                                  1: FlexColumnWidth(2),
                                                  2: FlexColumnWidth(1),
                                                },
                                                children: [
                                                  TableRow(children: [
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(8.0),
                                                      child: Center(
                                                        child: Text('Account',
                                                            style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(8.0),
                                                      child: Center(
                                                        child: Text('Amount',
                                                            style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(5.0),
                                                      child: Center(
                                                        child: Text('Actions',
                                                            style: TextStyle(
                                                                color:
                                                                    blueColor,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ),
                                                    ),
                                                  ]),
                                                  ...rows
                                                      .asMap()
                                                      .entries
                                                      .map((entry) {
                                                    int index = entry.key;
                                                    Map<String, dynamic> row =
                                                        entry.value;
                                                    return TableRow(children: [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child:
                                                            DropdownButtonHideUnderline(
                                                          child:
                                                              FormField<String>(
                                                            validator: (value) {
                                                              if (rows[index][
                                                                      'account'] ==
                                                                  null) {
                                                                return 'Please select an account';
                                                              }
                                                              return null;
                                                            },
                                                            builder:
                                                                (FormFieldState<
                                                                        String>
                                                                    state) {
                                                              String?
                                                                  selectedAccount =
                                                                  row['account'];

                                                              String?
                                                                  selectedCharge =
                                                                  row['charge_type'];
                                                              // List of all dropdown items, including missing ones
                                                              Map<
                                                                      String,
                                                                      List<
                                                                          String>>
                                                                  categorizedDataCopy =
                                                                  Map.from(
                                                                      categorizedData);

                                                              // Ensure the selected value is present in the list
                                                              if (selectedAccount !=
                                                                      null &&
                                                                  !categorizedData
                                                                      .values
                                                                      .expand(
                                                                          (list) =>
                                                                              list)
                                                                      .contains(
                                                                          selectedAccount)) {
                                                                if (categorizedDataCopy[
                                                                        'Other'] ==
                                                                    null) {
                                                                  categorizedDataCopy[
                                                                      'Other'] = [];
                                                                }
                                                                categorizedDataCopy[
                                                                        'Other']!
                                                                    .add(
                                                                        selectedAccount);
                                                              }

                                                              List<String>
                                                                  liabilityAccounts =
                                                                  [
                                                                "Late Fee Income",
                                                                "Pre-payments",
                                                              ];
                                                              String?
                                                                  surchargetype;
                                                              if (selectedCharge ==
                                                                  "Surcharge") {
                                                                for (var entry
                                                                    in categorizedData
                                                                        .entries) {
                                                                  if (entry
                                                                      .value
                                                                      .contains(
                                                                          selectedAccount)) {
                                                                    surchargetype =
                                                                        entry
                                                                            .key;
                                                                    break;
                                                                  }
                                                                }
                                                              }
                                                              bool nosurcharge =
                                                                  false;
                                                              if (row["charge_type"] ==
                                                                  "Surcharge") {

                                                                for (var entry
                                                                    in categorizedData
                                                                        .entries) {
                                                                  if (entry
                                                                      .value
                                                                      .contains(
                                                                          row['account'])) {
                                                                    surchargetype =
                                                                        entry
                                                                            .key;
                                                                  }
                                                                }
                                                                if (surchargetype ==
                                                                    "") {
                                                                  nosurcharge =
                                                                      true;
                                                                }
                                                              }

                                                              // Prepare the dropdown items
                                                              List<
                                                                      DropdownMenuItem<
                                                                          String>>
                                                                  dropdownItems =
                                                                  [
                                                                ...categorizedDataCopy
                                                                    .entries
                                                                    .expand(
                                                                        (entry) {
                                                                  return [
                                                                    // DropdownMenuItem<
                                                                    //     String>(
                                                                    //   enabled:
                                                                    //       false,
                                                                    //   child:
                                                                    //       Text(
                                                                    //     entry
                                                                    //         .key,
                                                                    //     style:
                                                                    //         const TextStyle(
                                                                    //       fontWeight:
                                                                    //           FontWeight.bold,
                                                                    //       color: Color.fromRGBO(
                                                                    //           21,
                                                                    //           43,
                                                                    //           81,
                                                                    //           1),
                                                                    //     ),
                                                                    //   ),
                                                                    // ),
                                                                    ...entry
                                                                        .value
                                                                        .map(
                                                                            (item) {
                                                                      return DropdownMenuItem<
                                                                          String>(
                                                                        value:
                                                                            "${item}_${entry.key}",
                                                                        child:
                                                                            Padding(
                                                                          padding: const EdgeInsets
                                                                              .only(
                                                                              left: 10,
                                                                              bottom: 1),
                                                                          child:
                                                                              Text(
                                                                            item,
                                                                            style:
                                                                                const TextStyle(
                                                                              color: Colors.black,
                                                                              fontWeight: FontWeight.w400,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    }).toList(),
                                                                  ];
                                                                }).toList(),
                                                                if (row['account'] !=
                                                                        null &&
                                                                    !categorizedData
                                                                        .values
                                                                        .expand(
                                                                            (v) =>
                                                                                v)
                                                                        .contains(row[
                                                                            'account']))
                                                                  DropdownMenuItem<
                                                                      String>(
                                                                    value:
                                                                        "${row['account']}_${row['charge_type']}",
                                                                    child:
                                                                        Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0.0),
                                                                      child:
                                                                          Text(
                                                                        row['account']!,
                                                                        style:
                                                                            const TextStyle(
                                                                          color:
                                                                              Colors.black,
                                                                          fontWeight:
                                                                              FontWeight.w400,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                DropdownMenuItem<
                                                                    String>(
                                                                  value:
                                                                      'button_item',
                                                                  child:
                                                                      GestureDetector(
                                                                    onTap: () {
                                                                      Navigator.pop(
                                                                          context);
                                                                      showDialog(
                                                                        context:
                                                                            context,
                                                                        builder:
                                                                            (BuildContext
                                                                                context) {
                                                                          return StatefulBuilder(builder:
                                                                              (context, setState) {
                                                                            return Dialog(
                                                                              backgroundColor: Colors.white,
                                                                              surfaceTintColor: Colors.white,
                                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                                                                              child: SingleChildScrollView(
                                                                                child: Container(
                                                                                  // height: 450,
                                                                                  child: Padding(
                                                                                    padding: const EdgeInsets.all(16.0),
                                                                                    child: Form(
                                                                                      key: _subFormKey,
                                                                                      child: Column(
                                                                                        mainAxisAlignment: MainAxisAlignment.start,
                                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                                        children: [
                                                                                          Text(
                                                                                            'Add account',
                                                                                            style: TextStyle(
                                                                                              fontSize: 16,
                                                                                              fontWeight: FontWeight.bold,
                                                                                              color: blueColor,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(
                                                                                            height: 20,
                                                                                          ),
                                                                                          Text(
                                                                                            'Account Name *',
                                                                                            style: TextStyle(
                                                                                              fontSize: 14,
                                                                                              fontWeight: FontWeight.bold,
                                                                                              color: blueColor,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 5),
                                                                                          CustomTextField(
                                                                                            validator: (value) {
                                                                                              if (value == null || value.isEmpty) {
                                                                                                return 'Please enter Account Name';
                                                                                              }
                                                                                              return null;
                                                                                            },
                                                                                            keyboardType: TextInputType.text,
                                                                                            hintText: 'Enter Account Name',
                                                                                            controller: _accountNameController,
                                                                                          ),
                                                                                          const SizedBox(height: 10),
                                                                                          Text(
                                                                                            'Account Type',
                                                                                            style: TextStyle(
                                                                                              fontSize: 14,
                                                                                              fontWeight: FontWeight.bold,
                                                                                              color: blueColor,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 5),
                                                                                          CustomDropdown(
                                                                                            validator: (value) {
                                                                                              if (_selectedAccountType == null || _selectedAccountType!.isEmpty) {
                                                                                                return 'Please select a Account Type';
                                                                                              }
                                                                                              return null;
                                                                                            },
                                                                                            labelText: 'Select Account Type',
                                                                                            items: accountTypeItems,
                                                                                            selectedValue: _selectedAccountType,
                                                                                            onChanged: (String? value) {
                                                                                              setState(() {
                                                                                                _selectedAccountType = value;
                                                                                              });
                                                                                            },
                                                                                          ),
                                                                                          const SizedBox(height: 10),
                                                                                          Text(
                                                                                            'Fund Type',
                                                                                            style: TextStyle(
                                                                                              fontSize: 14,
                                                                                              fontWeight: FontWeight.bold,
                                                                                              color: blueColor,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 5),
                                                                                          CustomDropdown(
                                                                                            validator: (value) {
                                                                                              if (_selectedFundType == null || _selectedFundType!.isEmpty) {
                                                                                                return 'Please select a Fund Type';
                                                                                              }
                                                                                              return null;
                                                                                            },
                                                                                            labelText: 'Select Fund Type',
                                                                                            items: fundTypeItems,
                                                                                            selectedValue: _selectedFundType,
                                                                                            onChanged: (String? value) {
                                                                                              setState(() {
                                                                                                _selectedFundType = value;
                                                                                              });
                                                                                            },
                                                                                          ),
                                                                                          const SizedBox(height: 10),
                                                                                          Text(
                                                                                            'Notes',
                                                                                            style: TextStyle(
                                                                                              fontSize: 14,
                                                                                              fontWeight: FontWeight.bold,
                                                                                              color: blueColor,
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(height: 5),
                                                                                          CustomTextField(
                                                                                            validator: (value) {
                                                                                              if (value == null || value.isEmpty) {
                                                                                                return 'Please enter Notes';
                                                                                              }
                                                                                              return null;
                                                                                            },
                                                                                            keyboardType: TextInputType.text,
                                                                                            hintText: 'Enter Notes',
                                                                                            controller: _notesController,
                                                                                          ),
                                                                                          const SizedBox(
                                                                                            height: 20,
                                                                                          ),
                                                                                          RichText(
                                                                                            text: TextSpan(
                                                                                              children: <TextSpan>[
                                                                                                const TextSpan(
                                                                                                  text: 'We stores this information ',
                                                                                                  style: TextStyle(
                                                                                                    fontSize: 12,
                                                                                                    fontWeight: FontWeight.bold,
                                                                                                    color: Colors.grey,
                                                                                                  ),
                                                                                                ),
                                                                                                TextSpan(
                                                                                                  text: ' Privately ',
                                                                                                  style: TextStyle(
                                                                                                    fontSize: 12,
                                                                                                    fontWeight: FontWeight.bold,
                                                                                                    color: blueColor,
                                                                                                  ),
                                                                                                ),
                                                                                                const TextSpan(
                                                                                                  text: ' and ',
                                                                                                  style: TextStyle(
                                                                                                    fontSize: 12,
                                                                                                    fontWeight: FontWeight.normal,
                                                                                                    color: Colors.grey,
                                                                                                  ),
                                                                                                ),
                                                                                                TextSpan(
                                                                                                  text: ' Securely ',
                                                                                                  style: TextStyle(
                                                                                                    fontSize: 12,
                                                                                                    fontWeight: FontWeight.bold,
                                                                                                    color: blueColor,
                                                                                                  ),
                                                                                                ),
                                                                                              ],
                                                                                            ),
                                                                                          ),
                                                                                          const SizedBox(
                                                                                            height: 20,
                                                                                          ),
                                                                                          Row(
                                                                                            mainAxisAlignment: MainAxisAlignment.end,
                                                                                            children: [
                                                                                              Container(
                                                                                                  height: 50,
                                                                                                  width: 90,
                                                                                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8.0)),
                                                                                                  child: ElevatedButton(
                                                                                                      style: ElevatedButton.styleFrom(backgroundColor: blueColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
                                                                                                      // onPressed:
                                                                                                      //     () {
                                                                                                      //   _submitSubForm(context);
                                                                                                      // },
                                                                                                      onPressed: isLoading
                                                                                                          ? null
                                                                                                          : () async {
                                                                                                        if (isLoading) return;
                                                                                                        if (_selectedAccountType == null || _accountNameController.text.isEmpty || _selectedFundType == null || _notesController.text.isEmpty) {
                                                                                                          setState(() {
                                                                                                            isError = true;
                                                                                                          });
                                                                                                        } else {
                                                                                                          setState(() {
                                                                                                            isLoading = true;
                                                                                                            isError = false;
                                                                                                          });

                                                                                                          SharedPreferences prefs = await SharedPreferences.getInstance();
                                                                                                          String? id = prefs.getString("adminId");

                                                                                                          try {
                                                                                                            await accountRepository().addAccount(
                                                                                                              adminId: id!,
                                                                                                              account: _accountNameController.text,
                                                                                                              accounttype: _selectedAccountType,
                                                                                                              fundtype: _selectedFundType,
                                                                                                              chargetype: 'One Time Charge',
                                                                                                              notes: _notesController.text,
                                                                                                            );
                                                                                                            Navigator.pop(context, true);
                                                                                                            _refreshAccounts();
                                                                                                          } catch (e) {
                                                                                                            setState(() {
                                                                                                              isError = true;
                                                                                                            });
                                                                                                          } finally {
                                                                                                            setState(() {
                                                                                                              isLoading = false;
                                                                                                            });
                                                                                                          }
                                                                                                        }
                                                                                                      },
                                                                                                      child: const Text(
                                                                                                        'Add',
                                                                                                        style: TextStyle(color: Color(0xFFf7f8f9)),
                                                                                                      ))),
                                                                                              const SizedBox(
                                                                                                width: 10,
                                                                                              ),
                                                                                              Container(
                                                                                                  height: 50,
                                                                                                  width: 94,
                                                                                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8.0)),
                                                                                                  child: ElevatedButton(
                                                                                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFffffff), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
                                                                                                      onPressed: () {
                                                                                                        setState(() {
                                                                                                          Navigator.pop(context);
                                                                                                          _selectedProperty = null;
                                                                                                        });
                                                                                                        Navigator.pop(context);
                                                                                                      },
                                                                                                      child: const Text(
                                                                                                        'Cancel',
                                                                                                        style: TextStyle(color: Color(0xFF748097)),
                                                                                                      ))),
                                                                                            ],
                                                                                          ),
                                                                                          if (isError)
                                                                                            const Padding(
                                                                                              padding: EdgeInsets.only(top: 8.0),
                                                                                              child: Text(
                                                                                                'Please fill all fields',
                                                                                                style: TextStyle(color: Colors.red),
                                                                                              ),
                                                                                            ),
                                                                                        ],
                                                                                      ),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            );
                                                                          });
                                                                        },
                                                                      );
                                                                    },
                                                                    child: const Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .start,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          '+ Add One Time Charge',
                                                                          style: TextStyle(
                                                                              fontSize: 14,
                                                                              color: Colors.black,
                                                                              fontWeight: FontWeight.w500),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ),
                                                              ];

                                                              return Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  const SizedBox(
                                                                      height:
                                                                          5),
                                                                  DropdownButton2<
                                                                      String>(
                                                                    isExpanded:
                                                                        true,
                                                                    value: row['account'] !=
                                                                            null
                                                                        ? (liabilityAccounts.contains(row['account'])
                                                                            ? "${row['account']}_Liability Account"
                                                                            : row['charge_type'] != null
                                                                                ? "${row['account']}_${row['charge_type']}"
                                                                                : null)
                                                                        : null,
                                                                    items:
                                                                        dropdownItems,
                                                                    onChanged:
                                                                        (value) {
                                                                      if (value !=
                                                                              null &&
                                                                          value !=
                                                                              'button_item') {
                                                                        setState(
                                                                            () {
                                                                          final parts =
                                                                              value.split('_');
                                                                          if (parts.length >=
                                                                              2) {
                                                                            final selectedAccount =
                                                                                parts[0];
                                                                            final selectedChargeType =
                                                                                parts.sublist(1).join('_');

                                                                            rows[index]['account'] =
                                                                                selectedAccount;
                                                                            rows[index]['charge_type'] =
                                                                                selectedChargeType;

                                                                            // Update form field state
                                                                            state.didChange(value);
                                                                          }
                                                                        });
                                                                      }
                                                                    },
                                                                    buttonStyleData:
                                                                        ButtonStyleData(
                                                                      height:
                                                                          45,
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              0,
                                                                          right:
                                                                              14),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(6),
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                      elevation:
                                                                          2,
                                                                    ),
                                                                    iconStyleData:
                                                                        const IconStyleData(
                                                                      icon: Icon(
                                                                          Icons
                                                                              .arrow_drop_down),
                                                                      iconSize:
                                                                          24,
                                                                      iconEnabledColor:
                                                                          Color(
                                                                              0xFFb0b6c3),
                                                                      iconDisabledColor:
                                                                          Colors
                                                                              .grey,
                                                                    ),
                                                                    dropdownStyleData:
                                                                        DropdownStyleData(
                                                                      width:
                                                                          250,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(6),
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                      scrollbarTheme:
                                                                          ScrollbarThemeData(
                                                                        radius: const Radius
                                                                            .circular(
                                                                            6),
                                                                        thickness:
                                                                            MaterialStateProperty.all(6),
                                                                        thumbVisibility:
                                                                            MaterialStateProperty.all(true),
                                                                      ),
                                                                    ),
                                                                    hint:
                                                                        const Padding(
                                                                      padding: EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              7,
                                                                          right:
                                                                              5,
                                                                          bottom:
                                                                              2),
                                                                      child: Text(
                                                                          'Select an account'),
                                                                    ),
                                                                  ),
                                                                  if (state
                                                                      .hasError) // Display the validation error
                                                                    Padding(
                                                                      padding: const EdgeInsets
                                                                          .only(
                                                                          left:
                                                                              16.0,
                                                                          top:
                                                                              5.0),
                                                                      child:
                                                                          Text(
                                                                        state.errorText ??
                                                                            '',
                                                                        style:
                                                                            const TextStyle(
                                                                          color:
                                                                              Colors.red,
                                                                          fontSize:
                                                                              12,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                ],
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                      Container(
                                                        margin: const EdgeInsets.only(
                                                            top: 5),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8.0),
                                                          child: SizedBox(
                                                            height: 50,
                                                            child:
                                                                KeyboardActions(
                                                              config:
                                                                  _buildConfig(
                                                                      context),
                                                              child:
                                                                  TextFormField(
                                                                initialValue: widget
                                                                            .leaseId !=
                                                                        null
                                                                    ? rows[index]
                                                                            [
                                                                            "amount"]
                                                                        .toString()
                                                                    : "0", // Make sure 0 is a string,
                                                                focusNode:
                                                                    focusNodes[
                                                                        index],
                                                                keyboardType:
                                                                    TextInputType
                                                                        .number,
                                                                textInputAction:
                                                                    TextInputAction
                                                                        .done,
                                                                onChanged: (value) =>
                                                                    updateAmount(
                                                                        index,
                                                                        value),
                                                                decoration: const InputDecoration(
                                                                    border:
                                                                        OutlineInputBorder(),
                                                                    hintText:
                                                                        'Enter amount',
                                                                    hintStyle: TextStyle(
                                                                        fontSize:
                                                                            14),
                                                                    contentPadding:
                                                                        EdgeInsets.only(
                                                                            top:
                                                                                7,
                                                                            left:
                                                                                7)),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8.0),
                                                        child: IconButton(
                                                          icon: const Icon(
                                                              Icons.delete,
                                                              color:
                                                                  Colors.red),
                                                          onPressed: () =>
                                                              deleteRow(index),
                                                        ),
                                                      ),
                                                    ]);
                                                  }).toList(),
                                                  TableRow(children: [
                                                    const Padding(
                                                      padding:
                                                          EdgeInsets.all(8.0),
                                                      child: Text('Total',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8.0),
                                                      child: Text(
                                                          formatMoney(totalAmount)),
                                                    ),
                                                    const SizedBox.shrink(),
                                                  ]),
                                                  TableRow(children: [
                                                    Padding(
                                                      padding: EdgeInsets.only(
                                                          left: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 16
                                                              : 70,
                                                          right: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width <
                                                                  500
                                                              ? 16
                                                              : 70,
                                                          top: 10,
                                                          bottom: 10),
                                                      child: Container(
                                                        height: 40,
                                                        width: 100,
                                                        decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            border: Border.all(
                                                                width: 1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        5.0)),
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                              shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              5.0)),
                                                              elevation: 0,
                                                              backgroundColor:
                                                                  Colors.white),
                                                          onPressed: addRow,
                                                          child: Text(
                                                            'Add Row',
                                                            style: TextStyle(
                                                              fontSize: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width <
                                                                      500
                                                                  ? 14
                                                                  : 18,
                                                              color: blueColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox.shrink(),
                                                    const SizedBox.shrink(),
                                                  ]),
                                                ],
                                              ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  List<Map<String, dynamic>> entries =
                                      rows.map((element) {
                                    return {
                                      "account": element["account"],
                                      "amount": element["amount"],
                                      //  "charge_type": 'One Time Charge',
                                      "charge_type":
                                          (element["account"] == "" ||
                                                  element["account"] ==
                                                      "Late Fee Income" ||
                                                  element["account"] ==
                                                      "Pre-payments")
                                              ? element["account"]
                                              : "One Time Charge",
                                      //  "charge_type": element["charge_type"],
                                      "memo": element["memo"]
                                    };
                                  }).toList();

                                  Map<String, dynamic> charge = {
                                    "lease_id": widget.leaseId,
                                    "admin_id": leasesummery.data!.adminId,
                                    //  "type": "One Time Charge",
                                    //  "type": "Charge",
                                    "total_amount": totalAmount,
                                    "entry": entries.length > 0
                                        ? entries
                                        : [
                                            {
                                              "account": "",
                                              "amount": "",
                                              "charge_type": "",
                                              "memo": ""
                                            }
                                          ]
                                  };

                                  // Debug: Print the date values before formatting

                                  // Validate that dates are not empty
                                  if (startDateController.text.trim().isEmpty ||
                                      endDateController.text.trim().isEmpty) {
                                    Fluttertoast.showToast(
                                        msg:
                                            "Please select both start and end dates");
                                    return;
                                  }

                                  Map<String, dynamic> leasedata = {
                                    "lease_id": widget.leaseId,
                                    "tenant_id":
                                        leasesummery.data?.tenantData != null &&
                                                leasesummery.data!.tenantData!
                                                    .isNotEmpty
                                            ? leasesummery.data!.tenantData!
                                                .first.tenantId
                                            : "",
                                    "renewAmount": widget.rentamount,
                                    "admin_id": leasesummery.data!.adminId,
                                    "lease_type": leasesummery.data!.leaseType,
                                    "start_date": startDateController.text
                                            .trim()
                                            .isNotEmpty
                                        ? reverseFormatDate(
                                            startDateController.text.trim())
                                        : "",
                                    "end_date":
                                        endDateController.text.trim().isNotEmpty
                                            ? reverseFormatDate(
                                                endDateController.text.trim())
                                            : "",
                                    "amount": rent.text.trim(), // new amount
                                    "renewAmount": securitydeposit.text
                                        .trim(), // new amount
                                    "lease_amount": widget.rentamount,
                                    "charges": charge,
                                    "renew_fileName":
                                        _uploadedFileNames.length > 0
                                            ? _uploadedFileNames.first
                                            : "",
                                  };

                                  // Debug: Print the final lease data
                                  updatenewrenewallease(leasedata);
                                },
                                child: Container(
                                    height:
                                        MediaQuery.of(context).size.width < 500
                                            ? 40
                                            : 45,
                                    width:
                                        MediaQuery.of(context).size.width < 500
                                            ? 90
                                            : 150,
                                    decoration: BoxDecoration(
                                        color: blueColor,
                                        borderRadius:
                                            BorderRadius.circular(5.0)),
                                    child: Center(
                                      child: Text(
                                        'Ok',
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 16
                                                : 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    )),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: Container(
                                    height:
                                        MediaQuery.of(context).size.width < 500
                                            ? 35
                                            : 45,
                                    width:
                                        MediaQuery.of(context).size.width < 500
                                            ? 120
                                            : 165,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(5.0)),
                                    child: Center(
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                            fontSize: MediaQuery.of(context)
                                                        .size
                                                        .width <
                                                    500
                                                ? 16
                                                : 18,
                                            fontWeight: FontWeight.bold,
                                            color: blueColor),
                                      ),
                                    )),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  bool determineStatus(String? startDate, String? endDate) {
    if (startDate == null || endDate == null) return false;

    DateTime start = formatDates(startDate);
    DateTime end = formatDates(endDate);
    DateTime today = DateTime.now();
    if (today.isAfter(end)) {
      return true;
    } else {
      return false;
    }
  }
}
