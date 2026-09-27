import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_badge.dart';
import 'retro_icon.dart';

/// An 8-bit retro arcade loading and scanning indicator.
class RetroLoadingState extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? badgeText;
  final bool isCompact;

  const RetroLoadingState({
    super.key,
    this.title = 'FETCHING FROM STORAGE...',
    this.subtitle = 'SCANNING AUDIO FILES & EXTRACTING METADATA',
    this.badgeText = 'PLEASE WAIT',
    this.isCompact = false,
  });

  @override
  State<RetroLoadingState> createState() => _RetroLoadingStateState();
}

class _RetroLoadingStateState extends State<RetroLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    if (widget.isCompact) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final step = (_controller.value * 4).floor() / 4.0;
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: AlwaysStoppedAnimation(step),
                  child: RetroIcon(
                    'refresh',
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.primary,
                    fontSize: 8.5,
                  ),
                ),
                const SizedBox(width: 10),
                _buildSegmentedBar(theme, retro, 5, size: 8),
              ],
            ),
          );
        },
      );
    }

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final step = (_controller.value * 4).floor() / 4.0;
            return Container(
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: retro.cardColor,
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.zero,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    offset: const Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.badgeText != null) ...[
                    RetroBadge(
                      text: widget.badgeText!,
                      backgroundColor: theme.colorScheme.primary,
                      textColor: theme.colorScheme.onPrimary,
                      fontSize: 8.5,
                    ),
                    const SizedBox(height: 16),
                  ],
                  RotationTransition(
                    turns: AlwaysStoppedAnimation(step),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Center(
                        child: RetroIcon(
                          'disc',
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: RetroTypography.pixelHeader(
                      color: theme.colorScheme.onSurface,
                      fontSize: 12.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSegmentedBar(theme, retro, 8, size: 14),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSegmentedBar(
    ThemeData theme,
    RetroThemeTokens retro,
    int totalSegments, {
    double size = 12,
  }) {
    final activeIndex = (_controller.value * totalSegments).floor() % totalSegments;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSegments, (index) {
        final isFilled = index <= activeIndex;
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: isFilled ? theme.colorScheme.primary : retro.cardColor,
            border: Border.all(
              color: isFilled ? theme.colorScheme.primary : retro.borderColor,
              width: 1.5,
            ),
            borderRadius: BorderRadius.zero,
          ),
        );
      }),
    );
  }
}
