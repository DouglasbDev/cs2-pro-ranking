import '../../../data/models/player_model.dart';
import '../../../data/models/team_model.dart';

sealed class TeamDetailState {
  const TeamDetailState();
}

class TeamDetailInitial extends TeamDetailState {
  const TeamDetailInitial();
}

class TeamDetailLoading extends TeamDetailState {
  const TeamDetailLoading();
}

class TeamDetailLoaded extends TeamDetailState {
  const TeamDetailLoaded({required this.team, required this.roster});

  final TeamModel team;
  final List<PlayerModel> roster;
}

class TeamDetailError extends TeamDetailState {
  const TeamDetailError(this.message);

  final String message;
}
