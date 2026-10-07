// Table support for email bodies shown with flutter_html.
//
// Payment receipts and the daily digests (Scheduled Payment, Insurance
// Summary, Late Fee, Expired Leases, ACH Payment Status…) lay their content
// out with HTML <table>s. flutter_html 3.x moved table rendering into the
// separate flutter_html_table add-on, so without it everything inside a
// table — receipt header and rows — was dropped and only the text around the
// tables (usually just the sign-off) was left. Web (EmailDialog.jsx) renders
// the same body in the browser, so it showed the full email.
//
// On a phone every table must fit the card — no sideways scrolling:
//  * Data tables (a header row over rows, 3+ columns) are shown the way the
//    app's own list tables look: a header bar with the first two column
//    titles, then one card per row with the remaining columns as
//    "Label : value" lines. Readable at any width, like Tenants/Leases lists.
//  * Other tables (layout blocks such as a receipt's title-and-address
//    header, or two-column label/value tables) render as tables at the
//    card's width; in the rare case their columns can't fit even wrapped,
//    the table is scaled down to the card's width instead of overflowing.
//
// [prepareEmailHtml] only rewrites the copy that is DISPLAYED — the stored
// email is untouched — and also works around two add-on limits: a
// `width: N%` inline style collapses a table to zero width, and a table
// nested inside another table's cell fails to lay out.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
// The grid the table add-on lays cells out with. Its render class is not
// re-exported by the package; it is only used to ask how wide the columns
// need to be (see _RenderTableFit).
// ignore: implementation_imports
import 'package:flutter_layout_grid/src/rendering/layout_grid.dart'
    show RenderLayoutGrid;
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../constant/constant.dart';

/// Placeholder tag a data table is turned into; built by [_ListTable].
const _listTableTag = 'crm-email-list-table';

/// Returns [html] ready for `Html(data: …)`. Bodies without a table come back
/// unchanged, so every other email renders exactly as before.
String prepareEmailHtml(String html) {
  if (!html.toLowerCase().contains('<table')) return html;

  final document = html_parser.parse(html);
  _dropPercentWidths(document);
  _applyCellAttributes(document);
  _flattenTablesThatHoldTables(document);
  _convertDataTables(document);
  return document.outerHtml;
}

/// Extensions to pass to every email-body `Html` widget.
List<HtmlExtension> emailHtmlExtensions() => [
      TagExtension(
        tagsToExtend: const {_listTableTag},
        builder: (context) =>
            _ListTable.fromAttribute(context.attributes['data-table']),
      ),
      TagWrapExtension(
        tagsToWrap: const {'table'},
        builder: (child) => _TableFrame(child: child),
      ),
      const TableHtmlExtension(),
    ];

// ---------------------------------------------------------------- markup

const _widthProperties = {'width', 'min-width', 'max-width'};

/// flutter_html sizes an element with an inline `width: N%` to zero width, so
/// a `<table style="width:100%">` (the usual email markup) collapsed to
/// nothing. Without the percentage the block simply fills the card, which is
/// what 100% meant. Images keep theirs; their sizing is handled separately.
void _dropPercentWidths(dom.Document document) {
  for (final element in document.querySelectorAll('[style]')) {
    if (element.localName == 'img') continue;
    final style = element.attributes['style']!;
    if (!style.contains('%')) continue;
    element.attributes['style'] = style
        .split(';')
        .map((declaration) => declaration.trim())
        .where((declaration) {
          if (declaration.isEmpty) return false;
          final colon = declaration.indexOf(':');
          if (colon < 0) return true;
          final property =
              declaration.substring(0, colon).trim().toLowerCase();
          final value = declaration.substring(colon + 1);
          return !(_widthProperties.contains(property) && value.contains('%'));
        })
        .join('; ');
  }
}

/// The add-on ignores the old table attributes emails still use (cellpadding,
/// border, bgcolor, align) and draws cells edge to edge, so neighbouring
/// columns ran together ("John TenantAve"). Turn them into the inline styles
/// it does honour, the way a browser reads them: padding from cellpadding
/// (a few px when none is given, like a browser's default spacing), a light
/// border when border is set, and bold header cells.
void _applyCellAttributes(dom.Document document) {
  for (final table in document.querySelectorAll('table')) {
    final cellPadding = int.tryParse(table.attributes['cellpadding'] ?? '');
    final bordered = (int.tryParse(table.attributes['border'] ?? '') ?? 0) > 0;
    for (final row in _ownRows(table)) {
      _addStyles(row, [
        if (row.attributes['bgcolor'] != null)
          'background-color: ${row.attributes['bgcolor']}',
      ], unless: 'background');
      for (final cell in row.children) {
        if (cell.localName != 'td' && cell.localName != 'th') continue;
        _addStyles(cell, ['padding: ${cellPadding ?? 4}px'], unless: 'padding');
        if (bordered) {
          _addStyles(cell, ['border: 1px solid #cfcfcf'], unless: 'border');
        }
        if (cell.localName == 'th') {
          _addStyles(cell, ['font-weight: bold'], unless: 'font-weight');
        }
        if (cell.attributes['bgcolor'] != null) {
          _addStyles(cell, ['background-color: ${cell.attributes['bgcolor']}'],
              unless: 'background');
        }
        if (cell.attributes['align'] != null) {
          _addStyles(cell, ['text-align: ${cell.attributes['align']}'],
              unless: 'text-align');
        }
      }
    }
  }
}

