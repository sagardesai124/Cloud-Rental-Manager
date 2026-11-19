import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../constant/constant.dart';

/// The one pagination footer for every dashboard table, Admin and Staff.
///
/// The dashboard previously carried two different footers — a "modern" one on
/// the Failed Payments section (Material elevation 2, radius 8, grey.shade300
/// border) and an older one everywhere else (elevation 3, square corners,
/// unstyled page label). This is the modern one, in a single place.
///
/// It owns its own vertical spacing, so call sites must NOT wrap it in a
/// SizedBox — that double spacing is what made the gap around the old footers
/// look so large.
///
/// Contract:
///  * [currentPage] is 1-BASED. A 0-based caller passes `page + 1`.
///  * [onPrev] / [onNext] must be null at the bounds — the chevron greys itself
///    from the null callback, so there is no separate colour argument.
class DashboardPaginationFooter extends StatelessWidget {
  /// 1-based.
  final int currentPage;
  final int totalPages;
  final int rowsPerPage;
  final List<int> rowsPerPageOptions;
  final ValueChanged<int>? onRowsPerPageChanged;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  /// Web's "All" page size (CommonPagination), listed first. While [showAll]
  /// the arrows give way to "Showing all [totalRecords] records". Off by
  /// default, so existing tables are unchanged.
  final bool showAllOption;
  final bool showAll;
  final VoidCallback? onShowAll;
  final int totalRecords;

  static const int _kAllValue = -1;

  /// The footer's own breathing room, above and below.
  static const double kFooterPad = 4.0;

  /// The gap every dashboard call site should leave between two sections.
  static const double kSectionGap = 8.0;

  static const List<int> kDefaultOptions = <int>[5, 10, 25];

  const DashboardPaginationFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.rowsPerPage,
    this.rowsPerPageOptions = kDefaultOptions,
    this.onRowsPerPageChanged,
    this.onPrev,
    this.onNext,
    this.showAllOption = false,
    this.showAll = false,
    this.onShowAll,
    this.totalRecords = 0,
  });

  Widget _chevron(IconData icon, VoidCallback? onTap) {
    return IconButton(
      // A default IconButton is 48x48 with 8dp of padding, which is what made
      // the old footer taller than the 40dp dropdown beside it. Pinning it to
      // 40x40 squares the row up and removes the dead height.
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      splashRadius: 22,
      icon: FaIcon(
        icon,
        size: 24,
        color: onTap == null ? Colors.grey : blueColor,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Never render "of 0".
    final int safeTotal = totalPages < 1 ? 1 : totalPages;

    // DropdownButton asserts that exactly one item matches `value`; a caller
    // whose saved page size is not in its own option list would crash without
    // this.
    final List<int> options = rowsPerPageOptions.contains(rowsPerPage)
        ? rowsPerPageOptions
        : (<int>[...rowsPerPageOptions, rowsPerPage]..sort());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kFooterPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Flat, not raised. The old footers wrapped this in Material with an
          // elevation shadow on top of a hard grey border, which is what still
          // read as the "old" boxy control — a soft border and a rounder radius
          // sit better next to the shadowed white row cards above it.
          Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDBE0E5)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: showAllOption && showAll ? _kAllValue : rowsPerPage,
                  isExpanded: false,
                  items: [
                    if (showAllOption) _kAllValue,
                    ...options,
                  ].map((int value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text(
                        value == _kAllValue ? 'All' : value.toString(),
                        style:
                            const TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    );
                  }).toList(),
                  onChanged: onRowsPerPageChanged == null
                      ? null
                      : (int? newValue) {
                          if (newValue == null) return;
                          if (newValue == _kAllValue) {
                            onShowAll?.call();
                          } else {
                            onRowsPerPageChanged!(newValue);
                          }
                        },
                  icon: Icon(Icons.arrow_drop_down, color: blueColor, size: 24),
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                  dropdownColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (showAllOption && showAll)
            Text('Showing all $totalRecords records',
                style: const TextStyle(fontSize: 14))
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chevron(FontAwesomeIcons.circleChevronLeft, onPrev),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text(
                    'Page $currentPage of $safeTotal',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                _chevron(FontAwesomeIcons.circleChevronRight, onNext),
              ],
            ),
        ],
      ),
    );
  }
}
