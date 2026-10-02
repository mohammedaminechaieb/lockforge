import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_pack.dart';

/// Every theme the user has saved, persisted locally via SharedPreferences
/// as a JSON array under one key, so closing the app (or Android killing it
/// in the background) never loses work.
class ThemeStorageService {
  static const _themesKey = 'lockforge_saved_themes';
  static const _lastOpenedKey = 'lockforge_last_opened_theme_id';
  static const _activeKey = 'lockforge_active_lock_theme_id';

  Future<List<ThemePack>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themesKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final themes = <ThemePack>[];
    for (final e in list) {
      // One corrupt entry shouldn't make every other saved theme vanish.
      try {
        themes.add(ThemePack.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {}
    }
    return themes;
  }

  Future<void> saveAll(List<ThemePack> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themesKey, jsonEncode(themes.map((t) => t.toJson()).toList()));
  }

  /// Upserts a single theme (matched by id) and persists the whole list —
  /// called after edits so work is never lost.
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
    if (await getActiveId() == themeId) await setActiveId(null);
  }

  Future<void> setLastOpened(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastOpenedKey, themeId);
  }

  Future<String?> getLastOpenedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastOpenedKey);
  }

  /// The theme currently shown on the real lock screen, if any.
  Future<String?> getActiveId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> setActiveId(String? themeId) async {
    final prefs = await SharedPreferences.getInstance();
    if (themeId == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, themeId);
    }
  }
}
