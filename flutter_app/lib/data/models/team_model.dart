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
}
