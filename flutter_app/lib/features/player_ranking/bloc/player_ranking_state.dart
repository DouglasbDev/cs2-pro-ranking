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
  });

  final List<PlayerModel> players;
  final Side selectedSide;

  List<PlayerModel> get sortedPlayers {
    final sorted = [...players];
    sorted.sort((a, b) {
      final ratingA = a.ratingFor(selectedSide);
      final ratingB = b.ratingFor(selectedSide);
      if (ratingA == null && ratingB == null) return 0;
      if (ratingA == null) return 1;
      if (ratingB == null) return -1;
      return ratingB.compareTo(ratingA);
    });
    return sorted;
  }

  PlayerRankingLoaded copyWith({Side? selectedSide}) {
    return PlayerRankingLoaded(
        players: players, selectedSide: selectedSide ?? this.selectedSide);
  }
}

class PlayerRankingError extends PlayerRankingState {
  const PlayerRankingError(this.message);

  final String message;
}
