import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_icon.dart';

/// Button component for 8-bit retro arcade design.
class RetroButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget? child;
  final String? label;
  final Widget? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final BoxBorder? border;
  final EdgeInsetsGeometry padding;
  final bool isCompact;
  final double borderWidth;
  final double? fontSize;
  final double? width;
  final double? height;

  const RetroButton({
    super.key,
    required this.onPressed,
    this.onLongPress,
    this.child,
    this.label,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.isCompact = false,
    this.borderWidth = 2.5,
    this.fontSize,
    this.width,
    this.height,
  }) : assert(child != null || label != null || icon != null);

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isPressed = false;
  int _lastTapDownTime = 0;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null && widget.onLongPress == null) return;
    _lastTapDownTime = DateTime.now().millisecondsSinceEpoch;
    HapticFeedback.selectionClick();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onPressed == null) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _lastTapDownTime;
    const minHold = 80;
    if (elapsed < minHold) {
      Future.delayed(Duration(milliseconds: minHold - elapsed), () {
        if (mounted) setState(() => _isPressed = false);
      });
    } else {
      setState(() => _isPressed = false);
    }
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    final isEnabled = widget.onPressed != null || widget.onLongPress != null;
    final bg = isEnabled
        ? (widget.backgroundColor ?? theme.colorScheme.primary)
        : retro.disabledColor;
    final isBgLight = bg.computeLuminance() > 0.4;
    Color textCol;
    if (widget.textColor != null) {
      if (widget.textColor!.computeLuminance() > 0.8 && isBgLight) {
        textCol = const Color(0xFF0F0E0E);
      } else if (widget.textColor!.computeLuminance() < 0.2 && !isBgLight) {
        textCol = theme.colorScheme.onSurface;
      } else {
        textCol = widget.textColor!;
      }
    } else {
      if (widget.backgroundColor != null) {
        final base = isBgLight ? const Color(0xFF0F0E0E) : theme.colorScheme.onSurface;
        textCol = isEnabled ? base : base.withValues(alpha: 0.4);
      } else {
        textCol = isEnabled ? theme.colorScheme.onPrimary : retro.cardColor;
      }
    }
    final borderCol = widget.borderColor ?? retro.borderColor;

    // Adapt icon color to match textCol and ensure contrast
    Widget? effectiveIcon = widget.icon;
    if (widget.icon != null) {
      if (widget.icon is RetroIcon) {
        final rIcon = widget.icon as RetroIcon;
        final iconC = rIcon.color;
        final shouldInherit = iconC == null ||
            iconC == widget.textColor ||
            (iconC.computeLuminance() > 0.8 && isBgLight) ||
            (iconC.computeLuminance() < 0.2 && !isBgLight);
        effectiveIcon = RetroIcon(
          rIcon.iconName,
          size: rIcon.size,
          color: shouldInherit ? textCol : iconC,
        );
      } else {
        effectiveIcon = IconTheme(
          data: IconThemeData(color: textCol),
          child: widget.icon!,
        );
      }
    }

    final effectivePadding = widget.padding == const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
        ? (widget.isCompact
            ? const EdgeInsets.only(left: 10, right: 10, top: 6.0, bottom: 8.0)
            : const EdgeInsets.only(left: 14, right: 14, top: 7.5, bottom: 12.5))
        : widget.padding;

    Widget content;
    final effectiveFontSize = widget.fontSize ?? (widget.isCompact ? 9.0 : 11.0);
    final labelStyle = RetroTypography.pixelBadge(
      color: textCol,
      fontSize: effectiveFontSize,
    ).copyWith(
      height: 1.0,
      leadingDistribution: TextLeadingDistribution.even,
    );

    if (widget.child != null) {
      content = widget.child!;
    } else if (effectiveIcon != null && widget.label != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          effectiveIcon,
          SizedBox(width: widget.isCompact ? 5 : 8),
          Flexible(
            child: Text(
              widget.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      );
    } else if (effectiveIcon != null) {
      content = effectiveIcon;
    } else {
      content = Text(
        widget.label!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: labelStyle,
      );
    }

    final transformMatrix = Matrix4.identity()
      ..translateByDouble(0.0, _isPressed ? 3.0 : 0.0, 0.0, 1.0)
      ..scaleByDouble(_isPressed ? 0.93 : 1.0, _isPressed ? 0.93 : 1.0, 1.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      onLongPress: widget.onLongPress != null
          ? () {
              setState(() => _isPressed = false);
              HapticFeedback.heavyImpact();
              widget.onLongPress!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: transformMatrix,
        width: widget.width,
        height: widget.height,
        alignment: (widget.width != null || widget.height != null)
            ? Alignment.center
            : null,
        padding: effectivePadding,
        decoration: BoxDecoration(
          color: _isPressed
              ? (isEnabled ? Color.lerp(bg, Colors.black, 0.12) : bg)
              : bg,
          border: widget.border ??
              Border.all(
                color: borderCol,
                width: widget.borderWidth,
              ),
          borderRadius: BorderRadius.zero,
        ),
        child: IconTheme(
          data: IconThemeData(
            color: textCol,
            size: widget.isCompact ? 14 : 16,
          ),
          child: content,
        ),
      ),
    );
  }
}
