# Macierz urządzeń iOS

## Zasada

GitHub Actions potwierdza build i symulator. Każda bramka od G0 wymaga osobnego
raportu z fizycznego urządzenia. Raport jest issue utworzonym z szablonu
`iOS device test` i wskazuje dokładny commit.

## Minimalna macierz

| ID | Klasa | System | Zakres | G0 |
|---|---|---|---|---|
| `MIN-16_4` | fizyczny iPhone/iPad wspierający iOS 16.4 | dokładnie 16.4, jeśli dostępny | dolna kompatybilność API i bundle | wymagany przed zamknięciem fazy 1 |
| `PRIMARY` | fizyczne urządzenie właściciela projektu | 16.4 lub nowszy | instalacja, ekran G0, log, lifecycle, Debug | wymagany |
| `CURRENT` | współczesny iPhone | aktualny stabilny iOS | bieżące SDK i regresje | wymagany od G2 |
| `IPAD` | iPad | 16.4 lub nowszy | layout, input, multitasking | wymagany od G3 |
| `SIM-ARM64` | iPhone Simulator na Apple Silicon | runtime dostępny na runnerze | automatyczny smoke CI | wymagany w każdym PR |

Model `PRIMARY` zostanie wpisany z pierwszego raportu PASS. Nie zgadujemy modelu
sprzętu użytkownika i nie odhaczamy tego zadania przed otrzymaniem dowodu.

## Dane raportu

- identyfikator macierzy;
- model i identyfikator sprzętu;
- wersja i build iOS;
- commit forka i bazowy upstream SHA;
- wersja Xcode/SDK albo wersja SideStore;
- sposób podpisania i instalacji;
- wynik instalacji oraz pierwszego startu;
- screenshot;
- unified log;
- background/foreground;
- breakpoint C++ albo potwierdzenie symboli;
- wynik PASS/FAIL;
- data i tester.

## Polityka danych gry

G0 nie potrzebuje danych Morrowinda. Od G2 tester używa wyłącznie własnych
plików. Raport nie może zawierać:

- plików gry;
- save'ów z prywatnymi danymi;
- Apple ID;
- certyfikatów i provisioning profiles;
- SideStore pairing file;
- pełnego UDID urządzenia.
