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
| `render` | GL4ES i fork OSG; artefakty należą do closure fazy 2, a ich runtime bring-up do fazy 4 |

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
7. `vcpkg_port_source` jawnie wybiera `builtin` albo lokalny `overlay`;
   skrypt sprawdza marker i SHA-512 w portfile z wybranego źródła, bez
   fallbacku do drugiego. Do vcpkg przekazywane są tylko katalogi overlay
   wybrane przez aktywny profil, więc nie mogą niejawnie przesłonić portu
   oznaczonego w locku jako `builtin`.

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
- `data-foundation`: profil kumulatywny, który dodaje yaml-cpp 0.8.0 oraz
  SQLite 3.51.2 z JSON1 i bez runtime loadable extensions. Nie buduje narzędzia
  `sqlite3`, integracji ICU ani funkcji domyślnych. Closure Boost pozostaje
  identyczna: dwa nowe porty są bezpośrednimi zależnościami targetu.
- `physics-foundation`: profil kumulatywny, który dodaje iOS-only overlay
  Bullet 3.17#6 z funkcjami `double-precision` i `multithreading`. Instaluje
  wyłącznie `BulletCollision` i `LinearMath`; definicje ABI są PUBLIC na
  eksportowanych targetach.
- `navigation-foundation`: profil kumulatywny, który dodaje przypięty commit
  forka `OpenMW/recastnavigation` jako iOS-only overlay w wersji projektu
  1.6.0. Instaluje dokładnie statyczne `Recast`, `Detour`, `DetourTileCache`
  i `DebugUtils`; `DetourCrowd`, demo, testy, przykłady i narzędzia są wyłączone
  oraz odrzucane przez walidator prefiksu. ABI zachowuje 32-bitowe `dtPolyRef`
  i niewirtualny `dtQueryFilter`. Closure profilu to 13 bezpośrednich portów
  targetu, 79 portów tranzytywnych targetu i 3 helpery hosta.
- `language-foundation`: profil kumulatywny, który dodaje dwa lokalne overlaye:
  PUC Lua 5.1.5#1 oraz ICU 70.1#1. Closure to 15 bezpośrednich portów targetu,
  niezmienione 79 portów tranzytywnych targetu i 4 porty hosta. Czwartym
  portem hosta jest dokładnie `icu[tools]`; target ICU nie ma funkcji `tools`.
- `ui-foundation`: profil kumulatywny, który dodaje iOS-only overlay
  MyGUI 3.4.3#5. Instaluje wyłącznie statyczny `MyGUIEngine`, publiczne
  nagłówki i metadane pkg-config; platformy, renderery, pluginy, wrappery,
  narzędzia, demo, testy i dokumentacja nie są budowane. Closure to 16
  bezpośrednich portów targetu, niezmienione 79 portów tranzytywnych targetu
  i 4 porty hosta z `icu[tools]`.
- `multimedia-foundation`: profil kumulatywny dodający statyczny OpenAL Soft
  1.24.3#2 z wyłącznie backendem CoreAudio oraz statyczny FFmpeg 7.1.1#7.
  Closure to 18 bezpośrednich portów targetu, niezmienione 79 portów
  tranzytywnych targetu oraz 5 portów hosta; nowym helperem jest
  `vcpkg-cmake-get-vars`.

### Kontrakt PUC Lua

Overlay Lua instaluje wyłącznie `liblua.a` i publiczne nagłówki API 5.1.
Nie buduje `lua` ani `luac`, nie definiuje profilu POSIX/macOS i pozostawia
dynamiczny loader w bezpiecznym wariancie stub. `os.execute` na iOS kończy się
kontrolowanym błędem Lua, a skompilowany probe nie może mieć nierozwiązanego
symbolu `system` ani `dlopen`.

Probe runtime używa `lua_newstate` z własnym allocatorem i potwierdza
alokację, realokację i zwalnianie. Następnie wykonuje semantykę Lua 5.1:
tabele i metatabele, coroutine, globalne `unpack`, obsługę błędu, `_VERSION`
oraz niedostępność procesów i modułów dynamicznych. Istniejąca ścieżka
`CheckLuaCustomAllocator.cmake` używa `try_compile` podczas cross-builda;
na iOS nieudana kompilacja jest teraz błędem konfiguracji.

### Kontrakt ICU i danych

