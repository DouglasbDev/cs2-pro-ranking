import 'dart:async';

import 'package:flutter/widgets.dart';

/// Debounces callbacks from any [State]: call [onDebounce] with the work to
/// run — each call cancels the previous pending one and reschedules, so
/// only the last call within [debounceDuration] actually executes. Change
/// the wait window at any time with [setDebounceDuration].
mixin DebounceMixin<T extends StatefulWidget> on State<T> {
  Timer? _debounceTimer;
  Duration _debounceDuration = const Duration(milliseconds: 300);

  void setDebounceDuration(Duration duration) {
    _debounceDuration = duration;
  }

  void onDebounce(VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, callback);
  }

  void cancelDebounce() {
    _debounceTimer?.cancel();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
