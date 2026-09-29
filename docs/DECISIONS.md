# Döntésnapló

| Döntés | Választás | Alternatíva | Indok |
|---|---|---|---|
| Widget UI | Jetpack Glance | XML RemoteViews | Compose-szerű, modern; a Chronometerhez `AndroidRemoteViews`-zal lenyúlunk |
| Lekérés helye | Dart (háttér-callback) | Kotlin | Egy parser, egy tesztkészlet |
| Adatforrás | Megálló-szintű REST | Teljes GTFS-RT feed | A feed városméretű, egy widgethez pazarló |
| Állapotkezelés | Riverpod, kódgenerálás nélkül | Provider | Tanulási cél; a Provider már ismert |
| Tárolás | `shared_preferences` (JSON) | drift | Néhány kis objektum, nincs lekérdezési igény |
| Kulcskezelés | `--dart-define-from-file` | Proxy | Nincs szerver a scope-ban; a kompromisszum dokumentált |
| HTTP-kliens | `http` | `dio` | Kicsi, elég 3 GET-hez; `MockClient` a teszthez |
| API-verzió | `version=4` rögzítve | alapértelmezett (`2`) | A fixture-ök ezzel készültek; a mezők erre vannak tesztelve |
| Törölt járatok | A mapper kiszűri (`canceled: true`) | Áthúzva mutatni | Widgeten nincs hely rá; a zavar-jelvény úgyis jelzi a gondot |
| Időegység | A Futár mp-et ad, a mapper ms-re vált | ms-ben tárolni mindent az API szerint | SPEC: belül minden UTC epoch ms |
