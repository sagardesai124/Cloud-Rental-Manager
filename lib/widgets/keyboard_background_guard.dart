import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Closes the keyboard when the app leaves the screen on Android.
///
/// When the user goes Home (or to another app) with a field focused, Android
/// hides the keyboard itself, but the app can come back still keeping the
/// keyboard's space reserved: the page stays squeezed above a blank white
/// area and its text is cut off. Closing the keyboard as the app is hidden
/// means it comes back at full height; the user taps the field to type again.
///
/// Only a fully hidden app counts — a notification shade, permission dialog
/// or other brief interruption leaves the keyboard alone. iOS restores the
/// keyboard correctly on its own, so it is not touched.
class KeyboardBackgroundGuard extends StatefulWidget {
  const KeyboardBackgroundGuard({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardBackgroundGuard> createState() =>
      _KeyboardBackgroundGuardState();
}

class _KeyboardBackgroundGuardState extends State<KeyboardBackgroundGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
