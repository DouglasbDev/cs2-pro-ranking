const int _rankLabelMinDigits = 2;
const String _rankLabelPadChar = '0';

extension RankLabel on int {
  String get rankLabel =>
      toString().padLeft(_rankLabelMinDigits, _rankLabelPadChar);
}
