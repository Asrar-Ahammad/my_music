import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/recently_played_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_song_tile.dart';

class AlbumDetailScreen extends ConsumerWidget {
  final Album album;
  final VoidCallback? onBack;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    // Refresh album info dynamically if library changes
    final currentAlbum = libraryState.albums.firstWhere(
      (a) =>
          a.title.toLowerCase() == album.title.toLowerCase() &&
          a.artist.toLowerCase() == album.artist.toLowerCase(),
      orElse: () => album,
    );
    final List<Song> songs = currentAlbum.songs;

    final Widget content = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: retro.cardColor,
            border: Border(
              bottom: BorderSide(
                color: retro.borderColor,
                width: retro.borderWidth,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RetroAlbumArt(
                    artPath: currentAlbum.effectiveArtPath,
                    title: currentAlbum.title,
                    artist: currentAlbum.artist,
                    width: 52,
                    height: 52,
                    borderWidth: 2.0,
                    borderColor: retro.borderColor,
                    backgroundColor: retro.cardColor,
                    placeholderIconSize: 24,
                    placeholderColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentAlbum.title,
                          style: RetroTypography.pixelHeader(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${currentAlbum.artist} • ${songs.length} Tracks',
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (songs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RetroButton(
                        label: 'PLAY ALL',
                        icon: const RetroIcon('play', size: 14),
                        backgroundColor: theme.colorScheme.primary,
                        textColor: theme.colorScheme.onPrimary,
                        onPressed: () {
                          ref
                              .read(recentlyPlayedProvider.notifier)
                              .recordAlbum(
                                title: currentAlbum.title,
                                artist: currentAlbum.artist,
                                artUri: currentAlbum.effectiveArtPath,
                              );
                          playerNotifier.playSong(songs.first, queue: songs);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RetroButton(
                        label: 'SHUFFLE PLAY',
                        icon: const RetroIcon('shuffle', size: 14),
                        backgroundColor: retro.cardColor,
                        textColor: theme.colorScheme.onSurface,
                        borderColor: retro.borderColor,
                        onPressed: () {
                          ref
                              .read(recentlyPlayedProvider.notifier)
                              .recordAlbum(
                                title: currentAlbum.title,
                                artist: currentAlbum.artist,
                                artUri: currentAlbum.effectiveArtPath,
                              );
                          final shuffled = List<Song>.from(songs)..shuffle();
                          playerNotifier.playSong(
                            shuffled.first,
                            queue: shuffled,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Songs List
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text(
                    'NO SONGS FOUND IN THIS ALBUM',
                    style: RetroTypography.pixelHeader(
                      color: theme.colorScheme.onSurface,
                      fontSize: 11,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: songs.length,
                  // ignore: deprecated_member_use
                  cacheExtent: 500,
                  addRepaintBoundaries: true,
                  separatorBuilder: (context, idx) => Container(
                    height: 1,
                    color: retro.borderColor.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return RetroSongTile(
                      key: ValueKey(song.id),
                      song: song,
                      index: index,
                      queue: songs,
                      subtitle: DurationFormatter.format(song.duration),
                      showAlbumArt: false,
                      showIndex: true,
                    );
                  },
                ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const RetroIcon('arrow_left', size: 20),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          currentAlbum.title.toUpperCase(),
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: content,
    );
  }
}
