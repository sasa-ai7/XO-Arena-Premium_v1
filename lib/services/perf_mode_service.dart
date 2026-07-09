import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight, standalone **Performance Mode** flag.
///
/// Kept deliberately separate from `LocalStore` (the wallet/profile store) so
/// that critical system is untouched. When enabled, the UI drops non-essential
/// visual work — the animated logo, backdrop blur passes, and entrance
/// animations — for smoother frames on low-end devices. Default is OFF, so
/// existing behavior is unchanged unless the user opts in from Settings.
///
/// Usage: wrap the exact subtree that should change in a
/// `ValueListenableBuilder(valueListenable: PerfMode.enabled, ...)`, or read
/// `PerfMode.enabled.value` at build time for one-shot decisions.
class PerfMode {
  PerfMode._();

  static const String prefsKey = 'performanceModeEnabled';

  /// Reactive flag. Default false (full visuals).
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  static bool _loaded = false;

  /// Loads the persisted value once. Safe to call repeatedly (no-op after the
  /// first successful load). Never throws — falls back to the default on error.
  static Future<void> init() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(prefsKey) ?? false;
      _loaded = true;
    } catch (_) {
      // Keep the default (false) if prefs are unavailable.
    }
  }

  /// Persists and broadcasts a new value.
  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, value);
    } catch (_) {
      // Value is still live in-memory for this session even if the write fails.
    }
  }
}
