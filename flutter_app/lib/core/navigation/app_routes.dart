import 'package:flutter/material.dart';

import '../../features/player_detail/view/player_detail_page.dart';
import '../../features/team_detail/view/team_detail_page.dart';
import 'slide_fade_route.dart';

abstract final class AppRoutes {
  static const String playerDetail = '/player-detail';
  static const String teamDetail = '/team-detail';
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  return switch (settings) {
    RouteSettings(
      name: AppRoutes.playerDetail,
      arguments: final int playerId
    ) =>
      slideFadeRoute(PlayerDetailScreen(playerId: playerId)),
    RouteSettings(name: AppRoutes.teamDetail, arguments: final int teamId) =>
      slideFadeRoute(TeamDetailScreen(teamId: teamId)),
    RouteSettings(:final name) => MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('Unknown route: $name')),
        ),
      ),
  };
}
