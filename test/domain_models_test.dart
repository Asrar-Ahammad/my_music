import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/domain/models/album.dart';
import 'package:my_music/domain/models/artist.dart';
import 'package:my_music/domain/models/playlist.dart';

void main() {
  group('Domain Models & Audio Quality Tests', () {
    test('AudioQuality identifies Hi-Res bit depth and sample rates', () {
      const normalMp3 = AudioQuality(
        format: 'MP3',
        bitDepth: 16,
        sampleRate: 44100,
        bitrateKbps: 320,
      );
      expect(normalMp3.isHiRes, isFalse);
      expect(normalMp3.isLossless, isFalse);
      expect(normalMp3.isHighQuality, isTrue);
      expect(normalMp3.qualityTier, equals(AudioQualityTier.highQuality));
      expect(normalMp3.tierLabel, equals('HQ'));
      expect(normalMp3.qualityBadge, equals('HQ 320k'));
      expect(normalMp3.sampleRateKhz, equals('44.1kHz'));
      expect(normalMp3.badgeText, equals('HQ • 320kbps'));

      const hiResFlac = AudioQuality(
        format: 'FLAC',
        bitDepth: 24,
        sampleRate: 96000,
        bitrateKbps: 4608,
      );
      expect(hiResFlac.isHiRes, isTrue);
      expect(hiResFlac.isLossless, isTrue);
      expect(hiResFlac.qualityTier, equals(AudioQualityTier.hiRes));
      expect(hiResFlac.tierLabel, equals('HI-RES'));
      expect(hiResFlac.qualityBadge, equals('24-BIT 96kHz'));
      expect(hiResFlac.sampleRateKhz, equals('96kHz'));
      expect(hiResFlac.badgeText, equals('HI-RES • 24-BIT 96kHz'));
      expect(hiResFlac.fullSpecs, contains('24-bit'));
      expect(hiResFlac.fullSpecs, contains('96.0 kHz'));

      const cdWav = AudioQuality(
        format: 'WAV',
        bitDepth: 16,
        sampleRate: 44100,
        bitrateKbps: 1411,
      );
      expect(cdWav.isHiRes, isFalse);
      expect(cdWav.isLossless, isTrue);
      expect(cdWav.qualityTier, equals(AudioQualityTier.lossless));
      expect(cdWav.qualityBadge, equals('LOSSLESS'));

      // Serialization
      final map = hiResFlac.toMap();
      final restored = AudioQuality.fromMap(map);
      expect(restored.format, equals('FLAC'));
      expect(restored.bitDepth, equals(24));
      expect(restored.sampleRate, equals(96000));
    });

    test('Song model copyWith and serialization work properly', () {
      const song = Song(
        id: 'track_1',
        title: 'Chiptune Quest',
        artist: 'Pixel Hero',
        album: 'Retro World',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/chiptune_quest.wav',
        isAsset: true,
        quality: AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
        isFavorite: false,
      );

      expect(song.id, equals('track_1'));
      expect(song.isFavorite, isFalse);

      final favSong = song.copyWith(isFavorite: true);
      expect(favSong.isFavorite, isTrue);
      expect(favSong.title, equals('Chiptune Quest'));

      final map = song.toMap();
      final restored = Song.fromMap(map);
      expect(restored.id, equals(song.id));
      expect(restored.title, equals(song.title));
      expect(restored.artist, equals(song.artist));
      expect(restored.duration.inSeconds, equals(120));
      expect(restored.quality.format, equals('WAV'));
    });

    test('Album and Artist compute aggregations correctly', () {
      const s1 = Song(
        id: '1',
        title: 'Song 1',
        artist: 'Chiptune Band',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'path1',
        quality: AudioQuality(format: 'FLAC'),
      );
      const s2 = Song(
        id: '2',
        title: 'Song 2',
        artist: 'Chiptune Band',
        album: 'Album 1',
        duration: Duration(seconds: 140),
        uri: 'path2',
        quality: AudioQuality(format: 'FLAC'),
      );

      const album = Album(
        title: 'Album 1',
        artist: 'Chiptune Band',
        songs: [s1, s2],
      );
      expect(album.trackCount, equals(2));
      expect(album.totalDuration, equals(const Duration(seconds: 240)));
      expect(album.effectiveArtPath, isNull);

      // When second song has art, effectiveArtPath resolves it
      final s2WithArt = s2.copyWith(artPath: 'assets/album_art/retro_quest.svg');
      final albumWithSongArt = Album(
        title: 'Album 1',
        artist: 'Chiptune Band',
        songs: [s1, s2WithArt],
      );
      expect(albumWithSongArt.effectiveArtPath, equals('assets/album_art/retro_quest.svg'));

      // When album has explicit art, it takes precedence
      final albumWithExplicitArt = Album(
        title: 'Album 1',
        artist: 'Chiptune Band',
        songs: [s1, s2WithArt],
        artPath: 'assets/album_art/arcade_rush.svg',
      );
      expect(albumWithExplicitArt.effectiveArtPath, equals('assets/album_art/arcade_rush.svg'));

      const artist = Artist(
        name: 'Chiptune Band',
        songs: [s1, s2],
      );
      expect(artist.trackCount, equals(2));
      expect(artist.albumCount, equals(1));
      expect(artist.artPath, isNull);

      final artistWithArt = Artist(
        name: 'Chiptune Band',
        songs: [s1, s2WithArt],
      );
      expect(artistWithArt.artPath, equals('assets/album_art/retro_quest.svg'));
    });

    test('Playlist creation and manipulation', () {
      final now = DateTime.now();
      final playlist = Playlist(
        id: 'p1',
        name: 'Retro Hits',
        songIds: ['s1', 's2'],
        createdAt: now,
      );

      expect(playlist.songIds.length, equals(2));
      final modified = playlist.copyWith(name: 'Arcade Classics');
      expect(modified.name, equals('Arcade Classics'));
      expect(modified.songIds, equals(['s1', 's2']));

      final map = playlist.toMap();
      final restored = Playlist.fromMap(map);
      expect(restored.name, equals('Retro Hits'));
      expect(restored.songIds, equals(['s1', 's2']));
      expect(restored.customArtPath, isNull);
    });

    test('Playlist getValidSongCount reflects available library songs', () {
      final now = DateTime.now();
      final playlist = Playlist(
        id: 'p1',
        name: 'Retro Hits',
        songIds: ['s1', 's2', 's3'],
        createdAt: now,
      );

      const song1 = Song(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 120),
        uri: '/path/1',
        quality: AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 150),
        uri: '/path/2',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      // When all songs are present
      expect(playlist.getValidSongCount([song1, song2]), equals(2));

      // When song2 is removed from local storage
      expect(playlist.getValidSongCount([song1]), equals(1));

      // When all songs are removed
      expect(playlist.getValidSongCount([]), equals(0));

      // When library is empty but still loading, falls back to songIds.length
      expect(playlist.getValidSongCount([], isLoading: true), equals(3));
    });

    test('Playlist customArtPath and resolveArtPath fallback logic', () {
      final now = DateTime.now();
      const s1 = Song(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 120),
        uri: 'uri1',
        quality: AudioQuality(format: 'MP3'),
        artPath: 'assets/album_art/first_song_cover.png',
      );
      const s2 = Song(
        id: 's2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 140),
        uri: 'uri2',
        quality: AudioQuality(format: 'MP3'),
        artPath: 'assets/album_art/second_song_cover.png',
      );
      const sNoArt = Song(
        id: 's_no_art',
        title: 'Song No Art',
        artist: 'Artist 3',
        album: 'Album 3',
        duration: Duration(seconds: 90),
        uri: 'uri3',
        quality: AudioQuality(format: 'MP3'),
      );

      final List<Song> songs = [s1, s2, sNoArt];

      // 1. Fallback to first song's artwork when customArtPath is null
      final pDefault = Playlist(
        id: 'p1',
        name: 'My Playlist',
        songIds: ['s1', 's2'],
        createdAt: now,
      );
      expect(pDefault.resolveArtPath(songs), equals('assets/album_art/first_song_cover.png'));

      // 2. If first song has no art but second song has art, fallback picks first available
      final pFirstNoArt = Playlist(
        id: 'p2',
        name: 'Mixed Art',
        songIds: ['s_no_art', 's2'],
        createdAt: now,
      );
      expect(pFirstNoArt.resolveArtPath(songs), equals('assets/album_art/second_song_cover.png'));

      // 3. If no songs have art, resolveArtPath returns null
      final pEmptyOrNoArt = Playlist(
        id: 'p3',
        name: 'No Art',
        songIds: ['s_no_art'],
        createdAt: now,
      );
      expect(pEmptyOrNoArt.resolveArtPath(songs), isNull);

      // 4. Custom art takes priority over song artworks
      final pCustom = Playlist(
        id: 'p4',
        name: 'Custom Art Playlist',
        songIds: ['s1', 's2'],
        createdAt: now,
        customArtPath: '/data/user/0/images/custom_playlist_cover.jpg',
      );
      expect(pCustom.resolveArtPath(songs), equals('/data/user/0/images/custom_playlist_cover.jpg'));

      // 5. Serialization with customArtPath
      final pCustomMap = pCustom.toMap();
      final pCustomRestored = Playlist.fromMap(pCustomMap);
      expect(pCustomRestored.customArtPath, equals('/data/user/0/images/custom_playlist_cover.jpg'));

      // 6. Clearing custom art with copyWith(clearCustomArt: true)
      final cleared = pCustom.copyWith(clearCustomArt: true);
      expect(cleared.customArtPath, isNull);
      expect(cleared.resolveArtPath(songs), equals('assets/album_art/first_song_cover.png'));
    });
  });
}
