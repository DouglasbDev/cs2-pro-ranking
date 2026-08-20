import 'package:flutter/material.dart';

import '../formatters/rank_label.dart';
import '../theme/app_colors.dart';

const double _badgeWidth = 32.0;

/// Purely a display: text formatting (zero-padding) lives in [RankLabel],
/// this widget just renders whatever string it's handed.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _badgeWidth,
      child: Text(
        rank.rankLabel,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
