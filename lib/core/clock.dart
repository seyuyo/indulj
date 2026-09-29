/// Injektálható óra: a domain soha nem hívja a `DateTime.now()`-t.
abstract interface class Clock {
  /// UTC epoch ms.
  int nowMs();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  int nowMs() => DateTime.now().millisecondsSinceEpoch;
}

/// Tesztekhez: kézzel léptethető óra.
class FakeClock implements Clock {
  FakeClock(this._nowMs);

  int _nowMs;

  @override
  int nowMs() => _nowMs;

  void advance(Duration by) => _nowMs += by.inMilliseconds;
}
