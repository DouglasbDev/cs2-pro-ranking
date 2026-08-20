import '../../core/models/side.dart';

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
    this.rank,
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
  final int? rank;

  PlayerModel copyWithRank(int rank) {
    return PlayerModel(
      id: id,
      nickname: nickname,
      fullName: fullName,
      age: age,
      country: country,
      teamId: teamId,
      teamName: teamName,
      ratingOverall: ratingOverall,
      ratingCtSide: ratingCtSide,
      ratingTSide: ratingTSide,
      kdRatio: kdRatio,
      kdDiffCtSide: kdDiffCtSide,
      kdDiffTSide: kdDiffTSide,
      roundsPlayedCtSide: roundsPlayedCtSide,
      roundsPlayedTSide: roundsPlayedTSide,
      totalKills: totalKills,
      totalDeaths: totalDeaths,
      damagePerRound: damagePerRound,
      headshotPercentage: headshotPercentage,
      kastPercentage: kastPercentage,
      killsPerRound: killsPerRound,
      deathsPerRound: deathsPerRound,
      assistsPerRound: assistsPerRound,
      mapsPlayed: mapsPlayed,
      imageUrl: imageUrl,
      rank: rank,
    );
  }

  factory PlayerModel.fromMap(Map<String, Object?> map) {
    return PlayerModel(
      id: map['id'] as int,
      nickname: map['nickname'] as String,
      fullName: map['full_name'] as String?,
      age: map['age'] as int?,
      country: map['country'] as String?,
      teamId: map['team_id'] as int?,
      teamName: map['team_name'] as String?,
      ratingOverall: (map['rating_overall'] as num?)?.toDouble(),
      ratingCtSide: (map['rating_ct_side'] as num?)?.toDouble(),
      ratingTSide: (map['rating_t_side'] as num?)?.toDouble(),
      kdRatio: (map['kd_ratio'] as num?)?.toDouble(),
      kdDiffCtSide: map['kd_diff_ct_side'] as int?,
      kdDiffTSide: map['kd_diff_t_side'] as int?,
      roundsPlayedCtSide: map['rounds_played_ct_side'] as int?,
      roundsPlayedTSide: map['rounds_played_t_side'] as int?,
      totalKills: map['total_kills'] as int?,
      totalDeaths: map['total_deaths'] as int?,
      damagePerRound: (map['damage_per_round'] as num?)?.toDouble(),
      headshotPercentage: (map['headshot_percentage'] as num?)?.toDouble(),
      kastPercentage: (map['kast_percentage'] as num?)?.toDouble(),
      killsPerRound: (map['kills_per_round'] as num?)?.toDouble(),
      deathsPerRound: (map['deaths_per_round'] as num?)?.toDouble(),
      assistsPerRound: (map['assists_per_round'] as num?)?.toDouble(),
      mapsPlayed: map['maps_played'] as int?,
      imageUrl: map['image_url'] as String?,
    );
  }
}

extension PlayerSideStats on PlayerModel {
  double? ratingFor(Side side) => switch (side) {
        Side.both => ratingOverall,
        Side.ct => ratingCtSide,
        Side.t => ratingTSide,
      };

  int? kdDiffFor(Side side) => switch (side) {
        Side.both => (totalKills != null && totalDeaths != null)
            ? totalKills! - totalDeaths!
            : null,
        Side.ct => kdDiffCtSide,
        Side.t => kdDiffTSide,
      };

  int? roundsPlayedFor(Side side) => switch (side) {
        Side.both => mapsPlayed,
        Side.ct => roundsPlayedCtSide,
        Side.t => roundsPlayedTSide,
      };
}
