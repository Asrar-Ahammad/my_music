import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';

/// Container adapting to active design system: chunky 2.5px border, zero elevation, sharp corners.
class RetroCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? titleTrailing;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderWidth;
  final double? borderRadius;

  const RetroCard({
    super.key,
    required this.child,
    this.title,
    this.titleTrailing,
    this.backgroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.borderWidth = 2.5,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    final bg = backgroundColor ?? theme.cardColor;
    final bColor = borderColor ?? retro.borderColor;
    final effectiveRadius = BorderRadius.circular(borderRadius ?? 0.0);

    Widget body = child;

    if (title != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border(
                bottom: BorderSide(
                  color: bColor,
                  width: borderWidth,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ?titleTrailing,
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      );
    } else {
      body = Padding(
        padding: padding,
        child: child,
      );
    }

    final container = Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(
          color: bColor,
          width: borderWidth,
        ),
        borderRadius: effectiveRadius,
      ),
      child: body,
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}
