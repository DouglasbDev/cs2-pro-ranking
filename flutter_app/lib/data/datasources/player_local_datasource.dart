import 'package:cs2_ranking_app/core/database/app_database.dart';

import '../models/player_model.dart';

class PlayerLocalDataSource {
  static const _selectWithTeam = '''
    SELECT p.*, t.name AS team_name
    FROM players p
    LEFT JOIN teams t ON t.id = p.team_id
  ''';

  Future<List<PlayerModel>> getRanking() async {
    final database = await AppDatabase.open();
    final rows = await database.db.rawQuery(
      '$_selectWithTeam ORDER BY p.rating_overall DESC',
    );
    return rows.map(PlayerModel.fromMap).toList();
  }

  Future<PlayerModel?> getById(int id) async {
    final database = await AppDatabase.open();
    final rows = await database.db.rawQuery(
      '$_selectWithTeam WHERE p.id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return PlayerModel.fromMap(rows.first);
  }

  Future<List<PlayerModel>> getRosterByTeamId(int teamId) async {
    final database = await AppDatabase.open();
    final rows = await database.db.rawQuery(
      '$_selectWithTeam WHERE p.team_id = ? ORDER BY p.rating_overall DESC',
      [teamId],
    );
    return rows.map(PlayerModel.fromMap).toList();
  }
}
