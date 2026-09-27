import 'package:flutter/material.dart';

/// Horizontally scrolls text if it overflows the available width,
/// revealing the entire text, and pauses for a configurable duration
/// (default 5 seconds) between scroll cycles.
class RetroMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration pauseDuration;
  final double pixelsPerSecond;

  const RetroMarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.pauseDuration = const Duration(seconds: 5),
    this.pixelsPerSecond = 32.0,
  });

  @override
  State<RetroMarqueeText> createState() => _RetroMarqueeTextState();
}

class _RetroMarqueeTextState extends State<RetroMarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late CurvedAnimation _curvedAnimation;
  bool _isLooping = false;
  double _overflowDistance = 0.0;
  bool _needsScroll = false;
  int _cycleId = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    // Ease-in-out for natural deceleration on 120Hz displays
    _curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
      reverseCurve: Curves.easeInOutSine,
    );
  }

  @override
  void didUpdateWidget(covariant RetroMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _cycleId++;
      _controller.reset();
      _isLooping = false;
      _needsScroll = false;
      _overflowDistance = 0.0;
    }
  }

  @override
  void dispose() {
    _cycleId++;
    _curvedAnimation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _checkOverflowAndAnimate(double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    final textWidth = textPainter.width;
    final overflow = textWidth - maxWidth;

    if (overflow > 1.0) {
      if (!_needsScroll || (_overflowDistance - (overflow + 8.0)).abs() > 2.0) {
        _overflowDistance = overflow + 8.0;
        _needsScroll = true;
        final scrollSeconds =
            (_overflowDistance / widget.pixelsPerSecond).clamp(2.0, 10.0);
        _controller.duration =
            Duration(milliseconds: (scrollSeconds * 1000).round());
        if (!_isLooping) {
          _runMarqueeLoop(_cycleId);
        }
      }
    } else {
      if (_needsScroll) {
        _needsScroll = false;
        _overflowDistance = 0.0;
        _cycleId++;
        _controller.reset();
        _isLooping = false;
      }
    }
  }

  Future<void> _runMarqueeLoop(int cycleId) async {
    if (_isLooping) return;
    _isLooping = true;

    while (mounted && _needsScroll && cycleId == _cycleId) {
      // 1. Initial pause at start so beginning is readable
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || !_needsScroll || cycleId != _cycleId) break;

      // 2. Sliding animation so entire song name is visible
      try {
        await _controller.forward();
      } catch (_) {
        break;
      }
      if (!mounted || !_needsScroll || cycleId != _cycleId) break;

      // 3. Pause at the end so trailing text is readable
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted || !_needsScroll || cycleId != _cycleId) break;

      // 4. Smoothly reverse back to start
      try {
        await _controller.reverse();
      } catch (_) {
        break;
      }
      if (!mounted || !_needsScroll || cycleId != _cycleId) break;

      // 5. Exactly 5 seconds pause after one animation before next scroll appears
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_needsScroll || cycleId != _cycleId) break;
    }

    _isLooping = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isFinite && maxWidth > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _checkOverflowAndAnimate(maxWidth);
            }
          });
        }

        return ClipRect(
          child: AnimatedBuilder(
            animation: _curvedAnimation,
            builder: (context, child) {
              final offset =
                  _needsScroll ? -_curvedAnimation.value * _overflowDistance : 0.0;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        );
      },
    );
  }
}
