import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:three_zero_two_property/screens/Signup/signup_screen.dart';
import 'package:three_zero_two_property/widgets/appbar.dart';
import 'package:three_zero_two_property/widgets/us_state_dropdown.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:three_zero_two_property/widgets/titleBar.dart';

import '../../constant/constant.dart';
import '../../widgets/drawer_tiles.dart';
import '../../widgets/custom_drawer.dart';
void main() {
  runApp(const MaterialApp(home: Planform()));
}

class Planform extends StatefulWidget {
  const Planform({super.key});

  @override
  State<Planform> createState() => _PlanformState();
}

class _PlanformState extends State<Planform> {
  bool isLoading = false;
  TextEditingController streetaddress1 = TextEditingController();
  TextEditingController streetaddress2 = TextEditingController();
  TextEditingController city = TextEditingController();
  TextEditingController state = TextEditingController();
  TextEditingController postalcode = TextEditingController();
  TextEditingController country = TextEditingController();
  TextEditingController cardtype = TextEditingController();
  TextEditingController cardnumber = TextEditingController();
  TextEditingController month = TextEditingController();
  TextEditingController year = TextEditingController();
  TextEditingController cvv = TextEditingController();
  TextEditingController cardholder = TextEditingController();

  @override
  void dispose() {
    streetaddress1.dispose();
    streetaddress2.dispose();
    city.dispose();
    state.dispose();
    postalcode.dispose();
    country.dispose();
    cardtype.dispose();
    cardnumber.dispose();
    month.dispose();
    year.dispose();
    cvv.dispose();
    cardholder.dispose();
    super.dispose();
  }

  bool streetaddress1error = false;
  bool streetaddress2error = false;
  bool cityerror = false;
  bool stateerror = false;
  bool postalcodeerror = false;
  bool countryerror = false;
  bool cardtypeerror = false;
  bool cardnumbererror = false;
  bool montherror = false;
  bool yearerror = false;
  bool cvverror = false;
  bool cardholdererror = false;

  bool loading = false;

  String streetaddress1message = "";
  String streetaddress2message = "";
  String citymessage = "";
  String statemessage = "";
  String postalcodemessage = "";
  String countrymessage = "";
  String cardtypemessage = "";
  String cardnumbermessage = "";
  String monthmessage = "";
  String yearmessage = "";
  String cvvmessage = "";
  String cardholdermessage = "";

  bool showStep2Details = false;

  String selectedCountry = '';

  List<int> years =
      List<int>.generate(10, (int index) => DateTime.now().year + index);
  List<String> months = [
    '01',
    '02',
    '03',
    '04',
    '05',
    '06',
    '07',
    '08',
    '09',
    '10',
    '11',
    '12'
  ];

  String selectedMonth = '01';
  int selectedYear = DateTime.now().year;

  List<String> countries = [];

  @override
  void initState() {
    super.initState();
    fetchCountries();
  }

