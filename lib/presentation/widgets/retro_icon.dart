import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders crisp Pixelarticons SVGs for the retro 8-bit arcade theme.
class RetroIcon extends StatelessWidget {
  final String iconName; // e.g. 'play', 'pause', 'skip_next'
  final Color? color;
  final double size;

  const RetroIcon(
    this.iconName, {
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final inheritedColor = iconTheme.color;
    final effectiveColor = color ?? inheritedColor ?? Theme.of(context).colorScheme.onSurface;

    return SvgPicture.asset(
      'assets/icons/$iconName.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        effectiveColor,
        BlendMode.srcIn,
      ),
    );
  }
}
