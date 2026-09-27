import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';

/// Tag/badge component for 8-bit retro arcade design.
class RetroBadge extends StatelessWidget {
  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final Widget? icon;

  const RetroBadge({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.fontSize = 8.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
  });

  @override
  Widget build(BuildContext context) {
    final retro = context.retro;

    final bg = backgroundColor ?? retro.cardColor;
    final isBgLight = bg.computeLuminance() > 0.4;
    Color txt;
    if (textColor != null) {
      if (textColor!.computeLuminance() > 0.8 && isBgLight) {
        txt = const Color(0xFF0F0E0E);
      } else if (textColor!.computeLuminance() < 0.2 && !isBgLight) {
        txt = Theme.of(context).colorScheme.onSurface;
      } else {
        txt = textColor!;
      }
    } else {
      txt = isBgLight
          ? const Color(0xFF0F0E0E)
          : Theme.of(context).colorScheme.onSurface;
    }
    final bColor = borderColor ??
        (isBgLight ? const Color(0xFF222222) : retro.borderColor);

    final badgeStyle = RetroTypography.pixelBadge(
      color: txt,
      fontSize: fontSize,
    );

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: bColor,
          width: 1.5,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: icon == null
          ? Text(
              text,
              style: badgeStyle,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon!,
                const SizedBox(width: 4),
                Text(
                  text,
                  style: badgeStyle,
                ),
              ],
            ),
    );
  }
}
