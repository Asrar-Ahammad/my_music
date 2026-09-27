import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'retro_colors.dart';
import 'retro_typography.dart';

/// ThemeExtension providing retro-specific tokens: solid chunky borders, zero-shadow flags,
/// and consistent accent colors across both Light and Dark modes.
class RetroThemeTokens extends ThemeExtension<RetroThemeTokens> {
  final Color borderColor;
  final Color cardColor;
  final Color accentGreen;
  final Color accentYellow;
  final Color accentPurple;
  final Color disabledColor;
  final double borderWidth;
  final bool isDark;

  const RetroThemeTokens({
    required this.borderColor,
    required this.cardColor,
    required this.accentGreen,
    required this.accentYellow,
    required this.accentPurple,
    required this.disabledColor,
    this.borderWidth = 2.5,
    required this.isDark,
  });

  Border get border => Border.all(color: borderColor, width: borderWidth);
  BorderSide get borderSide => BorderSide(color: borderColor, width: borderWidth);

  Color get borderSubtle => borderColor.withValues(alpha: 0.25);
  Color get surfaceContainer => cardColor;
  Color get accent => borderColor;
  Color get dividerColor => borderColor.withValues(alpha: 0.25);
  double get borderRadius => 0.0;
  double get borderRadiusSmall => 0.0;
  double get borderRadiusLarge => 0.0;

