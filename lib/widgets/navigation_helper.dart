import 'package:flutter/material.dart';

class NavigationHelper {
  /// Checks if the current route matches the target route
  static bool isCurrentRoute(BuildContext context, String targetRoute) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return currentRoute == targetRoute;
  }

  /// Gets the current route name
  static String? getCurrentRouteName(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  /// Checks if the current widget type matches the target widget type
  static bool isCurrentWidget(BuildContext context, Widget targetWidget) {
    final currentWidget = ModalRoute.of(context)?.settings.arguments;
    return currentWidget.runtimeType == targetWidget.runtimeType;
  }

  /// Simple navigation that just closes drawer if on same screen
  static Future<void> navigateWithValidation(
    BuildContext context,
    Widget targetWidget,
    String routeName,
  ) async {
    // Same screen? Compare route NAMES. This used to compare
    // settings.arguments against the target widget, which meant every pushed
    // screen stayed referenced from its own route settings for no other reason.
    if (isCurrentRoute(context, routeName)) {
      // Close drawer if open and return
      if (Scaffold.of(context).isDrawerOpen) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Drawer destinations REPLACE the stack instead of growing it. A plain
    // push left one live copy of every screen the user had ever opened — so
    // back walked through all of them (5 drawer taps = 5 backs) and each copy
    // held its own fetched lists. Keeping only the first route means back
    // always returns to the dashboard, the way tab-style navigation behaves.
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => targetWidget,
        settings: RouteSettings(name: routeName),
      ),
      (route) => route.isFirst,
    );
  }

  /// Navigate with validation for routes that use WidgetBuilder
  static Future<void> navigateWithValidationBuilder(
    BuildContext context,
    WidgetBuilder builder,
    String routeName,
  ) async {
    // Check if we're already on the same screen by route name
    if (isCurrentRoute(context, routeName)) {
      // Close drawer if open and return
      if (Scaffold.of(context).isDrawerOpen) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Drawer destinations REPLACE the stack instead of growing it — see the
    // note in [navigateWithValidation]. Safe because the dashboard is the
    // first route: splash pushReplacement's to login, login pushReplacement's
    // to Dashboard, so nothing below it can be reached.
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: builder,
        settings: RouteSettings(name: routeName),
      ),
      (route) => route.isFirst,
    );
  }
}
