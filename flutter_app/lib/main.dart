import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/database/app_database.dart';
import 'core/navigation/app_routes.dart' as app_routes;
import 'core/theme/app_theme.dart';
import 'data/datasources/player_local_datasource.dart';
import 'data/datasources/team_local_datasource.dart';
import 'data/repositories/player_repository.dart';
import 'data/repositories/player_repository_impl.dart';
import 'data/repositories/team_repository.dart';
import 'data/repositories/team_repository_impl.dart';
import 'features/home/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  runApp(Cs2RankingApp(database: database));
}

class Cs2RankingApp extends StatelessWidget {
  const Cs2RankingApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PlayerRepository>(
          create: (_) => PlayerRepositoryImpl(PlayerLocalDataSource()),
        ),
        RepositoryProvider<TeamRepository>(
          create: (_) => TeamRepositoryImpl(TeamLocalDataSource()),
        ),
      ],
      child: MaterialApp(
        title: 'CS2 Ranking',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const HomeShell(),
        onGenerateRoute: app_routes.onGenerateRoute,
      ),
    );
  }
}
