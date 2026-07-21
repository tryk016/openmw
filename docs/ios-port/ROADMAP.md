# Roadmapa portu OpenMW na iOS

**Ostatnia aktualizacja:** 2026-07-21
**Bazowy upstream:** `7a5e77a45130aca9b33db1d2eb6b412a8a848c9b`
**Repo docelowe:** `tryk016/openmw`
**Pierwotny branch dokumentacji:** `codex/ios-port-plan`
**Branch integracyjny:** `ios/main`

## Zaakceptowany zakres

- iOS/iPadOS 16.4+ jest jedynym wspieranym runtime.
- Kompatybilność Linux/Windows/macOS/Android może zostać świadomie złamana.
- Build device/simulator i packaging IPA realizuje GitHub Actions.
- Artefakty publikujemy na GitHubie.
- Instalacja odbywa się przez SideStore albo lokalny Xcode.
- App Store i TestFlight nie należą do projektu.
- Dane gry zawsze dostarcza użytkownik.

Źródłem decyzji jest
[ADR-0002-IOS-ONLY-SCOPE.md](ADR-0002-IOS-ONLY-SCOPE.md).

## Jak prowadzimy roadmapę

- `[ ]` oznacza niewykonane.
- `[x]` oznacza wykonane, zweryfikowane i udokumentowane.
- Częściowo wykonany większy punkt pozostaje `[ ]`; odhaczamy jego gotowe
  podpunkty.
- Zadanie zablokowane pozostaje `[ ]` i dostaje dopisek `BLOCKED:` z linkiem do
  issue/ADR.
- Każdy PR do `ios/main` aktualizuje tę roadmapę albo jawnie uzasadnia brak
  zmiany.
- Checkbox zmieniamy w tym samym commicie co kod/test/dokument, który go
  kończy.
- Dla testu urządzenia dowód zapisujemy w opisie PR: model, wersja iOS, build
  SHA, wynik i data.
- Faza kończy się dopiero po spełnieniu jej Definition of Done.

## Wspólna Definition of Done

Punkt implementacyjny można odhaczyć tylko, jeżeli:

- zmiana znajduje się w forku, nie w `OpenMW/openmw`;
- wymagane testy core/iOS w GitHub Actions przechodzą;
- właściwy build iOS przechodzi;
- istnieje test automatyczny albo powtarzalny scenariusz manualny;
- wynik na fizycznym urządzeniu jest zapisany, jeżeli zadanie dotyczy runtime;
- wersje i licencje nowych zależności są przypięte;
- dokumentacja i rejestr ryzyk są aktualne;
- roadmapa została zaktualizowana.

## Bramki stop/go

| Bramka | Decyzja |
|---|---|
| G0 — toolchain | C++20 app uruchamia się na device i simulator |
| G1 — rendering | realna scena OpenMW działa przez 20 min na fizycznym urządzeniu |
| G2 — vertical slice | tutorial Seyda Neen, save/load, audio i kontroler |
| G3 — touch | tutorial jest grywalny bez fizycznego kontrolera |
| G4 — performance | 60 min bez memory kill i krytycznego throttlingu |
| G5 — release | GitHub Release daje kompletne IPA do SideStore i powtarzalny build Xcode |

Nie przechodzimy do kosztownego polishu, dopóki poprzednia bramka nie jest
zamknięta.

## Postęp

Tabela jest aktualizowana razem z checkboxami.

| Faza | Ukończone | Wszystkie | Stan |
|---:|---:|---:|---|
| 0 | 24 | 24 | ukończona |
| 1 | 13 | 13 | ukończona |
| 2 | 21 | 45 | w toku |
| 3 | 10 | 26 | w toku |
| 4 | 0 | 32 | oczekuje |
| 5 | 0 | 39 | oczekuje |
| 6 | 0 | 33 | oczekuje |
| 7 | 0 | 17 | oczekuje |
| 8 | 0 | 32 | oczekuje |
| 9 | 0 | 25 | oczekuje |
| 10 | 20 | 38 | w toku |
| 11 | 4 | 42 | w toku |
| 12 | 0 | 16 | oczekuje |
| **Razem** | **92** | **382** | **24,1%** |

---

## Faza 0 — fork, governance i dokumentacja startowa

### Repozytorium

- [x] Utworzyć fork `tryk016/openmw`.
- [x] Pobrać `master` forka do lokalnego workspace.
- [x] Ustawić `origin` na `https://github.com/tryk016/openmw.git`.
- [x] Ustawić `upstream` na `https://github.com/OpenMW/openmw.git`.
- [x] Zablokować push URL `upstream` wartością `DISABLED`.
- [x] Ustawić `remote.pushDefault=origin`.
- [x] Zapisać bazowy SHA upstreamu.
- [x] Utworzyć izolowany branch `codex/ios-port-plan`.
- [x] Utworzyć branch integracyjny `ios/main`.
- [x] Włączyć ochronę `ios/main` w GitHubie.

### Dokumenty

