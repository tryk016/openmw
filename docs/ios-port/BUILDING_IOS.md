# Budowanie G0 dla iOS

## Zakres

Ten dokument opisuje hermetyczny bootstrap fazy G0. Nie buduje jeszcze silnika
OpenMW ani jego zależności. Celem jest udowodnienie, że czysty checkout tworzy
aplikację Objective-C++/C++20 dla:

- `iphoneos/arm64`;
- `iphonesimulator/arm64`;
- deployment targetu iOS/iPadOS 16.4.

Jedynym wspieranym systemem CI/CD jest GitHub Actions. Buildy innych platform
nie są wymagane.

## Przypięty toolchain G0

| Element | Wartość |
|---|---|
| runner | `macos-15` |
| Xcode | `16.4` |
| generator | `Xcode` |
| CMake | 3.25 lub nowszy |
| języki | Objective-C++ i C++20 |
| device | `iphoneos/arm64` |
| simulator | `iphonesimulator/arm64` |
| deployment target | `16.4` |
| target CMake/Xcode | `openmw-ios-bootstrap` |
| bundle ID G0 | `org.openmw.ios.bootstrap` |

Workflow zawsze wypisuje faktyczną wersję obrazu, Xcode, SDK, Clang i CMake.
Aktualizacja Xcode wymaga kontrolowanej zmiany tego dokumentu i zielonego G0.

## GitHub Actions — ścieżka podstawowa

1. Otwórz zakładkę Actions w `tryk016/openmw`.
2. Wybierz workflow `iOS G0`.
3. Uruchom `Run workflow` dla właściwego brancha lub commita.
4. Sprawdź joby device i simulator.
5. Pobierz artefakty:
   - niesygnowane IPA dla urządzenia;
   - bundle symulatora;
   - dSYM;
   - manifest i log smoke testu.

Workflow PR nie używa Apple ID, certyfikatu ani provisioning profile.

## Lokalny build na Macu

Wymagania:

- macOS zdolny uruchomić Xcode 16.4;
- pełne Xcode, nie tylko Command Line Tools;
- CMake 3.25+;
- dla fizycznego urządzenia: Apple Account zalogowany w Xcode i włączony
  Developer Mode na urządzeniu.

Wybór Xcode:

```sh
sudo xcode-select -s /Applications/Xcode_16.4.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
cmake --version
```

### Symulator

```sh
cmake --preset ios-simulator
cmake --build --preset ios-simulator-debug
```

Projekt Xcode znajduje się w:

```text
build/ios-simulator/OpenMWIOSBootstrap.xcodeproj
```

### Urządzenie — build bez podpisu

```sh
cmake --preset ios-device
cmake --build --preset ios-device-debug
```

To jest ten sam tryb, którego używa GitHub Actions do przygotowania
niesygnowanego IPA.

### Urządzenie — lokalne podpisanie w Xcode

Wstaw własny Team ID:

```sh
cmake --preset ios-device \
  -DOPENMW_IOS_ENABLE_CODE_SIGNING=ON \
  -DOPENMW_IOS_DEVELOPMENT_TEAM=YOUR_TEAM_ID

open build/ios-device/OpenMWIOSBootstrap.xcodeproj
```

W Xcode:

1. wybierz scheme `openmw-ios-bootstrap`;
2. wybierz fizyczny iPhone/iPad;
3. sprawdź Team i automatyczne zarządzanie signingiem;
4. uruchom Product → Run;
5. zaakceptuj Developer Mode/trust, jeżeli urządzenie o to poprosi.

Przy Personal Team profil aplikacji wygasa po siedmiu dniach i wymaga
okresowego ponownego podpisania.

## Oczekiwany wynik

Po starcie widoczny jest ekran:

```text
OpenMW for iOS
G0 bootstrap running on an iOS device
```

albo odpowiedni komunikat symulatora.

Subsystem unified logging:

```text
org.openmw.ios.bootstrap
```

Kategorie lifecycle:

- start `UIApplicationMain`;
- zakończenie uruchamiania;
- widoczny ekran G0;
- background;
- foreground;
- memory warning.

Log symulatora:

```sh
xcrun simctl spawn booted log stream \
  --level info \
  --predicate 'subsystem == "org.openmw.ios.bootstrap"'
```

Log fizycznego urządzenia sprawdzamy w Xcode albo Console.app.

## Debugowanie C++

Debug używa C++20 i generuje symbole `dwarf-with-dsym`. Do testu breakpointu:

1. otwórz wygenerowany projekt;
2. ustaw breakpoint w `OpenMW::IOS::bootstrapStatus`;
3. uruchom Debug na symulatorze albo urządzeniu;
4. zapisz screenshot zatrzymanego breakpointu w issue testowym.

## Artefakt dla SideStore

GitHub Actions pakuje niesygnowany bundle jako:

```text
Payload/OpenMW.app
```

i tworzy `OpenMW-iOS-unsigned.ipa`. SideStore podpisuje IPA certyfikatem
użytkownika. Dane gry nie są potrzebne do testu G0 i nie mogą znaleźć się w
artefakcie.

## Raport testu urządzenia

Test fizycznego urządzenia zgłaszamy przez szablon `iOS device test`. Raport
musi zawierać:

- model urządzenia i wersję iOS;
- commit SHA;
- instalację SideStore albo Xcode;
- screenshot ekranu G0;
- fragment unified log;
- wynik background/foreground;
- potwierdzenie breakpointu lub symbolizacji Debug;
- wynik PASS/FAIL.

Faza 1 nie jest ukończona bez raportu PASS na fizycznym urządzeniu.

## Najczęstsze problemy

### CMake uruchamia pełny desktopowy build

Użyj dokładnie presetów `ios-device` albo `ios-simulator`. Ustawiają
`OPENMW_IOS_BOOTSTRAP=ON`, co kończy konfigurację przed zależnościami desktopu.

### CMake nie znajduje Xcode

Sprawdź `xcode-select -p` i wybierz pełną instalację Xcode. Sam pakiet Command
Line Tools nie zawiera iOS SDK.

### Podpisywanie blokuje CI

Tryb CI musi mieć:

```text
OPENMW_IOS_ENABLE_CODE_SIGNING=OFF
CODE_SIGNING_ALLOWED=NO
CODE_SIGNING_REQUIRED=NO
```

### Xcode nie instaluje aplikacji

Sprawdź Team, unikalny bundle ID, Developer Mode, zaufanie urządzenia i ważność
profilu. Przy konflikcie bundle ID skonfiguruj własny identyfikator przed
ponownym wygenerowaniem projektu.

## Źródła

- [Apple: uruchamianie na symulatorze i urządzeniu](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- [Apple: konto i Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account/)
- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub runner image macOS 15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
