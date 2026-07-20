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
2. ten SHA-512 musi występować w portfile z przypiętego commita vcpkg;
3. wersja zainstalowanego pakietu musi zgadzać się z lockiem.

W ten sposób cache źródeł locka i niezależny asset cache vcpkg odnoszą się do
identycznego archiwum, mimo że vcpkg zarządza własną kopią downloadu.

- `bootstrap`: zlib-only, mały test samego pipeline'u;
- `base-foundation`: SDL2, LZ4 i zlib, pierwszy produkcyjny fragment grafu.

Dodanie biblioteki do profilu przed pogodzeniem jej wersji z przypiętym
registry albo portem overlay celowo kończy build błędem.

Smoke profilu `base-foundation` zachowuje własny `UIApplicationMain`, definiuje
`SDL_MAIN_HANDLED` i nie linkuje `SDL2::SDL2main`. Eksportowany target SDL ma
sam przenieść wymagane frameworki Apple; `-ObjC` wymusza uwzględnienie jego
statycznych członów Objective-C. Test wywołuje centralną inicjalizację SDL oraz
wykonuje pełny round-trip LZ4.

## Pobieranie i tryb offline

Na macOS/GitHub Actions:

```bash
bash CI/ios/deps/fetch-sources.sh --group all
bash CI/ios/deps/fetch-sources.sh --group all --offline
```

Domyślny cache to `build/ios-deps/source-cache`. Można go zmienić przez
`--cache` albo `IOS_DEPS_SOURCE_CACHE`. Druga komenda jest obowiązkowym testem,
że kompletny i poprawnie zahashowany cache wystarcza bez sieci.

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