/// Appends [declarations] to [element]'s inline style unless it already
/// mentions [unless] (an explicit value in the email always wins).
void _addStyles(dom.Element element, List<String> declarations,
    {required String unless}) {
  if (declarations.isEmpty) return;
  final style = (element.attributes['style'] ?? '').trim();
  if (style.toLowerCase().contains(unless)) return;
  element.attributes['style'] = [
    if (style.isNotEmpty)
      style.endsWith(';') ? style.substring(0, style.length - 1) : style,
    ...declarations,
  ].join('; ');
}

/// A table inside another table's cell fails to lay out (the add-on cannot
/// measure it), so the inner table disappeared. Email layouts nest tables
/// mostly as wrappers; turning each wrapper into stacked blocks keeps every
/// piece of content and leaves only plain data tables for the add-on — the
/// same stacking a phone-width mail client does.
void _flattenTablesThatHoldTables(dom.Document document) {
  while (true) {
    dom.Element? wrapper;
    for (final table in document.querySelectorAll('table')) {
      if (table.querySelector('table') != null) {
        wrapper = table;
        break;
      }
    }
    if (wrapper == null) return;
    wrapper.replaceWith(_tableAsBlocks(wrapper));
  }
}

dom.Element _tableAsBlocks(dom.Element table) {
  final block = _blockLike(table);
  for (final child in table.children.toList()) {
    if (child.localName == 'caption') {
      block.append(_blockLike(child)..nodes.addAll(child.nodes.toList()));
    }
  }
  for (final row in _ownRows(table)) {
    final rowBlock = _blockLike(row);
    for (final cell in row.children.toList()) {
      if (cell.localName != 'td' && cell.localName != 'th') continue;
      final cellBlock = _blockLike(cell);
      cellBlock.nodes.addAll(cell.nodes.toList());
      rowBlock.append(cellBlock);
    }
    block.append(rowBlock);
  }
  return block;
}

/// Data tables — a header row over at least one row, 3+ columns — become a
/// [_ListTable] placeholder carrying their text. Emails often mark the header
/// row with plain cells (the Scheduled Payment Digest does), so the first row
/// is the header whatever its cell type. Narrower tables stay real tables.
void _convertDataTables(dom.Document document) {
  for (final table in document.querySelectorAll('table').toList()) {
    final ownRows = _ownRows(table).toList();
    if (ownRows.length < 2) continue;
    final columns = ownRows.fold<int>(
        0, (most, row) => math.max(most, row.children.where(_isCell).length));
    if (columns < 3) continue;
    final rows = ownRows.map(_cellTexts).toList();
    final body =
        rows.skip(1).where((row) => row.any((text) => text.isNotEmpty)).toList();
    final placeholder = dom.Element.tag(_listTableTag)
      ..attributes['data-table'] =
          jsonEncode({'headers': rows.first, 'rows': body});
    // A block of its own, like the table it replaces.
    table.replaceWith(dom.Element.tag('div')..append(placeholder));
  }
}

bool _isCell(dom.Element element) =>
    element.localName == 'td' || element.localName == 'th';

List<String> _cellTexts(dom.Element row) => [
      for (final cell in row.children)
        if (_isCell(cell)) _cellText(cell),
    ];

/// A cell's text the way a browser shows it: line breaks kept, other runs of
/// whitespace collapsed. Reads a copy, so the cell itself is left as it was.
String _cellText(dom.Element cell) {
  final copy = cell.clone(true);
  for (final br in copy.querySelectorAll('br').toList()) {
    br.replaceWith(dom.Text('\n'));
  }
  return copy.text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
}

/// Rows that belong to [table] itself, not to a table nested in its cells.
Iterable<dom.Element> _ownRows(dom.Element table) sync* {
  for (final child in table.children) {
    if (child.localName == 'tr') {
      yield child;
    } else if (child.localName == 'thead' ||
        child.localName == 'tbody' ||
        child.localName == 'tfoot') {
      yield* child.children.where((e) => e.localName == 'tr');
    }
  }
}

/// A `<div>` carrying [source]'s inline style and alignment, so colours,
/// padding and text alignment survive the conversion.
dom.Element _blockLike(dom.Element source) {
  final div = dom.Element.tag('div');
  final style = <String>[
    if ((source.attributes['style'] ?? '').trim().isNotEmpty)
      source.attributes['style']!.trim(),
    if (source.attributes['align'] != null)
      'text-align: ${source.attributes['align']}',
    if (source.attributes['bgcolor'] != null)
      'background-color: ${source.attributes['bgcolor']}',
  ];
  if (style.isNotEmpty) div.attributes['style'] = style.join('; ');
  return div;
}

