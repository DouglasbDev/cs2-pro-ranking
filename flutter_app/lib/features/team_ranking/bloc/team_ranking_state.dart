import '../../../data/models/team_model.dart';

/// A team paired with its position in the full ranked list — computed once
/// from the unfiltered list (teams already arrive rating-sorted from the
/// repository) so a search filter never changes what rank a team shows.
typedef RankedTeam = ({int rank, TeamModel team});

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
  const TeamRankingLoaded({required this.teams, this.searchQuery = ''});

  final List<TeamModel> teams;
  final String searchQuery;

  List<RankedTeam> get rankedTeams {
    final allRanked =
        teams.indexed.map((entry) => (rank: entry.$1 + 1, team: entry.$2));

    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return allRanked.toList();
    return allRanked
        .where((ranked) => ranked.team.name.toLowerCase().contains(query))
        .toList();
  }
}

class TeamRankingError extends TeamRankingState {
  const TeamRankingError(this.message);

  final String message;
}
