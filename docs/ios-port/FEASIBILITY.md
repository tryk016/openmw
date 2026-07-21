# Ocena wykonalności portu OpenMW na iOS

## Ocena końcowa

**GO dla ograniczonego PoC, NO-GO dla deklaracji gotowego produktu przed
przejściem bramki renderingu, powtarzalnego CI i testu na minimalnym iOS 16.4.**

Silnik gry, formaty danych, mechanika, fizyka i większość warstwy zasobów są
przenośnym C++. Port blokują nie reguły gry, lecz integracja renderera,
pakietowanie zależności, model plików iOS oraz UX urządzenia mobilnego.

Najrozsądniejsza kolejność to:

1. skompilować core i statyczne zależności dla `iphoneos/arm64`;
2. uruchomić minimalny shell SDL;
3. udowodnić OSG + GL4ES na fizycznym urządzeniu;
4. dopiero potem inwestować w importer danych, dotyk i pełny gameplay;
5. zbudować niesygnowane IPA w GitHub Actions;
6. potwierdzić instalację, refresh i aktualizację przez SideStore oraz Xcode.

Zakres jest świadomie iOS-only. Nie utrzymujemy kompatybilności runtime ani
zielonego CI dla Linuxa, Windowsa, macOS i Androida kosztem iOS. Pozwala to
usunąć desktopowe gałęzie builda, aplikacje Qt i abstrakcje bez wartości dla
docelowego portu. Minimalny deployment target to iOS/iPadOS 16.4.

## Co już pomaga

- OpenMW ma rozdzielone biblioteki `components` i `openmw-lib`, więc aplikację
  iOS można zbudować bez narzędzi Qt i OpenMW-CS.
- SDL2 oficjalnie wspiera UIKit, kontrolery, dotyk, lifecycle i audio na iOS.
- `components/sdlutil/gl4esinit.cpp` oraz
  `OPENMW_GL4ES_MANUAL_INIT` stanowią istniejący punkt integracji GL4ES.
- `apps/openmw/androidmain.cpp` pokazuje, jak mobilny wrapper może wstrzykiwać
  ścieżki i wirtualny kontroler.
- `components/sdlutil/sdlinputwrapper.cpp` już odbiera zdarzenia dotyku,
  background/foreground i low-memory.
- Build pozwala wyłączyć launcher, wizard, OpenMW-CS, importery i narzędzia.
- OSG, MyGUI, Bullet, Recast, SQLite i wiele bibliotek można linkować
  statycznie.
- `USE_LUAJIT=OFF` pozwala zrezygnować z JIT.

## Co obecnie nie działa na iOS

### Build i pakiet aplikacji

- `if(APPLE)` w głównym CMake zakłada macOS.
- Ścieżka bundle używa `OpenMW.app/Contents/Resources`, podczas gdy bundle iOS
  ma inny układ.
- Kod linkuje `Cocoa` i `IOKit`; iOS potrzebuje między innymi UIKit,
  Foundation, GameController, AVFoundation/AudioToolbox i odpowiedniego
  frameworku grafiki.
- Domyślnie budowane są aplikacje desktopowe i Qt. Preset iOS musi je jawnie
  wyłączyć.
- `apps/openmw/main.cpp` używa desktopowego `main`; shell iOS musi działać
  zgodnie z kontraktem `SDL_main`/`SDL_UIKitRunApp`.
- Fizyczne urządzenie i symulator są różnymi platformami binarnymi, nawet gdy
  oba używają arm64. Artefakty trzeba pakować jako osobne slice'y lub
  XCFrameworks.
- Przypięty fork OSG zawiera historyczną ścieżkę iPhone, ale zakłada stary SDK
  i wybiera macOS-owe nagłówki dla profilu GL2. Nie jest gotowym rozwiązaniem;
  wymaga aktualizacji toolchainu i integracji nagłówków GL4ES.
- `CheckLuaCustomAllocator.cmake` wykonuje `try_run`, którego binarium arm64
  iOS nie uruchomi się na hoście. Wynik trzeba ustawić dla cross-build albo
  zmienić test na compile-only.

### Rendering

