import 'package:flutter/material.dart';

const Duration _pressDuration = Duration(milliseconds: 100);
const Curve _pressCurve = Curves.easeOut;
const double _pressedScale = 0.98;
const double _restingScale = 1.0;

/// Wraps a clickable card with a subtle press-down scale — the only touch
/// feedback (no ripple, no shadow, no bounce): 1.0 -> 0.98 on press, back to
/// 1.0 on release/cancel. Local `_pressed` bool only; [AnimatedScale] does
/// the tweening itself, no AnimationController needed.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? _pressedScale : _restingScale,
        duration: _pressDuration,
        curve: _pressCurve,
        child: widget.child,
      ),
    );
  }
}
