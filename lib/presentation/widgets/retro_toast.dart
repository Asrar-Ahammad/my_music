import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_icon.dart';

/// Ultra-high contrast 8-bit retro toast / snackbar component.
class RetroToast {
  RetroToast._();

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    String? icon,
    Color? iconColor,
    Color? textColor,
  }) {
    final retro = context.retro;
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: theme.brightness == Brightness.dark
            ? retro.cardColor
            : const Color(0xFF1E1A17),
        duration: duration,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: retro.borderColor,
            width: retro.borderWidth,
          ),
          borderRadius: BorderRadius.zero,
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                RetroIcon(
                  icon,
                  size: 14,
                  color: iconColor ?? theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  message.toUpperCase(),
                  style: RetroTypography.pixelBadge(
                    color: textColor ?? Colors.white,
                    fontSize: 9.5,
                  ).copyWith(height: 1.6),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