- `extern/CMakeLists.txt` ustawia fork OSG na `OPENGL_PROFILE=GL2`.
- `components/myguiplatform/myguirendermanager.cpp` używa starego fixed
  function pipeline (`glEnableClientState`, `glVertexPointer`).
- Shadery zgodności zaczynają się od `#version 120`, a shadery core od
  `#version 430`; nie są shaderami GLSL ES.
- Renderer korzysta z FBO, wielokrotnych render targetów, rozszerzeń,
  postprocessingu, compute shaderów i zachowań desktopowego OpenGL.
- iOS nie udostępnia desktopowego OpenGL. OpenGL ES został zdeprecjonowany w
  iOS 12, a długoterminową technologią Apple jest Metal.

GL4ES może przetłumaczyć znaczną część starego desktopowego OpenGL na GLES i
ma oficjalną instrukcję kompilacji na iOS. Nie gwarantuje jednak pełnej
zgodności wszystkich ścieżek OpenMW ani dobrej wydajności. Dlatego pierwszy
milestone musi sprawdzić realną scenę, a nie tylko pusty kontekst.
Konserwatywny baseline PoC to GLES 2 z `DEFAULT_ES=2`; GLES 3.0 należy zbadać
osobno. Obecna gałąź ustawiająca `OPENMW_GLES_VERSION=3` żąda wersji 3.2,
której iOS nie udostępnia.

### System plików i dane gry

- `components/files/fixedpath.hpp` wybiera `MacOsPath` dla każdego
  `__APPLE__`.
- `MacOsPath` używa `/Library/...`, `$HOME`, `getpwuid` i układu bundle macOS.
- Aplikacja iOS może zapisywać tylko w swoim kontenerze, chyba że użytkownik
  nada dostęp przez document picker.
- Zasoby aplikacji w bundle są tylko do odczytu.
- Dane Morrowinda nie mogą być dodane do repo ani IPA. Użytkownik musi
  zaimportować własną, legalną kopię.
- Security-scoped URL wymaga rozpoczęcia dostępu, opcjonalnego bookmarka i
  poprawnego zakończenia dostępu.

Rekomendacja dla wersji pierwszej: skopiować wybrany katalog danych do
`Application Support/GameData`, pokazać postęp i sprawdzić wymagane pliki.
Tryb pracy bezpośrednio na zewnętrznym providerze plików można dodać później,
ponieważ ma gorszą przewidywalność opóźnień i dostępności.

### Lifecycle, pamięć i wątki

`sdlinputwrapper.cpp` ignoruje obecnie `SDL_APP_*` i wszystkie
`SDL_FINGER*`. To jest bezpieczne na desktopie, ale błędne na iOS.

Port musi:

- zatrzymać symulację i rendering przed przejściem w background;
- szybko zapisać stan lub wymusić bezpieczny checkpoint;
- przerwać/odtworzyć audio po rozmowie, Siri lub zmianie urządzenia;
- zwolnić cache przy low-memory;
- obsłużyć utratę/odtworzenie kontekstu lub powierzchni;
- nie zakładać, że proces dostanie czas na klasyczne zamknięcie;
- ograniczyć liczbę wątków i ich priorytety do profilu urządzenia.

### Sterowanie i UX

- Samo mapowanie dotyku na mysz wystarczy do części menu, ale nie do wygodnej
  rozgrywki.
- Gra oczekuje względnego ruchu myszy, wielu klawiszy i hover.
- Pierwszy grywalny zakres powinien wymagać kontrolera MFi/standardowego
  gamepada.
- Overlay dotykowy należy dodać po działającym vertical slice z kontrolerem.
- UI MyGUI wymaga skalowania do punktów, safe area, notcha, orientacji i
  klawiatury ekranowej.

### Audio i wideo

- OpenMW korzysta z OpenAL i FFmpeg.
- Najmniej inwazyjna ścieżka to statyczny OpenAL Soft oraz statyczny FFmpeg
  z minimalnym zestawem kodeków.
- Należy zintegrować `AVAudioSession`, przerwania audio, route changes,
  wyciszenie i powrót z backgroundu.
- Konfigurację FFmpeg trzeba ocenić pod kątem LGPL/GPL, patentów kodeków i
  rozmiaru aplikacji.

### Lua, mody i wykonywalny kod

