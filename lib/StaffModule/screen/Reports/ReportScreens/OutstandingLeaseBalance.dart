import 'dart:async';
import 'package:three_zero_two_property/services/app_log.dart';
import 'package:three_zero_two_property/services/csv_row.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:three_zero_two_property/Model/OutstandingLeaseBalanceModel.dart';
import 'package:three_zero_two_property/constant/constant.dart';
import 'package:three_zero_two_property/StaffModule/repository/OutstandingLeaseBalanceService.dart';
import 'package:three_zero_two_property/StaffModule/widgets/appbar.dart';
import 'package:three_zero_two_property/StaffModule/widgets/staff_report_header.dart';
import 'package:intl/intl.dart';
import '../../../../widgets/custom_drawer.dart';
import '../../../widgets/custom_drawer.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:three_zero_two_property/services/api_helpers.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as syncXlsx;
import 'package:fluttertoast/fluttertoast.dart';
import '../../../repository/GetAdminAddressPdf.dart';
import 'package:three_zero_two_property/Model/profile.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:three_zero_two_property/widgets/no_internet_view.dart';
import 'package:three_zero_two_property/provider/network_retry_state.dart';

class OutstandingLeaseBalance extends StatefulWidget {
  @override
  State<OutstandingLeaseBalance> createState() =>
      _OutstandingLeaseBalanceState();
}

