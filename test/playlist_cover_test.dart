import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:my_music/data/services/audio_player_handler.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/domain/models/audio_quality.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Playlist Cover Resolution & Song Count Tests', () {
    const song1 = Song(
      id: 'file_111',
      title: 'Track One',
      artist: 'Artist One',
      album: 'Album One',
      duration: Duration(seconds: 120),
      uri: '/storage/emulated/0/Music/track1.mp3',
      artPath: 'assets/album_art/retro_quest.svg',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    );

    const song2 = Song(
      id: 'file_222',
      title: 'Track Two',
      artist: 'Artist Two',
      album: 'Album Two',
      duration: Duration(seconds: 150),
      uri: '/storage/emulated/0/Music/track2.mp3',
      artPath: 'assets/album_art/neon_stage.svg',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    );

    test('resolveArtPath resolves cover art by song.id', () {
      final playlist = Playlist(
        id: 'pl_1',
        name: 'My Playlist',
        songIds: ['file_111'],
        createdAt: DateTime.now(),
      );

      final art = playlist.resolveArtPath([song1, song2]);
      expect(art, 'assets/album_art/retro_quest.svg');
    });

    test('resolveArtPath resolves cover art when songIds stores URI path', () {
      final playlist = Playlist(
        id: 'pl_2',
        name: 'My URI Playlist',
        songIds: ['/storage/emulated/0/Music/track2.mp3'],
        createdAt: DateTime.now(),
      );

      final art = playlist.resolveArtPath([song1, song2]);
      expect(art, 'assets/album_art/neon_stage.svg');
    });

    test('resolveArtPath resolves cover art when songIds stores base filename', () {
      final playlist = Playlist(
        id: 'pl_3',
        name: 'My Filename Playlist',
        songIds: ['track1.mp3'],
        createdAt: DateTime.now(),
      );

      final art = playlist.resolveArtPath([song1, song2]);
      expect(art, 'assets/album_art/retro_quest.svg');
    });

    test('resolveArtPath prefers customArtPath if it is an asset', () {
      final playlist = Playlist(
        id: 'pl_4',
        name: 'Custom Art Playlist',
        songIds: ['file_111'],
        createdAt: DateTime.now(),
        customArtPath: 'assets/album_art/custom.png',
      );

      final art = playlist.resolveArtPath([song1, song2]);
      expect(art, 'assets/album_art/custom.png');
    });

    test('resolveArtPath falls back to songs if customArtPath file does not exist', () {
      final playlist = Playlist(
        id: 'pl_5',
        name: 'Missing File Custom Art',
        songIds: ['file_222'],
        createdAt: DateTime.now(),
        customArtPath: '/non/existent/path/cover.png',
      );

      final art = playlist.resolveArtPath([song1, song2]);
      expect(art, 'assets/album_art/neon_stage.svg');
    });

    test('getValidSongCount correctly counts songs with both IDs and URIs', () {
      final playlist = Playlist(
        id: 'pl_6',
        name: 'Count Test Playlist',
        songIds: ['file_111', '/storage/emulated/0/Music/track2.mp3', 'non_existent_track'],
        createdAt: DateTime.now(),
      );

      final count = playlist.getValidSongCount([song1, song2]);
      expect(count, 2);
    });

    test('Playlist.fromMap parses legacy coverArt and artPath fields', () {
      final p1 = Playlist.fromMap({
        'id': 'pl_7',
        'name': 'Legacy CoverArt',
        'songIds': ['s1'],
        'coverArt': 'assets/cover1.png',
      });
      expect(p1.customArtPath, 'assets/cover1.png');

      final p2 = Playlist.fromMap({
        'id': 'pl_8',
        'name': 'Legacy ArtPath',
        'songIds': ['s1'],
        'artPath': 'assets/cover2.png',
      });
      expect(p2.customArtPath, 'assets/cover2.png');
    });
  });

  group('System Notification Drawer & Shuffle Button Tests', () {
    test('PlaybackState has 5 controls with shuffle next to loop', () {
      final handler = AudioPlayerHandler();
      final controls = handler.playbackState.value.controls;

      expect(controls.length, 5);
      expect(controls[0].action, MediaAction.skipToPrevious);
      expect(controls[1].action, MediaAction.play);
      expect(controls[2].action, MediaAction.skipToNext);
      expect(controls[3].customAction?.name, 'toggle_repeat');
      expect(controls[4].customAction?.name, 'toggle_shuffle');
    });

    test('customAction toggle_shuffle toggles shuffle and updates icon', () async {
      final handler = AudioPlayerHandler();

      expect(handler.isShuffle, isFalse);
      expect(handler.playbackState.value.controls[4].androidIcon, 'drawable/ic_shuffle');

      await handler.customAction('toggle_shuffle');
      expect(handler.isShuffle, isTrue);
      expect(handler.playbackState.value.controls[4].androidIcon, 'drawable/ic_shuffle_dot');

      await handler.customAction('toggle_shuffle');
      expect(handler.isShuffle, isFalse);
      expect(handler.playbackState.value.controls[4].androidIcon, 'drawable/ic_shuffle');
    });
  });
}
