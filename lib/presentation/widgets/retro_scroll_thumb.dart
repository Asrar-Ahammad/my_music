import 'package:flutter/material.dart';

/// Fixed-length retro scrollbar thumb.
///
/// Unlike default Flutter scrollbars, the thumb maintains a fixed height
/// (e.g. 44px / ~half an inch) regardless of playlist length, has no background track,
/// features sharp retro edges, and supports interactive vertical dragging.
///
/// If [initialTop] is specified, the thumb's initial position (at scroll offset 0)
/// starts at [initialTop] (e.g. aligned with the first song on screen).
class RetroScrollThumb extends StatefulWidget {
  final ScrollController controller;
  final double thickness;
  final double thumbHeight;
  final Color thumbColor;
  final EdgeInsets padding;
  final double hitTargetWidth;
  final double? initialTop;

  const RetroScrollThumb({
    super.key,
    required this.controller,
    this.thickness = 4.0,
    this.thumbHeight = 44.0,
    required this.thumbColor,
    this.padding = const EdgeInsets.only(top: 2, bottom: 2, right: 2),
    this.hitTargetWidth = 24.0,
    this.initialTop,
  });

  @override
  State<RetroScrollThumb> createState() => _RetroScrollThumbState();
}

class _RetroScrollThumbState extends State<RetroScrollThumb> {
  void _handleDrag(DragUpdateDetails details, double trackHeight, double maxScroll) {
    if (trackHeight <= 0 || maxScroll <= 0 || !widget.controller.hasClients) return;
    final deltaFraction = details.delta.dy / trackHeight;
    final targetOffset = (widget.controller.offset + deltaFraction * maxScroll).clamp(0.0, maxScroll);
    widget.controller.jumpTo(targetOffset);
  }

  void _handleTapDown(TapDownDetails details, double trackHeight, double maxScroll) {
    if (trackHeight <= 0 || maxScroll <= 0 || !widget.controller.hasClients) return;
    final touchY = details.localPosition.dy;
    final targetCenter = touchY - (widget.thumbHeight / 2);
    final targetFraction = (targetCenter / trackHeight).clamp(0.0, 1.0);
    widget.controller.jumpTo(targetFraction * maxScroll);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              if (!widget.controller.hasClients ||
                  !widget.controller.position.hasContentDimensions ||
                  widget.controller.position.maxScrollExtent <= 0) {
                return const SizedBox.shrink();
              }

              final totalHeight = constraints.maxHeight;
              final topPad = (widget.initialTop != null && widget.initialTop! > 0)
                  ? widget.initialTop!
                  : widget.padding.top;
              final bottomPad = widget.padding.bottom;
              final trackHeight = totalHeight - topPad - bottomPad - widget.thumbHeight;
              if (trackHeight <= 0) return const SizedBox.shrink();

              final maxScroll = widget.controller.position.maxScrollExtent;
              final scrollFraction = (widget.controller.offset / maxScroll).clamp(0.0, 1.0);
              final thumbTop = topPad + (scrollFraction * trackHeight);

              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: topPad,
                    bottom: 0,
                    right: 0,
                    width: widget.hitTargetWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) => _handleTapDown(details, trackHeight, maxScroll),
                      onVerticalDragUpdate: (details) => _handleDrag(details, trackHeight, maxScroll),
                      child: Stack(
                        children: [
                          Positioned(
                            top: thumbTop - topPad,
                            right: widget.padding.right,
                            width: widget.thickness,
                            height: widget.thumbHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: widget.thumbColor,
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
