import 'package:flutter/material.dart';

class RetroPaletteData {
  final String id;
  final String name;
  final bool isDark;
  final Color bg;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;
  final Color secondary;
  final Color green;
  final Color yellow;
  final Color purple;
  final Color disabled;
  final List<Color>? customSwatches;

  const RetroPaletteData({
    required this.id,
    required this.name,
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
    required this.secondary,
    this.green = const Color(0xFF56C483),
    this.yellow = const Color(0xFFEEB039),
    this.purple = const Color(0xFFA976CB),
    required this.disabled,
    this.customSwatches,
  });

  /// 4 representative colors for UI swatch preview: background, surface/card, border/secondary, accent/primary
  List<Color> get swatchColors => customSwatches ?? [bg, card, border, primary];
}

/// Curated PICO-8 / Retro Arcade solid pastel color palette.
/// Strictly NO gradients, NO shadows.
class RetroColors {
  RetroColors._();

  // === LIGHT THEME (Warm Vintage Handheld / Off-white) ===
  static const Color lightBg = Color(0xFFF5F1E8);
  static const Color lightSurface = Color(0xFFFFFDF8);
  static const Color lightCard = Color(0xFFEBE4D5);
  static const Color lightBorder = Color(0xFF2C2824); // Solid 2.5px chunky ink
  static const Color lightTextPrimary = Color(0xFF1E1A17);
  static const Color lightTextSecondary = Color(0xFF6B6357);
  static const Color lightPrimary = Color(0xFFE05367); // Retro Pink-Red
  static const Color lightSecondary = Color(0xFF587CD4); // Retro Blue
  static const Color lightGreen = Color(0xFF4EB676); // 1-UP Green
  static const Color lightYellow = Color(0xFFE5A122); // Coin Gold
  static const Color lightPurple = Color(0xFF9E65C4);
  static const Color lightDisabled = Color(0xFFD3CABE);

  // === DARK THEME (Default: Warm Espresso) ===
  static const Color darkBg = Color(0xFF1E1A17); // Warm espresso dark base
  static const Color darkSurface = Color(0xFF28241F); // Dark espresso surface
  static const Color darkCard = Color(0xFF353029); // Warm dark card
  static const Color darkBorder = Color(0xFF5C5246); // Espresso solid 2.5px border
  static const Color darkTextPrimary = Color(0xFFF5F1E8); // Warm off-white text
  static const Color darkTextSecondary = Color(0xFFB5A99B); // Muted warm off-white
  static const Color darkPrimary = Color(0xFFE56B7D); // Retro rose primary
  static const Color darkSecondary = Color(0xFF6E8FE0); // Retro blue secondary
  static const Color darkGreen = Color(0xFF56C483);
  static const Color darkYellow = Color(0xFFEEB039);
  static const Color darkPurple = Color(0xFFA976CB);
  static const Color darkDisabled = Color(0xFF453D34);

  // === PALETTE PRESETS ===

  // Dark 1: Warm Espresso (Off-white dark shade)
  static const RetroPaletteData warmEspressoPalette = RetroPaletteData(
    id: 'warm_espresso',
    name: 'WARM ESPRESSO',
    isDark: true,
    bg: Color(0xFF1E1A17),
    surface: Color(0xFF28241F),
    card: Color(0xFF353029),
    border: Color(0xFF5C5246),
    textPrimary: Color(0xFFF5F1E8),
    textSecondary: Color(0xFFB5A99B),
    primary: Color(0xFFE56B7D),
    secondary: Color(0xFF6E8FE0),
    disabled: Color(0xFF453D34),
  );

