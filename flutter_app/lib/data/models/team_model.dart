class TeamModel {
  const TeamModel({
    required this.id,
    required this.name,
    this.country,
    this.mapsPlayed,
    this.wins,
    this.draws,
    this.losses,
    this.totalKills,
    this.totalDeaths,
    this.roundsPlayed,
    this.kdRatio,
    this.kdDiff,
    this.ratingOverall,
    this.logoUrl,
    this.rank,
  });

  final int id;
  final String name;
  final String? country;
  final int? mapsPlayed;
  final int? wins;
  final int? draws;
  final int? losses;
  final int? totalKills;
  final int? totalDeaths;
  final int? roundsPlayed;
  final double? kdRatio;
  final int? kdDiff;
  final double? ratingOverall;
  final String? logoUrl;
  final int? rank;

  TeamModel copyWithRank(int rank) {
    return TeamModel(
      id: id,
      name: name,
      country: country,
      mapsPlayed: mapsPlayed,
      wins: wins,
      draws: draws,
      losses: losses,
      totalKills: totalKills,
      totalDeaths: totalDeaths,
      roundsPlayed: roundsPlayed,
      kdRatio: kdRatio,
      kdDiff: kdDiff,
      ratingOverall: ratingOverall,
      logoUrl: logoUrl,
      rank: rank,
    );
  }

  factory TeamModel.fromMap(Map<String, Object?> map) {
    return TeamModel(
      id: map['id'] as int,
      name: map['name'] as String,
      country: map['country'] as String?,
      mapsPlayed: map['maps_played'] as int?,
      wins: map['wins'] as int?,
      draws: map['draws'] as int?,
      losses: map['losses'] as int?,
      totalKills: map['total_kills'] as int?,
      totalDeaths: map['total_deaths'] as int?,
      roundsPlayed: map['rounds_played'] as int?,
      kdRatio: (map['kd_ratio'] as num?)?.toDouble(),
      kdDiff: map['kd_diff'] as int?,
      ratingOverall: (map['rating_overall'] as num?)?.toDouble(),
      logoUrl: map['logo_url'] as String?,
    );
  }
}
