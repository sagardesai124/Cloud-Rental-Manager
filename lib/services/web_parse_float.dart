/// Reads a number the way web's JavaScript `parseFloat` does: the number at
/// the start of the text counts and anything after it is ignored, so "1.2.3"
/// reads as 1.2 and "1." as 1. An exponent counts too, like parseFloat:
/// "1e5" is 100000 and "1.2e3" is 1200, while an "e" with no digits after it
/// is ignored ("1e" is 1). That matters for stored values, which Dart prints
/// with an exponent when they are very large or small ("1e+21", "1e-7").
/// Returns null where parseFloat gives NaN, that is when the text does not
/// start with a number ("." or ""). `$` and commas are dropped first, as web
/// drops its "$" prefix and thousands commas before parsing.
double? parseFloatLikeWeb(String text) {
  final cleaned = text.replaceAll(RegExp(r'[\$,]'), '').trim();
  final match =
      RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?').firstMatch(cleaned);
  return match == null ? null : double.tryParse(match.group(0)!);
}
