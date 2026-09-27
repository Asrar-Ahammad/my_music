import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_colors.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../../core/utils/duration_formatter.dart';
import '../../domain/models/song.dart';
import '../providers/font_provider.dart';
import '../providers/library_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import 'create_playlist_modal.dart';
import 'retro_album_art.dart';
import 'retro_button.dart';
import 'retro_icon.dart';
import 'retro_toast.dart';

/// Unified 8-bit arcade song tile matching the user's template:
/// [01] [Album Art] [Title / Subtitle • Duration] [FLAC 44.1kHz] [ ⋮ ]
class RetroSongTile extends ConsumerWidget {
  final Song song;
  final int? index;
  final List<Song> queue;
  final VoidCallback? onTap;
  final String? subtitle;
  final VoidCallback? onRemoveFromPlaylist;
  final bool showIndex;
  final bool showAlbumArt;
  final bool showQualityBadge;
  final bool showMenu;
  // --- Selection Mode ---
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const RetroSongTile({
    super.key,
    required this.song,
    this.index,
    required this.queue,
    this.onTap,
    this.subtitle,
    this.onRemoveFromPlaylist,
    this.showIndex = true,
    this.showAlbumArt = true,
    this.showQualityBadge = true,
    this.showMenu = true,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Narrow select: only rebuild when this song's current/playing status changes.
    // Avoids ~10Hz rebuilds caused by position stream updates on every visible tile.
    final (isCurrent, isPlaying) = ref.watch(playerProvider.select((s) {
      final cur = s.currentSong;
      final current = cur != null &&
          (cur.id == song.id ||
              (song.uri.isNotEmpty && cur.uri == song.uri));
      return (current, current && s.isPlaying);
    }));
    final activeFont = ref.watch(fontProvider);
    final isSatoshi = RetroTypography.isSatoshi(activeFont);
    final theme = Theme.of(context);
    final retro = context.retro;

    // Track number formatted as at least 2 digits: "01", "02", etc.
    final trackNumStr = index != null ? (index! + 1).toString().padLeft(2, '0') : '';

    // Calculate width and font size to support 3-digit and 4-digit numbers cleanly without wrapping
    final totalTracks = math.max(queue.length, (index != null ? index! + 1 : 0));
    final numDigits = math.max(
      trackNumStr.length,
      totalTracks >= 10000
          ? 5
          : totalTracks >= 1000
              ? 4
              : totalTracks >= 100
                  ? 3
                  : 2,
    );

    final double indexWidth;
    final double indexFontSize;
    if (numDigits >= 5) {
      indexWidth = 52;
      indexFontSize = 8.5;
    } else if (numDigits == 4) {
      indexWidth = 44;
      indexFontSize = 9.5;
    } else if (numDigits == 3) {
      indexWidth = 36;
      indexFontSize = 10.5;
    } else {
      indexWidth = 26;
      indexFontSize = 11.0;
    }

    // Subtitle format: "[Artist or Album] • [Duration]"
    final subtitleText = subtitle ??
        (song.artist.isNotEmpty
            ? '${song.artist} • ${DurationFormatter.format(song.duration)}'
            : (song.album.isNotEmpty
                ? '${song.album} • ${DurationFormatter.format(song.duration)}'
                : DurationFormatter.format(song.duration)));

    // Select only this song's favourite flag — avoids rebuild when other songs change.
    final isFavorite = ref.watch(
      libraryProvider.select((s) => s.songFavoriteMap[song.id] ?? song.isFavorite),
    );
    final isNothing = context.isNothingTheme;
    final isModern = isNothing;

    final tileContent = RepaintBoundary(
      child: InkWell(
        onLongPress: selectionMode ? null : onLongPress,
        onTap: selectionMode
            ? (onToggleSelect ?? () {})
            : onTap ?? () { ref.read(playerProvider.notifier).playSong(song, queue: queue); },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: isModern ? 0.12 : 0.18)
                : isCurrent
                    ? theme.colorScheme.primary.withValues(alpha: isNothing ? 0.10 : 0.14)
                    : Colors.transparent,
            border: isCurrent
                ? (isNothing
                    ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 0.5)
                    : Border.all(color: theme.colorScheme.primary, width: 1.5))
                : null,
            borderRadius: isModern ? BorderRadius.circular(10) : BorderRadius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // 1. Checkbox (selection mode) OR Track Number
            if (selectionMode) ...[
              SizedBox(
                width: indexWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isModern ? Colors.transparent : retro.cardColor),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isNothing ? context.nothing.borderColor : retro.borderColor),
                        width: isModern ? 1.2 : 2.0,
                      ),
                      borderRadius: isModern ? BorderRadius.circular(6) : BorderRadius.zero,
                    ),
                    child: isSelected
                        ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else if (showIndex && trackNumStr.isNotEmpty) ...[
              SizedBox(
                width: indexWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    trackNumStr,
                    textAlign: TextAlign.center,
                    style: isNothing
                        ? TextStyle(
                            fontFamily: 'GeistMono',
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                            fontSize: (indexFontSize * 1.1).clamp(11.0, 14.0),
                            fontWeight: FontWeight.w500,
                          )
                        : isSatoshi
                            ? TextStyle(
                                fontFamily: 'Satoshi',
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: RetroTypography.effectiveSatoshiSize(indexFontSize),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              )
                            : RetroTypography.pixelBadge(
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: indexFontSize,
                              ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // 2. Album Art Thumbnail (40x40)
            if (showAlbumArt) ...[
              RetroAlbumArt(
                artPath: song.artPath,
                title: song.title,
                artist: song.artist,
                width: 40,
                height: 40,
                borderWidth: isModern ? 0.0 : (isCurrent ? 1.5 : 1.0),
                borderColor: isCurrent ? theme.colorScheme.primary : retro.borderColor,
                backgroundColor: retro.cardColor,
                placeholderIconSize: 18,
              ),
              const SizedBox(width: 12),
            ],

            // 3. Middle Content: Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          song.title,
                          style: isNothing
                              ? TextStyle(
                                  fontFamily: 'Geist',
                                  color: isCurrent
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                )
                              : isSatoshi
                                  ? TextStyle(
                                      fontFamily: 'Satoshi',
                                      color: isCurrent
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.15,
                                      height: 1.25,
                                    )
                                  : RetroTypography.pixelHeader(
                                      color: isCurrent
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                      fontSize: 11,
                                    ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isFavorite) ...[
                        const SizedBox(width: 5),
                        const RetroIcon(
                          'heart_filled',
                          size: 11,
                          color: RetroColors.picoRed,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitleText,
                    style: isNothing
                        ? TextStyle(
                            fontFamily: 'Geist',
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                          )
                        : isSatoshi
                            ? TextStyle(
                                fontFamily: 'Satoshi',
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                                height: 1.2,
                              )
                            : RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 15.5,
                              ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Volume / Playing Speaker icon (vertically centered in tile)
            if (isPlaying) ...[
              const SizedBox(width: 8),
              RetroIcon(
                'volume',
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],



            // 5. Three-dot Dropdown Menu [ ⋮ ] — hidden in selection mode
            if (showMenu && !selectionMode) ...[
              const SizedBox(width: 2),

              PopupMenuButton<String>(
                icon: RetroIcon(
                  'more_vertical',
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
                tooltip: 'Song Options',
                elevation: 0,
                color: retro.cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(
                    color: retro.borderColor,
                    width: 2.0,
                  ),
                ),
                onSelected: (action) => _handleAction(context, ref, action),
                itemBuilder: (ctx) => [
                  _buildMenuItem(
                    value: 'play_next',
                    label: 'PLAY NEXT',
                    icon: 'skip_next',
                    theme: theme,
                  ),
                  _buildMenuItem(
                    value: 'add_queue',
                    label: 'ADD TO QUEUE',
                    icon: 'queue',
                    theme: theme,
                  ),
                  _buildMenuItem(
                    value: 'add_playlist',
                    label: 'ADD TO PLAYLIST',
                    icon: 'folder',
                    theme: theme,
                  ),
                  _buildMenuItem(
                    value: 'go_album',
                    label: 'GO TO ALBUM',
                    icon: 'disc',
                    theme: theme,
                  ),
                  _buildMenuItem(
                    value: 'go_artist',
                    label: 'GO TO ARTIST',
                    icon: 'user',
                    theme: theme,
                  ),
                  _buildMenuItem(
                    value: 'toggle_favorite',
                    label: isFavorite ? 'UNFAVORITE' : 'FAVORITE',
                    icon: isFavorite ? 'heart_filled' : 'heart',
                    theme: theme,
                    iconColor: isFavorite ? RetroColors.picoRed : null,
                  ),
                  if (onRemoveFromPlaylist != null) ...[
                    const PopupMenuDivider(height: 2),
                    _buildMenuItem(
                      value: 'remove_playlist',
                      label: 'REMOVE FROM PLAYLIST',
                      icon: 'trash',
                      theme: theme,
                      textColor: theme.colorScheme.primary,
                      iconColor: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),           // Row
        ),           // Padding
        ),           // DecoratedBox
      ),             // InkWell
    );               // RepaintBoundary

    if (selectionMode) {
      return tileContent;
    }

    return Dismissible(
      key: ValueKey('song_tile_dismissible_${song.id}_${index ?? 0}'),
      direction: DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.25,
        DismissDirection.endToStart: 0.25,
      },
      confirmDismiss: (direction) async {
        final playerNotifier = ref.read(playerProvider.notifier);
        if (direction == DismissDirection.startToEnd) {
          // Swipe Right: Add to Queue
          HapticFeedback.mediumImpact();
          playerNotifier.addToQueue(song);
          RetroToast.show(
            context,
            'ADDED TO QUEUE: ${song.title.toUpperCase()}',
            icon: 'queue',
          );
        } else if (direction == DismissDirection.endToStart) {
          // Swipe Left: Play Next
          HapticFeedback.mediumImpact();
          playerNotifier.addNext(song);
          RetroToast.show(
            context,
            'PLAYING NEXT: ${song.title.toUpperCase()}',
            icon: 'skip_next',
          );
        }
        // Always return false so the card snaps back smoothly without removing from list
        return false;
      },
      background: _buildSwipeActionBackground(
        context: context,
        theme: theme,
        retro: retro,
        isNothing: isNothing,
        isSatoshi: isSatoshi,
        alignment: Alignment.centerLeft,
        icon: 'queue',
        label: 'ADD TO QUEUE',
      ),
      secondaryBackground: _buildSwipeActionBackground(
        context: context,
        theme: theme,
        retro: retro,
        isNothing: isNothing,
        isSatoshi: isSatoshi,
        alignment: Alignment.centerRight,
        icon: 'skip_next',
        label: 'PLAY NEXT',
      ),
      child: tileContent,
    );
  }

  Widget _buildSwipeActionBackground({
    required BuildContext context,
    required ThemeData theme,
    required dynamic retro,
    required bool isNothing,
    required bool isSatoshi,
    required Alignment alignment,
    required String icon,
    required String label,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isNothing
            ? context.nothing.surfaceContainer.withValues(alpha: 0.7)
            : retro.cardColor,
        border: isNothing
            ? null
            : Border.all(
                color: retro.borderColor.withValues(alpha: 0.4),
                width: 1.0,
              ),
        borderRadius: isNothing ? BorderRadius.circular(10) : BorderRadius.zero,
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLeft) ...[
            RetroIcon(icon, size: 18, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: isNothing
                  ? TextStyle(
                      fontFamily: 'GeistMono',
                      color: primaryColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    )
                  : isSatoshi
                      ? TextStyle(
                          fontFamily: 'Satoshi',
                          color: primaryColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )
                      : RetroTypography.pixelBadge(
                          color: primaryColor,
                          fontSize: 10,
                        ),
            ),
          ] else ...[
            Text(
              label,
              style: isNothing
                  ? TextStyle(
                      fontFamily: 'GeistMono',
                      color: primaryColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    )
                  : isSatoshi
                      ? TextStyle(
                          fontFamily: 'Satoshi',
                          color: primaryColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        )
                      : RetroTypography.pixelBadge(
                          color: primaryColor,
                          fontSize: 10,
                        ),
            ),
            const SizedBox(width: 8),
            RetroIcon(icon, size: 18, color: primaryColor),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required String label,
    required String icon,
    required ThemeData theme,
    Color? textColor,
    Color? iconColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          RetroIcon(
            icon,
            size: 15,
            color: iconColor ?? theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: RetroTypography.pixelBadge(
              color: textColor ?? theme.colorScheme.onSurface,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final libraryState = ref.read(libraryProvider);

    switch (action) {
      case 'play_next':
        playerNotifier.addNext(song);
        RetroToast.show(
          context,
          'PLAYING NEXT: ${song.title.toUpperCase()}',
          icon: 'skip_next',
        );
        break;
      case 'add_queue':
        playerNotifier.addToQueue(song);
        RetroToast.show(
          context,
          'ADDED TO QUEUE: ${song.title.toUpperCase()}',
          icon: 'queue',
        );
        break;
      case 'add_playlist':
        _showAddToPlaylistDialog(context, ref);
        break;
      case 'go_album':
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.popUntil((route) => route.isFirst);
        }
        ref.read(homeTabProvider.notifier).openAlbum(song.album);
        break;
      case 'go_artist':
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.popUntil((route) => route.isFirst);
        }
        ref.read(homeTabProvider.notifier).openArtist(song.artist);
        break;
      case 'toggle_favorite':
        final isCurrentlyFav = libraryState.allSongs
            .firstWhere((s) => s.id == song.id, orElse: () => song)
            .isFavorite;
        ref.read(libraryProvider.notifier).toggleFavorite(song.id);
        RetroToast.show(
          context,
          isCurrentlyFav ? 'REMOVED FROM FAVORITES' : 'ADDED TO FAVORITES',
          icon: isCurrentlyFav ? 'heart' : 'heart_filled',
          iconColor: isCurrentlyFav ? null : RetroColors.picoRed,
        );
        break;
      case 'remove_playlist':
        onRemoveFromPlaylist?.call();
        break;
    }
  }

  void _showAddToPlaylistDialog(BuildContext context, WidgetRef ref) {
    showAddToPlaylistDialog(context, ref, song);
  }

  static void showAddToPlaylistDialog(BuildContext context, WidgetRef ref, Song song) {
    final playlists = ref.read(playlistProvider).playlists;
    final libraryState = ref.read(libraryProvider);
    final retro = context.retro;
    final theme = Theme.of(context);

    if (playlists.isEmpty) {
      CreatePlaylistModal.show(
        context,
        initialSong: song,
        isInitialEmptyPrompt: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: retro.cardColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: retro.borderColor, width: 2.5),
          borderRadius: BorderRadius.zero,
        ),
        title: Row(
          children: [
            const RetroIcon('folder', size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ADD TO PLAYLIST',
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    border: Border.all(color: retro.borderColor, width: 1.5),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Center(
                    child: RetroIcon('plus', size: 16, color: Colors.white),
                  ),
                ),
                title: Text(
                  'CREATE NEW PLAYLIST',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.primary,
                    fontSize: 10,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(dialogCtx);
                  await CreatePlaylistModal.show(context, initialSong: song);
                },
              ),
              Divider(color: retro.borderColor.withValues(alpha: 0.4), height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, idx) {
                    final pl = playlists[idx];
                    final coverArt = pl.resolveArtPath(libraryState.allSongs);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: coverArt != null
                          ? RetroAlbumArt(
                              artPath: coverArt,
                              title: pl.name,
                              width: 36,
                              height: 36,
                              borderWidth: 1.5,
                              borderColor: retro.borderColor,
                            )
                          : Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: retro.accentYellow,
                                border: Border.all(color: retro.borderColor, width: 1.5),
                                borderRadius: BorderRadius.zero,
                              ),
                              child: const Center(
                                child: RetroIcon('music', size: 16, color: Colors.black),
                              ),
                            ),
                      title: Text(
                        pl.name,
                        style: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface,
                          fontSize: 10,
                        ),
                      ),
                      subtitle: Text(
                        '${pl.getValidSongCount(libraryState.allSongs, isLoading: libraryState.isLoading)} tracks',
                        style: RetroTypography.retroMono(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      onTap: () async {
                        await ref
                            .read(playlistProvider.notifier)
                            .addSongToPlaylist(pl.id, song.id);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          RetroToast.show(
                            context,
                            'ADDED TO ${pl.name.toUpperCase()}',
                            icon: 'plus',
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          RetroButton(
            isCompact: true,
            label: 'CANCEL',
            backgroundColor: retro.cardColor,
            textColor: theme.colorScheme.onSurface,
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }
}
