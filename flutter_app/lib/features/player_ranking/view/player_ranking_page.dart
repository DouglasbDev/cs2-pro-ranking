import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/side.dart';
import '../../../core/navigation/app_routes.dart';
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
import '../bloc/player_ranking_bloc.dart';
import '../bloc/player_ranking_event.dart';
import '../bloc/player_ranking_state.dart';

const double _kdDiffColumnWidth = 52.0;
const double _kdRatioColumnWidth = 40.0;
const double _ratingColumnWidth = 44.0;
const int _topRankHighlightThreshold = 3;

const TextStyle _columnLabelStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 10,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.6,
);

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
            :final rankedPlayers,
            :final selectedSide,
            :final searchQuery
          ) =>
            _PlayerRankingContent(
              rankedPlayers: rankedPlayers,
              selectedSide: selectedSide,
              searchQuery: searchQuery,
            ),
        };
      },
    );
  }
}

class _PlayerRankingContent extends StatelessWidget {
  const _PlayerRankingContent({
    required this.rankedPlayers,
    required this.selectedSide,
    required this.searchQuery,
  });

  final List<RankedPlayer> rankedPlayers;
  final Side selectedSide;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Column(
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
              onChanged: (side) =>
                  context.read<PlayerRankingBloc>().add(ChangeSideFilter(side)),
            ),
          ),
        ),
        const _ColumnHeaders(),
        Expanded(
          child: _PlayerList(
            rankedPlayers: rankedPlayers,
            side: selectedSide,
            searchQuery: searchQuery,
          ),
        ),
      ],
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Spacer(),
          SizedBox(
            width: _kdDiffColumnWidth,
            child: Text('K-D DIFF',
                textAlign: TextAlign.right, style: _columnLabelStyle),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: _kdRatioColumnWidth,
            child: Text('K/D',
                textAlign: TextAlign.right, style: _columnLabelStyle),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: _ratingColumnWidth,
            child: Text('RATING',
                textAlign: TextAlign.right, style: _columnLabelStyle),
          ),
        ],
      ),
    );
  }
}

class _PlayerList extends StatelessWidget {
  const _PlayerList({
    required this.rankedPlayers,
    required this.side,
    required this.searchQuery,
  });

  final List<RankedPlayer> rankedPlayers;
  final Side side;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (rankedPlayers.isEmpty) {
      return _EmptyState(
          searchQuery: searchQuery, emptyLabel: 'No players found');
    }
    return StaggeredEntranceList(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: rankedPlayers.length,
      itemBuilder: (context, index) {
        final (:rank, :player) = rankedPlayers[index];
        return _PlayerRow(rank: rank, player: player, side: side);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searchQuery, required this.emptyLabel});

  final String searchQuery;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
          searchQuery.isEmpty ? emptyLabel : 'No results for "$searchQuery"'),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow(
      {required this.rank, required this.player, required this.side});

  final int rank;
  final PlayerModel player;
  final Side side;

  @override
  Widget build(BuildContext context) {
    final rating = player.ratingFor(side);
    final kdDiff = player.kdDiffFor(side);
    final isTopRank = rank <= _topRankHighlightThreshold;
    final flag = countryFlag(player.country);

    return PressableScale(
      onTap: () => Navigator.of(context)
          .pushNamed(AppRoutes.playerDetail, arguments: player.id),
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
              AppImage(assetPath: player.imageUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                  child: _PlayerNameAndFlag(
                      nickname: player.nickname, flag: flag)),
              _KdDiffLabel(kdDiff: kdDiff),
              const SizedBox(width: 10),
              _RightAlignedColumn(
                width: _kdRatioColumnWidth,
                child: Text(
                  player.kdRatio?.toStringAsFixed(2) ?? '—',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              _RightAlignedColumn(
                width: _ratingColumnWidth,
                child: Text(
                  rating?.toStringAsFixed(2) ?? '—',
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

class _PlayerNameAndFlag extends StatelessWidget {
  const _PlayerNameAndFlag({required this.nickname, required this.flag});

  final String nickname;
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
            nickname,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RightAlignedColumn extends StatelessWidget {
  const _RightAlignedColumn({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: width,
        child: Align(alignment: Alignment.centerRight, child: child));
  }
}

class _KdDiffLabel extends StatelessWidget {
  const _KdDiffLabel({required this.kdDiff});

  final int? kdDiff;

  @override
  Widget build(BuildContext context) {
    final color = switch (kdDiff) {
      null => AppColors.textSecondary,
      > 0 => AppColors.positive,
      < 0 => AppColors.negative,
      _ => AppColors.textSecondary,
    };
    final label = switch (kdDiff) {
      null => '—',
      > 0 => '+$kdDiff',
      _ => '$kdDiff',
    };

    return _RightAlignedColumn(
      width: _kdDiffColumnWidth,
      child: Text(label, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
