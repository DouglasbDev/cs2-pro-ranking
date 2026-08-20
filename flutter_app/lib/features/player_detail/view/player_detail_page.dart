import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/side.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/country_flags.dart';
import '../../../core/utils/segment_alignment.dart';
import '../../../core/widgets/animated_rating_number.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/side_toggle.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../data/models/player_model.dart';
import '../../../data/repositories/player_repository.dart';
import '../bloc/player_detail_bloc.dart';
import '../bloc/player_detail_event.dart';
import '../bloc/player_detail_state.dart';

const Duration _tabTransitionDuration = Duration(milliseconds: 200);
const Curve _tabTransitionCurve = Curves.easeOutCubic;
const List<String> _tabLabels = ['OVERVIEW', 'STATISTICS'];
const int _overviewTabIndex = 0;
const double _tabIndicatorHeight = 2.0;

const EdgeInsets _tabContentPadding = EdgeInsets.all(16);
const double _statGridSpacing = 12.0;
const double _statGridAspectRatio = 1.6;
const int _statGridCrossAxisCount = 2;
const SliverGridDelegate _statGridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: _statGridCrossAxisCount,
  mainAxisSpacing: _statGridSpacing,
  crossAxisSpacing: _statGridSpacing,
  childAspectRatio: _statGridAspectRatio,
);

class PlayerDetailScreen extends StatelessWidget {
  const PlayerDetailScreen({super.key, required this.playerId});

  final int playerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PlayerDetailBloc(context.read<PlayerRepository>())
        ..add(LoadPlayerDetail(playerId)),
      child: const _PlayerDetailBody(),
    );
  }
}

class _PlayerDetailBody extends StatelessWidget {
  const _PlayerDetailBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: BlocBuilder<PlayerDetailBloc, PlayerDetailState>(
        builder: (context, state) {
          return switch (state) {
            PlayerDetailInitial() || PlayerDetailLoading() => const Center(
                child: CircularProgressIndicator(color: AppColors.gold)),
            PlayerDetailError(:final message) =>
              Center(child: Text('Error: $message')),
            PlayerDetailLoaded(:final player, :final selectedSide) =>
              _PlayerDetailContent(player: player, selectedSide: selectedSide),
          };
        },
      ),
    );
  }
}

class _PlayerDetailContent extends StatelessWidget {
  const _PlayerDetailContent(
      {required this.player, required this.selectedSide});

  final PlayerModel player;
  final Side selectedSide;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlayerHeader(player: player),
        const SizedBox(height: 16),
        _SideFilterRow(selectedSide: selectedSide),
        const SizedBox(height: 12),
        Expanded(
          child: _DetailTabs(player: player, selectedSide: selectedSide),
        ),
      ],
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.player});

  final PlayerModel player;

  @override
  Widget build(BuildContext context) {
    final flag = countryFlag(player.country);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          AppImage(assetPath: player.imageUrl, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.nickname,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (flag.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(flag, style: const TextStyle(fontSize: 18)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                _PlayerSubtitle(
                    fullName: player.fullName, teamName: player.teamName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerSubtitle extends StatelessWidget {
  const _PlayerSubtitle({required this.fullName, required this.teamName});

  final String? fullName;
  final String? teamName;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        if (fullName case final String name)
          Text(name, style: const TextStyle(color: AppColors.textSecondary)),
        if (teamName case final String team) _TeamBadge(teamName: team),
      ],
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.teamName});

  final String teamName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        teamName,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SideFilterRow extends StatelessWidget {
  const _SideFilterRow({required this.selectedSide});

  final Side selectedSide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SIDE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          SideToggle(
            selected: selectedSide,
            onChanged: (side) =>
                context.read<PlayerDetailBloc>().add(ChangeSideFilter(side)),
          ),
        ],
      ),
    );
  }
}

/// Local-only UI state (which tab is showing) — not business logic, so it
/// stays as plain widget state rather than going through the Bloc.
class _DetailTabs extends StatefulWidget {
  const _DetailTabs({required this.player, required this.selectedSide});

  final PlayerModel player;
  final Side selectedSide;

  @override
  State<_DetailTabs> createState() => _DetailTabsState();
}

class _DetailTabsState extends State<_DetailTabs> {
  int _activeTab = _overviewTabIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabHeader(
          activeTab: _activeTab,
          onChanged: (index) => setState(() => _activeTab = index),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: _tabTransitionDuration,
            switchInCurve: _tabTransitionCurve,
            switchOutCurve: _tabTransitionCurve,
            // Fade only — a big slide here would fight with the sliding
            // indicator above and feel heavier than the content warrants.
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: switch (_activeTab) {
              _overviewTabIndex => _OverviewTab(
                  key: const ValueKey('overview'),
                  player: widget.player,
                  selectedSide: widget.selectedSide,
                ),
              _ => _StatsTab(
                  key: const ValueKey('stats'),
                  player: widget.player,
                  selectedSide: widget.selectedSide,
                ),
            },
          ),
        ),
      ],
    );
  }
}

