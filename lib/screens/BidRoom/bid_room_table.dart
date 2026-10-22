import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/provider/dateProvider.dart';
import 'package:three_zero_two_property/Model/bid_request.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/repository/bid_request.dart';
import 'package:three_zero_two_property/StaffModule/repository/bid_room_repository.dart';
import 'package:three_zero_two_property/StaffModule/widgets/custom_drawer.dart'
    as staff_drawer;
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart'
    as widget_302_staff;
import 'package:three_zero_two_property/widgets/appbar.dart' as widget_302;
import 'package:three_zero_two_property/widgets/titleBar.dart';
import 'package:three_zero_two_property/widgets/custom_drawer.dart';
import 'package:three_zero_two_property/widgets/CustomTableShimmer.dart';
import 'package:three_zero_two_property/screens/BidRoom/create_bid_room.dart';
import 'package:three_zero_two_property/repository/fetch_allcategories.dart';
import 'package:three_zero_two_property/Model/All_categories_model.dart';
import 'package:lottie/lottie.dart';
import 'package:three_zero_two_property/widgets/dashboard_pagination_footer.dart';

class BidRoomTable extends StatefulWidget {
  /// When true, uses staff drawer, staff app bar, and staff repository.
  final bool useStaffLayout;

  const BidRoomTable({super.key, this.useStaffLayout = false});

  @override
  State<BidRoomTable> createState() => _BidRoomTableState();
}

