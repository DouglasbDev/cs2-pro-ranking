import '../../../core/models/side.dart';

sealed class PlayerRankingEvent {
  const PlayerRankingEvent();
}

class LoadPlayerRanking extends PlayerRankingEvent {
  const LoadPlayerRanking();
}

class ChangeSideFilter extends PlayerRankingEvent {
  const ChangeSideFilter(this.side);

  final Side side;
}
