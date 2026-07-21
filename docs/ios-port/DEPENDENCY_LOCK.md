# Zależności portu iOS

Maszynowym źródłem prawdy jest
[`ios-deps/dependencies.lock.json`](../../ios-deps/dependencies.lock.json). Ten dokument opisuje
zasady jego użycia i decyzje, których sam JSON nie wyjaśnia.

## Kontrakt

- Minimalny deployment target wszystkich artefaktów to iOS 16.4.
- Budujemy wyłącznie statyczne biblioteki.
- `iphoneos/arm64` i `iphonesimulator/arm64` mają osobne katalogi build oraz
  osobne prefiksy instalacyjne.
- Nie tworzymy bibliotek fat ani XCFrameworków. Pozwala to sprawdzać platformę
  każdego obiektu i uniemożliwia przypadkowe podanie slice'a symulatora
  linkerowi urządzenia.
- Każdy download ma niezmienny tag albo commit oraz SHA-256 pełnego archiwum.
- Cache źródeł zawiera oryginalne archiwa, a nie zmodyfikowane drzewa robocze.
- Build w trybie offline nie wykonuje żadnego żądania sieciowego.

## Grupy

| Grupa | Zawartość |
|---|---|
| `base` | SDL2, Boost, LZ4, zlib, yaml-cpp, SQLite, Bullet, Recast, MyGUI, FreeType, PNG i JPEG |
| `language` | PUC Lua i ICU wraz z osobnym buildem narzędzi hosta |
| `multimedia` | OpenAL Soft i minimalny FFmpeg |
| `render` | GL4ES i fork OSG; grupa należy do fazy 4, lecz korzysta z tego samego locka |

## Profile aktywnego buildu

Sekcja `build_profiles` w locku rozróżnia przypięte źródła planowane od tych,
które są już podłączone do superbuilda. Każdy profil ma odpowiadającą mu funkcję
manifestu vcpkg o identycznym zestawie portów i ustawieniach default features.
Przed buildem skrypt pobiera archiwa wskazane przez profil i sprawdza SHA-256.
Dla aktywnych portów z builtin registry dodatkowo:

1. SHA-512 tych samych bajtów musi zgadzać się z lockiem;
2. marker repozytorium i SHA-512 muszą wystąpić w tym samym bloku źródłowym
   portfile z przypiętego commita vcpkg;
3. content-addressed asset cache vcpkg musi zawierać plik o tym SHA-512;
4. wersja zainstalowanego pakietu musi zgadzać się z lockiem;
5. `vcpkg_port_version` musi zgadzać się z wynikiem instalacji. Pole jest
   opcjonalne i dla starszych wpisów oznacza `0`;
6. `default-registry.baseline` w `vcpkg-configuration.json` musi być identyczny
   z rewizją wpisu `vcpkg` w locku.

W ten sposób cache źródeł locka i niezależny asset cache vcpkg odnoszą się do
identycznego archiwum, mimo że vcpkg zarządza własną kopią downloadu.
Checkout narzędzia zachowuje pełną historię Git przypiętej rewizji. Wpisy
wersjonowanego builtin registry wskazują historyczne obiekty drzew portów,
których płytki checkout nie zawiera; cache z płytkim repozytorium jest
automatycznie odrzucany i odbudowywany.
Testy negatywne kontraktu odrzucają brakującą lub dodatkową funkcję portu,
włączone default features, dodatkowy direct port i duplikaty funkcji.

- `bootstrap`: zlib-only, mały test samego pipeline'u;
- `base-foundation`: SDL2, LZ4 i zlib, pierwszy produkcyjny fragment grafu.
- `image-foundation`: profil kumulatywny, który dodaje FreeType z funkcjami
  `png,zlib`, libpng i libjpeg-turbo bez narzędzi ani emulacji ABI JPEG 7/8.
- `cpp-foundation`: profil kumulatywny, który dodaje wyłącznie używane API
  Boost: `geometry`, `iostreams` bez filtrów kompresji oraz `program_options`.
  Pełna closure Boost — 82 porty targetowe i 3 helpery hosta — jest jawnie
  przypięta.

