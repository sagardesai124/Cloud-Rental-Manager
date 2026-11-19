import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Model/history_item_model.dart';
import '../enums/history_type.dart';
import '../services/history_service.dart';
import '../services/lease_history_search.dart';
import '../provider/dateProvider.dart';
import 'dashboard_pagination_footer.dart';

class CustomHistoryTable extends StatefulWidget {
  final HistoryType historyType;
  final String entityId;
  final String title;
  final Color blueColor;
  final int itemsPerPage;

  /// Heading size. Defaults to 16 so existing screens are unchanged;
  /// Lease Summary passes 18 to match its "Lease Details" heading.
  final double titleFontSize;

  const CustomHistoryTable({
    Key? key,
    required this.historyType,
    required this.entityId,
    this.title = 'History',
    required this.blueColor,
    this.itemsPerPage = 10,
    this.titleFontSize = 16,
  }) : super(key: key);

  @override
  State<CustomHistoryTable> createState() => _CustomHistoryTableState();
}

class _CustomHistoryTableState extends State<CustomHistoryTable> {
  int _currentPage = 1;
  int? _expandedIndex;
  late Future<HistoryResponse> _historyFuture;
  List<HistoryItem>?
      _allHistoryItems; // Store all items for frontend pagination
  bool _isFrontendPagination = false;

  // Lease History only, like web: the search box, the page size (5–100, or
  // "All") and the box's identity so typing keeps focus when the list
  // switches to "No history matches your search".
  final TextEditingController _leaseSearchController = TextEditingController();
  final GlobalKey _leaseSearchKey = GlobalKey();
  String _leaseSearch = '';
  int? _leasePageSize;
  bool _leaseShowAll = false;

  bool get _isLease => widget.historyType == HistoryType.lease;
  int get _perPage => _leasePageSize ?? widget.itemsPerPage;

  @override
  void initState() {
    super.initState();
    // print(
        // '🔵 CustomHistoryTable initState - Type: ${widget.historyType}, EntityId: ${widget.entityId}');
    _loadHistory();
    if (_isLease) _loadLeasePageSize();
  }

  @override
  void dispose() {
    _leaseSearchController.dispose();
    super.dispose();
  }

  /// The page size last chosen on Lease History, like web's remembered
  /// page size per screen.
  Future<void> _loadLeasePageSize() async {
    try {
      final stored =
          (await SharedPreferences.getInstance()).getInt(leaseHistoryPageSizeKey);
      if (stored != null &&
          leaseHistoryPageSizes.contains(stored) &&
          mounted &&
          stored != _perPage) {
        setState(() {
          _leasePageSize = stored;
          _currentPage = 1;
        });
      }
    } catch (_) {}
  }

  // Like web: a new search, page size or "All" starts again at page 1.
  void _setLeaseSearch(String value) {
    setState(() {
      _leaseSearch = value;
      _currentPage = 1;
      _expandedIndex = null;
    });
  }

  void _setLeasePageSize(int size) {
    setState(() {
      _leasePageSize = size;
      _leaseShowAll = false;
      _currentPage = 1;
      _expandedIndex = null;
    });
    SharedPreferences.getInstance()
        .then((p) => p.setInt(leaseHistoryPageSizeKey, size))
        .catchError((_) => false);
  }

  void _showAllLeaseRows() {
    setState(() {
      _leaseShowAll = true;
      _currentPage = 1;
      _expandedIndex = null;
    });
  }

