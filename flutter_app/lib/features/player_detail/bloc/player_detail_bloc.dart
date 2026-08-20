import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/side.dart';
import '../../../data/repositories/player_repository.dart';
import 'player_detail_event.dart';
import 'player_detail_state.dart';

class PlayerDetailBloc extends Bloc<PlayerDetailEvent, PlayerDetailState> {
  PlayerDetailBloc(this._repository) : super(const PlayerDetailInitial()) {
    on<LoadPlayerDetail>(_onLoad);
    on<ChangeSideFilter>(_onChangeSide);
  }

  final PlayerRepository _repository;

  Future<void> _onLoad(
      LoadPlayerDetail event, Emitter<PlayerDetailState> emit) async {
    emit(const PlayerDetailLoading());
    try {
      final player = await _repository.getPlayerById(event.playerId);
      if (player == null) {
        emit(const PlayerDetailError('Player not found'));
        return;
      }
      emit(PlayerDetailLoaded(player: player, selectedSide: Side.both));
    } catch (e) {
      emit(PlayerDetailError(e.toString()));
    }
  }

  void _onChangeSide(ChangeSideFilter event, Emitter<PlayerDetailState> emit) {
    if (state case PlayerDetailLoaded(:final player)) {
      emit(PlayerDetailLoaded(player: player, selectedSide: event.side));
    }
  }
}
