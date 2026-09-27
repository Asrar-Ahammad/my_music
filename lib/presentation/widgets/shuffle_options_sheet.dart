import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import 'retro_badge.dart';
import 'retro_button.dart';
import 'retro_icon.dart';
import 'retro_toast.dart';

/// Modal bottom sheet displaying comprehensive 8-bit Shuffle Play options.
class ShuffleOptionsSheet extends ConsumerWidget {
  const ShuffleOptionsSheet({super.key});

  /// Static helper to display the sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ShuffleOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final libraryState = ref.watch(libraryProvider);

    final allSongs = libraryState.allSongs;
    final currentSong = playerState.currentSong;
    final queue = playerState.queue;
    final isShuffle = playerState.isShuffle;

    final hasAlbum = currentSong != null &&
        currentSong.album.trim().isNotEmpty &&
        currentSong.album.toLowerCase() != 'unknown';

    final hasArtist = currentSong != null &&
        currentSong.artist.trim().isNotEmpty &&
        currentSong.artist.toLowerCase() != 'unknown';

    void showNotification(String message) {
      RetroToast.show(
        context,
        message,
        icon: 'shuffle',
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: retro.borderColor,
              width: retro.borderWidth,
            ),
          ),
          borderRadius: BorderRadius.zero,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: retro.borderColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),

            // Header row
            Row(
              children: [
                RetroIcon(
                  'shuffle',
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'SHUFFLE PLAY OPTIONS',
                    style: RetroTypography.pixelHeader(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                RetroButton(
                  isCompact: true,
                  padding: const EdgeInsets.all(5),
                  backgroundColor: retro.cardColor,
                  borderColor: retro.borderColor,
                  icon: const RetroIcon('close', size: 14),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Shuffle Mode Toggle Card
            GestureDetector(
              onTap: () {
                playerNotifier.toggleShuffle();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isShuffle
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : retro.cardColor,
                  border: Border.all(
                    color: isShuffle ? theme.colorScheme.primary : retro.borderColor,
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    RetroIcon(
                      'shuffle',
                      size: 20,
                      color: isShuffle
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SHUFFLE PLAYBACK MODE',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 9.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isShuffle
                                ? 'Tracks play in randomized order'
                                : 'Tracks play sequentially in order',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RetroBadge(
                      text: isShuffle ? 'ON' : 'OFF',
                      backgroundColor: isShuffle ? retro.accentGreen : retro.disabledColor,
                      textColor: isShuffle ? Colors.black : Colors.white,
                      fontSize: 8.5,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Action section title
            Text(
              'QUICK SHUFFLE ACTIONS',
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontSize: 8.5,
              ),
            ),

            const SizedBox(height: 8),

            // Option 1: Shuffle All Songs
            RetroButton(
              label: 'SHUFFLE ALL SONGS (${allSongs.length})',
              icon: const RetroIcon('play', size: 15, color: Colors.black),
              backgroundColor: retro.accentYellow,
              textColor: Colors.black,
              borderColor: retro.borderColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onPressed: allSongs.isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      playerNotifier.shuffleAll(allSongs);
                      showNotification('Shuffling all ${allSongs.length} songs');
                    },
            ),

            const SizedBox(height: 8),

            // Option 2: Reshuffle Current Queue
            if (queue.length > 1) ...[
              RetroButton(
                label: 'RESHUFFLE CURRENT QUEUE (${queue.length})',
                icon: RetroIcon(
                  'shuffle',
                  size: 15,
                  color: theme.colorScheme.onSurface,
                ),
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                borderColor: retro.borderColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onPressed: () {
                  Navigator.pop(context);
                  playerNotifier.reshuffleQueue();
                  showNotification('Queue reshuffled (${queue.length} songs)');
                },
              ),
              const SizedBox(height: 8),
            ],

            // Option 3: Shuffle Album
            if (hasAlbum) ...[
              RetroButton(
                label: 'SHUFFLE ALBUM: ${currentSong.album}',
                icon: RetroIcon(
                  'music',
                  size: 15,
                  color: theme.colorScheme.onSurface,
                ),
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                borderColor: retro.borderColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onPressed: () {
                  Navigator.pop(context);
                  playerNotifier.shuffleAlbum(allSongs, currentSong.album);
                  showNotification('Shuffling album: ${currentSong.album}');
                },
              ),
              const SizedBox(height: 8),
            ],

            // Option 4: Shuffle Artist
            if (hasArtist) ...[
              RetroButton(
                label: 'SHUFFLE ARTIST: ${currentSong.artist}',
                icon: RetroIcon(
                  'heart',
                  size: 15,
                  color: theme.colorScheme.onSurface,
                ),
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                borderColor: retro.borderColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onPressed: () {
                  Navigator.pop(context);
                  playerNotifier.shuffleArtist(allSongs, currentSong.artist);
                  showNotification('Shuffling artist: ${currentSong.artist}');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
