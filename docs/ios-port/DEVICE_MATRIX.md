# Macierz urządzeń iOS

## Zasada

GitHub Actions potwierdza build i symulator. Każda bramka od G0 wymaga osobnego
raportu z fizycznego urządzenia. Raport jest issue utworzonym z szablonu
`iOS device test` i wskazuje dokładny commit.

## Minimalna macierz

| ID | Klasa | System | Zakres | G0 |
|---|---|---|---|---|
| `MIN-16_4` | fizyczny iPhone/iPad wspierający iOS 16.4 | dokładnie 16.4, jeśli dostępny | dolna kompatybilność API i bundle | wymagany przed G5; w G0 zastępowany kontrolą `minos 16.4`, gdy sprzęt nie jest dostępny |
| `PRIMARY` | iPhone 16 Pro Max | iOS 26.6 | instalacja, ekran G0 i lifecycle | PASS w [#1](https://github.com/tryk016/openmw/issues/1) |
| `CURRENT` | współczesny iPhone | aktualny stabilny iOS | bieżące SDK i regresje | wymagany od G2 |
| `IPAD` | iPad | 16.4 lub nowszy | layout, input, multitasking | wymagany od G3 |
| `SIM-ARM64` | iPhone Simulator na Apple Silicon | runtime dostępny na runnerze | automatyczny smoke CI | wymagany w każdym PR |

Model `PRIMARY` pochodzi z pierwszego raportu PASS. Dokładny runtime iOS 16.4
nie był dostępny w G0. Minimalny deployment target potwierdzają metadane Mach-O
i bundle; test dolnej wersji systemu pozostaje jawną bramką przed G5.

## Wykonane raporty

| Bramka | Issue | Model | System | Commit | Instalacja | Wynik | Data |
|---|---|---|---|---|---|---|---|
| G0 | [#1](https://github.com/tryk016/openmw/issues/1) | iPhone 16 Pro Max | iOS 26.6 | `66d1e7ff230c16e7dca4c0f656612323c72aab00` | Sideloadly | PASS | 2026-07-20 |

Raport G0 potwierdza widoczny ekran bootstrapu, przejście
background/foreground bez crasha i ponowny start po zamknięciu. Fizycznych
logów nie zebrano; unified logging, dSYM i breakpoint C++ zostały potwierdzone
automatycznie dla tego samego commita w
[workflow 29750407807](https://github.com/tryk016/openmw/actions/runs/29750407807).
Sideloadly jest wyłącznie potwierdzoną metodą testu deweloperskiego G0; docelowe
kanały projektu pozostają SideStore i lokalny Xcode.

## Dane raportu

- identyfikator macierzy;
- model i identyfikator sprzętu;
- wersja i build iOS;
- commit forka i bazowy upstream SHA;
- wersja Xcode/SDK albo użyte narzędzie sideload;
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
