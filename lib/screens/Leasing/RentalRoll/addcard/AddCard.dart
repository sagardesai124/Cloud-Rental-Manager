import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:keyboard_actions/keyboard_actions.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/collectjs_card_field.dart';

import 'CardModel.dart';
import 'Service.dart';
import '../../../../widgets/custom_drawer.dart';

class AddCard extends StatefulWidget {
  final String leaseId;

  /// When set (e.g. opened from tenant summary), selects this tenant and merges `tenant_details` for name/email/phone.
  final String? initialTenantId;

  /// Staff module: use `staff_id` in the `id` header (admin_id in bodies stays from prefs).
  final bool useStaffIdHeader;

  AddCard({
    required this.leaseId,
    this.initialTenantId,
    this.useStaffIdHeader = false,
  });

  @override
  State<AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<AddCard> {
  TextEditingController cardNumber = TextEditingController();
  TextEditingController expirationDate = TextEditingController();
  TextEditingController firstName = TextEditingController();
  TextEditingController lastName = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController phoneNumber = TextEditingController();
  TextEditingController address = TextEditingController();
  TextEditingController city = TextEditingController();
  TextEditingController state = TextEditingController();
  TextEditingController country = TextEditingController();
  TextEditingController zip = TextEditingController();
  TextEditingController cvv = TextEditingController();
  String? _selectedExpiringMonth;
  String? _selectedExpiringYear;
  List<String> expiringMonth = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12'
  ];
  List<String> expiringYear =
      List.generate(12, (index) => (2024 + index).toString());
  String yearmessage = "";
  bool yearerror = false;
  String carderrorMessage = '';

  void _validateInput() {
    setState(() {
      String input = cardNumber.text.trim();
      if (input.isEmpty) {
        carderrorMessage = 'This field cannot be empty';
      } else if (input.length > 16) {
        carderrorMessage = 'Card number cannot be more than 16 digits';
      } else if (!isValidLuhn(input)) {
        carderrorMessage = 'Invalid card number';
      } else {
        carderrorMessage = '';
      }
    });
  }

  final _formKey = GlobalKey<FormState>();

  String? messageCardAvailable;

  List<Map<String, String>> tenants = [];
  bool isLoading = false;
  String? selectedTenantId;
  int? customervaultid;
  List<BillingData> cardDetails = [];
  // PCI tokenization (Collect.js) — replaces the raw card fields on this screen.
  final CollectJsController _cardCtrl = CollectJsController();
  String? _publicKey;
  bool _cardReady = false;
  bool _submitting = false;
  // Strict gate: track each Collect.js card field's validity so the Add Card
  // button stays disabled until the card itself is validly entered.
  final Map<String, bool> _cardValidity = {};
  bool get _cardValid =>
      (_cardValidity['ccnumber'] ?? false) &&
      (_cardValidity['ccexp'] ?? false) &&
      (_cardValidity['cvv'] ?? false);
  String? _adminId; // company admin_id captured from the lease_tenant response
  // Web parity (AddCardForm.jsx): submit stays disabled until the required
  // native fields are filled (Collect.js card fields validate on submit).
  bool get _requiredFieldsFilled =>
      firstName.text.trim().isNotEmpty &&
      lastName.text.trim().isNotEmpty &&
      email.text.trim().isNotEmpty &&
      phoneNumber.text.trim().isNotEmpty;

