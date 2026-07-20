# Plan testów portu OpenMW na iOS

## Cel

Testy mają odpowiedzieć kolejno na pięć pytań:

1. Czy toolchain tworzy poprawny bundle iOS?
2. Czy renderer pokazuje realną scenę OpenMW?
3. Czy podstawowy gameplay, save i lifecycle są poprawne?
4. Czy sterowanie mobilne i wydajność nadają się do dłuższej gry?
5. Czy GitHub Release daje poprawne IPA do SideStore oraz powtarzalny build
   lokalny dla Xcode?

GitHub Actions wykonuje właściwy build na runnerze macOS z Xcode. Co najmniej
jedno fizyczne urządzenie z iOS 16.4+ jest wymagane już dla G0. Urządzenie z
dokładnym iOS 16.4 jest obowiązkową dolną bramką kompatybilności przed G5; gdy
nie jest dostępne w G0, deployment target potwierdzają kontrole Mach-O i
bundle.

## Poziomy testów

### 1. Core unit/component tests

Uruchamiane w środowisku Apple w GitHub Actions:

- parsowanie ESM/BSA/NIF;
- VFS i ścieżki;
- serializacja i save;
- Lua/MWScript;
- settings/config;
- navmesh i SQLite;
- resource/shader helpers;
- nowe czyste funkcje adapterów iOS.

Nie wymagamy uruchamiania tych testów na Linuxie ani Windowsie. Logikę wyboru
katalogów i lifecycle state machine wydzielamy tak, by była testowalna bez
fizycznego urządzenia.

### 2. Cross-build validation

Dla `iphoneos` i `iphonesimulator`:

- CMake configure bez nierozwiązanych `try_run`;
- pełny compile i link;
- kontrola architektury każdego `.a`;
- kontrola platformy Mach-O;
- kontrola finalnych dylib dependencies;
- kontrola statycznej rejestracji OSG plugins;
- kontrola resources w bundle;
- archive bez sekretów w buildzie PR.

Przykładowe narzędzia na runnerze Apple:

```sh
file path/to/lib.a
lipo -info path/to/lib.a
otool -l path/to/binary
otool -L path/to/binary
nm -u path/to/binary
```

### 3. Simulator smoke

Symulator ma szybko wykrywać:

- start/crash;
- brak zasobów;
- problemy z config i read-only bundle;
- podstawowy importer z test fixture;
- generowanie UI;
- lifecycle callbacks;
- podstawowy input.

Symulator nie jest źródłem prawdy dla:

- zgodności GPU/GL4ES;
- wydajności i termiki;
- limitów pamięci/jetsam;
- audio route;
- fizycznych kontrolerów;
- podpisywania, refreshu i aktualizacji przez SideStore.

### 4. Physical device integration

Każdy milestone od G1 wymaga fizycznego urządzenia:

- instalacja podpisanego bundle;
- SDL/GLES/GL4ES/OSG;
- touch, controller, sensors;
- AVAudioSession;
- Files/document picker;
- background/foreground;
- memory pressure;
- Instruments i thermal state.

### 5. End-to-end gameplay

Scenariusze używają legalnie posiadanych danych testera. Dane Morrowinda nie są
artefaktem CI ani repozytorium.

## Macierz urządzeń

Dokładne modele zostaną przypisane w `DEVICE_MATRIX.md`. Minimalny zakres:

| Klasa | Cel |
|---|---|
| fizyczny iPhone/iPad z iOS 16.4 | minimalny system, start, import, gameplay i lifecycle |
| najstarszy wspierany iPhone | limit RAM/GPU/CPU, 30 FPS |
| współczesny iPhone | profil 60 FPS i wysoka rozdzielczość |
| iPad | layout, klawiatura, mysz, multitasking |
| urządzenie z inną rodziną GPU niż główny tester | regresje shaderów/drivera |
| symulator Apple Silicon | szybki smoke CI |

Każdy raport zawiera:

- model i identyfikator urządzenia;
- wersję iOS;
- wersję Xcode/SDK;
- commit forka i bazowy commit upstreamu;
- profil grafiki;
- rozdzielczość/render scale;
- źródło danych i lista aktywnych modów bez ich redystrybucji;
- wynik, log, screenshot i metryki.

## Bramki akceptacyjne

### G0 — toolchain

- czysty checkout w GitHub Actions konfiguruje device i simulator;
- wszystkie warianty deklarują deployment target `16.4`;
- pusty C++20 target startuje w obu;
- ten sam bundle instaluje się, startuje i przechodzi podstawowy lifecycle na
  fizycznym urządzeniu z iOS 16.4+;
- debug symbols działają;
- finalny app używa tylko zatwierdzonych bibliotek systemowych/statycznych.

### G1 — rendering

Na fizycznym urządzeniu:

- log pokazuje oczekiwany backend GLES/GL4ES;
- wszystkie wymagane pluginy OSG są dostępne;
- kompilują się shadery profilu `ios-low`;
- działa tekstura PNG/JPEG/DDS i font;
- menu MyGUI jest czytelne;
- scena zawiera teren, NIF, aktora, UI, niebo i wodę;
- brak migotania, czarnej sceny i stale rosnącej liczby błędów GL;
- aplikacja działa 20 minut;
- screenshoty są porównane z desktopem;
- pomiar FPS/RAM/thermal jest zapisany.

### G2 — gameplay kontrolerem

- import danych i ponowny start;
- nowa gra;
- tutorial Seyda Neen;
- dialog i inventory;
- interior/exterior;
- walka;
- save, zamknięcie i load;
- MWScript i Lua;
- muzyka/SFX;
- gamepad disconnect/reconnect;
- background/foreground;
- sesja 60 minut bez crasha i uszkodzenia save.

### G3 — touch-only

