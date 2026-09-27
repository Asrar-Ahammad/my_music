import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../domain/models/song.dart';
import '../providers/mini_player_settings_provider.dart';
import '../providers/now_playing_settings_provider.dart';
import '../providers/player_provider.dart';
import 'retro_album_art.dart';
import 'retro_cassette_art.dart';
import 'retro_mini_player_art.dart';

/// A morphing album art widget that continuously enlarges and shrinks between
/// MiniPlayer thumbnail size and NowPlayingScreen full size on swipe gestures,
/// seamlessly handling Box, Vinyl, Cassette, and mixed style transitions with synchronized rotation.
class MorphingAlbumArt extends ConsumerStatefulWidget {
  final Song song;
  final double progress; // 0.0 (collapsed mini) to 1.0 (expanded full)
  final double miniSize;
  final double fullSize;

  const MorphingAlbumArt({
    super.key,
    required this.song,
    required this.progress,
    this.miniSize = 44.0,
    required this.fullSize,
  });

  @override
  ConsumerState<MorphingAlbumArt> createState() => _MorphingAlbumArtState();
}

class _MorphingAlbumArtState extends ConsumerState<MorphingAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateRotation();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _updateRotation() {
    final isPlaying = ref.read(playerProvider).isPlaying;
    final miniSettings = ref.read(miniPlayerArtSettingsProvider);
    final fullSettings = ref.read(nowPlayingArtSettingsProvider);

    final isMiniRotating = (miniSettings.style == MiniPlayerArtStyle.vinyl ||
            miniSettings.style == MiniPlayerArtStyle.cassette) &&
        miniSettings.isRotating;
    final isFullRotating = (fullSettings.style == NowPlayingArtStyle.vinyl ||
            fullSettings.style == NowPlayingArtStyle.cassette) &&
        fullSettings.isRotating;
    final shouldRotate = isPlaying && (isMiniRotating || isFullRotating);

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

  Widget _buildBoxArt(ThemeData theme, dynamic retro, double size, double borderWidth, double progress) {
    final placeholderSize = (size * (0.35 - 0.03 * progress)).clamp(18.0 + 30.0 * progress, 96.0);
    return RetroAlbumArt(
      artPath: widget.song.artPath,
      title: widget.song.title,
      artist: widget.song.artist,
      width: size,
      height: size,
      borderWidth: borderWidth,
      borderColor: retro.borderColor,
      backgroundColor: retro.cardColor,
      placeholderIconSize: placeholderSize,
      placeholderColor: theme.colorScheme.primary,
    );
  }

  Widget _buildVinylDisc(ThemeData theme, dynamic retro, double size, bool isRotating, double progress) {
    final spindleSize = (size * ((2.4 - 0.2 * progress) / 24.0)).clamp(4.5 + 9.5 * progress, 6.0 + 20.0 * progress);
    final centerRatio = (6.5 + 0.3 * progress) / 12.0;
    final centerBorderWidth = 1.6 + 0.2 * progress;

    final disc = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Outer 8-bit stepped pixel vinyl body
          ClipPath(
            clipper: const RetroPixelPathClipper(radiusRatio: 10.5 / 12.0),
            child: Container(
              width: size,
              height: size,
              color: const Color(0xFF0D0F14),
            ),
          ),

          // 2. Grooves: dynamically blends from 2 mini grooves to 4 rich NowPlaying grooves
          if (progress < 0.6)
            Opacity(
              opacity: (1.0 - (progress - 0.3) / 0.3).clamp(0.0, 1.0),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: RetroPixelPathPainter(
                      radiusRatio: 9.2 / 12.0,
                      color: Colors.white.withValues(alpha: 0.14),
                      strokeWidth: 1.0,
                    ),
                  ),
                  CustomPaint(
                    size: Size(size, size),
                    painter: RetroPixelPathPainter(
                      radiusRatio: 7.8 / 12.0,
                      color: Colors.white.withValues(alpha: 0.09),
                      strokeWidth: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          if (progress > 0.3)
            Opacity(
              opacity: ((progress - 0.3) / 0.3).clamp(0.0, 1.0),
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(size, size),
                    painter: RetroPixelPathPainter(
                      radiusRatio: 9.7 / 12.0,
                      color: Colors.white.withValues(alpha: 0.12),
                      strokeWidth: 1.5,
                    ),
                  ),
                  CustomPaint(
                    size: Size(size, size),
                    painter: RetroPixelPathPainter(
                      radiusRatio: 9.0 / 12.0,
                      color: Colors.white.withValues(alpha: 0.08),
                      strokeWidth: 1.5,
                    ),
                  ),
                  CustomPaint(
                    size: Size(size, size),
                    painter: RetroPixelPathPainter(
                      radiusRatio: 8.3 / 12.0,
                      color: Colors.white.withValues(alpha: 0.11),
                      strokeWidth: 1.5,
                    ),
                  ),
                  CustomPaint(
                    size: Size(size, size),
                    painter: RetroPixelPathPainter(
                      radiusRatio: 7.6 / 12.0,
                      color: Colors.white.withValues(alpha: 0.07),
                      strokeWidth: 1.5,
                    ),
                  ),
                ],
              ),
            ),