  @override
  RetroThemeTokens copyWith({
    Color? borderColor,
    Color? cardColor,
    Color? accentGreen,
    Color? accentYellow,
    Color? accentPurple,
    Color? disabledColor,
    double? borderWidth,
    bool? isDark,
  }) {
    return RetroThemeTokens(
      borderColor: borderColor ?? this.borderColor,
      cardColor: cardColor ?? this.cardColor,
      accentGreen: accentGreen ?? this.accentGreen,
      accentYellow: accentYellow ?? this.accentYellow,
      accentPurple: accentPurple ?? this.accentPurple,
      disabledColor: disabledColor ?? this.disabledColor,
      borderWidth: borderWidth ?? this.borderWidth,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  RetroThemeTokens lerp(ThemeExtension<RetroThemeTokens>? other, double t) {
    if (other is! RetroThemeTokens) return this;
    return RetroThemeTokens(
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentYellow: Color.lerp(accentYellow, other.accentYellow, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      disabledColor: Color.lerp(disabledColor, other.disabledColor, t)!,
      borderWidth: borderWidth,
      isDark: other.isDark,
    );
  }
}

extension RetroThemeContext on BuildContext {
  RetroThemeTokens get retro => Theme.of(this).extension<RetroThemeTokens>()!;
  bool get isNothingTheme => false;
  RetroThemeTokens get nothing => retro;
}

class NothingTypography {
  static TextStyle headline({required Color color, double fontSize = 20, FontWeight fontWeight = FontWeight.bold}) =>
      RetroTypography.pixelHeader(color: color, fontSize: fontSize, fontWeight: fontWeight);
  static TextStyle label({required Color color, double fontSize = 12, FontWeight fontWeight = FontWeight.normal}) =>
      RetroTypography.pixelBadge(color: color, fontSize: fontSize, fontWeight: fontWeight);
  static TextStyle body({required Color color, double fontSize = 14, FontWeight fontWeight = FontWeight.normal}) =>
      RetroTypography.retroMono(color: color, fontSize: fontSize, fontWeight: fontWeight);
  static TextStyle tag({required Color color, double fontSize = 10, FontWeight fontWeight = FontWeight.bold}) =>
      RetroTypography.pixelBadge(color: color, fontSize: fontSize, fontWeight: fontWeight);
  static TextStyle title({required Color color, double fontSize = 16, FontWeight fontWeight = FontWeight.bold}) =>
      RetroTypography.pixelHeader(color: color, fontSize: fontSize, fontWeight: fontWeight);
  static TextStyle mono({required Color color, double fontSize = 14, FontWeight fontWeight = FontWeight.normal}) =>
      RetroTypography.retroMono(color: color, fontSize: fontSize, fontWeight: fontWeight);
  static TextStyle caption({required Color color, double fontSize = 11}) =>
      RetroTypography.retroMono(color: color, fontSize: fontSize);
}

class RetroTheme {
  RetroTheme._();

  static const double standardBorderWidth = 2.5;

  /// Build Light ThemeData (zero shadows, zero gradients, solid borders)
  static ThemeData lightTheme({String? paletteId, String? fontFamily}) {
    final palette = RetroColors.getLightPalette(paletteId);
    final borderSide = BorderSide(
      color: palette.border,
      width: standardBorderWidth,
    );

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      error: RetroColors.picoRed,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.card,
      outline: palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily ?? RetroTypography.currentFontFamily,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.surface,
      cardColor: palette.card,
      dividerColor: palette.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: RetroTypography.pixelHeader(
          color: palette.textPrimary,
          fontSize: 14,
        ),
        shape: Border(bottom: borderSide),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: RetroTypography.pixelBadge(
          color: palette.primary,
          fontSize: 8,
        ),
        unselectedLabelStyle: RetroTypography.pixelBadge(
          color: palette.textSecondary,
          fontSize: 8,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
        textStyle: RetroTypography.pixelBadge(
          color: palette.textPrimary,
          fontSize: 9.5,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: palette.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: palette.border,
        dividerHeight: standardBorderWidth,
        labelColor: palette.primary,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: RetroTypography.pixelBadge(
          color: palette.primary,
          fontSize: 10,
        ),
        unselectedLabelStyle: RetroTypography.pixelBadge(
          color: palette.textSecondary,
          fontSize: 10,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: palette.primary,
        inactiveTrackColor: palette.card,
        thumbColor: palette.primary,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 7,
          elevation: 0,
          pressedElevation: 0,
        ),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primary;
          }
          return palette.card;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: palette.border, width: 2.0),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.card,
        contentTextStyle: RetroTypography.pixelBadge(
          color: Colors.white,
          fontSize: 9.5,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: borderSide,
          borderRadius: BorderRadius.zero,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [
        RetroThemeTokens(
          borderColor: palette.border,
          cardColor: palette.card,
          accentGreen: palette.green,
          accentYellow: palette.yellow,
          accentPurple: palette.purple,
          disabledColor: palette.disabled,
          borderWidth: standardBorderWidth,
          isDark: false,
        ),
      ],
    );
  }

  /// Build Dark ThemeData (zero shadows, zero gradients, solid borders)
  static ThemeData darkTheme({String? paletteId, String? fontFamily}) {
    final palette = RetroColors.getDarkPalette(paletteId);
    final borderSide = BorderSide(
      color: palette.border,
      width: standardBorderWidth,
    );

    final isPrimaryLight = palette.primary.computeLuminance() > 0.4;
    final isSecondaryLight = palette.secondary.computeLuminance() > 0.4;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: palette.primary,
      onPrimary: isPrimaryLight ? const Color(0xFF0F0E0E) : Colors.white,
      secondary: palette.secondary,
      onSecondary: isSecondaryLight ? const Color(0xFF0F0E0E) : Colors.white,
      error: RetroColors.picoRed,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.card,
      outline: palette.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily ?? RetroTypography.currentFontFamily,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: palette.bg,
      canvasColor: palette.surface,
      cardColor: palette.card,
      dividerColor: palette.border,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.bg,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: RetroTypography.pixelHeader(
          color: palette.textPrimary,
          fontSize: 14,
        ),
        shape: Border(bottom: borderSide),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.surface,
        selectedItemColor: palette.primary,
        unselectedItemColor: palette.textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: RetroTypography.pixelBadge(
          color: palette.primary,
          fontSize: 8,
        ),
        unselectedLabelStyle: RetroTypography.pixelBadge(
          color: palette.textSecondary,
          fontSize: 8,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: borderSide,
        ),
        textStyle: RetroTypography.pixelBadge(
          color: palette.textPrimary,
          fontSize: 9.5,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: palette.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: palette.border,
        dividerHeight: standardBorderWidth,
        labelColor: palette.primary,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: RetroTypography.pixelBadge(
          color: palette.primary,
          fontSize: 10,
        ),
        unselectedLabelStyle: RetroTypography.pixelBadge(
          color: palette.textSecondary,
          fontSize: 10,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: palette.primary,
        inactiveTrackColor: palette.card,
        thumbColor: palette.primary,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 7,
          elevation: 0,
          pressedElevation: 0,
        ),
        overlayShape: SliderComponentShape.noOverlay,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return palette.primary;
          }
          return palette.card;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: palette.border, width: 2.0),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.card,
        contentTextStyle: RetroTypography.pixelBadge(
          color: Colors.white,
          fontSize: 9.5,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          side: borderSide,
          borderRadius: BorderRadius.zero,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [
        RetroThemeTokens(
          borderColor: palette.border,
          cardColor: palette.card,
          accentGreen: palette.green,
          accentYellow: palette.yellow,
          accentPurple: palette.purple,
          disabledColor: palette.disabled,
          borderWidth: standardBorderWidth,
          isDark: true,
        ),
      ],
    );
  }
}
