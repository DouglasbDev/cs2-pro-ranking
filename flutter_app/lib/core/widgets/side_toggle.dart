import 'package:flutter/material.dart';

import '../models/side.dart';
import '../theme/app_colors.dart';

class SideToggle extends StatelessWidget {
  const SideToggle(
      {super.key, required this.selected, required this.onChanged});

  final Side selected;
  final ValueChanged<Side> onChanged;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;
  static const _segmentWidth = 56.0;
  static const _segmentHeight = 32.0;

  @override
  Widget build(BuildContext context) {
    const values = Side.values;
    final index = values.indexOf(selected);
    final alignX =
        values.length > 1 ? (index / (values.length - 1)) * 2 - 1 : 0.0;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: _segmentWidth * values.length,
        height: _segmentHeight,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: _duration,
              curve: _curve,
              alignment: Alignment(alignX, 0),
              child: Container(
                width: _segmentWidth,
                height: _segmentHeight,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Row(
              children: values.map((side) {
                final isSelected = side == selected;
                return SizedBox(
                  width: _segmentWidth,
                  height: _segmentHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(side),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: _duration,
                        curve: _curve,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.background
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        child: Text(side.label),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