Powtarza G2 bez fizycznego kontrolera:

- jednoczesny ruch i kamera;
- activate/use/jump/combat;
- menu i quick slots;
- drag/drop inventory;
- text input;
- layout w safe area;
- iPhone i iPad.

### G4 — stabilność i wydajność

- 60 minut na najstarszym urządzeniu;
- brak memory kill/jetsam;
- resident memory w budżecie;
- brak nieograniczonego wzrostu cache;
- akceptowalny frametime i 1% low;
- brak krytycznego thermal throttling;
- lifecycle x20;
- zmiana komórki x50;
- save/load x20;
- import dużego zestawu danych z kontrolą wolnego miejsca.

### G5 — release

- GitHub Actions odtwarza build z dokładnego tagu;
- powstaje niesygnowane `OpenMW-iOS-unsigned.ipa`;
- `otool -L` bez niespakowanych bibliotek;
- komplet dSYM i symbolizacja crasha;
- privacy manifest i entitlements sprawdzone;
- brak danych Bethesdy;
- corresponding source dla dokładnego buildu;
- SBOM, notices i `SHA256SUMS`;
- manifest zawiera commit forka, bazowy upstream SHA, Xcode/SDK i zależności;
- brak certyfikatów, provisioning profiles i danych Apple ID w CI/artifactach;
- IPA instaluje się przez SideStore na czystym urządzeniu;
- refresh i aktualizacja SideStore zachowują importowane dane, config i save'y;
- lokalny checkout tagu buduje się i instaluje przez Xcode z Team użytkownika;
- instrukcja opisuje Developer Mode, Personal Team i okresowe odnawianie
  profilu;
- GitHub Release zawiera instrukcję instalacji i informację, że plików gry nie
  dołączono.

## Szczegółowe scenariusze

### Rendering

- menu i loading screen;
- interior z wieloma światłami;
- exterior w dzień/noc/deszcz/mgłę;
- water/reflection/refraction w profilu iOS;
- terrain LOD i szybki ruch;
- NPC/creature animacje;
- particles i transparenty;
- mapy local/global;
- screenshot;
- orientacja i drawable resize;
- opcjonalne funkcje włączane pojedynczo:
  - cienie;
  - postprocessing;
  - MSAA;
  - groundcover.

### Pliki i import

- brak wybranego folderu;
- anulowanie picker;
- brak `Morrowind.esm`;
- niekompletny zestaw danych;
- brak miejsca w trakcie kopiowania;
- utrata dostępu do provider;
- przerwany import i resume;
- ponowny import;
- ścieżki ze spacjami i znakami Unicode;
- różna wielkość liter nazw plików;
- cache wyłączony z backup;
- config/save zachowany po aktualizacji.

### Lifecycle

- Home z menu;
- Home w trakcie gry;
- Home w loading screen;
- blokada ekranu;
- rozmowa/Siri/audio interruption;
- foreground po 5 sekundach i po kilku minutach;
- memory warning w menu i świecie;
- proces zabity w background po wcześniejszym checkpoint;
- restart po crashu bez korupcji config/save.

### Input

- touch-emulated mouse vs prawdziwa mysz;
- multi-finger pointer identity;
- kontroler podłączony przed i po starcie;
- rozłączenie w walce;
- klawiatura ekranowa;
- klawiatura sprzętowa;
- mysz iPadOS;
- orientacja/gyro;
- zmiana układu przycisków i zapis ustawień.

### Audio/wideo

- speaker;
- headphones;
- Bluetooth;
- route change podczas gry;
- interruption i resume;
- silent mode;
- background;
- intro z audio;
- seek/EOF;
- wyłączone audio i brak FFmpeg jako kontrolowany profil diagnostyczny.

### Gameplay/save

- new game;
- manual save i quicksave;
- load po cold start;
- wejście do nowej komórki podczas preload;
- dialog/quest/journal;
- kradzież/handel/inventory;
- walka/magia/projectiles;
- pathfinding/navmesh;
- Lua permanent storage;
- mod bez natywnego kodu;
- save desktop → iOS i iOS → desktop, jeśli deklarujemy kompatybilność.

## Regresja obrazu

Referencja desktopowa i screenshot iOS muszą używać:

- tego samego save;
- tych samych danych/modów;
- stałej pory, pogody i pozycji kamery;
- tego samego profilu funkcji, na ile to możliwe;
- wyłączonych elementów niedeterministycznych.

Porównanie pikselowe ma tolerancję i maski dla znanych różnic. Sam brak crasha
nie wystarcza — błędne światła, alpha, fog albo kolejność transparentów mogą
zepsuć gameplay.

## Testy negatywne i bezpieczeństwo

- bundle pozostaje read-only;
- wszystkie zapisy trafiają do zatwierdzonych katalogów;
- nie ma runtime `dlopen` wymaganych pluginów;
- nie ma JIT ani writable+executable pages;
- aplikacja nie pobiera natywnego kodu;
- import odrzuca symlinki/ścieżki wychodzące poza wybrany zakres, jeśli dane są
  kopiowane;
- logi nie zawierają tokenów, bookmark data ani zbędnych danych osobowych;
- usuwanie danych wymaga potwierdzenia i nie wychodzi poza kontener.

## Format dowodu testowego

```markdown
### TEST-ID — nazwa

- Build: `<fork SHA>` / upstream `<SHA>`
- Xcode/SDK:
- Urządzenie/iOS:
- Profil:
- Dane/mody:
- Kroki:
- Oczekiwane:
- Wynik: PASS | FAIL | BLOCKED
- Metryki:
- Log/screenshot/crash:
- Data/tester:
```

Checkbox w roadmapie można zaznaczyć dopiero po dołączeniu takiego dowodu do
PR, issue albo katalogu wyników release.
