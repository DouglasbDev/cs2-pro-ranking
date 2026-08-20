import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/navigation/slide_fade_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/country_flags.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/staggered_entrance_list.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../../team_detail/view/team_detail_page.dart';
import '../bloc/team_ranking_bloc.dart';
import '../bloc/team_ranking_event.dart';
import '../bloc/team_ranking_state.dart';

class TeamRankingScreen extends StatelessWidget {
  const TeamRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TeamRankingBloc(context.read<TeamRepository>())
        ..add(const LoadTeamRanking()),
      child: const _TeamRankingBody(),
    );
  }
}

class _TeamRankingBody extends StatelessWidget {
  const _TeamRankingBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamRankingBloc, TeamRankingState>(
      builder: (context, state) {
        return switch (state) {
          TeamRankingInitial() || TeamRankingLoading() => const Center(
              child: CircularProgressIndicator(color: AppColors.gold)),
          TeamRankingError(:final message) =>
            Center(child: Text('Error loading teams: $message')),
          TeamRankingLoaded(:final teams) => _TeamList(teams: teams),
        };
      },
    );
  }
}

class _TeamList extends StatelessWidget {
  const _TeamList({required this.teams});

  final List<TeamModel> teams;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const Center(child: Text('No teams found'));
    }
    return StaggeredEntranceList(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        return _TeamRow(rank: index + 1, team: team);
      },
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.rank, required this.team});

  final int rank;
  final TeamModel team;

  @override
  Widget build(BuildContext context) {
    final isTopThree = rank <= 3;
    final flag = countryFlag(team.country);

    return PressableScale(
      onTap: () => Navigator.of(context).push(
        slideFadeRoute(TeamDetailScreen(teamId: team.id)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isTopThree
              ? const Border(left: BorderSide(color: AppColors.gold, width: 3))
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              RankBadge(rank: rank),
              const SizedBox(width: 12),
              AppImage(
                assetPath: team.logoUrl,
                size: 40,
                shape: BoxShape.rectangle,
                fallbackIcon: Icons.shield,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    if (flag.isNotEmpty) ...[
                      Text(flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        team.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                team.ratingOverall?.toStringAsFixed(2) ?? '—',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
