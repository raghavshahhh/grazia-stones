import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/core/services/storage_service.dart';

/// Holds the active [LuxuryPalette] for the entire app.
/// Default is gold (Grazia branding). Swap to marble / obsidian / etc. for white-label.
final themePaletteProvider =
    StateNotifierProvider<ThemePaletteNotifier, LuxuryPalette>((ref) {
  return ThemePaletteNotifier();
});

class ThemePaletteNotifier extends StateNotifier<LuxuryPalette> {
  final StorageService _storage = StorageService.instance;

  ThemePaletteNotifier() : super(GLuxuryPalettes.gold) {
    _loadPersistedTheme();
  }

  bool get isDarkMode => state is GoldDarkPalette || state is ObsidianPalette || state is MidnightPalette;

  /// Load theme from storage
  Future<void> _loadPersistedTheme() async {
    try {
      final isDark = _storage.getThemeMode();
      state = isDark ? GLuxuryPalettes.goldDark : GLuxuryPalettes.gold;
      debugPrint('✅ Theme restored: ${isDark ? "Dark" : "Light"}');
    } catch (e) {
      debugPrint('❌ Error loading theme: $e');
    }
  }

  /// Save theme to storage
  Future<void> _persistTheme(bool isDark) async {
    try {
      await _storage.saveThemeMode(isDark);
      debugPrint('✅ Theme saved: ${isDark ? "Dark" : "Light"}');
    } catch (e) {
      debugPrint('❌ Error saving theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    if (isDarkMode) {
      state = GLuxuryPalettes.gold; // Light Mode (Day default)
      await _persistTheme(false);
    } else {
      state = GLuxuryPalettes.goldDark; // Dark Mode (Night luxury)
      await _persistTheme(true);
    }
  }

  Future<void> setPalette(LuxuryPalette palette) async {
    state = palette;
    final isDark = palette is GoldDarkPalette || palette is ObsidianPalette || palette is MidnightPalette;
    await _persistTheme(isDark);
  }

  void setGold() => setPalette(GLuxuryPalettes.gold);
  void setMarble() => setPalette(GLuxuryPalettes.marble);
  void setObsidian() => setPalette(GLuxuryPalettes.obsidian);
  void setPearl() => setPalette(GLuxuryPalettes.pearl);
  void setRoseGold() => setPalette(GLuxuryPalettes.roseGold);
  void setMidnight() => setPalette(GLuxuryPalettes.midnight);
}
