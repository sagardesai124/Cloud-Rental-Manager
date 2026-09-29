import 'dart:convert';
import 'dart:math';
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
import 'package:keyboard_actions/keyboard_actions_config.dart';
import 'package:keyboard_actions/keyboard_actions_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/constant/constant.dart';

import '../../../widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';
import '../../../widgets/custom_drawer.dart';

import 'package:three_zero_two_property/widgets/collectjs_card_field.dart';
import 'CardModel.dart';
import 'Service.dart';

class AddCard extends StatefulWidget {
  @override
  State<AddCard> createState() => _AddCardState();
}

class _AddCardState extends State<AddCard> {
  TextEditingController cardNumber = TextEditingController();
  TextEditingController expirationDate = TextEditingController();
  TextEditingController cvv = TextEditingController();
  TextEditingController firstName = TextEditingController();
  TextEditingController lastName = TextEditingController();
  TextEditingController email = TextEditingController();
  TextEditingController phoneNumber = TextEditingController();
  TextEditingController address = TextEditingController();
  TextEditingController city = TextEditingController();
  TextEditingController state = TextEditingController();
  TextEditingController country = TextEditingController();
  TextEditingController zip = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? messageCardAvailable;

  List<Map<String, String>> tenants = [];
  bool isLoading = false;
  bool isLoading1 = false;
  String? selectedTenantId;
  int? customervaultid;
  List<BillingData> cardDetails = [];
  Map<String, dynamic> profiledata = {};

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
    fetchProfile();
    fetchTenants();
    _fetchTokenizationKey();
  }

  Future<void> _fetchTokenizationKey() async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    if (adminId == null || adminId.isEmpty) return;
    final key = await AddCardService().getTokenizationKeyByAdmin(adminId);
    if (!mounted) return;
    setState(() => _publicKey = key);
  }

  Future<void> _saveTokenizedCard(CardToken card) async {
    final prefs = await SharedPreferences.getInstance();
    final adminId = prefs.getString('adminId');
    final tenantId = prefs.getString('tenant_id');
    if (adminId == null ||
        adminId.isEmpty ||
        tenantId == null ||
        tenantId.isEmpty) {
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
    setState(() => isLoading1 = true);
    String company = '';
    try {
      company = await fetchCompanyName(adminId);
    } catch (_) {}
    final result = await AddCardService().saveTokenizedCard(
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
      isLoading1 = false;
      _submitting = false;
    });
    if (result.success) {
      Fluttertoast.showToast(msg: 'Add Card Successfully');
      Navigator.pop(context, true); // return true so the caller refreshes the list
    } else {
      Fluttertoast.showToast(msg: result.message ?? 'Failed to add card.');
    }
  }

  Future<void> fetchProfile() async {
    //  String? token = prefs.getString('token');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final String apiUrl = "${Api_url}/api/tenant/tenant_profile/$id";
    final response = await apiGet(
      Uri.parse('$apiUrl'),
      headers: {
        "authorization": "CRM $token",
        "id": "CRM $id",
      },
    );
    final response_Data = jsonDecode(response.body);
    if (response_Data["statusCode"] == 200) {
      setState(() {
        profiledata = response_Data["data"];
        firstName.text = "${profiledata["tenant_firstName"]}";
        lastName.text = profiledata["tenant_lastName"];
        email.text = profiledata["tenant_email"];
        phoneNumber.text = profiledata["tenant_phoneNumber"];
        address.text = profiledata['leaseData']['rental_adress'];

        //  _isLoading = false;
      });
      // return profile.fromJson(jsonDecode(response.body)["data"]);
    } else {
      throw Exception('Failed to load profile');
    }
  }

  Future<void> fetchTenants() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');

    if (id == null) {
      setState(() {
        isLoading = false;
        messageCardAvailable = 'Tenant ID not found';
      });
      return;
    }

    fetchcreditcard(id);
    /*  final response = await apiGet(
      Uri.parse('$Api_url/api/leases/lease_tenant/${id}'),
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
        });
      }

      setState(() {
        tenants = fetchedTenants;
      });
    } else {
      throw Exception('Failed to load tenants');
    }*/
  }

  Future<String> fetchCompanyName(String adminId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("tenant_id");
    String? admin_id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    final String apiUrl = '${Api_url}/api/admin/admin_profile/$admin_id';

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
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("tenant_id");
      String? admin_id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      setState(() {
        isLoading = true;
        cardDetails = []; // Clear previous card details
        messageCardAvailable = null;
      });

      final response = await apiGet(
        Uri.parse('$Api_url/api/creditcard/getCreditCards/$tenantId'),
        headers: {"id": "CRM $id", "authorization": "CRM $token"},
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        customervaultid = jsonResponse['customer_vault_id'];
        List<dynamic> cardDetailsList = jsonResponse['card_detail'] ?? [];

        if (cardDetailsList.isEmpty) {
          setState(() {
            isLoading = false;
            cardDetails = [];
            messageCardAvailable = 'No cards added.';
          });
          return;
        }

        CustomerData? customerData = await postBillingCustomerVault(
            customervaultid.toString(), cardDetailsList);

        if (customerData != null) {
          setState(() {
            customervaultid = jsonResponse['customer_vault_id'];
            // The gateway keeps cards AND ACH accounts in one `billing` list;
            // an ACH entry has no card number. Assigning the list unfiltered
            // rendered each ACH account as a blank card tile in the Cards
            // list. Same filter the Admin and Staff copies already apply.
            cardDetails = customerData.billing.where((b) {
              final cn = b.ccNumber?.trim() ?? '';
              return cn.isNotEmpty;
            }).toList();
            messageCardAvailable = cardDetails.isEmpty ? 'No cards added.' : '';
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            cardDetails = [];
            messageCardAvailable = 'No cards added.';
          });
        }
      } else if (response.statusCode == 404) {
        setState(() {
          isLoading = false;
          cardDetails = [];
          messageCardAvailable = 'No cards added.';
        });
      } else {
        setState(() {
          isLoading = false;
          cardDetails = [];
          messageCardAvailable = 'Failed to load credit card data';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        cardDetails = [];
        messageCardAvailable = 'No cards added.';
      });
    }
  }

  Future<CustomerData?> postBillingCustomerVault(
      String customerVaultId, List<dynamic> cardDetailsList) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("tenant_id");
      String? admin_id = prefs.getString("adminId");
      String? token = prefs.getString('token');

      Map<String, String> requestBody = {
        "customer_vault_id": customerVaultId,
        "admin_id": admin_id.toString(),
      };

      final response = await apiPost(
        Uri.parse('$Api_url/api/nmipayment/get-billing-customer-vault'),
        headers: {
          'Content-Type': 'application/json',
          "id": "CRM $id",
          "authorization": "CRM $token",
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        var customerJson = jsonResponse['data']?['customer'];

        if (customerJson == null) {
          return null;
        }

        CustomerData customerData = CustomerData.fromJson(customerJson);

        final Set<String> cardBillingIds = cardDetailsList
            .map((card) => card['billing_id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();

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

        final filteredCards = customerData.billing.where((billing) {
          final id = billing.billingId?.toString();
          return id != null && cardBillingIds.contains(id);
        }).toList();

        for (final billing in filteredCards) {
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

        customerData.billing = filteredCards;

        return customerData;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteCardaction(
      BillingData billingData, String customervaultid) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('adminId');

    cardModelFordelete cardmodelfordelete = cardModelFordelete(
      adminId: id,
      billingId: billingData.billingId,
      customerVaultId: customervaultid,
    );

    if (cardDetails.length == 1) {
      AddCardService apiService = AddCardService();
      int deleteResponse =
          await apiService.deleteOneCardDelete(customervaultid);

      if (deleteResponse == 200) {
        await apiService.deleteOneCardfromdatabase(customervaultid);
        setState(() {
          cardDetails
              .remove(billingData); // Remove the deleted card from the list
        });
        Fluttertoast.showToast(msg: "Card Deleted Successfully");
      } else {
        // Handle the error case
      }
    } else {
      AddCardService apiService = AddCardService();
      int deleteResponse = await apiService.deleteCard(cardmodelfordelete);

      if (deleteResponse == 200) {
        await apiService
            .deletefromdatabaseCard(billingData.billingId.toString());
        setState(() {
          cardDetails
              .remove(billingData); // Remove the deleted card from the list
        });
        Fluttertoast.showToast(msg: "Card Deleted Successfully");
      } else {
        // Handle the error case
      }
    }
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

  String generateRandomNumber(int length) {
    String randomNumber = "";
    for (int i = 0; i < length; i++) {
      randomNumber += (Random().nextInt(9) + 1).toString();
    }
    return randomNumber;
  }

  String? _errorMessage;
  String? _cardNumberError;
  String? _cvvError;
  // Callback to handle error messages
  void handleError(String? error) {
    setState(() {
      _errorMessage = error;
    });
  }

  bool showmessage = true;
  String? errorMessageDropdown = 'Please select any one Tenant.';
  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: key,
      appBar: widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {
          key.currentState!.openDrawer();
        },
      ),
      backgroundColor: Colors.white,
      drawer: CustomDrawer(
        currentpage: 'Financial',
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(0.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.0),
                        child: Container(
                          height: 50.0,
                          padding: EdgeInsets.only(top: 14, left: 10),
                          width: MediaQuery.of(context).size.width * .91,
                          margin: const EdgeInsets.only(bottom: 6.0),
                          //Same as `blurRadius` i guess
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5.0),
                            color: blueColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey,
                                offset: Offset(0.0, 1.0), //(x,y)
                                blurRadius: 6.0,
                              ),
                            ],
                          ),
                          child: Text(
                            "Add Card",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    // (Collect.js card field moved to the end — see after Country/Zip.)
                    const SizedBox(
                      height: 8,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    const Text('First Name *',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    CustomTextField(
                      keyboardType: TextInputType.text,
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,

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
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
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
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'Enter Email',
                      email: true,
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
                      controller: email,
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
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                        PhoneNumberFormatter(),
                      ],
                      keyboardType: TextInputType.number,
                      // keyboardType: TextInputType.numberWithOptions(signed: true,decimal: true),
                      hintText: 'Enter Phone Number',
                      controller: phoneNumber,
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
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
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
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
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
                      optional: true,
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
                    UsStateDropdown(
                      controller: state,
                      hintText: 'Select state',
                      borderColor: Colors.grey.shade300,
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
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
                      optional: true,
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
                      keyboardType: TextInputType.number,
                      hintText: 'Enter Zip',
                      controller: zip,
                      borderColor: Colors.grey.shade300,
                      borderWidth: 1,
                      showElevation: false,
                      optional: true,
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    // PCI: secure Collect.js card field — placed at the END of the form, matching web.
                    CollectJsCardField(
                      publicKey: _publicKey,
                      controller: _cardCtrl,
                      onReady: () => setState(() => _cardReady = true),
                      onToken: (t) => _saveTokenizedCard(t),
                      onError: (msg) {
                        if (mounted) setState(() => _submitting = false);
                        Fluttertoast.showToast(msg: msg);
                      },
                      onValidation: (field, valid, message) {
                            setState(() => _cardValidity[field] = valid);
                        // If the user tapped Add Card but a field is invalid, Collect.js fires
                        // validation instead of returning a token — release the button + tell them.
                        if (!valid && _submitting) {
                          setState(() => _submitting = false);
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
              selectedTenantId == null && cardDetails.isEmpty
                  ? Container()
                  : Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('Cards',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
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
                                      fontWeight: FontWeight.bold,
                                      color: blueColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10),
                child: isLoading
                    ? const Center(
                        child: SpinKitFadingCircle(
                          color: Colors.black,
                          size: 55.0,
                        ),
                      )
                    : cardDetails.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Text(
                                messageCardAvailable ?? 'No cards added.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: cardDetails.length,
                            itemBuilder: (context, index) {
                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildCreditCard(cardDetails[index],
                                        customervaultid.toString()),
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                  SizedBox(
                                    width: 5,
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                child: Row(
                  children: [
                    Container(
                        height: 42,
                        width: 110,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0)),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0))),
                            // onPressed: () async {
                            //   print(_formKey.currentState!.validate());
                            //   if (_formKey.currentState!.validate()) {
                            //     setState(() {
                            //       isLoading1 = true;
                            //     });
                            //     print("calling");
                            //     SharedPreferences prefs =
                            //         await SharedPreferences.getInstance();
                            //     String? id = prefs.getString("adminId");
                            //     String? token = prefs.getString('token');
                            //     selectedTenantId = prefs.getString('tenant_id');
                            //     String randomNumber = generateRandomNumber(10);
                            //
                            //     String? comapanyName =
                            //         await fetchCompanyName(id!);
                            //
                            //     CardModel cardwithOutVaultId = CardModel(
                            //       firstName: firstName.text,
                            //       lastName: lastName.text,
                            //       ccnumber: cardNumber.text,
                            //       cvv: cvv.text,
                            //       ccexp: expirationDate.text,
                            //       address1: address.text,
                            //       address2: '',
                            //       city: city.text,
                            //       state: state.text,
                            //       zip: zip.text,
                            //       country: country.text,
                            //       phone: phoneNumber.text,
                            //       email: email.text,
                            //       company: comapanyName,
                            //       billingId: randomNumber,
                            //       adminId: id,
                            //     );
                            //
                            //     CardModel cardwithVaultId = CardModel(
                            //         phone: phoneNumber.text,
                            //         adminId: id,
                            //         cvv: cvv.text,
                            //         company: comapanyName,
                            //         firstName: firstName.text,
                            //         lastName: lastName.text,
                            //         ccnumber: cardNumber.text,
                            //         ccexp: expirationDate.text,
                            //         address1: address.text,
                            //         address2: '',
                            //         zip: zip.text,
                            //         state: state.text,
                            //         city: city.text,
                            //         billingId: randomNumber,
                            //         email: email.text,
                            //         country: country.text,
                            //         customervaultid:
                            //             customervaultid.toString());
                            //
                            //     AddCardService addCardService =
                            //         AddCardService();
                            //
                            //     if (messageCardAvailable ==
                            //         "No card found for this tenant") {
                            //       print('create api and billing post api both');
                            //       // await addCardService
                            //       //     .postCardDetails(cardwithOutVaultId);
                            //       CardResponse? cardResponse =
                            //           await addCardService
                            //               .postCardDetails(cardwithOutVaultId);
                            //
                            //       if (cardResponse != null) {
                            //         print(
                            //             'Customer Vault ID: ${cardResponse.customerVaultId}');
                            //         print(
                            //             'Response Code: ${cardResponse.responseCode}');
                            //       } else {
                            //         print('Failed to get card response');
                            //       }
                            //       AddCreditCard addcard = AddCreditCard(
                            //         tenantId: selectedTenantId,
                            //         billingId: randomNumber,
                            //         customerVaultId:
                            //             cardResponse?.customerVaultId,
                            //         responseCode: cardResponse?.responseCode,
                            //       );
                            //
                            //       await addCardService
                            //           .postAddCreditCard(addcard)
                            //           .then((value) {
                            //         setState(() {
                            //           isLoading1 = false;
                            //         });
                            //       });
                            //       Navigator.pop(context);
                            //       Fluttertoast.showToast(
                            //           msg: 'Add Card Successfully');
                            //     } else {
                            //       CardResponse? cardResponses =
                            //           await addCardService
                            //               .postCardWithVaultId(cardwithVaultId);
                            //       if (cardResponses != null) {
                            //         print(
                            //             'Customer Vault ID: ${cardResponses.customerVaultId}');
                            //         print(
                            //             'Response Code: ${cardResponses.responseCode}');
                            //       } else {
                            //         print('Failed to get card response');
                            //       }
                            //       AddCreditCard addcards = AddCreditCard(
                            //         tenantId: selectedTenantId,
                            //         billingId: randomNumber,
                            //         customerVaultId:
                            //             cardResponses?.customerVaultId,
                            //         responseCode: cardResponses?.responseCode,
                            //       );
                            //       await addCardService
                            //           .postAddCreditCard(addcards)
                            //           .then((value) {
                            //         setState(() {
                            //           isLoading1 = false;
                            //         });
                            //       });
                            //       Navigator.pop(context, true);
                            //       Fluttertoast.showToast(
                            //           msg: 'Add Card Successfully');
                            //     }
                            //
                            //     //charges
                            //   } else {
                            //     setState(() {
                            //       isLoading1 = false;
                            //     });
                            //     print("invalid");
                            //   }
                            // },
                            onPressed: (!_requiredFieldsFilled || !_cardValid || _submitting)
                                ? null
                                : () {
                                    // PCI: tokenize in the WebView; the save runs in CollectJsCardField.onToken -> _saveTokenizedCard.
                                    if (!_cardReady) {
                                      Fluttertoast.showToast(
                                          msg: 'Card fields are still loading…');
                                      return;
                                    }
                                    if (!(_formKey.currentState?.validate() ??
                                        true)) {
                                      Fluttertoast.showToast(
                                          msg:
                                              'Form is invalid. Please check the details.');
                                      return;
                                    }
                                    setState(() => _submitting = true);
                                    _cardCtrl.tokenize();
                                  },
                            child: _submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Add Card',
                                    style: TextStyle(color: Color(0xFFf7f8f9)),
                                  ))),
                    const SizedBox(
                      width: 8,
                    ),
                    Container(
                        height: 42,
                        width: 120,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0)),
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFffffff),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0))),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Color(0xFF748097)),
                            )))
                  ],
                ),
              ),
            ],
          ),
        ),
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
        motion: ScrollMotion(),
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
                  style: TextStyle(
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
          return Icon(
            Icons.credit_card,
            color: Colors.white,
            size: 30,
          );
        },
      ),
      Text(
        cardType,
        style: TextStyle(
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
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
      SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
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
    return LinearGradient(
      colors: [Color(0xFF121E2E), Color(0xFF3A6194)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (cardType.toLowerCase() == "visa" ||
      cardType.toLowerCase() == "jcb") {
    return LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF666666)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else {
    return LinearGradient(
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
  final Border? customBorder;
  final Color? borderColor;
  final double? borderWidth;
  final bool? showElevation;

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
    this.customBorder,
    this.borderColor,
    this.borderWidth,
    this.showElevation,
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
            } else if (widget.amount_check != null &&
                (double.tryParse(widget.controller!.text.trim()) ?? 0.0) >
                    (double.tryParse(widget.max_amount!) ?? 0.0))
              setState(() {
                _errorMessage = '${widget.error_mess}';
              });
            return null;
          },
          builder: (FormFieldState<String> state) {
            return Column(
              children: <Widget>[
                Material(
                  elevation: widget.showElevation != null && widget.showElevation! ? 2 : 0,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Container(
                    height: 50,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                      border: widget.customBorder ??
                          (widget.borderColor != null
                              ? Border.all(
                                  color: widget.borderColor!,
                                  width: widget.borderWidth ?? 1.0)
                              : null),
                      boxShadow: widget.showElevation != null && widget.showElevation!
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                offset: const Offset(4, 4),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
                      //border: Border.all(color: blueColor),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.grey.shade300,
                      //     offset: Offset(4, 4),
                      //     blurRadius: 3,
                      //   ),
                      // ],
                 
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
    return shouldUseKeyboardActions
        ? SizedBox(
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
          )
        : textfield;
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