// ------------------------------------------------------- list-table look

/// A data table drawn like the app's list tables (Tenants, Leases…): a
/// header bar with the first two column titles, then one card per row — the
/// first two values on top, every other column as a "Label : value" line.
class _ListTable extends StatelessWidget {
  const _ListTable({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  static const _barColor = Color(0xFFF4F8FF);
  static const _borderColor = Color(0xFFDBE0E5);

  static Widget fromAttribute(String? raw) {
    try {
      final data = jsonDecode(raw ?? '') as Map<String, dynamic>;
      return _ListTable(
        headers: (data['headers'] as List).map((e) => '$e').toList(),
        rows: (data['rows'] as List)
            .map((row) => (row as List).map((e) => '$e').toList())
            .toList(),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  String _header(int column) => column < headers.length ? headers[column] : '';

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: blueColor,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _barColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor),
            ),
            child: _pair(_header(0), _header(1), titleStyle),
          ),
          for (var index = 0; index < rows.length; index++)
            _rowCard(rows[index], index, titleStyle),
        ],
      ),
    );
  }

  Widget _rowCard(List<String> row, int index, TextStyle titleStyle) {
    final detailLabel = TextStyle(fontWeight: FontWeight.bold, color: blueColor);
    final detailValue = TextStyle(fontWeight: FontWeight.w700, color: grey);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: index.isOdd ? _barColor : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A row with a single cell (e.g. "No records found" spanning the
          // table) reads as one line across the card.
          if (row.length == 1)
            Text(row.first, style: titleStyle)
          else
            _pair(row[0], row[1], titleStyle),
          for (var column = 2; column < row.length; column++)
            if (row[column].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text.rich(
                  TextSpan(children: [
                    if (_header(column).isNotEmpty)
                      TextSpan(text: '${_header(column)} : ', style: detailLabel),
                    TextSpan(text: row[column], style: detailValue),
                  ]),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
        ],
      ),
    );
  }

  Widget _pair(String first, String second, TextStyle style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(first, style: style)),
        const SizedBox(width: 8),
        Expanded(child: Text(second, style: style)),
      ],
    );
  }
}

// ---------------------------------------------------------------- layout

/// Gives a (non-list) table the card's width to lay out in.
class _TableFrame extends StatelessWidget {
  const _TableFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.maxWidth.isFinite) return child;
      return _TableFit(cardWidth: constraints.maxWidth, child: child);
    });
  }
}

class _TableFit extends SingleChildRenderObjectWidget {
  const _TableFit({required this.cardWidth, required Widget child})
      : super(child: child);

  final double cardWidth;

  @override
  _RenderTableFit createRenderObject(BuildContext context) =>
      _RenderTableFit(cardWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderTableFit renderObject) {
    renderObject.cardWidth = cardWidth;
  }
}

/// Lays the table out at the card's width, like a browser: columns share the
/// width and their text wraps. Columns can't get narrower than their longest
/// word, though; when those minimums add up to more than the card, the table
/// is laid out at the width it needs and scaled down to the card's width, so
/// it always fits — never scrolling sideways, never painting past the edge.
class _RenderTableFit extends RenderProxyBox {
  _RenderTableFit(this._cardWidth);

  double _cardWidth;
  double _scale = 1;

  set cardWidth(double value) {
    if (value == _cardWidth) return;
    _cardWidth = value;
    markNeedsLayout();
  }

  Matrix4 get _transform => Matrix4.diagonal3Values(_scale, _scale, 1);

  @override
  void performLayout() {
    final child = this.child;
    _scale = 1;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(BoxConstraints(maxWidth: _cardWidth), parentUsesSize: true);

    final grid = _firstGrid(child);
    if (grid != null) {
      final needed = grid.getMinIntrinsicWidth(double.infinity);
      final missing = needed - grid.constraints.maxWidth;
      if (missing > 0.5) {
        final width = _cardWidth + missing;
        child.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
        _scale = _cardWidth / width;
      }
    }
    size = constraints.constrain(
        Size(child.size.width * _scale, child.size.height * _scale));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    if (_scale == 1) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (_scale == 1) return super.hitTestChildren(result, position: position);
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) =>
          child?.hitTest(result, position: position) ?? false,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_scale != 1) transform.multiply(_transform);
    super.applyPaintTransform(child, transform);
  }

  static RenderLayoutGrid? _firstGrid(RenderObject node) {
    RenderLayoutGrid? found;
    void visit(RenderObject child) {
      if (found != null) return;
      if (child is RenderLayoutGrid) {
        found = child;
        return;
      }
      child.visitChildren(visit);
    }

    node.visitChildren(visit);
    return found;
  }
}