  void _onRequiredChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    firstName.addListener(_onRequiredChanged);
    lastName.addListener(_onRequiredChanged);
    email.addListener(_onRequiredChanged);
    phoneNumber.addListener(_onRequiredChanged);
    fetchTenants();
  }

  bool _tapToPayEnabled = false;
  String? _cardId;

  String _crmHeaderId(SharedPreferences prefs) {
    if (widget.useStaffIdHeader) {
      return prefs.getString('staff_id') ?? prefs.getString('adminId') ?? '';
    }
    return prefs.getString('adminId') ?? '';
  }

  Future<void> _mergeTenantDetailsIntoForm(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final idHeader = _crmHeaderId(prefs);
    final response = await apiGet(
      Uri.parse('$Api_url/api/tenant/tenant_details/$tenantId'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $idHeader",
      },
    );
    if (response.statusCode != 200 || !mounted) return;
    final body = jsonDecode(response.body);
    final list = body['data'];
    if (list is! List || list.isEmpty) return;
    final d = list.first;
    if (d is! Map<String, dynamic>) return;
    setState(() {
      final fn = d['tenant_firstName']?.toString();
      final ln = d['tenant_lastName']?.toString();
      final em = d['tenant_email']?.toString();
      final ph = d['tenant_phoneNumber']?.toString();
      if (fn != null && fn.isNotEmpty) firstName.text = fn;
      if (ln != null && ln.isNotEmpty) lastName.text = ln;
      if (em != null && em.isNotEmpty) email.text = em;
      if (ph != null && ph.isNotEmpty) {
        phoneNumber.text = formatPhoneNumberedit(ph);
      }
    });
  }

  Future<void> fetchTenants() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = _crmHeaderId(prefs);
    String? token = prefs.getString('token');
    // print("token $token"); // removed: do not log auth token
    final response = await apiGet(
      Uri.parse('$Api_url/api/leases/lease_tenant/${widget.leaseId}'),
      headers: {"id": "CRM $id", "authorization": "CRM $token"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<Map<String, String>> fetchedTenants = [];
      for (var tenant in data['data']['tenants']) {
        fetchedTenants.add({
          'tenant_id': tenant['tenant_id'],
          'tenant_name':
              '${tenant['tenant_firstName']} ${tenant['tenant_lastName']}',
          'tenant_firstname': '${tenant['tenant_firstName']}',
          'tenant_lastName': '${tenant['tenant_lastName']}',
          'tenant_email': '${tenant['tenant_email']}',
          'tenant_phoneNumber': '${tenant['tenant_phoneNumber']}',
          'rental_adress': "${data['data']['rental_adress']}",
          'rental_city': "${data['data']['rental_city']}",
          'rental_state': "${data['data']['rental_state']}",
          'rental_country': "${data['data']['rental_country']}",
          'rental_zip': "${data['data']['rental_zip']}",
          'tenant_firstName': '${tenant['tenant_firstName']}',
          'tenant_lastName': '${tenant['tenant_lastName']}',
          'tenant_email': '${tenant['tenant_email']}',
          'tenant_phoneNumber':
              formatPhoneNumberedit('${tenant['tenant_phoneNumber']}'),
          'rental_adress': "${data['data']['rental_adress']}",
          'rental_city': "${data['data']['rental_city']}",
          'rental_state': "${data['data']['rental_state']}",
          'rental_country': "${data['data']['rental_country']}",
          'rental_zip': "${data['data']['rental_zip']}",
        });
      }
      setState(() {
        tenants = fetchedTenants;
        showmessage = false;
        _adminId = data['data']['admin_id']?.toString();
      });
      _fetchTokenizationKey();
      Map<String, String>? preferred;
      final wantId = widget.initialTenantId;
      if (wantId != null && wantId.isNotEmpty) {
        for (final t in fetchedTenants) {
          if (t['tenant_id'] == wantId) {
            preferred = t;
            break;
          }
        }
      }
      if (preferred != null && wantId != null && wantId.isNotEmpty) {
        setTenantFormData(preferred);
        await _mergeTenantDetailsIntoForm(wantId);
      } else if (fetchedTenants.isNotEmpty) {
        setTenantFormData(fetchedTenants.first);
      }
    } else {
      throw Exception('Failed to load tenants');
    }
  }

  Future<void> _fetchTokenizationKey() async {
    final adminId =
        _adminId ?? (await SharedPreferences.getInstance()).getString('adminId');
    if (adminId == null || adminId.isEmpty) return;
    final key = await AddCardService(useStaffIdHeader: widget.useStaffIdHeader)
        .getTokenizationKeyByAdmin(adminId);
    if (!mounted) return;
    setState(() => _publicKey = key);
  }

  Future<void> _saveTokenizedCard(CardToken card) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = _adminId ?? prefs.getString('adminId');
    final tenantId = selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      Fluttertoast.showToast(msg: 'Please select a tenant first.');
      setState(() => _submitting = false);
      return;
    }
    if (adminId == null || adminId.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Unable to determine account. Please reopen and retry.');
      setState(() => _submitting = false);
      return;
    }
    if (firstName.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        phoneNumber.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: 'Please fill name, email, and phone.');
      setState(() => _submitting = false);
      return;
    }
    setState(() => isLoading = true);
    String company = '';
    try {
      company = await fetchCompanyName(adminId);
    } catch (_) {}
    final result =
        await AddCardService(useStaffIdHeader: widget.useStaffIdHeader)
            .saveTokenizedCard(
      paymentToken: card.token,
      ccBin: card.bin,
      ccExp: card.exp,
      firstName: firstName.text,
      lastName: lastName.text,
      email: email.text,
      phone: phoneNumber.text,
      address1: address.text,
      city: city.text,
      state: state.text,
      zip: zip.text,
      country: country.text,
      company: company,
      adminId: adminId,
      tenantId: tenantId,
    );
    if (!mounted) return;
    setState(() {
      isLoading = false;
      _submitting = false;
    });
    if (result.success) {
      Fluttertoast.showToast(msg: 'Add Card Successfully');
      Navigator.pop(context, true); // return true so the caller refreshes the list
    } else {
      Fluttertoast.showToast(msg: result.message ?? 'Failed to add card.');
    }
  }

  void setTenantFormData(Map<String, String> tenantData) {
    address.text = tenantData['rental_adress']!;
    selectedTenantId = tenantData['tenant_id'];
    firstName.text = tenantData['tenant_firstName']!;
    lastName.text = tenantData['tenant_lastName']!;
    email.text = tenantData['tenant_email']!;
    phoneNumber.text = tenantData['tenant_phoneNumber']!;
    city.text = tenantData['rental_city']!;
    state.text = tenantData['rental_state']!;
    country.text = tenantData['rental_country']!;
    zip.text = tenantData['rental_zip']!;
    fetchcreditcard(selectedTenantId!);
  }

  Future<String> fetchCompanyName(String adminId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    String? id = _crmHeaderId(prefs);
    final String apiUrl = '${Api_url}/api/admin/admin_profile/$adminId';

    try {
      final http.Response response = await apiGet(
        Uri.parse(apiUrl),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $id",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        // Check if company_name exists in response and is not null
        if (data.containsKey('data') &&
            data['data'] != null &&
            data['data']['company_name'] != null) {
          return data['data']['company_name'].toString();
        } else {
          throw Exception('Company name not found in response');
        }
      } else {
        throw Exception(
            'Failed to fetch company name. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch company name: $e');
    }
  }

  Future<void> fetchcreditcard(String tenantId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = _crmHeaderId(prefs);
    String? token = prefs.getString('token');

    setState(() {
      isLoading = true;
      cardDetails = []; // Clear previous card details
    });

    try {
      final response = await apiGet(
        Uri.parse('$Api_url/api/creditcard/getCreditCards/$tenantId'),
        headers: {"id": "CRM $id", "authorization": "CRM $token"},
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        customervaultid = jsonResponse['customer_vault_id'];
        final rawDetail = jsonResponse['card_detail'];
        final List<dynamic> cardDetailsList =
            rawDetail is List ? List<dynamic>.from(rawDetail) : <dynamic>[];

        CustomerData? customerData = await postBillingCustomerVault(
            customervaultid.toString(), cardDetailsList);

        // Vault can include ACH / extra rows not present in card_detail; only list
        // saved cards (masked cc_number) so indices never mismatch UI expectations.
        // customerData == null means an empty vault (no cards yet) -> show the
        // "no card" state instead of leaving the spinner running.
        final cardsOnly = customerData == null
            ? <BillingData>[]
            : customerData.billing.where((b) {
                final cn = b.ccNumber?.trim() ?? '';
                return cn.isNotEmpty;
              }).toList();
        setState(() {
          cardDetails = cardsOnly;
          messageCardAvailable =
              cardsOnly.isEmpty ? 'No card found for this tenant' : '';
        });
      } else if (response.statusCode == 404) {
        setState(() {
          messageCardAvailable = 'No card found for this tenant';
        });
      } else {
        setState(() {
          messageCardAvailable = 'Failed to load cards';
        });
      }
    } catch (e) {
      setState(() {
        messageCardAvailable = 'Failed to load cards';
      });
    } finally {
      // Always stop the spinner, even if parsing/network throws.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<CustomerData?> postBillingCustomerVault(
      String customerVaultId, List<dynamic> cardDetailsList) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final idHeader = _crmHeaderId(prefs);

    Map<String, String> requestBody = {
      "customer_vault_id": customerVaultId,
      "admin_id": adminId.toString(),
    };

    final response = await apiPost(
      Uri.parse('$Api_url/api/nmipayment/get-billing-customer-vault'),
      headers: {
        'Content-Type': 'application/json',
        "id": "CRM $idHeader",
        "authorization": "CRM $token",
      },
      body: json.encode(requestBody),
    );
    if (response.statusCode == 200) {
      var jsonResponse = json.decode(response.body);
      final customerJson = jsonResponse['data']?['customer'];
      if (customerJson is! Map<String, dynamic>) {
        // Empty vault / no customer record yet -> treat as no cards
        // instead of crashing on CustomerData.fromJson(null).
        return null;
      }
      CustomerData customerData = CustomerData.fromJson(customerJson);

      final Map<String, String> cardTypeByBillingId = {};
      for (final raw in cardDetailsList) {
        if (raw is Map) {
          final bid = raw['billing_id']?.toString();
          final ct = raw['card_type']?.toString();
          if (bid != null && bid.isNotEmpty && ct != null && ct.isNotEmpty) {
            cardTypeByBillingId[bid] = ct;
          }
        }
      }
      for (final billing in customerData.billing) {
        final id = billing.billingId?.toString();
        if (id != null && cardTypeByBillingId.containsKey(id)) {
          billing.binResult = cardTypeByBillingId[id];
        } else {
          final hasCardNumber = (billing.ccNumber?.trim().isNotEmpty ?? false);
          billing.binResult = hasCardNumber
              ? (billing.ccType ?? 'CREDIT')
              : (billing.ccType ?? 'ACH');
        }
      }

      return customerData;
    } else {
      return null;
    }
  }

  Future<void> deleteCardaction(
      BillingData billingData, String customervaultid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");

    cardModelFordelete cardmodelfordelete = cardModelFordelete(
      adminId: id,
      billingId: billingData.billingId,
      customerVaultId: customervaultid,
    );

    if (cardDetails.length == 1) {
      AddCardService apiService =
          AddCardService(useStaffIdHeader: widget.useStaffIdHeader);
      int deleteResponse =
          await apiService.deleteOneCardDelete(customervaultid);

      if (deleteResponse == 200) {
        await apiService.deleteOneCardfromdatabase(
            customervaultid, selectedTenantId);
        setState(() {
          cardDetails
              .remove(billingData); // Remove the deleted card from the list
        });
      } else {
        // Handle the error case
      }
    } else {
      AddCardService apiService =
          AddCardService(useStaffIdHeader: widget.useStaffIdHeader);
      int deleteResponse = await apiService.deleteCard(cardmodelfordelete);

      if (deleteResponse == 200) {
        await apiService.deletefromdatabaseCard(
            billingData.billingId.toString(), selectedTenantId);
        setState(() {
          cardDetails
              .remove(billingData); // Remove the deleted card from the list
        });
      } else {
        // Handle the error case
      }
    }
    fetchcreditcard(selectedTenantId!);
  }

  String _formatCardNumber(String cardNumber) {
    if (cardNumber.length != 16) {
      return cardNumber;
    }

    String maskedNumber = '';
    maskedNumber += cardNumber.substring(0, 1);

    for (int i = 1; i < cardNumber.length - 4; i++) {
      if (i % 4 == 0) {
        maskedNumber += ' ';
      }
      maskedNumber += 'x';
    }

    maskedNumber += ' ' + cardNumber.substring(cardNumber.length - 4);
    return maskedNumber;
  }

  bool isValidLuhn(String number) {
    int sum = 0;
    bool alternate = false;

    for (int i = number.length - 1; i >= 0; i--) {
      int n = int.parse(number[i]);

      if (alternate) {
        n *= 2;
        if (n > 9) {
          n -= 9;
        }
      }

      sum += n;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  String _nfcData = "";

  String generateRandomNumber(int length) {
    String randomNumber = "";
    for (int i = 0; i < length; i++) {
      randomNumber += (Random().nextInt(9) + 1).toString();
    }
    return randomNumber;
  }

  bool showmessage = true;
  String? errorMessageDropdown = 'Please select any one Tenant.';

  String? _errorMessage;
  String? _cardNumberError;
  String? _cvvError;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: "Leases",
        dropdown: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isTablet = constraints.maxWidth > 600;
          return isTablet
              ? SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 5,
                      top: 30,
                    ),
                    child: Wrap(
                        alignment: WrapAlignment.start,
                        spacing: MediaQuery.of(context).size.width * 0.03,
                        runSpacing: MediaQuery.of(context).size.width * 0.035,
                        children: [
                          SingleChildScrollView(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                //crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16, right: 16, top: 16),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(5.0),
                                      child: Container(
                                        height: 50.0,
                                        padding: const EdgeInsets.only(
                                            top: 10, left: 10),
                                        width:
                                            MediaQuery.of(context).size.width *
                                                .99,
                                        margin:
                                            const EdgeInsets.only(bottom: 6.0),
                                        //Same as `blurRadius` i guess
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
                                        child: const Text(
                                          "Add Card",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5.0),
                                    child: Row(
                                      // mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // First Column
                                        Expanded(
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(left: 10),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                showmessage
                                                    ? Text(
                                                        '${errorMessageDropdown.toString()}',
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.red))
                                                    : Container(),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Received From *',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                tenants.isEmpty
                                                    ? const Center(
                                                        child:
                                                            SpinKitSpinningLines(
                                                          color: Colors.black,
                                                          size: 55.0,
                                                        ),
                                                      )
                                                    : DropdownButtonHideUnderline(
                                                        child:
                                                            DropdownButtonFormField2<
                                                                String>(
                                                          decoration:
                                                              const InputDecoration(
                                                                  border:
                                                                      InputBorder
                                                                          .none),
                                                          validator: (value) {
                                                            if (value == null ||
                                                                value.isEmpty) {
                                                              return 'Please select resident';
                                                            }
                                                            return null;
                                                          },
                                                          isExpanded: true,
                                                          hint: const Text(
                                                              'Select Resident'),
                                                          value:
                                                              selectedTenantId,
                                                          items: tenants
                                                              .map((tenant) {
                                                            return DropdownMenuItem<
                                                                String>(
                                                              value: tenant[
                                                                  'tenant_id'],
                                                              child: Text(tenant[
                                                                  'tenant_name']!),
                                                            );
                                                          }).toList(),
                                                          onChanged: (value) {
                                                            setState(() {
                                                              selectedTenantId =
                                                                  value;
                                                              showmessage =
                                                                  false;
                                                              final selectedTenant =
                                                                  tenants.firstWhere(
                                                                      (tenant) =>
                                                                          tenant[
                                                                              'tenant_id'] ==
                                                                          value);
                                                              firstName.text =
                                                                  selectedTenant[
                                                                      'tenant_firstName']!;
                                                              lastName.text =
                                                                  selectedTenant[
                                                                      'tenant_lastName']!;
                                                              firstName.text =
                                                                  selectedTenant[
                                                                      'tenant_firstname']!;
                                                              lastName.text =
                                                                  selectedTenant[
                                                                      'tenant_lastName']!;
                                                              email.text =
                                                                  selectedTenant[
                                                                      'tenant_email']!;
                                                              phoneNumber.text =
                                                                  selectedTenant[
                                                                      'tenant_phoneNumber']!;
                                                              address.text =
                                                                  selectedTenant[
                                                                      'rental_adress']!;
                                                              city.text =
                                                                  selectedTenant[
                                                                      'rental_city']!;
                                                              state.text =
                                                                  selectedTenant[
                                                                      'rental_state']!;
                                                              country.text =
                                                                  selectedTenant[
                                                                      'rental_country']!;
                                                              zip.text =
                                                                  selectedTenant[
                                                                      'rental_zip']!;
                                                            });

                                                            fetchcreditcard(
                                                                value!);
                                                          },
                                                          buttonStyleData:
                                                              ButtonStyleData(
                                                            height: 45,
                                                            width:
                                                                double.infinity,
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 14,
                                                                    right: 14),
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            elevation: 2,
                                                          ),
                                                          iconStyleData:
                                                              const IconStyleData(
                                                            icon: Icon(
                                                              Icons
                                                                  .arrow_drop_down,
                                                            ),
                                                            iconSize: 24,
                                                            iconEnabledColor:
                                                                Color(
                                                                    0xFFb0b6c3),
                                                            iconDisabledColor:
                                                                Colors.grey,
                                                          ),
                                                          dropdownStyleData:
                                                              DropdownStyleData(
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                            scrollbarTheme:
                                                                ScrollbarThemeData(
                                                              radius:
                                                                  const Radius
                                                                      .circular(
                                                                      6),
                                                              thickness:
                                                                  MaterialStateProperty
                                                                      .all(6),
                                                              thumbVisibility:
                                                                  MaterialStateProperty
                                                                      .all(
                                                                          true),
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
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                // (Collect.js card field moved to the end — see after Country.)
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('First Name *',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter First Name',
                                                  controller: firstName,
                                                  optional: true,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Last Name *',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter Last Name',
                                                  controller: lastName,
                                                  optional: true,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Email *',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter Email',
                                                  controller: email,
                                                  email: true,
                                                  optional: true,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Phone Number *',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.number,
                                                  formatter: [
                                                    FilteringTextInputFormatter
                                                        .digitsOnly,
                                                    LengthLimitingTextInputFormatter(
                                                        10),
                                                    PhoneNumberFormatter(),
                                                  ],
                                                  // keyboardType: TextInputType.numberWithOptions(signed: true,decimal: true),
                                                  hintText:
                                                      'Enter Phone Number',
                                                  controller: phoneNumber,
                                                  phone: true,
                                                  optional: true,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Address',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter Address',
                                                  controller: address,
                                                  optional: true,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('City',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter City',
                                                  controller: city,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('State',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter State',
                                                  controller: state,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Zip',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  formatter: [
                                                    FilteringTextInputFormatter
                                                        .allow(RegExp(
                                                            r'[a-zA-Z0-9]')),
                                                    TextInputFormatter
                                                        .withFunction((oldValue,
                                                            newValue) {
                                                      return TextEditingValue(
                                                        text: newValue.text
                                                            .toUpperCase(),
                                                        selection:
                                                            newValue.selection,
                                                      );
                                                    }),
                                                  ],
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter Zip',
                                                  controller: zip,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                const Text('Country',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.grey)),
                                                CustomTextField(
                                                  keyboardType:
                                                      TextInputType.text,
                                                  hintText: 'Enter Country',
                                                  controller: country,
                                                ),
                                                const SizedBox(
                                                  height: 8,
                                                ),
                                                // PCI: secure Collect.js card field — placed at the END of the form, matching web.
                                                CollectJsCardField(
                                                  publicKey: _publicKey,
                                                  controller: _cardCtrl,
                                                  onReady: () => setState(() =>
                                                      _cardReady = true),
                                                  onToken: (t) =>
                                                      _saveTokenizedCard(t),
                                                  onError: (msg) {
                                                    if (mounted) {
                                                      setState(() =>
                                                          _submitting = false);
                                                    }
                                                    Fluttertoast.showToast(
                                                        msg: msg);
                                                  },
                                                  onValidation:
                                                      (field, valid, message) {
                            setState(() => _cardValidity[field] = valid);
                                                    if (!valid && _submitting) {
                                                      setState(() =>
                                                          _submitting = false);
                                                      Fluttertoast.showToast(
                                                          msg: message.isNotEmpty
                                                              ? message
                                                              : 'Please enter valid card details.');
                                                    }
                                                  },
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        // Second Column
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              selectedTenantId == null
                                                  ? Container()
                                                  : Padding(
                                                      padding: EdgeInsets.only(
                                                          left: 10.0, top: 10),
                                                      child: Text('Cards',
                                                          style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  blueColor)),
                                                    ),
                                              selectedTenantId == null
                                                  ? Container()
                                                  : const SizedBox(height: 8),
                                              selectedTenantId == null
                                                  ? Container()
                                                  : isLoading
                                                      ? const Center(
                                                          child:
                                                              SpinKitFadingCircle(
                                                            color: Colors.black,
                                                            size: 55.0,
                                                          ),
                                                        )
                                                      : cardDetails.isEmpty
                                                          ? Center(
                                                              child: Text(
                                                                  messageCardAvailable ??
                                                                      'No card details available'),
                                                            )
                                                          : ListView.builder(
                                                              shrinkWrap: true,
                                                              physics:
                                                                  const NeverScrollableScrollPhysics(),
                                                              itemCount:
                                                                  cardDetails
                                                                      .length,
                                                              itemBuilder:
                                                                  (context,
                                                                      index) {
                                                                return Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: _buildCreditCard(
                                                                          cardDetails[
                                                                              index],
                                                                          customervaultid
                                                                              .toString()),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 5,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 5,
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            ),
                                              SizedBox(height: 5),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 16.0, bottom: 18.0, top: 10),
                                    child: Row(
                                      children: [
                                        Container(
                                            height: 42,
                                            width: 110,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8.0)),
                                            child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: blueColor,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0))),
                                                onPressed: (!_requiredFieldsFilled || !_cardValid ||
                                                        _submitting)
                                                    ? null
                                                    : () {
                                                        // PCI: tokenize in the WebView; the save runs in CollectJsCardField.onToken -> _saveTokenizedCard.
                                                        if (!_cardReady) {
                                                          Fluttertoast.showToast(
                                                              msg:
                                                                  'Card fields are still loading…');
                                                          return;
                                                        }
                                                        if (!(_formKey
                                                                .currentState
                                                                ?.validate() ??
                                                            true)) {
                                                          Fluttertoast.showToast(
                                                              msg:
                                                                  'Form is invalid. Please check the details.');
                                                          return;
                                                        }
                                                        setState(() =>
                                                            _submitting = true);
                                                        _cardCtrl.tokenize();
                                                      },
                                                child: _submitting
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Colors
                                                                    .white),
                                                      )
                                                    : const Text(
                                                        'Add Card',
                                                        style: TextStyle(
                                                            color: Color(
                                                                0xFFf7f8f9)),
                                                      ))),
                                        const SizedBox(
                                          width: 8,
                                        ),
                                        Container(
                                            height: 42,
                                            width: 100,
                                            decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8.0)),
                                            child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFffffff),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0))),
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: const Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                      color: Color(0xFF748097)),
                                                )))
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: MediaQuery.of(context).size.width * 0.03,
                      runSpacing: MediaQuery.of(context).size.width * 0.02,
                      children: [
                        SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 16, top: 16),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(5.0),
                                    child: Container(
                                      height: 50.0,
                                      padding: const EdgeInsets.only(
                                          top: 10, left: 10),
                                      width: MediaQuery.of(context).size.width *
                                          .94,
                                      margin:
                                          const EdgeInsets.only(bottom: 6.0),
                                      //Same as `blurRadius` i guess
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
                                      child: const Text(
                                        "Add Card",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Container(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        showmessage
                                            ? Text(
                                                '${errorMessageDropdown.toString()}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red))
                                            : Container(),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Received From *',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        tenants.isEmpty
                                            ? const Center(
                                                child: SpinKitFadingCircle(
                                                  color: Colors.black,
                                                  size: 55.0,
                                                ),
                                              )
                                            : DropdownButtonHideUnderline(
                                                child: DropdownButtonFormField2<
                                                    String>(
                                                  decoration:
                                                      const InputDecoration(
                                                          border:
                                                              InputBorder.none),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Please select resident';
                                                    }
                                                    return null;
                                                  },
                                                  isExpanded: true,
                                                  hint: const Text(
                                                      'Select Resident'),
                                                  value: selectedTenantId,
                                                  items: tenants.map((tenant) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value:
                                                          tenant['tenant_id'],
                                                      child: Text(tenant[
                                                          'tenant_name']!),
                                                    );
                                                  }).toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      selectedTenantId = value;
                                                      showmessage = false;
                                                      final selectedTenant =
                                                          tenants.firstWhere(
                                                              (tenant) =>
                                                                  tenant[
                                                                      'tenant_id'] ==
                                                                  value);
                                                      firstName.text =
                                                          selectedTenant[
                                                              'tenant_firstName']!;
                                                      lastName.text =
                                                          selectedTenant[
                                                              'tenant_lastName']!;
                                                      email.text =
                                                          selectedTenant[
                                                              'tenant_email']!;
                                                      phoneNumber.text =
                                                          selectedTenant[
                                                              'tenant_phoneNumber']!;
                                                      address.text =
                                                          selectedTenant[
                                                              'rental_adress']!;
                                                      city.text =
                                                          selectedTenant[
                                                              'rental_city']!;
                                                      state.text =
                                                          selectedTenant[
                                                              'rental_state']!;
                                                      country.text =
                                                          selectedTenant[
                                                              'rental_country']!;
                                                      zip.text = selectedTenant[
                                                          'rental_zip']!;
                                                    });
                                                    // Get the selected tenant
                                                    final selectedTenant = tenants
                                                        .firstWhere((tenant) =>
                                                            tenant[
                                                                'tenant_id'] ==
                                                            value);
                                                    // Update the text controllers with the selected tenant's values
                                                    firstName.text =
                                                        selectedTenant[
                                                            'tenant_firstname']!;
                                                    lastName.text =
                                                        selectedTenant[
                                                            'tenant_lastName']!;
                                                    email.text = selectedTenant[
                                                        'tenant_email']!;
                                                    phoneNumber.text =
                                                        selectedTenant[
                                                            'tenant_phoneNumber']!;
                                                    address.text =
                                                        selectedTenant[
                                                            'rental_adress']!;
                                                    city.text = selectedTenant[
                                                        'rental_city']!;
                                                    state.text = selectedTenant[
                                                        'rental_state']!;
                                                    country.text =
                                                        selectedTenant[
                                                            'rental_country']!;
                                                    zip.text = selectedTenant[
                                                        'rental_zip']!;

                                                    fetchcreditcard(value!);
                                                  },
                                                  buttonStyleData:
                                                      ButtonStyleData(
                                                    height: 45,
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.only(
                                                            left: 14,
                                                            right: 14),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      color: Colors.white,
                                                    ),
                                                    elevation: 2,
                                                  ),
                                                  iconStyleData:
                                                      const IconStyleData(
                                                    icon: Icon(
                                                      Icons.arrow_drop_down,
                                                    ),
                                                    iconSize: 24,
                                                    iconEnabledColor:
                                                        Color(0xFFb0b6c3),
                                                    iconDisabledColor:
                                                        Colors.grey,
                                                  ),
                                                  dropdownStyleData:
                                                      DropdownStyleData(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      color: Colors.white,
                                                    ),
                                                    scrollbarTheme:
                                                        ScrollbarThemeData(
                                                      radius:
                                                          const Radius.circular(
                                                              6),
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
                                                    padding: EdgeInsets.only(
                                                        left: 14, right: 14),
                                                  ),
                                                ),
                                              ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        // (Collect.js card field moved to the end — see after Country.)
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        const Text('First Name *',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter First Name',
                                          controller: firstName,
                                          optional: true,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Last Name *',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter Last Name',
                                          controller: lastName,
                                          optional: true,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Email *',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter Email',
                                          controller: email,
                                          email: true,
                                          optional: true,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Phone Number *',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          formatter: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                                10),
                                            PhoneNumberFormatter(),
                                          ],
                                          keyboardType: TextInputType.number,
                                          // keyboardType: TextInputType.numberWithOptions(signed: true,decimal: true),
                                          hintText: 'Enter Phone Number',
                                          controller: phoneNumber,
                                          phone: true,
                                          optional: true,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Address',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter Address',
                                          controller: address,
                                          optional: true,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('City',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter City',
                                          controller: city,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('State',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter State',
                                          controller: state,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Zip',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          formatter: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(r'[a-zA-Z0-9]')),
                                            TextInputFormatter.withFunction(
                                                (oldValue, newValue) {
                                              return TextEditingValue(
                                                text:
                                                    newValue.text.toUpperCase(),
                                                selection: newValue.selection,
                                              );
                                            }),
                                          ],
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter Zip',
                                          controller: zip,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        const Text('Country',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey)),
                                        CustomTextField(
                                          keyboardType: TextInputType.text,
                                          hintText: 'Enter Country',
                                          controller: country,
                                        ),
                                        const SizedBox(
                                          height: 8,
                                        ),
                                        // PCI: secure Collect.js card field — placed at the END of the form, matching web.
                                        CollectJsCardField(
                                          publicKey: _publicKey,
                                          controller: _cardCtrl,
                                          onReady: () =>
                                              setState(() => _cardReady = true),
                                          onToken: (t) => _saveTokenizedCard(t),
                                          onError: (msg) {
                                            if (mounted) {
                                              setState(
                                                  () => _submitting = false);
                                            }
                                            Fluttertoast.showToast(msg: msg);
                                          },
                                          onValidation: (field, valid, message) {
                            setState(() => _cardValidity[field] = valid);
                                            // If the user tapped Add Card but a field is invalid, Collect.js fires
                                            // validation instead of returning a token — release the button + tell them.
                                            if (!valid && _submitting) {
                                              setState(
                                                  () => _submitting = false);
                                              Fluttertoast.showToast(
                                                  msg: message.isNotEmpty
                                                      ? message
                                                      : 'Please enter valid card details.');
                                            }
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                ),
                                selectedTenantId == null
                                    ? Container()
                                    : Padding(
                                        padding: EdgeInsets.only(left: 16.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Text('Cards',
                                                    style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor)),
                                              ],
                                            ),
                                            SizedBox(
                                              height: 10,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                    'Note: Swipe right on the card to delete it.',
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: blueColor)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                selectedTenantId == null
                                    ? Container()
                                    : const SizedBox(height: 8),
                                selectedTenantId == null
                                    ? Container()
                                    : Padding(
                                        padding: const EdgeInsets.only(
                                            left: 10, right: 10),
                                        child: isLoading
                                            ? const Center(
                                                child: SpinKitFadingCircle(
                                                  color: Colors.black,
                                                  size: 55.0,
                                                ),
                                              )
                                            : cardDetails.isEmpty
                                                ? Center(
                                                    child: Text(
                                                        messageCardAvailable ??
                                                            'No card details available'),
                                                  )
                                                : ListView.builder(
                                                    shrinkWrap: true,
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount:
                                                        cardDetails.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return Row(
                                                        children: [
                                                          Expanded(
                                                            child: _buildCreditCard(
                                                                cardDetails[
                                                                    index],
                                                                customervaultid
                                                                    .toString()),
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                          const SizedBox(
                                                            width: 5,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  ),
                                      ),
                                SizedBox(
                                  height: 15,
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16.0, bottom: 16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                          height: 42,
                                          width: 110,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.0)),
                                          child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: blueColor,
                                                  disabledBackgroundColor:
                                                      blueColor,
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0))),
                                              onPressed: (!_requiredFieldsFilled || !_cardValid || _submitting)
                                                  ? null
                                                  : () {
                                                      // PCI: tokenize in the WebView; the save runs in CollectJsCardField.onToken -> _saveTokenizedCard.
                                                      if (!_cardReady) {
                                                        Fluttertoast.showToast(
                                                            msg:
                                                                'Card fields are still loading…');
                                                        return;
                                                      }
                                                      if (!(_formKey
                                                              .currentState
                                                              ?.validate() ??
                                                          true)) {
                                                        Fluttertoast.showToast(
                                                            msg:
                                                                'Form is invalid. Please check the details.');
                                                        return;
                                                      }
                                                      setState(() =>
                                                          _submitting = true);
                                                      _cardCtrl.tokenize();
                                                    },
                                              child: _submitting
                                                  ? const SizedBox(
                                                      height: 20,
                                                      width: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white),
                                                    )
                                                  : const Text(
                                                      'Add Card',
                                                      style: TextStyle(
                                                          color: Color(
                                                              0xFFf7f8f9)),
                                                    ))),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Container(
                                          height: 42,
                                          width: 100,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8.0)),
                                          child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFffffff),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0))),
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                              },
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                    color: Color(0xFF748097)),
                                              )))
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]),
                );
        },
      ),
    );
  }

  String? validateExpirationDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a date';
    }

    final RegExp dateRegex = RegExp(r'^(0[1-9]|1[0-2])/(\d{4})$');
    if (!dateRegex.hasMatch(value)) {
      return 'Invalid date format';
    }

    return null;
  }

  void formatExpiryDateForTextField(
      TextEditingController controller, String expiryDate) {
    if (expiryDate.length == 4) {
      String month = expiryDate.substring(0, 2);
      String year = expiryDate.substring(2, 4);
      controller.text = '$month/$year';
    } else {
      controller.text = expiryDate; // Set as is if not 4 characters long
    }
  }

  Widget _buildCreditCard(BillingData billingData, String customervaultid) {
    String _formatCardNumber(String cardNumber) {
      // Strip any grouping spaces so the input can be already-masked or raw.
      final String raw = cardNumber.replaceAll(' ', '');
      final int len = raw.length;

      // Only known card lengths are masked; anything else is returned as-is.
      if (len < 12 || len > 19) {
        return cardNumber;
      }

      // First digit + masked middle + last 4 (real digits are preserved).
      final StringBuffer masked = StringBuffer();
      masked.write(raw.substring(0, 1));
      for (int i = 1; i < len - 4; i++) {
        masked.write('x');
      }
      masked.write(raw.substring(len - 4));
      final String maskedDigits = masked.toString();

      // AMEX (15 digits) groups 4-6-5; everything else groups by 4.
      final List<int> groups = [];
      if (len == 15) {
        groups.addAll([4, 6, 5]);
      } else {
        int remaining = len;
        while (remaining > 0) {
          groups.add(remaining >= 4 ? 4 : remaining);
          remaining -= 4;
        }
      }

      final StringBuffer out = StringBuffer();
      int idx = 0;
      for (int g = 0; g < groups.length; g++) {
        if (g > 0) out.write(' ');
        out.write(maskedDigits.substring(idx, idx + groups[g]));
        idx += groups[g];
      }
      return out.toString();
    }

    String formatExpiryDate(String expiryDate) {
      if (expiryDate.length == 4) {
        String month = expiryDate.substring(0, 2);
        String year = expiryDate.substring(2, 4);
        return '$month/$year';
      } else {
        return expiryDate; // Return as is if not 4 characters long
      }
    }

    return Slidable(
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            borderRadius: BorderRadius.circular(10.0),
            onPressed: (context) async {
              await deleteCardaction(billingData, customervaultid);
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete Card',
          ),
        ],
      ),
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Container(
          height: 210,
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 22.0),
          decoration: BoxDecoration(
            gradient: _getCardGradient(billingData.ccType ?? ''),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildLogosBlock(
                    _cardTypeLabel(billingData),
                    billingData.ccType ?? ''),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _formatCardNumber(billingData.ccNumber ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _buildDetailsBlock(
                    label: 'CARDHOLDER',
                    value:
                        '${billingData.firstName ?? ''} ${billingData.lastName ?? ''}',
                  ),
                  _buildDetailsBlock(
                      label: 'VALID THRU',
                      value: formatExpiryDate(billingData.ccExp ?? '')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Resolves the card brand for display: prefer the processor's cc_type when it
// is a real brand, otherwise infer from the first digit of the (masked) number.
String _resolveCardBrand(String? ccType, String? ccNumber) {
  final String raw = (ccType ?? '').trim().toLowerCase();
  if (raw.contains('american express') || raw.contains('amex')) return 'AMEX';
  if (raw.contains('mastercard') || raw.contains('master card'))
    return 'MASTERCARD';
  if (raw.contains('visa')) return 'VISA';
  if (raw.contains('discover')) return 'DISCOVER';
  if (raw.contains('jcb')) return 'JCB';
  if (raw.contains('diners')) return 'DINERS';

  final String digits = (ccNumber ?? '').replaceAll(RegExp(r'\D'), '');
  final String first = digits.isNotEmpty ? digits[0] : '';
  if (first == '3') return 'AMEX';
  if (first == '4') return 'VISA';
  if (first == '5') return 'MASTERCARD';
  if (first == '6') return 'DISCOVER';
  return '';
}

// Builds the tile label combining brand and funding type, e.g. "VISA · DEBIT".
// binResult (CREDIT/DEBIT) is only read here — never modified — so surcharge
// and card-acceptance logic that depend on it are unaffected.
String _cardTypeLabel(BillingData billingData) {
  final String brand =
      _resolveCardBrand(billingData.ccType, billingData.ccNumber);
  final String type = (billingData.binResult ?? '').trim().toUpperCase();
  if (brand.isNotEmpty && type.isNotEmpty) return '$brand · $type';
  if (brand.isNotEmpty) return '$brand CARD';
  if (type.isNotEmpty) return '$type CARD';
  return 'CARD';
}

Row _buildLogosBlock(String cardType, String ccType) {
  String logoUrl =
      'https://logo.clearbit.com/${ccType.replaceAll(RegExp(r'[-\s]'), "").toLowerCase()}.com';
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: <Widget>[
      Image.network(
        logoUrl,
        height: 40,
        width: 40,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.credit_card,
            color: Colors.white,
            size: 30,
          );
        },
      ),
      Text(
        cardType,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
      ),
    ],
  );
}

