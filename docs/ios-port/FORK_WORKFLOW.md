# Workflow forka i ochrona upstreamu

## Zasada nadrzędna

Cały port iOS rozwijamy w [`tryk016/openmw`](https://github.com/tryk016/openmw).
Repozytorium [`OpenMW/openmw`](https://github.com/OpenMW/openmw) służy wyłącznie
do pobierania zmian. Nie pushujemy commitów, branchy ani tagów do upstreamu i
nie otwieramy tam pull requestów z portem.

Fork jest iOS-only zgodnie z
[ADR-0002](ADR-0002-IOS-ONLY-SCOPE.md). Zmiany nie muszą zachowywać buildów ani
runtime innych platform. Upstream jest źródłem poprawek, a nie kontraktem
kompatybilności.

## Aktualny układ remotes

```text
origin    https://github.com/tryk016/openmw.git  (fetch/push)
upstream  https://github.com/OpenMW/openmw.git   (fetch)
upstream  DISABLED                               (push)
```

Weryfikacja:

```sh
git remote -v
git remote get-url --push upstream
```

Oczekiwany push URL upstreamu to dokładnie `DISABLED`.

## Dodatkowe lokalne zabezpieczenie

W każdej kopii roboczej:

```sh
git remote set-url --push upstream DISABLED
git config remote.pushDefault origin
```

Po nowym clone sprawdzamy remotes przed pierwszym push. Nie kopiujemy
konfiguracji z dokumentacji bez sprawdzenia nazwy właściciela forka.

## Strategia branchy

```text
upstream/master
      |
      v
master                 czyste lustro upstreamu, bez commitów portu
      |
      v
ios/main               branch integracyjny portu
      |
      +-- ios/build-...
      +-- ios/render-...
      +-- ios/input-...
      +-- ios/storage-...
      +-- ios/audio-...
      +-- ios/sync-YYYYMMDD
```

- `master` jest aktualizowany tylko fast-forwardem z `upstream/master`.
- `ios/main` zawiera różnicę portu.
- Feature branches startują z aktualnego `ios/main`.
- Przyjęcie zmian upstreamu wykonujemy selektywnie w osobnym `ios/sync-*`,
  testujemy wyłącznie wymagany zakres iOS i mergujemy do `ios/main`.
- Branch `codex/ios-port-plan` zawiera dokumentację początkową.

## Pierwsze utworzenie `ios/main`

```sh
git switch master
git pull --ff-only origin master
git switch -c ios/main
git push -u origin ios/main
```

Ochronę brancha ustawiamy w repo forka:

- wymagany PR;
- wymagane GitHub Actions device/simulator i testy iOS;
- zakaz force-push;
- zakaz usunięcia;
- co najmniej jedna akceptacja, gdy projekt ma więcej niż jednego maintenera.

## Feature workflow

```sh
git switch ios/main
git pull --ff-only origin ios/main
git switch -c ios/render-gl4es-bootstrap

# zmiany + testy + aktualizacja ROADMAP.md

git push -u origin ios/render-gl4es-bootstrap
```

Pull request ma bazę `tryk016/openmw:ios/main`, nigdy
`OpenMW/openmw:master`.

Checklist PR:

- [ ] base repo to `tryk016/openmw`;
- [ ] base branch to `ios/main`;
- [ ] testy i dowody urządzenia dołączone;
- [ ] dokumentacja/ADR zaktualizowane;
- [ ] checkboxy roadmapy zaktualizowane;
- [ ] nowe zależności mają hash, licencję i SBOM;
- [ ] deployment target pozostaje `16.4` lub zmiana ma zaakceptowany ADR;
- [ ] brak danych Morrowinda/Bethesdy;
- [ ] brak sekretów, provisioning profiles i prywatnych certyfikatów.

## Synchronizacja z upstreamem

### 1. Zaktualizuj czysty `master`

```sh
git fetch upstream
git switch master
git merge --ff-only upstream/master
git push origin master
```

Jeżeli `master` nie daje się fast-forwardować, zatrzymujemy się i badamy
nieplanowany commit. Nie używamy force-push ani resetu jako automatycznej
naprawy.

### 2. Przygotuj branch integracyjny

```sh
git switch ios/main
git pull --ff-only origin ios/main
git switch -c ios/sync-YYYYMMDD

# zależnie od zakresu:
git cherry-pick <upstream-commit>
# albo świadomie:
git merge master
```

Na branchu sync:

- wybierz tylko zmiany dające wartość portowi iOS;
- rozwiąż konflikty;
- zapisz nowy bazowy SHA w roadmapie/changelogu;
- uruchom testy core używane przez port;
- uruchom GitHub Actions device/simulator;
- uruchom smoke na urządzeniu dla ryzykownych zmian;
- otwórz PR tylko do `tryk016/openmw:ios/main`.

Regresja Linux/Windows/macOS/Android nie blokuje tego PR. Musi zostać opisana
tylko wtedy, gdy wpływa na możliwość dalszego wykorzystania kodu upstream.

## Commity

Zalecane małe commity:

```text
ios(build): split macOS and iOS CMake paths
ios(render): initialize gl4es after SDL GLES context
ios(files): add sandbox-aware iOS paths
docs(ios): update phase 4 rendering evidence
```

Nie mieszamy sync upstreamu z nową funkcją iOS. Nie przepisujemy historii
opublikowanego `ios/main`.

## Tagi i release

- tagi release tworzymy w forku;
- nazwa jasno wskazuje fork i platformę, np. `ios-v0.1.0`;
- release notes zawierają bazowy upstream SHA;
- corresponding source wskazuje dokładny tag;
- GitHub Actions publikuje niesygnowane IPA, dSYM, sumy kontrolne, SBOM i
  notices;
- użytkownik podpisuje IPA przez SideStore albo buduje tag lokalnie w Xcode;
- binary artifacts nigdy nie zawierają danych gry;
- release nie jest publikowany przed checklistą licencyjną.

## Czego nie robimy

- `git push upstream ...`;
- przywracania push URL upstreamu;
- GitHub „Contribute → Open pull request” do upstreamu;
- commitów portu bezpośrednio na `master`;
- force-push do `master` lub `ios/main`;
- vendoringu prywatnych danych/provisioning/certyfikatów;
- commitowania importowanych assetów Morrowinda;
- publikowania do App Store Connect lub TestFlight;
- przechowywania Apple ID, certyfikatów, provisioning profiles albo SideStore
  pairing files w GitHub Actions;
- blokowania zmiany iOS z powodu regresji niewspieranej platformy;
- automatycznego sync bez testów i aktualizacji bazowego SHA.

## Kontrola przed każdym push

```sh
git status --short --branch
git remote -v
git branch --show-current
git diff --check
```

Push jest dozwolony tylko, gdy:

- bieżący branch nie jest przypadkowo `master`;
- docelowy remote to `origin`;
- `origin` należy do właściciela forka;
- `upstream (push)` pozostaje `DISABLED`;
- diff nie zawiera danych gry ani sekretów.