Dodanie biblioteki do profilu przed pogodzeniem jej wersji z przypiętym
registry albo portem overlay celowo kończy build błędem.

### Jawna closure portów vcpkg

Bezpośrednie zależności nadal definiują `build_profiles` i manifest. Profil,
który ma tranzytywne porty vcpkg, może dodatkowo przypiąć ich dokładny zbiór:

```json
"expected_vcpkg_transitive_ports": {
  "cpp-foundation": {
    "target": [
      { "port": "boost-algorithm" }
    ],
    "host": [
      { "port": "vcpkg-boost" }
    ]
  }
}
```

Każdy wpis oznacza tuple `scope|port|@core` oraz po jednej tupli dla każdej
funkcji. Walidator porównuje dokładnie cały zbiór z wynikiem
`vcpkg list --x-json`: brakujący lub dodatkowy port, funkcja albo triplet kończy
build błędem. Bezpośrednich portów nie powtarzamy w sekcji `target`. Profile bez
tej sekcji zachowują starszy kontrakt target-only i ignorują narzędzia hosta.
Znormalizowany wynik `vcpkg list --x-json`, razem z wersjami i port-version
całej closure, jest zachowywany jako artefakt workflow.

Smoke profilu `base-foundation` zachowuje własny `UIApplicationMain`, definiuje
`SDL_MAIN_HANDLED` i nie linkuje `SDL2::SDL2main`. Eksportowany target SDL ma
sam przenieść wymagane frameworki Apple; `-ObjC` wymusza uwzględnienie jego
statycznych członów Objective-C. Test wywołuje centralną inicjalizację SDL oraz
wykonuje pełny round-trip LZ4.

Smoke profilu `image-foundation` dodatkowo inicjalizuje FreeType, tworzy i
niszczy reader libpng oraz dekodery libjpeg i TurboJPEG. Sprawdza też w czasie
kompilacji, że FreeType faktycznie używa zewnętrznego zlib i obsługi PNG.

## Pobieranie i tryb offline

Na macOS/GitHub Actions:

```bash
bash CI/ios/deps/fetch-sources.sh --group all
bash CI/ios/deps/fetch-sources.sh --group all --offline
```

Domyślny cache to `build/ios-deps/source-cache`. Można go zmienić przez
`--cache` albo `IOS_DEPS_SOURCE_CACHE`. Druga komenda jest obowiązkowym testem,
że kompletny i poprawnie zahashowany cache wystarcza bez sieci.

Offline build vcpkg zaczyna z pustym katalogiem downloads właściwym dla danego
profilu. Content-addressed asset cache jest wtedy tylko do odczytu, a
`x-block-origin` zabrania fallbacku do sieci. Celowo nie używamy
`--no-downloads`: ta opcja ominęłaby asset provider i pozwoliłaby uzyskać
fałszywie dodatni wynik dzięki wcześniej współdzielonym plikom downloads.

Sam schemat i komplet pinów można sprawdzić na dowolnym hoście:

```bash
cmake -P CI/ios/deps/validate-lock.cmake
```

## Audyt licencji

Pole `license` zawiera identyfikator lub wyrażenie SPDX, a `license_files`
wskazuje pliki kopiowane ze zweryfikowanego źródła do zestawu notices. SQLite
i Lua mają jawny `license_notice`, ponieważ ich wybrane archiwa nie zawierają
osobnego pliku licencji w root.

FFmpeg pozostaje na warunkach LGPL: konfiguracja iOS musi mieć wyłączone
`--enable-gpl`, `--enable-version3` i `--enable-nonfree`. Każda późniejsza
zmiana listy kodeków lub bibliotek zewnętrznych wymaga ponownego audytu
licencji przed odhaczeniem odpowiedniego punktu roadmapy.

## Aktualizacja

Zmiana wersji wymaga jednego PR-a zawierającego:

1. nowy niezmienny URL i SHA-256;
2. potwierdzenie licencji;
3. czysty build obu platform;
4. kontrolę architektury i `LC_BUILD_VERSION`;
5. aktualizację SBOM i `ROADMAP.md`.

Nie wolno aktualizować tylko dokumentu. Lock JSON, build i dowody CI muszą
opisywać ten sam commit forka.
