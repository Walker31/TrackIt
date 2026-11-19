import 'package:flutter/material.dart';

/// Wraps [child] with a subtle press-down scale, for cards/tiles that
/// aren't already backed by Material's own ripple feedback.
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TapScale({super.key, required this.child, this.onTap});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  double _scale = 1.0;

  void _setScale(double value) => setState(() => _scale = value);

  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    // With a mouse, a tappable card lifts slightly and shows the hand
    // cursor, so it reads as clickable before it is clicked.
    final scale = _scale < 1 ? _scale : (_hovered ? 1.01 : 1.0);
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: tappable ? (_) => setState(() => _hovered = true) : null,
      onExit: tappable ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setScale(0.97),
        onTapUp: (_) => _setScale(1.0),
        onTapCancel: () => _setScale(1.0),
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Press-down scale that only listens to pointers, so it can wrap widgets
/// that handle their own taps (InkWell, buttons) without stealing them.
class PressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PressScale({super.key, required this.child, this.enabled = true});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.enabled && value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