class _OutstandingLeaseBalanceState extends State<OutstandingLeaseBalance>
    with NetworkRetryState {
  late Future<OutstandingLeaseBalanceModel> _futureOutstandingLeaseBalance;
  OutstandingLeaseBalanceModel? outstandingLeaseBalanceModel;
  bool isLoading = false;
  String? errorMessage;
  int? expandedRowIndex;
  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // Pagination and filtering
  int _currentPage = 1;
  int _limit = 10;
  String _statusFilter = 'all';
  String? _rentalOwnerFilter;
  String _sortBy = 'property_address';
  String _sortOrder = 'asc';
  String _searchValue = "";

  // Rental owners list
  List<Map<String, dynamic>> _rentalOwners = [];
  List<String> selectedRentalOwnerIds = [];
  final ValueNotifier<List<String>> _selectedOwnersNotifier =
      ValueNotifier<List<String>>([]);

  /// Required by [NetworkRetryState]: re-issue this screen's own load,
  /// called by the Retry button and when the connection comes back.
  @override
  Future<void> reloadData() async {
    if (!mounted) return;
    // Exactly what initState loads. The report itself waits for Run, by web
    // parity, so a reload must not fire it with an owner scope that is not
    // ready yet.
    await _fetchRentalOwners();
  }

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (!mounted) return;
      // The event is only a trigger: checkInternet() verifies
      // against the network before deciding, so a stale `none`
      // from the plugin cannot strand this screen offline.
      checkInternet();
    });
    checkInternet();
    // Web parity: do not auto-load the report on open. The rental-owner scope
    // is not ready on the first frame, so an initial fetch would omit the owner
    // filter and return unscoped data. Load the owners now (all selected) and
    // wait for the user to tap Run to fetch the correctly scoped report.
    _futureOutstandingLeaseBalance =
        Future.value(OutstandingLeaseBalanceModel(success: true));
    _fetchRentalOwners();
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

  Future<OutstandingLeaseBalanceModel>
      fetchOutstandingLeaseBalanceData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString("adminId");

      if (adminId == null) {
        setState(() {
          isLoading = false;
          errorMessage = 'Admin ID not found. Please login again.';
        });
        return OutstandingLeaseBalanceModel(
          success: false,
          message: 'Admin ID not found. Please login again.',
        );
      }

      OutstandingLeaseBalanceModel data =
          await OutstandingLeaseBalanceService().fetchOutstandingLeaseBalance(
        adminId: adminId,
        statusFilter: _statusFilter,
        rentalOwnerFilter: _rentalOwnerFilter,
        page: _currentPage,
        limit: _limit,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      setState(() {
        outstandingLeaseBalanceModel = data;
        isLoading = false;
        errorMessage = data.success == false ? data.message : null;
      });
      return data;
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage =
            'Failed to load outstanding lease balance data. Please try again later.';
      });
      return OutstandingLeaseBalanceModel(
        success: false,
        message:
            'Failed to load outstanding lease balance data. Please try again later.',
      );
    }
  }

  // Fetch ALL data for export (without pagination)
  Future<List<OutstandingLeaseBalanceData>> fetchAllDataForExport() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? adminId = prefs.getString("adminId");

      if (adminId == null) {
        return [];
      }

      List<OutstandingLeaseBalanceData> allData = [];
      int currentPage = 1;
      int limit = 1000; // Fetch large batches
      bool hasMoreData = true;

      while (hasMoreData) {
        OutstandingLeaseBalanceModel data =
            await OutstandingLeaseBalanceService().fetchOutstandingLeaseBalance(
          adminId: adminId,
          statusFilter: _statusFilter,
          rentalOwnerFilter: _rentalOwnerFilter,
          page: currentPage,
          limit: limit,
          sortBy: _sortBy,
          sortOrder: _sortOrder,
        );

        if (data.success == true &&
            data.data != null &&
            data.data!.isNotEmpty) {
          allData.addAll(data.data!);

          // Check if there are more pages
          if (data.pagination != null) {
            int totalPages = data.pagination!.totalPages ?? 1;
            if (currentPage >= totalPages) {
              hasMoreData = false;
            } else {
              currentPage++;
            }
          } else {
            // If no pagination info, assume no more data if returned less than limit
            if (data.data!.length < limit) {
              hasMoreData = false;
            } else {
              currentPage++;
            }
          }
        } else {
          hasMoreData = false;
        }
      }

      return allData;
    } catch (e) {
      logError('Error fetching all data for export: $e');
      return [];
    }
  }

  void _refreshData() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    _futureOutstandingLeaseBalance = fetchOutstandingLeaseBalanceData();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      isLoading = true;
    });
    _futureOutstandingLeaseBalance = fetchOutstandingLeaseBalanceData();
  }

  void _onSort(String column) {
    setState(() {
      if (_sortBy == column) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortBy = column;
        _sortOrder = 'asc';
      }
      isLoading = true;
    });
    _futureOutstandingLeaseBalance = fetchOutstandingLeaseBalanceData();
  }

  void _onSearch(String value) {
    setState(() {
      _searchValue = value;
      _currentPage = 1; // Reset to first page when searching
      isLoading = true;
    });
    _futureOutstandingLeaseBalance = fetchOutstandingLeaseBalanceData();
  }

  List<OutstandingLeaseBalanceData> _getFilteredData() {
    if (outstandingLeaseBalanceModel?.data == null) return [];

    if (_searchValue.isEmpty) {
      return outstandingLeaseBalanceModel!.data!;
    }

    return outstandingLeaseBalanceModel!.data!.where((item) {
      return item.tenantNames
                  ?.toLowerCase()
                  .contains(_searchValue.toLowerCase()) ==
              true ||
          item.propertyAddress
                  ?.toLowerCase()
                  .contains(_searchValue.toLowerCase()) ==
              true ||
          item.leaseId?.toLowerCase().contains(_searchValue.toLowerCase()) ==
              true;
    }).toList();
  }

  Future<void> _fetchRentalOwners() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString("adminId");
      String? token = prefs.getString('token');
      String? staffId = prefs.getString('staff_id');
      final response = await apiGet(
        Uri.parse('$Api_url/api/rentals/rental-owners/$id'),
        headers: {
          "authorization": "CRM $token",
          "id": "CRM $staffId",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _rentalOwners = (jsonDecode(response.body) as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();

          // Sort rental owners alphabetically by name
          _rentalOwners.sort((a, b) {
            String nameA = a['rentalOwner_name']?.toString() ?? '';
            String nameB = b['rentalOwner_name']?.toString() ?? '';
            return nameA.toLowerCase().compareTo(nameB.toLowerCase());
          });

          // Insert "All" option at the beginning
          _rentalOwners.insert(0, {
            "rentalowner_id": "all",
            "rentalOwner_name": "All",
          });

          // Select all rental owners by default (excluding "All" option)
          if (selectedRentalOwnerIds.isEmpty) {
            selectedRentalOwnerIds = _rentalOwners
                .where((o) => o['rentalowner_id']?.toString() != 'all')
                .map((o) => o['rentalowner_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();

            // Set the filter to all owners (but don't fetch data yet - wait for Run button)
            if (selectedRentalOwnerIds.isNotEmpty) {
              _rentalOwnerFilter = selectedRentalOwnerIds.join(',');
            }
          }
          // Update the notifier
          _selectedOwnersNotifier.value = List.from(selectedRentalOwnerIds);
        });
      }
    } catch (e) {
      logError('Error fetching rental owners: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: CustomDrawerStaff(
        currentpage: "Reports",
        dropdown: false,
      ),
      appBar: widget_302_Staff.App_Bar(context: context),
      body: isOffline
          ? _buildNoInternetWidget()
          : SingleChildScrollView(
              child: Column(
                children: [
                  StaffReportHeader(
                    title: 'Outstanding Lease Balance Report',
                  ),
                  // Filters Section - Always visible
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    child: _buildFiltersSection(),
                  ),
                  _buildReportContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildNoInternetWidget() {
    return NoInternetView(onRetry: retryNow);
  }

  Widget _buildReportContent() {
    return FutureBuilder<OutstandingLeaseBalanceModel>(
      future: _futureOutstandingLeaseBalance,
      builder: (context, snapshot) {
        if (isLoading) {
          return _buildLoadingWidget();
        }

        if (errorMessage != null) {
          return _buildErrorWidget();
        }

        if (outstandingLeaseBalanceModel == null ||
            outstandingLeaseBalanceModel!.data == null ||
            outstandingLeaseBalanceModel!.data!.isEmpty) {
          // Before Run (or a run that returned nothing): show the report chrome
          // — a $0.00 total plus a "no data" message. Run populates it.
          return Column(
            children: [
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildSummaryCards(),
              ),
              SizedBox(height: 40),
              _buildNoDataWidget(),
              SizedBox(height: 20),
            ],
          );
        }

        return _buildDataTable();
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCircle(
            color: blueColor,
            size: 50.0,
          ),
          SizedBox(height: 20),
          Text(
            'Loading Outstanding Lease Balance Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 8),
          Text(
            errorMessage ?? 'An unknown error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  // The standard empty state used across reports.
  Widget _buildNoDataWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/images/no_data_transparent.png",
            height: 200,
            width: 200,
          ),
          SizedBox(height: 10),
          Text(
            "No Data Available",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: blueColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    // Export is greyed out and not tappable until a run has returned rows.
    final bool hasExportData = errorMessage == null &&
        (outstandingLeaseBalanceModel?.data?.isNotEmpty ?? false);
    return Row(
      children: [
        // Status Filter
        Flexible(
          flex: 2,
          child: Container(
            height: 50,
            child: DropdownButtonHideUnderline(
              child: DropdownButton2<String>(
                isExpanded: true,
                value: _statusFilter,
                hint: Text(
                  'Status Filter',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF8A95A8),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text(
                      'All Leases',
                      style: TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'active',
                    child: Text(
                      'Active',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'future',
                    child: Text(
                      'Future',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'past',
                    child: Text(
                      'Past',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value ?? 'all';
                  });
                },
                buttonStyleData: ButtonStyleData(
                  height: 50,
                  padding: const EdgeInsets.only(left: 12, right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF8A95A8),
                    ),
                    color: Colors.white,
                  ),
                  elevation: 0,
                ),
                iconStyleData: IconStyleData(
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                ),
                dropdownStyleData: DropdownStyleData(
                  maxHeight: 250,
                  width: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  offset: const Offset(0, -5),
                ),
                menuItemStyleData: const MenuItemStyleData(
                  height: 40,
                  padding: EdgeInsets.only(left: 12, right: 12),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),

        // Rental Owner Filter
        Flexible(
          flex: 2,
          child: Container(
            height: 50,
            child: _buildMultiSelectRentalOwnerCompact(),
          ),
        ),
        SizedBox(width: 8),

        // Run Button
        Flexible(
          flex: 1,
          child: Container(
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentPage = 1;
                  isLoading = true;
                });
                _futureOutstandingLeaseBalance =
                    fetchOutstandingLeaseBalanceData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: blueColor,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Run',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 8),

        // Export Button
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFF8A95A8)),
          ),
          child: PopupMenuButton<String>(
            enabled: hasExportData,
            offset: Offset(0, 50),
            onSelected: (value) async {
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Fetch ALL data for export
                final allData = await fetchAllDataForExport();

                Navigator.pop(context); // Close loading dialog

                if (allData.isEmpty) {
                  Fluttertoast.showToast(
                    msg: 'No data to export',
                    toastLength: Toast.LENGTH_SHORT,
                  );
                  return;
                }

                if (value == 'PDF') {
                  await _generatePdf(allData);
                } else if (value == 'XLSX') {
                  await _generateExcel(allData);
                } else if (value == 'CSV') {
                  await _generateCsv(allData);
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                Fluttertoast.showToast(
                  msg: 'Error exporting data: ${friendlyErrorMessage(e)}',
                  toastLength: Toast.LENGTH_SHORT,
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'PDF',
                child: Text('PDF'),
              ),
              const PopupMenuItem<String>(
                value: 'XLSX',
                child: Text('XLSX'),
              ),
              const PopupMenuItem<String>(
                value: 'CSV',
                child: Text('CSV'),
              ),
            ],
            child: Center(
              child:
                  FaIcon(FontAwesomeIcons.download,
                      color: hasExportData ? blueColor : Colors.grey.shade400,
                      size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectRentalOwnerCompact() {
    // Filter out "All" option for the dropdown
    List<Map<String, dynamic>> rentalOwnersList = _rentalOwners
        .where((o) => o['rentalowner_id']?.toString() != 'all')
        .toList();

    // Check if all owners are selected
    bool allSelected = rentalOwnersList.isNotEmpty &&
        rentalOwnersList.every((owner) => selectedRentalOwnerIds
            .contains(owner['rentalowner_id']?.toString()));

    String displayText = selectedRentalOwnerIds.isEmpty
        ? "Rental Owner"
        : allSelected
            ? "All"
            : rentalOwnersList
                        .where((owner) => selectedRentalOwnerIds
                            .contains(owner['rentalowner_id']?.toString()))
                        .length ==
                    1
                ? rentalOwnersList
                        .firstWhere((owner) => selectedRentalOwnerIds.contains(
                            owner['rentalowner_id']
                                ?.toString()))['rentalOwner_name']
                        ?.toString() ??
                    "Rental Owner"
                : "${rentalOwnersList.where((owner) => selectedRentalOwnerIds.contains(owner['rentalowner_id']?.toString())).length} selected";

    return ValueListenableBuilder<List<String>>(
      valueListenable: _selectedOwnersNotifier,
      builder: (context, currentSelected, _) {
        return DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: true,
            hint: Text(
              displayText,
              style: TextStyle(
                fontSize: 13,
                color: selectedRentalOwnerIds.isEmpty
                    ? const Color(0xFF8A95A8)
                    : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            value: null, // Always null for multi-select
            items: [
              // "All" option at the top
              DropdownMenuItem<String>(
                value: 'all',
                enabled: false,
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: _selectedOwnersNotifier,
                  builder: (context, currentSelectedList, _) {
                    final isCurrentlySelected = rentalOwnersList.isNotEmpty &&
                        rentalOwnersList.every((owner) => currentSelectedList
                            .contains(owner['rentalowner_id']?.toString()));
                    return InkWell(
                      onTap: () {
                        if (isCurrentlySelected) {
                          selectedRentalOwnerIds.clear();
                        } else {
                          // Select all rental owners
                          selectedRentalOwnerIds = rentalOwnersList
                              .map((owner) =>
                                  owner['rentalowner_id']?.toString() ?? '')
                              .where((id) => id.isNotEmpty)
                              .toList();
                        }
                        _selectedOwnersNotifier.value =
                            List.from(selectedRentalOwnerIds);
                        setState(() {
                          // Convert to comma-separated string for API (but don't fetch yet)
                          if (selectedRentalOwnerIds.isEmpty) {
                            _rentalOwnerFilter = null;
                          } else {
                            _rentalOwnerFilter =
                                selectedRentalOwnerIds.join(',');
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Checkbox(
                            value: isCurrentlySelected,
                            onChanged: (bool? checked) {
                              if (checked == true) {
                                // Select all rental owners
                                selectedRentalOwnerIds = rentalOwnersList
                                    .map((owner) =>
                                        owner['rentalowner_id']?.toString() ??
                                        '')
                                    .where((id) => id.isNotEmpty)
                                    .toList();
                              } else {
                                selectedRentalOwnerIds.clear();
                              }
                              _selectedOwnersNotifier.value =
                                  List.from(selectedRentalOwnerIds);
                              setState(() {
                                // Convert to comma-separated string for API (but don't fetch yet)
                                if (selectedRentalOwnerIds.isEmpty) {
                                  _rentalOwnerFilter = null;
                                } else {
                                  _rentalOwnerFilter =
                                      selectedRentalOwnerIds.join(',');
                                }
                              });
                            },
                            activeColor: blueColor,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Expanded(
                            child: Text(
                              'All',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isCurrentlySelected
                                    ? FontWeight.bold
                                    : FontWeight.w400,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Individual rental owners
              ...rentalOwnersList.map((owner) {
                return DropdownMenuItem<String>(
                  value: owner['rentalowner_id']?.toString(),
                  enabled: false,
                  child: ValueListenableBuilder<List<String>>(
                    valueListenable: _selectedOwnersNotifier,
                    builder: (context, currentSelectedList, _) {
                      final isCurrentlySelected = currentSelectedList
                          .contains(owner['rentalowner_id']?.toString());
                      return InkWell(
                        onTap: () {
                          if (isCurrentlySelected) {
                            selectedRentalOwnerIds
                                .remove(owner['rentalowner_id']?.toString());
                          } else {
                            selectedRentalOwnerIds
                                .add(owner['rentalowner_id']?.toString() ?? '');
                          }
                          _selectedOwnersNotifier.value =
                              List.from(selectedRentalOwnerIds);
                          setState(() {
                            // Convert to comma-separated string for API (but don't fetch yet)
                            if (selectedRentalOwnerIds.isEmpty) {
                              _rentalOwnerFilter = null;
                            } else {
                              _rentalOwnerFilter =
                                  selectedRentalOwnerIds.join(',');
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Checkbox(
                              value: isCurrentlySelected,
                              onChanged: (bool? checked) {
                                if (checked == true) {
                                  selectedRentalOwnerIds.add(
                                      owner['rentalowner_id']?.toString() ??
                                          '');
                                } else {
                                  selectedRentalOwnerIds.remove(
                                      owner['rentalowner_id']?.toString());
                                }
                                _selectedOwnersNotifier.value =
                                    List.from(selectedRentalOwnerIds);
                                setState(() {
                                  // Convert to comma-separated string for API (but don't fetch yet)
                                  if (selectedRentalOwnerIds.isEmpty) {
                                    _rentalOwnerFilter = null;
                                  } else {
                                    _rentalOwnerFilter =
                                        selectedRentalOwnerIds.join(',');
                                  }
                                });
                              },
                              activeColor: blueColor,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            Expanded(
                              child: Text(
                                owner['rentalOwner_name']!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrentlySelected
                                      ? FontWeight.bold
                                      : FontWeight.w400,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
            onChanged:
                (_) {}, // Do nothing - selection handled in item's InkWell
            buttonStyleData: ButtonStyleData(
              height: 50,
              padding: const EdgeInsets.only(left: 12, right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8A95A8),
                ),
                color: Colors.white,
              ),
              elevation: 0,
            ),
            iconStyleData: IconStyleData(
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.grey[600],
                size: 18,
              ),
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 250,
              width: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              offset: const Offset(-20, -5),
              scrollbarTheme: ScrollbarThemeData(
                radius: const Radius.circular(40),
                thickness: MaterialStateProperty.all(6),
                thumbVisibility: MaterialStateProperty.all(true),
              ),
            ),
            menuItemStyleData: const MenuItemStyleData(
              height: 40,
              padding: EdgeInsets.only(left: 12, right: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataTable() {
    final filteredData = _getFilteredData();

    return Column(
      children: [
        SizedBox(height: 20),

        // Summary Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildSummaryCards(),
        ),

        // Data Table
        Column(
          children: [
            // Data Rows
            if (filteredData.isEmpty) kNoSearchResults(context),
            ...filteredData.asMap().entries.map((entry) {
              int index = entry.key;
              OutstandingLeaseBalanceData item = entry.value;
              return _buildLeaseCard(item, index);
            }).toList(),
          ],
        ),
        SizedBox(height: 20),
        // Pagination
        _buildPagination(),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSummaryCards() {
    // Show $0.00 before Run (no totals yet) instead of hiding the card.
    final balance =
        outstandingLeaseBalanceModel?.totals?.outstandingBalance ?? 0;

    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Text(
                      'Total Outstanding Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: blueColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    formatMoney(balance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
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

  Widget _buildLeaseCard(OutstandingLeaseBalanceData item, int index) {
    final isExpanded =
        expandedRowIndex == outstandingLeaseBalanceModel!.data!.indexOf(item);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: index % 2 != 0 ? Color(0xFFF4F8FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFDBE0E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main row - clickable header
          InkWell(
            onTap: () {
              setState(() {
                expandedRowIndex = isExpanded
                    ? null
                    : outstandingLeaseBalanceModel!.data!.indexOf(item);
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Lease info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.propertyAddress ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: blueColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          item.tenantNames ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Spacing between tenant and amount
                  SizedBox(width: 16),

                  // Total Balance
                  Text(
                    formatMoney(item.outstandingBalance ?? 0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: blueColor,
                    ),
                  ),

                  // Expand/Collapse icon
                  SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          // Expanded details - Nested table
          if (isExpanded)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: index % 2 != 0 ? Color(0xFFF4F8FF) : Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: _buildNestedTable(item),
            ),
        ],
      ),
    );
  }

  Widget _buildNestedTable(OutstandingLeaseBalanceData item) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Lease',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '0-30\n Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '31-60\n Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '61-90\n Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '90+\n Days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ),
              // Expanded(
              //   child: Text(
              //     'Balance',
              //     style: TextStyle(
              //       fontWeight: FontWeight.bold,
              //       fontSize: 13,
              //       color: Colors.black,
              //     ),
              //     textAlign: TextAlign.right,
              //   ),
              // ),
           
            ],
          ),
        ),
        SizedBox(height: 8),

        Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          margin: EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  item.propertyAddress ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: blueColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(item.balance030 ?? 0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(item.balance3160 ?? 0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(item.balance6190 ?? 0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatMoney(item.balance90Plus ?? 0),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: blueColor,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ),
                ),
              ),
              
                       ],
          ),
        ),
        SizedBox(height: 8),

        // Account breakdown rows (show account name and total balance only, like PDF)
        if (item.accountBreakdown != null && item.accountBreakdown!.isNotEmpty)
          ...item.accountBreakdown!.map((account) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              margin: EdgeInsets.only(bottom: 4),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          account.accountName ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '-', // Empty for 0-30 days (like PDF)
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '-', // Empty for 31-60 days (like PDF)
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '-', // Empty for 61-90 days (like PDF)
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '-', // Empty for 90+ days (like PDF)
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: blueColor,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 8),
                Row(
           
                children: [
                    Text('Balance :', style: TextStyle(fontSize: 13, color: blueColor, fontWeight: FontWeight.bold,),),
                    Spacer(),
                    Text(
                      formatMoney(account.amount ?? 0),
                      style: TextStyle(fontSize: 13, color: blueColor, fontWeight: FontWeight.bold,),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),  
                ],
              ),
            );
          }).toList(),

        // Balance row
        SizedBox(height: 8),
        // Container(
        //   padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(4),
        //     border: Border(
        //       top: BorderSide(color: Colors.grey[300]!, width: 1),
        //     ),
        //   ),
        //   child: Column(
        //     children: [
        //       Row(
        //         children: [
        //           Expanded(
        //             flex: 2,
        //             child: Text(
        //               'Balance',
        //               style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 13,
        //                 color: Colors.grey[800],
        //               ),
        //             ),
        //           ),
        //           Expanded(
        //             child: Text(
        //               '\$${NumberFormat('#,##0.00').format(item.balance030 ?? 0)}',
        //               style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 13,
        //                 color: blueColor,
        //               ),
        //               textAlign: TextAlign.right,
        //             ),
        //           ),
        //           Expanded(
        //             child: Text(
        //               '\$${NumberFormat('#,##0.00').format(item.balance3160 ?? 0)}',
        //               style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 13,
        //                 color: blueColor,
        //               ),
        //               textAlign: TextAlign.right,
        //             ),
        //           ),
        //           Expanded(
        //             child: Text(
        //               '\$${NumberFormat('#,##0.00').format(item.balance6190 ?? 0)}',
        //               style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 13,
        //                 color: blueColor,
        //               ),
        //               textAlign: TextAlign.right,
        //             ),
        //           ),
        //           Expanded(
        //             child: Text(
        //               '\$${NumberFormat('#,##0.00').format(item.balance90Plus ?? 0)}',
        //               style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 13,
        //                 color: blueColor,
        //               ),
        //               textAlign: TextAlign.right,
        //             ),
        //           ),
        //           Expanded(
        //             child: Text(
        //               '\$${NumberFormat('#,##0.00').format(item.outstandingBalance ?? 0)}',
        //               style: TextStyle(
        //                 fontWeight: FontWeight.bold,
        //                 fontSize: 13,
        //                 color: blueColor,
        //               ),
        //               textAlign: TextAlign.right,
        //             ),
        //           ),
        //         ],
        //       ),
           
        //     ],
        //   ),
        // ),
      
      ],
    );
  }

  Widget _buildPagination() {
    if (outstandingLeaseBalanceModel?.pagination == null)
      return SizedBox.shrink();

    final pagination = outstandingLeaseBalanceModel!.pagination!;
    final totalPages = pagination.totalPages ?? 1;
    final currentPage = pagination.currentPage ?? 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          elevation: 2,
          color: Colors.white,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _limit,
                items: [10, 25, 50, 100].map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _limit = newValue;
                      _currentPage = 1; // Reset to first page
                      isLoading = true;
                    });
                    _futureOutstandingLeaseBalance =
                        fetchOutstandingLeaseBalanceData();
                  }
                },
                icon: const Icon(
                  Icons.arrow_drop_down,
                  size: 24,
                ),
                style: const TextStyle(color: Colors.black, fontSize: 14),
                dropdownColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.circleChevronLeft,
            color: currentPage == 1 ? Colors.grey : blueColor,
          ),
          onPressed: currentPage == 1
              ? null
              : () {
                  _onPageChanged(currentPage - 1);
                },
        ),
        Text(
          'Page $currentPage of $totalPages',
        ),
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.circleChevronRight,
            color: currentPage >= totalPages ? Colors.grey : blueColor,
          ),
          onPressed: currentPage >= totalPages
              ? null
              : () {
                  _onPageChanged(currentPage + 1);
                },
        ),
      ],
    );
  }

  // Export Methods - Same as main file
  Future<void> _generatePdf(List<OutstandingLeaseBalanceData> data) async {
    try {
      GetAddressAdminPdfService service = GetAddressAdminPdfService();
      profile? profileData;

      try {
        profileData = await service.fetchAdminAddress();
      } catch (e) {
        logError("Error fetching profile data: $e");
        Fluttertoast.showToast(
          msg: 'Error fetching profile data',
          toastLength: Toast.LENGTH_SHORT,
        );
        return;
      }

      // Load logo
      final image = pw.MemoryImage(
        (await rootBundle.load('assets/images/applogo.png'))
            .buffer
            .asUint8List(),
      );

      // Format date and time
      final DateTime now = DateTime.now();
      final String formattedDateTime =
          DateFormat('dd/MMM/yyyy HH:mm:ss').format(now);

      final pdf = pw.Document();

      // Calculate grand totals
      double grandTotal030 = 0.0;
      double grandTotal3160 = 0.0;
      double grandTotal6190 = 0.0;
      double grandTotal90Plus = 0.0;
      double grandTotalBalance = 0.0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Image(image, width: 40, height: 40),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Outstanding Lease Balance Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Date: $formattedDateTime',
                      style: pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      profileData?.companyName ?? '',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${context.pageNumber}',
                      style: pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          build: (pw.Context context) {
            final List<List<dynamic>> tableData = [];

            for (var item in data) {
              tableData.add([
                pw.Text(
                  '${item.propertyAddress ?? 'N/A'} | ${item.tenantNames ?? 'N/A'}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                formatMoney(item.balance030 ?? 0),
                formatMoney(item.balance3160 ?? 0),
                formatMoney(item.balance6190 ?? 0),
                formatMoney(item.balance90Plus ?? 0),
                formatMoney(item.outstandingBalance ?? 0),
              ]);

              grandTotal030 += item.balance030 ?? 0.0;
              grandTotal3160 += item.balance3160 ?? 0.0;
              grandTotal6190 += item.balance6190 ?? 0.0;
              grandTotal90Plus += item.balance90Plus ?? 0.0;
              grandTotalBalance += item.outstandingBalance ?? 0.0;

              if (item.accountBreakdown != null &&
                  item.accountBreakdown!.isNotEmpty) {
                for (var account in item.accountBreakdown!) {
                  tableData.add([
                    pw.Text(
                      '  ${account.accountName ?? 'N/A'}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    '',
                    '',
                    '',
                    '',
                    formatMoney(account.amount ?? 0),
                  ]);
                }
              }
            }

            final grandTotalRow = [
              pw.Text(
                'Grand Total',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              formatMoney(grandTotal030),
              formatMoney(grandTotal3160),
              formatMoney(grandTotal6190),
              formatMoney(grandTotal90Plus),
              formatMoney(grandTotalBalance),
            ];

            return [
              pw.Table(
                columnWidths: {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.2),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex("#5A86D5"),
                    ),
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Lease',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '0-30 days',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '31-60 days',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '61-90 days',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          '90+ days',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Balance',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...tableData.map((row) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: row[0],
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Text(
                            row[1].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Text(
                            row[2].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Text(
                            row[3].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Text(
                            row[4].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: pw.EdgeInsets.all(6),
                          child: pw.Text(
                            row[5].toString(),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Grand Total',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(
                          grandTotalRow[1].toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(
                          grandTotalRow[2].toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(
                          grandTotalRow[3].toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(
                          grandTotalRow[4].toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(
                          grandTotalRow[5].toString(),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ];
          },
        ),
      );

      if (Platform.isIOS) {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'Outstanding_lease_balance_report.pdf');
    } else {
      await Printing.layoutPdf(
        name: 'Outstanding_lease_balance_report',
        format: PdfPageFormat.a4.landscape,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
    } catch (e) {
      logError('Error generating PDF: $e');
      Fluttertoast.showToast(
        msg: 'Error generating PDF',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  Future<void> _generateExcel(List<OutstandingLeaseBalanceData> data) async {
    try {
      final syncXlsx.Workbook workbook = syncXlsx.Workbook();
      final syncXlsx.Worksheet sheet = workbook.worksheets[0];

      sheet.getRangeByIndex(1, 1).setText('Lease');
      sheet.getRangeByIndex(1, 2).setText('0-30 Days');
      sheet.getRangeByIndex(1, 3).setText('31-60 Days');
      sheet.getRangeByIndex(1, 4).setText('61-90 Days');
      sheet.getRangeByIndex(1, 5).setText('90+ Days');
      sheet.getRangeByIndex(1, 6).setText('Balance');

      final syncXlsx.Style headerStyle = workbook.styles.add('headerStyle');
      headerStyle.backColor = '#5A86D5';
      headerStyle.fontColor = '#FFFFFF';
      headerStyle.bold = true;
      sheet.getRangeByIndex(1, 1, 1, 6).cellStyle = headerStyle;

      int rowIndex = 2;
      double grandTotal = 0.0;

      for (var item in data) {
        sheet.getRangeByIndex(rowIndex, 1).setText(
            '${item.propertyAddress ?? 'N/A'}\n${item.tenantNames ?? 'N/A'}');
        sheet.getRangeByIndex(rowIndex, 2).setNumber(item.balance030 ?? 0);
        sheet.getRangeByIndex(rowIndex, 3).setNumber(item.balance3160 ?? 0);
        sheet.getRangeByIndex(rowIndex, 4).setNumber(item.balance6190 ?? 0);
        sheet.getRangeByIndex(rowIndex, 5).setNumber(item.balance90Plus ?? 0);
        sheet
            .getRangeByIndex(rowIndex, 6)
            .setNumber(item.outstandingBalance ?? 0);
        grandTotal += item.outstandingBalance ?? 0.0;
        rowIndex++;
      }

      sheet.getRangeByIndex(rowIndex, 1).setText('Grand Total');
      sheet.getRangeByIndex(rowIndex, 1).cellStyle.bold = true;
      sheet.getRangeByIndex(rowIndex, 6).setNumber(grandTotal);
      sheet.getRangeByIndex(rowIndex, 6).cellStyle.bold = true;

      sheet.autoFitColumn(1);
      sheet.autoFitColumn(2);
      sheet.autoFitColumn(3);
      sheet.autoFitColumn(4);
      sheet.autoFitColumn(5);
      sheet.autoFitColumn(6);

      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final DateTime now = DateTime.now();
      final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
      final String fileName = 'OutstandingLeaseBalance_$formattedDate.xlsx';

      final Directory directory = await getApplicationDocumentsDirectory();

      final path = '${directory.path}/$fileName';

      if (!await directory.exists() && !Platform.isIOS) {
        await directory.create(recursive: true);
      }

      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);
      Share.shareXFiles([XFile(path)]);
      Fluttertoast.showToast(
        msg: 'Excel file saved to $path',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      logError('Error generating Excel: $e');
      Fluttertoast.showToast(
        msg: 'Error generating Excel',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  Future<void> _generateCsv(List<OutstandingLeaseBalanceData> data) async {
    try {
      final List<String> headers = [
        'Property Address',
        'Tenant Names',
        '0-30 Days',
        '31-60 Days',
        '61-90 Days',
        '90+ Days',
        'Outstanding Balance',
      ];

      final StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln(csvRow(headers));

      double grandTotal = 0.0;

      for (var item in data) {
        final String sanitizedAddress =
            (item.propertyAddress ?? 'N/A');
        final String sanitizedTenants =
            (item.tenantNames ?? 'N/A');

        csvBuffer.writeln(csvRow([
          sanitizedAddress,
          sanitizedTenants,
          NumberFormat('#,##0.00').format(item.balance030 ?? 0),
          NumberFormat('#,##0.00').format(item.balance3160 ?? 0),
          NumberFormat('#,##0.00').format(item.balance6190 ?? 0),
          NumberFormat('#,##0.00').format(item.balance90Plus ?? 0),
          NumberFormat('#,##0.00').format(item.outstandingBalance ?? 0),
        ]));

        grandTotal += item.outstandingBalance ?? 0.0;
      }

      csvBuffer.writeln(csvRow([
        'Grand Total',
        '',
        '',
        '',
        '',
        '',
        NumberFormat('#,##0.00').format(grandTotal),
      ]));

      final DateTime now = DateTime.now();
      final String formattedDate = DateFormat('yyyyMMddHHmmss').format(now);
      final String fileName = 'OutstandingLeaseBalance_$formattedDate.csv';

      final Directory directory = await getApplicationDocumentsDirectory();

      final path = '${directory.path}/$fileName';

      if (!await directory.exists() && !Platform.isIOS) {
        await directory.create(recursive: true);
      }

      final File file = File(path);
      await file.writeAsString(csvBuffer.toString(), flush: true);
      Share.shareXFiles([XFile(path)]);
      Fluttertoast.showToast(
        msg: 'CSV file saved to $path',
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      logError('Error generating CSV: $e');
      Fluttertoast.showToast(
        msg: 'Error generating CSV',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }
}
