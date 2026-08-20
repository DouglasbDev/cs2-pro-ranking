import '../../../core/enums/side.dart';
import '../../../data/models/player_model.dart';

typedef RankedPlayer = ({int rank, PlayerModel player});

sealed class PlayerRankingState {
  const PlayerRankingState();
}

class PlayerRankingInitial extends PlayerRankingState {
  const PlayerRankingInitial();
}

class PlayerRankingLoading extends PlayerRankingState {
  const PlayerRankingLoading();
}

class PlayerRankingLoaded extends PlayerRankingState {
  const PlayerRankingLoaded({
    required this.players,
    this.selectedSide = Side.both,
    this.searchQuery = '',
  });

  final List<PlayerModel> players;
  final Side selectedSide;
  final String searchQuery;

  List<RankedPlayer> get rankedPlayers {
    final playersBySideRating = [...players]..sort(
        (a, b) =>
            switch ((a.ratingFor(selectedSide), b.ratingFor(selectedSide))) {
          (null, null) => 0,
          (null, _) => 1,
          (_, null) => -1,
          (final ratingA?, final ratingB?) => ratingB.compareTo(ratingA),
        },
      );

    final allRanked = playersBySideRating.indexed
        .map((entry) => (rank: entry.$1 + 1, player: entry.$2));

    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return allRanked.toList();
    return allRanked
        .where((ranked) => ranked.player.nickname.toLowerCase().contains(query))
        .toList();
  }
}

class PlayerRankingError extends PlayerRankingState {
  const PlayerRankingError(this.message);

  final String message;
}
