import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/country_flags.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/debounced_search_field.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/staggered_entrance_list.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../bloc/team_ranking_bloc.dart';
import '../bloc/team_ranking_event.dart';
import '../bloc/team_ranking_state.dart';

const int _topRankHighlightThreshold = 3;

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
          TeamRankingLoaded(:final rankedTeams, :final searchQuery) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: DebouncedSearchField(
                    hintText: 'Search teams...',
                    onChanged: (query) => context
                        .read<TeamRankingBloc>()
                        .add(TeamSearchQueryChanged(query)),
                  ),
                ),
                Expanded(
                  child: _TeamList(
                      rankedTeams: rankedTeams, searchQuery: searchQuery),
                ),
              ],
            ),
        };
      },
    );
  }
}

class _TeamList extends StatelessWidget {
  const _TeamList({required this.rankedTeams, required this.searchQuery});

  final List<RankedTeam> rankedTeams;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (rankedTeams.isEmpty) {
      return Center(
        child: Text(searchQuery.isEmpty
            ? 'No teams found'
            : 'No results for "$searchQuery"'),
      );
    }
    return StaggeredEntranceList(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: rankedTeams.length,
      itemBuilder: (context, index) {
        final (:rank, :team) = rankedTeams[index];
        return _TeamRow(rank: rank, team: team);
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
    final isTopRank = rank <= _topRankHighlightThreshold;
    final flag = countryFlag(team.country);

    return PressableScale(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.teamDetail, arguments: team.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: isTopRank
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
              Expanded(child: _TeamNameAndFlag(name: team.name, flag: flag)),
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

class _TeamNameAndFlag extends StatelessWidget {
  const _TeamNameAndFlag({required this.name, required this.flag});

  final String name;
  final String flag;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (flag.isNotEmpty) ...[
          Text(flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