          // 3. Center album art label
          ClipPath(
            clipper: RetroPixelPathClipper(radiusRatio: centerRatio),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: RetroAlbumArt(
                  artPath: widget.song.artPath,
                  title: widget.song.title,
                  artist: widget.song.artist,
                  width: size,
                  height: size,
                  borderWidth: 0,
                  backgroundColor: retro.cardColor,
                  placeholderIconSize: (size * 0.22).clamp(14.0 + 10.0 * progress, 64.0),
                  placeholderColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          // 4. Border around center label
          CustomPaint(
            size: Size(size, size),
            painter: RetroPixelPathPainter(
              radiusRatio: centerRatio,
              color: retro.borderColor,
              strokeWidth: centerBorderWidth,
            ),
          ),

          // 5. Outer disc border
          CustomPaint(
            size: Size(size, size),
            painter: RetroPixelPathPainter(
              radiusRatio: 10.5 / 12.0,
              color: retro.borderColor,
              strokeWidth: 2.0,
            ),
          ),

          // 6. Center spindle hole
          Container(
            width: spindleSize,
            height: spindleSize,
            decoration: BoxDecoration(
              color: const Color(0xFF14161E),
              border: Border.all(
                color: Colors.white60,
                width: 1.0,
              ),
            ),
          ),
        ],
      ),
    );

    if (isRotating) {
      return RotationTransition(
        turns: _rotationController,
        child: disc,
      );
    }

    return disc;
  }

  Widget _buildCassetteArt(double size, bool isRotating) {
    return RetroCassetteArt(
      song: widget.song,
      width: size,
      height: size,
      rotationAnimation: isRotating ? _rotationController : null,
      isMini: size < 120,
    );
  }

  Widget _buildArtForStyle({
    required dynamic style,
    required ThemeData theme,
    required dynamic retro,
    required double size,
    required double borderWidth,
    required bool isRotating,
    required double progress,
  }) {
    if (style == MiniPlayerArtStyle.box || style == NowPlayingArtStyle.box) {
      return _buildBoxArt(theme, retro, size, borderWidth, progress);
    } else if (style == MiniPlayerArtStyle.vinyl || style == NowPlayingArtStyle.vinyl) {
      return _buildVinylDisc(theme, retro, size, isRotating, progress);
    } else {
      return _buildCassetteArt(size, isRotating);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final miniSettings = ref.watch(miniPlayerArtSettingsProvider);
    final fullSettings = ref.watch(nowPlayingArtSettingsProvider);
    final isPlaying = ref.watch(playerProvider.select((s) => s.isPlaying));

    final isMiniRotating = (miniSettings.style == MiniPlayerArtStyle.vinyl ||
            miniSettings.style == MiniPlayerArtStyle.cassette) &&
        miniSettings.isRotating;
    final isFullRotating = (fullSettings.style == NowPlayingArtStyle.vinyl ||
            fullSettings.style == NowPlayingArtStyle.cassette) &&
        fullSettings.isRotating;
    final isRotating = isPlaying && (isMiniRotating || isFullRotating);

    if (isRotating && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isRotating && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    final p = widget.progress.clamp(0.0, 1.0);
    final currentSize = widget.miniSize + (widget.fullSize - widget.miniSize) * p;

    final borderWidth = 2.0 + (3.0 - 2.0) * p;

    final miniStyle = miniSettings.style;
    final fullStyle = fullSettings.style;

    if (miniStyle.name == fullStyle.name) {
      return SizedBox(
        width: currentSize,
        height: currentSize,
        child: _buildArtForStyle(
          style: miniStyle,
          theme: theme,
          retro: retro,
          size: currentSize,
          borderWidth: borderWidth,
          isRotating: isRotating,
          progress: p,
        ),
      );
    }

    // Mixed styles: Cross-fade smoothly between mini style and full style
    final fullOpacity = p.clamp(0.0, 1.0);
    final miniOpacity = 1.0 - fullOpacity;

    return SizedBox(
      width: currentSize,
      height: currentSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (miniOpacity > 0.01)
            Opacity(
              opacity: miniOpacity,
              child: _buildArtForStyle(
                style: miniStyle,
                theme: theme,
                retro: retro,
                size: currentSize,
                borderWidth: borderWidth,
                isRotating: isRotating,
                progress: p,
              ),
            ),
          if (fullOpacity > 0.01)
            Opacity(
              opacity: fullOpacity,
              child: _buildArtForStyle(
                style: fullStyle,
                theme: theme,
                retro: retro,
                size: currentSize,
                borderWidth: borderWidth,
                isRotating: isRotating,
                progress: p,
              ),
            ),
        ],
      ),
    );
  }
}
