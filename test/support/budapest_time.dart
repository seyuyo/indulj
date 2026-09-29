// Europe/Budapest UTC-eltolás az EU-szabály szerint, a gép zónájától
// függetlenül: nyári idő márc. utolsó vasárnap 01:00 UTC-től
// okt. utolsó vasárnap 01:00 UTC-ig.

const _hourMs = 3600 * 1000;

int budapestOffsetMs(int utcMs) {
  final year = DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true).year;
  final start = _lastSundayAt1Utc(year, 3);
  final end = _lastSundayAt1Utc(year, 10);
  return utcMs >= start && utcMs < end ? 2 * _hourMs : _hourMs;
}

int _lastSundayAt1Utc(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0); // a hónap utolsó napja
  final day = last.day - last.weekday % 7;
  return DateTime.utc(year, month, day, 1).millisecondsSinceEpoch;
}

/// Budapesti helyi idő → UTC epoch ms (egyértelmű időpontokra).
int budapest(int y, int mo, int d, int h, int mi, {int? offsetHours}) {
  final naive = DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch;
  if (offsetHours != null) return naive - offsetHours * _hourMs;
  final guess = naive - _hourMs;
  return naive - budapestOffsetMs(guess);
}
