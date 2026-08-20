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
  const TeamRankingLoaded({required this.teams, this.searchQuery = ''});

  final List<TeamModel> teams;
  final String searchQuery;

  List<TeamModel> get filteredTeams {
    // Same rule as players: rank reflects position in the full list (teams
    // already arrive rating-sorted from the repository), assigned before
    // any search filtering — never recomputed from a filtered index.
    final ranked = [
      for (var i = 0; i < teams.length; i++) teams[i].copyWithRank(i + 1),
    ];

    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return ranked;
    return ranked.where((t) => t.name.toLowerCase().contains(query)).toList();
  }

  TeamRankingLoaded copyWith({String? searchQuery}) {
    return TeamRankingLoaded(teams: teams, searchQuery: searchQuery ?? this.searchQuery);
  }
}

class TeamRankingError extends TeamRankingState {
  const TeamRankingError(this.message);

  final String message;
}
