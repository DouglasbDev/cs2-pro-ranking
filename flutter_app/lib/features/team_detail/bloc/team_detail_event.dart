sealed class TeamDetailEvent {
  const TeamDetailEvent();
}

class LoadTeamDetail extends TeamDetailEvent {
  const LoadTeamDetail(this.teamId);

  final int teamId;
}
