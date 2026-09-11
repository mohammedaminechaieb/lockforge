import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_pack.dart';

/// Every theme the user has saved, persisted locally via SharedPreferences
/// as a JSON array under one key. This is what makes closing the app (or
/// it getting killed in the background, which Android does constantly)
/// non-destructive — previously ThemePack only lived in a StatefulWidget
/// field, so it vanished the moment EditorScreen was disposed. That's a
/// launch-blocking bug for anything meant to be actually used, let alone
/// sold.
class ThemeStorageService {
  static const _themesKey = 'lockforge_saved_themes';
  static const _lastOpenedKey = 'lockforge_last_opened_theme_id';

  Future<List<ThemePack>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => ThemePack.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveAll(List<ThemePack> themes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(themes.map((t) => t.toJson()).toList());
    await prefs.setString(_themesKey, raw);
  }

  /// Upserts a single theme into the saved list (matched by id) and
  /// persists the whole list — called on every meaningful edit in the
  /// editor so work is never lost, not just on an explicit "Save" tap.
  Future<void> upsert(ThemePack theme) async {
    final all = await loadAll();
    final index = all.indexWhere((t) => t.id == theme.id);
    if (index >= 0) {
      all[index] = theme;
    } else {
      all.add(theme);
    }
    await saveAll(all);
  }

  Future<void> delete(String themeId) async {
    final all = await loadAll();
    all.removeWhere((t) => t.id == themeId);
    await saveAll(all);
  }

  Future<void> setLastOpened(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey, themeId);
  }

  Future<String?> getLastOpenedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenedKey);
  }
}
