import 'package:flutter/material.dart';

class StaggeredEntranceList extends StatefulWidget {
  const StaggeredEntranceList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.staggerCount = 12,
    this.staggerGap = const Duration(milliseconds: 40),
    this.itemDuration = const Duration(milliseconds: 260),
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;

  final int staggerCount;
  final Duration staggerGap;
  final Duration itemDuration;

  @override
  State<StaggeredEntranceList> createState() => _StaggeredEntranceListState();
}

class _StaggeredEntranceListState extends State<StaggeredEntranceList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _staggered;
  late final int _totalMs;

  @override
  void initState() {
    super.initState();
    _staggered = widget.itemCount.clamp(0, widget.staggerCount);
    _totalMs = _staggered > 0
        ? widget.staggerGap.inMilliseconds * (_staggered - 1) +
            widget.itemDuration.inMilliseconds
        : widget.itemDuration.inMilliseconds;
    _controller = AnimationController(
        vsync: this, duration: Duration(milliseconds: _totalMs))
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _entranceFor(int index) {
    if (index >= widget.staggerCount) {
      return kAlwaysCompleteAnimation;
    }
    final startMs = index * widget.staggerGap.inMilliseconds;
    final endMs =
        (startMs + widget.itemDuration.inMilliseconds).clamp(0, _totalMs);
    final begin = startMs / _totalMs;
    final end = endMs / _totalMs;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end > begin ? end : begin,
          curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      itemCount: widget.itemCount,
      itemBuilder: (context, index) {
        final entrance = _entranceFor(index);
        return FadeTransition(
          opacity: entrance,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(entrance),
            child: widget.itemBuilder(context, index),
          ),
        );
      },
    );
  }
}
