import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// App theme mode, persisted across launches.
///
/// The design ships a full dark token set and the prototype's Settings has a
/// dark-mode switch, so brightness is a user choice rather than purely
/// following the OS. Defaults to [ThemeMode.system] until the user picks.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _restore();
    return ThemeMode.system;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kThemeModeKey);
    if (saved == null) return;
    final restored = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (restored != state) state = restored;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModeKey, mode.name);
  }

  /// Convenience for the Settings switch, which is a plain on/off.
  Future<void> setDark(bool dark) =>
      set(dark ? ThemeMode.dark : ThemeMode.light);
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