Overlay ICU najpierw buduje na `arm64-osx` przypięty zestaw natywnych narzędzi
i pliki `icucross.mk`/`icucross.inc`. Target device lub simulator używa tego
katalogu przez `--with-cross-build`. Target instaluje dokładnie statyczne
`libicudata.a`, `libicuuc.a` i `libicui18n.a`; narzędzia, `icuio`, extras,
layoutex, sample i testy są niedozwolone. Dane są generowane bez targetowego
obiektu asemblera (`PKGDATA_OPTS=--without-assembly`) jako statyczna biblioteka.

Źródłem filtra jest `extern/icufilters.json`. Lock przechowuje ścieżkę,
kanoniczne zakończenia linii LF oraz oba hashe:

```text
SHA-256 05533f4c0bf0b50c93ab3e0fb8a09a98965f1ea58510144b0c9e0239671f3a6f
SHA-512 e4d91a6daa494331729e9791e17db60dc467fbbcd6c121069ccd339781bfff1419ea170f21ad7b190a8755d52afbcc8722096695128fe36b04e24279d28c25ea
```

Walidator host-tools sprawdza dokładny zbiór binariów Mach-O arm64, wersję
70.1, metadane cross-builda i brak narzędzi w targetowym prefiksie. Probe ICU
wykonuje `u_init`, round-trip UTF-8, `MessageFormat`, reguły plural dla
`en=1`, `pl=2`, `ru=5` oraz skeleton liczbowy `.00 group-off`.

### Kontrakt MyGUI

Overlay przypina tag `MyGUI3.4.3` do commita
`dae9ac4be5a09e672bec509b1a8552b107c40214` i stosuje backport poprawki LLVM
dla `char16_t`/`char32_t`. W prefiksie może istnieć dokładnie jedno archiwum
MyGUI: `libMyGUIEngineStatic.a`. Adaptery platform, render systemy, pluginy,
wrappery, narzędzia, demo, testy i dokumentacja są wyłączone podczas
konfiguracji i odrzucane przez walidator prefiksu.

Konsumenci muszą kompilować nagłówki z trzema definicjami ABI:
`MYGUI_STATIC`, `MYGUI_USE_FREETYPE` i `MYGUI_DONT_USE_OBSOLETE`. Overlay
zapisuje je w `MYGUIStatic.pc`, natomiast profil produktu OpenMW dodaje dwie
ostatnie jawnie, ponieważ `FindMyGUI.cmake` nie przenosi `Cflags` pkg-config;
`MYGUI_STATIC` wynika z istniejącej opcji statycznego linkowania. Importowany
target smoke przenosi pełną statyczną krawędź
`Freetype::Freetype;PNG::PNG;ZLIB::ZLIB`, więc probe nie może dopisywać tych
bibliotek poza targetem MyGUI. Walidator `nm -u` dodatkowo wymaga, aby samo
archiwum silnika zawierało nierozwiązane symbole `_FT_Init_FreeType` i
`_FT_Done_FreeType`.

### Kontrakt OpenAL Soft

Overlay przypina OpenAL Soft 1.24.3 i instaluje wyłącznie `libopenal.a` oraz
publiczne nagłówki. Backend CoreAudio jest wymagany, a backendy desktopowe,
narzędzia, przykłady, testy i biblioteki dynamiczne są wyłączone. Profil
produktu ustawia dokładne `OPENAL_INCLUDE_DIR` i `OPENAL_LIBRARY` w
zweryfikowanym prefiksie, więc `FindOpenAL` nie może wybrać systemowego
`OpenAL.framework`. Konsument jawnie linkuje CoreAudio, CoreFoundation i
AudioToolbox.

Pakiet ma wyrażenie SPDX
`LGPL-2.0-or-later AND BSD-3-Clause AND MIT`. Notices obejmują `COPYING`,
`LICENSE-pffft`, `BSD-3Clause` oraz licencję vendored `fmt-11.1.1`.

### Kontrakt FFmpeg

Overlay przypina źródło FFmpeg 7.1.1 o SHA-256
`733984395e0dbbe5c046abda2dc49a5544e7e0e1e2366bba849222ae9e3a03b1`
i patch `0020-fix-aarch64-libswscale.patch`. Buduje tylko `avformat`,
`avcodec`, `swresample`, `swscale` i `avutil`. Protokoły sieciowe, devices,
programy, muxery, encodery, filtry, GPL, nonfree i version3 są wyłączone.
Allowlista obejmuje demuxery Bink, Matroska/WebM, MP3, Ogg i WAV; dekodery
Bink, Bink audio, MP3, PCM s16le/u8, Vorbis, Opus, VP8 i VP9; parsery MPEG
audio i VP9 oraz `vp9_superframe_split` BSF. OpenMW używa własnego
`AVIOContext`, dlatego żaden protokół FFmpeg nie jest potrzebny.

