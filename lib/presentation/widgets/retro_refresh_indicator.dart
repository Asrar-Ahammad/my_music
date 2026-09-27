import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_icon.dart';

/// An 8-bit retro styled pull-to-refresh indicator.
/// Features a custom pixel-art refresh icon, stepped rotation,
/// arcade card styling (solid 2.5px borders, zero radius, #14161E background),
/// and crisp status text.
class RetroRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final double triggerThreshold;

  const RetroRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.triggerThreshold = 55.0,
  });

  @override
  State<RetroRefreshIndicator> createState() => RetroRefreshIndicatorState();
}

class RetroRefreshIndicatorState extends State<RetroRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isRefreshingNotifier = ValueNotifier<bool>(false);
  double _scrollOffset = 0.0;
  double _dragStartY = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pullDistanceNotifier.dispose();
    _isRefreshingNotifier.dispose();
    super.dispose();
  }

  Future<void> show() => _triggerRefresh();

  Future<void> _triggerRefresh() async {
    if (!mounted || _isRefreshingNotifier.value) return;

    _isRefreshingNotifier.value = true;
    _pullDistanceNotifier.value = widget.triggerThreshold;
    _spinController.repeat();

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        _spinController.stop();
        _spinController.reset();
        _isRefreshingNotifier.value = false;
        _pullDistanceNotifier.value = 0.0;
      }
    }
  }

  void _resetPull() {
    if (_isRefreshingNotifier.value) return;
    _pullDistanceNotifier.value = 0.0;
    _isDragging = false;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    _scrollOffset = notification.metrics.pixels;

    if (_isRefreshingNotifier.value) return false;

    if (notification.metrics.extentBefore == 0) {
      if (notification is ScrollUpdateNotification) {
        if (notification.metrics.pixels < 0) {
          _pullDistanceNotifier.value = (-notification.metrics.pixels).clamp(0.0, 100.0);
        }
      } else if (notification is OverscrollNotification) {
        if (notification.overscroll < 0) {
          _pullDistanceNotifier.value = (_pullDistanceNotifier.value - notification.overscroll * 0.6).clamp(0.0, 100.0);
        }
      } else if (notification is ScrollEndNotification) {
        if (_pullDistanceNotifier.value >= widget.triggerThreshold) {
          _triggerRefresh();
        } else {
          _resetPull();
        }
      }
    } else if (notification.metrics.pixels > 0 && _pullDistanceNotifier.value > 0) {
      _resetPull();
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _dragStartY = e.position.dy;
          _isDragging = true;
        },
        onPointerMove: (e) {
          if (_isRefreshingNotifier.value || !_isDragging) return;
          if (_scrollOffset <= 0) {
            final delta = e.position.dy - _dragStartY;
            if (delta > 0) {
              _pullDistanceNotifier.value = (delta * 0.45).clamp(0.0, 100.0);
            }
          }
        },
        onPointerUp: (e) {
          if (_isRefreshingNotifier.value) return;
          if (_pullDistanceNotifier.value >= widget.triggerThreshold) {
            _triggerRefresh();
          } else {
            _resetPull();
          }
        },
        onPointerCancel: (_) => _resetPull(),
        child: Stack(
          children: [
            widget.child,
            AnimatedBuilder(
              animation: Listenable.merge([
                _pullDistanceNotifier,
                _isRefreshingNotifier,
                _spinController,
              ]),
              builder: (context, _) {
                final pullDistance = _pullDistanceNotifier.value;
                final isRefreshing = _isRefreshingNotifier.value;
                final isVisible = isRefreshing || pullDistance > 10;
                if (!isVisible) return const SizedBox.shrink();

                final isArmed = pullDistance >= widget.triggerThreshold;
                final progress = (pullDistance / widget.triggerThreshold).clamp(0.0, 1.0);

                double rotationTurns;
                if (isRefreshing) {
                  rotationTurns = (_spinController.value * 4).floor() / 4.0;
                } else {
                  rotationTurns = (progress * 4).floor() / 8.0;
                }

                final double bannerTop = isRefreshing
                    ? 12.0
                    : (pullDistance > 0 ? (pullDistance * 0.5 - 20).clamp(-50.0, 14.0) : -60.0);

                final isNothing = context.isNothingTheme;
                final accentColor = (isArmed || isRefreshing)
                    ? theme.colorScheme.primary
                    : (isNothing ? context.nothing.borderColor : retro.borderColor);
                final iconColor = (isArmed || isRefreshing)
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface;

                return Positioned(
                  top: bannerTop,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isNothing ? 16 : 14,
                        vertical: isNothing ? 10 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isNothing
                            ? (theme.brightness == Brightness.dark ? const Color(0xFF242424) : const Color(0xFFEEEEEE))
                            : retro.cardColor,
                        border: Border.all(
                          color: accentColor,
                          width: isNothing ? 0.5 : retro.borderWidth,
                        ),
                        borderRadius: isNothing ? BorderRadius.circular(999) : BorderRadius.zero,
                        boxShadow: isNothing
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RotationTransition(
                            turns: AlwaysStoppedAnimation(rotationTurns),
                            child: RetroIcon(
                              'refresh',
                              size: 18,
                              color: iconColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isRefreshing
                                ? (isNothing ? 'Rescanning...' : 'RESCANNING...')
                                : isArmed
                                    ? (isNothing ? 'Release to rescan' : 'RELEASE TO RESCAN')
                                    : (isNothing ? 'Pull to rescan' : 'PULL TO RESCAN'),
                            style: isNothing
                                ? TextStyle(
                                    fontFamily: 'Geist',
                                    color: iconColor,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  )
                                : RetroTypography.pixelBadge(
                                    color: iconColor,
                                    fontSize: 9,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
