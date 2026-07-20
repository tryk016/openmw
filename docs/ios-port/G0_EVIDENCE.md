# Dowody G0

## Zakres

Ten dokument zapisuje trwały wynik automatycznej części bramki G0. Test
fizycznego urządzenia jest raportowany osobnym issue `iOS physical-device test`.

## Wzmocniony PASS

| Pole | Wartość |
|---|---|
| workflow | [iOS G0 run 29750407807](https://github.com/tryk016/openmw/actions/runs/29750407807) |
| commit | `66d1e7ff230c16e7dca4c0f656612323c72aab00` |
| wynik | PASS |
| data | 2026-07-20 |
| runner | `macos-15`, Apple Silicon `arm64` |
| runner image | `20260715.0234.1` |
| Xcode | 16.4 (`16F6`) |
| SDK | iPhoneOS/iPhoneSimulator 18.5 |
| CMake | 4.4.0 |
| deployment target | 16.4 |
| bundle ID | `org.openmw.ios.bootstrap` |

### Potwierdzone kontrole

- configure i build `iphoneos/arm64`;
- configure i build `iphonesimulator/arm64`;
- Mach-O device: platform `IOS`, arch `arm64`, `minos 16.4`;
- Mach-O simulator: platform `IOSSIMULATOR`, arch `arm64`, `minos 16.4`;
- oba bundle bez code signing, provisioning profile i `_CodeSignature`;
- brak danych gry, certyfikatów, profili i wzorców sekretów;
- instalacja oraz rzeczywiste uruchomienie procesu w iPhone Simulator;
- widoczny ekran G0 oraz screenshot;
- wymagane wpisy z subsystemu `org.openmw.ios.bootstrap` w unified logging;
- zgodność UUID binarki i dSYM dla device oraz simulator;
- obecność symbolu C++ `OpenMW::IOS::bootstrapStatus`;
- rozwiązanie breakpointu tego symbolu przez LLDB;
- niesygnowane IPA, simulator app, oba dSYM, manifest i sumy SHA-256.

Symulator wybrany automatycznie przez runner:

```text
iPhone 16
```

Runtime symulatora pochodzi z obrazu GitHub Actions. Nie jest to fizyczne
urządzenie użytkownika ani deklaracja wsparcia wyłącznie dla tego modelu.

### Artefakty i sumy

| Artefakt | SHA-256 |
|---|---|
| `OpenMW-iOS-unsigned.ipa` | `eb7d86266916289d3528cbbbfb0366d5fc2d3bd1182bc1bf61fb6e320b6c736e` |
| `OpenMW-iOS-Simulator.app.zip` | `8a666aeaf25e21df6dca35e9aabaef02ee885b998c445715df106183ca21628d` |
| `OpenMW-iOS-device.dSYM.zip` | `a26a6068c2d9a4e5e081ffc77a415911d0f8caa7886613296957f5bf3e4a6c0f` |
| `OpenMW-iOS-simulator.dSYM.zip` | `208088c707f25590cdaad8340fdcdb2b85b211c4f44cd31a99a7261ae3132923` |

Artefakty workflow mają retencję siedmiu dni. Odpowiadający im kod i manifest
pozostają identyfikowalne przez commit i numer przebiegu.

## Aktualizacja z upstreamu

Przed powyższym PASS włączono cztery commity z `OpenMW/openmw:master`, do
`7a5e77a451`. Zmiany dotyczą iteratorów Lua i nie przecinają bootstrapu iOS.
Podany wynik pochodzi już z `ios/main`, po synchronizacji; gałąź ma w tym
punkcie `0` commitów zaległości względem upstreamu.

## Zachowany wynik diagnostyczny

[Run 29746751289](https://github.com/tryk016/openmw/actions/runs/29746751289)
poprawnie skonfigurował Xcode i build device, ale linkowanie ujawniło brak
jawnego `CoreGraphics`. Poprawka dodała wymagany framework, a kolejne pełne
przebiegi przeszły. To zachowany dowód, że workflow nie maskuje błędów
kompilacji.

## Dowód fizycznego urządzenia

Stan: **PASS** — [test urządzenia #1](https://github.com/tryk016/openmw/issues/1).

| Pole | Wynik |
|---|---|
| model | iPhone 16 Pro Max |
| system | iOS 26.6 |
| commit i artefakt | `66d1e7ff230c16e7dca4c0f656612323c72aab00`, `OpenMW-iOS-unsigned-*` |
| podpisanie i instalacja | PASS przez Sideloadly |
| pierwszy start | PASS, widoczny ekran `OpenMW for iOS` |
| marker urządzenia | PASS, `G0 bootstrap running on an iOS device` |
| background/foreground | PASS, bez crasha |
| ponowny start | PASS |
| screenshot | 25 113 B, SHA-256 `060c0c63038e088d58f3497130a271976a1186706e44c5f5d0799112ae2ec01a` |
| data | 2026-07-20 |

Tester dostarczył screenshot działającej aplikacji, który został wizualnie
sprawdzony w wątku roboczym Codex. Obraz nie został skopiowany do publicznego
repozytorium bez osobnej zgody użytkownika.

Fizycznych logów nie zebrano. Nie maskujemy tego braku: unified logging, dSYM,
symbol C++ i breakpoint LLDB mają osobny automatyczny PASS dla dokładnie tego
samego commita w runie 29750407807. Sideloadly potwierdza signing, provisioning,
instalację i runtime G0, ale nie zmienia wybranych kanałów dystrybucji projektu:
pozostają nimi SideStore i lokalny Xcode.

Dokładny runtime iOS 16.4 nie był dostępny. G0 zamyka kontrola `minos 16.4` w
device/simulator Mach-O oraz fizyczny PASS na iOS 16.4+. Test urządzenia z
dokładnym iOS 16.4 pozostaje dolną bramką kompatybilności przed G5.
