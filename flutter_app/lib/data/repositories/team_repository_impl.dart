import '../datasources/team_local_datasource.dart';
import '../models/team_model.dart';
import 'team_repository.dart';

class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(this._dataSource);

  final TeamLocalDataSource _dataSource;

  @override
  Future<List<TeamModel>> getTeamRanking() => _dataSource.getRanking();

  @override
  Future<TeamModel?> getTeamById(int id) => _dataSource.getById(id);
}