  Future<void> fetchCountries() async {
    final response = await http
        .get(Uri.parse('https://restcountries.com/v3.1/all?fields=name'));
    final List<dynamic> data = jsonDecode(response.body);
    setState(() {
      countries = data
          .map((country) => country['name']['common'])
          .toList()
          .cast<String>();
      countries.sort(); // Sort countries alphabetically
      if (countries.isNotEmpty) {
        selectedCountry = countries[0];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer:CustomDrawer(currentpage: "Dashboard",dropdown: false,),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(
              height: 16,
            ),
            titleBar(
              title: 'Preminum Plans',
              width: MediaQuery.of(context).size.width * .91,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                   Row(
                    children: [
                      Text(
                        "1.Enter the company Address",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: blueColor),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Enter the company's headquarter to ensure accurate tax information",
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                   Row(
                    children: [
                      Text(
                        "Street Address *",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: blueColor),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                streetaddress1error = false;
                              });
                            },
                            controller: streetaddress1,
                            cursorColor:blueColor,
                            decoration: InputDecoration(
                              enabledBorder: streetaddress1error
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(2),
                                      borderSide: const BorderSide(
                                          color: Colors
                                              .red), // Set border color here
                                    )
                                  : InputBorder.none,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                              hintText: "Enter the street address here 1...*",
                              hintStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (streetaddress1error)
                    Center(
                      child: Text(
                        streetaddress1message,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(
                    height: 10,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: Colors.grey),
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                streetaddress2error = false;
                              });
                            },
                            controller: streetaddress2,
                            cursorColor:blueColor,
                            decoration: InputDecoration(
                              enabledBorder: streetaddress2error
                                  ? OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(2),
                                      borderSide: const BorderSide(
                                          color: Colors
                                              .red), // Set border color here
                                    )
                                  : InputBorder.none,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(12),
                              hintText: "Enter the street address here 2...*",
                              hintStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (streetaddress2error)
                    Center(
                      child: Text(
                        streetaddress2message,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(
                    height: 10,
                  ),
                  //city,state,postalcode

                  Column(
                    children: [
                      Row(
                        children: [
                           Text(
                            "City *",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor),
                          ),
                          const SizedBox(
                            width: 80,
                          ),
                           Text(
                            "State *",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor),
                          ),
                          const SizedBox(
                            width: 65,
                          ),
                           Text(
                            "Postal code *",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blueColor),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 110,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  //  color: Color.fromRGBO(196, 196, 196, .3),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: TextField(
                                        onChanged: (value) {
                                          setState(() {
                                            cityerror = false;
                                          });
                                        },
                                        controller: city,
                                        cursorColor:
                                           blueColor,
                                        decoration: InputDecoration(
                                          enabledBorder: cityerror
                                              ? OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  borderSide: const BorderSide(
                                                      color: Colors
                                                          .red), // Set border color here
                                                )
                                              : InputBorder.none,
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.all(12),
                                          hintText: "Enter city*",
                                          hintStyle:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              cityerror
                                  ? Center(
                                      child: Text(
                                      citymessage,
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .02),
                                    ))
                                  : Container(),
                            ],
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Column(
                            children: [
                              SizedBox(
                                width: 110,
                                child: UsStateDropdown(
                                  controller: state,
                                  hintText: 'State*',
                                  borderColor: stateerror ? redClr : null,
                                  onChanged: (value) {
                                    setState(() {
                                      stateerror = false;
                                    });
                                  },
                                ),
                              ),
                              stateerror
                                  ? Center(
                                      child: Text(
                                      statemessage,
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .02),
                                    ))
                                  : Container(),
                            ],
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Column(
                            children: [
                              Container(
                                width: 110,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  //  color: Color.fromRGBO(196, 196, 196, .3),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: TextField(
                                        onChanged: (value) {
                                          setState(() {
                                            postalcodeerror = false;
                                          });
                                        },
                                        controller: postalcode,
                                        cursorColor:
                                           blueColor,
                                        decoration: InputDecoration(
                                          enabledBorder: postalcodeerror
                                              ? OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  borderSide: const BorderSide(
                                                      color: Colors
                                                          .red), // Set border color here
                                                )
                                              : InputBorder.none,
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.all(12),
                                          hintText: "Enter postalcode...*",
                                          hintStyle:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              postalcodeerror
                                  ? Center(
                                      child: Text(
                                      postalcodemessage,
                                      style: TextStyle(
                                          color: Colors.red,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              .02),
                                    ))
                                  : Container(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                   Row(
                    children: [
                      Text(
                        "Country *",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: blueColor),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Row(
                    children: [
                      Column(
                        children: [
                          Stack(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 40,
                                  width: 285,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: Center(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: selectedCountry,
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedCountry = newValue!;
                                          });
                                        },
                                        items: countries
                                            .map<DropdownMenuItem<String>>(
                                                (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          yearerror
                              ? Center(
                                  child: Text(
                                    yearmessage,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize:
                                          MediaQuery.of(context).size.width *
                                              .02,
                                    ),
                                  ),
                                )
                              : Container(),
                        ],
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * .099,
                      ),
                    ],
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  Row(
                    children: [
                      SizedBox(
                        width: MediaQuery.of(context).size.width * .04,
                      ),
                      GestureDetector(
                        onTap: () {
                          if (streetaddress1.text.isEmpty) {
                            setState(() {
                              streetaddress1error = true;
                              streetaddress1message =
                                  "Street address 1 is required";
                            });
                          } else {
                            setState(() {
                              streetaddress1error = false;
                            });
                          }
                          if (streetaddress2.text.isEmpty) {
                            setState(() {
                              streetaddress2error = true;
                              streetaddress2message = "Address 2 is required";
                            });
                          } else {
                            setState(() {
                              streetaddress2error = false;
                            });
                          }
                          if (city.text.isEmpty) {
                            setState(() {
                              cityerror = true;
                              citymessage = "City is required";
                            });
                          } else {
                            setState(() {
                              cityerror = false;
                            });
                          }
                          if (state.text.isEmpty) {
                            setState(() {
                              stateerror = true;
                              statemessage = "State is required";
                            });
                          } else {
                            setState(() {
                              stateerror = false;
                            });
                          }
                          if (postalcode.text.isEmpty) {
                            setState(() {
                              postalcodeerror = true;
                              postalcodemessage = "Country is required";
                            });
                          } else {
                            setState(() {
                              postalcodeerror = false;
                            });
                          }

                          if (!streetaddress1error &&
                              !streetaddress2error &&
                              !cityerror &&
                              !stateerror &&
                              !postalcodeerror) {
                            setState(() {
                              showStep2Details =
                                  true; // Set to true to show step 2 details
                            });
                          }
                        },
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.05,
                          width: MediaQuery.of(context).size.width * 0.25,
                          decoration: BoxDecoration(
                            color:blueColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Continue",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        MediaQuery.of(context).size.width *
                                            0.04,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  if (showStep2Details)
                    Column(
                      // crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * .099,
                            ),
                             Expanded(
                              child: Text(
                                "2.Review the subscription and enter the payment information",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: blueColor,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * .099,
                            ),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * .02,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 25, right: 25),
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: MediaQuery.of(context).size.height * .24,
                              width: MediaQuery.of(context).size.width * .99,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:  Column(
                                children: [
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 15,
                                      ),
                                      Text(
                                        "Subtotal",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                blueColor,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(left: 15, right: 25),
                                    child: Divider(
                                      // Add Divider widget here
                                      color: Colors.grey,
                                      thickness: 1,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Row(
                                    children: [
                                      SizedBox(
                                        width: 15,
                                      ),
                                      Text(
                                        "Growth - Anuual Subscription 10 % discount",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10),
                                      ),
                                      SizedBox(
                                        width: 15,
                                      ),
                                      Text(
                                        "\$1880.00",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10),
                                      ),
                                      SizedBox(
                                        width: 15,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 10,
                                  ),
                                  const Row(
                                    children: [
                                      SizedBox(
                                        width: 15,
                                      ),
                                      Text(
                                        "10 unit plan- 2/6/2024 to 2/5/2025",
                                        style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 20,
                                  ),
                                  Row(
                                    children: [
                                      const SizedBox(
                                        width: 15,
                                      ),
                                      Text(
                                        "Total:",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                blueColor,
                                            fontSize: 12),
                                      ),
                                      const Spacer(),
                                      Text(
                                        "\$1880.00",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                blueColor,
                                            fontSize: 12),
                                      ),
                                      const SizedBox(
                                        width: 15,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * .02,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 25, right: 25),
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: MediaQuery.of(context).size.height * .4,
                              width: MediaQuery.of(context).size.width * .99,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  // Subtotal
                                   Row(
                                    children: [
                                      const SizedBox(width: 15),
                                      Text(
                                        "Subtotal",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: blueColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Divider
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(left: 15, right: 25),
                                    child: Divider(
                                      color: Colors.grey,
                                      thickness: 1,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Card type
                                  Row(
                                    children: [
                                      const SizedBox(width: 15),
                                      const SizedBox(
                                        width: 100, // Fixed width for label
                                        child: Text(
                                          "Card Type",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            border:
                                                Border.all(color: Colors.grey),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      cardtypeerror = false;
                                                    });
                                                  },
                                                  controller: cardtype,
                                                  cursorColor:
                                                       blueColor


,
                                                  decoration: InputDecoration(
                                                    enabledBorder: cardtypeerror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        2),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            10),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                  cardtypeerror
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 117,
                                            ),
                                            Text(
                                              cardtypemessage,
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                  const SizedBox(height: 10),
                                  // Card number
                                  Row(
                                    children: [
                                      const SizedBox(width: 15),
                                      const SizedBox(
                                        width: 100, // Fixed width for label
                                        child: Text(
                                          "Card Number",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      // SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            border:
                                                Border.all(color: Colors.grey),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      cardnumbererror = false;
                                                    });
                                                  },
                                                  controller: cardnumber,
                                                  cursorColor:
                                                       blueColor


,
                                                  decoration: InputDecoration(
                                                    enabledBorder:
                                                        cardnumbererror
                                                            ? OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            2),
                                                                borderSide:
                                                                    const BorderSide(
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              )
                                                            : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            10),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                  cardnumbererror
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 117,
                                            ),
                                            Text(
                                              cardnumbermessage,
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                  const SizedBox(height: 20),
                                  // Expiration date
                                  Row(
                                    children: [
                                      const SizedBox(width: 15),
                                      const SizedBox(
                                        width: 100,
                                        child: Text(
                                          "Expiration Date",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                width: 80,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                ),
                                                child: Center(
                                                  child:
                                                      DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButton<String>(
                                                      value: selectedMonth,
                                                      onChanged:
                                                          (String? newValue) {
                                                        setState(() {
                                                          selectedMonth =
                                                              newValue!;
                                                        });
                                                      },
                                                      items: months
                                                          .map((String months) {
                                                        return DropdownMenuItem<
                                                            String>(
                                                          value: months,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        10.0),
                                                            child: Text(
                                                              months,
                                                              style:
                                                                  const TextStyle(
                                                                      fontSize:
                                                                          12),
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // montherror
                                          //     ? Center(
                                          //   child: Text(
                                          //     monthmessage,
                                          //     style: TextStyle(
                                          //       color: Colors.red,
                                          //       fontSize: MediaQuery.of(context).size.width * .02,
                                          //     ),
                                          //   ),
                                          // )
                                          //     : Container(),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      Column(
                                        children: [
                                          Stack(
                                            children: [
                                              Container(
                                                width: 90,
                                                height: 30,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                ),
                                                child: Center(
                                                  child:
                                                      DropdownButtonHideUnderline(
                                                    child: DropdownButton<int>(
                                                      value: selectedYear,
                                                      onChanged:
                                                          (int? newValue) {
                                                        setState(() {
                                                          selectedYear =
                                                              newValue!;
                                                        });
                                                      },
                                                      items:
                                                          years.map((int year) {
                                                        return DropdownMenuItem<
                                                            int>(
                                                          value: year,
                                                          child: Text(
                                                            year.toString(),
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        12),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // CVV
                                  Row(
                                    children: [
                                      const SizedBox(width: 15),
                                      const SizedBox(
                                        width: 100,
                                        child: Text(
                                          "CVV",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            border:
                                                Border.all(color: Colors.grey),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      cvverror = false;
                                                    });
                                                  },
                                                  controller: cvv,
                                                  cursorColor:
                                                       blueColor


,
                                                  decoration: InputDecoration(
                                                    enabledBorder: cvverror
                                                        ? OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        2),
                                                            borderSide:
                                                                const BorderSide(
                                                              color: Colors.red,
                                                            ),
                                                          )
                                                        : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            10),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                  cvverror
                                      ? Center(
                                          child: Text(
                                          cvvmessage,
                                          style: const TextStyle(
                                              color: Colors.red),
                                        ))
                                      : Container(),
                                  const SizedBox(height: 20),
                                  // Cardholder
                                  Row(
                                    children: [
                                      const SizedBox(width: 15),
                                      const SizedBox(
                                        width: 90,
                                        child: Text(
                                          "Cardholder Name",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          height: 30,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(2),
                                            border:
                                                Border.all(color: Colors.grey),
                                          ),
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: TextField(
                                                  onChanged: (value) {
                                                    setState(() {
                                                      cardholdererror = false;
                                                    });
                                                  },
                                                  controller: cardholder,
                                                  cursorColor:
                                                       blueColor


,
                                                  decoration: InputDecoration(
                                                    enabledBorder:
                                                        cardholdererror
                                                            ? OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            2),
                                                                borderSide:
                                                                    const BorderSide(
                                                                  color: Colors
                                                                      .red,
                                                                ),
                                                              )
                                                            : InputBorder.none,
                                                    border: InputBorder.none,
                                                    contentPadding:
                                                        const EdgeInsets.all(
                                                            10),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                  ),
                                  cardholdererror
                                      ? Row(
                                          children: [
                                            const SizedBox(
                                              width: 117,
                                            ),
                                            Text(
                                              cardholdermessage,
                                              style: const TextStyle(
                                                  color: Colors.red),
                                            ),
                                          ],
                                        )
                                      : Container(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * .02,
                        ),
                        //submit
                        Row(
                          children: [
                            SizedBox(
                              width: MediaQuery.of(context).size.width * .099,
                            ),
                            GestureDetector(
                              onTap: () {
                                if (cardtype.text.isEmpty) {
                                  setState(() {
                                    cardtypeerror = true;
                                    cardtypemessage = "cardtype is required";
                                  });
                                } else {
                                  setState(() {
                                    cardtypeerror = false;
                                  });
                                }
                                if (cardnumber.text.isEmpty) {
                                  setState(() {
                                    cardnumbererror = true;
                                    cardnumbermessage =
                                        "cardnumber 2 is required";
                                  });
                                } else {
                                  setState(() {
                                    cardnumbererror = false;
                                  });
                                }
                                if (cvv.text.isEmpty) {
                                  setState(() {
                                    cvverror = true;
                                    cvvmessage = "cvv is required";
                                  });
                                } else {
                                  setState(() {
                                    cvverror = false;
                                  });
                                }
                                if (cardholder.text.isEmpty) {
                                  setState(() {
                                    cardholdererror = true;
                                    cardholdermessage =
                                        "cardholder is required";
                                  });
                                } else {
                                  setState(() {
                                    cardholdererror = false;
                                  });
                                }

                                if (!cardtypeerror &&
                                    !cardnumbererror &&
                                    !cvverror &&
                                    !cardholdererror) {
                                  setState(() {
                                    showStep2Details =
                                        true; // Set to true to show step 2 details
                                  });
                                }
                              },
                              child: Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.05,
                                width: MediaQuery.of(context).size.width * 0.25,
                                decoration: BoxDecoration(
                                  color:blueColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Submit",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.04,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * .02,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
