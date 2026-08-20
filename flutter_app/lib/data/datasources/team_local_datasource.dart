import 'package:cs2_ranking_app/core/database/app_database.dart';

import '../dto/team_dto.dart';
import '../models/team_model.dart';

class TeamLocalDataSource {
  Future<List<TeamModel>> getRanking() async {
    final database = await AppDatabase.open();
    final rows =
        await database.db.query('teams', orderBy: 'rating_overall DESC');
    return rows.map((row) => TeamDto.fromMap(row).toEntity()).toList();
  }

  Future<TeamModel?> getById(int id) async {
    final database = await AppDatabase.open();
    final rows =
        await database.db.query('teams', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return TeamDto.fromMap(rows.first).toEntity();
  }
}