- LuaJIT z aktywnym JIT jest nieakceptowalną bazą dla iOS. Używamy
  `USE_LUAJIT=OFF`, dopóki osobny przegląd nie zatwierdzi trybu interpreter-only.
- OpenMW ładuje skrypty Lua i skrypty Morrowinda z danych/modów.
- Z technicznego punktu widzenia interpreter nie potrzebuje generowania
  natywnego kodu.
- Sideload może wspierać mody i skrypty bez tworzenia osobnego profilu App
  Store. Nadal obowiązują limity pamięci, bezpieczeństwo importu i brak
  generowania natywnego kodu.

### Licencje i dystrybucja

- OpenMW jest na GPLv3.
- Każdy binarny GitHub Release musi wskazywać corresponding source dokładnego
  tagu, pełny tekst GPLv3 i notices statycznie linkowanych zależności.
- Repo, cache CI, IPA i release nie mogą zawierać danych Morrowinda.
- Publiczny build jest niesygnowany. SideStore podpisuje go certyfikatem
  użytkownika; lokalny Xcode używa Team wybranego przez użytkownika.
- Prywatne certyfikaty, profile, Apple ID i SideStore pairing files nie trafiają
  do GitHub Actions.
- Publiczny App Store, App Store Connect i TestFlight są poza zakresem, więc
  zasady App Review nie są bramką projektu.
- Osoba instalująca nadal musi przestrzegać zasad własnego konta Apple i
  okresowo odnawiać profil, jeżeli używa Personal Team.

## Macierz zależności

| Zależność | Stan iOS | Plan |
|---|---|---|
| CMake/Xcode | dobry | osobne presety device/simulator i target bundle |
| SDL2 | dobry | statyczny build/XCFramework, UIKit main |
| OpenMW OSG fork | krytyczny | statyczny GLES build, GL4ES, minimalne pluginy |
| GL4ES | ryzykowny, ale obiecujący | spike na urządzeniu; ręczna inicjalizacja |
| ANGLE | opcja zapasowa | spike GLES-over-Metal po PoC GL4ES |
| MyGUI | średni | GL4ES albo renderer shaderowy GLES |
| Bullet (double precision) | dobry | statyczny arm64, test deterministyczności |
| Recast/Detour | dobry | statyczny build, budżet wątków/pamięci |
| Boost | dobry | `program_options`, `iostreams` bez filtrów i header-only `geometry` |
| Lua | dobry | PUC Lua, bez JIT |
| ICU | średni | host tools + biblioteki target, ograniczenie danych |
| SQLite | dobry | systemowa biblioteka albo statyczna amalgamacja |
| yaml-cpp/LZ4/zlib | dobry | statyczne biblioteki |
| FreeType/libpng/libjpeg | dobry | statyczne, ograniczyć pluginy OSG |
| OpenAL | średni | preferowany OpenAL Soft + `AVAudioSession` |
| FFmpeg | średni | minimalny statyczny build i audyt licencji |
| Qt | zbędny dla runtime | wyłączyć launcher, wizard i OpenMW-CS |
| libunshield/collada_dom | zbędny w MVP | wyłączyć wizard i plugin DAE |

## Rejestr głównych ryzyk

| ID | Ryzyko | Prawdopodobieństwo | Wpływ | Redukcja |
|---|---|---:|---:|---|
| R1 | GL4ES/OSG nie renderuje poprawnej sceny | wysokie | krytyczny | timeboxowany PoC i bramka stop/go |
| R2 | Zbyt niska wydajność lub termika | średnie/wysokie | wysoki | profil grafiki mobile, budżety, testy urządzeń |
| R3 | Limity pamięci przy dużych modach | wysokie | wysoki | streaming, limity cache, low-memory handling |
| R4 | Re-sign zmienia bundle ID/kontener i odcina dane | średnie | wysoki | stabilny identyfikator, test refresh/update i instrukcja backupu |
| R5 | Runner GitHub nie mieści builda zależności | średnie | wysoki | cache po lockfile, sekwencyjne slice'y, kontrola storage i czasu |
| R6 | Zależności nie budują się statycznie | średnie | średni | hermetyczny dependency build i wersje przypięte hashami |
| R7 | Background niszczy niezapisany stan | wysokie bez zmian | wysoki | natychmiastowe lifecycle callbacks i checkpoint |
| R8 | Dotyk daje zły UX | wysokie | średni/wysoki | gamepad-first, później iteracyjny overlay |
| R9 | Import danych jest wolny/awaryjny | średnie | średni | kopiowanie do sandboxu, walidacja i resume |
| R10 | Selektywny sync pomija ważną poprawkę upstreamu | średnie | wysoki | rejestr bazowego SHA, przegląd changelogu i testy iOS; duża delta jest akceptowana |

