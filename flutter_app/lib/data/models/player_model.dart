import '../../core/enums/side.dart';

/// Domain entity — pure data, no parsing concerns (see [PlayerDto] for
/// that) and no ranking-context concept (see the ranking Bloc states for
/// where a player's position in a list is computed).
class PlayerModel {
  const PlayerModel({
    required this.id,
    required this.nickname,
    this.fullName,
    this.age,
    this.country,
    this.teamId,
    this.teamName,
    this.ratingOverall,
    this.ratingCtSide,
    this.ratingTSide,
    this.kdRatio,
    this.kdDiffCtSide,
    this.kdDiffTSide,
    this.roundsPlayedCtSide,
    this.roundsPlayedTSide,
    this.totalKills,
    this.totalDeaths,
    this.damagePerRound,
    this.headshotPercentage,
    this.kastPercentage,
    this.killsPerRound,
    this.deathsPerRound,
    this.assistsPerRound,
    this.mapsPlayed,
    this.imageUrl,
  });

  final int id;
  final String nickname;
  final String? fullName;
  final int? age;
  final String? country;
  final int? teamId;
  final String? teamName;
  final double? ratingOverall;
  final double? ratingCtSide;
  final double? ratingTSide;
  final double? kdRatio;
  final int? kdDiffCtSide;
  final int? kdDiffTSide;
  final int? roundsPlayedCtSide;
  final int? roundsPlayedTSide;
  final int? totalKills;
  final int? totalDeaths;
  final double? damagePerRound;
  final double? headshotPercentage;
  final double? kastPercentage;
  final double? killsPerRound;
  final double? deathsPerRound;
  final double? assistsPerRound;
  final int? mapsPlayed;
  final String? imageUrl;
}

extension PlayerSideStats on PlayerModel {
  double? ratingFor(Side side) => switch (side) {
        Side.both => ratingOverall,
        Side.ct => ratingCtSide,
        Side.t => ratingTSide,
      };

  int? kdDiffFor(Side side) => switch (side) {
        Side.both => switch ((totalKills, totalDeaths)) {
            (final kills?, final deaths?) => kills - deaths,
            _ => null,
          },
        Side.ct => kdDiffCtSide,
        Side.t => kdDiffTSide,
      };

  int? roundsPlayedFor(Side side) => switch (side) {
        Side.both => mapsPlayed,
        Side.ct => roundsPlayedCtSide,
        Side.t => roundsPlayedTSide,
      };
}
