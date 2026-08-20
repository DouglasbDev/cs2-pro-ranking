import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/side.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/country_flags.dart';
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

  double? get _rating => player.ratingFor(selectedSide);

  int? get _kdDiff =>
      selectedSide == Side.both ? null : player.kdDiffFor(selectedSide);

  int? get _roundsPlayed => player.roundsPlayedFor(selectedSide);

  @override
  Widget build(BuildContext context) {
    final flag = countryFlag(player.country);

    return Column(
      children: [
        Padding(
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (player.fullName != null)
                          Text(
                            player.fullName!,
                            style:
                                const TextStyle(color: AppColors.textSecondary),
                          ),
                        if (player.teamName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              player.teamName!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
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
                onChanged: (side) => context
                    .read<PlayerDetailBloc>()
                    .add(ChangeSideFilter(side)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _DetailTabs(
            player: player,
            rating: _rating,
            kdDiff: _kdDiff,
            roundsPlayed: _roundsPlayed,
            selectedSide: selectedSide,
          ),
        ),
      ],
    );
  }
}

class _DetailTabs extends StatefulWidget {
  const _DetailTabs({
    required this.player,
    required this.rating,
    required this.kdDiff,
    required this.roundsPlayed,
    required this.selectedSide,
  });

  final PlayerModel player;
  final double? rating;
  final int? kdDiff;
  final int? roundsPlayed;
  final Side selectedSide;

  @override
  State<_DetailTabs> createState() => _DetailTabsState();
}

class _DetailTabsState extends State<_DetailTabs> {
  int _index = 0;

  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabHeader(index: _index, onChanged: (i) => setState(() => _index = i)),
        Expanded(
          child: AnimatedSwitcher(
            duration: _duration,
            switchInCurve: _curve,
            switchOutCurve: _curve,
            // Fade only — a big slide here would fight with the sliding
            // indicator above and feel heavier than the content warrants.
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _index == 0
                ? _OverviewTab(
                    key: const ValueKey('overview'),
                    player: widget.player,
                    rating: widget.rating)
                : _StatsTab(
                    key: const ValueKey('stats'),
                    player: widget.player,
                    kdDiff: widget.kdDiff,
                    roundsPlayed: widget.roundsPlayed,
                    selectedSide: widget.selectedSide,
                  ),
          ),
        ),
      ],
    );
  }
}

class _TabHeader extends StatelessWidget {
  const _TabHeader({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _labels = ['OVERVIEW', 'STATISTICS'];
  static const _duration = Duration(milliseconds: 200);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(_labels.length, (i) {
            final selected = i == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: _duration,
                      curve: _curve,
                      style: TextStyle(
                        color:
                            selected ? AppColors.gold : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        fontSize: 13,
                      ),
                      child: Text(_labels[i]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final segmentWidth = totalWidth / _labels.length;
            return SizedBox(
              width: totalWidth,
              height: 2,
              child: Stack(
                children: [
                  const ColoredBox(color: AppColors.divider),
                  AnimatedAlign(
                    duration: _duration,
                    curve: _curve,
                    alignment: Alignment(index == 0 ? -1.0 : 1.0, 0),
                    child: Container(
                        width: segmentWidth, height: 2, color: AppColors.gold),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({super.key, required this.player, required this.rating});

  final PlayerModel player;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
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
          ],
        ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({
    super.key,
    required this.player,
    required this.kdDiff,
    required this.roundsPlayed,
    required this.selectedSide,
  });

  final PlayerModel player;
  final int? kdDiff;
  final int? roundsPlayed;
  final Side selectedSide;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
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
          ],
        ),
      ],
    );
  }
}