  // Dark 2: Cyber Slate (Original retro slate)
  static const RetroPaletteData cyberSlatePalette = RetroPaletteData(
    id: 'cyber_slate',
    name: 'CYBER SLATE',
    isDark: true,
    bg: Color(0xFF14161E),
    surface: Color(0xFF20232C),
    card: Color(0xFF2C303E),
    border: Color(0xFF4F576D),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8F98B0),
    primary: Color(0xFFE05367),
    secondary: Color(0xFF00E5FF),
    disabled: Color(0xFF303545),
  );

  // Dark 3: Obsidian Olive (Pitch black, oxblood burgundy, olive moss, crisp silver)
  static const RetroPaletteData obsidianOlivePalette = RetroPaletteData(
    id: 'obsidian_olive',
    name: 'OBSIDIAN OLIVE',
    isDark: true,
    bg: Color(0xFF0F0E0E),
    surface: Color(0xFF1B1717),
    card: Color(0xFF281414),
    border: Color(0xFF541212),
    textPrimary: Color(0xFFEEEEEE),
    textSecondary: Color(0xFFA69B9B),
    primary: Color(0xFF8B9A46),
    secondary: Color(0xFF541212),
    green: Color(0xFF8B9A46),
    yellow: Color(0xFFD4B859),
    purple: Color(0xFF8F3B4E),
    disabled: Color(0xFF381F1F),
    customSwatches: [
      Color(0xFF0F0E0E),
      Color(0xFF541212),
      Color(0xFF8B9A46),
      Color(0xFFEEEEEE),
    ],
  );

  // Dark 4: Jet Black (True 100% OLED pitch black, high-contrast monochrome silver & stark white)
  static const RetroPaletteData jetBlackPalette = RetroPaletteData(
    id: 'jet_black',
    name: 'JET BLACK',
    isDark: true,
    bg: Color(0xFF000000),
    surface: Color(0xFF101010),
    card: Color(0xFF181818),
    border: Color(0xFF5A5A5A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8B8B8),
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFA6A6A6),
    green: Color(0xFF00E676),
    yellow: Color(0xFFFFD600),
    purple: Color(0xFFD500F9),
    disabled: Color(0xFF383838),
  );

  // Light 1: Vintage Handheld (Classic warm off-white, chunky ink, retro pink & blue)
  static const RetroPaletteData vintageHandheldPalette = RetroPaletteData(
    id: 'vintage_handheld',
    name: 'VINTAGE HANDHELD',
    isDark: false,
    bg: Color(0xFFF5F1E8),
    surface: Color(0xFFFFFDF8),
    card: Color(0xFFEBE4D5),
    border: Color(0xFF2C2824),
    textPrimary: Color(0xFF1E1A17),
    textSecondary: Color(0xFF6B6357),
    primary: Color(0xFFE05367),
    secondary: Color(0xFF587CD4),
    disabled: Color(0xFFD3CABE),
  );

  // Light 2: Desert Sage (Warm cream, desert beige, sage green, camel tan)
  static const RetroPaletteData desertSagePalette = RetroPaletteData(
    id: 'desert_sage',
    name: 'DESERT SAGE',
    isDark: false,
    bg: Color(0xFFFEFAE0),
    surface: Color(0xFFFFFDF5),
    card: Color(0xFFFAEDCD),
    border: Color(0xFF382E26),
    textPrimary: Color(0xFF28211A),
    textSecondary: Color(0xFF706354),
    primary: Color(0xFFD4A373),
    secondary: Color(0xFFCCD5AE),
    green: Color(0xFFCCD5AE),
    yellow: Color(0xFFD4A373),
    purple: Color(0xFF9E7C65),
    disabled: Color(0xFFE9EDC9),
    customSwatches: [
      Color(0xFFFEFAE0),
      Color(0xFFFAEDCD),
      Color(0xFFCCD5AE),
      Color(0xFFD4A373),
    ],
  );

  // Light 3: Olive Grove (Parchment, tea green, moss olivine, warm umber, dark chestnut)
  static const RetroPaletteData oliveGrovePalette = RetroPaletteData(
    id: 'olive_grove',
    name: 'OLIVE GROVE',
    isDark: false,
    bg: Color(0xFFF0EAD2),
    surface: Color(0xFFFAF7EE),
    card: Color(0xFFDDE5B6),
    border: Color(0xFF6C584C),
    textPrimary: Color(0xFF2C241E),
    textSecondary: Color(0xFF6C584C),
    primary: Color(0xFFA98467),
    secondary: Color(0xFFADC178),
    green: Color(0xFFADC178),
    yellow: Color(0xFFA98467),
    purple: Color(0xFF8C6D58),
    disabled: Color(0xFFD4DCAD),
    customSwatches: [
      Color(0xFFF0EAD2),
      Color(0xFFDDE5B6),
      Color(0xFFADC178),
      Color(0xFFA98467),
    ],
  );

  // Light 4: Pastel Lavender (Alabaster cream, powder aqua, pastel lilac, periwinkle)
  static const RetroPaletteData pastelLavenderPalette = RetroPaletteData(
    id: 'pastel_lavender',
    name: 'PASTEL LAVENDER',
    isDark: false,
    bg: Color(0xFFF2EAE0),
    surface: Color(0xFFFAF5EE),
    card: Color(0xFFB4D3D9),
    border: Color(0xFF352B3C),
    textPrimary: Color(0xFF261D2D),
    textSecondary: Color(0xFF6B5C75),
    primary: Color(0xFF9B8EC7),
    secondary: Color(0xFFBDA6CE),
    green: Color(0xFF7FA899),
    yellow: Color(0xFFD4A373),
    purple: Color(0xFF9B8EC7),
    disabled: Color(0xFFDCD2C5),
    customSwatches: [
      Color(0xFFF2EAE0),
      Color(0xFFB4D3D9),
      Color(0xFFBDA6CE),
      Color(0xFF9B8EC7),
    ],
  );

  static const List<RetroPaletteData> darkPalettes = [
    warmEspressoPalette,
    cyberSlatePalette,
    obsidianOlivePalette,
    jetBlackPalette,
  ];

  static const List<RetroPaletteData> lightPalettes = [
    vintageHandheldPalette,
    desertSagePalette,
    oliveGrovePalette,
    pastelLavenderPalette,
  ];

  static RetroPaletteData getDarkPalette(String? id) {
    return darkPalettes.firstWhere(
      (p) => p.id == id,
      orElse: () => warmEspressoPalette,
    );
  }

  static RetroPaletteData getLightPalette(String? id) {
    return lightPalettes.firstWhere(
      (p) => p.id == id,
      orElse: () => vintageHandheldPalette,
    );
  }

  // === UNIVERSAL ACCENT PALETTE (PICO-8 inspired) ===
  static const Color picoBlack = Color(0xFF000000);
  static const Color picoDarkBlue = Color(0xFF1D2B53);
  static const Color picoPurple = Color(0xFF7E2553);
  static const Color picoDarkGreen = Color(0xFF008751);
  static const Color picoBrown = Color(0xFFAB5236);
  static const Color picoDarkGray = Color(0xFF5F574F);
  static const Color picoLightGray = Color(0xFFC2C3C7);
  static const Color picoWhite = Color(0xFFFFF1E8);
  static const Color picoRed = Color(0xFFFF004D);
  static const Color picoOrange = Color(0xFFFFA300);
  static const Color picoYellow = Color(0xFFFFEC27);
  static const Color picoGreen = Color(0xFF00E436);
  static const Color picoBlue = Color(0xFF29ADFF);
  static const Color picoIndigo = Color(0xFF83769C);
  static const Color picoPink = Color(0xFFFF77A8);
  static const Color picoPeach = Color(0xFFFFCCAA);

  /// Returns a distinctive, vibrant retro arcade accent color based deterministically on the song
  static Color getSongAccentColor(String? songId, String? title, {bool isDark = true}) {
    final seed = '${songId ?? ""}_${title ?? ""}'.hashCode.abs();
    final accents = isDark
        ? const [
            Color(0xFF00E5FF), // Cyber Cyan
            Color(0xFFFFEC27), // PICO Yellow
            Color(0xFFFF004D), // PICO Red
            Color(0xFF00E436), // PICO Green
            Color(0xFFFF77A8), // PICO Pink
            Color(0xFFFFA300), // PICO Orange
            Color(0xFF29ADFF), // PICO Blue
            Color(0xFFE040FB), // Neon Magenta
          ]
        : const [
            Color(0xFF008751), // Dark Green
            Color(0xFFE05367), // Retro Pink-Red
            Color(0xFF587CD4), // Retro Blue
            Color(0xFFE5A122), // Coin Gold
            Color(0xFF9E65C4), // Retro Purple
            Color(0xFF007A87), // Deep Teal
            Color(0xFFC2410C), // Deep Amber
          ];
    return accents[seed % accents.length];
  }
}
