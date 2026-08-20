import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/segment_alignment.dart';
import '../player_ranking/view/player_ranking_page.dart';
import '../team_ranking/view/team_ranking_page.dart';

const Duration _switcherDuration = Duration(milliseconds: 240);
const Curve _switcherCurve = Curves.easeOutCubic;
const double _switcherHeight = 58.0;
const int _switcherSegmentCount = 2;

const List<String> _screenTitles = ['CS2\nPRO RANKING', 'CS2\nTEAM RANKING'];
const List<String> _screenSubtitles = ['TOP PLAYERS', 'TOP TEAMS'];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ScreenHeader(index: _selectedIndex),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [PlayerRankingScreen(), TeamRankingScreen()],
              ),
            ),
            _BottomSwitcher(
              index: _selectedIndex,
              onChanged: (index) => setState(() => _selectedIndex = index),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _screenTitles[index],
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _screenSubtitles[index],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSwitcher extends StatelessWidget {
  const _BottomSwitcher({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final segmentWidth = totalWidth / _switcherSegmentCount;
          final alignX = segmentAlignmentX(
              selectedIndex: index, segmentCount: _switcherSegmentCount);

          return SizedBox(
            width: totalWidth,
            height: _switcherHeight,
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: _switcherDuration,
                  curve: _switcherCurve,
                  alignment: Alignment(alignX, 0),
                  child: Container(
                    width: segmentWidth,
                    height: _switcherHeight,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: segmentWidth,
                      height: _switcherHeight,
                      child: _SwitcherItem(
                        icon: Icons.leaderboard_rounded,
                        label: 'ranking',
                        selected: index == 0,
                        onTap: () => onChanged(0),
                      ),
                    ),
                    SizedBox(
                      width: segmentWidth,
                      height: _switcherHeight,
                      child: _SwitcherItem(
                        icon: Icons.groups_rounded,
                        label: 'teams',
                        selected: index == 1,
                        onTap: () => onChanged(1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final targetColor =
        selected ? AppColors.background : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: targetColor),
        duration: _switcherDuration,
        curve: _switcherCurve,
        builder: (context, color, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          );
        },
      ),
    );
  }
}
