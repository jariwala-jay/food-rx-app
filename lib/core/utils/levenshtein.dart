/// Minimum number of single-character edits (insert/delete/substitute)
/// needed to turn [a] into [b].
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final rows = a.length + 1;
  final cols = b.length + 1;
  final matrix = List.generate(rows, (_) => List<int>.filled(cols, 0));

  for (var i = 0; i < rows; i++) {
    matrix[i][0] = i;
  }
  for (var j = 0; j < cols; j++) {
    matrix[0][j] = j;
  }

  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < cols; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      matrix[i][j] = [
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost,
      ].reduce((left, right) => left < right ? left : right);
    }
  }

  return matrix[a.length][b.length];
}

/// 1.0 for identical strings, 0.0 for completely different ones, scaled by
/// the longer string's length so short/long comparisons stay meaningful.
double levenshteinSimilarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1.0;
  return 1.0 - (levenshteinDistance(a, b) / maxLen);
}