/// "OVERVIEW | STATISTICS" header with a sliding gold underline — same
/// AnimatedAlign-in-a-Stack technique as SideToggle, sized off the real
/// available width via LayoutBuilder since this bar spans the screen.
class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.activeTab, required this.onChanged});

  final int activeTab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (final (index, label) in _tabLabels.indexed)
              _TabHeaderLabel(
                label: label,
                selected: index == activeTab,
                onTap: () => onChanged(index),
              ),
          ],
        ),
        _TabHeaderIndicator(activeTab: activeTab),
      ],
    );
  }
}

class _TabHeaderLabel extends StatelessWidget {
  const _TabHeaderLabel(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: _tabTransitionDuration,
              curve: _tabTransitionCurve,
              style: TextStyle(
                color: selected ? AppColors.gold : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                fontSize: 13,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabHeaderIndicator extends StatelessWidget {
  const _TabHeaderIndicator({required this.activeTab});

  final int activeTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final segmentWidth = totalWidth / _tabLabels.length;
        final alignX = segmentAlignmentX(
            selectedIndex: activeTab, segmentCount: _tabLabels.length);

        return SizedBox(
          width: totalWidth,
          height: _tabIndicatorHeight,
          child: Stack(
            children: [
              const ColoredBox(color: AppColors.divider),
              AnimatedAlign(
                duration: _tabTransitionDuration,
                curve: _tabTransitionCurve,
                alignment: Alignment(alignX, 0),
                child: Container(
                  width: segmentWidth,
                  height: _tabIndicatorHeight,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab(
      {super.key, required this.player, required this.selectedSide});

  final PlayerModel player;
  final Side selectedSide;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: _tabContentPadding,
          sliver: SliverToBoxAdapter(
            child: _OverallRatingCard(rating: player.ratingFor(selectedSide)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: _statGridDelegate,
            delegate: SliverChildListDelegate([
              StatTile(
                label: 'Kills',
                value: player.totalKills?.toString() ?? '—',
                icon: Icons.gps_fixed,
              ),
              StatTile(
                label: 'Deaths',
                value: player.totalDeaths?.toString() ?? '—',
                icon: Icons.dangerous_outlined,
              ),
              StatTile(
                label: 'K/D ratio',
                value: player.kdRatio?.toStringAsFixed(2) ?? '—',
                icon: Icons.balance,
              ),
              StatTile(
                label: 'Assist/round',
                value: player.assistsPerRound?.toStringAsFixed(2) ?? '—',
                icon: Icons.handshake_outlined,
              ),
              StatTile(
                label: 'ADR',
                value: player.damagePerRound?.toStringAsFixed(1) ?? '—',
                icon: Icons.bolt,
              ),
              StatTile(
                label: 'Headshot %',
                value: player.headshotPercentage != null
                    ? '${player.headshotPercentage!.toStringAsFixed(1)}%'
                    : '—',
                icon: Icons.adjust,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _OverallRatingCard extends StatelessWidget {
  const _OverallRatingCard({required this.rating});

  final double? rating;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OVERALL RATING',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedRatingNumber(
            value: rating,
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 40,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab(
      {super.key, required this.player, required this.selectedSide});

  final PlayerModel player;
  final Side selectedSide;

  @override
  Widget build(BuildContext context) {
    final roundsPlayed = player.roundsPlayedFor(selectedSide);
    final kdDiff =
        selectedSide == Side.both ? null : player.kdDiffFor(selectedSide);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: _tabContentPadding,
          sliver: SliverGrid(
            gridDelegate: _statGridDelegate,
            delegate: SliverChildListDelegate([
              StatTile(
                label: 'KAST %',
                value: player.kastPercentage != null
                    ? '${player.kastPercentage!.toStringAsFixed(1)}%'
                    : '—',
                icon: Icons.shield_outlined,
              ),
              StatTile(
                label:
                    selectedSide == Side.both ? 'Maps played' : 'Rounds played',
                value: roundsPlayed?.toString() ?? '—',
                icon: Icons.grid_view_rounded,
              ),
              StatTile(
                label: 'Kills/round',
                value: player.killsPerRound?.toStringAsFixed(2) ?? '—',
                icon: Icons.speed,
              ),
              StatTile(
                label: 'Deaths/round',
                value: player.deathsPerRound?.toStringAsFixed(2) ?? '—',
                icon: Icons.heart_broken_outlined,
              ),
              if (selectedSide != Side.both)
                StatTile(
                  label: 'K-D diff (${selectedSide.label})',
                  value: kdDiff?.toString() ?? '—',
                  icon: Icons.trending_up,
                  valueColor: switch (kdDiff) {
                    null => AppColors.textPrimary,
                    > 0 => AppColors.positive,
                    < 0 => AppColors.negative,
                    _ => AppColors.textPrimary,
                  },
                ),
            ]),
          ),
        ),
      ],
    );
  }
}
