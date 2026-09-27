import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/retro_theme.dart';
import '../../../../core/theme/retro_typography.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/retro_badge.dart';
import '../../../widgets/retro_button.dart';
import '../../../widgets/retro_card.dart';
import '../../../widgets/retro_icon.dart';
import '../../../widgets/retro_loading_state.dart';
import '../../../widgets/retro_refresh_indicator.dart';
import '../../../widgets/retro_toast.dart';
import '../../../widgets/scan_options_dialog.dart';
import '../folder_detail_screen.dart';

enum FolderSortMode { name, tracks, path }

class FoldersTab extends ConsumerStatefulWidget {
  final bool showToolbar;

  const FoldersTab({
    super.key,
    this.showToolbar = true,
  });

  @override
  ConsumerState<FoldersTab> createState() => _FoldersTabState();
}

class _FoldersTabState extends ConsumerState<FoldersTab> {
  FolderSortMode _sortMode = FolderSortMode.name;
  bool _sortAscending = true;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSortSelected(FolderSortMode mode) {
    setState(() {
      if (_sortMode == mode) {
        _sortAscending = !_sortAscending;
      } else {
        _sortMode = mode;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final rawFolders = libraryState.folders;
    final theme = Theme.of(context);
    final retro = context.retro;

    final globalSearch = ref.watch(folderSearchProvider);
    final globalSortMode = ref.watch(folderSortModeProvider);
    final globalSortAscending = ref.watch(folderSortAscendingProvider);

    final query = (!widget.showToolbar ? globalSearch : _searchController.text).trim().toLowerCase();

    // Filter folder keys
    var folderKeys = rawFolders.keys.where((folderPath) {
      if (query.isEmpty) return true;
      final folderName = folderPath.contains('/')
          ? folderPath.split('/').where((s) => s.isNotEmpty).last
          : folderPath;
      return folderName.toLowerCase().contains(query) ||
          folderPath.toLowerCase().contains(query);
    }).toList();

    final sortMode = !widget.showToolbar
        ? (globalSortMode == 'tracks'
            ? FolderSortMode.tracks
            : (globalSortMode == 'path' ? FolderSortMode.path : FolderSortMode.name))
        : _sortMode;
    final sortAscending = !widget.showToolbar ? globalSortAscending : _sortAscending;

    // Sort folder keys
    folderKeys.sort((a, b) {
      final aName = a.contains('/') ? a.split('/').where((s) => s.isNotEmpty).last : a;
      final bName = b.contains('/') ? b.split('/').where((s) => s.isNotEmpty).last : b;
      int cmp = 0;
      switch (sortMode) {
        case FolderSortMode.name:
          cmp = aName.toLowerCase().compareTo(bName.toLowerCase());
          break;
        case FolderSortMode.tracks:
          cmp = (rawFolders[a]?.length ?? 0).compareTo(rawFolders[b]?.length ?? 0);
          break;
        case FolderSortMode.path:
          cmp = a.toLowerCase().compareTo(b.toLowerCase());
          break;
      }
      return sortAscending ? cmp : -cmp;
    });

    final isFiltering = query.isNotEmpty;
    final totalCount = rawFolders.length;
    final filteredCount = folderKeys.length;

    final folderContent = RetroRefreshIndicator(
      onRefresh: () async {
        final result = await ref.read(libraryProvider.notifier).rescanLibrary();
        if (context.mounted) {
          if (result.newCount > 0) {
            RetroToast.show(
              context,
              'FOUND ${result.newCount} NEW TRACK${result.newCount == 1 ? '' : 'S'} \u2022 ${result.totalCount} TOTAL',
              icon: 'folder',
              iconColor: theme.colorScheme.secondary,
            );
          } else {
            final updatedFolders = ref.read(libraryProvider).folders;
            RetroToast.show(
              context,
              'LIBRARY UP TO DATE \u2022 ${updatedFolders.length} FOLDER${updatedFolders.length == 1 ? '' : 'S'}',
              icon: 'check',
              iconColor: context.retro.accentGreen,
            );
          }
        }
      },
      child: libraryState.isLoading && rawFolders.isEmpty
          ? const RetroLoadingState(
              title: 'SCANNING DIRECTORIES...',
              subtitle: 'INDEXING FOLDERS & AUDIO FILES FROM STORAGE',
              badgeText: 'SCANNING STORAGE',
            )
          : rawFolders.isEmpty
              ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RetroIcon('folder', size: 36, color: theme.colorScheme.secondary),
                        const SizedBox(height: 12),
                        Text(
                          'NO MUSIC FOLDERS',
                          style: RetroTypography.pixelHeader(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ADD FOLDERS TO SCAN FOR MUSIC',
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        RetroButton(
                          isCompact: true,
                          label: 'SCAN FOLDERS',
                          icon: const RetroIcon('scan', size: 12, color: Colors.black),
                          backgroundColor: retro.accentGreen,
                          textColor: Colors.black,
                          onPressed: () => ScanOptionsDialog.show(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : folderKeys.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RetroIcon('search', size: 36, color: theme.colorScheme.secondary),
                            const SizedBox(height: 12),
                            Text(
                              'NO MATCHING FOLDERS',
                              style: RetroTypography.pixelHeader(
                                color: theme.colorScheme.onSurface,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'TRY A DIFFERENT SEARCH TERM',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RetroButton(
                              isCompact: true,
                              label: 'CLEAR SEARCH',
                              icon: const RetroIcon('close', size: 12, color: Colors.white),
                              backgroundColor: theme.colorScheme.primary,
                              onPressed: () {
                                if (!widget.showToolbar) {
                                  ref.read(folderSearchProvider.notifier).state = '';
                                } else {
                                  _searchController.clear();
                                  setState(() {});
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  itemCount: folderKeys.length,
                  itemBuilder: (context, index) {
                    final folderPath = folderKeys[index];
                    final folderSongs = rawFolders[folderPath] ?? [];
                    final folderName = folderPath.contains('/')
                        ? folderPath.split('/').where((s) => s.isNotEmpty).last
                        : folderPath;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RetroCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => FolderDetailScreen(folderPath: folderPath),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: retro.accentYellow,
                                    border: Border.all(color: retro.borderColor, width: 2.0),
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  child: const Center(
                                    child: RetroIcon('folder', size: 20, color: Colors.black),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        folderName,
                                        style: RetroTypography.pixelBadge(
                                          color: theme.colorScheme.onSurface,
                                          fontSize: 10.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        folderPath,
                                        style: RetroTypography.retroMono(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 1.5,
                              color: retro.borderColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                RetroBadge(
                                  text: '${folderSongs.length} TRACKS',
                                  backgroundColor: retro.cardColor,
                                  textColor: theme.colorScheme.onSurface,
                                  fontSize: 7.5,
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    RetroButton(
                                      isCompact: true,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      backgroundColor: retro.cardColor,
                                      borderColor: retro.borderColor,
                                      icon: const RetroIcon('folder', size: 11),
                                      label: 'OPEN',
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => FolderDetailScreen(folderPath: folderPath),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 6),
                                    RetroButton(
                                      isCompact: true,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      backgroundColor: theme.colorScheme.primary,
                                      textColor: theme.colorScheme.onPrimary,
                                      icon: RetroIcon('play', size: 11, color: theme.colorScheme.onPrimary),
                                      label: 'PLAY',
                                      onPressed: () {
                                        if (folderSongs.isNotEmpty) {
                                          playerNotifier.playSong(folderSongs.first, queue: folderSongs);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );

    if (!widget.showToolbar) {
      return folderContent;
    }

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: retro.cardColor,
            border: Border(
              bottom: BorderSide(
                color: retro.borderColor,
                width: retro.borderWidth,
              ),
            ),
          ),
          child: _isSearchOpen
              ? _buildSearchBar(context, theme, retro, filteredCount, totalCount)
              : _buildNormalBar(context, theme, retro, filteredCount, totalCount, isFiltering),
        ),

        // ── Folder Content ──────────────────────────────────────────────────
        Expanded(
          child: folderContent,
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    int filteredCount,
    int totalCount,
  ) {
    return Row(
      children: [
        RetroBadge(
          text: '$filteredCount/$totalCount',
          backgroundColor: theme.colorScheme.secondary,
          textColor: theme.colorScheme.onSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 8, right: 6),
                  child: RetroIcon('search', size: 14),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.search,
                    onTapOutside: (_) => _searchFocusNode.unfocus(),
                    onSubmitted: (_) => _searchFocusNode.unfocus(),
                    onChanged: (_) => setState(() {}),
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 9.5,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      isCollapsed: true,
                      hintText: 'SEARCH FOLDERS...',
                      hintStyle: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 8.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      child: RetroIcon('close', size: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        _buildSortMenu(theme, retro),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            setState(() {
              _isSearchOpen = false;
              _searchController.clear();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border.all(color: retro.borderColor, width: 1.5),
            ),
            child: const RetroIcon('close', size: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalBar(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    int filteredCount,
    int totalCount,
    bool isFiltering,
  ) {
    return Row(
      children: [
        RetroBadge(
          text: isFiltering ? '$filteredCount/$totalCount DIRECTORIES' : '$totalCount DIRECTORIES',
          backgroundColor: theme.colorScheme.secondary,
          textColor: theme.colorScheme.onSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearchOpen = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _searchFocusNode.requestFocus();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroIcon('search', size: 13, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 4),
                          Text(
                            'SEARCH FOLDERS',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSortMenu(theme, retro),
                  const SizedBox(width: 6),
                  RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    backgroundColor: retro.accentGreen,
                    textColor: Colors.black,
                    label: 'IMPORT',
                    icon: const RetroIcon('plus', size: 13, color: Colors.black),
                    onPressed: () => ScanOptionsDialog.show(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortMenu(ThemeData theme, RetroThemeTokens retro) {
    String label;
    switch (_sortMode) {
      case FolderSortMode.name:
        label = 'NAME';
        break;
      case FolderSortMode.tracks:
        label = 'TRACKS';
        break;
      case FolderSortMode.path:
        label = 'PATH';
        break;
    }

    return PopupMenuButton<FolderSortMode>(
      tooltip: "Sort folders",
      color: retro.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: retro.borderColor, width: 2.0),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: _onSortSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: FolderSortMode.name,
          child: Text('SORT BY NAME',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: FolderSortMode.tracks,
          child: Text('SORT BY TRACKS',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: FolderSortMode.path,
          child: Text('SORT BY PATH',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: retro.borderColor, width: 1.5),
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
            const SizedBox(width: 4),
            Text(
              label,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface,
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
