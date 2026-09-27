import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/widgets/retro_icon.dart';

class TestLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() {
    return const LibraryState(
      isLoading: false,
      sortMode: SongSortMode.title,
      sortAscending: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Library Sort Direction State Tests', () {
    test('LibraryNotifier toggles sort direction and sets sort ascending', () {
      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(TestLibraryNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      // Initial state
      final initial = container.read(libraryProvider);
      expect(initial.sortAscending, isTrue);

      // Toggle to descending
      container.read(libraryProvider.notifier).toggleSortDirection();
      expect(container.read(libraryProvider).sortAscending, isFalse);

      // Toggle back to ascending
      container.read(libraryProvider.notifier).toggleSortDirection();
      expect(container.read(libraryProvider).sortAscending, isTrue);

      // setSortAscending explicitly
      container.read(libraryProvider.notifier).setSortAscending(false);
      expect(container.read(libraryProvider).sortAscending, isFalse);

      container.read(libraryProvider.notifier).setSortAscending(true);
      expect(container.read(libraryProvider).sortAscending, isTrue);
    });

    test('album, artist, and folder sort ascending providers toggle correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Album
      expect(container.read(albumSortAscendingProvider), isTrue);
      container.read(albumSortAscendingProvider.notifier).toggle();
      expect(container.read(albumSortAscendingProvider), isFalse);
      container.read(albumSortAscendingProvider.notifier).set(true);
      expect(container.read(albumSortAscendingProvider), isTrue);

      // Artist
      expect(container.read(artistSortAscendingProvider), isTrue);
      container.read(artistSortAscendingProvider.notifier).toggle();
      expect(container.read(artistSortAscendingProvider), isFalse);
      container.read(artistSortAscendingProvider.notifier).set(true);
      expect(container.read(artistSortAscendingProvider), isTrue);

      // Folder
      expect(container.read(folderSortAscendingProvider), isTrue);
      container.read(folderSortAscendingProvider.notifier).toggle();
      expect(container.read(folderSortAscendingProvider), isFalse);
      container.read(folderSortAscendingProvider.notifier).set(true);
      expect(container.read(folderSortAscendingProvider), isTrue);
    });

    test('LibraryState filteredSongs respects sortAscending flag', () {
      const quality = AudioQuality(format: 'MP3');
      const songA = Song(
        id: '1',
        title: 'Alpha',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: '/a.mp3',
        quality: quality,
      );
      const songZ = Song(
        id: '2',
        title: 'Zulu',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 200),
        uri: '/z.mp3',
        quality: quality,
      );

      // Ascending
      const stateAsc = LibraryState(
        allSongs: [songZ, songA],
        sortMode: SongSortMode.title,
        sortAscending: true,
      );
      final ascList = stateAsc.filteredSongs;
      expect(ascList.first.title, equals('Alpha'));
      expect(ascList.last.title, equals('Zulu'));

      // Descending
      const stateDesc = LibraryState(
        allSongs: [songZ, songA],
        sortMode: SongSortMode.title,
        sortAscending: false,
      );
      final descList = stateDesc.filteredSongs;
      expect(descList.first.title, equals('Zulu'));
      expect(descList.last.title, equals('Alpha'));
    });
  });

  group('RetroIcon Sort Arrow Widget Tests', () {
    testWidgets('RetroIcon renders arrow_up and arrow_down without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                RetroIcon('arrow_up', size: 16),
                RetroIcon('arrow_down', size: 16),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(RetroIcon), findsNWidgets(2));
    });
  });
}
