import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/team_repository.dart';
import 'team_ranking_event.dart';
import 'team_ranking_state.dart';

class TeamRankingBloc extends Bloc<TeamRankingEvent, TeamRankingState> {
  TeamRankingBloc(this._repository) : super(const TeamRankingInitial()) {
    on<LoadTeamRanking>(_onLoad);
    on<TeamSearchQueryChanged>(_onSearchQueryChanged);
  }

  final TeamRepository _repository;

  Future<void> _onLoad(
      LoadTeamRanking event, Emitter<TeamRankingState> emit) async {
    emit(const TeamRankingLoading());
    try {
      final teams = await _repository.getTeamRanking();
      emit(TeamRankingLoaded(teams: teams));
    } catch (e) {
      emit(TeamRankingError(e.toString()));
    }
  }

  void _onSearchQueryChanged(
      TeamSearchQueryChanged event, Emitter<TeamRankingState> emit) {
    if (state case TeamRankingLoaded(:final teams)) {
      emit(TeamRankingLoaded(teams: teams, searchQuery: event.query));
    }
  }
}
