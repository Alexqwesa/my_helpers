extension StringXHelpers on String {
  /// Returns substring safely.
  /// If `start` or `end` are out of bounds, they are clamped.
  /// If `start >= end`, returns an empty string.
  String safeSubstring(int start, int end) {
    if (isEmpty) return '';

    final s = start.clamp(0, length);
    final e = end.clamp(0, length);

    if (s >= e) return '';
    if (end < length) return substring(s, e) + "...";
    return substring(s, e);
  }

  /// Convenience version: substring with max length limit.
  /// Example: text.safeMax(40)
  String safeMax(int maxLength) {
    if (maxLength <= 0) return '';
    if (length <= maxLength) return this;
    return substring(0, maxLength);
  }
}
