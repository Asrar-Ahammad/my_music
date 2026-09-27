import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../providers/font_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_toast.dart';

class QueueSheet extends ConsumerStatefulWidget {
  const QueueSheet({super.key});

  /// Opens the queue bottom drawer
  static Future<void> showAsDrawer(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const QueueSheet(),
    );
  }

  @override
  ConsumerState<QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<QueueSheet> {
  late final ScrollController _scrollController;
  bool _isDismissing = false;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // After the first layout, compute the true item height from the scroll
    // position and jump instantly to the current song. The bottom sheet's
    // slide-in animation (~300ms) means this jump happens before the list
    // is fully visible — no scroll animation is ever seen by the user.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final currentIndex = ref.read(playerProvider).currentIndex;
      if (currentIndex <= 0) return;

      final position = _scrollController.position;
      final queueLength = ref.read(playerProvider).queue.length;
      if (queueLength <= 1) return;

      // Derive exact item height from the rendered content dimensions.
      // totalContentHeight = maxScrollExtent + viewportDimension
      // All items share the same structure so average == per-item height.
      final totalContent = position.maxScrollExtent + position.viewportDimension;
      final itemHeight = totalContent / queueLength;
      final offset = (currentIndex * itemHeight)
          .clamp(0.0, position.maxScrollExtent);

      _scrollController.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissing || _isReordering || !mounted) return;
    _isDismissing = true;
    Navigator.of(context).pop();
  }

  Future<void> _confirmClearQueue(BuildContext context, PlayerNotifier playerNotifier) async {
    final theme = Theme.of(context);
    final retro = context.retro;
    final isNothing = context.isNothingTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: isNothing ? BorderRadius.circular(12) : BorderRadius.zero,
            side: isNothing
                ? BorderSide(color: context.nothing.borderSubtle, width: 0.5)
                : BorderSide(color: retro.borderColor, width: 2.0),
          ),
          contentPadding: const EdgeInsets.all(16),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isNothing ? context.nothing.accent : RetroColors.picoRed,
                  border: isNothing ? null : Border.all(color: retro.borderColor, width: 2.0),
                  borderRadius: isNothing ? BorderRadius.circular(6) : BorderRadius.zero,
                ),
                child: const Center(
                  child: RetroIcon('trash', size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CLEAR QUEUE?',
                  style: RetroTypography.pixelHeader(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to clear all tracks from the queue?',
                style: RetroTypography.retroMono(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isNothing ? context.nothing.surfaceContainer : retro.cardColor,
                  border: isNothing
                      ? Border.all(color: context.nothing.borderSubtle, width: 0.5)
                      : Border.all(color: retro.borderColor, width: 1.5),
                  borderRadius: isNothing ? BorderRadius.circular(6) : BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    const RetroIcon('info', size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The queue will be emptied.',
                        style: RetroTypography.retroMono(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            RetroButton(
              isCompact: true,
              label: 'CANCEL',
              backgroundColor: isNothing ? context.nothing.surfaceContainer : retro.cardColor,
              textColor: theme.colorScheme.onSurface,
              borderColor: isNothing ? context.nothing.borderSubtle : retro.borderColor,
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            RetroButton(
              isCompact: true,
              label: 'CLEAR',
              backgroundColor: isNothing ? context.nothing.accent : RetroColors.picoRed,
              textColor: Colors.white,
              borderColor: isNothing ? context.nothing.accent : retro.borderColor,
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _dismiss();
      playerNotifier.clearQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final activeFont = ref.watch(fontProvider);
    final isSatoshi = RetroTypography.isSatoshi(activeFont);
    final playerNotifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    final queue = playerState.queue;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: context.isNothingTheme
            ? Border(
                top: BorderSide(
                  color: context.nothing.borderSubtle,
                  width: 0.5,
                ),
              )
            : Border(
                top: BorderSide(color: retro.borderColor, width: 2.5),
                left: BorderSide(color: retro.borderColor, width: 2.0),
                right: BorderSide(color: retro.borderColor, width: 2.0),
              ),
        borderRadius: context.isNothingTheme
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.zero,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Drag Handle (swipeable & tappable affordance)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! > 4) {
                _dismiss();
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 50) {
                _dismiss();
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.isNothingTheme
                        ? context.nothing.borderSubtle
                        : retro.borderColor.withValues(alpha: 0.6),
                    borderRadius: context.isNothingTheme
                        ? BorderRadius.circular(999)
                        : BorderRadius.zero,
                  ),
                ),
              ),
            ),
          ),

          // Header Section with swipe-down detector
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! > 4) {
                _dismiss();
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null && details.primaryVelocity! > 50) {
                _dismiss();
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Queue Title & Tracks Badge
                Row(
                  children: [
                    RetroIcon('queue', size: 18, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.isNothingTheme ? 'Playback Queue' : 'PLAYBACK QUEUE',
                        style: context.isNothingTheme
                            ? NothingTypography.headline(
                                color: theme.colorScheme.onSurface,
                                fontSize: 16,
                              )
                            : RetroTypography.pixelHeader(
                                color: theme.colorScheme.onSurface,
                                fontSize: 10,
                              ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RetroBadge(
                      text: '${queue.length} TRACKS',
                      backgroundColor: theme.colorScheme.primary,
                      textColor: theme.colorScheme.onPrimary,
                      fontSize: 7.5,
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    ),
                  ],
                ),
                if (queue.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // Actions Row: Up Next label + Shuffle & Clear buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          'UP NEXT',
                          style: context.isNothingTheme
                              ? NothingTypography.tag(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                )
                              : RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontSize: 8.0,
                                ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RetroButton(
                        isCompact: true,
                        fontSize: context.isNothingTheme ? 9.0 : 8.0,
                        padding: context.isNothingTheme
                            ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5)
                            : const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        label: playerState.isShuffle ? 'SHUFFLE ON' : 'SHUFFLE',
                        icon: RetroIcon(
                          'shuffle',
                          size: 11,
                          color: playerState.isShuffle
                              ? (context.isNothingTheme ? Colors.white : Colors.black)
                              : theme.colorScheme.onSurface,
                        ),
                        backgroundColor: playerState.isShuffle
                            ? (context.isNothingTheme ? theme.colorScheme.primary : retro.accentYellow)
                            : (context.isNothingTheme ? context.nothing.surfaceContainer : retro.cardColor),
                        textColor: playerState.isShuffle
                            ? (context.isNothingTheme ? Colors.white : Colors.black)
                            : theme.colorScheme.onSurface,
                        borderColor: playerState.isShuffle
                            ? (context.isNothingTheme ? theme.colorScheme.primary : retro.accentYellow)
                            : (context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor),
                        onPressed: () {
                          playerNotifier.toggleShuffle();
                        },
                      ),
                      SizedBox(width: context.isNothingTheme ? 5 : 4),
                      RetroButton(
                        isCompact: true,
                        fontSize: context.isNothingTheme ? 9.0 : 8.0,
                        padding: context.isNothingTheme
                            ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5)
                            : const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        label: 'RESHUFFLE',
                        icon: RetroIcon(
                          'refresh',
                          size: 11,
                          color: theme.colorScheme.onSurface,
                        ),
                        backgroundColor: context.isNothingTheme
                            ? context.nothing.surfaceContainer
                            : retro.cardColor,
                        textColor: theme.colorScheme.onSurface,
                        borderColor: context.isNothingTheme
                            ? context.nothing.borderSubtle
                            : retro.borderColor,
                        onPressed: queue.length > 1
                            ? () {
                                playerNotifier.reshuffleQueue();
                                RetroToast.show(
                                  context,
                                  'QUEUE RESHUFFLED',
                                  icon: 'shuffle',
                                );
                              }
                            : null,
                      ),
                      SizedBox(width: context.isNothingTheme ? 5 : 4),
                      RetroButton(
                        isCompact: true,
                        fontSize: context.isNothingTheme ? 9.0 : 8.0,
                        padding: context.isNothingTheme
                            ? const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5)
                            : const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        label: 'CLEAR',
                        backgroundColor: context.isNothingTheme
                            ? context.nothing.surfaceContainer
                            : retro.cardColor,
                        textColor: theme.colorScheme.onSurface,
                        borderColor: context.isNothingTheme
                            ? context.nothing.borderSubtle
                            : retro.borderColor,
                        onPressed: () => _confirmClearQueue(context, playerNotifier),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),
          Container(
            height: context.isNothingTheme ? 0.5 : 2,
            color: context.isNothingTheme ? context.nothing.borderSubtle : retro.borderColor,
          ),
          const SizedBox(height: 8),

          Expanded(
            child: queue.isEmpty
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: (details) {
                      if (details.primaryDelta != null && details.primaryDelta! > 4) {
                        _dismiss();
                      }
                    },
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! > 50) {
                        _dismiss();
                      }
                    },
                    child: Center(
                      child: Text(
                        'QUEUE IS EMPTY',
                        style: RetroTypography.pixelHeader(
                          color: theme.colorScheme.onSurface,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (_isReordering) return false;
                      if (notification is OverscrollNotification) {
                        if (notification.overscroll < -8) {
                          _dismiss();
                          return true;
                        }
                      } else if (notification is ScrollEndNotification) {
                        final velocity =
                            notification.dragDetails?.primaryVelocity ?? 0;
                        if (velocity > 120 && notification.metrics.pixels <= 0) {
                          _dismiss();
                          return true;
                        }
                      }
                      return false;
                    },
                    child: ReorderableListView.builder(
                      scrollController: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      itemCount: queue.length,
                      onReorderStart: (index) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _isReordering = true;
                        });
                      },
                      onReorderEnd: (index) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isReordering = false;
                        });
                      },
                      onReorderItem: (oldIdx, newIdx) {
                        HapticFeedback.lightImpact();
                        playerNotifier.reorderQueue(oldIdx, newIdx);
                      },
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrent = (playerState.currentSong != null &&
                                (song.id == playerState.currentSong!.id ||
                                    (song.uri.isNotEmpty && song.uri == playerState.currentSong!.uri))) ||
                            (index == playerState.currentIndex && playerState.currentIndex >= 0);
                        final isUserQueued = !isCurrent &&
                            index > playerState.currentIndex &&
                            index <= playerState.currentIndex + playerState.userQueueCount;

                        return Container(
                          key: ValueKey('${song.id}_$index'),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? (context.isNothingTheme
                                    ? context.nothing.accent.withValues(alpha: 0.12)
                                    : theme.colorScheme.primary.withValues(alpha: 0.15))
                                : (context.isNothingTheme
                                    ? context.nothing.surfaceContainer
                                    : retro.cardColor),
                            border: Border.all(
                              color: isCurrent
                                  ? (context.isNothingTheme
                                      ? context.nothing.accent
                                      : theme.colorScheme.primary)
                                  : (context.isNothingTheme
                                      ? context.nothing.borderSubtle
                                      : retro.borderColor),
                              width: context.isNothingTheme ? 0.5 : 2.0,
                            ),
                            borderRadius: context.isNothingTheme
                                ? BorderRadius.circular(10)
                                : BorderRadius.zero,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${index + 1}'.padLeft(2, '0'),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: context.isNothingTheme
                                        ? NothingTypography.mono(
                                            color: isCurrent
                                                ? context.nothing.accent
                                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          )
                                        : RetroTypography.pixelBadge(
                                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                            fontSize: 10,
                                          ),
                                  ),
                                  if (isCurrent && playerState.isPlaying) ...[
                                    const SizedBox(width: 6),
                                    RetroIcon(
                                      'play',
                                      size: 14,
                                      color: context.isNothingTheme ? context.nothing.accent : theme.colorScheme.primary,
                                    ),
                                  ],
                                ],
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      song.title,
                                      style: context.isNothingTheme
                                          ? NothingTypography.title(
                                              color: isCurrent
                                                  ? context.nothing.accent
                                                  : theme.colorScheme.onSurface,
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                            )
                                          : isSatoshi
                                              ? TextStyle(
                                                  fontFamily: 'Satoshi',
                                                  color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                                  fontSize: 15.0,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.15,
                                                )
                                              : RetroTypography.pixelBadge(
                                                  color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                                  fontSize: 10,
                                                ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isUserQueued) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (context.isNothingTheme ? context.nothing.accent : theme.colorScheme.primary).withValues(alpha: 0.15),
                                        border: Border.all(
                                          color: (context.isNothingTheme ? context.nothing.accent : theme.colorScheme.primary).withValues(alpha: 0.6),
                                          width: 0.8,
                                        ),
                                        borderRadius: context.isNothingTheme ? BorderRadius.circular(4) : BorderRadius.zero,
                                      ),
                                      child: Text(
                                        'QUEUED',
                                        style: TextStyle(
                                          fontSize: 8.0,
                                          fontWeight: FontWeight.w700,
                                          color: context.isNothingTheme ? context.nothing.accent : theme.colorScheme.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${song.artist} • ${DurationFormatter.format(song.duration)}',
                                  style: context.isNothingTheme
                                      ? NothingTypography.label(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                          fontSize: 12.0,
                                        )
                                      : isSatoshi
                                          ? TextStyle(
                                              fontFamily: 'Satoshi',
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 0.1,
                                            )
                                          : RetroTypography.retroMono(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                              fontSize: 12,
                                            ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    iconSize: 16,
                                    icon: const RetroIcon('trash', size: 16),
                                    onPressed: () => playerNotifier.removeQueueAt(index),
                                  ),
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      child: RetroIcon('drag_handle', size: 18),
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                playerNotifier.playAtIndex(index);
                              },
                            ),
                          ),
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
