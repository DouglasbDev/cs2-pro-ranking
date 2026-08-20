enum Side {
  both,
  ct,
  t;

  String get label => switch (this) {
        Side.both => 'Both',
        Side.ct => 'CT',
        Side.t => 'T',
      };
}
