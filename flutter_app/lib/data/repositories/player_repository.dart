import '../models/player_model.dart';

abstract class PlayerRepository {
  Future<List<PlayerModel>> getPlayerRanking();
  Future<PlayerModel?> getPlayerById(int id);
  Future<List<PlayerModel>> getRosterForTeam(int teamId);
}
