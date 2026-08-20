import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        rank.toString().padLeft(2, '0'),
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
