sealed class TeamRankingEvent {
  const TeamRankingEvent();
}

class LoadTeamRanking extends TeamRankingEvent {
  const LoadTeamRanking();
}

class TeamSearchQueryChanged extends TeamRankingEvent {
  const TeamSearchQueryChanged(this.query);

  final String query;
}
