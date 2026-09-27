import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../data/services/file_scanner_service.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_refresh_indicator.dart';
import '../../widgets/retro_song_tile.dart';
import '../../widgets/retro_toast.dart';

class FolderDetailScreen extends ConsumerWidget {
  final String folderPath;
  final VoidCallback? onBack;

  const FolderDetailScreen({
    super.key,
    required this.folderPath,
    this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    final List<Song> songs = libraryState.folders[folderPath] ?? [];
    final folderName = folderPath.contains('/')
        ? folderPath.split('/').where((s) => s.isNotEmpty).last
        : folderPath;

    // Resolve artwork from folder cover image or any song in the folder
    String? folderArt = FileScannerService.findFolderCoverImageSync(folderPath);
    if (folderArt == null) {
      for (final s in songs) {
        if (s.artPath != null && s.artPath!.trim().isNotEmpty) {
          folderArt = s.artPath!.trim();
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const RetroIcon('arrow_left', size: 20),
          onPressed: () {
            if (onBack != null) {
              onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          folderName.toUpperCase(),
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          // Banner with Folder Info, Play All, and Shuffle Play
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
                    folderArt != null
                        ? RetroAlbumArt(
                            artPath: folderArt,
                            title: folderName,
                            width: 48,
                            height: 48,
                            borderWidth: 2.0,
                            borderColor: retro.borderColor,
                            backgroundColor: retro.accentYellow,
                            placeholderIconSize: 22,
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: retro.accentYellow,
                              border: Border.all(color: retro.borderColor, width: 2.0),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: const Center(
                              child: RetroIcon('folder', size: 24, color: Colors.black),
                            ),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folderName,
                            style: RetroTypography.pixelHeader(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${songs.length} Tracks • $folderPath',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 13,
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
                            playerNotifier.playSong(songs.first, queue: songs);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RetroButton(
                          label: 'SHUFFLE PLAY',
                          icon: const RetroIcon('shuffle', size: 14),
                          backgroundColor: retro.accentYellow,
                          textColor: Colors.black,
                          onPressed: () {
                            playerNotifier.shuffleList(songs);
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
            child: RetroRefreshIndicator(
              onRefresh: () async {
                final result = await ref.read(libraryProvider.notifier).rescanLibrary();
                if (context.mounted) {
                  final updatedSongs = ref.read(libraryProvider).folders[folderPath] ?? [];
                  if (result.newCount > 0) {
                    RetroToast.show(
                      context,
                      'FOUND ${result.newCount} NEW TRACK${result.newCount == 1 ? '' : 'S'} \u2022 ${updatedSongs.length} IN FOLDER',
                      icon: 'folder',
                      iconColor: theme.colorScheme.secondary,
                    );
                  } else {
                    RetroToast.show(
                      context,
                      'FOLDER UP TO DATE \u2022 ${updatedSongs.length} TRACKS',
                      icon: 'check',
                      iconColor: context.retro.accentGreen,
                    );
                  }
                }
              },
              child: songs.isEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Text(
                              'NO SONGS FOUND IN THIS FOLDER',
                              style: RetroTypography.pixelHeader(
                                color: theme.colorScheme.onSurface,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
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
                        subtitle: '${song.artist} • ${DurationFormatter.format(song.duration)}',
                        onTap: () {
                          playerNotifier.playSong(song, queue: songs);
                        },
                      );
                    },
                  ),

            ),
          ),
        ],
      ),
    );
  }
}
