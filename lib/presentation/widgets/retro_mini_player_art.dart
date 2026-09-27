import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../domain/models/song.dart';
import '../providers/mini_player_settings_provider.dart';
import '../providers/player_provider.dart';
import 'retro_album_art.dart';
import 'retro_cassette_art.dart';

/// Renders classic boxed retro album art, animated grooved vinyl record disc,
/// or an authentic 8-bit cassette tape with spinning spools, adhering to user settings.
class RetroMiniPlayerArt extends ConsumerStatefulWidget {
  final Song song;
  final double size;

  const RetroMiniPlayerArt({
    super.key,
    required this.song,
    this.size = 44,
  });

  @override
  ConsumerState<RetroMiniPlayerArt> createState() => _RetroMiniPlayerArtState();
}

class _RetroMiniPlayerArtState extends ConsumerState<RetroMiniPlayerArt>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isPlaying = ref.read(playerProvider).isPlaying;
      final settings = ref.read(miniPlayerArtSettingsProvider);
      final shouldRotate = (settings.style == MiniPlayerArtStyle.vinyl ||
              settings.style == MiniPlayerArtStyle.cassette) &&
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

  void _syncAnimation(bool isPlaying, bool isRotating, MiniPlayerArtStyle style) {
    final shouldRotate = (style == MiniPlayerArtStyle.vinyl ||
            style == MiniPlayerArtStyle.cassette) &&
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
    final settings = ref.watch(miniPlayerArtSettingsProvider);

    // Listen to changes and adjust animation accordingly
    ref.listen<bool>(
      playerProvider.select((s) => s.isPlaying),
      (prev, playing) {
        final curSettings = ref.read(miniPlayerArtSettingsProvider);
        _syncAnimation(playing, curSettings.isRotating, curSettings.style);
      },
    );

    ref.listen<MiniPlayerArtSettings>(
      miniPlayerArtSettingsProvider,
      (prev, newSettings) {
        final playing = ref.read(playerProvider).isPlaying;
        _syncAnimation(playing, newSettings.isRotating, newSettings.style);
      },
    );

    final retro = context.retro;
    final theme = Theme.of(context);

    Widget artWidget;

    if (settings.style == MiniPlayerArtStyle.box) {
      artWidget = RetroAlbumArt(
        artPath: widget.song.artPath,
        title: widget.song.title,
        artist: widget.song.artist,
        width: widget.size,
        height: widget.size,
        borderWidth: 2.0,
        borderColor: retro.borderColor,
        backgroundColor: retro.cardColor,
        placeholderIconSize: 20,
        placeholderColor: theme.colorScheme.primary,
      );
    } else if (settings.style == MiniPlayerArtStyle.cassette) {
      artWidget = RetroCassetteArt(
        song: widget.song,
        width: widget.size,
        height: widget.size,
        rotationAnimation: settings.isRotating ? _rotationController : null,
        isMini: true,
      );
    } else {

    // 8-Bit Stepped Pixel Vinyl Record appearance
    final discSize = widget.size;
    final spindleSize = (discSize * (2.5 / 24.0)).clamp(4.0, 7.0);

    Widget vinylDisc = SizedBox(
      width: discSize,
      height: discSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Outer 8-bit stepped pixel vinyl disc body
          ClipPath(
            clipper: const RetroPixelPathClipper(radiusRatio: 10.5 / 12.0),
            child: Container(
              width: discSize,
              height: discSize,
              color: const Color(0xFF0D0F14),
            ),
          ),

          // 2. Outer 8-bit stepped vinyl groove
          CustomPaint(
            size: Size(discSize, discSize),
            painter: RetroPixelPathPainter(
              radiusRatio: 9.2 / 12.0,
              color: Colors.white.withValues(alpha: 0.14),
              strokeWidth: 1.0,
            ),
          ),

          // 3. Inner 8-bit stepped vinyl groove
          CustomPaint(
            size: Size(discSize, discSize),
            painter: RetroPixelPathPainter(
              radiusRatio: 7.8 / 12.0,
              color: Colors.white.withValues(alpha: 0.09),
              strokeWidth: 1.0,
            ),
          ),

          // 4. Center Cover Art Label clipped to 8-bit stepped pixel circle
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
                  placeholderIconSize: 14,
                  placeholderColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),

          // 5. 8-Bit stepped pixel border around the center Cover Art Label
          CustomPaint(
            size: Size(discSize, discSize),
            painter: RetroPixelPathPainter(
              radiusRatio: 6.5 / 12.0,
              color: retro.borderColor,
              strokeWidth: 1.5,
            ),
          ),

          // 6. Outer 8-bit stepped pixel disc border
          CustomPaint(
            size: Size(discSize, discSize),
            painter: RetroPixelPathPainter(
              radiusRatio: 10.5 / 12.0,
              color: retro.borderColor,
              strokeWidth: 1.5,
            ),
          ),

          // 7. Center 8-bit square spindle hole (zero border radius)
          Container(
            width: spindleSize,
            height: spindleSize,
            decoration: BoxDecoration(
              color: const Color(0xFF14161E),
              border: Border.all(
                color: Colors.white54,
                width: 1.0,
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
      duration: const Duration(milliseconds: 200),
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
        key: ValueKey('mini_player_art_${widget.song.id}_${widget.song.artPath}'),
        child: artWidget,
      ),
    );
  }
}

/// Custom clipper that cuts out an authentic 8-bit stepped pixel circle.
class RetroPixelPathClipper extends CustomClipper<Path> {
  final double radiusRatio;
  final int gridSize;

  const RetroPixelPathClipper({
    required this.radiusRatio,
    this.gridSize = 24,
  });

  @override
  Path getClip(Size size) {
    return buildPixelCirclePath(size, radiusRatio: radiusRatio, gridSize: gridSize);
  }

  @override
  bool shouldReclip(covariant RetroPixelPathClipper oldClipper) {
    return oldClipper.radiusRatio != radiusRatio || oldClipper.gridSize != gridSize;
  }
}

/// Custom painter for drawing sharp, authentic 8-bit stepped pixel contours and borders.
class RetroPixelPathPainter extends CustomPainter {
  final double radiusRatio;
  final int gridSize;
  final Color color;
  final double strokeWidth;
  final PaintingStyle style;

  const RetroPixelPathPainter({
    required this.radiusRatio,
    required this.color,
    this.gridSize = 24,
    this.strokeWidth = 1.5,
    this.style = PaintingStyle.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildPixelCirclePath(size, radiusRatio: radiusRatio, gridSize: gridSize);
    final paint = Paint()
      ..color = color
      ..style = style
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = false;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant RetroPixelPathPainter oldDelegate) {
    return oldDelegate.radiusRatio != radiusRatio ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.style != style ||
        oldDelegate.gridSize != gridSize;
  }
}

/// Generates a closed stepped polygon Path for an 8-bit pixel circle on a discrete grid.
Path buildPixelCirclePath(
  Size size, {
  required double radiusRatio,
  int gridSize = 24,
}) {
  if (size.width <= 0 || size.height <= 0) return Path();

  final double u = size.width / gridSize;
  final double c = gridSize / 2.0;
  final double r = (gridSize / 2.0) * radiusRatio;

  final path = Path();
  final List<List<int>> spans = [];

  for (int y = 0; y < gridSize; y++) {
    int start = -1;
    int end = -1;
    for (int x = 0; x < gridSize; x++) {
      final double dx = (x + 0.5) - c;
      final double dy = (y + 0.5) - c;
      if (dx * dx + dy * dy <= r * r) {
        if (start == -1) start = x;
        end = x;
      }
    }
    if (start != -1) {
      spans.add([y, start, end]);
    }
  }

  if (spans.isEmpty) return path;

  // Start at top-left of first pixel row
  path.moveTo(spans.first[1] * u, spans.first[0] * u);
  path.lineTo((spans.first[2] + 1) * u, spans.first[0] * u);

  // Trace right edge going downwards
  for (int i = 0; i < spans.length; i++) {
    final y = spans[i][0];
    final endX = (spans[i][2] + 1) * u;
    final nextY = (y + 1) * u;

    path.lineTo(endX, y * u);
    path.lineTo(endX, nextY);

    if (i + 1 < spans.length) {
      final nextEndX = (spans[i + 1][2] + 1) * u;
      path.lineTo(nextEndX, nextY);
    }
  }

  // Bottom edge of last row
  path.lineTo(spans.last[1] * u, (spans.last[0] + 1) * u);

  // Trace left edge going upwards
  for (int i = spans.length - 1; i >= 0; i--) {
    final y = spans[i][0];
    final startX = spans[i][1] * u;
    final prevY = y * u;

    path.lineTo(startX, (y + 1) * u);
    path.lineTo(startX, prevY);

    if (i - 1 >= 0) {
      final prevStartX = spans[i - 1][1] * u;
      path.lineTo(prevStartX, prevY);
    }
  }

  path.close();
  return path;
}
