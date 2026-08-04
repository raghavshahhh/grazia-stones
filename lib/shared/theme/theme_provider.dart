import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/shared/theme/colors.dart';

/// Holds the active [LuxuryPalette] for the entire app.
/// Default is gold (Grazia branding). Swap to marble / obsidian / etc. for white-label.
final themePaletteProvider =
    StateNotifierProvider<ThemePaletteNotifier, LuxuryPalette>((ref) {
  return ThemePaletteNotifier();
});

class ThemePaletteNotifier extends StateNotifier<LuxuryPalette> {
  ThemePaletteNotifier() : super(GLuxuryPalettes.gold);

  bool get isDarkMode => state is GoldPalette || state is ObsidianPalette || state is MidnightPalette;

  void toggleTheme() {
    if (isDarkMode) {
      state = GLuxuryPalettes.pearl; // Light Mode (Day)
    } else {
      state = GLuxuryPalettes.gold; // Dark Mode (Night)
    }
  }

  void setPalette(LuxuryPalette palette) => state = palette;

  void setGold() => state = GLuxuryPalettes.gold;
  void setMarble() => state = GLuxuryPalettes.marble;
  void setObsidian() => state = GLuxuryPalettes.obsidian;
  void setPearl() => state = GLuxuryPalettes.pearl;
  void setRoseGold() => state = GLuxuryPalettes.roseGold;
  void setMidnight() => state = GLuxuryPalettes.midnight;
}
