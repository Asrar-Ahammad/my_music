import 'package:flutter/material.dart';

/// Font option model representing a selectable retro or display font.
class AppFontOption {
  final String id;
  final String displayName;
  final String fontFamily;
  final String category;
  final String description;

  const AppFontOption({
    required this.id,
    required this.displayName,
    required this.fontFamily,
    required this.category,
    required this.description,
  });
}

/// Monospace and pixel typography for the 8-bit retro theme.
/// Bundled fonts are local assets in assets/fonts/
/// so they are always available offline in release builds without network access.
class RetroTypography {
  RetroTypography._();

  /// Available selectable fonts
  static const List<AppFontOption> availableFonts = [
    AppFontOption(
      id: 'PressStart2P',
      displayName: 'Press Start 2P',
      fontFamily: 'PressStart2P',
      category: '8-BIT ARCADE',
      description: 'Chunky arcade pixel classic with nostalgic weight',
    ),
    AppFontOption(
      id: 'Satoshi',
      displayName: 'Satoshi',
      fontFamily: 'Satoshi',
      category: 'MODERN SANS',
      description: 'Clean modernist geometric neo-grotesque typeface',
    ),
    AppFontOption(
      id: 'Gotham',
      displayName: 'Gotham',
      fontFamily: 'Gotham',
      category: 'SPOTIFY MODERN',
      description: 'Iconic Spotify geometric typeface with sleek, modern proportions',
    ),
  ];

  /// Currently active primary app font family
  static String currentFontFamily = 'PressStart2P';

  /// Currently active font option
  static AppFontOption get currentFontOption {
    return availableFonts.firstWhere(
      (f) => f.fontFamily == currentFontFamily || f.id == currentFontFamily,
      orElse: () => availableFonts.first,
    );
  }

  /// Sets the active font family
  static void setFontFamily(String familyOrId) {
    final option = availableFonts.firstWhere(
      (f) => f.fontFamily == familyOrId || f.id == familyOrId,
      orElse: () => availableFonts.first,
    );
    currentFontFamily = option.fontFamily;
  }

  /// Returns true if the given or active font family is a modern sans (Satoshi or Gotham)
  static bool isModernSans([String? family]) {
    final effective = (family ?? currentFontFamily).trim().toLowerCase();
    return effective == 'satoshi' || effective == 'gotham';
  }

  /// Backward compatible alias for modern sans check
  static bool isSatoshi([String? family]) => isModernSans(family);

  /// Secondary font family: follows modern sans when active, otherwise defaults to VT323
  static String get secondaryFontFamily => isModernSans() ? currentFontFamily : 'VT323';

  /// Increases font size for Satoshi to maintain strong optical readability
  /// and balance throughout the app compared to heavy pixel typography.
  static double effectiveSatoshiSize(double size) {
    if (size <= 7.0) {
      return size + 2.5;
    } else if (size <= 10.5) {
      return size + 3.0;
    } else if (size <= 14.5) {
      return size + 2.5;
    } else {
      return size + 3.0;
    }
  }

  /// Pixel header style using active app font
  static TextStyle pixelHeader({
    required Color color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.bold,
    double letterSpacing = 1.0,
    double height = 1.4,
    List<Shadow>? shadows,
    String? fontFamily,
  }) {
    final effectiveFont = fontFamily ?? currentFontFamily;
    final satoshi = isSatoshi(effectiveFont);
    final effectiveSize = satoshi ? effectiveSatoshiSize(fontSize) : fontSize;
    return TextStyle(
      fontFamily: effectiveFont,
      color: color,
      fontSize: effectiveSize,
      fontWeight: fontWeight,
      letterSpacing: satoshi ? (letterSpacing * 0.4).clamp(0.2, 0.6) : letterSpacing,
      height: height,
      shadows: shadows,
    );
  }

  /// Retro terminal / body style (secondary font: follows Satoshi when selected, else VT323)
  static TextStyle retroMono({
    required Color color,
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    double letterSpacing = 0.5,
    double height = 1.2,
    String? fontFamily,
  }) {
    final effectiveFont = fontFamily ?? secondaryFontFamily;
    final satoshi = isSatoshi(effectiveFont);
    final effectiveSize = satoshi ? effectiveSatoshiSize(fontSize) : fontSize;
    return TextStyle(
      fontFamily: effectiveFont,
      color: color,
      fontSize: effectiveSize,
      fontWeight: satoshi && fontWeight == FontWeight.normal ? FontWeight.w500 : fontWeight,
      letterSpacing: satoshi ? 0.2 : letterSpacing,
      height: satoshi ? 1.3 : height,
    );
  }

  /// Compact pixel badge / tag style using active app font
  static TextStyle pixelBadge({
    required Color color,
    double fontSize = 9,
    FontWeight fontWeight = FontWeight.bold,
    String? fontFamily,
  }) {
    final effectiveFont = fontFamily ?? currentFontFamily;
    final satoshi = isSatoshi(effectiveFont);
    final effectiveSize = satoshi ? effectiveSatoshiSize(fontSize) : fontSize;
    return TextStyle(
      fontFamily: effectiveFont,
      color: color,
      fontSize: effectiveSize,
      fontWeight: satoshi ? FontWeight.w600 : fontWeight,
      letterSpacing: satoshi ? 0.2 : 0.5,
    );
  }

  /// Checks whether a text contains non-Latin scripts (e.g. Indic, CJK, Arabic, Cyrillic)
  /// where standard pixel fonts lack glyphs and render too small in system fallback.
  static bool isNonLatin(String text) {
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) > 0x024F) {
        return true;
      }
    }
    return false;
  }

  /// Adaptive lyrics typography that preserves 8-bit retro pixel styling for Latin/English
  /// text while intelligently scaling and rendering non-Latin scripts (Hindi, Telugu, Tamil,
  /// Chinese, Japanese, Korean, Arabic, etc.) with proper optical sizing and legibility.
  static TextStyle lyricsStyle({
    required String text,
    required Color color,
    FontWeight fontWeight = FontWeight.normal,
    bool isTicker = false,
    double? fontSize,
    double height = 1.35,
    List<Shadow>? shadows,
    String? fontFamily,
  }) {
    final nonLatin = isNonLatin(text);
    if (nonLatin) {
      final size = fontSize ?? (isTicker ? 16.5 : 17.5);
      return TextStyle(
        color: color,
        fontSize: size,
        fontWeight: fontWeight == FontWeight.bold ? FontWeight.w700 : FontWeight.w600,
        height: height,
        letterSpacing: 0.2,
        shadows: shadows,
      );
    } else {
      final size = fontSize ?? (isTicker ? 12.5 : 13.5);
      return pixelHeader(
        color: color,
        fontSize: size,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: 0.8,
        shadows: shadows,
        fontFamily: fontFamily ?? currentFontFamily,
      );
    }
  }
}

