import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../../domain/models/song.dart';
import 'retro_album_art.dart';

/// Renders an authentic 8-bit retro cassette tape with corner screw rivets,
/// a vintage label sticker with song album art, magnetic tape window,
/// and dual rotating cogwheel spools synchronized with playback.
class RetroCassetteArt extends StatelessWidget {
  final Song song;
  final double width;
  final double height;
  final Animation<double>? rotationAnimation;
  final bool isMini;

  const RetroCassetteArt({
    super.key,
    required this.song,
    required this.width,
    required this.height,
    this.rotationAnimation,
    this.isMini = false,
  });

  @override
  Widget build(BuildContext context) {
    final retro = context.retro;
    final theme = Theme.of(context);

    // Maintain ~1.54:1 aspect ratio inside the allocated width and height
    final targetAspect = 1.54;
    double tapeW = width;
    double tapeH = width / targetAspect;
    if (tapeH > height) {
      tapeH = height;
      tapeW = height * targetAspect;
    }

    final bool mini = isMini || tapeW < 120;
    final borderWidth = mini ? 1.5 : (retro.borderWidth.clamp(2.0, 3.0));

    final shellBg = retro.isDark
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.06),
            const Color(0xFF13161F),
          )
        : Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.08),
            retro.cardColor,
          );

    final labelBg = retro.isDark
        ? const Color(0xFF1F2432)
        : theme.colorScheme.surface;

    final bannerH = (tapeH * 0.16).clamp(8.0, 24.0);

    return Center(
      child: SizedBox(
        width: tapeW,
        height: tapeH,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Cassette Shell Body with Chamfered Corners
            ClipPath(
              clipper: _CassetteShellClipper(
                chamfer: mini ? 3.0 : 7.0,
              ),
              child: Container(
                width: tapeW,
                height: tapeH,
                color: shellBg,
              ),
            ),

            // 2. Shell Outer Pixel Border
            CustomPaint(
              size: Size(tapeW, tapeH),
              painter: _CassetteShellBorderPainter(
                borderColor: retro.borderColor,
                borderWidth: borderWidth,
                chamfer: mini ? 3.0 : 7.0,
              ),
            ),

            // 3. Four Corner Screws
            if (!mini) ...[
              _buildCornerScrew(top: 6, left: 6, retro: retro),
              _buildCornerScrew(top: 6, right: 6, retro: retro),
              _buildCornerScrew(bottom: 6, left: 6, retro: retro),
              _buildCornerScrew(bottom: 6, right: 6, retro: retro),
            ] else ...[
              _buildMiniScrew(top: 3, left: 3, retro: retro),
              _buildMiniScrew(top: 3, right: 3, retro: retro),
              _buildMiniScrew(bottom: 3, left: 3, retro: retro),
              _buildMiniScrew(bottom: 3, right: 3, retro: retro),
            ],

            // 4. Center Label Area
            Positioned(
              top: tapeH * (mini ? 0.10 : 0.09),
              left: tapeW * 0.08,
              right: tapeW * 0.08,
              height: tapeH * (mini ? 0.72 : 0.68),
              child: Container(
                decoration: BoxDecoration(
                  color: labelBg,
                  border: Border.all(
                    color: retro.borderColor,
                    width: mini ? 1.0 : 1.5,
                  ),
                  borderRadius: BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    // Top Label Header Banner
                    Container(
                      height: bannerH,
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: mini ? 3 : 6),
                        color: theme.colorScheme.primary,
                      child: Row(
                        children: [
                          if (!mini && tapeW >= 150) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: retro.borderColor,
                                borderRadius: BorderRadius.zero,
                              ),
                              child: Text(
                                'SIDE A',
                                style: RetroTypography.pixelBadge(
                                  color: retro.accentYellow,
                                  fontSize: 7.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              song.title.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onPrimary,
                                fontSize: mini ? 6.5 : 9.5,
                              ),
                            ),
                          ),
                          if (!mini && tapeW >= 180) ...[
                            const SizedBox(width: 4),
                            Text(
                              '60 MIN',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
                                fontSize: 7.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Accent stripe
                    Container(
                      height: mini ? 1.5 : 2.5,
                      width: double.infinity,
                      color: retro.accentYellow,
                    ),

                    // Label Subtitle (when space permits)
                    if (!mini && tapeH >= 110)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.artist.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                                  fontSize: 8.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'HI-FI STEREO',
                              style: RetroTypography.pixelBadge(
                                color: retro.accentGreen,
                                fontSize: 7.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Tape Window with Spools (Flexibly fills available label height)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: mini ? 4 : 8,
                          right: mini ? 4 : 8,
                          top: 2,
                          bottom: mini ? 2 : 4,
                        ),
                        child: _buildTapeWindow(
                          context: context,
                          tapeW: tapeW,
                          tapeH: tapeH,
                          mini: mini,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Bottom Trapezoid Head Opening & Rollers
            Positioned(
              bottom: 0,
              child: _buildBottomHeadSection(
                tapeW: tapeW,
                tapeH: tapeH,
                mini: mini,
                retro: retro,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerScrew({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required dynamic retro,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: retro.cardColor,
          border: Border.all(color: retro.borderColor, width: 1.0),
          borderRadius: BorderRadius.zero,
        ),
        child: Center(
          child: Container(
            width: 2,
            height: 2,
            color: retro.borderColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniScrew({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required dynamic retro,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 3,
        height: 3,
        color: retro.borderColor.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildTapeWindow({
    required BuildContext context,
    required double tapeW,
    required double tapeH,
    required bool mini,
  }) {
    final retro = context.retro;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final windowHeight = constraints.maxHeight;
        final spoolDiameter = (windowHeight * 0.78).clamp(8.0, 52.0);

        return Container(
          height: windowHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF090B10),
            border: Border.all(
              color: retro.borderColor,
              width: mini ? 1.0 : 1.5,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Dark tape ribbon connecting left and right reels
              Positioned(
                left: spoolDiameter * 0.6,
                right: spoolDiameter * 0.6,
                top: windowHeight * 0.22,
                bottom: windowHeight * 0.22,
                child: Container(
                  color: const Color(0xFF2B1F16),
                ),
              ),

              // Center clear window slit with tape marker
              if (!mini && windowHeight >= 28) ...[
                Container(
                  width: (windowHeight * 1.3).clamp(24.0, 90.0),
                  height: (windowHeight * 0.68).clamp(16.0, 50.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141824).withValues(alpha: 0.9),
                    border: Border.all(
                      color: retro.borderColor.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Center(
                    // Mini Album Art Thumbnail inside the tape window
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: RetroAlbumArt(
                        artPath: song.artPath,
                        title: song.title,
                        artist: song.artist,
                        width: (windowHeight * 0.52).clamp(12.0, 40.0),
                        height: (windowHeight * 0.52).clamp(12.0, 40.0),
                        borderWidth: 1.0,
                        borderColor: retro.borderColor,
                        backgroundColor: retro.cardColor,
                        placeholderIconSize: 10.0,
                        placeholderColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],

              // Left Reel / Spool
              Positioned(
                left: mini ? 2.0 : 8.0,
                child: _buildSpool(
                  size: spoolDiameter,
                  retro: retro,
                  theme: theme,
                  mini: mini,
                ),
              ),

              // Right Reel / Spool
              Positioned(
                right: mini ? 2.0 : 8.0,
                child: _buildSpool(
                  size: spoolDiameter,
                  retro: retro,
                  theme: theme,
                  mini: mini,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpool({
    required double size,
    required dynamic retro,
    required ThemeData theme,
    required bool mini,
  }) {
    final spoolBody = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CassetteSpoolPainter(
          spoolColor: retro.isDark ? const Color(0xFFE2E4EB) : const Color(0xFFD4D8E2),
          teethColor: theme.colorScheme.primary,
          holeColor: const Color(0xFF090B10),
          borderColor: retro.borderColor,
          mini: mini,
        ),
      ),
    );

    // Isolate spinning spool in a RepaintBoundary for optimal 60/120fps performance!
    if (rotationAnimation != null) {
      return RepaintBoundary(
        child: RotationTransition(
          turns: rotationAnimation!,
          child: spoolBody,
        ),
      );
    }

    return RepaintBoundary(child: spoolBody);
  }

  Widget _buildBottomHeadSection({
    required double tapeW,
    required double tapeH,
    required bool mini,
    required dynamic retro,
    required ThemeData theme,
  }) {
    final headW = tapeW * 0.56;
    final headH = tapeH * (mini ? 0.18 : 0.16);

    return Container(
      width: headW,
      height: headH,
      decoration: BoxDecoration(
        color: retro.isDark ? const Color(0xFF181C26) : retro.cardColor,
        border: Border(
          top: BorderSide(color: retro.borderColor, width: mini ? 1.0 : 1.5),
          left: BorderSide(color: retro.borderColor, width: mini ? 1.0 : 1.5),
          right: BorderSide(color: retro.borderColor, width: mini ? 1.0 : 1.5),
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left guide roller hole
          Container(
            width: mini ? 3 : 8,
            height: mini ? 3 : 8,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E14),
              border: Border.all(color: retro.borderColor, width: 0.8),
              borderRadius: BorderRadius.zero,
            ),
          ),

          // Center magnetic tape head pad
          Container(
            width: mini ? 10 : 28,
            height: mini ? 4 : 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.25),
              border: Border.all(color: retro.borderColor, width: 0.8),
              borderRadius: BorderRadius.zero,
            ),
          ),

          // Right guide roller hole
          Container(
            width: mini ? 3 : 8,
            height: mini ? 3 : 8,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E14),
              border: Border.all(color: retro.borderColor, width: 0.8),
              borderRadius: BorderRadius.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Clipper creating authentic 45° chamfered retro corners for the cassette shell.
class _CassetteShellClipper extends CustomClipper<Path> {
  final double chamfer;

  const _CassetteShellClipper({this.chamfer = 6.0});

  @override
  Path getClip(Size size) {
    final c = chamfer;
    return Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant _CassetteShellClipper oldClipper) =>
      oldClipper.chamfer != chamfer;
}

/// Custom Painter drawing the chamfered border for the cassette shell.
class _CassetteShellBorderPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final double chamfer;

  const _CassetteShellBorderPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.chamfer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = chamfer;
    final path = Path()
      ..moveTo(c, 0)
      ..lineTo(size.width - c, 0)
      ..lineTo(size.width, c)
      ..lineTo(size.width, size.height - c)
      ..lineTo(size.width - c, size.height)
      ..lineTo(c, size.height)
      ..lineTo(0, size.height - c)
      ..lineTo(0, c)
      ..close();

    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CassetteShellBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.chamfer != chamfer;
}

/// Custom Painter for 3-tooth or 6-tooth retro cassette spool cogwheel.
class _CassetteSpoolPainter extends CustomPainter {
  final Color spoolColor;
  final Color teethColor;
  final Color holeColor;
  final Color borderColor;
  final bool mini;

  const _CassetteSpoolPainter({
    required this.spoolColor,
    required this.teethColor,
    required this.holeColor,
    required this.borderColor,
    required this.mini,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Spool Gear Circle Body
    final bodyPaint = Paint()..color = spoolColor;
    canvas.drawCircle(center, radius - 1.0, bodyPaint);

    // Border around spool
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = mini ? 0.8 : 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 1.0, borderPaint);

    // 2. Teeth (6 cog teeth protruding inward toward center)
    final numTeeth = 6;
    final teethPaint = Paint()..color = teethColor;

    for (int i = 0; i < numTeeth; i++) {
      final angle = (i * 2 * math.pi) / numTeeth;
      final toothRadius = radius * 0.75;
      final tx = center.dx + math.cos(angle) * toothRadius;
      final ty = center.dy + math.sin(angle) * toothRadius;
      final toothSize = (radius * 0.22).clamp(1.5, 4.5);

      canvas.drawRect(
        Rect.fromCenter(center: Offset(tx, ty), width: toothSize, height: toothSize),
        teethPaint,
      );
    }

    // 3. Center Spindle Hole
    final holeRadius = radius * 0.36;
    final holePaint = Paint()..color = holeColor;
    canvas.drawCircle(center, holeRadius, holePaint);

    final holeBorder = Paint()
      ..color = borderColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, holeRadius, holeBorder);
  }

  @override
  bool shouldRepaint(covariant _CassetteSpoolPainter oldDelegate) =>
      oldDelegate.spoolColor != spoolColor ||
      oldDelegate.teethColor != teethColor ||
      oldDelegate.holeColor != holeColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.mini != mini;
}
