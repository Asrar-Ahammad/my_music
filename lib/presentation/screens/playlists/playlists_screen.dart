import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../domain/models/playlist.dart';
import '../../providers/library_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/create_playlist_modal.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../home_scaffold.dart';
import '../../../data/services/storage_service.dart';
import '../settings/settings_screen.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends ConsumerStatefulWidget {
  final bool isActive;

  const PlaylistsScreen({
    super.key,
    this.isActive = true,
  });

  @override
  ConsumerState<PlaylistsScreen> createState() => PlaylistsScreenState();
}

class PlaylistsScreenState extends ConsumerState<PlaylistsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasOpenedEmptyPrompt = false;
  Playlist? _selectedPlaylist;
  bool _selectedIsFavorites = false;

  bool get canPop => _selectedPlaylist != null || _selectedIsFavorites;

  void popToRoot() {
    if (_selectedPlaylist != null) {
      setState(() {
        _selectedPlaylist = null;
        _selectedIsFavorites = false;
      });
    }
  }

  void openPlaylist(Playlist playlist, {bool isFavorites = false}) {
    setState(() {
      _selectedPlaylist = playlist;
      _selectedIsFavorites = isFavorites;
    });
  }

  @override
  void initState() {
    super.initState();
    final initialNav = ref.read(openPlaylistRequestProvider);
    if (initialNav != null) {
      _selectedPlaylist = initialNav.playlist;
      _selectedIsFavorites = initialNav.isFavorites;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(openPlaylistRequestProvider) != null) {
          ref.read(openPlaylistRequestProvider.notifier).clear();
        }
      });
    }
    if (widget.isActive) {
      _checkAndPromptEmptyPlaylists();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlaylistsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the user just navigated back to this screen
    if (widget.isActive && !oldWidget.isActive) {
      _checkAndPromptEmptyPlaylists();
    } else if (!widget.isActive) {
      // Reset prompt state so next time user enters the tab, it will prompt if still empty
      _hasOpenedEmptyPrompt = false;
    }
  }

  void _checkAndPromptEmptyPlaylists() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive || _selectedPlaylist != null) return;
      final playlists = ref.read(playlistProvider).playlists;
      if (playlists.isEmpty && !_hasOpenedEmptyPrompt) {
        _hasOpenedEmptyPrompt = true;
        _openCreateModal(isInitialEmptyPrompt: true);
      }
    });
  }

  Future<void> _openCreateModal({bool isInitialEmptyPrompt = false}) async {
    final newPlaylist = await CreatePlaylistModal.show(
      context,
      isInitialEmptyPrompt: isInitialEmptyPrompt,
    );
    if (newPlaylist != null && mounted) {
      setState(() {
        _selectedPlaylist = newPlaylist;
        _selectedIsFavorites = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PlaylistNavigationTarget?>(openPlaylistRequestProvider, (prev, next) {
      if (next != null) {
        setState(() {
          _selectedPlaylist = next.playlist;
          _selectedIsFavorites = next.isFavorites;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ref.read(openPlaylistRequestProvider) != null) {
            ref.read(openPlaylistRequestProvider.notifier).clear();
          }
        });
      }
    });

    final playlistState = ref.watch(playlistProvider);
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final retro = context.retro;
    final isNothing = context.isNothingTheme;

    final playlists = playlistState.playlists;
    final favoriteCount = libraryState.favoriteSongs.length;
    final favoriteCoverArt = libraryState.favoriteSongs
        .where((s) => s.artPath != null && s.artPath!.trim().isNotEmpty)
        .firstOrNull
        ?.artPath;
    final isGridView = ref.watch(playlistViewModeProvider);

    if (_selectedPlaylist != null) {
      if (_selectedIsFavorites) {
        final favoritesPlaylist = Playlist(
          id: 'favorites_system',
          name: 'Favorites',
          songIds: libraryState.favoriteSongs.map((s) => s.id).toList(),
          createdAt: DateTime.now(),
          isSystem: true,
        );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final home = HomeScaffold.of(context);
            if ((home != null && home.isNowPlayingExpanded) ||
                StorageService().isNowPlayingDrawerOpen()) {
              return;
            }
            setState(() {
              _selectedPlaylist = null;
              _selectedIsFavorites = false;
            });
          },
          child: PlaylistDetailScreen(
            playlist: favoritesPlaylist,
            isFavorites: true,
            onBack: () {
              setState(() {
                _selectedPlaylist = null;
                _selectedIsFavorites = false;
              });
            },
          ),
        );
      } else {
        final playlistIndex = playlists.indexWhere((p) =>
            p.id.toLowerCase() == _selectedPlaylist!.id.toLowerCase() ||
            p.name.toLowerCase() == _selectedPlaylist!.name.toLowerCase());
        final effectivePlaylist =
            playlistIndex != -1 ? playlists[playlistIndex] : _selectedPlaylist!;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final home = HomeScaffold.of(context);
            if ((home != null && home.isNowPlayingExpanded) ||
                StorageService().isNowPlayingDrawerOpen()) {
              return;
            }
            setState(() {
              _selectedPlaylist = null;
              _selectedIsFavorites = false;
            });
          },
          child: PlaylistDetailScreen(
            playlist: effectivePlaylist,
            isFavorites: false,
            onBack: () {
              setState(() {
                _selectedPlaylist = null;
                _selectedIsFavorites = false;
              });
            },
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PLAYLISTS',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
        actions: [
          IconButton(
            icon: RetroIcon('settings', size: 20, color: theme.colorScheme.onSurface),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: RetroButton(
        key: const ValueKey('playlists_new_playlist_fab'),
        icon: RetroIcon('plus', size: 18, color: theme.colorScheme.onPrimary),
        backgroundColor: theme.colorScheme.primary,
        textColor: theme.colorScheme.onPrimary,
        borderColor: retro.borderColor,
        borderWidth: retro.borderWidth,
        padding: const EdgeInsets.all(14),
        onPressed: () => _openCreateModal(isInitialEmptyPrompt: playlists.isEmpty),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Preset "FAVORITES" playlist card
                RetroCard(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: theme.colorScheme.surface,
                  borderColor: theme.colorScheme.primary,
                  onTap: () {
                    setState(() {
                      _selectedPlaylist = Playlist(
                        id: 'favorites_system',
                        name: 'Favorites',
                        songIds: libraryState.favoriteSongs.map((s) => s.id).toList(),
                        createdAt: DateTime.now(),
                        isSystem: true,
                      );
                      _selectedIsFavorites = true;
                    });
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          border: isNothing ? null : Border.all(color: retro.borderColor, width: 2.0),
                          borderRadius: isNothing ? BorderRadius.circular(context.nothing.borderRadiusSmall) : BorderRadius.zero,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: favoriteCoverArt != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  RetroAlbumArt(
                                    artPath: favoriteCoverArt,
                                    title: 'Favorites',
                                    width: 48,
                                    height: 48,
                                    borderWidth: 0,
                                  ),
                                  Container(
                                    color: Colors.black.withValues(alpha: 0.35),
                                  ),
                                  Center(
                                    child: RetroIcon(
                                      'heart_filled',
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: RetroIcon(
                                  'heart_filled',
                                  size: 24,
                                  color: theme.colorScheme.primary.computeLuminance() > 0.4
                                      ? RetroColors.picoRed
                                      : Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FAVORITE TRACKS',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Starred & Liked Chiptunes',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      RetroBadge(
                        text: '$favoriteCount TRACKS',
                        backgroundColor: theme.colorScheme.primary,
                        textColor: theme.colorScheme.onPrimary,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Header with View Toggle (LIST | GRID)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'MY PLAYLISTS (${playlists.length})',
                        style: RetroTypography.pixelHeader(
                          color: theme.colorScheme.onSurface,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    // LIST / GRID toggle buttons
                    Row(
                      children: [
                        RetroButton(
                          isCompact: true,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          backgroundColor: !isGridView
                              ? theme.colorScheme.primary
                              : retro.cardColor,
                          borderColor: !isGridView
                              ? theme.colorScheme.primary
                              : retro.borderColor,
                          icon: RetroIcon(
                            'list',
                            size: 13,
                            color: !isGridView
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                          textColor: !isGridView
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          onPressed: () {
                            ref.read(playlistViewModeProvider.notifier).setGridView(false);
                          },
                        ),
                        const SizedBox(width: 4),
                        RetroButton(
                          isCompact: true,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                          backgroundColor: isGridView
                              ? theme.colorScheme.primary
                              : retro.cardColor,
                          borderColor: isGridView
                              ? theme.colorScheme.primary
                              : retro.borderColor,
                          icon: RetroIcon(
                            'grid',
                            size: 13,
                            color: isGridView
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                          textColor: isGridView
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                          onPressed: () {
                            ref.read(playlistViewModeProvider.notifier).setGridView(true);
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                if (playlists.isEmpty)
                  RetroCard(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: retro.cardColor,
                    borderColor: retro.borderColor,
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: retro.accentYellow,
                            border: Border.all(color: retro.borderColor, width: 2.0),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: const Center(
                            child: RetroIcon('folder', size: 28, color: Colors.black),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'NO CUSTOM PLAYLISTS YET',
                          textAlign: TextAlign.center,
                          style: RetroTypography.pixelHeader(
                            color: theme.colorScheme.onSurface,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first custom playlist to group your favorite 8-bit chiptunes!',
                          textAlign: TextAlign.center,
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        RetroButton(
                          label: 'CREATE FIRST PLAYLIST',
                          icon: RetroIcon('plus', size: 14, color: theme.colorScheme.onPrimary),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          onPressed: () => _openCreateModal(isInitialEmptyPrompt: true),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ),

          if (playlists.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
              sliver: isGridView
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final playlist = playlists[index];
                          final coverArt = playlist.resolveArtPath(libraryState.allSongs);
                          final songCount = playlist.getValidSongCount(
                            libraryState.allSongs,
                            isLoading: libraryState.isLoading,
                          );

                          return RetroCard(
                            padding: const EdgeInsets.all(8),
                            onTap: () {
                              setState(() {
                                _selectedPlaylist = playlist;
                                _selectedIsFavorites = false;
                              });
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cover Art or Retro Icon Box
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isNothing ? context.nothing.surfaceContainer : retro.cardColor,
                                      border: isNothing ? null : Border.all(color: retro.borderColor, width: 2.0),
                                      borderRadius: isNothing ? BorderRadius.circular(context.nothing.borderRadius) : BorderRadius.zero,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: (coverArt != null && coverArt.trim().isNotEmpty)
                                        ? RetroAlbumArt(
                                            artPath: coverArt,
                                            title: playlist.name,
                                            width: double.infinity,
                                            height: double.infinity,
                                            borderWidth: 0,
                                            placeholderIconSize: 36,
                                          )
                                        : Center(
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: isNothing ? context.nothing.surfaceContainer : retro.accentYellow,
                                                border: isNothing ? null : Border.all(color: retro.borderColor, width: 2.0),
                                                borderRadius: isNothing ? BorderRadius.circular(context.nothing.borderRadiusSmall) : BorderRadius.zero,
                                              ),
                                              child: Center(
                                                child: RetroIcon('music', size: 22, color: isNothing ? theme.colorScheme.onSurface : Colors.black),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  playlist.name,
                                  style: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    RetroBadge(
                                      text: '$songCount SONGS',
                                      fontSize: 7.5,
                                      backgroundColor: retro.cardColor,
                                      textColor: theme.colorScheme.onSurface,
                                    ),
                                    Text(
                                      '${playlist.createdAt.month}/${playlist.createdAt.day}',
                                      style: RetroTypography.retroMono(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: playlists.length,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final playlist = playlists[index];
                          final coverArt = playlist.resolveArtPath(libraryState.allSongs);
                          final songCount = playlist.getValidSongCount(
                            libraryState.allSongs,
                            isLoading: libraryState.isLoading,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RetroCard(
                              padding: const EdgeInsets.all(12),
                              onTap: () {
                                setState(() {
                                  _selectedPlaylist = playlist;
                                  _selectedIsFavorites = false;
                                });
                              },
                              child: Row(
                                children: [
                                  (coverArt != null && coverArt.trim().isNotEmpty)
                                      ? RetroAlbumArt(
                                          artPath: coverArt,
                                          title: playlist.name,
                                          width: 44,
                                          height: 44,
                                          borderWidth: isNothing ? 0.0 : 1.5,
                                          borderColor: retro.borderColor,
                                        )
                                      : Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isNothing ? context.nothing.surfaceContainer : retro.accentYellow,
                                            border: isNothing ? null : Border.all(color: retro.borderColor, width: 2.0),
                                            borderRadius: isNothing ? BorderRadius.circular(context.nothing.borderRadiusSmall) : BorderRadius.zero,
                                          ),
                                          child: Center(
                                            child: RetroIcon('music', size: 20, color: isNothing ? theme.colorScheme.onSurface : Colors.black),
                                          ),
                                        ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          playlist.name,
                                          style: RetroTypography.pixelBadge(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Created ${playlist.createdAt.month}/${playlist.createdAt.day}/${playlist.createdAt.year}',
                                          style: RetroTypography.retroMono(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  RetroBadge(
                                    text: '$songCount SONGS',
                                    backgroundColor: retro.cardColor,
                                    textColor: theme.colorScheme.onSurface,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: playlists.length,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}

