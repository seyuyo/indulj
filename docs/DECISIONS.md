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
| Helyi idő | Injektált `UtcOffsetOf` függvény; appban az eszköz zónája | `timezone` csomag + Europe/Budapest | Nincs új függőség; a tesztek saját EU-szabályú budapesti offsetet adnak, így UTC-s CI-n is determinisztikusak |
| Járatszűrő kulcsa | `routeId` | `routeShortName` | Az ID stabil; a rövid név csak megjelenítés |
| Lefedettség-mérés | `tool/check_coverage.dart` (lcov-parszoló) | `coverage` csomag | Függőség nélkül; a CI-ban a `lib/domain` ≥ 95% kötelező |
| Csoport tagjai | Peron és állomás (`BKK_CS…`) is lehet | Csak peron | Élő teszt: az állomás-ID az összes peron indulását adja; a szűkítést a járatszűrő végzi |
| API-korlát helye | `DeparturesRepository`, megállókészletenként 30 mp | A képernyő időzítőjében | Egy helyen érvényesül a húzásos frissítésre és a szerkesztőre is; a hálózati hiba (nem ért el a szerverig) nem számít kérésnek |
| Keresés | Csak beküldésre (Enter / gomb) | Gépelés közben, debounce-szal | Kevesebb API-hívás; a 30 mp-es korlát a periodikus lekérdezésre vonatkozik, a keresés egyedi felhasználói művelet |
| Feliratfrissítés | 15 mp-enként újraszámolás hívás nélkül | Minden lekéréskor | A „3 perc" így nem avul el két lekérés között |
