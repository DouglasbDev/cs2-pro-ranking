import '../../../core/enums/side.dart';
import '../../../data/models/player_model.dart';

sealed class PlayerDetailState {
  const PlayerDetailState();
}

class PlayerDetailInitial extends PlayerDetailState {
  const PlayerDetailInitial();
}

class PlayerDetailLoading extends PlayerDetailState {
  const PlayerDetailLoading();
}

class PlayerDetailLoaded extends PlayerDetailState {
  const PlayerDetailLoaded({required this.player, required this.selectedSide});

  final PlayerModel player;
  final Side selectedSide;
}

class PlayerDetailError extends PlayerDetailState {
  const PlayerDetailError(this.message);

  final String message;
}
