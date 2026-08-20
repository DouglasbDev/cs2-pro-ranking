import '../../../core/enums/side.dart';

sealed class PlayerDetailEvent {
  const PlayerDetailEvent();
}

class LoadPlayerDetail extends PlayerDetailEvent {
  const LoadPlayerDetail(this.playerId);

  final int playerId;
}

class ChangeSideFilter extends PlayerDetailEvent {
  const ChangeSideFilter(this.side);

  final Side side;
}
