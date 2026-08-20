import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/country_flags.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/stat_tile.dart';
import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/team_repository.dart';
import '../bloc/team_detail_bloc.dart';
import '../bloc/team_detail_event.dart';
import '../bloc/team_detail_state.dart';

const EdgeInsets _pageContentPadding = EdgeInsets.all(16);
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

class TeamDetailScreen extends StatelessWidget {
  const TeamDetailScreen({super.key, required this.teamId});

  final int teamId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TeamDetailBloc(
        context.read<TeamRepository>(),
        context.read<PlayerRepository>(),
      )..add(LoadTeamDetail(teamId)),
      child: const _TeamDetailBody(),
    );
  }
}

class _TeamDetailBody extends StatelessWidget {
  const _TeamDetailBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      body: BlocBuilder<TeamDetailBloc, TeamDetailState>(
        builder: (context, state) {
          return switch (state) {
            TeamDetailInitial() || TeamDetailLoading() => const Center(
                child: CircularProgressIndicator(color: AppColors.gold)),
            TeamDetailError(:final message) =>
              Center(child: Text('Error: $message')),
            TeamDetailLoaded(:final team, :final roster) =>
              _TeamDetailContent(team: team, roster: roster),
          };
        },
      ),
    );
  }
}

class _TeamDetailContent extends StatelessWidget {
  const _TeamDetailContent({required this.team, required this.roster});

  final TeamModel team;
  final List<PlayerModel> roster;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: _pageContentPadding,
          sliver: SliverToBoxAdapter(child: _TeamHeader(team: team)),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: _statGridDelegate,
            delegate: SliverChildListDelegate([
              StatTile(
                label: 'Maps played',
                value: team.mapsPlayed?.toString() ?? '—',
                icon: Icons.grid_view_rounded,
              ),
              StatTile(
                label: 'W / D / L',
                value:
                    '${team.wins ?? '—'} / ${team.draws ?? '—'} / ${team.losses ?? '—'}',
                icon: Icons.emoji_events_outlined,
              ),
              StatTile(
                label: 'K/D ratio',
                value: team.kdRatio?.toStringAsFixed(2) ?? '—',
                icon: Icons.balance,
              ),
              StatTile(
                label: 'K/D diff',
                value: team.kdDiff?.toString() ?? '—',
                icon: Icons.trending_up,
                valueColor: switch (team.kdDiff) {
                  null => AppColors.textPrimary,
                  > 0 => AppColors.positive,
                  < 0 => AppColors.negative,
                  _ => AppColors.textPrimary,
                },
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          sliver: SliverToBoxAdapter(child: _RosterSection(roster: roster)),
        ),
      ],
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final flag = countryFlag(team.country);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppImage(
              assetPath: team.logoUrl,
              size: 64,
              shape: BoxShape.rectangle,
              fallbackIcon: Icons.shield,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  if (team.country case final String country) ...[
                    const SizedBox(height: 4),
                    _CountryLabel(flag: flag, country: country),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _OverallRatingCard(rating: team.ratingOverall),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _CountryLabel extends StatelessWidget {
  const _CountryLabel({required this.flag, required this.country});

  final String flag;
  final String country;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (flag.isNotEmpty) ...[
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
        ],
        Text(country, style: const TextStyle(color: AppColors.textSecondary)),
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
          Text(
            rating?.toStringAsFixed(2) ?? '—',
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

class _RosterSection extends StatelessWidget {
  const _RosterSection({required this.roster});

  final List<PlayerModel> roster;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LINEUP',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 12),
        switch (roster) {
          [] => const Text(
              'No players linked to this team',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          _ => SectionCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _RosterList(roster: roster),
            ),
        },
      ],
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({required this.roster});

  final List<PlayerModel> roster;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: roster.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) => _RosterRow(player: roster[index]),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.player});

  final PlayerModel player;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.playerDetail, arguments: player.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            AppImage(assetPath: player.imageUrl, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                player.nickname,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Text(
              player.ratingOverall?.toStringAsFixed(2) ?? '—',
              style: const TextStyle(
                  color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
