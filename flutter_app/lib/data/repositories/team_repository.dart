import '../models/team_model.dart';

abstract class TeamRepository {
  Future<List<TeamModel>> getTeamRanking();
  Future<TeamModel?> getTeamById(int id);
}