class _BidRoomTableState extends State<BidRoomTable>
    with NetworkRetryState {
  late final dynamic _repository;
  List<BidRequest> _bidRequests = [];
  List<BidRequest> _filteredBidRequests = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedTradeType;
  List<String> _tradeTypes = ['All'];
  int _currentPage = 0;
  int _rowsPerPage = 10;
  final TextEditingController _searchController = TextEditingController();
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool sorting1 = false;
  bool ascending1 = false;
  int? expandedIndex;
  String? expandedBidRequestId;
  Map<String, BidRequestDetail?> _bidRequestDetails = {};
  Map<String, bool> _loadingDetails = {};

  /// Required by [NetworkRetryState]: re-issue this screen's own load.
  /// The two loads initState makes; the repository choice it also makes is a
  /// one-time decision, not something a reload should redo.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    _fetchBidRequests();
    _loadAllTradeTypes();
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.useStaffLayout
        ? StaffBidRoomRepository()
        : BidRequestRepository();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    _fetchBidRequests();
    _loadAllTradeTypes();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
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
    setState(() {
      _connectivityResult = connectiondata;
    });
  }

  Future<void> _fetchBidRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _repository.fetchBidRequests(
        limit: 10000,
        page: 1,
      );

      if (mounted) {
        setState(() {
          _bidRequests = response.data ?? [];
          _extractTradeTypes();
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
        // which says it better than a toast stacked on top of it. Anything
        // else still gets the clean message.
        if (!isNetworkError(e)) {
          Fluttertoast.showToast(msg: friendlyErrorMessage(e));
        }
      }
    }
  }

  void _extractTradeTypes() {
    // Keep existing bid request types merged with any already-loaded API types
    Set<String> types = {'All'};
    for (var t in _tradeTypes) {
      if (t != 'All') types.add(t);
    }
    for (var request in _bidRequests) {
      if (request.workCategory != null && request.workCategory!.isNotEmpty) {
        types.add(request.workCategory!);
      }
    }
    _tradeTypes = types.toList()..sort();
  }

  Future<void> _loadAllTradeTypes() async {
    try {
      final result = await FetchAllcategories().fetchAllCategories();
      if (mounted) {
        setState(() {
          final Set<String> types = {'All'};
          for (var c in result) {
            if (c.name != null && c.name!.isNotEmpty && c.isDelete != true)
              types.add(c.name!);
          }
          for (var t in _tradeTypes) {
            if (t != 'All') types.add(t);
          }
          _tradeTypes = types.toList()..sort();
        });
      }
    } catch (_) {}
  }

  void _applyFilters() {
    _filteredBidRequests = _bidRequests.where((request) {
      // Search filter
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        matchesSearch = (request.rental?.rentalAddress ?? '')
                .toLowerCase()
                .contains(searchLower) ||
            (request.workCategory ?? '').toLowerCase().contains(searchLower) ||
            (request.description ?? '').toLowerCase().contains(searchLower) ||
            (request.unit?.rentalUnit ?? '')
                .toLowerCase()
                .contains(searchLower);
      }

      // Trade type filter
      bool matchesTradeType = true;
      if (_selectedTradeType != null && _selectedTradeType != 'All') {
        matchesTradeType = request.workCategory == _selectedTradeType;
      }

      return matchesSearch && matchesTradeType;
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

  void sortData(List<BidRequest> data) {
    if (sorting1) {
      data.sort((a, b) {
        String aTitle = _getBidRoomTitle(a);
        String bTitle = _getBidRoomTitle(b);
        return ascending1
            ? aTitle.toLowerCase().compareTo(bTitle.toLowerCase())
            : bTitle.toLowerCase().compareTo(aTitle.toLowerCase());
      });
    }
  }

  String _getBidRoomTitle(BidRequest request) {
    String address = request.rental?.rentalAddress ?? 'N/A';
    return address;
  }

  String _formatDate(BuildContext context, String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      return Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDate(dateStr);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatDateTime(BuildContext context, String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      return Provider.of<DateProvider>(context, listen: false)
          .formatCurrentDateTime(dateStr);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _fetchBidRequestDetails(String bidRequestId) async {
    // Don't fetch if already loaded or currently loading
    if (_bidRequestDetails.containsKey(bidRequestId) ||
        _loadingDetails[bidRequestId] == true) {
      return;
    }

    setState(() {
      _loadingDetails[bidRequestId] = true;
    });

    try {
      final response = await _repository.fetchBidRequestDetails(
        bidRequestId: bidRequestId,
      );

      if (mounted) {
        setState(() {
          _bidRequestDetails[bidRequestId] = response.data;
          _loadingDetails[bidRequestId] = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingDetails[bidRequestId] = false;
        });
        if (!isNetworkError(e)) {
          Fluttertoast.showToast(msg: friendlyErrorMessage(e));
        }
      }
    }
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

  Future<void> _deleteBidRequest(String bidRequestId, String reason) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString("adminId");
    String? token = prefs.getString('token');
    // Header `id` = the logged-in user's OWN id (web parity): Staff → staff_id,
    // Admin → adminId.
    String? headerId =
        widget.useStaffLayout ? prefs.getString("staff_id") : id;

    try {
      final response = await apiDelete(
        Uri.parse('${Api_url}/api/bid-request/bid-request/$bidRequestId'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $headerId",
          "Content-Type": "application/json",
        },
        body: json.encode({"reason": reason}),
      );

      final responseBody = json.decode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: responseBody['message'] ?? 'Bid Room deleted successfully',
          toastLength: Toast.LENGTH_SHORT,
        );
        if (mounted) {
          setState(() {
            expandedIndex = null;
            expandedBidRequestId = null;
          });
          _fetchBidRequests();
        }
      } else {
        Fluttertoast.showToast(
          msg: responseBody['message'] ?? 'Failed to delete bid room',
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error deleting bid room: ${friendlyErrorMessage(e)}',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  void _showDeleteDialog(BuildContext context, BidRequest request) {
    final TextEditingController reasonController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Orange warning icon circle
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.orange,
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Title
                    const Text(
                      'Are you sure?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Subtitle
                    Text(
                      'Once deleted, you will not be able to recover this bid room!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Reason text field
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        hintText: 'Enter reason for deletion',
                        hintStyle:
                            TextStyle(fontSize: 13, color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFDBE0E5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFDBE0E5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: blueColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    // Buttons row
                    Row(
                      children: [
                        // Delete button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: isDeleting
                                ? null
                                : () async {
                                    final reason =
                                        reasonController.text.trim();
                                    if (reason.isEmpty) {
                                      Fluttertoast.showToast(
                                          msg: 'Please enter a reason');
                                      return;
                                    }
                                    setDialogState(
                                        () => isDeleting = true);
                                    Navigator.of(dialogContext).pop();
                                    await _deleteBidRequest(
                                        request.bidRequestId!, reason);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: blueColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: isDeleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cancel button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDeleting
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: blueColor,
                              side: BorderSide(color: blueColor),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
              flex: 3,
              child: InkWell(
                child: Row(
                  children: [
                    width < 400
                        ? Text("  #",
                            style: TextStyle(
                                color: blueColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold))
                        : Text("  #",
                            style: TextStyle(
                                color: blueColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
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
                        style: TextStyle(
                            color: blueColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 5),
                    ascending1
                        ? Padding(
                            padding: const EdgeInsets.only(top: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortUp,
                              size: 20,
                              color: blueColor,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 7, left: 2),
                            child: FaIcon(
                              FontAwesomeIcons.sortDown,
                              size: 20,
                              color: blueColor,
                            ),
                          ),
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
      appBar: widget.useStaffLayout
          ? widget_302_staff.widget_302_Staff.App_Bar(context: context)
          : widget_302.widget_302.App_Bar(context: context),
      backgroundColor: Colors.white,
      drawer: widget.useStaffLayout
          ? staff_drawer.CustomDrawerStaff(
              currentpage: "Bid Room",
              dropdown: false,
            )
          : CustomDrawer(
              currentpage: "Bid Room",
              dropdown: false,
            ),
      body: !isOffline
          ? SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Header Section with Title and Add Button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 13),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: titleBar(
                              width: double.infinity,
                              title: 'Bid Room',
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: GestureDetector(
                              onTap: () async {
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CreateBidRoom(
                                        useStaffLayout: widget.useStaffLayout),
                                  ),
                                );
                                if (result == true) {
                                  setState(() {
                                    _fetchBidRequests();
                                  });
                                }
                              },
                              child: Container(
                                height:
                                    (MediaQuery.of(context).size.width < 768)
                                        ? 50
                                        : 60,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Center(
                                  child: Text(
                                    "+ Add",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (MediaQuery.of(context).size.width < 500)
                          SizedBox(width: 3),
                        if (MediaQuery.of(context).size.width > 500)
                          SizedBox(width: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Search and Filter section
                  Padding(
                    padding: const EdgeInsets.only(left: 11, right: 11),
                    child: Row(
                      children: [
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 18),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            height: MediaQuery.of(context).size.width < 500
                                ? 45
                                : 50,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFDBE0E5))),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: TextField(
                                    controller: _searchController,
                                    style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    500
                                                ? 12
                                                : 14),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                        if (_currentPage != 0) _currentPage = 0;
                                        _applyFilters();
                                      });
                                    },
                                    cursorColor: blueColor,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Search here...",
                                      hintStyle: TextStyle(
                                          color: const Color(0xFF495160),
                                          fontWeight: FontWeight.bold,
                                          fontSize: MediaQuery.of(context)
                                                      .size
                                                      .width <
                                                  500
                                              ? 14
                                              : 18),
                                      contentPadding: (const EdgeInsets.only(
                                          left: 5, bottom: 12, top: 5)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: Text(
                                'Trade Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF495160),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              items: _tradeTypes.map((String item) {
                                final bool isSelected =
                                    _selectedTradeType == item ||
                                        (_selectedTradeType == null &&
                                            item == 'All');
                                return DropdownMenuItem<String>(
                                  value: item,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 16,
                                        color: isSelected
                                            ? blueColor
                                            : Colors.transparent,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? blueColor
                                                : Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              value: _selectedTradeType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedTradeType = value;
                                  if (_currentPage != 0) _currentPage = 0;
                                  _applyFilters();
                                });
                              },
                              buttonStyleData: ButtonStyleData(
                                height: MediaQuery.of(context).size.width < 500
                                    ? 48
                                    : 54,
                                width: MediaQuery.of(context).size.width < 500
                                    ? MediaQuery.of(context).size.width * .37
                                    : MediaQuery.of(context).size.width * .4,
                                padding:
                                    const EdgeInsets.only(left: 14, right: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFDBE0E5),
                                  ),
                                  color: Colors.white,
                                ),
                                elevation: 0,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 320,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.white,
                                  border: Border.all(
                                      color: const Color(0xFFDBE0E5)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                offset: const Offset(0, 4),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(8),
                                  thickness: MaterialStateProperty.all(4),
                                  thumbVisibility:
                                      MaterialStateProperty.all(true),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 48,
                                padding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ),
                        ),
                        if (MediaQuery.of(context).size.width < 500)
                          const SizedBox(width: 2),
                        if (MediaQuery.of(context).size.width > 500)
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (MediaQuery.of(context).size.width > 500)
                    const SizedBox(height: 25),
                  if (MediaQuery.of(context).size.width < 500)
                    Padding(
                      padding: EdgeInsets.all(
                          MediaQuery.of(context).size.width < 500 ? 11 : 28),
                      child: _isLoading
                          ? ColabShimmerLoadingWidget()
                          : _filteredBidRequests.isEmpty
                              ? Container(
                                  height:
                                      MediaQuery.of(context).size.height * .5,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          "assets/images/no_data.jpg",
                                          height: 200,
                                          width: 200,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          // CRM-4365 parity: this state is reached BOTH when there are no
                                          // bid rooms at all and when a search or filter matched none of
                                          // them. Telling a user with 12 records "No Data Available"
                                          // reads as data loss, so the two cases now say different things.
                                          (_searchQuery.isNotEmpty ||
                (_selectedTradeType != null && _selectedTradeType != 'All'))
                                              ? "No Results Found"
                                              : "No Bid Rooms Yet",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: blueColor,
                                              fontSize: 16),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 2),
                                      _buildHeaders(),
                                      const SizedBox(height: 10),
                                      Container(
                                        child: Column(
                                          children: _pagedData
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int index = entry.key;
                                            BidRequest request = entry.value;
                                            bool isExpanded =
                                                expandedIndex == index;

                                            // Find the correct index for expanded bid request by ID
                                            if (expandedBidRequestId != null) {
                                              int? foundIndex;
                                              for (int i = 0;
                                                  i < _pagedData.length;
                                                  i++) {
                                                if (_pagedData[i].id ==
                                                    expandedBidRequestId) {
                                                  foundIndex = i;
                                                  break;
                                                }
                                              }
                                              if (foundIndex != null &&
                                                  foundIndex != expandedIndex) {
                                                expandedIndex = foundIndex;
                                                isExpanded =
                                                    expandedIndex == index;
                                              } else if (foundIndex == null) {
                                                expandedIndex = null;
                                                expandedBidRequestId = null;
                                                isExpanded = false;
                                              }
                                            }

                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (expandedIndex == index) {
                                                    expandedIndex = null;
                                                    expandedBidRequestId = null;
                                                  } else {
                                                    expandedIndex = index;
                                                    expandedBidRequestId =
                                                        request.id;
                                                    // Fetch details when expanding
                                                    if (request.bidRequestId !=
                                                        null) {
                                                      _fetchBidRequestDetails(
                                                          request
                                                              .bidRequestId!);
                                                    }
                                                  }
                                                });
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: index % 2 != 0
                                                      ? const Color(0xFFF4F8FF)
                                                      : Colors.white,
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFDBE0E5)),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Column(
                                                  children: [
                                                    ListTile(
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8),
                                                      title: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: <Widget>[
                                                          InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                if (expandedIndex ==
                                                                    index) {
                                                                  expandedIndex =
                                                                      null;
                                                                  expandedBidRequestId =
                                                                      null;
                                                                } else {
                                                                  expandedIndex =
                                                                      index;
                                                                  expandedBidRequestId =
                                                                      request
                                                                          .id;
                                                                  // Fetch details when expanding
                                                                  if (request
                                                                          .bidRequestId !=
                                                                      null) {
                                                                    _fetchBidRequestDetails(
                                                                        request
                                                                            .bidRequestId!);
                                                                  }
                                                                }
                                                              });
                                                            },
                                                            child: Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5,
                                                                      right: 5),
                                                              padding: !isExpanded
                                                                  ? const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          10)
                                                                  : const EdgeInsets
                                                                      .only(
                                                                      top: 10),
                                                              child: FaIcon(
                                                                isExpanded
                                                                    ? FontAwesomeIcons
                                                                        .sortUp
                                                                    : FontAwesomeIcons
                                                                        .sortDown,
                                                                size: 20,
                                                                color:
                                                                    blueColor,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            flex: 3,
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

                                                          Expanded(
                                                            flex: 3,
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  if (expandedIndex ==
                                                                      index) {
                                                                    expandedIndex =
                                                                        null;
                                                                    expandedBidRequestId =
                                                                        null;
                                                                  } else {
                                                                    expandedIndex =
                                                                        index;
                                                                    expandedBidRequestId =
                                                                        request
                                                                            .id;
                                                                    // Fetch details when expanding
                                                                    if (request
                                                                            .bidRequestId !=
                                                                        null) {
                                                                      _fetchBidRequestDetails(
                                                                          request
                                                                              .bidRequestId!);
                                                                    }
                                                                  }
                                                                });
                                                              },
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    _getBidRoomTitle(
                                                                        request),
                                                                    style:
                                                                        TextStyle(
                                                                      color:
                                                                          blueColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                  if ((request.description ??
                                                                          '')
                                                                      .isNotEmpty)
                                                                    Text(
                                                                      request
                                                                          .description!,
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .lightBlue,
                                                                        fontSize:
                                                                            11,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          SizedBox(width: 5),

                                                          // Container(
                                                          //   height: 35,
                                                          //   width: 35,
                                                          //   padding: const EdgeInsets.all(5),
                                                          //   decoration: BoxDecoration(
                                                          //     borderRadius: BorderRadius.circular(8),
                                                          //     color: request.status == "Open"
                                                          //         ? Colors.greenAccent.shade100
                                                          //         : Colors.redAccent.withOpacity(0.3),
                                                          //   ),
                                                          //   child: Center(
                                                          //     child: Icon(
                                                          //       request.status == "Open"
                                                          //           ? Icons.check_circle
                                                          //           : Icons.lock_rounded,
                                                          //       color: request.status == "Open"
                                                          //           ? Colors.green
                                                          //           : Colors.red,
                                                          //       size: 18,
                                                          //     ),
                                                          //   ),
                                                          // ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isExpanded)
                                                      Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                          border: Border(
                                                            top: BorderSide(
                                                              color: Color(
                                                                  0xFFDBE0E5),
                                                              width: 1,
                                                            ),
                                                          ),
                                                        ),
                                                        child:
                                                            SingleChildScrollView(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(8.0),
                                                            child: Column(
                                                              children: [
                                                                Row(
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
                                                                      child:
                                                                          Table(
                                                                        columnWidths: {
                                                                          0: const FlexColumnWidth(),
                                                                          1: const FlexColumnWidth(),
                                                                        },
                                                                        children: [
                                                                          _buildTableRow(
                                                                            'Trade Type:',
                                                                            request.workCategory ??
                                                                                'N/A',
                                                                            'Created On:',
                                                                            _formatDate(context,
                                                                                request.createdAt),
                                                                          ),
                                                                          _buildTableRow(
                                                                            'Due Date:',
                                                                            _formatDate(context,
                                                                                request.dueDate),
                                                                            'Status:',
                                                                            request.status ??
                                                                                'N/A',
                                                                          ),
                                                                          _buildTableRow(
                                                                            'Submissions:',
                                                                            '${request.submissionCount ?? 0}',
                                                                            '',
                                                                            '',
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                // Submissions section
                                                                if (request
                                                                        .bidRequestId !=
                                                                    null)
                                                                  _buildSubmissionsSection(
                                                                      request
                                                                          .bidRequestId!),
                                                                const SizedBox(
                                                                    height: 10),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .end,
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        // TODO: View bid room details
                                                                        Fluttertoast.showToast(
                                                                            msg:
                                                                                'View Bid Room feature coming soon');
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          color: Colors
                                                                              .grey
                                                                              .shade200,
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(
                                                                              FontAwesomeIcons.eye,
                                                                              size: 15,
                                                                              color: Colors.black87,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            5),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () async {
                                                                        final result =
                                                                            await Navigator.of(context).push(
                                                                          MaterialPageRoute(
                                                                            builder: (context) =>
                                                                                CreateBidRoom(
                                                                              useStaffLayout: widget.useStaffLayout,
                                                                              existingBidRequest: request,
                                                                            ),
                                                                          ),
                                                                        );
                                                                        if (result ==
                                                                            true) {
                                                                          setState(() =>
                                                                              _fetchBidRequests());
                                                                        }
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          color: Colors
                                                                              .green
                                                                              .shade50,
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(
                                                                              FontAwesomeIcons.edit,
                                                                              size: 15,
                                                                              color: Colors.green,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            5),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        if (request.bidRequestId != null) {
                                                                          _showDeleteDialog(context, request);
                                                                        }
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          color: Colors
                                                                              .red
                                                                              .shade50,
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(
                                                                              FontAwesomeIcons.trashCan,
                                                                              size: 15,
                                                                              color: Colors.red,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
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
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                    // CRM-4837: the list slices to a page, so without this control the
                    // records past the first page were unreachable. Same shared footer
                    // the dashboard tables use. Sits AFTER the list, not inside the row
                    // builder — one footer per list, not one per row.
                    if (MediaQuery.of(context).size.width < 500 &&
                        !_isLoading &&
                        _filteredBidRequests.isNotEmpty)
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
                  if (MediaQuery.of(context).size.width > 500)
                    Padding(
                      padding: const EdgeInsets.only(left: 11, right: 11),
                      child: _isLoading
                          ? ColabShimmerLoadingWidget()
                          : _filteredBidRequests.isEmpty
                              ? Container(
                                  height:
                                      MediaQuery.of(context).size.height * .5,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          "assets/images/no_data.jpg",
                                          height: 200,
                                          width: 200,
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          // CRM-4365 parity: this state is reached BOTH when there are no
                                          // bid rooms at all and when a search or filter matched none of
                                          // them. Telling a user with 12 records "No Data Available"
                                          // reads as data loss, so the two cases now say different things.
                                          (_searchQuery.isNotEmpty ||
                (_selectedTradeType != null && _selectedTradeType != 'All'))
                                              ? "No Results Found"
                                              : "No Bid Rooms Yet",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: blueColor,
                                              fontSize: 16),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              : SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 2),
                                      _buildHeaders(),
                                      const SizedBox(height: 10),
                                      Container(
                                        child: Column(
                                          children: _pagedData
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int index = entry.key;
                                            BidRequest request = entry.value;
                                            bool isExpanded =
                                                expandedIndex == index;

                                            // Find the correct index for expanded bid request by ID
                                            if (expandedBidRequestId != null) {
                                              int? foundIndex;
                                              for (int i = 0;
                                                  i < _pagedData.length;
                                                  i++) {
                                                if (_pagedData[i].id ==
                                                    expandedBidRequestId) {
                                                  foundIndex = i;
                                                  break;
                                                }
                                              }
                                              if (foundIndex != null &&
                                                  foundIndex != expandedIndex) {
                                                expandedIndex = foundIndex;
                                                isExpanded =
                                                    expandedIndex == index;
                                              } else if (foundIndex == null) {
                                                expandedIndex = null;
                                                expandedBidRequestId = null;
                                                isExpanded = false;
                                              }
                                            }

                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (expandedIndex == index) {
                                                    expandedIndex = null;
                                                    expandedBidRequestId = null;
                                                  } else {
                                                    expandedIndex = index;
                                                    expandedBidRequestId =
                                                        request.id;
                                                    // Fetch details when expanding
                                                    if (request.bidRequestId !=
                                                        null) {
                                                      _fetchBidRequestDetails(
                                                          request
                                                              .bidRequestId!);
                                                    }
                                                  }
                                                });
                                              },
                                              child: Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: index % 2 != 0
                                                      ? const Color(0xFFF4F8FF)
                                                      : Colors.white,
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xFFDBE0E5)),
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
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: <Widget>[
                                                          // The shared _buildHeaders() renders a "#" column for this layout
                                                          // too, but the row had no cell beneath it — so the header sat over an
                                                          // empty column. Same reference the narrow layout shows.
                                                          Expanded(
                                                            flex: 3,
                                                            child: Text(
                                                              "BR${request.bidRequestNo ?? ''}",
                                                              textAlign: TextAlign.center,
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: blueColor),
                                                            ),
                                                          ),
                                                          InkWell(
                                                            onTap: () {
                                                              setState(() {
                                                                if (expandedIndex ==
                                                                    index) {
                                                                  expandedIndex =
                                                                      null;
                                                                  expandedBidRequestId =
                                                                      null;
                                                                } else {
                                                                  expandedIndex =
                                                                      index;
                                                                  expandedBidRequestId =
                                                                      request
                                                                          .id;
                                                                  // Fetch details when expanding
                                                                  if (request
                                                                          .bidRequestId !=
                                                                      null) {
                                                                    _fetchBidRequestDetails(
                                                                        request
                                                                            .bidRequestId!);
                                                                  }
                                                                }
                                                              });
                                                            },
                                                            child: Container(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 5,
                                                                      right: 5),
                                                              padding: !isExpanded
                                                                  ? const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          10)
                                                                  : const EdgeInsets
                                                                      .only(
                                                                      top: 10),
                                                              child: FaIcon(
                                                                isExpanded
                                                                    ? FontAwesomeIcons
                                                                        .sortUp
                                                                    : FontAwesomeIcons
                                                                        .sortDown,
                                                                size: 20,
                                                                color:
                                                                    blueColor,
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: InkWell(
                                                              onTap: () {
                                                                setState(() {
                                                                  if (expandedIndex ==
                                                                      index) {
                                                                    expandedIndex =
                                                                        null;
                                                                    expandedBidRequestId =
                                                                        null;
                                                                  } else {
                                                                    expandedIndex =
                                                                        index;
                                                                    expandedBidRequestId =
                                                                        request
                                                                            .id;
                                                                    // Fetch details when expanding
                                                                    if (request
                                                                            .bidRequestId !=
                                                                        null) {
                                                                      _fetchBidRequestDetails(
                                                                          request
                                                                              .bidRequestId!);
                                                                    }
                                                                  }
                                                                });
                                                              },
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Text(
                                                                    _getBidRoomTitle(
                                                                        request),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                    style:
                                                                        TextStyle(
                                                                      color:
                                                                          blueColor,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      fontSize:
                                                                          13,
                                                                    ),
                                                                  ),
                                                                  if ((request.description ??
                                                                          '')
                                                                      .isNotEmpty)
                                                                    Text(
                                                                      request
                                                                          .description!,
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style:
                                                                          TextStyle(
                                                                        color: Colors
                                                                            .lightBlue,
                                                                        fontSize:
                                                                            11,
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Status icon (padlock or other status)
                                                          Container(
                                                            height: 35,
                                                            width: 35,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(5),
                                                            decoration:
                                                                BoxDecoration(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                              color: request
                                                                          .status ==
                                                                      "Open"
                                                                  ? Colors
                                                                      .greenAccent
                                                                      .shade100
                                                                  : Colors
                                                                      .redAccent
                                                                      .withOpacity(
                                                                          0.3),
                                                            ),
                                                            child: Center(
                                                              child: Icon(
                                                                request.status ==
                                                                        "Open"
                                                                    ? Icons
                                                                        .check_circle
                                                                    : Icons
                                                                        .lock_rounded,
                                                                color: request.status ==
                                                                        "Open"
                                                                    ? Colors
                                                                        .green
                                                                    : Colors
                                                                        .red,
                                                                size: 18,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isExpanded)
                                                      Container(
                                                        decoration:
                                                            const BoxDecoration(
                                                          border: Border(
                                                            top: BorderSide(
                                                              color: Color(
                                                                  0xFFDBE0E5),
                                                              width: 1,
                                                            ),
                                                          ),
                                                        ),
                                                        child:
                                                            SingleChildScrollView(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(16.0),
                                                            child: Column(
                                                              children: [
                                                                Row(
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
                                                                      child:
                                                                          Table(
                                                                        columnWidths: {
                                                                          0: const FlexColumnWidth(),
                                                                          1: const FlexColumnWidth(),
                                                                        },
                                                                        children: [
                                                                          _buildTableRow(
                                                                            'Trade Type:',
                                                                            request.workCategory ??
                                                                                'N/A',
                                                                            'Created On:',
                                                                            _formatDate(context,
                                                                                request.createdAt),
                                                                          ),
                                                                          _buildTableRow(
                                                                            'Due Date:',
                                                                            _formatDate(context,
                                                                                request.dueDate),
                                                                            'Status:',
                                                                            request.status ??
                                                                                'N/A',
                                                                          ),
                                                                          _buildTableRow(
                                                                            'Submissions:',
                                                                            '${request.submissionCount ?? 0}',
                                                                            '',
                                                                            '',
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                // Submissions section
                                                                if (request
                                                                        .bidRequestId !=
                                                                    null)
                                                                  _buildSubmissionsSection(
                                                                      request
                                                                          .bidRequestId!),
                                                                const SizedBox(
                                                                    height: 10),
                                                                Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .end,
                                                                  children: [
                                                                    const SizedBox(
                                                                        width:
                                                                            12),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        // TODO: View bid room details
                                                                        Fluttertoast.showToast(
                                                                            msg:
                                                                                'View Bid Room feature coming soon');
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          color: Colors
                                                                              .grey
                                                                              .shade200,
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(
                                                                              FontAwesomeIcons.eye,
                                                                              size: 15,
                                                                              color: Colors.black87,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            5),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () async {
                                                                        final result =
                                                                            await Navigator.of(context).push(
                                                                          MaterialPageRoute(
                                                                            builder: (context) =>
                                                                                CreateBidRoom(
                                                                              useStaffLayout: widget.useStaffLayout,
                                                                              existingBidRequest: request,
                                                                            ),
                                                                          ),
                                                                        );
                                                                        if (result ==
                                                                            true) {
                                                                          setState(() =>
                                                                              _fetchBidRequests());
                                                                        }
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          color: Colors
                                                                              .green
                                                                              .shade50,
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(
                                                                              FontAwesomeIcons.edit,
                                                                              size: 15,
                                                                              color: Colors.green,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            5),
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        if (request.bidRequestId != null) {
                                                                          _showDeleteDialog(context, request);
                                                                        }
                                                                      },
                                                                      child:
                                                                          Container(
                                                                        height:
                                                                            35,
                                                                        width:
                                                                            35,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          color: Colors
                                                                              .red
                                                                              .shade50,
                                                                        ),
                                                                        child:
                                                                            const Row(
                                                                          mainAxisAlignment:
                                                                              MainAxisAlignment.center,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.center,
                                                                          children: [
                                                                            FaIcon(
                                                                              FontAwesomeIcons.trashCan,
                                                                              size: 15,
                                                                              color: Colors.red,
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
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
                                          }).toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                    // CRM-4837: the list slices to a page, so without this control the
                    // records past the first page were unreachable. Same shared footer
                    // the dashboard tables use. Sits AFTER the list, not inside the row
                    // builder — one footer per list, not one per row.
                    if (MediaQuery.of(context).size.width > 500 &&
                        !_isLoading &&
                        _filteredBidRequests.isNotEmpty)
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

  TableRow _buildTableRow(String leftLabel, String leftValue, String rightLabel,
      String rightValue) {
    return TableRow(
      children: [
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leftLabel.isNotEmpty)
                  Text(
                    leftLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                if (leftLabel.isNotEmpty) const SizedBox(height: 4.0),
                Text(
                  leftValue,
                  style: TextStyle(color: grey),
                ),
              ],
            ),
          ),
        ),
        TableCell(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rightLabel.isNotEmpty)
                  Text(
                    rightLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),
                if (rightLabel.isNotEmpty) const SizedBox(height: 4.0),
                if (rightValue.isNotEmpty)
                  Text(
                    rightValue,
                    style: TextStyle(color: grey),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionsSection(String bidRequestId) {
    final detail = _bidRequestDetails[bidRequestId];
    final isLoading = _loadingDetails[bidRequestId] == true;

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: SpinKitFadingCircle(color: blueColor, size: 25),
        ),
      );
    }

    if (detail == null ||
        detail.submissions == null ||
        detail.submissions!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          'No submissions available',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Bid Room Submissions (${detail.submissions!.length})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: blueColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        ...detail.submissions!.map((submission) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VENDOR NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            submission.vendorName ?? 'N/A',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: blueColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'TOTAL PRICE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(submission.totalPrice),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUBMITTED AT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // Web parity (BidRequests.jsx): submitted_at, else createdAt.
                            _formatDateTime(
                                context,
                                (submission.submittedAt?.isNotEmpty ?? false)
                                    ? submission.submittedAt
                                    : submission.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'STATUS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              submission.status ?? 'N/A',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 12),
                // SizedBox(
                //   width: double.infinity,
                //   child: ElevatedButton.icon(
                //     onPressed: () {
                //       // TODO: Show price breakdown
                //       Fluttertoast.showToast(
                //           msg: 'View Breakdown feature coming soon');
                //     },
                //     icon: FaIcon(
                //       FontAwesomeIcons.eye,
                //       size: 14,
                //     ),
                //     label: Text('View Breakdown'),
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.white,
                //       foregroundColor: blueColor,
                //       elevation: 0,
                //       side: BorderSide(color: blueColor),
                //       padding: const EdgeInsets.symmetric(vertical: 8),
                //     ),
                //   ),
                // ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
