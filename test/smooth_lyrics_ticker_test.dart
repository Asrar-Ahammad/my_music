import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/lrc_model.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/lyrics_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/widgets/smooth_lyrics_ticker.dart';

class _FakeLyricsNotifier extends LyricsNotifier {
  final LyricsState _initialState;
  _FakeLyricsNotifier(this._initialState);

  @override
  LyricsState build() => _initialState;

  void updateState(LyricsState newState) {
    state = newState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSong = Song(
    id: 'test_song_1',
    title: 'Test Song',
    artist: 'Test Artist',
    album: 'Test Album',
    duration: Duration(seconds: 200),
    uri: 'file:///test.mp3',
    quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
  );

  final testDoc = LrcDocument(
    lines: const [
      LrcLine(timestamp: Duration(seconds: 0), text: 'Line 1: In the beginning'),
      LrcLine(timestamp: Duration(seconds: 5), text: 'Line 2: The story continues'),
      LrcLine(timestamp: Duration(seconds: 10), text: 'Line 3: Reaching the climax'),
    ],
    isSynced: true,
    rawContent: '',
  );

  testWidgets('SmoothLyricsTicker animates next line from bottom and old line upwards (Spotify style)', (tester) async {
    final notifier = _FakeLyricsNotifier(
      LyricsState(
        lyrics: testDoc,
        activeLineIndex: 0,
        songId: testSong.id,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lyricsProvider.overrideWith(() => notifier),
          playerProvider.overrideWith(
            () => _FakePlayerNotifier(
              const PlayerStateModel(
                currentSong: testSong,
                isPlaying: true,
                position: Duration.zero,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: RetroTheme.darkTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: SmoothLyricsTicker(
                song: testSong,
                retro: context.retro,
                theme: Theme.of(context),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Line 1: In the beginning'), findsOneWidget);

    // Advance to line 2
    notifier.updateState(
      LyricsState(
        lyrics: testDoc,
        activeLineIndex: 1,
        songId: testSong.id,
      ),
    );

    // Pump one frame so the animation starts
    await tester.pump();
    // Advance 100ms into the 250ms animation
    await tester.pump(const Duration(milliseconds: 100));

    final slideTransitions = tester.widgetList<SlideTransition>(find.byType(SlideTransition)).toList();
    // The animated switcher transitions are the last two SlideTransitions
    final outSlide = slideTransitions.firstWhere((s) => s.position.status == AnimationStatus.reverse);
    final inSlide = slideTransitions.firstWhere((s) => s.position.status == AnimationStatus.forward);

    expect(outSlide.position.value.dy, lessThan(0.0));
    expect(inSlide.position.value.dy, greaterThan(0.0));

    // Let transition finish
    await tester.pumpAndSettle();
    expect(find.text('Line 2: The story continues'), findsOneWidget);
    expect(find.text('Line 1: In the beginning'), findsNothing);
  });
}

class _FakePlayerNotifier extends PlayerNotifier {
  final PlayerStateModel _model;
  _FakePlayerNotifier(this._model);

  @override
  PlayerStateModel build() => _model;
}
