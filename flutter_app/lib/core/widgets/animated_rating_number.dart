import 'package:flutter/material.dart';

class AnimatedRatingNumber extends StatelessWidget {
  const AnimatedRatingNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  final double? value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value;
    if (target == null) {
      return Text('—', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(animatedValue.toStringAsFixed(2), style: style);
      },
    );
  }
}
