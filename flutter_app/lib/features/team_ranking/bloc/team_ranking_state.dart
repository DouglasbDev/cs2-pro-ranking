import '../../../data/models/team_model.dart';

sealed class TeamRankingState {
  const TeamRankingState();
}

class TeamRankingInitial extends TeamRankingState {
  const TeamRankingInitial();
}

class TeamRankingLoading extends TeamRankingState {
  const TeamRankingLoading();
}

class TeamRankingLoaded extends TeamRankingState {
  const TeamRankingLoaded(this.teams);

  final List<TeamModel> teams;
}

class TeamRankingError extends TeamRankingState {
  const TeamRankingError(this.message);

  final String message;
}
