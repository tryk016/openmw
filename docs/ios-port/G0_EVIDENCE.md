# Dowody G0

## Zakres

Ten dokument zapisuje trwały wynik automatycznej części bramki G0. Test
fizycznego urządzenia jest raportowany osobnym issue `iOS physical-device test`.

## Wzmocniony PASS

| Pole | Wartość |
|---|---|
| workflow | [iOS G0 run 29749380532](https://github.com/tryk016/openmw/actions/runs/29749380532) |
| commit | `a001f5cfeb9e8a1ab76d601d88dfb5b6e279f6fb` |
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
| `OpenMW-iOS-unsigned.ipa` | `aa35ce7960f45dff5aa25df543d1afbfc8be4e4fcc1a365d18789a2a7c5dd8e7` |
| `OpenMW-iOS-Simulator.app.zip` | `f2079a5bda3e3eed3be23a7bc5ae0a2c8ee6ac0e9e1348d0c9c8d32bd6ba9a9a` |
| `OpenMW-iOS-device.dSYM.zip` | `c3542e9d55dfd8ff2fb0e3d03f87f0b1c6b666f9dab061e767abce89a411b006` |
| `OpenMW-iOS-simulator.dSYM.zip` | `dcb91e927bb3f883294c9d10808da096c982591d3ad4afd2dbf49196d930908e` |

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

Stan: **PENDING** — [test urządzenia #1](https://github.com/tryk016/openmw/issues/1).

Do zamknięcia G0 potrzebny jest PASS na fizycznym iPhonie/iPadzie z iOS 16.4
lub nowszym, zgłoszony za pomocą szablonu issue. Raport musi wskazywać dokładny
commit i workflow artifact oraz potwierdzić:

- instalację przez SideStore albo Xcode;
- widoczny ekran G0;
- własne komunikaty unified logging;
- background/foreground bez crasha;
- symbole/breakpoint Debug, jeżeli użyto Xcode.
