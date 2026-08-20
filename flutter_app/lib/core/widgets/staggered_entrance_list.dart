import 'package:flutter/material.dart';

const double _entranceSlideOffsetY = 0.04;

/// A scrolling list whose first [staggerCount] items play a subtle
/// fade + slide-up entrance (opacity 0->1, Offset(0, 0.04)->zero), each one
/// starting [staggerGap] after the previous, driven by a single
/// [AnimationController] sliced per item with [Interval] + [CurvedAnimation].
///
/// The controller lives in this State and only ever runs once, in
/// [initState] — so it plays on the widget's first real mount (e.g. the
/// frame a BLoC's Loading state resolves to Loaded) and does NOT replay on
/// later rebuilds of the same widget (e.g. a filter changing the item
/// order/values while staying "loaded"), since Flutter reuses this State
/// instance across those rebuilds instead of recreating it.
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

  /// Only the first N items get the staggered entrance; the rest render at
  /// their final state immediately (no point staggering off-screen rows the
  /// user hasn't scrolled to yet).
  final int staggerCount;
  final Duration staggerGap;
  final Duration itemDuration;

  @override
  State<StaggeredEntranceList> createState() => _StaggeredEntranceListState();
}

class _StaggeredEntranceListState extends State<StaggeredEntranceList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _staggeredCount;
  late final int _totalDurationMs;

  @override
  void initState() {
    super.initState();
    _staggeredCount = widget.itemCount.clamp(0, widget.staggerCount);
    _totalDurationMs = _staggeredCount > 0
        ? widget.staggerGap.inMilliseconds * (_staggeredCount - 1) +
            widget.itemDuration.inMilliseconds
        : widget.itemDuration.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalDurationMs),
    )..forward();
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
    final endMs = (startMs + widget.itemDuration.inMilliseconds)
        .clamp(0, _totalDurationMs);
    final begin = startMs / _totalDurationMs;
    final end = endMs / _totalDurationMs;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(begin, end > begin ? end : begin,
          curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: widget.padding ?? EdgeInsets.zero,
          sliver: SliverList.builder(
            itemCount: widget.itemCount,
            itemBuilder: (context, index) => _StaggeredItem(
              entrance: _entranceFor(index),
              child: widget.itemBuilder(context, index),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaggeredItem extends StatelessWidget {
  const _StaggeredItem({required this.entrance, required this.child});

  final Animation<double> entrance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: entrance,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, _entranceSlideOffsetY),
          end: Offset.zero,
        ).animate(entrance),
        child: child,
      ),
    );
  }
}