- [x] Dodać indeks `docs/ios-port/README.md`.
- [x] Dodać ocenę wykonalności `FEASIBILITY.md`.
- [x] Dodać mapę projektu `PROJECT_MAP.md`.
- [x] Dodać kanoniczną roadmapę z checkboxami.
- [x] Dodać początkowy `TEST_PLAN.md`.
- [x] Dodać politykę forka `FORK_WORKFLOW.md`.
- [x] Dodać proponowany ADR renderingu.
- [x] Dodać zaakceptowany ADR zakresu iOS-only.
- [x] Dodać projekt GitHub Actions i dystrybucji sideload `CI_IOS.md`.
- [x] Dodać szablon PR z obowiązkową aktualizacją roadmapy.
- [x] Dodać szablon issue dla testu urządzenia.
- [x] Dodać etykiety `ios/build`, `ios/render`, `ios/input`, `ios/device`,
  `ios/release` i `ios/blocker`.
- [x] Zacommitować dokumentację wyłącznie w forku.
- [x] Wypchnąć branch dokumentacyjny wyłącznie do `origin`.

**DoD fazy:** fork ma bezpieczne remotes, dokumenty są dostępne na branchu
forka, a praca nie może przypadkowo trafić do upstreamu.

---

## Faza 1 — G0: środowisko i minimalny shell iOS

### Wymagane środowisko

