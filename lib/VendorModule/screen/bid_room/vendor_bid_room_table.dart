import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/Model/bid_request.dart';
import 'package:three_zero_two_property/VendorModule/repository/vendor_bid_repo.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/VendorModule/screen/bid_room/vendor_submit_bid_screen.dart';
import 'package:three_zero_two_property/VendorModule/widgets/appbar.dart'
    as vendor_appbar;
import 'package:three_zero_two_property/widgets/titleBar.dart';
// import 'package:three_zero_two_property/widgets/custom_drawer.dart'; // Depending on if we use the same drawer
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:three_zero_two_property/widgets/dashboard_pagination_footer.dart';

class VendorBidRoomTable extends StatefulWidget {
  const VendorBidRoomTable({super.key});

  @override
  State<VendorBidRoomTable> createState() => _VendorBidRoomTableState();
}

class _VendorBidRoomTableState extends State<VendorBidRoomTable>
    with NetworkRetryState {
  final VendorBidRepository _repository = VendorBidRepository();
  List<BidRequest> _bidRequests = [];
  List<BidRequest> _filteredBidRequests = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  final List<String> _statuses = const ['All', 'Open', 'Closed'];
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool sorting1 = false;
  bool ascending1 = false;
  String? expandedBidRequestId;

  // We can add detail fetching if needed, similar to the admin side.
  // Map<String, BidRequestDetail?> _bidRequestDetails = {};
  // Map<String, bool> _loadingDetails = {};

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// These are the data calls `initState` makes; nothing that sets up
  /// controllers, filters or defaults is repeated, so a reload cannot
  /// reset what the user is looking at.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() {
      _fetchBidRequests();;
    });
  }

  @override
  void initState() {
    super.initState();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    _fetchBidRequests();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void checkInternet() async {
    var connectiondata = await Connectivity().checkConnectivity();
    // connectivity_plus answers from a cached reachability result that
    // can stay `none` after the connection is back; confirm before
    // believing it, or this screen strands itself offline.
    if (connectiondata == ConnectivityResult.none &&
        await hasNetworkNow()) {
      connectiondata = ConnectivityResult.wifi;
    }
    if (!mounted) return;
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  Future<void> _fetchBidRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? vendorId = prefs.getString('vendor_id');

      if (vendorId == null) {
        setState(() {
          _isLoading = false;
        });
        Fluttertoast.showToast(msg: 'Vendor ID not found');
        return;
      }

      final response = await _repository.fetchVendorBidRequests(
        vendorId: vendorId,
        limit: 10000,
        page: 1,
        status: _selectedStatus,
      );

      if (mounted) {
        setState(() {
          _bidRequests = response.data ?? [];
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // A network failure already flips this screen to its offline state,
        // which says it better than a toast of raw exception text on top of it.
        if (!isNetworkError(e)) {
          Fluttertoast.showToast(
              msg: 'Error loading bid requests: ${friendlyErrorMessage(e)}');
        }
      }
    }
  }

  void _applyFilters() {
    _filteredBidRequests = _bidRequests.where((request) {
      if (_searchQuery.isEmpty) return true;
      final searchLower = _searchQuery.toLowerCase();
      return (request.rental?.rentalAddress ?? '')
              .toLowerCase()
              .contains(searchLower) ||
          (request.workCategory ?? '').toLowerCase().contains(searchLower) ||
          (request.description ?? '').toLowerCase().contains(searchLower) ||
          (request.unit?.rentalUnit ?? '')
              .toLowerCase()
              .contains(searchLower) ||
          // Web's search also matches the status (Open, Closed).
          (request.status ?? '').toLowerCase().contains(searchLower);
    }).toList();

    // Apply sorting
    if (sorting1) {
      _filteredBidRequests.sort((a, b) {
        String aTitle = _getBidRoomTitle(a);
        String bTitle = _getBidRoomTitle(b);
        return ascending1
            ? aTitle.toLowerCase().compareTo(bTitle.toLowerCase())
            : bTitle.toLowerCase().compareTo(aTitle.toLowerCase());
      });
    }
  }

  String _getBidRoomTitle(BidRequest request) {
    // Sorting by description or address as per requirement.
    // Screenshot shows "Bid Room" column has "test" (description).
    return request.description ?? '';
  }

  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'closed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Like web's Vendor Bid Room (VendorBidRequests.jsx): Created On is the
  // createdAt_iso moment (else createdAt) in the viewer's local time, as
  // "<account date format> HH:mm:ss"; Due Date uses the account date
  // format. Both show "-" when empty.
  String _createdOn(BidRequest request) {
    final iso = request.createdAtIso ?? '';
    final raw = iso.isNotEmpty ? iso : (request.createdAt ?? '');
    if (raw.isEmpty) return '-';
    try {
      final dateFormat = Provider.of<DateProvider>(context).dateFormat;
      return DateFormat('$dateFormat HH:mm:ss')
          .format(DateTime.parse(raw).toLocal());
    } catch (e) {
      return raw;
    }
  }

  String _dueDate(BidRequest request) {
    final raw = request.dueDate ?? '';
    if (raw.isEmpty) return '-';
    try {
      final dateFormat = Provider.of<DateProvider>(context).dateFormat;
      return DateFormat(dateFormat).format(DateTime.parse(raw).toLocal());
    } catch (e) {
      return raw;
    }
  }

  Widget _buildCreatedOnDueDateRow(BidRequest request) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
     
        children: [
        Row(
          children: [
            SizedBox(
            width: 120,
            child: Text(
              "Created On :",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _createdOn(request),
              style: TextStyle(color: Colors.black, fontSize: 13),
            ),
          ),
         
          ],
        ),
        SizedBox(height: 4),
         Row(
          children: [
            SizedBox(
            width: 120,
            child: Text(
              "Due Date :",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: blueColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _dueDate(request),
              style: TextStyle(color: Colors.black, fontSize: 13),
            ),
          ),
          ],
         ),
        ],
      ),
    );
  }

  int get _totalPages =>
      (_filteredBidRequests.length / _rowsPerPage).ceil().clamp(1, 1 << 30);

  /// CRM-4362 / CRM-4837: the page actually shown. If a filter or delete
  /// shrinks the list past the current page, this clamps for DISPLAY only —
  /// it never writes `_currentPage`. The old getter assigned to it here,
  /// which is a state mutation inside a build pass; the real reset belongs in
  /// the handlers, which all set `_currentPage = 0` when the list changes.
  int get _safePage => _currentPage.clamp(0, _totalPages - 1);

  List<BidRequest> get _pagedData {
    if (_filteredBidRequests.isEmpty) return [];
    final int startIndex = _safePage * _rowsPerPage;
    final int endIndex =
        (startIndex + _rowsPerPage).clamp(0, _filteredBidRequests.length);
    return _filteredBidRequests.sublist(startIndex, endIndex);
  }

  void _changeRowsPerPage(int selectedRowsPerPage) {
    setState(() {
      _rowsPerPage = selectedRowsPerPage;
      _currentPage = 0;
    });
  }

   Widget _buildHeaders() {
    var width = MediaQuery.of(context).size.width;
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF4F8FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDBE0E5))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
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
              flex: 2,
              child: InkWell(
                 child: Row(
                  children: [
                    width < 400
                        ? Text("  #",
                            style: TextStyle(color: blueColor, fontSize: 14,fontWeight: FontWeight.bold))
                        : Text("  #",
                            style: TextStyle(color: blueColor, fontSize: 14,fontWeight: FontWeight.bold)),
                    
                   
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting1 == true) {
                      ascending1 = !ascending1;
                    } else {
                      sorting1 = true;
                      ascending1 = false;
                    }
                    _applyFilters();
                  });
                },
                child: Row(
                  children: [
                  
                    Text("Bid Room",
                        style: TextStyle(color: blueColor, fontSize: 14,fontWeight: FontWeight.bold )),
                    const SizedBox(width: 5),
                    ascending1
                        ? Padding(
                            padding: const EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 15,
                              color: blueColor,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 15,
                              color: blueColor,
                            ),
                          ),
                  ],
                ),
              ),
            ),
           Expanded(
              flex: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (sorting1 == true) {
                      ascending1 = !ascending1;
                    } else {
                      sorting1 = true;
                      ascending1 = false;
                    }
                    _applyFilters();
                  });
                },
                child: Row(
                  children: [
                  Text("Status",
                        style: TextStyle(color: blueColor, fontSize: 14,fontWeight: FontWeight.bold )),
                  
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: vendor_appbar.widget_302.App_Bar(
        context: context,
        onDrawerIconPressed: () {},
      ),
      backgroundColor: Colors.white,
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Title Bar
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width > 500 ? 13 : 16.0,
                    ),
                    child: titleBar(
                      width: double.infinity,
                      title: 'Bid Room',
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Search and Filter Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFDBE0E5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF495160),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  if (_currentPage != 0) _currentPage = 0;
                                  _applyFilters();
                                });
                              },
                              cursorColor: blueColor,
                              decoration: const InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: "Search here...",
                                hintStyle: TextStyle(
                                  color: Color(0xFF8A95A8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Color(0xFF8A95A8),
                                  size: 20,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFDBE0E5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton2<String>(
                                isExpanded: true,
                                alignment: AlignmentDirectional.centerStart,
                                hint: const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Text(
                                    'Status',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8A95A8),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                selectedItemBuilder: (context) => _statuses
                                    .map((item) => Container(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          padding: const EdgeInsets.only(
                                              left: 10),
                                          child: Text(
                                            item,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495160),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                items: _statuses
                                    .map((String item) =>
                                        DropdownMenuItem<String>(
                                          value: item,
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(left: 10),
                                            child: Text(
                                              item,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF495160),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ))
                                    .toList(),
                                value: _selectedStatus,
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _selectedStatus = value;
                                    if (_currentPage != 0) _currentPage = 0;
                                  });
                                  _fetchBidRequests();
                                },
                                buttonStyleData: ButtonStyleData(
                                  height: 42,
                                  padding: const EdgeInsets.only(
                                    left: 0,
                                    right: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.transparent,
                                  ),
                                  elevation: 0,
                                ),
                                iconStyleData: IconStyleData(
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color(0xFF8A95A8),
                                    size: 20,
                                  ),
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 200,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  _isLoading
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: ColabShimmerLoadingWidget(),
                        )
                      : _filteredBidRequests.isEmpty
                          ? Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: Column(
                                children: [
                                  _buildHeaders(),
                                  const SizedBox(height: 30),
                                  Image.asset(
                                    "assets/images/no_data.jpg",
                                    height: 120,
                                    width: 120,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    // CRM-4365 parity: this state is reached BOTH when there are no
                                    // bid rooms at all and when a search or filter matched none of
                                    // them. Telling a user with 12 records "No Data Available"
                                    // reads as data loss, so the two cases now say different things.
                                    (_searchQuery.isNotEmpty || _selectedStatus != 'All')
                                        ? "No Results Found"
                                        : "No Bid Rooms Yet",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: blueColor,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              child: Column(
                                children: [
                                  _buildHeaders(),
                                  const SizedBox(height: 10),
                                  Column(
                                    children:
                                        _pagedData.asMap().entries.map((entry) {
                                      int index = entry.key;
                                      BidRequest request = entry.value;
                                      final String bidKey =
                                          request.bidRequestId ??
                                              request.id ??
                                              '$index';
                                      bool isExpanded =
                                          expandedBidRequestId == bidKey;

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (expandedBidRequestId == bidKey) {
                                              expandedBidRequestId = null;
                                            } else {
                                              expandedBidRequestId = bidKey;
                                            }
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          margin: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                                color: const Color(0xFFDBE0E5)),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Column(
                                            children: [
                                              ListTile(
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                title: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: <Widget>[
                                                    InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          if (expandedBidRequestId ==
                                                              bidKey) {
                                                            expandedBidRequestId =
                                                                null;
                                                          } else {
                                                            expandedBidRequestId =
                                                                bidKey;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: EdgeInsets.only(
                                                            right: 8),
                                                        padding: !isExpanded
                                                            ? EdgeInsets.only(
                                                                bottom: 10)
                                                            : EdgeInsets.only(
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
                                                            flex: 2,
                                                            child: Text(
                                                              // Web parity (BidRequests.jsx:700): `BR${bid_request_no}`.
                                                              // Falls back to a bare "BR" when the number is absent, as
                                                              // web does, so older records without one still render.
                                                              "BR${request.bidRequestNo ?? ''}",
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color:
                                                                      blueColor),
                                                            ),
                                                          ),
                                                        SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                                                    Expanded(
                                                      flex: 4,
                                                      child: Text(
                                                        request.description ??
                                                            "N/A",
                                                        style: TextStyle(
                                                            color: blueColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                    SizedBox(width: MediaQuery.of(context).size.width * 0.08),
                                                    Expanded(
                                                      flex: 2,
                                                      child: Text(
                                                        request.status ?? "N/A",
                                                        style: TextStyle(
                                                            color: _statusColor(
                                                                request.status),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (isExpanded)
                                                Container(
                                                  padding: EdgeInsets.all(16),
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                        top: BorderSide(
                                                            color: Color(
                                                                0xFFDBE0E5))),
                                                    color: Colors.white,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets.only(left: 18),
                                                        child: Text("Details",
                                                            style: TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16)),
                                                      ),
                                                      SizedBox(height: 10),
                                                     _buildDetailRow(
                                                          "Property :",
                                                          request.rental
                                                                  ?.rentalAddress ??
                                                              "N/A"),
                                                      _buildDetailRow(
                                                          "Category :",
                                                          request.workCategory ??
                                                              "N/A"),
                                                     _buildCreatedOnDueDateRow(request),
                                                      SizedBox(height: 10),
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          _buildActionButton(request, index),
                                                        ],
                                                      ),
                                                                 
                                                    
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            // CRM-4837: the list slices to a page, so without this control the
                            // records past the first page were unreachable. Same shared footer
                            // the dashboard tables use. Sits AFTER the list, not inside the row
                            // builder — one footer per list, not one per row.
                            if (!_isLoading && _filteredBidRequests.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 11),
                                child: DashboardPaginationFooter(
                                  currentPage: _currentPage + 1,
                                  totalPages: _totalPages,
                                  rowsPerPage: _rowsPerPage,
                                  rowsPerPageOptions: const [10, 25, 50, 100],
                                  onRowsPerPageChanged: _changeRowsPerPage,
                                  onPrev: _currentPage == 0
                                      ? null
                                      : () => setState(() => _currentPage--),
                                  onNext: _currentPage < _totalPages - 1
                                      ? () => setState(() => _currentPage++)
                                      : null,
                                ),
                              ),
                ],
              ),
            )
          : NoInternetView(onRetry: retryNow),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0,horizontal: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: blueColor))),
          Expanded(child: Text(value, style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }

  Widget _buildActionButton(BidRequest request, int index) {
    final bool hasSubmitted = request.hasSubmitted == true;
    // Same lowercase comparison the server uses when it rejects a submission
    // (BidRequest.js: `(bidRequest.status || "").toLowerCase() === "closed"`),
    // so casing can never let the two disagree.
    final bool isClosed = (request.status ?? '').toLowerCase() == 'closed';
    final bool canBid = !hasSubmitted && !isClosed;
    return GestureDetector(
      onTap: () {
        // A disabled button says why instead of doing nothing: the vendor was
        // previously let into the whole form and only told at submit time.
        if (hasSubmitted) {
          Fluttertoast.showToast(msg: 'Bid Submitted');
          return;
        }
        if (isClosed) {
          Fluttertoast.showToast(msg: 'Bid Room Closed');
          return;
        }
        Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (context) => VendorSubmitBidScreen(bidRequest: request),
          ),
        ).then((refreshed) {
          if (refreshed == true) _fetchBidRequests();
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: hasSubmitted
            ? _actionBox(const Color(0xFFD1FADF), Icons.check_circle,
                const Color(0xFF039855))
            : !canBid
                ? _actionBox(const Color(0xFFF2F4F7), Icons.send_rounded,
                    const Color(0xFF98A2B3))
                : _actionBox(blueColor, Icons.send_rounded, Colors.white),
      ),
    );
  }

  /// One action button square, matching web's bid-row IconButton
  /// (borderRadius 7px, small icon).
  Widget _actionBox(Color background, IconData icon, Color foreground) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Center(child: Icon(icon, size: 18, color: foreground)),
    );
  }
}
