# ADR-0002: Fork iOS-only i dystrybucja przez sideload

**Status:** Accepted
**Data:** 2026-07-20
**Decydent:** właściciel forka `tryk016/openmw`

## Kontekst

Fork powstaje po to, aby uruchamiać OpenMW na iPhone'ach i iPadach. Nie jest
celem utrzymanie jednego kodu działającego równocześnie na Linuxie, Windowsie,
macOS, Androidzie i iOS. Zachowanie kompatybilności z innymi platformami
zwiększałoby koszt zmian w CMake, SDL, systemie plików, renderingu i pakietowaniu,
a nie daje wartości docelowemu produktowi.

Publiczny App Store i TestFlight nie są kanałami projektu. Kod i buildy będą
publikowane na GitHubie. Użytkownik sam podpisuje i instaluje aplikację przez
SideStore albo buduje ją i uruchamia z Xcode. Dane gry nie są częścią aplikacji;
użytkownik importuje własne, legalnie posiadane pliki.

## Decyzja

1. Jedynym wspieranym runtime jest iOS/iPadOS **16.4 lub nowszy**.
2. Wspieramy `iphoneos/arm64` oraz `iphonesimulator/arm64`. Inne architektury
   symulatora mogą istnieć wyłącznie jako pomoc techniczna i nie są wymaganiem.
3. Możemy usuwać, zastępować albo upraszczać kod innych platform, gdy:
   - zmniejsza to koszt portu;
   - poprawia jakość lub wydajność iOS;
   - usuwa zależność nieprzenośną na iOS;
   - upraszcza build, testy albo utrzymanie.
4. Zielone buildy Linux/Windows/macOS/Android nie są bramką merge. Narzędzia
   hostowe mogą nadal istnieć, jeżeli są potrzebne do wygenerowania artefaktów
   iOS, ale nie stanowią wspieranego produktu.
5. CI/CD realizuje GitHub Actions na runnerach macOS. Wynikiem CI jest:
   - niesygnowany bundle/IPA do podpisania przez SideStore;
   - build symulatora;
   - symbole, manifest zależności, SBOM, notices i sumy kontrolne.
6. Certyfikaty, hasła Apple ID, pairing files i provisioning profiles
   użytkowników nie trafiają do repozytorium ani publicznego CI.
7. Release jest publikowany na GitHub Releases. Nie tworzymy workflow App Store
   Connect, TestFlight ani automatycznego notarization/upload do Apple.
8. Upstream służy jako źródło kodu i poprawek. Synchronizacja jest selektywna;
   zgodność z każdą nową wersją upstreamu nie ma pierwszeństwa przed stabilnością
   iOS.
9. Zmian portu nie wysyłamy do `OpenMW/openmw`.

## Rozważone opcje

### A. Zachowanie pełnej wieloplatformowości

| Wymiar | Ocena |
|---|---|
| Koszt implementacji | wysoki |
| Łatwość synchronizacji upstreamu | najlepsza |
| Szybkość dostarczenia iOS | niska |
| Wartość dla celu projektu | niska |

Zaletą byłaby mniejsza delta względem upstreamu. Ceną są warstwy abstrakcji,
macierze CI i kompromisy renderera, których ten fork nie potrzebuje.

### B. Inkrementalny fork iOS-only

| Wymiar | Ocena |
|---|---|
| Koszt implementacji | średni |
| Łatwość synchronizacji upstreamu | średnia/niska |
| Szybkość dostarczenia iOS | najwyższa |
| Wartość dla celu projektu | najwyższa |

To wybrana opcja. Zachowujemy sprawdzone elementy silnika, ale granice
platformowe projektujemy wyłącznie pod UIKit, sandbox iOS i wybrany backend
graficzny.

### C. Przepisanie silnika od początku

| Wymiar | Ocena |
|---|---|
| Koszt implementacji | bardzo wysoki |
| Ryzyko zgodności z Morrowindem | krytyczne |
| Szybkość dostarczenia iOS | bardzo niska |
| Wartość dla celu projektu | nieuzasadniona |

Opcja odrzucona. Istniejący core OpenMW ma największą wartość projektu i powinien
pozostać bazą.

## Konsekwencje

### Łatwiejsze

- rozdzielenie albo zastąpienie bloków `APPLE` bez zachowania macOS;
- usunięcie Qt, CPack i niepotrzebnych aplikacji desktopowych z domyślnego
  grafu builda;
- przyjęcie jednego modelu ścieżek, lifecycle i input;
- agresywne ograniczenie pluginów, kodeków i funkcji renderera;
- uproszczenie CI do macierzy device/simulator;
- projektowanie UI, pamięci i wydajności pod minimalny iOS 16.4.

### Trudniejsze

- przyjmowanie dużych merge'y z upstreamu;
- ponowne wykorzystanie desktopowych instrukcji i paczek zależności;
- diagnostyka core wyłącznie przez dotychczasowe desktopowe programy;
- ewentualny powrót do wieloplatformowości.

### Ryzyka

- delta forka będzie rosła szybciej;
- selektywne cherry-picki mogą pominąć poprawki zależne od zmian desktopowych;
- część testów upstreamu przestanie być możliwa do uruchomienia bez adapterów;
- zmiana bundle ID przy ponownym podpisaniu może utworzyć nowy kontener i
  odseparować wcześniejsze dane użytkownika.

## Reguły ochronne

- każda regresja iOS blokuje merge;
- regresja innej platformy jest akceptowalna i musi być tylko jawnie opisana;
- dane Morrowinda nigdy nie trafiają do repo, cache CI, artifacts ani Releases;
- release zawiera dokładny corresponding source i wymagane informacje
  licencyjne;
- workflow nie posiada sekretów użytkownika służących do podpisywania;
- fizyczny iOS 16.4 pozostaje dolną bramką kompatybilności, nawet jeśli runner
  CI ma nowszy SDK i simulator.

## Działania

- [x] Zapisać iOS 16.4 jako minimalny deployment target.
- [x] Wyłączyć App Store i TestFlight z zakresu.
- [x] Wybrać SideStore i lokalny Xcode jako kanały instalacji.
- [x] Wybrać GitHub Actions jako jedyny system CI/CD.
- [x] Zezwolić na zmiany łamiące inne platformy.
- [ ] Wprowadzić `CMAKE_OSX_DEPLOYMENT_TARGET=16.4` do presetów device/simulator.
- [ ] Wyłączyć niewymagane workflow wieloplatformowe na branchach portu.
- [ ] Dodać workflow iOS zgodny z `CI_IOS.md`.
- [ ] Przetestować zachowanie danych po ponownym podpisaniu i aktualizacji IPA.
