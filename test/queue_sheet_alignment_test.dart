import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/data/repositories/settings_repository.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/screens/now_playing/queue_sheet.dart';
import 'package:my_music/presentation/widgets/retro_badge.dart';
import 'package:my_music/presentation/widgets/retro_button.dart';

class _MockSettingsRepository extends SettingsRepository {
  @override
  bool isDarkMode() => false;
}

class _MockPlayerNotifierWithQueue extends PlayerNotifier {
  @override
  PlayerStateModel build() {
    final song1 = Song(
      id: 's1',
      title: 'Chiptune 1',
      artist: 'Retro',
      album: 'Album',
      duration: const Duration(seconds: 30),
      uri: 'assets/audio/chiptune_quest.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
    );
    final song2 = Song(
      id: 's2',
      title: 'Chiptune 2',
      artist: 'Retro',
      album: 'Album',
      duration: const Duration(seconds: 45),
      uri: 'assets/audio/neon_pixels.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
    );
    return PlayerStateModel(
      currentSong: song1,
      isPlaying: true,
      queue: [song1, song2],
      currentIndex: 0,
      duration: const Duration(seconds: 30),
      position: const Duration(seconds: 10),
      isShuffle: false,
    );
  }

  @override
  Future<void> toggleShuffle() async {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }

  @override
  Future<void> reshuffleQueue() async {
    final cur = state.currentSong;
    final others = state.queue.where((s) => s.id != cur?.id).toList()..shuffle();
    state = state.copyWith(
      isShuffle: true,
      queue: cur != null ? [cur, ...others] : others,
    );
  }
}

void main() {
  testWidgets('QueueSheet top buttons and header layout test across small phone screens', (tester) async {
    // Set a narrow mobile screen width (360x640)
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(_MockSettingsRepository()),
          playerProvider.overrideWith(_MockPlayerNotifierWithQueue.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: QueueSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Row 1: Title, Badge, and Close Button
    expect(find.text('PLAYBACK QUEUE'), findsOneWidget);
    expect(find.text('2 TRACKS'), findsOneWidget);
    expect(find.byType(RetroBadge), findsOneWidget);

    // Verify Row 2: Up Next label, SHUFFLE button, RESHUFFLE button, and CLEAR button
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('SHUFFLE'), findsOneWidget);
    expect(find.text('RESHUFFLE'), findsOneWidget);
    expect(find.text('CLEAR'), findsOneWidget);

    // Verify RetroButtons are visible and within screen bounds (no overflow)
    final shuffleFinder = find.widgetWithText(RetroButton, 'SHUFFLE');
    final reshuffleFinder = find.widgetWithText(RetroButton, 'RESHUFFLE');
    final clearFinder = find.widgetWithText(RetroButton, 'CLEAR');
    expect(shuffleFinder, findsOneWidget);
    expect(reshuffleFinder, findsOneWidget);
    expect(clearFinder, findsOneWidget);

    final shuffleRect = tester.getRect(shuffleFinder);
    final reshuffleRect = tester.getRect(reshuffleFinder);
    final clearRect = tester.getRect(clearFinder);

    // RESHUFFLE is on the right of SHUFFLE, and CLEAR is to the right of RESHUFFLE
    expect(shuffleRect.left, greaterThanOrEqualTo(0));
    expect(shuffleRect.right, lessThan(reshuffleRect.left));
    expect(reshuffleRect.right, lessThan(clearRect.left));
    expect(clearRect.right, lessThanOrEqualTo(360));

    // All buttons share identical vertical alignment / height
    expect((shuffleRect.top - reshuffleRect.top).abs(), lessThan(2.0));
    expect((reshuffleRect.top - clearRect.top).abs(), lessThan(2.0));
    expect((shuffleRect.bottom - reshuffleRect.bottom).abs(), lessThan(2.0));

    // Tap SHUFFLE and ensure toggle works without causing overflow
    await tester.tap(shuffleFinder);
    await tester.pumpAndSettle();
    expect(find.text('SHUFFLE ON'), findsOneWidget);

    final shuffleOnRect = tester.getRect(find.widgetWithText(RetroButton, 'SHUFFLE ON'));
    final reshuffleRectAfter = tester.getRect(reshuffleFinder);
    expect(shuffleOnRect.right, lessThan(reshuffleRectAfter.left));
    expect(tester.getRect(clearFinder).right, lessThanOrEqualTo(360));

    // Tap RESHUFFLE button and verify it triggers reshuffle
    await tester.tap(reshuffleFinder);
    await tester.pumpAndSettle();
    expect(find.text('QUEUE RESHUFFLED'), findsOneWidget);
  });
}
