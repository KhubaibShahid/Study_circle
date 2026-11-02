import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers System / Light / Dark on this device.
class ThemeController {
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode.value = switch (p.getString('themeMode')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {}
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('themeMode', m.name);
    } catch (_) {}
  }
}
