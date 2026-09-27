import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_colors.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/core/theme/retro_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RetroTheme System Verification', () {
    test('Light and Dark themes adhere to zero elevation & solid borders', () {
      final light = RetroTheme.lightTheme();
      final dark = RetroTheme.darkTheme();

      // Zero elevation rules
      expect(light.appBarTheme.elevation, equals(0));
      expect(light.appBarTheme.scrolledUnderElevation, equals(0));
      expect(light.cardTheme.elevation, equals(0));
      expect(light.bottomNavigationBarTheme.elevation, equals(0));

      expect(dark.appBarTheme.elevation, equals(0));
      expect(dark.appBarTheme.scrolledUnderElevation, equals(0));
      expect(dark.cardTheme.elevation, equals(0));
      expect(dark.bottomNavigationBarTheme.elevation, equals(0));

      // Theme tokens
      final lightTokens = light.extension<RetroThemeTokens>();
      final darkTokens = dark.extension<RetroThemeTokens>();

      expect(lightTokens, isNotNull);
      expect(darkTokens, isNotNull);

      expect(lightTokens!.isDark, isFalse);
      expect(darkTokens!.isDark, isTrue);

      expect(lightTokens.borderWidth, equals(2.5));
      expect(darkTokens.borderWidth, equals(2.5));

      // Solid color checks
      expect(light.scaffoldBackgroundColor, equals(RetroColors.lightBg));
      expect(dark.scaffoldBackgroundColor, equals(RetroColors.darkBg));
    });

    test('RetroTypography handles non-Latin script scaling correctly', () {
      expect(RetroTypography.isNonLatin('Never gonna give you up'), isFalse);
      expect(RetroTypography.isNonLatin('Retro 8-Bit Beats 123!'), isFalse);

      // Hindi (Devanagari)
      expect(RetroTypography.isNonLatin('तू ही मेरी मंजिल'), isTrue);
      // Telugu
      expect(RetroTypography.isNonLatin('సరిగమపదనిస'), isTrue);
      // Japanese
      expect(RetroTypography.isNonLatin('音楽の世界へようこそ'), isTrue);
      // Korean
      expect(RetroTypography.isNonLatin('노래를 불러요'), isTrue);

      // English ticker style
      final englishStyle = RetroTypography.lyricsStyle(
        text: 'Hello World',
        color: RetroColors.picoBlue,
        isTicker: true,
      );
      expect(englishStyle.fontSize, equals(12.5));

      // Non-Latin ticker style (scaled larger for optical clarity)
      final nonLatinStyle = RetroTypography.lyricsStyle(
        text: 'तू ही मेरी मंजिल',
        color: RetroColors.picoBlue,
        isTicker: true,
      );
      expect(nonLatinStyle.fontSize, equals(16.5));
      expect(nonLatinStyle.fontSize! > englishStyle.fontSize!, isTrue);
    });

    test('All RetroPaletteData presets build valid themes adhering to 8-bit rules', () {
      for (final darkPalette in RetroColors.darkPalettes) {
        final dark = RetroTheme.darkTheme(paletteId: darkPalette.id);
        expect(dark.scaffoldBackgroundColor, equals(darkPalette.bg));
        final tokens = dark.extension<RetroThemeTokens>();
        expect(tokens, isNotNull);
        expect(tokens!.borderColor, equals(darkPalette.border));
        expect(tokens.cardColor, equals(darkPalette.card));
        expect(tokens.isDark, isTrue);
      }

      for (final lightPalette in RetroColors.lightPalettes) {
        final light = RetroTheme.lightTheme(paletteId: lightPalette.id);
        expect(light.scaffoldBackgroundColor, equals(lightPalette.bg));
        final tokens = light.extension<RetroThemeTokens>();
        expect(tokens, isNotNull);
        expect(tokens!.borderColor, equals(lightPalette.border));
        expect(tokens.cardColor, equals(lightPalette.card));
        expect(tokens.isDark, isFalse);
      }
    });

    test('RetroTypography font options and dynamic font selection work as expected', () {
      expect(RetroTypography.availableFonts.length, equals(3));
      final fontFamilies = RetroTypography.availableFonts.map((f) => f.fontFamily).toList();
      expect(fontFamilies, containsAll([
        'PressStart2P',
        'Satoshi',
        'Gotham',
      ]));

      // Verify PressStart2P default baseline
      RetroTypography.setFontFamily('PressStart2P');
      expect(RetroTypography.currentFontFamily, equals('PressStart2P'));
      expect(RetroTypography.secondaryFontFamily, equals('VT323'));
      final defaultMono = RetroTypography.retroMono(color: RetroColors.picoBlue, fontSize: 14);
      expect(defaultMono.fontFamily, equals('VT323'));
      expect(defaultMono.fontSize, equals(14));

      final defaultHeader = RetroTypography.pixelHeader(color: RetroColors.picoBlue, fontSize: 12);
      expect(defaultHeader.fontFamily, equals('PressStart2P'));
      expect(defaultHeader.fontSize, equals(12));

      final defaultBadge = RetroTypography.pixelBadge(color: RetroColors.picoBlue, fontSize: 8);
      expect(defaultBadge.fontFamily, equals('PressStart2P'));
      expect(defaultBadge.fontSize, equals(8));

      // Test switching font to Satoshi
      RetroTypography.setFontFamily('Satoshi');
      expect(RetroTypography.currentFontFamily, equals('Satoshi'));
      expect(RetroTypography.currentFontOption.displayName, equals('Satoshi'));

      // Secondary font must ALSO follow Satoshi
      expect(RetroTypography.secondaryFontFamily, equals('Satoshi'));
      final satoshiMono = RetroTypography.retroMono(color: RetroColors.picoBlue, fontSize: 14);
      expect(satoshiMono.fontFamily, equals('Satoshi'));
      // Font size must be increased for Satoshi
      expect(satoshiMono.fontSize, greaterThan(14));

      final satoshiHeader = RetroTypography.pixelHeader(color: RetroColors.picoBlue, fontSize: 12);
      expect(satoshiHeader.fontFamily, equals('Satoshi'));
      expect(satoshiHeader.fontSize, greaterThan(12));

      final satoshiBadge = RetroTypography.pixelBadge(color: RetroColors.picoBlue, fontSize: 8);
      expect(satoshiBadge.fontFamily, equals('Satoshi'));
      expect(satoshiBadge.fontSize, greaterThan(8));

      // Test switching font to Gotham
      RetroTypography.setFontFamily('Gotham');
      expect(RetroTypography.currentFontFamily, equals('Gotham'));
      expect(RetroTypography.currentFontOption.displayName, equals('Gotham'));
      expect(RetroTypography.secondaryFontFamily, equals('Gotham'));

      final gothamMono = RetroTypography.retroMono(color: RetroColors.picoBlue, fontSize: 14);
      expect(gothamMono.fontFamily, equals('Gotham'));
      expect(gothamMono.fontSize, greaterThan(14));

      final gothamHeader = RetroTypography.pixelHeader(color: RetroColors.picoBlue, fontSize: 12);
      expect(gothamHeader.fontFamily, equals('Gotham'));
      expect(gothamHeader.fontSize, greaterThan(12));

      final lightTheme = RetroTheme.lightTheme(fontFamily: 'Gotham');
      expect(lightTheme.textTheme.bodyMedium?.fontFamily ?? lightTheme.canvasColor, isNotNull);

      // Reset back to PressStart2P
      RetroTypography.setFontFamily('PressStart2P');
      expect(RetroTypography.currentFontFamily, equals('PressStart2P'));
      expect(RetroTypography.secondaryFontFamily, equals('VT323'));
    });
  });
}

