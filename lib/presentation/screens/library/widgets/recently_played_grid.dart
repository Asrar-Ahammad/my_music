import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/retro_theme.dart';
import '../../../../core/theme/retro_typography.dart';
import '../../../../domain/models/album.dart';
import '../../../../domain/models/artist.dart';
import '../../../../domain/models/playlist.dart';
import '../../../../domain/models/recently_played_item.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../../providers/recently_played_provider.dart';
import '../../../widgets/retro_album_art.dart';
import '../../../widgets/retro_icon.dart';
import '../album_detail_screen.dart';
import '../artist_detail_screen.dart';
import '../../home_scaffold.dart';
import '../../../providers/navigation_provider.dart';

class RecentlyPlayedGrid extends ConsumerWidget {
  const RecentlyPlayedGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentItems = ref.watch(recentlyPlayedProvider);
    final playlistState = ref.watch(playlistProvider);
    final existingPlaylistIds = playlistState.playlists.map((p) => p.id.toLowerCase()).toSet();
    final existingPlaylistNames = playlistState.playlists.map((p) => p.name.toLowerCase()).toSet();

    final validRecentItems = recentItems.where((item) {
      if (item.type == RecentItemType.playlist) {
        return existingPlaylistIds.contains(item.id.toLowerCase()) ||
            existingPlaylistNames.contains(item.title.toLowerCase());
      }
      return true;
    }).toList();

    if (validRecentItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = validRecentItems.take(8).toList();
    final theme = Theme.of(context);
    final retro = context.retro;
    final isNothing = context.isNothingTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNothing ? Colors.transparent : retro.cardColor.withValues(alpha: 0.5),
        border: isNothing
            ? null
            : Border(
                bottom: BorderSide(
                  color: retro.borderColor,
                  width: retro.borderWidth,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RetroIcon('history', size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'RECENTLY PLAYED',
                style: isNothing
                    ? NothingTypography.label(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ).copyWith(fontSize: 11)
                    : RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface,
                        fontSize: 10,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 52,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return _RecentQuickTile(item: item);
            },
          ),
        ],
      ),
    );
  }
}

class _RecentQuickTile extends ConsumerWidget {
  final RecentlyPlayedItem item;

  const _RecentQuickTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final isNothing = context.isNothingTheme;

    Color badgeColor;
    switch (item.type) {
      case RecentItemType.album:
        badgeColor = theme.colorScheme.primary;
        break;
      case RecentItemType.artist:
        badgeColor = isNothing ? context.nothing.borderSubtle : retro.accentYellow;
        break;
      case RecentItemType.playlist:
        badgeColor = isNothing ? context.nothing.surfaceContainer : retro.accentGreen;
        break;
    }

    return InkWell(
      onTap: () => _navigateToDetail(context, ref),
      borderRadius: isNothing ? BorderRadius.circular(context.nothing.borderRadius) : null,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isNothing ? context.nothing.cardColor : retro.cardColor,
          border: Border.all(
            color: isNothing
                ? context.nothing.borderColor.withValues(alpha: 0.3)
                : retro.borderColor,
            width: isNothing ? 0.5 : retro.borderWidth,
          ),
          borderRadius: isNothing
              ? BorderRadius.circular(context.nothing.borderRadius)
              : BorderRadius.zero,
        ),
        clipBehavior: isNothing ? Clip.antiAlias : Clip.none,
        child: Row(
          children: [
            // Left thumbnail
            SizedBox(
              width: 50,
              height: 50,
              child: _buildThumbnail(ref),
            ),
            Container(
              width: isNothing ? 0.5 : retro.borderWidth,
              color: isNothing
                  ? context.nothing.borderColor.withValues(alpha: 0.3)
                  : retro.borderColor,
            ),
            // Title & type
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isNothing
                          ? NothingTypography.label(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            )
                          : RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 8.5,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            border: isNothing
                                ? null
                                : Border.all(
                                    color: retro.borderColor,
                                    width: 1.0,
                                  ),
                            borderRadius: isNothing
                                ? BorderRadius.circular(999)
                                : BorderRadius.zero,
                          ),
                          child: Text(
                            item.type.name.toUpperCase(),
                            style: isNothing
                                ? NothingTypography.tag(
                                    color: badgeColor.computeLuminance() > 0.4
                                        ? Colors.black
                                        : Colors.white,
                                  ).copyWith(fontSize: 7.5, fontWeight: FontWeight.w700)
                                : RetroTypography.pixelBadge(
                                    color: badgeColor.computeLuminance() > 0.4
                                        ? Colors.black
                                        : Colors.white,
                                    fontSize: 6.5,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Right play arrow
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: RetroIcon(
                'play',
                size: 11,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(WidgetRef ref) {
    String? effectiveArt = item.artUri;
    if ((effectiveArt == null || effectiveArt.trim().isEmpty) &&
        item.type == RecentItemType.playlist) {
      final playlists = ref.watch(playlistProvider).playlists;
      final playlist = playlists.where(
        (p) => p.id == item.id || p.name.toLowerCase() == item.title.toLowerCase(),
      ).firstOrNull;
      if (playlist != null) {
        final librarySongs = ref.watch(libraryProvider).allSongs;
        effectiveArt = playlist.resolveArtPath(librarySongs);
      }
    }

    return RetroAlbumArt(
      artPath: effectiveArt,
      title: item.title,
      artist: item.subtitle,
      width: 50,
      height: 50,
      borderWidth: 0,
    );
  }

  void _navigateToDetail(BuildContext context, WidgetRef ref) {
    switch (item.type) {
      case RecentItemType.album:
        final albums = ref.read(libraryProvider).albums;
        final album = albums.firstWhere(
          (a) =>
              a.title.toLowerCase() == item.title.toLowerCase() ||
              a.title.toLowerCase() == item.id.toLowerCase(),
          orElse: () => Album(
            title: item.title,
            artist: item.subtitle,
            songs: [],
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlbumDetailScreen(album: album),
          ),
        );
        break;

      case RecentItemType.artist:
        final artists = ref.read(libraryProvider).artists;
        final artist = artists.firstWhere(
          (a) =>
              a.name.toLowerCase() == item.title.toLowerCase() ||
              a.name.toLowerCase() == item.id.toLowerCase(),
          orElse: () => Artist(
            name: item.title,
            songs: [],
          ),
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ArtistDetailScreen(artist: artist),
          ),
        );
        break;

      case RecentItemType.playlist:
        final isFavorites = item.id == 'favorites_system' ||
            item.title.toLowerCase() == 'favorites';
        Playlist playlist;
        if (isFavorites) {
          final libraryState = ref.read(libraryProvider);
          playlist = Playlist(
            id: 'favorites_system',
            name: 'Favorites',
            songIds: libraryState.favoriteSongs.map((s) => s.id).toList(),
            createdAt: DateTime.now(),
            isSystem: true,
          );
        } else {
          final playlists = ref.read(playlistProvider).playlists;
          playlist = playlists.firstWhere(
            (p) =>
                p.id.toLowerCase() == item.id.toLowerCase() ||
                p.name.toLowerCase() == item.title.toLowerCase(),
            orElse: () => Playlist(
              id: item.id,
              name: item.title,
              songIds: [],
              createdAt: DateTime.now(),
            ),
          );
        }

        final homeScaffold = HomeScaffold.of(context);
        if (homeScaffold != null) {
          homeScaffold.openPlaylist(playlist, isFavorites: isFavorites);
        } else {
          ref.read(homeTabProvider.notifier).openPlaylist(
                playlist,
                isFavorites: isFavorites,
              );
        }
        break;
    }
  }
}