  /// Web's search box above Lease History.
  Widget _leaseSearchBox() {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: Color(0xFFDBE0E5)),
    );
    return Padding(
      key: _leaseSearchKey,
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _leaseSearchController,
        onChanged: _setLeaseSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: leaseHistorySearchHint,
          hintStyle: const TextStyle(color: Color(0xFFB0B6C3), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF8A95A8)),
          suffixIcon: _leaseSearch.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _leaseSearchController.clear();
                    _setLeaseSearch('');
                  },
                ),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: BorderSide(color: widget.blueColor)),
        ),
      ),
    );
  }

  /// Lease History rows the search keeps, like web's filterLeaseHistory.
  List<HistoryItem> _leaseRowsMatching(
      List<HistoryItem> rows, BuildContext context) {
    if (_leaseSearch.isEmpty) return rows;
    final datePattern =
        Provider.of<DateProvider>(context, listen: false).dateFormat;
    return rows
        .where((item) => leaseHistoryMatches(item, _leaseSearch,
            shownDate: _formatDateTimeWithAMPM(item.date, context),
            datePattern: datePattern))
        .toList();
  }

  void _loadHistory() {
    _historyFuture = HistoryService.fetchHistory(
      historyType: widget.historyType,
      entityId: widget.entityId,
      page: _currentPage,
      limit: widget.itemsPerPage,
    );
    _historyFuture.then((response) {
      // print(
          // '🔵 History API Response - Status: ${response.pagination.total} items, Page: ${response.pagination.page}');
      // print('🔵 History Data Count: ${response.data.length}');

      // For lease history, always use frontend pagination (API returns all data)
      if (widget.historyType == HistoryType.lease) {
        // print('🔵 Lease history detected - using frontend pagination');
        setState(() {
          _allHistoryItems = response.data;
          _isFrontendPagination = true;
          // print('🔵 Stored ${_allHistoryItems!.length} lease history items');
        });
      } else {
        // For other types, check if data length > limit (frontend pagination)
        // or if pagination info suggests backend pagination
        if (response.data.length > widget.itemsPerPage &&
            response.pagination.totalPages == 1) {
          // print(
              // '🔵 Frontend pagination detected - data length (${response.data.length}) > limit (${widget.itemsPerPage})');
          setState(() {
            _allHistoryItems = response.data;
            _isFrontendPagination = true;
          });
        } else {
          // print('🔵 Backend pagination detected');
          _isFrontendPagination = false;
          _allHistoryItems = null;
        }
      }
    }).catchError((error) {
      // print('🔴 History API Error: $error');
    });
  }

  void _refreshHistory() {
    setState(() {
      _loadHistory();
    });
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
      _expandedIndex = null; // Reset expanded row when changing pages

      // For lease history or frontend pagination, we don't need to refresh API
      // The data is already loaded and pagination is handled in build method
      if (widget.historyType == HistoryType.lease ||
          (_isFrontendPagination && _allHistoryItems != null)) {
        // Pagination will be handled in the build method by slicing data
        // print('🔵 Page changed to $page - Using frontend pagination');
        return;
      }

      // Backend pagination - refresh API call
      _refreshHistory();
    });
  }

  String _formatDateTimeWithAMPM(String dateTimeString, BuildContext context) {
    if (dateTimeString.isEmpty) return '';

    try {
      // print('🔵 [LEASE HISTORY] Formatting date: "$dateTimeString"');
      // print('🔵 [LEASE HISTORY] History Type: ${widget.historyType}');

      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      DateTime? parsedDate;
      bool isAlreadyLocalTime = false; // Track if date is already in local time

      // Step 1: Handle verbose JavaScript date format FIRST
      // Format: "Mon Dec 08 2025 08:00:03 GMT+0000 (Coordinated Universal Time)"
      if (dateTimeString.contains('GMT') && dateTimeString.contains('(')) {
        //print('🔵 [LEASE HISTORY] Detected verbose GMT format');
        try {
          // Extract the date part before the parentheses: "Mon Dec 08 2025 08:00:03 GMT+0000"
          String datePart = dateTimeString.split('(')[0].trim();
          // Try parsing with DateFormat for this specific format
          try {
            final verboseFormat = DateFormat("EEE MMM dd yyyy HH:mm:ss 'GMT'Z");
            parsedDate = verboseFormat.parse(datePart);
         //   print('🔵 [LEASE HISTORY] Parsed verbose format: $parsedDate');
          } catch (e) {
            // print(
            //     '🔵 [LEASE HISTORY] Verbose format parse failed, trying alternative: $e');
            // Alternative: Extract components manually
            final altPattern = RegExp(
                r'(\w{3})\s+(\w{3})\s+(\d{1,2})\s+(\d{4})\s+(\d{2}:\d{2}:\d{2})');
            final match = altPattern.firstMatch(dateTimeString);
            if (match != null) {
              final month = match.group(2)!;
              final day = match.group(3)!;
              final year = match.group(4)!;
              final time = match.group(5)!;
              final altFormat = DateFormat("MMM dd yyyy HH:mm:ss");
              parsedDate = altFormat.parse("$month $day $year $time");
              // print(
              //     '🔵 [LEASE HISTORY] Parsed with alternative method: $parsedDate');
            }
          }
        } catch (e) {
          // print('🔴 [LEASE HISTORY] Failed to parse verbose date format: $e');
        }
      }

      // Step 2: If not verbose format, parse using common formats
      if (parsedDate == null) {
        // print('🔵 [LEASE HISTORY] Trying common format parsing');

        // Check if it's ISO format with Z (UTC) - e.g., "2026-01-07T04:51:59.000Z"
        // For lease history, if date has Z, convert UTC to local time (like web does)
        bool isISOWithZ = dateTimeString.contains('T') &&
            dateTimeString.toUpperCase().endsWith('Z');

        if (isISOWithZ && widget.historyType == HistoryType.lease) {
          // print(
          //     '🔵 [LEASE HISTORY] Detected ISO format with Z (UTC): "$dateTimeString"');
          try {
            // Parse as UTC and convert to local time (matching web behavior)
            parsedDate = DateTime.parse(dateTimeString).toLocal();
            isAlreadyLocalTime = true; // Already converted to local time
            // print(
            //     '🔵 [LEASE HISTORY] Parsed ISO with Z and converted to local: $parsedDate');
          } catch (e) {
            // print('🔵 [LEASE HISTORY] Failed to parse ISO with Z: $e');
          }
        }

        // If not ISO with Z, try other formats
        if (parsedDate == null) {
          try {
            // Handle "yyyy-MM-dd HH:mm:ss" format explicitly
            // This format is already in local time (no conversion needed)
            if (RegExp(r'^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}$')
                .hasMatch(dateTimeString)) {
              parsedDate =
                  DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTimeString);
              isAlreadyLocalTime = true; // Already in local time format
              // print(
              //     '🔵 [LEASE HISTORY] Parsed as yyyy-MM-dd HH:mm:ss (local time): $parsedDate');
            } else if (RegExp(r'^\d{4}-\d{2}-\d{2}$')
                .hasMatch(dateTimeString)) {
              // Date only format "yyyy-MM-dd" - parse and set to midnight
              parsedDate = DateFormat('yyyy-MM-dd').parse(dateTimeString);
              // print(
              //     '🔵 [LEASE HISTORY] Parsed as date-only (yyyy-MM-dd): $parsedDate');
            } else if (!isISOWithZ) {
              // Try DateTime.parse for ISO formats (but not if we already handled Z format)
              parsedDate = DateTime.parse(dateTimeString);
              // print(
              //     '🔵 [LEASE HISTORY] Parsed with DateTime.parse: $parsedDate');
            }
          } catch (e) {
            // print(
            //     '🔵 [LEASE HISTORY] Common format parse failed, trying format list: $e');
            // Try other common formats
            List<String> dateTimeFormats = [
              'yyyy-MM-dd HH:mm:ss', // "2026-01-01 08:00:04"
              'yyyy-MM-dd HH:mm', // "2026-01-01 08:00"
              'MM/dd/yyyy h:mm:ss a', // "01/01/2026 8:00:03 AM"
              'M/d/yyyy h:mm:ss a', // "1/1/2026 8:00:03 AM"
              'MM/dd/yyyy HH:mm:ss', // "01/01/2026 08:00:03"
              'M/d/yyyy HH:mm:ss', // "1/1/2026 08:00:03"
              'yyyy-MM-dd', // "2025-12-08" (date only)
              'MM/dd/yyyy', // "12/08/2025"
              'M/d/yyyy', // "12/8/2025"
            ];

            for (String format in dateTimeFormats) {
              try {
                parsedDate = DateFormat(format).parse(dateTimeString);
                // print(
                //     '🔵 [LEASE HISTORY] Parsed with format "$format": $parsedDate');
                break;
              } catch (e2) {
                continue;
              }
            }
          }
        }
      }

      // Step 3: If still not parsed, use DateProvider as fallback
      if (parsedDate == null) {
        // print('🔵 [LEASE HISTORY] Using DateProvider fallback');
        // Try DateProvider first
        String formatted = dateProvider.formatCurrentDateTime(dateTimeString);
        // print('🔵 [LEASE HISTORY] DateProvider formatted: "$formatted"');

        // ALWAYS ensure seconds are included - check and fix if missing
        // Check for patterns like "8:00 AM" or "08:00 AM" (without seconds)
        // Pattern: matches HH:MM or H:MM followed by optional space and AM/PM
        final timePattern12h =
            RegExp(r'(\d{1,2}:\d{2})\s*(AM|PM)', caseSensitive: false);
        // Pattern: matches HH:MM (24-hour) that is NOT followed by :ss
        final timePattern24h = RegExp(r'(\d{1,2}:\d{2})(?!:\d{2})');

        // Check if seconds are missing (no pattern like :00, :03, :59, etc.)
        bool hasSeconds = RegExp(r':\d{2}\s*(AM|PM)?$', caseSensitive: false)
                .hasMatch(formatted) ||
            formatted
                .contains(RegExp(r':\d{2}\s+(AM|PM)', caseSensitive: false));

        // print('🔵 [LEASE HISTORY] Has seconds? $hasSeconds');

        if (!hasSeconds) {
          // print('🔵 [LEASE HISTORY] Adding seconds...');
          // Seconds are missing - add them
          if (timePattern12h.hasMatch(formatted)) {
            // 12-hour format without seconds - add :00 before AM/PM
            formatted = formatted.replaceAllMapped(timePattern12h, (match) {
              final result = '${match.group(1)}:00 ${match.group(2)}';
              // print(
              //     '🔵 [LEASE HISTORY] Replaced 12h: "${match.group(0)}" -> "$result"');
              return result;
            });
          } else if (timePattern24h.hasMatch(formatted)) {
            // 24-hour format without seconds - add :00
            formatted = formatted.replaceAllMapped(timePattern24h, (match) {
              final result = '${match.group(1)}:00';
              // print(
              //     '🔵 [LEASE HISTORY] Replaced 24h: "${match.group(0)}" -> "$result"');
              return result;
            });
          }
        }

        // print(
        //     '🔵 [LEASE HISTORY] Final formatted result (Step 3): "$formatted"');
        return formatted;
      }

      // Step 4: Format parsed date
      // print('🔵 [LEASE HISTORY] Formatting parsed date: $parsedDate');

      // Apply timezone offset only if date is not already in local time
      // For lease history with "yyyy-MM-dd HH:mm:ss" or ISO Z (converted to local),
      // the time is already correct, so don't apply offset
      DateTime dateToFormat;
      if (widget.historyType == HistoryType.lease && isAlreadyLocalTime) {
        // For lease history that's already in local time, use as-is
        dateToFormat = parsedDate;
        // print(
        //     '🔵 [LEASE HISTORY] Using date as-is (already local time): $dateToFormat');
      } else {
        // For other history types or dates that need conversion, apply timezone offset
        dateToFormat = parsedDate.add(Duration(hours: 5, minutes: 30));
        // print('🔵 [LEASE HISTORY] After timezone offset: $dateToFormat');
      }

      // Use user's date format preferences for all history types including lease
      // Get user's date format preference
      String dateFormat = dateProvider.dateFormat;
      // Get user's time format preference and ALWAYS include seconds
      String timeFormatPattern =
          dateProvider.timeFormat == '24' ? 'HH:mm:ss' : 'h:mm:ss a';
      String dateTimeFormat = '$dateFormat $timeFormatPattern';

      // print('🔵 [LEASE HISTORY] Date format: "$dateFormat"');
      // print(
      //     '🔵 [LEASE HISTORY] Time format: "${dateProvider.timeFormat}" -> "$timeFormatPattern"');
      // print('🔵 [LEASE HISTORY] Combined format: "$dateTimeFormat"');

      // Format the date with seconds ALWAYS included
      String formattedResult = DateFormat(dateTimeFormat).format(dateToFormat);

      // Double-check: ensure seconds are present (safety check)
      // Check if seconds pattern exists (like :00, :03, :59 followed by optional AM/PM)
      bool hasSeconds = RegExp(r':\d{2}\s*(AM|PM)?$', caseSensitive: false)
              .hasMatch(formattedResult) ||
          formattedResult
              .contains(RegExp(r':\d{2}\s+(AM|PM)', caseSensitive: false));

      if (!hasSeconds) {
        // If somehow seconds are missing, add them manually
        final timeMatch12h =
            RegExp(r'(\d{1,2}:\d{2})\s*(AM|PM)', caseSensitive: false)
                .firstMatch(formattedResult);
        final timeMatch24h =
            RegExp(r'(\d{1,2}:\d{2})(?!:\d{2})').firstMatch(formattedResult);

        if (timeMatch12h != null) {
          formattedResult = formattedResult.replaceAll(timeMatch12h.group(0)!,
              '${timeMatch12h.group(1)}:00 ${timeMatch12h.group(2)}');
        } else if (timeMatch24h != null) {
          formattedResult = formattedResult.replaceAll(
              timeMatch24h.group(0)!, '${timeMatch24h.group(1)}:00');
        }
      }

      return formattedResult;
    } catch (e) {
      // print('Error formatting date: $e');
      // Fallback: try DateProvider one more time
      try {
        final dateProvider = Provider.of<DateProvider>(context, listen: false);
        return dateProvider.formatCurrentDateTime(dateTimeString);
      } catch (e2) {
        return dateTimeString;
      }
    }
  }

  Widget _buildMetadataContent(HistoryItem item) {
    if (item.metadata == null || item.metadata!.isEmpty) {
      return const SizedBox.shrink();
    }

    List<Widget> metadataWidgets = [];

    // Check if metadata has old_values and new_values (for updates)
    if (item.metadata!['old_values'] != null &&
        item.metadata!['new_values'] != null) {
      // Handle update comparison (old → new)
      Map<String, dynamic> oldValues = item.metadata!['old_values'];
      Map<String, dynamic> newValues = item.metadata!['new_values'];

      oldValues.forEach((key, oldValue) {
        // Skip ID fields
        if (_isIdField(key)) return;
        if (!newValues.containsKey(key)) return;

        // CRM-4373: compare what the user will actually SEE, not the raw JSON.
        //
        // The two sides often arrive in different shapes for the same value —
        // the stored side as a number or an ISO date, the submitted side as the
        // string the form posted. A raw `oldValue != newValue` then reports a
        // change for a field nobody touched, and because both sides are run
        // through _formatValue for display it renders as an obvious no-op like
        // "$100.00 → $100.00" or "06/25/2026 → 06/25/2026".
        //
        // Formatting first collapses those equivalent shapes, so a row is only
        // listed when the displayed values genuinely differ. A real edit still
        // formats differently on each side and is still reported.
        final String oldText = _formatValue(oldValue, key: key);
        final String newText = _formatValue(newValues[key], key: key);
        if (oldText == newText) return;

        metadataWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${_formatKey(key)}: $oldText → $newText',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        );
      });

      // Add any new fields that don't exist in old_values
      newValues.forEach((key, newValue) {
        if (_isIdField(key)) return;
        if (!oldValues.containsKey(key) && newValue != null) {
          metadataWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${_formatKey(key)}: ${_formatValue(newValue, key: key)}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
          );
        }
      });
    } else {
      // Dynamic metadata display - iterate through all fields
      item.metadata!.forEach((key, value) {
        // Skip ID fields
        if (_isIdField(key)) return;

        // Skip old_values and new_values if they're not maps (already handled above)
        if (key == 'old_values' || key == 'new_values') return;

        if (value != null && value.toString().isNotEmpty) {
          metadataWidgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _buildMetadataRow(key, value),
            ),
          );
        }
      });
    }

    if (metadataWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metadataWidgets,
    );
  }

  /// Check if a field key contains "id" (case-insensitive)
  bool _isIdField(String key) {
    final lowerKey = key.toLowerCase();
    return lowerKey.contains('_id') ||
        lowerKey == 'id' ||
        lowerKey.endsWith('id') ||
        lowerKey.startsWith('id_');
  }

  /// Build a metadata row widget based on value type
  Widget _buildMetadataRow(String key, dynamic value) {
    if (value is Map) {
      // Handle nested objects - recursively process all fields
      final mapValue = value as Map<String, dynamic>;
      final nestedWidgets = <Widget>[];

      mapValue.forEach((nestedKey, nestedValue) {
        if (_isIdField(nestedKey)) return;
        if (nestedValue == null || nestedValue.toString().isEmpty) return;

        nestedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildMetadataRow(nestedKey, nestedValue),
          ),
        );
      });

      if (nestedWidgets.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatKey(key)}:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nestedWidgets,
            ),
          ),
        ],
      );
    } else if (value is List) {
      // Handle arrays
      if (value.isEmpty) return const SizedBox.shrink();

      // Special handling for entries arrays (common in lease history)
      // Also handle payments, charges, and other array types
      if ((key == 'entries' || key == 'payments' || key == 'charges') &&
          value.isNotEmpty &&
          value[0] is Map) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatKey(key)}:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: value.asMap().entries.map((entry) {
                  final entryMap = entry.value as Map<String, dynamic>;
                  final entryWidgets = <Widget>[];

                  entryMap.forEach((entryKey, entryValue) {
                    if (_isIdField(entryKey)) return;
                    if (entryValue == null || entryValue.toString().isEmpty)
                      return;

                    // Recursively handle nested structures
                    if (entryValue is Map || entryValue is List) {
                      entryWidgets.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _buildMetadataRow(entryKey, entryValue),
                        ),
                      );
                    } else {
                      entryWidgets.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${_formatKey(entryKey)}: ${_formatValue(entryValue, key: entryKey)}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      );
                    }
                  });

                  if (entryWidgets.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatKey(key)} ${entry.key + 1}:',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...entryWidgets,
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }

      // Regular array handling
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatKey(key)}:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: value.asMap().entries.map((entry) {
                if (entry.value is Map) {
                  // If array contains maps, display them nicely
                  final mapValue = entry.value as Map<String, dynamic>;
                  final mapWidgets = <Widget>[];
                  mapValue.forEach((mapKey, mapVal) {
                    if (_isIdField(mapKey)) return;
                    if (mapVal != null && mapVal.toString().isNotEmpty) {
                      mapWidgets.add(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${_formatKey(mapKey)}: ${_formatValue(mapVal, key: mapKey)}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87),
                          ),
                        ),
                      );
                    }
                  });
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• Entry ${entry.key + 1}:',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: mapWidgets,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '• ${_formatValue(entry.value, key: key)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      );
    } else {
      // Simple value
      return Text(
        '${_formatKey(key)}: ${_formatValue(value, key: key)}',
        style: const TextStyle(fontSize: 14, color: Colors.black87),
      );
    }
  }

  /// Format a value for display
  String _formatValue(dynamic value, {String? key}) {
    if (value == null) return 'N/A';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) {
      // Format as currency if key suggests it's an amount
      final lowerKey = key?.toLowerCase() ?? '';
      final isAmountField = lowerKey.contains('amount') ||
          lowerKey.contains('price') ||
          lowerKey.contains('cost') ||
          lowerKey.contains('fee') ||
          lowerKey.contains('charge') ||
          lowerKey.contains('payment') ||
          lowerKey.contains('deposit') ||
          lowerKey.contains('rent');

      if (isAmountField && value >= 0) {
        // Format as currency with commas
        final formatted = value.toStringAsFixed(2);
        final parts = formatted.split('.');
        final integerPart = parts[0];
        final decimalPart = parts.length > 1 ? parts[1] : '00';

        // Add commas to integer part
        final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
        final formattedInteger = integerPart.replaceAllMapped(
          regex,
          (Match m) => '${m[1]},',
        );

        return '\$$formattedInteger.$decimalPart';
      }

      // Format regular numbers
      if (value is double && value == value.truncateToDouble()) {
        return value.toInt().toString();
      }
      return value.toString();
    }
    if (value is String) {
      // Check if it's a date string and format it nicely
      if (_looksLikeDate(value)) {
        return _formatDateString(value);
      }
      // Return as-is for strings
      return value;
    }
    return value.toString();
  }

  /// Check if a string looks like a date
  bool _looksLikeDate(String value) {
    // Common date patterns
    final datePatterns = [
      RegExp(r'^\d{4}-\d{2}-\d{2}'), // YYYY-MM-DD
      RegExp(r'^\d{2}/\d{2}/\d{4}'), // MM/DD/YYYY
      RegExp(r'^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}'), // YYYY-MM-DD HH:MM
    ];
    return datePatterns.any((pattern) => pattern.hasMatch(value));
  }

  /// Format a date string for display
  String _formatDateString(String dateStr) {
    try {
      // Try common date formats
      final formats = [
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd',
        'MM/dd/yyyy HH:mm:ss',
        'MM/dd/yyyy',
      ];

      for (var format in formats) {
        try {
          final date = DateFormat(format).parse(dateStr);
          return DateFormat('MM/dd/yyyy HH:mm').format(date);
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      // If parsing fails, return original
    }
    return dateStr;
  }

  String _formatKey(String key) {
    // These keys come straight from the server's audit metadata, so a leading,
    // trailing or doubled underscore is possible — "__v" splits to ["", "", "v"]
    // and `word[0]` on an empty segment threw RangeError during build, taking
    // the whole History section down with a red screen. Drop empty segments so
    // the spacing stays clean too.
    return key
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Parse description into structured format for better display
  List<String> _parseDescription(String description) {
    if (description.isEmpty) return [];

    // Clean HTML entities
    String cleanDescription = description
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();

    List<String> details = [];

    // Pattern 0: Special handling for Body preview - extract it first to prevent nested parsing
    // Find "Body preview:" and extract everything after it as a single value
    final bodyPreviewMatch =
        RegExp(r'Body preview:\s*(.+)$', caseSensitive: false, dotAll: true)
            .firstMatch(cleanDescription);
    String bodyPreviewValue = '';
    String descriptionWithoutBodyPreview = cleanDescription;

    if (bodyPreviewMatch != null) {
      bodyPreviewValue = bodyPreviewMatch.group(1)?.trim() ?? '';
      // Remove body preview from description for parsing other fields
      descriptionWithoutBodyPreview =
          cleanDescription.substring(0, bodyPreviewMatch.start).trim();
    }

    // Pattern 0.5: For lease history, show full description as-is without parsing
    // This MUST come before other patterns to prevent parsing
    // User wants to see the complete description text exactly as it comes from API
    if (widget.historyType == HistoryType.lease) {
      // Return the full description as a single item, only add body preview if exists
      List<String> details = [];
      details.add(descriptionWithoutBodyPreview);

      // Add body preview at the end if it exists
      if (bodyPreviewValue.isNotEmpty) {
        bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
        details.add('Body preview: $bodyPreviewValue');
      }

      return details;
    }

    // Pattern 0.7: Check for "Payment created" format (for tenant/property history)
    // Format: "Payment created" followed by details like Amount, Payment Method, Status, etc.
    if (descriptionWithoutBodyPreview
        .toLowerCase()
        .contains('payment created')) {
      return _parsePaymentCreatedDescription(
          descriptionWithoutBodyPreview, bodyPreviewValue);
    }

    // Pattern 0.8: Check for mortgage history format with "Changes:" and old → new values
    // Format: "Mortgage updated by X: ... Changes: Field: \"old\" → \"new\"; Field2: \"old2\" → \"new2\""
    if (widget.historyType == HistoryType.mortgage &&
        descriptionWithoutBodyPreview.contains('Changes:')) {
      final changesIndex = descriptionWithoutBodyPreview.indexOf('Changes:');
      final header =
          descriptionWithoutBodyPreview.substring(0, changesIndex).trim();
      final changesText = descriptionWithoutBodyPreview
          .substring(changesIndex + 'Changes:'.length)
          .trim();

      if (header.isNotEmpty) {
        details.add(header);
      }

      // Split changes by semicolon, preserving the old → new format
      final changes = changesText
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      details.addAll(changes);

      // Add body preview at the end if it exists
      if (bodyPreviewValue.isNotEmpty) {
        bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
        details.add('Body preview: $bodyPreviewValue');
      }

      return details;
    }

    // Pattern 1: Check for "Changes:" which indicates field changes
    final changesIndex = descriptionWithoutBodyPreview.indexOf('Changes:');
    if (changesIndex != -1) {
      final header =
          descriptionWithoutBodyPreview.substring(0, changesIndex).trim();
      final changesText = descriptionWithoutBodyPreview
          .substring(changesIndex + 'Changes:'.length)
          .trim();

      if (header.isNotEmpty) {
        details.add(header);
      }

      // Split changes by semicolon or comma, but be smart about it
      final changes = _smartSplit(changesText, [';', ',']);
      details.addAll(changes);

      // Add body preview at the end if it exists
      if (bodyPreviewValue.isNotEmpty) {
        bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
        details.add('Body preview: $bodyPreviewValue');
      }

      return details;
    }

    // Pattern 1.5: Check for Utility Added/Deleted patterns BEFORE other patterns
    // Format: "Utility Added (Unit X): utilityname (Provider: X, Account: Y)" or
    //         "Utility Deleted (Unit X): utilityname (Provider: X, Account: Y)"
    // Only check if it STARTS with "Utility Added" or "Utility Deleted" to avoid false matches
    final lowerDesc = descriptionWithoutBodyPreview.toLowerCase().trim();
    if (lowerDesc.startsWith('utility added') ||
        lowerDesc.startsWith('utility deleted')) {
      // More flexible pattern to handle variations
      final utilityActionPattern = RegExp(
          r'Utility\s+(Added|Deleted)\s*\(([^)]+)\):\s*(.+?)(?:\s*\(([^)]+)\))?\s*$',
          caseSensitive: false,
          dotAll: true);
      final utilityActionMatch =
          utilityActionPattern.firstMatch(descriptionWithoutBodyPreview);

      if (utilityActionMatch != null) {
        final action =
            utilityActionMatch.group(1)?.trim() ?? ''; // Added or Deleted
        var unit = utilityActionMatch.group(2)?.trim() ?? '';
        var utilityName = utilityActionMatch.group(3)?.trim() ?? '';
        var detailsStr = utilityActionMatch.group(4)?.trim() ??
            ''; // "Provider: X, Account: Y"

        // Clean up unit - remove duplicate "Unit" if present (e.g., "Unit Unit t1022" -> "t1022")
        if (unit.toLowerCase().startsWith('unit ')) {
          unit = unit.substring(5).trim();
        }

        // Check if utilityName contains key-value pairs (format: "Utility Name: testsd, Provider: ...")
        // This happens when details are not in parentheses but comma-separated after colon
        if (utilityName.contains(':') && utilityName.contains(',')) {
          // Extract utility name from first part
          final firstColon = utilityName.indexOf(':');
          if (firstColon > 0) {
            final utilityNameValue =
                utilityName.substring(firstColon + 1).trim();

            // Get the value before first comma
            final firstComma = utilityNameValue.indexOf(',');
            final actualUtilityName = firstComma > 0
                ? utilityNameValue.substring(0, firstComma).trim()
                : utilityNameValue.trim();

            // Build header
            final header = 'Utility $action (Unit $unit): $actualUtilityName';
            details.add(header);

            // Parse remaining details (everything after first comma)
            if (firstComma > 0) {
              final remainingDetails =
                  utilityNameValue.substring(firstComma + 1).trim();
              if (remainingDetails.isNotEmpty) {
                final detailParts = _smartSplit(remainingDetails, [',']);
                for (var part in detailParts) {
                  part = part.trim();
                  if (part.isNotEmpty) {
                    final colonIdx = part.indexOf(':');
                    if (colonIdx > 0 && colonIdx < part.length - 1) {
                      final key = part.substring(0, colonIdx).trim();
                      final value = part.substring(colonIdx + 1).trim();
                      if (key.isNotEmpty && value.isNotEmpty) {
                        details.add('$key: $value');
                      }
                    }
                  }
                }
              }
            }
          }
        } else {
          // Clean up utility name - remove trailing parentheses if any
          utilityName =
              utilityName.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();

          // Build header
          final header = 'Utility $action (Unit $unit): $utilityName';
          details.add(header);

          // Parse details from parentheses if they exist
          if (detailsStr.isNotEmpty) {
            // Split by comma, but be smart about it
            final detailParts = _smartSplit(detailsStr, [',']);
            for (var part in detailParts) {
              part = part.trim();
              if (part.isNotEmpty) {
                // Check if it's a key-value pair
                final colonIdx = part.indexOf(':');
                if (colonIdx > 0 && colonIdx < part.length - 1) {
                  final key = part.substring(0, colonIdx).trim();
                  final value = part.substring(colonIdx + 1).trim();
                  if (key.isNotEmpty && value.isNotEmpty) {
                    details.add('$key: $value');
                  }
                } else {
                  details.add(part);
                }
              }
            }
          }
        }

        // Add body preview at the end if it exists
        if (bodyPreviewValue.isNotEmpty) {
          bodyPreviewValue =
              bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
          bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
          bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
          details.add('Body preview: $bodyPreviewValue');
        }

        return details;
      }

      // Fallback: Try manual parsing if regex doesn't match
      final lowerDesc = descriptionWithoutBodyPreview.toLowerCase();
      final isAdded = lowerDesc.startsWith('utility added');
      final action = isAdded ? 'Added' : 'Deleted';

      // Extract unit from parentheses: "Utility X (Unit Y): ..."
      final unitMatch = RegExp(r'\(Unit\s+([^)]+)\)', caseSensitive: false)
          .firstMatch(descriptionWithoutBodyPreview);
      final unit = unitMatch?.group(1)?.trim() ?? '';

      // Extract utility name - everything after ": " until next "(" or end
      final colonIndex = descriptionWithoutBodyPreview.indexOf(':');
      if (colonIndex > 0) {
        var utilityName =
            descriptionWithoutBodyPreview.substring(colonIndex + 1).trim();

        // Extract details from last parentheses if exists
        final lastParenMatch = RegExp(r'\(([^)]+)\)\s*$')
            .firstMatch(descriptionWithoutBodyPreview);
        String? detailsStr;

        if (lastParenMatch != null) {
          detailsStr = lastParenMatch.group(1)?.trim();
          // Remove details part from utility name
          final detailsStart = descriptionWithoutBodyPreview.lastIndexOf('(');
          if (detailsStart > colonIndex) {
            utilityName = descriptionWithoutBodyPreview
                .substring(colonIndex + 1, detailsStart)
                .trim();
          }
        }

        // Build header
        final header = unit.isNotEmpty
            ? 'Utility $action (Unit $unit): $utilityName'
            : 'Utility $action: $utilityName';
        details.add(header);

        // Parse details if they exist
        if (detailsStr != null && detailsStr.isNotEmpty) {
          final detailParts = _smartSplit(detailsStr, [',']);
          for (var part in detailParts) {
            part = part.trim();
            if (part.isNotEmpty) {
              final colonIdx = part.indexOf(':');
              if (colonIdx > 0 && colonIdx < part.length - 1) {
                final key = part.substring(0, colonIdx).trim();
                final value = part.substring(colonIdx + 1).trim();
                if (key.isNotEmpty && value.isNotEmpty) {
                  details.add('$key: $value');
                }
              } else {
                details.add(part);
              }
            }
          }
        }

        // Add body preview at the end if it exists
        if (bodyPreviewValue.isNotEmpty) {
          bodyPreviewValue =
              bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
          bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
          bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
          details.add('Body preview: $bodyPreviewValue');
        }

        if (details.isNotEmpty) {
          return details;
        }
      }
    }

    // Pattern 1.6: Check for "Additional Stat" patterns BEFORE other patterns
    // Format: "Additional Stat Added (Year X): Value: Y" or "Additional Stat Updated (Year X): ..."
    final lowerDescForStat = descriptionWithoutBodyPreview.toLowerCase().trim();
    if (lowerDescForStat.contains('additional stat')) {
      // Check if it matches the pattern: "Additional Stat Added/Updated (Year X): Value: Y"
      final additionalStatPattern = RegExp(
          r'Additional Stat\s+(Added|Updated)\s*\(Year\s+([^)]+)\):\s*(.+?)$',
          caseSensitive: false,
          dotAll: true);
      final additionalStatMatch =
          additionalStatPattern.firstMatch(descriptionWithoutBodyPreview);

      if (additionalStatMatch != null) {
        final action =
            additionalStatMatch.group(1)?.trim() ?? ''; // Added or Updated
        final year = additionalStatMatch.group(2)?.trim() ?? '';
        final detailsText = additionalStatMatch.group(3)?.trim() ?? '';

        // Build header
        final header = 'Additional Stat $action (Year $year):';
        details.add(header);

        // Parse the details part (e.g., "Value: 10" or "No changes detected")
        if (detailsText.isNotEmpty) {
          // Check if it's "No changes detected"
          if (detailsText.toLowerCase().contains('no changes detected')) {
            details.add('No changes detected');
          } else {
            // Parse key-value pairs from details
            final detailParts = _smartSplit(detailsText, [',']);
            for (var part in detailParts) {
              part = part.trim();
              if (part.isNotEmpty) {
                final colonIdx = part.indexOf(':');
                if (colonIdx > 0 && colonIdx < part.length - 1) {
                  final key = part.substring(0, colonIdx).trim();
                  final value = part.substring(colonIdx + 1).trim();
                  if (key.isNotEmpty && value.isNotEmpty) {
                    details.add('$key: $value');
                  }
                } else {
                  details.add(part);
                }
              }
            }
          }
        }

        // Add body preview at the end if it exists
        if (bodyPreviewValue.isNotEmpty) {
          bodyPreviewValue =
              bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
          bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
          bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
          details.add('Body preview: $bodyPreviewValue');
        }

        return details;
      }
    }

    // Pattern 2: Check for arrow format FIRST (old → new) - like "Utility Gas Updated: Provider Name: HPdsef → HP"
    // This needs to be checked before key-value parsing to avoid incorrect splitting
    if (descriptionWithoutBodyPreview.contains('→') ||
        descriptionWithoutBodyPreview.contains('->')) {
      // Check if it's a utility/property update with arrow format
      // Pattern: "Utility X Updated: Field Name: old → new"
      final utilityUpdatePattern = RegExp(
          r'([A-Za-z\s]+(?:Updated|updated)):\s*([A-Za-z\s]+):\s*(.+?)\s*(?:→|->)\s*(.+?)$',
          caseSensitive: false);
      final utilityMatch =
          utilityUpdatePattern.firstMatch(descriptionWithoutBodyPreview);

      if (utilityMatch != null) {
        // Utility update format detected
        final action = utilityMatch.group(1)?.trim() ?? '';
        final fieldName = utilityMatch.group(2)?.trim() ?? '';
        final oldValue = utilityMatch.group(3)?.trim() ?? '';
        final newValue = utilityMatch.group(4)?.trim() ?? '';

        if (action.isNotEmpty && fieldName.isNotEmpty) {
          details.add('$action: $fieldName: $oldValue → $newValue');

          // Add body preview at the end if it exists
          if (bodyPreviewValue.isNotEmpty) {
            bodyPreviewValue =
                bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
            bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
            bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
            details.add('Body preview: $bodyPreviewValue');
          }

          return details;
        }
      }
    }

    // Pattern 3: Check for action-based descriptions FIRST (before generic key-value)
    // These need to be checked before Pattern 4 to ensure they're parsed correctly
    // Examples: "Tenant moved out", "Tenant updated", "Lease created", etc.

    // Check for "Tenant moved out" pattern
    if (cleanDescription.toLowerCase().contains('tenant moved out') ||
        cleanDescription.toLowerCase().contains('moved out')) {
      return _parseTenantMovedOutDescription(cleanDescription);
    }

    // Check for "Tenant updated" pattern
    if (cleanDescription.toLowerCase().contains('tenant updated')) {
      return _parseTenantUpdatedDescription(cleanDescription);
    }

    // Check for lease/property patterns
    if (cleanDescription.toLowerCase().contains('lease created') ||
        cleanDescription.toLowerCase().contains('property:') ||
        cleanDescription.toLowerCase().contains('lease type:')) {
      return _parseLeaseDescription(cleanDescription);
    }

    // Pattern 4: Enhanced Key-Value pair detection
    // Look for patterns like "Key: Value" but handle nested content better
    // Parse description WITHOUT body preview first
    final keyValuePattern = RegExp(
        r'([A-Za-z][A-Za-z\s]+?):\s*([^:]+?)(?=\s+[A-Za-z][A-Za-z\s]+?:|$)',
        dotAll: true);
    final matches = keyValuePattern.allMatches(descriptionWithoutBodyPreview);

    if (matches.length >= 1) {
      // Multiple key-value pairs found
      for (var match in matches) {
        final key = match.group(1)?.trim() ?? '';
        var value = match.group(2)?.trim() ?? '';

        // Clean up value - remove trailing commas/semicolons
        value = value.replaceAll(RegExp(r'^[,;]\s*'), '');
        value = value.replaceAll(RegExp(r'\s*[,;]$'), '');

        if (key.isNotEmpty && value.isNotEmpty) {
          details.add('$key: $value');
        }
      }

      // Add body preview at the end if it exists (as plain text, not parsed)
      if (bodyPreviewValue.isNotEmpty) {
        bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
        bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
        details.add('Body preview: $bodyPreviewValue');
      }

      // If we found structured pairs, return them
      if (details.isNotEmpty) {
        return details;
      }
    }

    // Pattern 6: Very long description - split intelligently
    if (cleanDescription.length > 150) {
      // Try splitting by periods first
      final sentences = cleanDescription
          .split(RegExp(r'\.\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s.length > 10)
          .toList();

      if (sentences.length >= 2) {
        return sentences;
      }

      // Try splitting by line breaks or double spaces
      if (cleanDescription.contains('\n') || cleanDescription.contains('  ')) {
        final lines = cleanDescription
            .split(RegExp(r'\n+|  +'))
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (lines.length >= 2) {
          return lines;
        }
      }

      // Last resort: split by commas, but be smart about it
      if (cleanDescription.length > 200) {
        final parts = _smartSplit(cleanDescription, [',']);
        if (parts.length >= 2) {
          return parts;
        }
      }
    }

    // Default: Return as single item if no pattern matches
    return [cleanDescription];
  }

  /// Smart split that handles nested content (like parentheses, quotes)
  List<String> _smartSplit(String text, List<String> delimiters) {
    List<String> parts = [];
    String currentPart = '';
    int parenDepth = 0;
    bool inQuotes = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == '"' || char == "'") {
        inQuotes = !inQuotes;
        currentPart += char;
      } else if (char == '(') {
        parenDepth++;
        currentPart += char;
      } else if (char == ')') {
        parenDepth--;
        currentPart += char;
      } else if (!inQuotes && parenDepth == 0 && delimiters.contains(char)) {
        // Check if next non-space char starts a new key-value pair
        final remaining = text.substring(i + 1).trim();
        if (remaining.isNotEmpty) {
          // Check if it looks like a new key-value pair
          final looksLikeNewKey =
              RegExp(r'^[A-Za-z][A-Za-z\s]*:').hasMatch(remaining);

          if (looksLikeNewKey && currentPart.trim().isNotEmpty) {
            parts.add(currentPart.trim());
            currentPart = '';
            continue;
          }
        }
        currentPart += char;
      } else {
        currentPart += char;
      }
    }

    if (currentPart.trim().isNotEmpty) {
      parts.add(currentPart.trim());
    }

    return parts.where((p) => p.isNotEmpty).toList();
  }

  /// Parse lease charge description
  List<String> _parseLeaseChargeDescription(
      String description, String bodyPreviewValue) {
    List<String> details = [];

    // Extract main charge line: "Charge added: $X for Y"
    final chargeMatch = RegExp(
            r'Charge added:\s*\$?([\d,]+\.?\d*)\s+for\s+(.+?)(?:\.|Breakdown:|Updated by:|$)',
            caseSensitive: false)
        .firstMatch(description);

    if (chargeMatch != null) {
      final amount = chargeMatch.group(1)?.trim() ?? '';
      final chargeType = chargeMatch.group(2)?.trim() ?? '';
      details.add('Charge added: \$$amount for $chargeType');
    } else {
      // Fallback: just get "Charge added: ..." part until period or Breakdown
      final simpleMatch = RegExp(
              r'Charge added:\s*(.+?)(?:\.|Breakdown:|Updated by:|$)',
              caseSensitive: false)
          .firstMatch(description);
      if (simpleMatch != null) {
        details.add('Charge added: ${simpleMatch.group(1)?.trim() ?? ''}');
      }
    }

    // Extract Breakdown section if exists
    final breakdownMatch = RegExp(r'Breakdown:\s*(.+?)(?:\s+Updated by:|$)',
            caseSensitive: false, dotAll: true)
        .firstMatch(description);
    if (breakdownMatch != null) {
      final breakdown = breakdownMatch.group(1)?.trim() ?? '';
      if (breakdown.isNotEmpty) {
        // Clean up breakdown - remove trailing periods and "Updated by" text
        var cleanBreakdown = breakdown.replaceAll(RegExp(r'\.\s*$'), '').trim();
        cleanBreakdown =
            cleanBreakdown.replaceAll(RegExp(r'\s+Updated by:.*$'), '').trim();
        if (cleanBreakdown.isNotEmpty) {
          details.add('Breakdown: $cleanBreakdown');
        }
      }
    }

    // Extract Due date from brackets: [Due: 01/05/2026]
    final dueMatch = RegExp(r'\[Due:\s*([^\]]+)\]', caseSensitive: false)
        .firstMatch(description);
    if (dueMatch != null) {
      details.add('Due: ${dueMatch.group(1)?.trim() ?? ''}');
    }

    // Extract Type from parentheses: (Type: Charge)
    final typeMatch = RegExp(r'\(Type:\s*([^)]+)\)', caseSensitive: false)
        .firstMatch(description);
    if (typeMatch != null) {
      details.add('Type: ${typeMatch.group(1)?.trim() ?? ''}');
    }

    // Extract "Updated by" if exists
    final updatedByMatch = RegExp(r'Updated by:\s*(.+?)$', caseSensitive: false)
        .firstMatch(description);
    if (updatedByMatch != null) {
      details.add('Updated by: ${updatedByMatch.group(1)?.trim() ?? ''}');
    }

    // Add body preview at the end if it exists
    if (bodyPreviewValue.isNotEmpty) {
      bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
      details.add('Body preview: $bodyPreviewValue');
    }

    return details.isNotEmpty ? details : [description];
  }

  /// Parse lease payment description
  List<String> _parseLeasePaymentDescription(
      String description, String bodyPreviewValue) {
    List<String> details = [];

    // Extract payment amount and method: "Payment of $X via Y"
    final paymentMatch = RegExp(
            r'Payment\s+of\s+\$?([\d,]+\.?\d*)\s+via\s+([^(]+?)(?:\(|\.|Updated by:|$)',
            caseSensitive: false)
        .firstMatch(description);

    if (paymentMatch != null) {
      final amount = paymentMatch.group(1)?.trim() ?? '';
      final method = paymentMatch.group(2)?.trim() ?? '';
      details.add('Payment: \$$amount via $method');
    }

    // Extract Transaction ID
    final txIdMatch =
        RegExp(r'Transaction ID:\s*([^\s.]+)', caseSensitive: false)
            .firstMatch(description);
    if (txIdMatch != null) {
      details.add('Transaction ID: ${txIdMatch.group(1)?.trim() ?? ''}');
    }

    // Extract "Applied to:" section
    final appliedMatch = RegExp(r'Applied to:\s*(.+?)(?:\s+Updated by:|$)',
            caseSensitive: false, dotAll: true)
        .firstMatch(description);
    if (appliedMatch != null) {
      final appliedTo = appliedMatch.group(1)?.trim() ?? '';
      if (appliedTo.isNotEmpty) {
        // Clean up - remove trailing periods
        var cleanAppliedTo = appliedTo.replaceAll(RegExp(r'\.\s*$'), '').trim();
        // Parse comma-separated charges: "Charge1: $X, Charge2: $Y"
        final charges = _smartSplit(cleanAppliedTo, [',']);
        if (charges.length > 1) {
          details.add('Applied to:');
          for (var charge in charges) {
            charge = charge.trim();
            if (charge.isNotEmpty) {
              details.add('  $charge');
            }
          }
        } else {
          details.add('Applied to: $cleanAppliedTo');
        }
      }
    }

    // Extract "Updated by" if exists
    final updatedByMatch = RegExp(r'Updated by:\s*(.+?)$', caseSensitive: false)
        .firstMatch(description);
    if (updatedByMatch != null) {
      details.add('Updated by: ${updatedByMatch.group(1)?.trim() ?? ''}');
    }

    // Add body preview at the end if it exists
    if (bodyPreviewValue.isNotEmpty) {
      bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
      details.add('Body preview: $bodyPreviewValue');
    }

    return details.isNotEmpty ? details : [description];
  }

  /// Parse lease insurance description
  List<String> _parseLeaseInsuranceDescription(
      String description, String bodyPreviewValue) {
    List<String> details = [];

    // Extract policy info: "Renters insurance policy X added from Y"
    final policyMatch = RegExp(
            r'Renters insurance policy\s+([^\s]+)\s+added from\s+(.+?)(?:\(|with|Updated by:|$)',
            caseSensitive: false)
        .firstMatch(description);

    if (policyMatch != null) {
      final policyNumber = policyMatch.group(1)?.trim() ?? '';
      final company = policyMatch.group(2)?.trim() ?? '';
      details.add('Policy: $policyNumber');
      details.add('Company: $company');
    }

    // Extract Effective date
    final effectiveMatch = RegExp(r'Effective:\s*([^-]+)', caseSensitive: false)
        .firstMatch(description);
    if (effectiveMatch != null) {
      details.add('Effective: ${effectiveMatch.group(1)?.trim() ?? ''}');
    }

    // Extract Expires date
    final expiresMatch = RegExp(r'Expires:\s*([^\s)]+)', caseSensitive: false)
        .firstMatch(description);
    if (expiresMatch != null) {
      details.add('Expires: ${expiresMatch.group(1)?.trim() ?? ''}');
    }

    // Extract liability coverage
    final coverageMatch = RegExp(r'liability coverage of\s+\$?([\d,]+\.?\d*)',
            caseSensitive: false)
        .firstMatch(description);
    if (coverageMatch != null) {
      details
          .add('Liability Coverage: \$${coverageMatch.group(1)?.trim() ?? ''}');
    }

    // Extract "Updated by" if exists
    final updatedByMatch = RegExp(r'Updated by:\s*(.+?)$', caseSensitive: false)
        .firstMatch(description);
    if (updatedByMatch != null) {
      details.add('Updated by: ${updatedByMatch.group(1)?.trim() ?? ''}');
    }

    // Add body preview at the end if it exists
    if (bodyPreviewValue.isNotEmpty) {
      bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
      details.add('Body preview: $bodyPreviewValue');
    }

    return details.isNotEmpty ? details : [description];
  }

  /// Parse lease email description
  List<String> _parseLeaseEmailDescription(
      String description, String bodyPreviewValue) {
    List<String> details = [];

    // Extract subject: "Email sent: "subject" to email@domain.com"
    final emailMatch = RegExp(r'Email sent:\s*"([^"]+)"\s+to\s+([^\s.]+)',
            caseSensitive: false)
        .firstMatch(description);

    if (emailMatch != null) {
      final subject = emailMatch.group(1)?.trim() ?? '';
      final recipient = emailMatch.group(2)?.trim() ?? '';
      details.add('Email sent: "$subject"');
      details.add('To: $recipient');
    } else {
      // Fallback: simpler format - "Email sent: subject to email@domain.com"
      final simpleMatch = RegExp(r'Email sent:\s*(.+?)(?:\s+Updated by:|$)',
              caseSensitive: false)
          .firstMatch(description);
      if (simpleMatch != null) {
        var emailText = simpleMatch.group(1)?.trim() ?? '';
        // Remove trailing period
        emailText = emailText.replaceAll(RegExp(r'\.\s*$'), '').trim();
        details.add('Email sent: $emailText');
      }
    }

    // Extract "Updated by" if exists
    final updatedByMatch = RegExp(r'Updated by:\s*(.+?)$', caseSensitive: false)
        .firstMatch(description);
    if (updatedByMatch != null) {
      details.add('Updated by: ${updatedByMatch.group(1)?.trim() ?? ''}');
    }

    // Add body preview at the end if it exists
    if (bodyPreviewValue.isNotEmpty) {
      bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
      details.add('Body preview: $bodyPreviewValue');
    }

    return details.isNotEmpty ? details : [description];
  }

  /// Parse lease description with structured fields
  List<String> _parseLeaseDescription(String description) {
    List<String> details = [];

    // Extract main action (e.g., "Lease created")
    final actionMatch = RegExp(r'^([^:]+?):').firstMatch(description);
    String headerText = '';
    if (actionMatch != null) {
      headerText = actionMatch.group(1)?.trim() ?? '';
      if (headerText.isNotEmpty) {
        details.add(headerText); // Add header without colon
        // print('🔵 [LEASE DESC] Added header: "$headerText"');
      }
    }

    // Extract all key-value pairs after the header
    // Remove the header part from description before parsing key-value pairs
    String remainingDescription = description;
    if (headerText.isNotEmpty) {
      // Remove "Lease created: " from the start
      final headerPattern = RegExp(r'^' + RegExp.escape(headerText) + r':\s*',
          caseSensitive: false);
      remainingDescription =
          remainingDescription.replaceFirst(headerPattern, '');
    }

    // Pattern: "Key: Value" separated by commas
    final keyValuePattern = RegExp(
        r'([A-Za-z][A-Za-z\s]+?):\s*([^,;]+?)(?=\s+[A-Za-z][A-Za-z\s]+?:|,|$)',
        dotAll: true);
    final matches = keyValuePattern.allMatches(remainingDescription);

    // print(
        // '🔵 [LEASE DESC] Found ${matches.length} key-value matches in remaining: "$remainingDescription"');

    for (var match in matches) {
      final key = match.group(1)?.trim() ?? '';
      var value = match.group(2)?.trim() ?? '';

      // Clean up value - remove trailing commas, periods, dashes, and extra spaces
      value = value.replaceAll(RegExp(r'^[,;.\s\-]+'), '');
      value = value.replaceAll(RegExp(r'[,;.\s\-]+$'), '');
      value = value.trim();

      // Skip if key matches the header (shouldn't happen after removing header, but just in case)
      if (key.toLowerCase() == headerText.toLowerCase() &&
          headerText.isNotEmpty) {
        // print('🔵 [LEASE DESC] Skipping header key: "$key"');
        continue;
      }

      if (key.isNotEmpty && value.isNotEmpty) {
        details.add('$key: $value');
        // print('🔵 [LEASE DESC] Added detail: "$key: $value"');
      }
    }

    // print(
        // '🔵 [LEASE DESC] Final details count: ${details.length}, details: $details');

    if (details.length <= 1) {
      // Only header or empty - try general parsing
      // print('🔵 [LEASE DESC] Falling back to general parsing');
      return _parseGeneralDescription(description);
    }

    return details;
  }

  /// Parse "Tenant moved out" description format
  /// Format: "Tenant moved out: Leo Brown, Property: X, Move-out Date: Y, Notice Given: Z, Lease ID: W"
  List<String> _parseTenantMovedOutDescription(String description) {
    List<String> details = [];

    // Extract header "Tenant moved out"
    details.add('Tenant moved out');
    // print('🔵 [TENANT MOVED OUT] Added header: "Tenant moved out"');

    // Remove "Tenant moved out:" from the start
    String remainingDescription = description;
    final headerPattern =
        RegExp(r'^Tenant moved out:\s*', caseSensitive: false);
    remainingDescription =
        remainingDescription.replaceFirst(headerPattern, '').trim();

    // print(
        // '🔵 [TENANT MOVED OUT] Remaining after header: "$remainingDescription"');

    // Extract tenant name (comes first, before first key-value pair)
    // Pattern: "Name, Key: Value" or "Name, Key: Value, Key: Value"
    final firstCommaIndex = remainingDescription.indexOf(',');
    if (firstCommaIndex > 0) {
      final tenantName =
          remainingDescription.substring(0, firstCommaIndex).trim();

      // Check if it's a valid name (not a key-value pair)
      if (tenantName.isNotEmpty &&
          !tenantName.contains(':') &&
          tenantName.length > 1) {
        // Add tenant name as bullet point
        details.add('• $tenantName');
        // print('🔵 [TENANT MOVED OUT] Added tenant name: "$tenantName"');

        // Remove tenant name from remaining description
        remainingDescription =
            remainingDescription.substring(firstCommaIndex + 1).trim();
      }
    }

    // Extract key-value pairs from remaining description
    final keyValuePattern = RegExp(
        r'([A-Za-z][A-Za-z\s\-]+?):\s*([^,;]+?)(?=\s+[A-Za-z][A-Za-z\s\-]+?:|,|$)',
        dotAll: true);
    final matches = keyValuePattern.allMatches(remainingDescription);

    // print('🔵 [TENANT MOVED OUT] Found ${matches.length} key-value matches');

    for (var match in matches) {
      final key = match.group(1)?.trim() ?? '';
      var value = match.group(2)?.trim() ?? '';

      // Clean up value - remove trailing commas, periods, dashes, and extra spaces
      value = value.replaceAll(RegExp(r'^[,;.\s\-]+'), '');
      value = value.replaceAll(RegExp(r'[,;.\s\-]+$'), '');
      value = value.trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        details.add('$key: $value');
        // print('🔵 [TENANT MOVED OUT] Added detail: "$key: $value"');
      }
    }

    // print(
        // '🔵 [TENANT MOVED OUT] Final details count: ${details.length}, details: $details');

    if (details.length <= 1) {
      // Only header or empty - try general parsing
      // print('🔵 [TENANT MOVED OUT] Falling back to general parsing');
      return _parseGeneralDescription(description);
    }

    return details;
  }

  /// Parse "Tenant updated" description format
  /// Format: "Tenant updated by User: Name (email) (no field changes detected)" or similar
  List<String> _parseTenantUpdatedDescription(String description) {
    List<String> details = [];

    // Extract header "Tenant updated"
    details.add('Tenant updated');

    // Remove "Tenant updated" from the start
    String remainingDescription = description;
    final headerPattern =
        RegExp(r'^Tenant updated\s*(?:by\s+[^:]+)?:\s*', caseSensitive: false);
    remainingDescription =
        remainingDescription.replaceFirst(headerPattern, '').trim();

    // Extract key-value pairs or simple text
    final keyValuePattern = RegExp(
        r'([A-Za-z][A-Za-z\s\-]+?):\s*([^,;]+?)(?=\s+[A-Za-z][A-Za-z\s\-]+?:|,|$)',
        dotAll: true);
    final matches = keyValuePattern.allMatches(remainingDescription);

    if (matches.length > 0) {
      for (var match in matches) {
        final key = match.group(1)?.trim() ?? '';
        var value = match.group(2)?.trim() ?? '';

        // Clean up value
        value = value.replaceAll(RegExp(r'^[,;.\s\-]+'), '');
        value = value.replaceAll(RegExp(r'[,;.\s\-]+$'), '');
        value = value.trim();

        if (key.isNotEmpty && value.isNotEmpty) {
          details.add('$key: $value');
        }
      }
    } else if (remainingDescription.isNotEmpty) {
      // No key-value pairs, add as simple text
      details.add(remainingDescription);
    }

    if (details.length <= 1) {
      return _parseGeneralDescription(description);
    }

    return details;
  }

  /// Parse "Payment created" description format
  /// Format: "Payment created" followed by key-value pairs like:
  /// Amount: $X, Payment Method: Y, Status: Z, Transaction ID: ABC, Payment Date: MM/DD/YYYY,
  /// Surcharge: $X, Entry: Account Name: $Amount, etc.
  List<String> _parsePaymentCreatedDescription(
      String description, String bodyPreviewValue) {
    List<String> details = [];

    // Add header "Payment created"
    details.add('Payment created');

    // Extract key-value pairs from the description
    // Pattern: "Key: Value" or "Key: Value."
    // Improved pattern to better handle Entry data
    final keyValuePattern = RegExp(
        r'([A-Za-z][A-Za-z\s]+?):\s*([^:]+?)(?=\s+[A-Za-z][A-Za-z\s]+?:|\.\s*$|$|\n)',
        dotAll: true);
    final matches = keyValuePattern.allMatches(description);

    // print('🔵 [PAYMENT CREATED] Parsing description: "$description"');
    // print('🔵 [PAYMENT CREATED] Found ${matches.length} key-value matches');

    // Separate payment fields from entry fields
    List<String> paymentFieldDetails = [];
    List<String> entryFieldDetails = [];

    for (var match in matches) {
      final key = match.group(1)?.trim() ?? '';
      var value = match.group(2)?.trim() ?? '';

      // Clean up value - remove trailing periods, commas, and extra spaces
      value = value.replaceAll(RegExp(r'^[,;.\s]+'), '');
      value = value.replaceAll(RegExp(r'[,;.\s]+$'), '');
      value = value.trim();

      // print('🔵 [PAYMENT CREATED] Key: "$key", Value: "$value"');

      // Skip "Payment created" itself as we already added it as header
      if (key.toLowerCase().contains('payment created')) {
        continue;
      }

      if (key.isNotEmpty && value.isNotEmpty) {
        final keyLower = key.toLowerCase();

        // Check if it's an entry-related field
        bool isEntryField = keyLower.contains('entry') ||
            keyLower.contains('fee income') ||
            keyLower.contains('late fee income') ||
            keyLower.contains('rent income') ||
            keyLower.contains('conviniance fee') ||
            keyLower.contains('convenience fee');

        // Handle "Entry:" specially - extract account:amount pairs, skip labels
        if (keyLower.contains('entry')) {
          // Entry can contain account:amount pairs: "Entry: Rent Income: $15.00, conviniance fee: $1.05"
          // We skip "Entry: Late" type labels and only extract account:amount pairs

          if (value.contains(':')) {
            // Value contains account:amount pairs
            // Split by comma to get individual entries
            if (value.contains(',')) {
              final entries = value
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              for (var entry in entries) {
                // Check if entry has format "Account: Amount"
                final entryMatch = RegExp(r'([^:]+):\s*(.+)').firstMatch(entry);
                if (entryMatch != null) {
                  final account = entryMatch.group(1)?.trim() ?? '';
                  final amount = entryMatch.group(2)?.trim() ?? '';
                  // Add as separate line: "Account: Amount" (not "Entry: Account: Amount")
                  entryFieldDetails.add('$account: $amount');
                }
                // Skip labels like "Entry: Late" - don't add them
              }
            } else {
              // Single entry with account:amount format
              final entryMatch = RegExp(r'([^:]+):\s*(.+)').firstMatch(value);
              if (entryMatch != null) {
                final account = entryMatch.group(1)?.trim() ?? '';
                final amount = entryMatch.group(2)?.trim() ?? '';
                // Add as separate line: "Account: Amount"
                entryFieldDetails.add('$account: $amount');
              }
              // Skip labels like "Entry: Late" - don't add them
            }
          }
          // Skip "Entry: Late" type labels - don't add them to entryFieldDetails
        } else if (isEntryField) {
          // Entry-related field (Fee Income, Late Fee Income, Rent Income, etc.)
          entryFieldDetails.add('$key: $value');
        } else {
          // Regular payment field
          paymentFieldDetails.add('$key: $value');
        }
      }
    }

    // Add payment fields first
    details.addAll(paymentFieldDetails);

    // Add "Entry Details:" header if there are entry fields
    if (entryFieldDetails.isNotEmpty) {
      details.add('Entry Details:');
      details.addAll(entryFieldDetails);
    }

    // If no matches found, try to extract common payment fields manually
    if (details.length == 1) {
      // Only "Payment created" header
      // Try to extract Amount
      final amountMatch =
          RegExp(r'Amount:\s*\$?([\d,]+\.?\d*)', caseSensitive: false)
              .firstMatch(description);
      if (amountMatch != null) {
        details.add('Amount: \$${amountMatch.group(1)}');
      }

      // Try to extract Payment Method
      final methodMatch =
          RegExp(r'Payment Method:\s*([^,\.]+)', caseSensitive: false)
              .firstMatch(description);
      if (methodMatch != null) {
        details.add('Payment Method: ${methodMatch.group(1)?.trim()}');
      }

      // Try to extract Status
      final statusMatch = RegExp(r'Status:\s*([^,\.]+)', caseSensitive: false)
          .firstMatch(description);
      if (statusMatch != null) {
        details.add('Status: ${statusMatch.group(1)?.trim()}');
      }

      // Try to extract Transaction ID
      final txIdMatch =
          RegExp(r'Transaction ID:\s*([^,\.\s]+)', caseSensitive: false)
              .firstMatch(description);
      if (txIdMatch != null) {
        details.add('Transaction ID: ${txIdMatch.group(1)?.trim()}');
      }

      // Try to extract Payment Date
      final dateMatch =
          RegExp(r'Payment Date:\s*([^,\.]+)', caseSensitive: false)
              .firstMatch(description);
      if (dateMatch != null) {
        details.add('Payment Date: ${dateMatch.group(1)?.trim()}');
      }

      // Try to extract Surcharge
      final surchargeMatch =
          RegExp(r'Surcharge:\s*\$?([\d,]+\.?\d*)', caseSensitive: false)
              .firstMatch(description);
      if (surchargeMatch != null) {
        details.add('Surcharge: \$${surchargeMatch.group(1)}');
      }

      // Extract individual account:amount pairs
      // Skip "Entry:" labels - we only want account:amount pairs under "Entry Details:"
      // Look for patterns like "Fee Income: $0.10", "Rent Income: $8.90", "conviniance fee: $0.70"
      // These might come after "Entry:" or be separate
      final accountAmountPattern = RegExp(
          r'([A-Za-z][A-Za-z\s]+?):\s*\$?([\d,]+\.?\d*)',
          caseSensitive: false);
      final accountMatches = accountAmountPattern.allMatches(description);

      // Filter out common payment fields we've already extracted
      final excludedKeys = [
        'amount',
        'payment method',
        'status',
        'transaction id',
        'payment date',
        'surcharge',
        'entry'
      ];
      final entryAccounts = <String, String>{};

      for (var match in accountMatches) {
        final account = match.group(1)?.trim() ?? '';
        final amount = match.group(2)?.trim() ?? '';
        final accountLower = account.toLowerCase();

        // Skip if it's a payment field we've already extracted
        bool isExcluded =
            excludedKeys.any((excluded) => accountLower.contains(excluded));

        // Only include if it looks like an income/account entry (not a payment field)
        if (!isExcluded && account.isNotEmpty && amount.isNotEmpty) {
          // Check if it's likely an entry account (contains "income", "fee", etc.)
          if (accountLower.contains('income') ||
              accountLower.contains('fee') ||
              accountLower.contains('rent') ||
              accountLower.contains('deposit') ||
              accountLower.contains('charge') ||
              accountLower.contains('conviniance')) {
            entryAccounts[account] = amount;
          }
        }
      }

      // Add "Entry Details:" header if we have entry accounts
      if (entryAccounts.isNotEmpty) {
        details.add('Entry Details:');
        // Add entry accounts as separate lines under "Entry Details:"
        for (var entry in entryAccounts.entries) {
          details.add('${entry.key}: \$${entry.value}');
        }
      }
    }

    // Add body preview at the end if it exists
    if (bodyPreviewValue.isNotEmpty) {
      bodyPreviewValue = bodyPreviewValue.replaceAll(RegExp(r'<[^>]+>'), '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('**', '');
      bodyPreviewValue = bodyPreviewValue.replaceAll('&nbsp;', ' ');
      details.add('Body preview: $bodyPreviewValue');
    }

    return details.isNotEmpty ? details : [description];
  }

  /// General description parser as fallback
  List<String> _parseGeneralDescription(String description) {
    List<String> details = [];

    // Try to find key-value pairs
    final keyValuePattern = RegExp(
        r'([A-Za-z][A-Za-z\s]+?):\s*([^:]+?)(?=\s+[A-Za-z][A-Za-z\s]+?:|$)',
        dotAll: true);
    final matches = keyValuePattern.allMatches(description);

    if (matches.length >= 1) {
      for (var match in matches) {
        final key = match.group(1)?.trim() ?? '';
        var value = match.group(2)?.trim() ?? '';
        value = value
            .replaceAll(RegExp(r'^[,;]\s*'), '')
            .replaceAll(RegExp(r'\s*[,;]$'), '');

        if (key.isNotEmpty && value.isNotEmpty) {
          // Special handling: Body preview should not be parsed further
          if (key.toLowerCase().contains('body preview')) {
            // Clean HTML but don't parse further
            value = value.replaceAll(RegExp(r'<[^>]+>'), '');
            value = value.replaceAll('**', '');
            value = value.replaceAll('&nbsp;', ' ');
          }
          details.add('$key: $value');
        }
      }
    }

    // If no key-value pairs found, split by common patterns
    if (details.isEmpty) {
      final parts = _smartSplit(description, [',', ';', '.']);
      if (parts.length > 1) {
        return parts;
      }
    }

    return details.isEmpty ? [description] : details;
  }

  /// Reformat any embedded date strings in [text] according to the provider's date format.
  String _formatDatesInText(String text, DateProvider dateProvider) {
    return text.replaceAllMapped(
      RegExp(r'\b(\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2})\b'),
      (match) => dateProvider.formatCurrentDate(match.group(0)!),
    );
  }

  /// Build description widget with parsed details
  Widget _buildDescriptionWidget(String description,
      {HistoryItem? historyItem}) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final parsedDetails = _parseDescription(description)
        // Lease History shows dates and amounts exactly as web does
        // (formatDaysInText + formatCurrencyInText), so the search finds
        // what is shown.
        .map((detail) => _isLease
            ? leaseHistoryShownDescription(detail, dateProvider.dateFormat)
            : _formatDatesInText(detail, dateProvider))
        .toList();

    // For "Payment created" entries, also check metadata for Entry data
    if (historyItem != null &&
        historyItem.metadata != null &&
        description.toLowerCase().contains('payment created')) {
      // Check if metadata has entry array
      if (historyItem.metadata!['entry'] != null) {
        final entryList = historyItem.metadata!['entry'];
        if (entryList is List && entryList.isNotEmpty) {
          // Add Entry data from metadata to parsed details
          // Find where to insert (after payment fields, before body preview)
          int insertIndex = parsedDetails.length;

          // Check if body preview exists, insert before it
          for (int i = 0; i < parsedDetails.length; i++) {
            if (parsedDetails[i].toLowerCase().startsWith('body preview')) {
              insertIndex = i;
              break;
            }
          }

          // Check if "Entry Details:" header already exists in parsed details
          bool hasEntryDetailsHeader = parsedDetails.any((detail) =>
              detail.toLowerCase().trim().startsWith('entry details:'));

          // Add "Entry Details:" header if not present
          if (!hasEntryDetailsHeader) {
            parsedDetails.insert(insertIndex, 'Entry Details:');
            insertIndex++;
          } else {
            // Find the index of "Entry Details:" header
            for (int i = 0; i < parsedDetails.length; i++) {
              if (parsedDetails[i]
                  .toLowerCase()
                  .trim()
                  .startsWith('entry details:')) {
                insertIndex = i + 1;
                break;
              }
            }
          }

          // Add each entry's account and amount under "Entry Details:"
          for (var entry in entryList) {
            if (entry is Map) {
              final account = entry['account']?.toString() ?? '';
              final amount = entry['amount'];

              if (account.isNotEmpty && amount != null) {
                // Format amount
                String amountStr = '';
                if (amount is num) {
                  amountStr = amount.toStringAsFixed(2);
                  // Add commas for thousands
                  final parts = amountStr.split('.');
                  final integerPart = parts[0];
                  final decimalPart = parts.length > 1 ? parts[1] : '00';
                  final regex = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
                  final formattedInteger = integerPart.replaceAllMapped(
                    regex,
                    (Match m) => '${m[1]},',
                  );
                  amountStr = '\$$formattedInteger.$decimalPart';
                } else {
                  amountStr = '\$$amount';
                }

                parsedDetails.insert(insertIndex, '$account: $amountStr');
                insertIndex++;
              }
            }
          }
        }
      }
    }

    if (parsedDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    if (parsedDetails.length == 1) {
      // Single item - show as simple text
      // For lease history, show full description text
      return Text(
        parsedDetails[0],
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
          fontSize: 14,
        ),
      );
    }

    // For lease history with body preview, show description first, then body preview
    if (widget.historyType == HistoryType.lease && parsedDetails.length == 2) {
      final description = parsedDetails[0];
      final bodyPreview = parsedDetails[1];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              fontSize: 14,
            ),
          ),
          if (bodyPreview.toLowerCase().startsWith('body preview')) ...[
            const SizedBox(height: 8),
            Text(
              'Body preview:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                bodyPreview.substring('Body preview:'.length).trim(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Multiple items - show as list
    // Check if first item is a header (like "Utility Added (Unit X): utilityname", "Payment created", "Entry Details:")
    // and rest are details (like "Provider: X", "Account: Y")
    bool hasHeader = false;
    String? headerText;
    List<String> detailItems = [];

    if (parsedDetails.length > 1) {
      final firstItem = parsedDetails[0];
      // Check if first item looks like a header
      final firstItemLower = firstItem.toLowerCase().trim();
      if (firstItemLower.startsWith('utility added') ||
          firstItemLower.startsWith('utility deleted') ||
          firstItemLower.startsWith('additional stat added') ||
          firstItemLower.startsWith('additional stat updated') ||
          firstItemLower.startsWith('payment created') ||
          firstItemLower.startsWith('lease created') ||
          firstItemLower.startsWith('tenant moved out') ||
          firstItemLower.startsWith('tenant updated') ||
          firstItemLower.startsWith('mortgage updated')) {
        hasHeader = true;
        headerText = firstItem;
        detailItems = parsedDetails.sublist(1);
      }

      // Check for "Entry Details:" header in the details
      int entryDetailsIndex = -1;
      for (int i = 0; i < parsedDetails.length; i++) {
        if (parsedDetails[i]
            .toLowerCase()
            .trim()
            .startsWith('entry details:')) {
          entryDetailsIndex = i;
          break;
        }
      }

      // If "Entry Details:" found, treat it as a sub-header
      // Items after it should be indented more
      if (entryDetailsIndex != -1 &&
          entryDetailsIndex < parsedDetails.length - 1) {
        // This will be handled in the widget builder
      }
    }

    if (hasHeader && headerText != null) {
      // Display header with expandable details
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - wrap properly to prevent awkward text breaking
          Text(
            headerText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
          // Details (indented)
          if (detailItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: detailItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final detail = entry.value;

                  // Check if it's "Entry Details:" header - make it bold
                  final isEntryDetailsHeader =
                      detail.toLowerCase().trim().startsWith('entry details:');

                  // Check if it's an entry item (comes after "Entry Details:")
                  // Find if there's an "Entry Details:" before this item
                  bool isEntryItem = false;
                  for (int i = 0; i <= index; i++) {
                    if (i < detailItems.length &&
                        detailItems[i]
                            .toLowerCase()
                            .trim()
                            .startsWith('entry details:')) {
                      isEntryItem = true;
                      break;
                    }
                  }

                  // Check if it's a bullet point (starts with "•")
                  if (detail.trim().startsWith('•')) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index < detailItems.length - 1 ? 4 : 0),
                      child: Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }

                  // Check if it's a key-value pair
                  final colonIndex = detail.indexOf(':');
                  if (colonIndex > 0 && colonIndex < detail.length - 1) {
                    final key = detail.substring(0, colonIndex).trim();
                    final value = detail.substring(colonIndex + 1).trim();

                    // Special handling for mortgage history: parse "old" → "new" format
                    if (widget.historyType == HistoryType.mortgage &&
                        value.contains('→')) {
                      // Parse format: "old" → "new" or "old" → "new" (with quotes)
                      final arrowIndex = value.indexOf('→');
                      if (arrowIndex > 0) {
                        final oldValuePart =
                            value.substring(0, arrowIndex).trim();
                        final newValuePart =
                            value.substring(arrowIndex + 1).trim();

                        // Remove quotes if present
                        String oldValue =
                            oldValuePart.replaceAll('"', '').trim();
                        String newValue =
                            newValuePart.replaceAll('"', '').trim();

                        // If old value is empty or same as new, it might be an addition (like "Added new payoff...")
                        if (oldValue.isEmpty ||
                            oldValue == newValue ||
                            !oldValuePart.contains('"')) {
                          // This is an addition, not a change - show as plain text
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: index < detailItems.length - 1 ? 4 : 0,
                                left: isEntryItem && !isEntryDetailsHeader
                                    ? 16.0
                                    : 0.0),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.start,
                              children: [
                                Text(
                                  '$key: ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  value,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Render old → new with colors - inline layout like web
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: index < detailItems.length - 1 ? 6 : 0,
                              left: isEntryItem && !isEntryDetailsHeader
                                  ? 16.0
                                  : 0.0),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              // Key label
                              Text(
                                '$key: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              // Old value in red background
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  oldValue,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red.shade900,
                                  ),
                                ),
                              ),
                              // Arrow
                              Text(
                                ' → ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              // New value in green background
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  newValue,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }

                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: index < detailItems.length - 1 ? 4 : 0,
                          left: isEntryItem && !isEntryDetailsHeader
                              ? 16.0
                              : 0.0), // Extra indent for Entry items
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          Text(
                            '$key: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isEntryDetailsHeader
                                  ? FontWeight.bold
                                  : (isEntryItem
                                      ? FontWeight.w500
                                      : FontWeight.bold),
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isEntryDetailsHeader
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: index < detailItems.length - 1 ? 4 : 0,
                        left: isEntryItem && !isEntryDetailsHeader
                            ? 16.0
                            : 0.0), // Extra indent for Entry items
                    child: Text(
                      detail,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isEntryDetailsHeader
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      );
    }

    // Regular list display (no special header)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parsedDetails.asMap().entries.map((entry) {
        final index = entry.key;
        final detail = entry.value;

        // Check if this is an indented item (starts with spaces) - used for "Applied to:" sub-items
        final isIndented = detail.startsWith('  ');
        final displayDetail = isIndented ? detail.substring(2) : detail;

        // Check if it's a key-value pair
        final colonIndex = displayDetail.indexOf(':');
        if (colonIndex > 0 && colonIndex < displayDetail.length - 1) {
          final key = displayDetail.substring(0, colonIndex).trim();
          final value = displayDetail.substring(colonIndex + 1).trim();

          // Special handling for mortgage history: parse "old" → "new" format
          if (widget.historyType == HistoryType.mortgage &&
              value.contains('→')) {
            final arrowIndex = value.indexOf('→');
            if (arrowIndex > 0) {
              final oldValuePart = value.substring(0, arrowIndex).trim();
              final newValuePart = value.substring(arrowIndex + 1).trim();

              // Remove quotes if present
              String oldValue = oldValuePart.replaceAll('"', '').trim();
              String newValue = newValuePart.replaceAll('"', '').trim();

              // If old value is empty or same as new, it might be an addition
              if (oldValue.isEmpty ||
                  oldValue == newValue ||
                  !oldValuePart.contains('"')) {
                // This is an addition, not a change - show as plain text
                return Padding(
                  padding: EdgeInsets.only(
                      left: isIndented ? 16.0 : 0.0,
                      bottom: index < parsedDetails.length - 1 ? 6 : 0),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      Text(
                        '$key: ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Render old → new with colors - inline layout like web
              return Padding(
                padding: EdgeInsets.only(
                    left: isIndented ? 16.0 : 0.0,
                    bottom: index < parsedDetails.length - 1 ? 6 : 0),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    // Key label
                    Text(
                      '$key: ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    // Old value in red background
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        oldValue,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                    // Arrow
                    const Text(
                      ' → ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    // New value in green background
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        newValue,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          // Special handling: Body preview value should be displayed as plain text
          // Don't parse nested key-values inside it (like Email Address:, Password:, etc.)
          if (key.toLowerCase().contains('body preview')) {
            return Padding(
              padding: EdgeInsets.only(
                  left: isIndented ? 16.0 : 0.0,
                  bottom: index < parsedDetails.length - 1 ? 6 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$key:',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Check if value contains arrow format (old → new)
          if (value.contains('→') || value.contains('->')) {
            final arrowIndex = value.indexOf('→') != -1
                ? value.indexOf('→')
                : value.indexOf('->');
            if (arrowIndex > 0) {
              final oldValue = value.substring(0, arrowIndex).trim();
              final arrowSymbol = value.contains('→') ? '→' : '->';
              final newValue =
                  value.substring(arrowIndex + arrowSymbol.length).trim();

              return Padding(
                padding: EdgeInsets.only(
                    left: isIndented ? 16.0 : 0.0,
                    bottom: index < parsedDetails.length - 1 ? 6 : 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$key: ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        oldValue,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    const Text(
                      '→',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        newValue,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                left: isIndented ? 16.0 : 0.0,
                bottom: index < parsedDetails.length - 1 ? 6 : 0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                Text(
                  '$key: ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }

        // Regular text item
        return Padding(
          padding: EdgeInsets.only(
              left: isIndented ? 16.0 : 0.0,
              bottom: index < parsedDetails.length - 1 ? 6 : 0),
          child: Text(
            '• $displayDetail',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // print(
        // '🔵 CustomHistoryTable build - Type: ${widget.historyType}, EntityId: ${widget.entityId}, Title: ${widget.title}');

    return FutureBuilder<HistoryResponse>(
      future: _historyFuture,
      builder: (context, snapshot) {
        // print(
            // '🔵 History FutureBuilder - ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}');

        // Lease History: the rows the search keeps (all of them when the
        // search is empty), like web.
        final List<HistoryItem>? leaseRows = _isLease &&
                snapshot.connectionState != ConnectionState.waiting &&
                snapshot.hasData
            ? _leaseRowsMatching(
                _allHistoryItems ?? snapshot.data!.data, context)
            : null;

        if (snapshot.connectionState == ConnectionState.waiting) {
          // print('⏳ History loading...');
          // Show title and header structure while loading
          return RepaintBoundary(
            child: Column(
              children: [
                // Title
                Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.titleFontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Lease History keeps web's search box while it loads.
                if (_isLease) _leaseSearchBox(),
                // Table Header
                Container(
                  decoration: BoxDecoration(
                    color: widget.blueColor.withOpacity(0.1),
                    border: Border.all(color: const Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                Text(
                                  width < 400
                                      ? "Date & Time"
                                      : "     Date & Time",
                                  style: TextStyle(
                                    color: widget.blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                Text(
                                  widget.historyType == HistoryType.lease
                                      ? "     Action"
                                      : "     User",
                                  style: TextStyle(
                                    color: widget.blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 4,
                          child: Text(
                            "     Description",
                            style: TextStyle(
                              color: widget.blueColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Loading indicator
                const Center(
                  child: SpinKitFadingCircle(
                    color: Color(0xFF152B51),
                    size: 40.0,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          // print('🔴 History Error: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  'Error loading history: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _refreshHistory();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData ||
            snapshot.data!.data.isEmpty ||
            (leaseRows != null && leaseRows.isEmpty)) {
          // print(
              // '⚠️ History - No data or empty data. Data count: ${snapshot.hasData ? snapshot.data!.data.length : 0}');
          // Show title and header even when no data. Lease History keeps
          // its search box and uses web's messages.
          final String emptyMessage = !_isLease
              ? 'No history data available'
              : (_leaseSearch.isNotEmpty
                  ? leaseHistoryNoMatchMessage
                  : leaseHistoryEmptyMessage);
          return RepaintBoundary(
            child: Column(
              children: [
                // Title
                Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.titleFontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isLease) _leaseSearchBox(),
                // Table Header
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBE0E5)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 20.0),
                                  child: Text(
                                    width < 400
                                        ? "Date & Time"
                                        : "     Date & Time",
                                    style: TextStyle(
                                      color: widget.blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                Text(
                                  widget.historyType == HistoryType.lease
                                      ? "     Action"
                                      : "     User",
                                  style: TextStyle(
                                    color: widget.blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10), // No data message
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFDBE0E5)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // print(
              // '✅ History loaded successfully - ${snapshot.data!.data.length} items');

          // Handle frontend pagination if we have all items stored
          List<HistoryItem> displayData = snapshot.data!.data;
          PaginationInfo pagination = snapshot.data!.pagination;

          // For lease history or frontend pagination, slice the data based on current page
          if (widget.historyType == HistoryType.lease) {
            // Lease history: the rows the search keeps, a page of the chosen
            // size at a time, or all of them with "All", like web.
            final allItems = leaseRows ?? _allHistoryItems ?? snapshot.data!.data;
            final perPage = _perPage;
            final pages = _leaseShowAll || allItems.isEmpty
                ? 1
                : (allItems.length / perPage).ceil();
            final page = _currentPage.clamp(1, pages);
            if (_leaseShowAll) {
              displayData = allItems;
            } else {
              final startIndex = (page - 1) * perPage;
              final endIndex = startIndex + perPage;
              displayData = allItems.sublist(
                startIndex,
                endIndex > allItems.length ? allItems.length : endIndex,
              );
            }
            pagination = PaginationInfo(
              total: allItems.length,
              page: page,
              limit: perPage,
              totalPages: pages,
            );
            // print(
                // '🔵 Lease History Pagination - Total: ${allItems.length}, Showing items ${startIndex + 1}-${endIndex > allItems.length ? allItems.length : endIndex}, Page: $_currentPage of $totalPages');
          } else if (_isFrontendPagination &&
              _allHistoryItems != null &&
              _allHistoryItems!.isNotEmpty) {
            // Other frontend pagination - slice the stored data
            final startIndex = (_currentPage - 1) * widget.itemsPerPage;
            final endIndex = startIndex + widget.itemsPerPage;
            displayData = _allHistoryItems!.sublist(
              startIndex,
              endIndex > _allHistoryItems!.length
                  ? _allHistoryItems!.length
                  : endIndex,
            );
            final totalPages =
                (_allHistoryItems!.length / widget.itemsPerPage).ceil();
            pagination = PaginationInfo(
              total: _allHistoryItems!.length,
              page: _currentPage,
              limit: widget.itemsPerPage,
              totalPages: totalPages > 0 ? totalPages : 1,
            );
            // print(
                // '🔵 Frontend Pagination - Showing items ${startIndex + 1}-${endIndex > _allHistoryItems!.length ? _allHistoryItems!.length : endIndex} of ${_allHistoryItems!.length}');
          }

          final historyData =
              HistoryResponse(data: displayData, pagination: pagination);
          final finalPagination = pagination;

          return RepaintBoundary(
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 2),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.blueColor,
                        fontWeight: FontWeight.bold,
                        fontSize: widget.titleFontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isLease) _leaseSearchBox(),
                // Header
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBE0E5)),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 20.0),
                                  child: Text(
                                    width < 400
                                        ? "Date & Time"
                                        : "     Date & Time",
                                    style: TextStyle(
                                      color: widget.blueColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () {},
                            child: Row(
                              children: [
                                Text(
                                  widget.historyType == HistoryType.lease
                                      ? "     Action"
                                      : "     User",
                                  style: TextStyle(
                                    color: widget.blueColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Data Rows
                Container(
                  child: Column(
                    children: historyData.data.asMap().entries.map((entry) {
                      int index = entry.key;
                      HistoryItem historyItem = entry.value;
                      bool isExpandedLocal = _expandedIndex == index;
                      String formattedDate =
                          _formatDateTimeWithAMPM(historyItem.date, context);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: index % 2 != 0
                              ? const Color(0xFFF4F8FF)
                              : Colors.white,
                          border: Border.all(color: const Color(0xFFDBE0E5)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: <Widget>[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: <Widget>[
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (_expandedIndex == index) {
                                            _expandedIndex = null;
                                          } else {
                                            _expandedIndex = index;
                                          }
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        padding: !isExpandedLocal
                                            ? const EdgeInsets.only(bottom: 10)
                                            : const EdgeInsets.only(top: 10),
                                        child: FaIcon(
                                          isExpandedLocal
                                              ? FontAwesomeIcons.sortUp
                                              : FontAwesomeIcons.sortDown,
                                          size: 20,
                                          color: widget.blueColor,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (_expandedIndex == index) {
                                              _expandedIndex = null;
                                            } else {
                                              _expandedIndex = index;
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 5.0),
                                          child: Text(
                                            formattedDate,
                                            style: TextStyle(
                                              color: widget.blueColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        widget.historyType == HistoryType.lease
                                            ? (historyItem.action.isNotEmpty
                                                ? historyItem.action
                                                : (historyItem
                                                        .category.isNotEmpty
                                                    ? historyItem.category
                                                    : historyItem.type))
                                            : historyItem.username,
                                        style: TextStyle(
                                          color: widget.blueColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpandedLocal)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                margin: const EdgeInsets.only(bottom: 20),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          FaIcon(
                                            isExpandedLocal
                                                ? FontAwesomeIcons.sortUp
                                                : FontAwesomeIcons.sortDown,
                                            size: 20,
                                            color: Colors.transparent,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                // Description with parsed details
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Description :',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: widget.blueColor,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 20),
                                                      child: Container(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsets
                                                                .fromLTRB(
                                                                12, 12, 12, 16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Colors.grey[100],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                              color: Colors
                                                                  .grey[300]!),
                                                        ),
                                                        child:
                                                            _buildDescriptionWidget(
                                                                historyItem
                                                                    .description,
                                                                historyItem:
                                                                    historyItem),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // For lease history: show Type and Updated by
                                                // For other history types: show only Description (no Type, no Details)
                                                if (widget.historyType ==
                                                    HistoryType.lease) ...[
                                                  if (historyItem.type
                                                          .toString()
                                                          .isNotEmpty ||
                                                      historyItem
                                                          .username.isNotEmpty)
                                                    const SizedBox(height: 10),
                                                  if (historyItem.type
                                                      .toString()
                                                      .isNotEmpty) ...[
                                                    Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text: 'Type : ',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: widget
                                                                  .blueColor,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: historyItem
                                                                .type,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Colors.grey,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (historyItem
                                                        .username.isNotEmpty)
                                                      const SizedBox(height: 8),
                                                  ],
                                                  if (historyItem
                                                      .username.isNotEmpty) ...[
                                                    Text.rich(
                                                      TextSpan(
                                                        children: [
                                                          TextSpan(
                                                            text:
                                                                'Updated by : ',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: widget
                                                                  .blueColor,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          TextSpan(
                                                            text: historyItem
                                                                .username,
                                                            style:
                                                                const TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .black87,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ],
                                            ),
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
                // Pagination Controls. Lease History: web's page sizes and
                // "All", shown whenever there are rows, like web.
                if (_isLease)
                  DashboardPaginationFooter(
                    currentPage: finalPagination.page,
                    totalPages: finalPagination.totalPages,
                    rowsPerPage: _perPage,
                    rowsPerPageOptions: leaseHistoryPageSizes,
                    onRowsPerPageChanged: _setLeasePageSize,
                    showAllOption: true,
                    showAll: _leaseShowAll,
                    onShowAll: _showAllLeaseRows,
                    totalRecords: finalPagination.total,
                    onPrev: finalPagination.page > 1
                        ? () => _goToPage(finalPagination.page - 1)
                        : null,
                    onNext: finalPagination.page < finalPagination.totalPages
                        ? () => _goToPage(finalPagination.page + 1)
                        : null,
                  )
                else if (finalPagination.totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: FaIcon(
                            FontAwesomeIcons.circleChevronLeft,
                            size: 30,
                            color: _currentPage <= 1
                                ? Colors.grey
                                : widget.blueColor,
                          ),
                          onPressed: _currentPage <= 1
                              ? null
                              : () {
                                  _goToPage(_currentPage - 1);
                                },
                        ),
                        Text(
                          'Page ${finalPagination.page} of ${finalPagination.totalPages}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        IconButton(
                          icon: FaIcon(
                            FontAwesomeIcons.circleChevronRight,
                            size: 30,
                            color: _currentPage >= finalPagination.totalPages
                                ? Colors.grey
                                : widget.blueColor,
                          ),
                          onPressed: _currentPage >= finalPagination.totalPages
                              ? null
                              : () {
                                  _goToPage(_currentPage + 1);
                                },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }
      },
    );
  }
}
