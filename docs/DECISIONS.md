# Döntésnapló

| Döntés | Választás | Alternatíva | Indok |
|---|---|---|---|
| Widget UI | Jetpack Glance | XML RemoteViews | Compose-szerű, modern; a Chronometerhez `AndroidRemoteViews`-zal lenyúlunk |
| Lekérés helye | Dart (háttér-callback) | Kotlin | Egy parser, egy tesztkészlet |
| Adatforrás | Megálló-szintű REST | Teljes GTFS-RT feed | A feed városméretű, egy widgethez pazarló |
| Állapotkezelés | Riverpod, kódgenerálás nélkül | Provider | Tanulási cél; a Provider már ismert |
| Tárolás | `shared_preferences` (JSON) | drift | Néhány kis objektum, nincs lekérdezési igény |
| Kulcskezelés | `--dart-define-from-file` | Proxy | Nincs szerver a scope-ban; a kompromisszum dokumentált |
