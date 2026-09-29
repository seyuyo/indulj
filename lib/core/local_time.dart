/// Az eszköz időzónájának UTC-eltolása az adott pillanatban (ms).
/// A domain `UtcOffsetOf`-ként kapja meg; a tesztek saját zónát adnak.
int deviceUtcOffsetMs(int utcMs) =>
    DateTime.fromMillisecondsSinceEpoch(utcMs).timeZoneOffset.inMilliseconds;
