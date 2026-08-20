library;

const double kAlignmentStart = -1.0;
const double kAlignmentEnd = 1.0;
const double kAlignmentSpan = kAlignmentEnd - kAlignmentStart;

double segmentAlignmentX(
    {required int selectedIndex, required int segmentCount}) {
  final lastIndex = segmentCount - 1;
  if (lastIndex <= 0) return 0.0;

  final normalizedPosition =
      selectedIndex / lastIndex; // 0.0 (first) .. 1.0 (last)
  return kAlignmentStart + normalizedPosition * kAlignmentSpan;
}
