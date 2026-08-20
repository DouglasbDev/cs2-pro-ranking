import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/side.dart';
import '../../../core/navigation/slide_fade_route.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/country_flags.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/debounced_search_field.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/side_toggle.dart';
import '../../../core/widgets/staggered_entrance_list.dart';
import '../../../data/models/player_model.dart';
import '../../../data/repositories/player_repository.dart';
import '../../player_detail/view/player_detail_page.dart';
import '../bloc/player_ranking_bloc.dart';
import '../bloc/player_ranking_event.dart';
import '../bloc/player_ranking_state.dart';

class PlayerRankingScreen extends StatelessWidget {
  const PlayerRankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PlayerRankingBloc(context.read<PlayerRepository>())
        ..add(const LoadPlayerRanking()),
      child: const _PlayerRankingBody(),
    );
  }
}

class _PlayerRankingBody extends StatelessWidget {
  const _PlayerRankingBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerRankingBloc, PlayerRankingState>(
      builder: (context, state) {
        return switch (state) {
          PlayerRankingInitial() || PlayerRankingLoading() => const Center(
              child: CircularProgressIndicator(color: AppColors.gold)),
          PlayerRankingError(:final message) =>
            Center(child: Text('Error loading players: $message')),
          PlayerRankingLoaded(
            :final sortedPlayers,
            :final selectedSide,
            :final searchQuery
          ) =>
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: DebouncedSearchField(
                    hintText: 'Search players...',
                    onChanged: (query) => context
                        .read<PlayerRankingBloc>()
                        .add(SearchQueryChanged(query)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SideToggle(
                      selected: selectedSide,
                      onChanged: (side) => context
                          .read<PlayerRankingBloc>()
                          .add(ChangeSideFilter(side)),
                    ),
                  ),
                ),
                const _ColumnHeaders(),
                Expanded(
                  child: _PlayerList(
                    players: sortedPlayers,
                    side: selectedSide,
                    searchQuery: searchQuery,
                  ),
                ),
              ],
            ),
        };
      },
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();

  static const _labelStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Spacer(),
          SizedBox(
            width: _PlayerRow.kdDiffWidth,
            child: Text('K-D DIFF',
                textAlign: TextAlign.right, style: _labelStyle),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: _PlayerRow.kdRatioWidth,
            child: Text('K/D', textAlign: TextAlign.right, style: _labelStyle),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: _PlayerRow.ratingWidth,
            child:
                Text('RATING', textAlign: TextAlign.right, style: _labelStyle),
          ),
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({required this.players, required this.side, required this.searchQuery});

  final List<PlayerModel> players;
  final Side side;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return Center(
        child: Text(
          searchQuery.isEmpty ? 'No players found' : 'No players match "$searchQuery"',
        ),
      );
    }
    return StaggeredEntranceList(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        return _PlayerRow(rank: player.rank ?? index + 1, player: player, side: side);
      },
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow(
      {required this.rank, required this.player, required this.side});

  final int rank;
  final PlayerModel player;
  final Side side;

  // Shared with _ColumnHeaders so the header labels line up with the values.
  static const kdDiffWidth = 52.0;
  static const kdRatioWidth = 40.0;
  static const ratingWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final rating = player.ratingFor(side);
    final kdDiff = player.kdDiffFor(side);
    final isTopThree = rank <= 3;
    final flag = countryFlag(player.country);

    return PressableScale(
      onTap: () => Navigator.of(context).push(
        slideFadeRoute(PlayerDetailScreen(playerId: player.id)),
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
              AppImage(assetPath: player.imageUrl, size: 40),
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
                        player.nickname,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // K-D Diff: kills minus deaths for the selected side — green
              // when the player got more kills than deaths, red otherwise.
              SizedBox(
                width: kdDiffWidth,
                child: Text(
                  kdDiff == null ? '—' : (kdDiff > 0 ? '+$kdDiff' : '$kdDiff'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: switch (kdDiff) {
                      null => AppColors.textSecondary,
                      > 0 => AppColors.positive,
                      < 0 => AppColors.negative,
                      _ => AppColors.textSecondary,
                    },
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // K/D ratio: kills / deaths (overall, HLTV doesn't split this
              // one by side either) — separate from the Rating below.
              SizedBox(
                width: kdRatioWidth,
                child: Text(
                  player.kdRatio?.toStringAsFixed(2) ?? '—',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: ratingWidth,
                child: Text(
                  rating?.toStringAsFixed(2) ?? '—',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
