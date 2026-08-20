import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/player_repository.dart';
import 'player_ranking_event.dart';
import 'player_ranking_state.dart';

class PlayerRankingBloc extends Bloc<PlayerRankingEvent, PlayerRankingState> {
  PlayerRankingBloc(this._repository) : super(const PlayerRankingInitial()) {
    on<LoadPlayerRanking>(_onLoad);
    on<ChangeSideFilter>(_onChangeSide);
    on<SearchQueryChanged>(_onSearchQueryChanged);
  }

  final PlayerRepository _repository;

  Future<void> _onLoad(
      LoadPlayerRanking event, Emitter<PlayerRankingState> emit) async {
    emit(const PlayerRankingLoading());
    try {
      final players = await _repository.getPlayerRanking();
      emit(PlayerRankingLoaded(players: players));
    } catch (e) {
      emit(PlayerRankingError(e.toString()));
    }
  }

  void _onChangeSide(ChangeSideFilter event, Emitter<PlayerRankingState> emit) {
    if (state case PlayerRankingLoaded(:final players, :final searchQuery)) {
      emit(PlayerRankingLoaded(
        players: players,
        selectedSide: event.side,
        searchQuery: searchQuery,
      ));
    }
  }

  void _onSearchQueryChanged(
      SearchQueryChanged event, Emitter<PlayerRankingState> emit) {
    if (state case PlayerRankingLoaded(:final players, :final selectedSide)) {
      emit(PlayerRankingLoaded(
        players: players,
        selectedSide: selectedSide,
        searchQuery: event.query,
      ));
    }
  }
}
