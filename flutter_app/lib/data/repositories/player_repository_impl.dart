import '../datasources/player_local_datasource.dart';
import '../models/player_model.dart';
import 'player_repository.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  PlayerRepositoryImpl(this._dataSource);

  final PlayerLocalDataSource _dataSource;

  @override
  Future<List<PlayerModel>> getPlayerRanking() => _dataSource.getRanking();

  @override
  Future<PlayerModel?> getPlayerById(int id) => _dataSource.getById(id);

  @override
  Future<List<PlayerModel>> getRosterForTeam(int teamId) =>
      _dataSource.getRosterByTeamId(teamId);
}