MP4/MOV, AAC, H.264 oraz `.ogv`/Theora są świadomie poza zakresem iOS MVP.
Podstawowe multimedia Morrowind (Bink, MP3, WAV) oraz WebM/Ogg audio pozostają
obsługiwane. Prefiks zachowuje wynikowe `config.h`, `config_components.h`,
pełną listę opcji configure, adres i hash źródła oraz zastosowany patch. CI
publikuje je obok SPDX i notices jako audytowalną ścieżkę corresponding source
dla statycznej dystrybucji LGPL. Konsument jawnie linkuje CoreFoundation,
CoreMedia i CoreVideo.

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

`boost-uninstall` jest wewnętrznym, pustym portem vcpkg instalującym wyłącznie
wrapper CMake. Nie dostarcza własnego pliku `copyright`, dlatego jego SPDX musi
jawnie identyfikować dokładnie ten helper i licencję MIT, a zestaw notices
kopiuje tekst MIT z checkoutu przypiętej rewizji vcpkg. Brak notice dla każdego
innego pakietu z dokumentem SPDX nadal kończy build błędem.

Smoke profilu `base-foundation` zachowuje własny `UIApplicationMain`, definiuje
`SDL_MAIN_HANDLED` i nie linkuje `SDL2::SDL2main`. Eksportowany target SDL ma
sam przenieść wymagane frameworki Apple; `-ObjC` wymusza uwzględnienie jego
statycznych członów Objective-C. Test wywołuje centralną inicjalizację SDL oraz
wykonuje pełny round-trip LZ4.

Smoke profilu `image-foundation` dodatkowo inicjalizuje FreeType, tworzy i
niszczy reader libpng oraz dekodery libjpeg i TurboJPEG. Sprawdza też w czasie
kompilacji, że FreeType faktycznie używa zewnętrznego zlib i obsługi PNG.

Smoke profilu `data-foundation` dodatkowo parsuje i ponownie emituje dokument
YAML oraz linkuje SQLite przez eksportowany target vcpkg. Próba SQLite sprawdza
wersję nagłówka i biblioteki, thread safety, konfigurację bez ładowania
rozszerzeń i wykonuje zapytanie `json_extract` na bazie in-memory.

Smoke profilu `navigation-foundation` dodatkowo wymusza link wszystkich
czterech archiwów RecastNavigation. Deterministyczna próba runtime klasyfikuje
walkable geometrię i rasteruje ją do heightfieldu Recast, tworzy poprawne dane
dwupoligonowego navmesha przez `dtCreateNavMeshData`, inicjalizuje `dtNavMesh`
i `dtNavMeshQuery`, a następnie wykonuje `findNearestPoly` oraz dwupoligonowy
`findPath`. Counting backend `duDebugDraw` potwierdza callbacki wierzchołków
podczas rysowania navmesha, a osobny lifecycle sprawdza alokację i zwolnienie
`dtTileCache`. Wszystkie zasoby natywne są chronione przez RAII, a każdy etap
ma osobny kod błędu. Symulator musi zalogować marker
`navigation foundation PASS`.

Smoke profilu `language-foundation` dodatkowo linkuje Lua oraz wszystkie trzy
archiwa ICU. Dedykowane binaria wymuszają statyczne rozwiązywanie symboli, a
aplikacja symulatora musi wykonać oba probe i zalogować marker
`language foundation PASS`.

Smoke profilu `ui-foundation` dodatkowo linkuje `libMyGUIEngineStatic.a` bez
adaptera platformy i bez renderera. Dedykowany probe sprawdza wersję 3.4.3,
trzy definicje ABI oraz typy `char16_t`/`char32_t`, wykonuje round-trip UTF-8,
wykonuje bezrendererowy cykl `FT_Init_FreeType`/`FT_Done_FreeType`, buduje
dokument XML silnika, serializuje go i ponownie parsuje. Aplikacja symulatora
musi wykonać probe i zalogować marker `ui foundation PASS`.

Smoke profilu `multimedia-foundation` linkuje rzeczywiste symbole OpenAL Soft
i wszystkich pięciu archiwów FFmpeg. Runtime symulatora sprawdza wersje API,
wymagane demuxery, dekodery, parsery i BSF, brak reprezentatywnych formatów
spoza allowlisty oraz brak protokołów. Wymagany marker to
`multimedia foundation PASS`. Otwarcie prawdziwego urządzenia audio pozostaje
późniejszym testem na fizycznym iPhonie.

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
