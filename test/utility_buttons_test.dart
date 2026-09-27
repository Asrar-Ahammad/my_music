import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/providers/theme_provider.dart';
import 'package:my_music/presentation/screens/now_playing/now_playing_screen.dart';
import 'package:my_music/presentation/widgets/retro_button.dart';
import 'package:my_music/presentation/widgets/retro_clock_timer_dialog.dart';

import 'widget_retro_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NowPlayingScreen utility buttons display full TIMER text and have all borders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryProvider.overrideWith(MockLibraryNotifier.new),
          playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
          playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          themeProvider.overrideWith(MockThemeNotifier.new),
          settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          equalizerProvider.overrideWith(MockEqualizerNotifier.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: NowPlayingScreen(isDrawer: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify TIMER text is not truncated
    expect(find.text('TIMER'), findsOneWidget);
    expect(find.text('EQ'), findsOneWidget);
    expect(find.text('ATMOS'), findsOneWidget);
    expect(find.text('QUEUE'), findsOneWidget);

    // Verify each button has full borders on all 4 sides
    final retroButtons = tester.widgetList<RetroButton>(find.byType(RetroButton));
    final utilityButtons = retroButtons.where((b) =>
      b.label == 'TIMER' || b.label == 'EQ' || b.label == 'ATMOS' || b.label == 'QUEUE'
    ).toList();

    expect(utilityButtons.length, 4);

    for (final btn in utilityButtons) {
      expect(btn.border, isNotNull);
      final border = btn.border as Border;
      expect(border.top.width, greaterThan(0), reason: '${btn.label} should have top border');
      expect(border.bottom.width, greaterThan(0), reason: '${btn.label} should have bottom border');
      expect(border.left.width, greaterThan(0), reason: '${btn.label} should have left border');
      expect(border.right.width, greaterThan(0), reason: '${btn.label} should have right border');
    }
  });

  testWidgets('RetroClockTimerDialog renders custom retro clock, stepper buttons, and sets timer', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.darkTheme(),
          home: const Scaffold(
            body: RetroClockTimerDialog(initialDuration: Duration(minutes: 45)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify dialog title and digital readout
    expect(find.text('CLOCK TIMER'), findsOneWidget);
    expect(find.text('45 MIN'), findsOneWidget);
    expect(find.text('45:00'), findsOneWidget);

    // Verify CustomPaint with retro clock is present
    expect(find.byType(CustomPaint), findsWidgets);

    // Verify step buttons
    expect(find.text('+5M'), findsOneWidget);
    expect(find.text('-5M'), findsOneWidget);

    // Tap +5M step button
    await tester.tap(find.text('+5M'));
    await tester.pumpAndSettle();

    // Minutes should now be 50 MIN
    expect(find.text('50 MIN'), findsOneWidget);

    // Verify SET TIMER button exists
    expect(find.text('SET TIMER'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(RetroClockTimerDialog)));
    await tester.tap(find.text('SET TIMER'));
    await tester.pumpAndSettle();
    container.read(playerProvider.notifier).setSleepTimer(null);
  });
}
