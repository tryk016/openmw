# Port OpenMW na iOS

Ten katalog jest centrum dokumentacji portu `OpenMW/openmw` na iOS rozwijanego
wyłącznie w forku [`tryk016/openmw`](https://github.com/tryk016/openmw).
Nie planujemy wysyłać commitów ani pull requestów do `OpenMW/openmw`.

## Stan analizy

- Data analizy: 2026-07-20.
- Punkt odniesienia upstreamu: `82c6847402323e140794cf1f940b68cf3165eaea`.
- Wersja deklarowana przez upstream: `0.52.0`.
- Branch dokumentacyjny: `codex/ios-port-plan`.
- Status decyzji: **port warunkowo wykonalny; wymagany timeboxowany PoC
  renderingu na fizycznym urządzeniu**.

## Stałe założenia produktu

- Jedyną wspieraną platformą jest iOS/iPadOS **16.4 lub nowszy**.
- Kompatybilność z Linuxem, Windowsem, macOS i Androidem nie jest celem. Możemy
  ją świadomie łamać, jeżeli upraszcza to lub poprawia port iOS.
- Buildy device/simulator i niesygnowane IPA tworzy GitHub Actions.
- Kod i artefakty wydajemy wyłącznie przez GitHub.
- Użytkownik podpisuje i instaluje aplikację przez SideStore albo lokalny Xcode.
- TestFlight i publiczny App Store są poza zakresem.
- Aplikacja nie zawiera danych gry. Użytkownik importuje własne, legalnie
  posiadane pliki Morrowinda.

Pełne konsekwencje tej decyzji zapisuje
[ADR-0002-IOS-ONLY-SCOPE.md](ADR-0002-IOS-ONLY-SCOPE.md).

## Wniosek

OpenMW da się przenieść na iOS, ale nie jest to zwykły cross-compile.
Większość logiki gry jest przenośnym C++20. Główne ryzyka są skupione w
warstwie platformowej:

1. OpenSceneGraph i MyGUI oczekują desktopowego OpenGL, a iOS udostępnia
   OpenGL ES (zdeprecjonowany) albo Metal.
2. Obecne bloki `APPLE` w CMake opisują macOS, nie iOS.
3. Ścieżki plików używają implementacji macOS i nie respektują kontenera iOS.
4. Zdarzenia dotyku i lifecycle są odbierane przez SDL, ale świadomie
   ignorowane.
5. LuaJIT nie powinien być używany jako JIT na iOS; pierwsza wersja ma używać
   interpretera Lua.
6. Publiczny runner CI nie może potwierdzić zachowania GPU, pamięci, termiki ani
   SideStore na fizycznym urządzeniu, więc wymagane są testy manualne.

Rekomendowany start to GL4ES nad kontekstem OpenGL ES na prawdziwym urządzeniu,
z konserwatywnym baseline'em ES 2 i osobnym testem ES 3.0. OpenMW ma już opcję
`OPENMW_GL4ES_MANUAL_INIT`, a GL4ES dokumentuje build dla iOS.
Równolegle należy sprawdzić wariant GL4ES + ANGLE/Metal jako drogę wyjścia z
zależności od zdeprecjonowanego API Apple. Pełny rewrite renderera do Metal lub
VulkanSceneGraph nie jest rozsądnym pierwszym krokiem.

Nie utrzymujemy desktopowych ścieżek tylko po to, aby ograniczyć deltę względem
upstreamu. Jeżeli prostszy target, backend lub adapter iOS wymaga usunięcia
nieprzenośnego kodu, stabilność iOS ma pierwszeństwo.

## Realistyczne poziomy celu

| Cel | Ocena | Warunek |
|---|---|---|
| Headless/core skompilowany dla arm64 | wysoka wykonalność | statyczne zależności i nowy preset CMake |
| Pierwsza klatka/menu na urządzeniu | średnia wykonalność | działający OSG + GL4ES + statyczne pluginy |
| Grywalny vertical slice | średnia wykonalność | dotyk, audio, sandbox, lifecycle i ograniczony profil grafiki |
| Niesygnowane IPA z GitHub Actions | wysoka po G0 | hermetyczny build, packaging i komplet licencji |
| Stabilna wersja SideStore/Xcode | średnia wykonalność | testy urządzeń, import danych, re-sign i aktualizacje |

Szacunek orientacyjny dla zespołu znającego C++, iOS i grafikę:

- techniczny PoC: 6–10 tygodni;
- grywalna alfa: 4–8 miesięcy;
- stabilny release sideload: 9–18 osobomiesięcy.

Szacunek ma duży przedział, ponieważ wynik pierwszego spike'u renderingu może
zmienić architekturę i zakres.

## Dokumenty

- [FEASIBILITY.md](FEASIBILITY.md) — szczegółowa ocena wykonalności, ryzyk i
  zależności.
- [ADR-0001-RENDERING.md](ADR-0001-RENDERING.md) — proponowana decyzja o
  ścieżce renderingu.
- [ADR-0002-IOS-ONLY-SCOPE.md](ADR-0002-IOS-ONLY-SCOPE.md) — zaakceptowany
  zakres iOS-only, iOS 16.4 i sideload.
- [CI_IOS.md](CI_IOS.md) — projekt GitHub Actions, artefaktów i podpisywania po
  stronie użytkownika.
- [BUILDING_IOS.md](BUILDING_IOS.md) — przypięty toolchain G0, GitHub Actions,
  lokalny Xcode i debugowanie.
- [DEVICE_MATRIX.md](DEVICE_MATRIX.md) — wymagana macierz i format dowodów z
  fizycznych urządzeń.
- [G0_EVIDENCE.md](G0_EVIDENCE.md) — trwały zapis wyników CI, artefaktów i
  brakującego dowodu fizycznego urządzenia.
- [DEPENDENCY_LOCK.md](DEPENDENCY_LOCK.md) — piny źródeł, hashe, format
  artefaktów, cache offline i polityka licencji zależności iOS.
- [PROJECT_MAP.md](PROJECT_MAP.md) — mapa repozytorium i zależności między
  subsystemami.
- [ROADMAP.md](ROADMAP.md) — kanoniczna, szczegółowa lista prac z checkboxami.
- [TEST_PLAN.md](TEST_PLAN.md) — bramki jakości, macierz urządzeń i testy.
- [FORK_WORKFLOW.md](FORK_WORKFLOW.md) — bezpieczna praca tylko w forku.

## Zasada aktualizacji

`ROADMAP.md` jest źródłem prawdy o stanie portu.

- Każdy zakończony, przetestowany punkt zmieniamy z `[ ]` na `[x]` w tym samym
  commicie co implementacja.
- Zadania zablokowane pozostają niezaznaczone i dostają dopisek `BLOCKED` z
  linkiem do decyzji albo problemu.
- Nie odhaczamy samego napisania kodu. Punkt jest gotowy dopiero po spełnieniu
  kryterium odbioru i zapisaniu dowodu testu.
- Po każdym merge do `ios/main` aktualizujemy licznik fazy i sekcję „Ostatnia
  aktualizacja” w roadmapie.

## Dokumentacja, która musi powstać wraz z implementacją

Poniższe dokumenty są wymagane, ale nie powinny być tworzone „na zapas” bez
działającego kodu:

- `DEPENDENCY_LOCK.md` — wersje, hashe, licencje i ustawienia każdego
  artefaktu/xcframework;
- `IOS_ARCHITECTURE.md` — shell aplikacji, wątki, lifecycle, dane i rendering;
- `DATA_IMPORT.md` — legalny import własnych danych Morrowinda i obsługa
  security-scoped URLs;
- `CONTROLS.md` — dotyk, kontroler, klawiatura, mysz i dostępność;
- `DEBUGGING_IOS.md` — logi, symbole, crash reporty, GPU capture i typowe awarie;
- `PERFORMANCE_BUDGET.md` — budżet RAM, storage, czas startu, frametime i
  termika;
- `RELEASING_IOS.md` — GitHub Releases, SideStore, Xcode, aktualizacja i
  rollback;
- `LICENSES_IOS.md` — GPLv3, corresponding source, SBOM, FFmpeg i prawa do
  danych gry;
- `SUPPORTED_FEATURES_IOS.md` — jawna macierz różnic wobec desktopu i wsparcia
  modów.

## Źródła zewnętrzne

- [SDL2: iOS](https://wiki.libsdl.org/SDL2/README-ios)
- [GL4ES: kompilacja dla iOS](https://github.com/ptitSeb/gl4es/blob/master/COMPILE.md#ios)
- [Apple: OpenGL ES jest zdeprecjonowany](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/)
- [Apple: dostęp do katalogów przez document picker](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [Apple: uruchamianie aplikacji na urządzeniu](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [SideStore](https://docs.sidestore.io/)
- [Referencyjny, zakończony port Android](https://gitlab.com/OpenMW/openmw-android)
