import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../domain/models/song.dart';
import '../providers/now_playing_settings_provider.dart';
import '../providers/player_provider.dart';
import 'retro_album_art.dart';
import 'retro_cassette_art.dart';
import 'retro_mini_player_art.dart';

/// Renders either a classic boxed retro album art frame, an animated 8-bit
/// stepped pixel vinyl record disc, or an authentic retro cassette tape for
/// the Now Playing screen, adhering to user settings.
class RetroNowPlayingArt extends ConsumerStatefulWidget {
  final Song song;
  final double size;

  const RetroNowPlayingArt({
    super.key,
    required this.song,
    required this.size,
  });

  @override
  ConsumerState<RetroNowPlayingArt> createState() => _RetroNowPlayingArtState();
}

class _RetroNowPlayingArtState extends ConsumerState<RetroNowPlayingArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPlaying = ref.read(playerProvider).isPlaying;
      final settings = ref.read(nowPlayingArtSettingsProvider);
      final shouldRotate = (settings.style == NowPlayingArtStyle.vinyl ||
              settings.style == NowPlayingArtStyle.cassette) &&
          settings.isRotating &&
          isPlaying;
      if (shouldRotate) {
        _rotationController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _syncAnimation(
    bool isPlaying,
    bool isRotating,
    NowPlayingArtStyle style,
  ) {
    final shouldRotate = (style == NowPlayingArtStyle.vinyl ||
            style == NowPlayingArtStyle.cassette) &&
        isRotating &&
        isPlaying;
    if (shouldRotate) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(nowPlayingArtSettingsProvider);

    // Synchronize rotation with playback and settings
    ref.listen<bool>(
      playerProvider.select((s) => s.isPlaying),
      (prev, playing) {
        final curSettings = ref.read(nowPlayingArtSettingsProvider);
        _syncAnimation(playing, curSettings.isRotating, curSettings.style);
      },
    );

    ref.listen<NowPlayingArtSettings>(
      nowPlayingArtSettingsProvider,
      (prev, newSettings) {
        final playing = ref.read(playerProvider).isPlaying;
        _syncAnimation(playing, newSettings.isRotating, newSettings.style);
      },
    );

    final retro = context.retro;
    final theme = Theme.of(context);

    Widget artWidget;

    if (settings.style == NowPlayingArtStyle.box) {
      // 1. Box Mode: Classic framed retro album art
      artWidget = RetroAlbumArt(
        artPath: widget.song.artPath,
        title: widget.song.title,
        artist: widget.song.artist,
        width: widget.size,
        height: widget.size,
        borderWidth: 3.0,
        borderColor: retro.borderColor,
        backgroundColor: retro.cardColor,
        placeholderIconSize: (widget.size * 0.32).clamp(48.0, 96.0),
        placeholderColor: theme.colorScheme.primary,
      );
    } else if (settings.style == NowPlayingArtStyle.cassette) {
      // 2. Cassette Mode: Authentic retro cassette tape deck
      artWidget = RetroCassetteArt(
        song: widget.song,
        width: widget.size,
        height: widget.size,
        rotationAnimation: settings.isRotating ? _rotationController : null,
        isMini: false,
      );
    } else {
      // 3. Vinyl Mode: Large 8-Bit Stepped Pixel Vinyl LP Record
      final discSize = widget.size;
      final spindleSize = (discSize * (2.2 / 24.0)).clamp(14.0, 26.0);

      Widget vinylDisc = SizedBox(
        width: discSize,
        height: discSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer 8-bit stepped pixel vinyl body
            ClipPath(
              clipper: const RetroPixelPathClipper(radiusRatio: 10.5 / 12.0),
              child: Container(
                width: discSize,
                height: discSize,
                color: const Color(0xFF0D0F14),
              ),
            ),

            // Stepped concentric grooves with subtle arcade sheen
            CustomPaint(
              size: Size(discSize, discSize),
              painter: RetroPixelPathPainter(
                radiusRatio: 9.7 / 12.0,
                color: Colors.white.withValues(alpha: 0.12),
                strokeWidth: 1.5,
              ),
            ),
            CustomPaint(
              size: Size(discSize, discSize),
              painter: RetroPixelPathPainter(
                radiusRatio: 9.0 / 12.0,
                color: Colors.white.withValues(alpha: 0.08),
                strokeWidth: 1.5,
              ),
            ),
            CustomPaint(
              size: Size(discSize, discSize),
              painter: RetroPixelPathPainter(
                radiusRatio: 8.3 / 12.0,
                color: Colors.white.withValues(alpha: 0.11),
                strokeWidth: 1.5,
              ),
            ),
            CustomPaint(
              size: Size(discSize, discSize),
              painter: RetroPixelPathPainter(
                radiusRatio: 7.6 / 12.0,
                color: Colors.white.withValues(alpha: 0.07),
                strokeWidth: 1.5,
              ),
            ),

            // Center Cover Art Label clipped to 8-bit stepped pixel circle
            ClipPath(
              clipper: const RetroPixelPathClipper(radiusRatio: 6.5 / 12.0),
              child: SizedBox(
                width: discSize,
                height: discSize,
                child: Center(
                  child: RetroAlbumArt(
                    artPath: widget.song.artPath,
                    title: widget.song.title,
                    artist: widget.song.artist,
                    width: discSize,
                    height: discSize,
                    borderWidth: 0,
                    backgroundColor: retro.cardColor,
                    placeholderIconSize: (discSize * 0.22).clamp(32.0, 64.0),
                    placeholderColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),

            // 8-Bit stepped pixel border around center Cover Art Label
            CustomPaint(
              size: Size(discSize, discSize),
              painter: RetroPixelPathPainter(
                radiusRatio: 6.5 / 12.0,
                color: retro.borderColor,
                strokeWidth: 2.0,
              ),
            ),

            // Outer 8-bit stepped pixel disc border
            CustomPaint(
              size: Size(discSize, discSize),
              painter: RetroPixelPathPainter(
                radiusRatio: 10.5 / 12.0,
                color: retro.borderColor,
                strokeWidth: 2.5,
              ),
            ),

            // Center 8-bit square pixel spindle hole (zero border radius)
            Container(
              width: spindleSize,
              height: spindleSize,
              decoration: BoxDecoration(
                color: const Color(0xFF14161E),
                border: Border.all(
                  color: Colors.white60,
                  width: 1.5,
                ),
              ),
            ),
          ],
        ),
      );

      if (settings.isRotating) {
        artWidget = RotationTransition(
          turns: _rotationController,
          child: vinylDisc,
        );
      } else {
        artWidget = vinylDisc;
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey('now_playing_art_${widget.song.id}_${widget.song.artPath}'),
        child: artWidget,
      ),
    );
  }
}
