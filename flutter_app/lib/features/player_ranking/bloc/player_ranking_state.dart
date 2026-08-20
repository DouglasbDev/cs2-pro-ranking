import '../../../core/models/side.dart';
import '../../../data/models/player_model.dart';

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

  List<PlayerModel> get sortedPlayers {
    // Rank must reflect each player's position in the FULL list for the
    // current side, not the index within whatever search happens to leave
    // visible — so sort+rank first, filter after, never the other way.
    final sorted = [...players];
    sorted.sort((a, b) {
      final ratingA = a.ratingFor(selectedSide);
      final ratingB = b.ratingFor(selectedSide);
      if (ratingA == null && ratingB == null) return 0;
      if (ratingA == null) return 1;
      if (ratingB == null) return -1;
      return ratingB.compareTo(ratingA);
    });

    final ranked = [
      for (var i = 0; i < sorted.length; i++) sorted[i].copyWithRank(i + 1),
    ];

    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return ranked;
    return ranked.where((p) => p.nickname.toLowerCase().contains(query)).toList();
  }

  PlayerRankingLoaded copyWith({Side? selectedSide, String? searchQuery}) {
    return PlayerRankingLoaded(
      players: players,
      selectedSide: selectedSide ?? this.selectedSide,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class PlayerRankingError extends PlayerRankingState {
  const PlayerRankingError(this.message);

  final String message;
}
