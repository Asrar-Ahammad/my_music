import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_image_filters.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/presentation/screens/playlists/retro_image_editor_screen.dart';
import 'package:my_music/presentation/widgets/retro_badge.dart';
import 'package:my_music/presentation/widgets/retro_button.dart';

void main() {
  group('Retro Image Filters & Presets Test', () {
    test('All presets are properly configured', () {
      expect(RetroFilterPreset.presets.length, equals(8));

      final labels = RetroFilterPreset.presets.map((p) => p.label).toList();
      expect(labels, contains('NORMAL'));
      expect(labels, contains('8-BIT GB'));
      expect(labels, contains('PIXEL NOIR'));
      expect(labels, contains('VINTAGE CRT'));
      expect(labels, contains('SYNTHWAVE'));
      expect(labels, contains('CASSETTE'));
      expect(labels, contains('CYBERPUNK'));
      expect(labels, contains('PIXELATE'));

      for (final preset in RetroFilterPreset.presets) {
        expect(preset.label.isNotEmpty, isTrue);
        expect(preset.description.isNotEmpty, isTrue);
        if (preset.matrix != null) {
          expect(preset.matrix!.length, equals(20)); // 4x5 color matrix
        }
      }
    });

    test('RetroScanlinesPainter shouldRepaint triggers correctly', () {
      const painter1 = RetroScanlinesPainter(lineSpacing: 3.0, opacity: 0.22);
      const painter2 = RetroScanlinesPainter(lineSpacing: 3.0, opacity: 0.22);
      const painter3 = RetroScanlinesPainter(lineSpacing: 4.0, opacity: 0.22);

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });

    test('RetroPixelGridPainter shouldRepaint triggers correctly', () {
      const painter1 = RetroPixelGridPainter(blockSize: 4.0, opacity: 0.18);
      const painter2 = RetroPixelGridPainter(blockSize: 4.0, opacity: 0.18);
      const painter3 = RetroPixelGridPainter(blockSize: 6.0, opacity: 0.18);

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });
  });

  group('RetroImageEditorScreen Widget Tests', () {
    late Directory tempDir;
    late File testImageFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('editor_test_');
      testImageFile = File('${tempDir.path}/test_image.png');
      // Create minimal 1x1 dummy PNG bytes
      await testImageFile.writeAsBytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Renders RetroImageEditorScreen with header, crop area, and filter carousel', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: RetroImageEditorScreen(
            imagePath: testImageFile.path,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & buttons
      expect(find.text('COVER EDITOR'), findsOneWidget);
      expect(find.widgetWithText(RetroButton, 'CANCEL'), findsOneWidget);
      expect(find.widgetWithText(RetroButton, 'APPLY'), findsOneWidget);

      // Verify crop area & instructions
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('DRAG TO PAN • PINCH TO ZOOM'), findsOneWidget);

      // Verify quick controls
      expect(find.widgetWithText(RetroButton, 'SCANLINES: OFF'), findsOneWidget);
      expect(find.widgetWithText(RetroButton, 'RESET'), findsOneWidget);

      // Verify filter card & presets
      expect(find.text('RETRO FILTERS'), findsOneWidget);
      expect(find.widgetWithText(RetroBadge, 'NORMAL'), findsOneWidget);
      expect(find.text('8-BIT GB'), findsOneWidget);
      expect(find.text('PIXEL NOIR'), findsOneWidget);
      expect(find.text('VINTAGE CRT'), findsOneWidget);
      expect(find.text('SYNTHWAVE'), findsOneWidget);
    });

    testWidgets('Toggling scanlines switches state label', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: RetroImageEditorScreen(
            imagePath: testImageFile.path,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scanlinesBtn = find.widgetWithText(RetroButton, 'SCANLINES: OFF');
      expect(scanlinesBtn, findsOneWidget);

      // Tap to toggle scanlines ON
      await tester.tap(scanlinesBtn);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(RetroButton, 'SCANLINES: ON'), findsOneWidget);

      // Tap again to toggle scanlines OFF
      await tester.tap(find.widgetWithText(RetroButton, 'SCANLINES: ON'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(RetroButton, 'SCANLINES: OFF'), findsOneWidget);
    });

    testWidgets('Selecting a filter updates active badge and description', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: RetroImageEditorScreen(
            imagePath: testImageFile.path,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: NORMAL
      expect(find.widgetWithText(RetroBadge, 'NORMAL'), findsOneWidget);
      expect(find.text('Original colors'), findsOneWidget);

      // Select '8-BIT GB'
      final gbFilterTile = find.text('8-BIT GB');
      expect(gbFilterTile, findsOneWidget);
      await tester.tap(gbFilterTile);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(RetroBadge, '8-BIT GB'), findsOneWidget);
      expect(find.text('Game Boy 4-color green matrix'), findsOneWidget);

      // Select 'SYNTHWAVE'
      final synthFilterTile = find.text('SYNTHWAVE');
      expect(synthFilterTile, findsOneWidget);
      await tester.tap(synthFilterTile);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(RetroBadge, 'SYNTHWAVE'), findsOneWidget);
      expect(find.text('Neon magenta & electric cyan'), findsOneWidget);

      // Tap RESET to return to NORMAL
      final resetBtn = find.widgetWithText(RetroButton, 'RESET');
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(RetroBadge, 'NORMAL'), findsOneWidget);
    });

    testWidgets('Tapping CANCEL pops navigator with null result', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? poppedResult = 'not_popped';

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => RetroImageEditorScreen(
                        imagePath: testImageFile.path,
                      ),
                    ),
                  );
                },
                child: const Text('OPEN EDITOR'),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open editor
      await tester.tap(find.text('OPEN EDITOR'));
      await tester.pumpAndSettle();

      expect(find.text('COVER EDITOR'), findsOneWidget);

      // Tap CANCEL
      await tester.tap(find.widgetWithText(RetroButton, 'CANCEL'));
      await tester.pumpAndSettle();

      expect(find.text('OPEN EDITOR'), findsOneWidget);
      expect(poppedResult, isNull);
    });
  });
}
