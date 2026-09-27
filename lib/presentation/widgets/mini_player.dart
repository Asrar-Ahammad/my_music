import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../providers/font_provider.dart';
import '../providers/player_provider.dart';
import '../screens/home_scaffold.dart';
import '../screens/now_playing/now_playing_screen.dart';

import 'retro_button.dart';
import 'retro_icon.dart';
import 'retro_marquee_text.dart';
import 'retro_mini_player_art.dart';
import 'retro_toast.dart';
import 'shuffle_options_sheet.dart';

class MiniPlayer extends ConsumerWidget {
  final VoidCallback? onTap;
  final void Function(DragUpdateDetails)? onVerticalDragUpdate;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final bool hideCoverArt;

  const MiniPlayer({
    super.key,
    this.onTap,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.hideCoverArt = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final activeFont = ref.watch(fontProvider);
    final isSatoshi = RetroTypography.isSatoshi(activeFont);
    final currentSong = playerState.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    final retro = context.retro;
    final theme = Theme.of(context);

    final totalMs = playerState.duration.inMilliseconds > 0
        ? playerState.duration.inMilliseconds
        : 1;
    final curMs = playerState.position.inMilliseconds.clamp(0, totalMs);
    final progress = (curMs / totalMs).clamp(0.0, 1.0);


    final titleStyle = isSatoshi
        ? TextStyle(
            fontFamily: 'Satoshi',
            color: theme.colorScheme.onSurface,
            fontSize: 15.0,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.15,
          )
        : RetroTypography.pixelBadge(
            color: theme.colorScheme.onSurface,
            fontSize: 10,
          );

    final artistStyle = isSatoshi
        ? TextStyle(
            fontFamily: 'Satoshi',
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          )
        : RetroTypography.retroMono(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 13,
          );


    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (onTap != null) {
          onTap!();
          return;
        }
        final home = HomeScaffold.of(context);
        if (home != null) {
          home.expandNowPlaying();
        } else {
          NowPlayingScreen.showBottomSheet(context);
        }
      },
      onVerticalDragUpdate: (details) {
        if (onVerticalDragUpdate != null) {
          onVerticalDragUpdate!(details);
          return;
        }
        final home = HomeScaffold.of(context);
        if (home != null) {
          home.handleDragUpdate(details.primaryDelta ?? 0);
        }
      },
      onVerticalDragEnd: (details) {
        if (onVerticalDragEnd != null) {
          onVerticalDragEnd!(details);
          return;
        }
        final home = HomeScaffold.of(context);
        if (home != null) {
          home.handleDragEnd(details.primaryVelocity ?? 0);
        } else {
          if ((details.primaryVelocity ?? 0) < -80) {
            NowPlayingScreen.showBottomSheet(context);
          }
        }
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
        ),
        child: Column(
          children: [
            // Top progress bar (solid 2.5px height)
            SizedBox(
              height: 3,
              width: double.infinity,
              child: Stack(
                children: [
                  Container(color: retro.cardColor),
                  // AnimatedContainer interpolates width between position ticks
                  // for smooth 120Hz progress without visible jumps.
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.linear,
                    width: MediaQuery.of(context).size.width * progress,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Opacity(
                      opacity: hideCoverArt ? 0.0 : 1.0,
                      child: RetroMiniPlayerArt(
                        song: currentSong,
                        size: 44,
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Song Title & Artist + Quality Badge
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: RetroMarqueeText(
                                  text: currentSong.title,
                                  style: titleStyle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentSong.artist,
                            style: artistStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Shuffle Play button
                    RetroButton(
                      padding: const EdgeInsets.all(7),
                      backgroundColor: playerState.isShuffle
                          ? theme.colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderColor: playerState.isShuffle
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      onPressed: () {
                        ref.read(playerProvider.notifier).toggleShuffle();
                        final isNowOn = !playerState.isShuffle;
                        RetroToast.show(
                          context,
                          isNowOn ? 'SHUFFLE: ON' : 'SHUFFLE: OFF',
                          icon: 'shuffle',
                          iconColor: isNowOn ? theme.colorScheme.primary : Colors.white,
                        );
                      },
                      onLongPress: () {
                        ShuffleOptionsSheet.show(context);
                      },
                      child: RetroIcon(
                        'shuffle',
                        size: 18,
                        color: playerState.isShuffle
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Play/Pause button
                    RetroButton(
                      padding: const EdgeInsets.all(7),
                      backgroundColor: theme.colorScheme.primary,
                      borderColor: theme.colorScheme.primary,
                      onPressed: () {
                        ref.read(playerProvider.notifier).togglePlayPause();
                      },
                      child: RetroIcon(
                        playerState.isPlaying ? 'pause' : 'play',
                        size: 18,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Skip Next button
                    RetroButton(
                      padding: const EdgeInsets.all(7),
                      backgroundColor: Colors.transparent,
                      borderColor: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                      onPressed: () {
                        ref.read(playerProvider.notifier).skipToNext();
                      },
                      child: RetroIcon(
                        'skip_next',
                        size: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
