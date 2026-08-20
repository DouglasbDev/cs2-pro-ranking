import 'package:flutter/material.dart';

import '../enums/side.dart';
import '../theme/app_colors.dart';
import '../utils/segment_alignment.dart';

const Duration _toggleDuration = Duration(milliseconds: 220);
const Curve _toggleCurve = Curves.easeOutCubic;
const double _segmentWidth = 56.0;
const double _segmentHeight = 32.0;
const double _outerPadding = 4.0;
const double _outerCornerRadius = 12.0;
const double _pillCornerRadius = 8.0;
const double _labelFontSize = 13.0;

/// Both / CT / T segmented control with a sliding gold pill behind the
/// selected item — purely implicit animations (AnimatedAlign +
/// AnimatedDefaultTextStyle driven by a Stack), no AnimationController.
class SideToggle extends StatelessWidget {
  const SideToggle(
      {super.key, required this.selected, required this.onChanged});

  final Side selected;
  final ValueChanged<Side> onChanged;

  @override
  Widget build(BuildContext context) {
    const values = Side.values;
    final selectedIndex = values.indexOf(selected);
    final alignX = segmentAlignmentX(
        selectedIndex: selectedIndex, segmentCount: values.length);

    return Container(
      padding: const EdgeInsets.all(_outerPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(_outerCornerRadius),
      ),
      child: SizedBox(
        width: _segmentWidth * values.length,
        height: _segmentHeight,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: _toggleDuration,
              curve: _toggleCurve,
              alignment: Alignment(alignX, 0),
              child: Container(
                width: _segmentWidth,
                height: _segmentHeight,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(_pillCornerRadius),
                ),
              ),
            ),
            Row(
              children: [
                for (final side in values)
                  _SideSegment(
                      side: side, selected: selected, onChanged: onChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SideSegment extends StatelessWidget {
  const _SideSegment(
      {required this.side, required this.selected, required this.onChanged});

  final Side side;
  final Side selected;
  final ValueChanged<Side> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSelected = side == selected;
    return SizedBox(
      width: _segmentWidth,
      height: _segmentHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(side),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: _toggleDuration,
            curve: _toggleCurve,
            style: TextStyle(
              color:
                  isSelected ? AppColors.background : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: _labelFontSize,
            ),
            child: Text(side.label),
          ),
        ),
      ),
    );
  }
}