## Kryteria zakończenia PoC

PoC jest pozytywny tylko wtedy, gdy na fizycznym urządzeniu:

- aplikacja startuje z prawidłowo podpisanego bundle;
- działa statyczny SDL + OSG + GL4ES;
- wczytuje statycznie pluginy DDS/PNG/JPEG/TGA/FreeType;
- wyświetla menu, a następnie scenę z terenem, NIF, aktorem i UI;
- zapis i ponowne wczytanie gry działa w sandboxie;
- wejście kontrolera działa;
- background/foreground nie powoduje crasha ani aktywnej symulacji w tle;
- 20-minutowa sesja nie przekracza ustalonego budżetu pamięci i nie ma
  nieograniczonego wzrostu;
- wszystkie braki renderingu są sklasyfikowane jako naprawialne lub świadomie
  wyłączone w profilu iOS.

Jeśli GL4ES nie przejdzie tej bramki, kończymy tę ścieżkę i wykonujemy osobny
spike GL4ES + ANGLE/Metal. Jeśli także on nie przejdzie, port w obecnej
architekturze jest NO-GO; rewrite renderera wymaga nowego projektu i estymacji.

## Dowody w kodzie upstream

- `CMakeLists.txt:17` — opcja ręcznej inicjalizacji GL4ES.
- `CMakeLists.txt:22-71` — `APPLE` i bundle skonfigurowane pod macOS.
- `CMakeLists.txt:267-271` — wymagany desktopowy OpenGL.
- `CMakeLists.txt:489-500` — SDL2, OpenAL i wybór LuaJIT/Lua.
- `extern/CMakeLists.txt` — OSG z profilem GL2 i przypięte źródła zależności.
- `apps/openmw/CMakeLists.txt` — `openmw-lib`, mobilny wariant Android i
  macOS-owe frameworki.
- `apps/openmw/engine.cpp:500-691` — tworzenie okna/kontekstu SDL OpenGL.
- `components/sdlutil/sdlgraphicswindow.cpp` — profil GLES i inicjalizacja
  GL4ES.
- `cmake/CheckLuaCustomAllocator.cmake` — hostowy `try_run` blokujący
  cross-compile bez override.
- `components/sdlutil/sdlinputwrapper.cpp:213-235` — ignorowane touch i
  lifecycle.
- `components/files/fixedpath.hpp` — każde `__APPLE__` wybiera `MacOsPath`.
- `components/myguiplatform/myguirendermanager.cpp` — fixed function OpenGL.
- `files/shaders/compatibility` i `files/shaders/core` — GLSL 120/430, nie
  GLSL ES.

## Źródła

- [Apple OpenGL ES Programming Guide](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/)
- [Apple: Migrating OpenGL code to Metal](https://developer.apple.com/documentation/metal/migrating-opengl-code-to-metal)
- [Apple: document picker i dostęp do katalogów](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [Apple: uruchamianie aplikacji na urządzeniu](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- [Apple: Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account/)
- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [SideStore](https://docs.sidestore.io/)
- [SDL2 README iOS](https://wiki.libsdl.org/SDL2/README-ios)
- [GL4ES COMPILE.md](https://github.com/ptitSeb/gl4es/blob/master/COMPILE.md#ios)
- [ANGLE — iOS/Metal](https://github.com/google/angle)
- [OpenMW Android wrapper](https://gitlab.com/OpenMW/openmw-android)
- [OpenMW MR: ręczna inicjalizacja GL4ES](https://gitlab.com/OpenMW/openmw/-/merge_requests/626)
- [OpenMW issue: możliwe ścieżki GL na Apple](https://gitlab.com/OpenMW/openmw/-/issues/6231)
