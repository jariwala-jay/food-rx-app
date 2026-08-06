/// True when [value] is local@domain.tld with a TLD of at least two letters.
bool isValidEmailFormat(String? value) {
  if (value == null) return false;

  final email = value.trim();
  if (email.isEmpty) return false;

  // local@domain.tld — TLD must be at least 2 letters.
  final emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@"
    r"[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?"
    r"(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*"
    r"\.[a-zA-Z]{2,}$",
  );

  return emailRegex.hasMatch(email);
}

const _popularEmailDomains = [
  'gmail.com',
  'googlemail.com',
  'yahoo.com',
  'hotmail.com',
  'outlook.com',
  'live.com',
  'icloud.com',
  'aol.com',
  'msn.com',
  'me.com',
  'protonmail.com',
  'proton.me',
];

/// Common misspellings of well-known email domains (e.g. gmil.com → gmail.com).
const _knownDomainTypos = <String, String>{
  'gmil.com': 'gmail.com',
  'gmal.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gamil.com': 'gmail.com',
  'gmial.com': 'gmail.com',
  'gmaill.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gmail.con': 'gmail.com',
  'gmail.comm': 'gmail.com',
  'gmailcom': 'gmail.com',
  'yahooo.com': 'yahoo.com',
  'yaho.com': 'yahoo.com',
  'yahho.com': 'yahoo.com',
  'hotmial.com': 'hotmail.com',
  'hotmal.com': 'hotmail.com',
  'hotmailcom': 'hotmail.com',
  'outlok.com': 'outlook.com',
  'outook.com': 'outlook.com',
  'outlookcom': 'outlook.com',
  'iclod.com': 'icloud.com',
  'icoud.com': 'icloud.com',
};

int _levenshtein(String a, String b) {
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

/// Returns a suggested domain if [domain] looks like a typo, else null.
String? emailDomainTypoSuggestion(String domain) {
  final lower = domain.trim().toLowerCase();
  if (lower.isEmpty) return null;

  final known = _knownDomainTypos[lower];
  if (known != null) return known;

  for (final popular in _popularEmailDomains) {
    if (lower == popular) return null;

    // Same starting letter and very close spelling (e.g. gmil.com ≈ gmail.com).
    if (lower[0] != popular[0]) continue;

    final distance = _levenshtein(lower, popular);
    final lengthDelta = (lower.length - popular.length).abs();
    if (distance == 1 && lengthDelta <= 1) {
      return popular;
    }
  }

  return null;
}

/// True when the domain looks like a typo of a popular provider.
bool hasLikelyEmailDomainTypo(String email) {
  final parts = email.trim().split('@');
  if (parts.length != 2) return false;
  return emailDomainTypoSuggestion(parts[1]) != null;
}

String? emailFormatValidator(String? value, {String? emptyMessage}) {
  if (value == null || value.trim().isEmpty) {
    return emptyMessage ?? 'Please enter your email';
  }

  final email = value.trim();

  if (!isValidEmailFormat(email)) {
    return 'Please enter a valid email address';
  }

  final parts = email.split('@');
  if (parts.length == 2) {
    final suggestion = emailDomainTypoSuggestion(parts[1]);
    if (suggestion != null) {
      return 'Please check your email address. Did you mean ${parts[0]}@$suggestion?';
    }
  }

  return null;
}

/// True when [emailFormatValidator] returns null.
bool isAcceptableEmail(String? value) => emailFormatValidator(value) == null;
