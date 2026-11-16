import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:super_tooltip/super_tooltip.dart';

import '../provider/dateProvider.dart';

/// Template Name `${date}` helper, the same as web (AddTemplate.jsx, the
/// template Name field — Admin and Staff use the same web page):
///  * an info icon next to "Name *" whose tip reads
///    "You can use the following dynamic variable: ${date} - Current Date
///    (<company date format>)";
///  * a suggestion under the Name box while typing `$`, `${` or `${d…`:
///    "${date} - Current Date"; picking it completes `${date}`.
/// When a letter is made, web fills `${date}` in the name with today's date.

const String templateDateVariable = r'${date}';
const String templateDateSuggestionLabel = r'${date} - Current Date';

final RegExp _partialDate = RegExp(r'\$\{[dD][aA]?[tT]?[eE]?$');
final RegExp _completeDate = RegExp(r'\$\{date\}');

/// Web's rule for showing the suggestion. [previous] is the text before this
/// edit: while deleting it never shows, and once the name already has
/// `${date}` it doesn't show again.
bool showTemplateDateSuggestion(String value, String previous) {
  if (value.length < previous.length) return false;
  if (_completeDate.hasMatch(value)) return false;
  return value.endsWith(r'$') ||
      value.endsWith(r'${') ||
      _partialDate.hasMatch(value);
}

/// The name after picking the suggestion, exactly as web builds it.
String completeTemplateDate(String value) {
  if (_partialDate.hasMatch(value)) {
    return value.substring(0, value.lastIndexOf(r'${')) + templateDateVariable;
  }
  if (value.endsWith(r'${')) {
    return value.substring(0, value.length - 2) + templateDateVariable;
  }
  if (value.endsWith(r'$')) {
    return value.substring(0, value.length - 1) + templateDateVariable;
  }
  return value + templateDateVariable;
}

/// The info tip text, web's words, with the company date format shown the
/// way web shows it (e.g. MM/DD/YYYY).
String templateNameDateTip(String dateFormat) =>
    'You can use the following dynamic variable:\n'
    '• $templateDateVariable - Current Date (${dateFormat.toUpperCase()})';

/// Info icon for the template Name label. Same tooltip look as the Body
/// tips on the template screen.
class TemplateNameDateTip extends StatefulWidget {
  const TemplateNameDateTip({super.key, required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  State<TemplateNameDateTip> createState() => _TemplateNameDateTipState();
}

class _TemplateNameDateTipState extends State<TemplateNameDateTip> {
  final SuperTooltipController _tip = SuperTooltipController();

  @override
  void dispose() {
    _tip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final format = Provider.of<DateProvider>(context).dateFormat;
    return SuperTooltip(
      controller: _tip,
      popupDirection: TooltipDirection.down,
      backgroundColor: const Color(0xff2f2d2f),
      arrowTipDistance: 20.0,
      touchThroughAreaShape: ClipAreaShape.rectangle,
      touchThroughAreaCornerRadius: 30,
      barrierColor: const Color.fromARGB(26, 47, 45, 47),
      content: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Text(
          templateNameDateTip(format),
          softWrap: true,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      child: Icon(Icons.error, color: widget.color, size: widget.size),
    );
  }
}

/// Wraps the template Name box: shows web's `${date}` suggestion just below
/// it while the typed text calls for it, and completes it on tap.
class TemplateDateTypeAhead extends StatefulWidget {
  const TemplateDateTypeAhead({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;

  @override
  State<TemplateDateTypeAhead> createState() => _TemplateDateTypeAheadState();
}

class _TemplateDateTypeAheadState extends State<TemplateDateTypeAhead> {
  final OverlayPortalController _suggestion = OverlayPortalController();
  final LayerLink _link = LayerLink();
  late String _previous;

  @override
  void initState() {
    super.initState();
    _previous = widget.controller.text;
    widget.controller.addListener(_onText);
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant TemplateDateTypeAhead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _previous = widget.controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onText() {
    final text = widget.controller.text;
    if (text == _previous) return; // only the cursor moved
    final show = widget.focusNode.hasFocus &&
        showTemplateDateSuggestion(text, _previous);
    _previous = text;
    if (show) {
      _suggestion.show();
    } else {
      _suggestion.hide();
    }
  }

  void _onFocus() {
    if (!widget.focusNode.hasFocus) _suggestion.hide();
  }

  void _pick() {
    final next = completeTemplateDate(widget.controller.text);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _suggestion.hide();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _suggestion,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 5),
        child: Align(
          alignment: Alignment.topLeft,
          // Part of the text field's tap area, so tapping the suggestion
          // doesn't count as tapping outside the Name box.
          child: TextFieldTapRegion(
            child: Material(
              elevation: 4,
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _pick,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    templateDateSuggestionLabel,
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(link: _link, child: widget.child),
    );
  }
}
