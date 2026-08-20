import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/player_repository.dart';
import '../../../data/repositories/team_repository.dart';
import 'team_detail_event.dart';
import 'team_detail_state.dart';

class TeamDetailBloc extends Bloc<TeamDetailEvent, TeamDetailState> {
  TeamDetailBloc(this._teamRepository, this._playerRepository)
      : super(const TeamDetailInitial()) {
    on<LoadTeamDetail>(_onLoad);
  }

  final TeamRepository _teamRepository;
  final PlayerRepository _playerRepository;

  Future<void> _onLoad(LoadTeamDetail event, Emitter<TeamDetailState> emit) async {
    emit(const TeamDetailLoading());
    try {
      final team = await _teamRepository.getTeamById(event.teamId);
      if (team == null) {
        emit(const TeamDetailError('Team not found'));
        return;
      }
      final roster = await _playerRepository.getRosterForTeam(event.teamId);
      emit(TeamDetailLoaded(team: team, roster: roster));
    } catch (e) {
      emit(TeamDetailError(e.toString()));
    }
  }
}