Widget _buildDetailsBlock({required String label, required String value}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    ],
  );
}

LinearGradient _getCardGradient(String cardType) {
  if (cardType.toLowerCase() == "mastercard" ||
      cardType.toLowerCase() == "discover") {
    return const LinearGradient(
      colors: [Color(0xFF121E2E), Color(0xFF3A6194)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (cardType.toLowerCase() == "visa" ||
      cardType.toLowerCase() == "jcb") {
    return const LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF666666)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else {
    return const LinearGradient(
      colors: [Color(0xFF949BA5), Color(0xFF393B3F)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Remove any existing spaces in the input
    String newText = newValue.text.replaceAll(' ', '');

    // Add a space after every 4 digits
    if (newText.length > 4) {
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < newText.length; i++) {
        buffer.write(newText[i]);
        if ((i + 1) % 4 == 0 && i + 1 != newText.length) {
          buffer.write(' ');
        }
      }
      newText = buffer.toString();
    }

    // Return the new value with the formatting applied
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// class CustomTextField extends StatefulWidget {
//   final String hintText;
//   final TextEditingController? controller;
//   final TextInputType keyboardType;
//   final String? Function(String?)? validator;
//   final bool obscureText;
//   final Function(String)? onChanged;
//   final Function(String)? onChanged2;
//   final Widget? suffixIcon;
//   final IconData? prefixIcon;
//   final void Function()? onSuffixIconPressed;
//   final void Function()? onTap;
//   final String? label;
//   final bool readOnnly;
//   final bool? amount_check;
//   final String? max_amount;
//   final String? error_mess;
//   final bool? optional;
//   final bool? phone;
//   final List<TextInputFormatter>? formatter;
//   final bool? email;
//
//   CustomTextField({
//     Key? key,
//     this.onChanged,
//     this.controller,
//     required this.hintText,
//     this.obscureText = false,
//     this.keyboardType = TextInputType.emailAddress,
//     this.readOnnly = false,
//     this.prefixIcon,
//     this.suffixIcon,
//     this.validator,
//     this.onSuffixIconPressed,
//     this.label,
//     this.onTap,
//     this.onChanged2,
//     this.amount_check,
//     this.max_amount,
//     this.error_mess,
//     this.formatter,
//     this.phone,
//     this.optional = false,
//     this.email,
//     // Initialize onTap
//   }) : super(key: key);
//
//   @override
//   CustomTextFieldState createState() => CustomTextFieldState();
// }
//
// class CustomTextFieldState extends State<CustomTextField> {
//   String? _errorMessage;
//   TextEditingController _textController =
//       TextEditingController(); // Add this line
//
//   late FocusNode _focusNode;
//   @override
//   @override
//   void initState() {
//     super.initState();
//     _textController = widget.controller ?? TextEditingController();
//     _focusNode = FocusNode();
//   }
//
//   KeyboardActionsConfig _buildConfig(BuildContext context) {
//     return KeyboardActionsConfig(
//       actions: [
//         KeyboardActionsItem(
//           focusNode: _focusNode,
//           toolbarButtons: [
//             (node) {
//               return GestureDetector(
//                 onTap: () {
//                   if (widget.onChanged2 != null) {
//                     widget.onChanged2!(_textController.text);
//                   }
//                   node.unfocus(); // Dismiss the keyboard
//                 },
//                 child: Padding(
//                   padding: EdgeInsets.all(14.0),
//                   child: Text(
//                     "Done",
//                     style: TextStyle(
//                         color: Colors.blue, fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               );
//             },
//           ],
//         ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final shouldUseKeyboardActions =
//         widget.keyboardType == TextInputType.number;
//     Widget textfield = Stack(
//       clipBehavior: Clip.none,
//       children: <Widget>[
//         FormField<String>(
//           validator: widget.optional!
//               ? null
//               : (value) {
//                   if (widget.controller!.text.isEmpty) {
//                     setState(() {
//                       if (widget.label == null)
//                         _errorMessage = 'Please ${widget.hintText}';
//                       else
//                         _errorMessage = 'Please ${widget.label}';
//                     });
//                     return '';
//                   } else if (widget.phone != null) {
//                     String formattedPhoneNumber =
//                         widget.controller!.text.replaceAll(RegExp(r'\D'), '');
//
//                     // Removed the empty check
//                     if (formattedPhoneNumber.length != 10) {
//                       setState(() {
//                         _errorMessage = "Phone number must be 10 digits";
//                       });
//                       return '';
//                     }
//                   } else if (widget.email != null) {
//                     if (!EmailValidator.validate(widget.controller!.text)) {
//                       setState(() {
//                         _errorMessage = "Email is not valid";
//                       });
//                       return '';
//                     }
//                   } else if (widget.amount_check != null &&
//                       double.parse(widget.controller!.text) >
//                           double.parse(widget.max_amount!))
//                     setState(() {
//                       _errorMessage = '${widget.error_mess}';
//                     });
//                   return null;
//                 },
//           builder: (FormFieldState<String> state) {
//             return Column(
//               children: <Widget>[
//                 Material(
//                   elevation: 2,
//                   borderRadius: BorderRadius.circular(8.0),
//                   child: Container(
//                     height: 50,
//                     padding:
//                         EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(8.0),
//                       //border: Border.all(color: blueColor),
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.2),
//                           offset: Offset(4, 4),
//                           blurRadius: 3,
//                         ),
//                       ],
//                     ),
//                     child: TextFormField(
//                       /*    onFieldSubmitted: (value){
//                         if(value.isNotEmpty){
//
//                           if(widget.amount_check != null){
//                             if(int.parse(value) > int.parse(widget.max_amount!)){
//                               setState(() {
//                                 _errorMessage = '${widget.error_mess}';
//                               });
//                             }
//                           }
//                           else{
//                             setState(() {
//                               _errorMessage = null;
//                             });
//                           }
//
//                         }
//                         print(value);
//                         widget.onChanged2;
//                       },*/
//                       inputFormatters: widget.formatter ?? [],
//                       onFieldSubmitted: widget.onChanged2,
//                       onChanged: (value) {
//                         //  print("object calin $value");
//                         if (value.isNotEmpty) {
//                           setState(() {
//                             _errorMessage = null;
//                           });
//                         }
//                         if (widget.onChanged != null) widget.onChanged!(value);
//                         // print("callllll");
//                       },
//                       focusNode: _focusNode,
//                       onTap: () {
//                         if (widget.onTap != null) {
//                           widget.onTap!();
//                           setState(() {
//                             _errorMessage = null;
//                           });
//                         }
//                       },
//                       obscureText: widget.obscureText,
//                       readOnly: widget.readOnnly,
//                       keyboardType: widget.keyboardType,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           state.validate();
//                         }
//                         return null;
//                       },
//                       controller: widget.controller,
//                       decoration: InputDecoration(
//                         suffixIcon: widget.suffixIcon,
//                         hintStyle:
//                             TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
//                         border: InputBorder.none,
//                         hintText: widget.hintText,
//                       ),
//                     ),
//                   ),
//                 ),
//                 if (state.hasError && _errorMessage != null ||
//                     widget.amount_check != null)
//                   SizedBox(height: 24),
//                 // Reserve space for error message
//               ],
//             );
//           },
//         ),
//         if (_errorMessage != null)
//           Positioned(
//             top: 60,
//             left: 8,
//             child: Text(
//               _errorMessage!,
//               style: TextStyle(
//                 color: Colors.red,
//                 fontSize: 12.0,
//               ),
//             ),
//           ),
//       ],
//     );
//     return shouldUseKeyboardActions
//         ? SizedBox(
//             height: widget.amount_check != null
//                 ? widget.amount_check!
//                     ? 75
//                     : 60
//                 : _errorMessage != null
//                     ? 75
//                     : 60,
//             width: MediaQuery.of(context).size.width * .98,
//             child: KeyboardActions(
//               config: _buildConfig(context),
//               child: textfield,
//             ),
//           )
//         : textfield;
//   }
// }

class CustomTextField extends StatefulWidget {
  final String hintText;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final Function(String)? onChanged;
  final Function(String)? onChanged2;
  final Widget? suffixIcon;
  final IconData? prefixIcon;
  final void Function()? onSuffixIconPressed;
  final void Function()? onTap;
  final String? label;
  final bool readOnnly;
  final bool? amount_check;
  final String? max_amount;
  final String? error_mess;
  final bool? optional;
  final bool? phone;
  final bool? cvv;
  final bool? expirydate;
  final bool? allerror;
  final bool? cardnum;
  final List<TextInputFormatter>? formatter;
  final bool? email;
  final Function(String?)? onError;
  final Function(String?)? onErrorcard;
  final Function(String?)? onErrorcvv;

  CustomTextField({
    Key? key,
    this.onChanged,
    this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.emailAddress,
    this.readOnnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onSuffixIconPressed,
    this.label,
    this.onTap,
    this.onChanged2,
    this.amount_check,
    this.max_amount,
    this.error_mess,
    this.formatter,
    this.phone,
    this.cvv,
    this.cardnum,
    this.expirydate,
    this.allerror,
    this.optional = false,
    this.email,
    this.onError,
    this.onErrorcard,
    this.onErrorcvv,
    // Initialize onTap
  }) : super(key: key);

  @override
  CustomTextFieldState createState() => CustomTextFieldState();
}

class CustomTextFieldState extends State<CustomTextField> {
  String? _errorMessage;
  TextEditingController _textController =
      TextEditingController(); // Add this line

  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
  }

  KeyboardActionsConfig _buildConfig(BuildContext context) {
    return KeyboardActionsConfig(
      actions: [
        KeyboardActionsItem(
          focusNode: _focusNode,
          toolbarButtons: [
            (node) {
              return GestureDetector(
                onTap: () {
                  if (widget.onChanged2 != null) {
                    widget.onChanged2!(_textController.text);
                  }
                  node.unfocus(); // Dismiss the keyboard
                },
                child: Padding(
                  padding: EdgeInsets.all(14.0),
                  child: Text(
                    "Done",
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ],
        ),
      ],
    );
  }

  String exprmessage = "";
  bool isValidLuhn(String input) {
    input = input.replaceAll(RegExp(r'\D'), ''); // Remove non-digit characters
    int sum = 0;
    bool alternate = false;

    for (int i = input.length - 1; i >= 0; i--) {
      int digit = int.parse(input[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final shouldUseKeyboardActions =
        widget.keyboardType == TextInputType.number;
    Widget textfield = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        FormField<String>(
          validator: (value) {
            // If field is optional and empty, no validation needed
            if (widget.optional! && widget.controller!.text.trim().isEmpty) {
              return null;
            }

            // If field is required and empty, show error
            if (!widget.optional! && widget.controller!.text.trim().isEmpty) {
              setState(() {
                if (widget.label == null)
                  _errorMessage = 'Please ${widget.hintText}';
                else
                  _errorMessage = 'Please ${widget.label}';
              });
              return '';
            }

            // Validate format if field has value (for optional fields) or is required
            if (widget.phone != null) {
              String formattedPhoneNumber =
                  widget.controller!.text.trim().replaceAll(RegExp(r'\D'), '');

              if (formattedPhoneNumber.isNotEmpty &&
                  formattedPhoneNumber.length != 10) {
                setState(() {
                  _errorMessage = "Phone number must be 10 digits";
                });
                return '';
              }
            } else if (widget.email != null) {
              String emailValue = widget.controller!.text.trim();
              if (emailValue.isNotEmpty &&
                  !EmailValidator.validate(emailValue)) {
                setState(() {
                  _errorMessage = "Email is not valid";
                });
                return '';
              }
            } else if (widget.amount_check != null) {
              // Web parity: AddPayment.js "is-less-than-balance" test only
              // applies when the balance is truthy, so a null/zero max must
              // not block the row.
              final double? maxValue =
                  double.tryParse(widget.max_amount ?? '');
              final double entered =
                  double.tryParse(widget.controller!.text.trim()) ?? 0.0;
              if (maxValue != null && maxValue > 0 && entered > maxValue) {
                setState(() {
                  _errorMessage = '${widget.error_mess}';
                });
                return '';
              }
            }
            return null;
          },
          builder: (FormFieldState<String> state) {
            return Column(
              children: <Widget>[
                Material(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 50,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      // Flat bordered look to match the Tenant Add Card fields.
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: TextFormField(
                      /*    onFieldSubmitted: (value){
                        if(value.isNotEmpty){

                          if(widget.amount_check != null){
                            if(int.parse(value) > int.parse(widget.max_amount!)){
                              setState(() {
                                _errorMessage = '${widget.error_mess}';
                              });
                            }
                          }
                          else{
                            setState(() {
                              _errorMessage = null;
                            });
                          }

                        }
                        widget.onChanged2;
                      },*/
                      textInputAction: TextInputAction.done,
                      inputFormatters: widget.formatter ?? [],
                      onFieldSubmitted: widget.onChanged2,
                      onChanged: (value) {
                        //  print("object calin $value");
                        if (widget.expirydate == true) {
                          String? validationMessage;

                          // If the field is empty, set the error message to null
                          if (value == null || value.isEmpty) {
                            validationMessage = null;
                          } else {
                            // If not empty, validate the expiration date
                            validationMessage = ValidateExpirationDate(
                                value); // Assuming ValidateExpirationDate() checks for expiration date format
                          }


                          setState(() {
                            if (validationMessage != null) {
                              exprmessage =
                                  validationMessage; // Display error message if invalid
                            } else {
                              exprmessage =
                                  ""; // Clear error message if valid or empty
                              _errorMessage =
                                  null; // Clear general error message
                            }
                          });

                          if (widget.onError != null) {
                            widget.onError!(
                                exprmessage); // Pass the error message to the parent
                          }
                        }
                        if (widget.cardnum != null && widget.allerror != null) {
                          String cardNumber = value.replaceAll(
                              RegExp(r'\D'), ''); // Remove non-digit characters

                          // If the card number is empty, clear the error message
                          if (cardNumber.isEmpty) {
                            setState(() {
                              _errorMessage =
                                  null; // Clear error message if the field is empty
                            });
                          } else if (cardNumber.length != 16) {
                            setState(() {
                              exprmessage = "Card number must be 16 digits";
                              _errorMessage = "Card number must be 16 digits";
                            });
                          } else if (!isValidLuhn(cardNumber)) {
                            setState(() {
                              _errorMessage = "Invalid credit card number";
                              exprmessage = "Invalid credit card number";
                            });
                          } else {
                            // Clear error message if the card number is valid
                            setState(() {
                              _errorMessage = null;
                              exprmessage = "";
                            });
                          }

                          // Notify parent about the error message (if any)
                          if (widget.onErrorcard != null) {
                            widget.onErrorcard!(
                                _errorMessage); // Pass the error message to the parent
                          }
                        }
                        if (widget.cvv != null && widget.allerror != null) {
                          String formattedCVV = widget.controller!.text
                              .trim()
                              .replaceAll(RegExp(r'\D'),
                                  ''); // Remove non-digit characters

                          // Check if the CVV field is empty
                          if (formattedCVV.isEmpty) {
                            setState(() {
                              _errorMessage =
                                  null; // Clear error message if the field is empty
                            });
                          } else if (formattedCVV.length != 3) {
                            setState(() {
                              _errorMessage = "Cvv number must be 3 digits";
                              exprmessage = "Cvv number must be 3 digits";
                            });
                          } else {
                            // Clear error message if the CVV is valid
                            setState(() {
                              _errorMessage = null;
                              exprmessage = "";
                            });
                          }

                          // Notify parent about the error message (if any)
                          if (widget.onErrorcvv != null) {
                            widget.onErrorcvv!(
                                _errorMessage); // Pass the error message to the parent
                          }
                        }

                        if (value.isNotEmpty) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                        if (widget.onChanged != null) widget.onChanged!(value);
                        // print("callllll");
                      },
                      focusNode: _focusNode,
                      onTap: () {
                        if (widget.onTap != null) {
                          widget.onTap!();
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                      obscureText: widget.obscureText,
                      readOnly: widget.readOnnly,
                      keyboardType: widget.keyboardType,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          state.validate();
                        }
                        return null;
                      },
                      controller: widget.controller,
                      decoration: InputDecoration(
                        suffixIcon: widget.suffixIcon,
                        hintStyle:
                            TextStyle(fontSize: 13, color: Color(0xFFb0b6c3)),
                        border: InputBorder.none,
                        hintText: widget.hintText,
                      ),
                      style: TextStyle(
                          color: widget.allerror == true
                              ? exprmessage != ""
                                  ? Colors.red
                                  : Colors.green
                              : Colors.black),
                    ),
                  ),
                ),
                if (state.hasError && _errorMessage != null ||
                    widget.amount_check != null)
                  SizedBox(height: 24),
                // Reserve space for error message
              ],
            );
          },
        ),
        if (_errorMessage != null)
          Positioned(
            top: 60,
            left: 8,
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: 12.0,
              ),
            ),
          ),
      ],
    );
    if (shouldUseKeyboardActions && Platform.isIOS) {
      return SizedBox(
        height: widget.amount_check != null
            ? widget.amount_check!
                ? 75
                : 60
            : _errorMessage != null
                ? 75
                : 60,
        width: MediaQuery.of(context).size.width * .98,
        child: KeyboardActions(
          config: _buildConfig(context),
          child: textfield,
        ),
      );
    } else {
      return textfield;
    }
  }
}

class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.replaceAll('/', '');

    if (newText.length > 6) {
      newText = newText.substring(0, 6);
    }

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(newText[i]);
    }

    return newValue.copyWith(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