- [x] Wyznaczyć wspieraną wersję Xcode 16.4 na runnerze `macos-15`.
- [x] Ustawić minimalną wersję iOS/iPadOS na 16.4.
- [x] Zapisać model fizycznego iPhone'a/iPada do PoC:
  iPhone 16 Pro Max, iOS 26.6,
  [test urządzenia #1](https://github.com/tryk016/openmw/issues/1).
- [x] Skonfigurować konto Apple Developer i development provisioning;
  podpisanie i instalację potwierdził test przez Sideloadly w
  [#1](https://github.com/tryk016/openmw/issues/1).
- [x] Utworzyć `BUILDING_IOS.md` z wymaganiami hosta.

### Minimalny target

- [x] Dodać minimalny target Objective-C++/C++20 generowany przez CMake.
- [x] Zbudować pusty bundle dla `iphoneos/arm64`.
- [x] Zainstalować i uruchomić pusty bundle na fizycznym urządzeniu; ekran G0,
  background/foreground i ponowny start potwierdzono w
  [#1](https://github.com/tryk016/openmw/issues/1).
- [x] Zbudować pusty bundle dla `iphonesimulator/arm64`.
- [x] Uruchomić pusty bundle w symulatorze.
- [x] Dodać log do unified logging i potwierdzić go przez `simctl` w CI;
  Console/Xcode pozostają równoważną ścieżką diagnostyczną dla urządzenia.
- [x] Potwierdzić działanie symboli debug i breakpointu C++.
- [x] Zapisać dokładne komendy jako CMake Presets.

**DoD/G0:** świeży checkout buduje device i simulator w GitHub Actions, a ten
sam kod instaluje się i uruchamia na fizycznym urządzeniu z iOS 16.4 lub
nowszym. Dokładny runtime 16.4 pozostaje dolną bramką kompatybilności przed G5,
jeżeli nie jest dostępny w G0.

---

## Faza 2 — hermetyczne zależności device/simulator

### Superbuild i manifest

- [x] Utworzyć wersjonowany `ios-deps`/superbuild.
- [x] Rozdzielić katalogi build `iphoneos` i `iphonesimulator`.
- [x] Ustalić format statycznych `.a` vs statycznych XCFrameworks.
- [x] Dodać `DEPENDENCY_LOCK.md`.
- [x] Przypiąć wersję/commit i SHA-256 każdego źródła.
- [x] Dodać cache pobranych źródeł działający offline.
- [ ] Dodać komendę czystego rebuilda wszystkich zależności.
- [ ] Utrzymać kumulatywny ciąg profili: `base-foundation` →
  `image-foundation` → `cpp-foundation` → `data-foundation` →
  `physics-foundation` → `navigation-foundation` →
  `language-foundation` → `ui-foundation` → `multimedia-foundation`
  → `render-foundation` → `full-openmw`.
- [x] Dodać kontrolę architektury każdego artefaktu.
- [x] Dodać kontrolę platform load commands każdego artefaktu.
- [x] Wygenerować SBOM i zestawienie licencji.

### Biblioteki bazowe

- [x] Zbudować SDL2 dla device.
- [x] Zbudować SDL2 dla simulator.
- [x] Zbudować Boost tylko z `program_options`, `iostreams` bez filtrów
  kompresji oraz header-only `geometry`.
- [x] Zbudować LZ4.
- [x] Zbudować zlib.
- [x] Zbudować yaml-cpp.
- [x] Zbudować SQLite amalgamation.
- [x] Zbudować Bullet 3.17 z `USE_DOUBLE_PRECISION=ON`.
- [x] Zweryfikować, że linkujemy tylko BulletCollision i LinearMath.
- [ ] Zbudować Recast/Detour bez demo/testów/examples.
- [ ] Zbudować MyGUIEngine bez pluginów/narzędzi.
- [x] Zbudować FreeType.
- [x] Zbudować libpng i libjpeg.

### Język i lokalizacja

- [ ] Zbudować PUC Lua dla device/simulator.
- [x] Ustawić `USE_LUAJIT=OFF` w bazowym profilu CMake dla iOS.
- [ ] Zweryfikować z docelowym PUC Lua istniejącą ścieżkę cross-compile:
  `CheckLuaCustomAllocator.cmake` używa `try_compile` i pomija `try_run`.
- [ ] Zbudować narzędzia ICU na hoście.
- [ ] Zbudować targetowe ICU `uc`, `i18n`, `data`.
- [ ] Ograniczyć ICU data do faktycznie wymaganych danych.

### Multimedia

- [ ] Zbudować statyczny OpenAL Soft lub udokumentować zatwierdzony wariant
  systemowy dla PoC.
- [ ] Zbudować minimalny FFmpeg: avcodec, avformat, avutil, swscale,
  swresample.
- [ ] Wyłączyć programy, devices, network i niepotrzebne kodeki FFmpeg.
- [ ] Zapisać pełne transitive libraries/frameworks FFmpeg.
- [ ] Zamknąć audyt konfiguracji LGPL/GPL FFmpeg.

### Closure renderera

- [ ] Zbudować GL4ES statycznie dla device.
- [ ] Zbudować GL4ES statycznie dla simulator.
- [ ] Ustawić `NOX11=ON`, `NOEGL=ON`, `STATICLIB=ON`, `NO_LOADER=ON` i
  `NO_INIT_CONSTRUCTOR=ON`.
- [ ] Usunąć hardkodowany stary iPhone SDK z przypiętego forka OSG.
- [ ] Poprawić wybór nagłówków GL2 tak, by używał GL4ES, nie macOS OpenGL.
- [ ] Zbudować OSG i OpenThreads statycznie.
- [ ] Zbudować osgDB/osgViewer/osgGA/osgText/osgAnimation/osgParticle/osgFX/
  osgShadow/osgSim/osgUtil.
- [ ] Zbudować statyczne pluginy BMP/DDS/JPEG/PNG/TGA/OSG/serializers/FreeType.
- [ ] Wyłączyć DAE/collada-dom w MVP i zapisać tę różnicę funkcjonalną.
- [ ] Utworzyć `full-openmw` jako dwa kompletne, osobne prefiksy device i
  simulator; ten profil jest wejściem fazy 3.

**DoD fazy:** dwa zestawy zależności linkują się do minimalnej aplikacji; nie
ma pomieszanych slice'ów, nieprzypiętych downloadów ani wymaganych dylib
spoza systemu.

**Dowód częściowy:** commit `690603fc0d`, workflow
[`iOS dependencies` #29756035686](https://github.com/tryk016/openmw/actions/runs/29756035686)
zbudował zlib dla obu SDK, zweryfikował każdy człon `.a`, zlinkował minimalne
bundle, zebrał SPDX/licencję i powtórzył czysty build z zablokowanym originem.
Punkt czystego rebuilda *wszystkich* zależności pozostaje otwarty do czasu
dodania pełnej funkcji manifestu.

**Dowód SDL2/LZ4:** commit `27f8547bfc`, workflow
[`iOS dependencies` #29760030676](https://github.com/tryk016/openmw/actions/runs/29760030676)
zbudował statyczne SDL2 2.32.10, LZ4 1.10.0 i zlib 1.3.1 dla obu SDK.
Oba joby zlinkowały symbole trzech bibliotek do minimalnego bundle'a UIKit,
zweryfikowały `arm64`, właściwą platformę `IOS`/`IOSSIMULATOR`, `minos 16.4`
i brak niesystemowych dylib, po czym powtórzyły czysty build bez dostępu do
originu. Lock i przypięte portfiles wskazują identyczne archiwa przez niezależne
SHA-256 oraz SHA-512.

**Dowód FreeType/kodeków:** commit `fb6c96f225`, workflow
[`iOS dependencies` #29784186547](https://github.com/tryk016/openmw/actions/runs/29784186547)
zbudował FreeType 2.13.3 z zewnętrznym zlib i PNG, libpng 1.6.54 oraz
libjpeg-turbo 3.1.3 dla obu SDK. Joby sprawdziły dokładny zestaw pakietów,
tożsamość źródeł, każdy człon archiwów, `arm64`, platformę, `minos 16.4`,
obiekty NEON JPEG, symbole obu API JPEG i minimalny bundle, po czym powtórzyły
czysty build offline i ponowny link. Workflow
[`iOS G0` #29784186534](https://github.com/tryk016/openmw/actions/runs/29784186534)
potwierdził brak regresji device/simulator oraz uruchomienie w symulatorze.

**Dowód Boost:** commit `f5ea9a6b90`, workflow
[`iOS dependencies` #29811362783](https://github.com/tryk016/openmw/actions/runs/29811362783)
zbudował Boost 1.90.0 dla obu SDK z dokładnie przypiętymi
`program_options`, `iostreams` bez filtrów kompresji i header-only `geometry`.
Pełna closure 82 portów targetowych i 3 helperów hosta została porównana z
`vcpkg list --x-json`; probe wymusił symbole Program Options, mapped file oraz
R-tree Geometry. Joby zweryfikowały wszystkie człony statycznych archiwów,
`arm64`, platformę i `minos 16.4`, zlinkowały probe, wykonały czysty rebuild
offline i ponowny link, a następnie zebrały SPDX oraz notices. Workflow
[`iOS G0` #29811362800](https://github.com/tryk016/openmw/actions/runs/29811362800)
potwierdził brak regresji device/simulator oraz start w symulatorze.

**Dowód yaml-cpp/SQLite:** commit `9da889e01d`, workflow
[`iOS dependencies` #29813819396](https://github.com/tryk016/openmw/actions/runs/29813819396)
zbudował yaml-cpp 0.8.0 i SQLite 3.51.2 dla obu SDK, zweryfikował pełną
closure 11 bezpośrednich portów, 79 tranzytywnych portów targetu i 3 helperów
hosta, każdy człon archiwów, `arm64`, platformę oraz `minos 16.4`. Oba joby
wykonały czysty rebuild offline i ponowny link. Aplikacja smoke uruchomiona na
iPhone Simulatorze wykonała parse/emit YAML oraz zapytanie SQLite `json_extract`
na bazie in-memory, potwierdzając jednocześnie thread safety i brak runtime
loadable extensions. Workflow
[`iOS G0` #29813819367](https://github.com/tryk016/openmw/actions/runs/29813819367)
potwierdził brak regresji device/simulator.

**Dowód Bullet:** commit `8743184554`, workflow
[`iOS dependencies` #29817842440](https://github.com/tryk016/openmw/actions/runs/29817842440)
zbudował iOS-only Bullet 3.17#6 dla obu SDK z publicznym ABI
`BT_USE_DOUBLE_PRECISION` i `BT_THREADSAFE=1`. Prefiksy zawierają wyłącznie
`BulletCollision` i `LinearMath`; walidacja odrzuca dynamics, soft body,
Bullet3, narzędzia, demo i testy. Closure obejmuje 12 bezpośrednich portów,
79 tranzytywnych portów targetu oraz 3 helpery hosta. Oba joby sprawdziły każdy
człon archiwów, wykonały link probes, czysty rebuild offline i ponowny link.
Smoke na iPhone Simulatorze utworzył dwa wątki z różnymi indeksami Bullet oraz
wykonał convex hull i kolizję BVH. Workflow
[`iOS G0` #29817842388](https://github.com/tryk016/openmw/actions/runs/29817842388)
potwierdził brak regresji device/simulator.

---

## Faza 3 — build system OpenMW dla iOS

### Klasyfikacja platformy

- [x] Dodać `OPENMW_IOS` albo użyć CMake `IOS`.
- [ ] Rozdzielić wspólne `APPLE` od `APPLE AND NOT IOS`.
- [ ] Zastąpić macOS `OpenGL.framework` właściwą zależnością warstwy GL4ES/GLES.
- [x] Wyłączyć macOS CPack dla iOS.
- [x] Usunąć założenie `OpenMW.app/Contents/Resources`.
- [x] Usunąć linkowanie Cocoa/IOKit w target iOS.
- [ ] Dodać wymagane frameworki UIKit/Foundation/GameController/AudioToolbox
  tylko przez jawne targety.
- [ ] Usunąć ograniczenie architektury odrzucające listę slice'ów symulatora.

### Zakres targetu

- [x] Ustawić `BUILD_OPENMW=ON`.
- [x] Ustawić `BUILD_LAUNCHER=OFF`.
- [x] Ustawić `BUILD_WIZARD=OFF`.
- [x] Ustawić `BUILD_OPENCS=OFF`.
- [x] Wyłączyć wszystkie importery i narzędzia CLI.
- [x] Wyłączyć testy/benchmarki w app buildzie.
- [ ] Zbudować `components` statycznie.
- [ ] Zbudować `openmw-lib` statycznie.
- [ ] Dodać finalny target app bundle iOS.
- [ ] Skonfigurować poprawne `Info.plist`, assets i launch screen.
- [ ] Osadzić OpenMW resources w root bundle.
- [ ] Zweryfikować wszystkie ścieżki `configure_file` i post-build commands.

### Link

- [ ] Zapewnić statyczną rejestrację pluginów OSG.
- [ ] Zweryfikować `WholeArchive.cmake` na linkerze Apple.
- [ ] Użyć precyzyjnego `-force_load`, jeśli szerokie `-all_load` tworzy
  duplicate symbols.
- [ ] Zlinkować finalny app target bez undefined symbols.
- [ ] Sprawdzić, że finalny bundle nie zawiera niedozwolonych dylibów.
- [ ] Zapisać map file i rozmiary największych sekcji binarnych.

**DoD fazy:** OpenMW core i finalny target iOS konfigurują się i linkują w obu
platformach build, nawet jeśli renderer/gameplay nie jest jeszcze uruchomiony.

**Dowód częściowy:** commit `690603fc0d`, workflow
[`iOS G0` #29756035280](https://github.com/tryk016/openmw/actions/runs/29756035280)
potwierdził kontrakt pruningu/statycznych zależności oraz brak regresji
bootstrapu device/simulator. Pełna konfiguracja i link core pozostają otwarte.

---

## Faza 4 — G1: rendering OpenMW na urządzeniu

### GL4ES i kontekst

- [ ] Ustawić deterministyczny baseline GLES wspierany przez iOS; nie polegać
  na zmiennej środowiskowej.
- [ ] Włączyć `OPENMW_GL4ES_MANUAL_INIT=ON`.
- [ ] Utworzyć kontekst SDL GLES przed `openmw_gl4es_init`.
- [ ] Użyć drawable pixel size w callbacku framebuffer Retina.
- [ ] Zalogować GL vendor, renderer, version, GLSL i extensions.

### Fork OpenSceneGraph

- [ ] Potwierdzić rejestrację każdego pluginu przy starcie.

### Bring-up sceny

- [ ] Wyświetlić trójkąt SDL → GLES → GL4ES. Po zielonym teście symulatora
  jest to pierwszy punkt zatrzymania autonomicznej pracy: wynik wymaga
  potwierdzenia na fizycznym iPhonie.
- [ ] Wyświetlić prostą scenę OSG.
- [ ] Wczytać teksturę PNG/JPEG.
- [ ] Wczytać teksturę DDS.
- [ ] Wyrenderować tekst przez osgText/FreeType.
- [ ] Wyrenderować podstawowe MyGUI.
- [ ] Skompilować wszystkie shadery profilu iOS w trybie testowym.
- [ ] Wczytać pojedynczy NIF z animacją.
- [ ] Wczytać teren i zewnętrzną komórkę.
- [ ] Wyrenderować aktora, UI, niebo i podstawową wodę.

### Profil grafiki `ios-low`

- [ ] Wyłączyć stereo/multiview.
- [ ] Wyłączyć compute ripples.
- [ ] Wyłączyć postprocessing.
- [ ] Ustawić cienie jako OFF w pierwszym profilu.
- [ ] Ograniczyć MSAA.
- [ ] Dodać niezależny render scale.
- [ ] Obsłużyć drawable resize i orientację.
- [ ] Dodać fallback/dekompresję nieobsługiwanych formatów tekstur.
- [ ] Dodać listę feature flags iOS.

### Ocena G1

- [ ] Przeprowadzić 20-minutowy test realnej sceny.
- [ ] Zmierzyć FPS/frametime/RAM/termikę.
- [ ] Sklasyfikować każdy błąd GL i shader.
- [ ] Porównać screenshoty z referencją desktopową.
- [ ] Zapisać decyzję G1 w ADR-0001.
- [ ] Niezależnie wykonać mały spike GL4ES + ANGLE/Metal.
- [ ] Jeśli GL4ES nie przejdzie, oznaczyć ścieżkę BLOCKED i nie inwestować w
  UI touch przed nową decyzją.

**DoD/G1:** menu i scena z terenem, NIF, aktorem, GUI i wodą działają stabilnie
20 minut na fizycznym urządzeniu, a znane różnice są ograniczalne.

---

## Faza 5 — shell aplikacji, sandbox i lifecycle

### Entrypoint i shell

- [ ] Dodać `iosmain.mm` albo równoważny bootstrap SDL UIKit.
- [ ] Zdefiniować prawidłowy `SDL_main`/`SDL_UIKitRunApp`.
- [ ] Przekazać syntetyczne argumenty do `runApplication`.
- [ ] Nie blokować głównego kontraktu lifecycle UIKit.
- [ ] Dodać natywny ekran pierwszego uruchomienia.
- [ ] Dodać natywny ekran błędu z możliwością eksportu logu.
- [ ] Dodać ekran wyboru profilu grafiki i kontrolera.

### Ścieżki

- [ ] Dodać `components/files/iospath.hpp`.
- [ ] Dodać `components/files/iospath.mm` lub `.cpp` z małym adapterem Foundation.
- [ ] Wybrać `IosPath` przed ogólnym `__APPLE__` w `fixedpath.hpp`.
- [ ] Mapować read-only resources na `NSBundle`.
- [ ] Mapować config na `Library/Application Support/OpenMW/Config`.
- [ ] Mapować saves/user data na `Application Support` lub `Documents` zgodnie
  z zatwierdzoną polityką backup.
- [ ] Mapować cache/navmesh na `Library/Caches`.
- [ ] Mapować temporary na `tmp`.
- [ ] Nie używać `/Library/...`, `getpwuid` ani `Contents/Resources`.
- [ ] Ustawić atrybuty backup/exclusion dla cache i kopiowanych danych.

### Import danych

- [ ] Dodać `UIDocumentPickerViewController` do wyboru folderu.
- [ ] Obsłużyć security-scoped URL.
- [ ] Podjąć i udokumentować decyzję copy-to-sandbox vs external bookmark.
- [ ] W MVP kopiować dane do `Application Support/GameData`.
- [ ] Pokazać postęp, wymagane miejsce i możliwość anulowania.
- [ ] Umożliwić wznowienie przerwanego importu.
- [ ] Walidować `Morrowind.esm` i wymagane archiwa.
- [ ] Nie kopiować ani publikować danych Bethesdy w repo/buildzie.
- [ ] Wygenerować `openmw.cfg` po udanym imporcie.
- [ ] Dodać migrację konfiguracji po aktualizacji aplikacji.
- [ ] Dodać bezpieczne usuwanie/reimport danych przez UI.

### Lifecycle

- [ ] Przestać ignorować `SDL_APP_WILLENTERBACKGROUND`.
- [ ] Natychmiast zatrzymać symulację/rendering przed background.
- [ ] Zatrzymać work queues i generację navmesh.
- [ ] Wykonać bezpieczny checkpoint/save, jeśli dozwolony stan gry na to pozwala.
- [ ] Zapisać config i Lua storage.
- [ ] Wyciszyć/zatrzymać audio.
- [ ] Obsłużyć `DIDENTERBACKGROUND`.
- [ ] Obsłużyć powrót foreground bez podwójnej inicjalizacji usług.
- [ ] Obsłużyć `SDL_APP_TERMINATING` jako best-effort, nie jedyny shutdown.
- [ ] Zastąpić samo logowanie `SDL_APP_LOWMEMORY` realnym czyszczeniem cache.
- [ ] Przetestować blokadę ekranu, telefon/Siri, Home i wielominutowy background.

**DoD fazy:** użytkownik legalnie importuje dane, po restarcie uruchamia grę,
a background/foreground nie powoduje utraty danych, audio ani crasha.

---

## Faza 6 — G2/G3: input, UI i dostępność

### Gamepad-first (G2)

- [ ] Potwierdzić działanie standardowego SDL GameController na iOS.
- [ ] Przetestować kontroler Xbox.
- [ ] Przetestować kontroler PlayStation.
- [ ] Przetestować kontroler MFi, jeśli znajduje się w macierzy.
- [ ] Ustawić rozsądne domyślne bindingi iOS.
- [ ] Włączyć controller menus i overlay podpowiedzi.
- [ ] Obsłużyć rozłączenie/powrót kontrolera.
- [ ] Obsłużyć gyro tylko dla zatwierdzonych urządzeń.
- [ ] Ukończyć tutorial Seyda Neen kontrolerem.

### Touch (G3)

- [ ] Przestać ignorować `SDL_FINGERDOWN`.
- [ ] Przestać ignorować `SDL_FINGERUP`.
- [ ] Przestać ignorować `SDL_FINGERMOTION`.
- [ ] Odróżnić touch-emulated mouse od prawdziwej myszy.
- [ ] Dodać warstwę `TouchListener`/virtual controller.
- [ ] Dodać lewy stick ruchu.
- [ ] Dodać prawy obszar kamery.
- [ ] Dodać przyciski activate/use/jump/sneak.
- [ ] Dodać weapon/spell/menu/quick slots.
- [ ] Dodać multitouch bez utraty pointer IDs.
- [ ] Dodać drag/drop inventory.
- [ ] Dodać skalowanie, opacity i edycję layoutu kontrolera.
- [ ] Dodać opcjonalne haptyki.
- [ ] Ukończyć tutorial bez fizycznego kontrolera.

### UI i urządzenia

- [ ] Dodać safe-area insets do layoutu.
- [ ] Zdefiniować profile UI iPhone compact/regular.
- [ ] Zdefiniować profil iPad.
- [ ] Obsłużyć punkty vs drawable pixels.
- [ ] Obsłużyć zmianę orientacji.
- [ ] Podłączyć `SDL_StartTextInput` do pól tekstowych.
- [ ] Obsłużyć klawiaturę ekranową bez zasłaniania pola.
- [ ] Przetestować klawiaturę sprzętową i mysz na iPadOS.
- [ ] Zapisać audyt minimalnych rozmiarów touch targetów.
- [ ] Zapisać plan VoiceOver/kontrastu albo jawny zakres dostępności pierwszej
  wersji.

**DoD/G2:** cały vertical slice działa kontrolerem.
**DoD/G3:** ten sam vertical slice działa touch-only, także inventory, dialog,
walka i zapis.

---

## Faza 7 — audio i wideo

### Audio

- [ ] Wybrać i opisać backend OpenAL/OpenAL Soft.
- [ ] Skonfigurować `AVAudioSession`.
- [ ] Uruchomić efekty 2D.
- [ ] Uruchomić pozycjonowanie 3D.
- [ ] Uruchomić muzykę i streaming.
- [ ] Obsłużyć audio interruption.
- [ ] Obsłużyć zmianę route: speaker/headphones/Bluetooth.
- [ ] Obsłużyć silent mode zgodnie z decyzją UX.
- [ ] Nie odtwarzać audio w background bez uzasadnionego background mode.
- [ ] Zweryfikować wznowienie bez podwójnych źródeł i leaków.

### FFmpeg/wideo

- [ ] Podłączyć minimalny statyczny FFmpeg.
- [ ] Odtworzyć intro/cutscene.
- [ ] Odtworzyć wideo z audio.
- [ ] Przetestować seek, pause, EOF i przerwanie lifecycle.
- [ ] Obsłużyć brak/wyłączone wideo bez blokady gameplay.
- [ ] Zmierzyć wpływ FFmpeg na rozmiar IPA.
- [ ] Zamknąć licencje i notices FFmpeg.

**DoD fazy:** muzyka, SFX i wideo przetrwają blokadę/odblokowanie ekranu,
interruption i zmianę output route.

---

## Faza 8 — G2: gameplay, zapis i skrypty

### Dane i świat

- [ ] Załadować `Morrowind.esm`.
- [ ] Załadować Tribunal/Bloodmoon w poprawnej kolejności.
- [ ] Rozpocząć nową grę.
- [ ] Przejść interior → exterior → interior.
- [ ] Zweryfikować streaming komórek.
- [ ] Zweryfikować NIF animations i particles.
- [ ] Zweryfikować pogodę i zmianę czasu.

### Mechanika

- [ ] Zweryfikować dialog i journal.
- [ ] Zweryfikować inventory i handel.
- [ ] Zweryfikować walkę melee/ranged/magic.
- [ ] Zweryfikować AI i pathfinding.
- [ ] Zweryfikować Bullet collision.
- [ ] Wygenerować i użyć navmesh.
- [ ] Zweryfikować teleport/travel/rest.

### Skrypty

- [ ] Uruchomić legacy MWScript.
- [ ] Uruchomić builtin Lua na PUC Lua.
- [ ] Zweryfikować eventy i Lua UI.
- [ ] Zweryfikować permanent storage Lua.
- [ ] Zweryfikować save serializujący stan Lua.
- [ ] Zdefiniować profil wspieranych modów w wersji deweloperskiej.
- [ ] Zdefiniować osobny profil modów dla publicznej dystrybucji.

### Save/load

- [ ] Zapisać ręcznie.
- [ ] Wykonać quicksave.
- [ ] Zamknąć aplikację po zapisie.
- [ ] Wczytać zapis po ponownym starcie.
- [ ] Przetestować save podczas/po lifecycle transition.
- [ ] Przetestować migrację zapisu między wersjami forka.

### Vertical slice

- [ ] Ukończyć tutorial Seyda Neen.
- [ ] Wykonać 60-minutową sesję: dialog, walka, podróż, save/load.
- [ ] Uruchomić wybrany zestaw OpenMW example suite.
- [ ] Uruchomić podstawowy zestaw Morrowind tests.
- [ ] Sprawdzić co najmniej jeden prosty mod bez natywnego kodu.

**DoD/G2:** 60-minutowy scenariusz przechodzi bez błędu danych, crasha,
uszkodzenia save ani krytycznej różnicy gameplay.

---

## Faza 9 — G4: pamięć, wydajność, energia i storage

### Budżety

- [ ] Utworzyć `PERFORMANCE_BUDGET.md`.
- [ ] Ustalić budżet resident memory dla najstarszego urządzenia.
- [ ] Ustalić budżet czasu startu do menu.
- [ ] Ustalić budżet czasu wejścia do zewnętrznej komórki.
- [ ] Ustalić target 30 FPS i opcjonalny 60 FPS.
- [ ] Ustalić limit render resolution/scale.
- [ ] Ustalić limit cache navmesh.
- [ ] Ustalić limit storage importu i wolnego miejsca.

### Optymalizacja

- [ ] Ograniczyć cache resource/texture przy memory warning.
- [ ] Ograniczyć preload komórek.
- [ ] Ograniczyć liczbę workerów OSG/resource.
- [ ] Ograniczyć liczbę workerów navmesh.
- [ ] Ograniczyć wątki physics.
- [ ] Ograniczyć background work do zera poza krótkim task completion.
- [ ] Dodać profil rozdzielczości zależny od urządzenia.
- [ ] Zmierzyć/dekompresować tekstury bez skoków pamięci.
- [ ] Dodać purge/rebuild cache navmesh.

### Testy długie

- [ ] 60 minut na najstarszym wspieranym urządzeniu.
- [ ] 60 minut na nowym urządzeniu.
- [ ] Test szybkich zmian komórek.
- [ ] Test dużych save'ów i modów.
- [ ] Test wielokrotnego background/foreground.
- [ ] Zmierzyć thermal state i throttling.
- [ ] Zmierzyć energię w Instruments.
- [ ] Sprawdzić brak nieograniczonego wzrostu RAM.

**DoD/G4:** najstarsze urządzenie kończy 60-minutową sesję bez jetsam/memory
kill, krytycznego throttlingu i przekroczenia zatwierdzonych budżetów.

---

## Faza 10 — testy, CI i obserwowalność

### Testy core na runnerze Apple

- [ ] Skonfigurować wybrane `components` tests na runnerze macOS.
- [ ] Skonfigurować wybrane `openmw` tests potrzebne portowi.
- [ ] Zachować testy serializacji/save używane przez iOS.
- [ ] Dodać testy adapterów `IosPath` bez fizycznego urządzenia.
- [ ] Dodać testy generowania iOS config.
- [ ] Dodać testy mapowania lifecycle state machine.
- [ ] Dodać testy mapowania touch → actions.
- [x] Usunąć z required checks workflow Linux/Windows/macOS runtime.

### GitHub Actions iOS

- [x] Wybrać GitHub Actions jako jedyny system CI/CD.
- [x] Udokumentować graf jobów, artefakty i granicę podpisywania w `CI_IOS.md`.
- [x] Dodać `.github/workflows/ios-ci.yml`.
- [x] Ustawić jawny runner `macos-15`.
- [x] Wybrać stabilny Xcode dostępny na runnerze i sprawdzać jego wersję.
- [x] Logować wersje obrazu, Xcode, SDK, Clang i CMake.
- [ ] Dodać cache zależności zależny od Xcode, architektury i lockfile.
- [ ] Zabezpieczyć cache/workflow przed niezaufanym kodem z PR.
- [x] Dodać configure/build `ios-device`.
- [x] Dodać configure/build `ios-simulator`.
- [x] Wymusić deployment target `16.4` w obu buildach.
- [x] Dodać simulator launch smoke test.
- [x] Dodać test braku niezamierzonych zewnętrznych dylibów.
- [x] Dodać test architektury/platform każdego artefaktu.
- [ ] Dodać test listy statycznych pluginów OSG.
- [ ] Dodać test kompilacji shaderów profilu iOS.
- [x] Dodać niesygnowany archive/IPA bez sekretów.
- [x] Sprawdzić brak danych gry, certyfikatów i provisioning profiles.
- [ ] Publikować IPA, dSYM, manifest, SBOM, notices i sumy kontrolne.
- [x] Ustawić krótką retencję artefaktów PR.

### Device lab/manual

- [x] Utworzyć `DEVICE_MATRIX.md`.
- [x] Dodać fizyczne urządzenie z iOS 16.4+ do wymaganej macierzy.
- [x] Dodać formularz raportu urządzenia.
- [ ] Automatyzować instalację i zebranie logów, gdy infrastruktura pozwoli.
- [ ] Archiwizować crash reports i dSYM dla każdego RC.
- [ ] Archiwizować metryki FPS/RAM/thermal.
- [x] Dodać checklistę lifecycle.
- [ ] Dodać checklistę audio route.
- [ ] Dodać checklistę input.
- [ ] Dodać checklistę save/load.

**DoD fazy:** każdy RC ma zielone wymagane testy core, device/simulator build,
simulator smoke oraz kompletny wynik macierzy urządzeń z testem iOS 16.4.

---

## Faza 11 — G5: GitHub Release, SideStore i Xcode

### Decyzje kanału

- [x] Wybrać GitHub Releases jako kanał publikacji.
- [x] Wybrać SideStore jako główny kanał instalacji gotowego IPA.
- [x] Wybrać lokalny Xcode jako alternatywny kanał build/install.
- [x] Wyłączyć TestFlight, App Store i App Store Connect z zakresu.

### Bundle i bezpieczeństwo

- [ ] Spakować resources/defaults/shaders/Lua libs w read-only bundle.
- [ ] Dodać app icons, launch assets i wersjonowanie.
- [ ] Ustalić stabilny bundle ID dla forka.
- [ ] Potwierdzić minimalny system `16.4` w finalnym bundle.
- [ ] Dodać minimalne entitlements.
- [ ] Dodać wymagany privacy manifest.
- [ ] Potwierdzić brak nieużywanych uprawnień.
- [ ] Potwierdzić, że bundle nie zawiera danych Morrowinda.
- [ ] Potwierdzić, że logi nie ujawniają prywatnych ścieżek/danych użytkownika.
- [ ] Potwierdzić standardowy układ `Payload/OpenMW.app`.

### Licencje

- [ ] Utworzyć `LICENSES_IOS.md`.
- [ ] Dołączyć pełny tekst GPLv3 i notices.
- [ ] Opisać dostęp do corresponding source dla dokładnego buildu.
- [ ] Opublikować źródła portu i skrypty build zależności.
- [ ] Dołączyć notices wszystkich statycznie linkowanych bibliotek.
- [ ] Zamknąć konfigurację/licencję FFmpeg.
- [ ] Udokumentować prawa użytkownika do importowanych danych.
- [ ] Generować SBOM dla dokładnego tagu.
- [ ] Generować `SHA256SUMS` dla plików release.

### GitHub Release

- [ ] Dodać `.github/workflows/ios-release.yml`.
- [ ] Uruchamiać release z tagów `ios-v*` i ręcznego `workflow_dispatch`.
- [ ] Odtwarzać build z tagu zamiast kopiować przypadkowy artefakt PR.
- [ ] Publikować `OpenMW-iOS-unsigned.ipa`.
- [ ] Publikować osobno dSYM, manifest, SBOM, notices i sumy kontrolne.
- [ ] Dodać bazowy upstream SHA do manifestu i release notes.
- [ ] Dodać informację „game data not included”.
- [ ] Przygotować rollback i unieważnienie wadliwego release.

### SideStore i Xcode

- [ ] Zainstalować niesygnowane IPA przez SideStore na czystym urządzeniu.
- [ ] Potwierdzić pierwszy start i import własnych danych.
- [ ] Potwierdzić refresh/re-sign SideStore.
- [ ] Potwierdzić aktualizację do kolejnego IPA bez utraty save'ów.
- [ ] Potwierdzić zachowanie config i zaimportowanych danych po aktualizacji.
- [ ] Wykryć/opisać skutki zmiany bundle ID i kontenera.
- [ ] Zbudować dokładny tag lokalnie w Xcode.
- [ ] Zainstalować build Xcode z Team użytkownika.
- [ ] Opisać Developer Mode i automatyczne zarządzanie signingiem.
- [ ] Opisać ograniczenia Personal Team i okresowe odnawianie profilu.
- [ ] Opublikować instrukcję instalacji, importu i troubleshooting.

**DoD/G5:** GitHub Release zawiera powtarzalne, niesygnowane IPA i komplet
źródeł/licencji; instalacja, refresh oraz aktualizacja działają przez SideStore,
a dokładny tag buduje się i instaluje przez Xcode użytkownika.

---

## Faza 12 — utrzymanie długowiecznego forka

### Strategia branchy

- [ ] Utrzymywać `master` jako czyste lustro `upstream/master`.
- [ ] Utrzymywać port na `ios/main`.
- [ ] Tworzyć małe `ios/<obszar>-<zadanie>` branche.
- [ ] Nie otwierać PR do `OpenMW/openmw`.
- [ ] Nie włączać push URL upstreamu.

### Synchronizacja

- [ ] Ustalić zasady selektywnego przyjmowania zmian upstream według wartości
  dla iOS.
- [ ] Zapisywać bazowy upstream SHA po każdym sync.
- [ ] Rozwiązywać konflikty w osobnym branchu `ios/sync-*`.
- [ ] Uruchamiać wymagane testy core/iOS po sync.
- [ ] Monitorować szczególnie CMake, SDLUtil, OSG, files i engine.
- [ ] Preferować najprostsze rozwiązanie iOS, nawet jeśli łamie inną platformę.
- [ ] Aktualizować zależności wraz z hashami i licencjami.
- [ ] Aktualizować device matrix po nowych iOS/Xcode.
- [ ] Aktualizować roadmapę w każdym merge.
- [ ] Kwartalnie usuwać nieaktualne workaroundy.
- [ ] Prowadzić changelog różnic forka wobec upstream.

**DoD fazy:** fork świadomie przyjmuje tylko wartościowe zmiany upstream bez
regresji iOS, a żaden workflow nie wysyła commitów z powrotem do OpenMW.
