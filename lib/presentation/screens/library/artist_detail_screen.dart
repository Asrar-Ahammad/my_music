import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/recently_played_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_song_tile.dart';

class ArtistDetailScreen extends ConsumerWidget {
  final Artist artist;
  final VoidCallback? onBack;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    // Refresh artist info dynamically if library changes
    final currentArtist = libraryState.artists.firstWhere(
      (a) => a.name.toLowerCase() == artist.name.toLowerCase(),
      orElse: () => artist,
    );
    final List<Song> songs = currentArtist.songs;

    final Widget content = Column(
      children: [
        // Banner with Artist Info, Play All, and Shuffle Play
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: retro.cardColor,
            border: Border(
              bottom: BorderSide(color: retro.borderColor, width: retro.borderWidth),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RetroAlbumArt(
                    artPath: currentArtist.artPath,
                    title: currentArtist.name,
                    width: 48,
                    height: 48,
                    borderWidth: 2.0,
                    borderColor: retro.borderColor,
                    backgroundColor: retro.accentPurple,
                    placeholderIconSize: 22,
                    placeholderColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentArtist.name,
                          style: RetroTypography.pixelHeader(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} Tracks • ${currentArtist.albumCount} Albums',
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
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
                          ref.read(recentlyPlayedProvider.notifier).recordArtist(
                                name: artist.name,
                                artUri: artist.artPath,
                                songCount: artist.songs.length,
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
                          ref.read(recentlyPlayedProvider.notifier).recordArtist(
                                name: artist.name,
                                artUri: artist.artPath,
                                songCount: artist.songs.length,
                              );
                          final shuffled = List<Song>.from(songs)..shuffle();
                          playerNotifier.playSong(shuffled.first, queue: shuffled);
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
                    'NO SONGS FOUND FOR THIS ARTIST',
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
                      subtitle: '${song.album.isNotEmpty ? song.album : "Single"} • ${DurationFormatter.format(song.duration)}',
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
          currentArtist.name.toUpperCase(),
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
