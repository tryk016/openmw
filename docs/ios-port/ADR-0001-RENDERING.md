# ADR-0001: Bootstrap renderingu OpenMW na iOS

**Status:** Proposed
**Data:** 2026-07-20
**Decydenci:** maintainerzy forka i osoba odpowiedzialna za iOS/graphics
**Bramka akceptacji:** faza 4 roadmapy, test na fizycznym urządzeniu

## Kontekst

OpenMW 0.52 opiera rendering na forku OpenSceneGraph skonfigurowanym pod
desktopowy OpenGL 2 oraz na MyGUI, które nadal wywołuje fixed function API.
iOS nie udostępnia desktopowego OpenGL. OpenGL ES istnieje, ale jest
zdeprecjonowany od iOS 12; docelowym API Apple jest Metal.

Przepisanie renderera OpenMW przed uzyskaniem pierwszej działającej sceny
byłoby projektem wielokrotnie większym niż sam port platformowy. Kod upstreamu
ma już integrację GL4ES, a GL4ES wspiera statyczny build iOS.

## Decyzja proponowana

Wykonujemy dwustopniowy, timeboxowany bootstrap:

1. **Ścieżka A — GL4ES nad natywnym OpenGL ES** służy do uzyskania pierwszej
   działającej sceny i pomiaru zakresu niezgodności. Baseline PoC to ES 2,
   zgodny z typową konfiguracją GL4ES; ES 3.0 sprawdzamy osobno.
2. **Ścieżka B — GL4ES nad ANGLE/Metal** jest planem ograniczenia zależności od
   zdeprecjonowanego backendu Apple, uruchamianym po potwierdzeniu, że OpenMW
   działa przez GL4ES albo gdy natywny GLES nie spełnia wymagań stabilności,
   wydajności lub utrzymania na iOS 16.4+.

Nie rozpoczynamy pełnego rewrite'u do Metal/VulkanSceneGraph w ramach pierwszego
portu.

Decyzja jest warunkowa. PoC może ją odrzucić.

## Opcje

### A. GL4ES + natywny OpenGL ES

| Wymiar | Ocena |
|---|---|
| Zmiany w OpenMW | niskie/średnie |
| Czas do pierwszej klatki | najkrótszy |
| Ryzyko zgodności | wysokie |
| Ryzyko długoterminowe | wysokie, API Apple jest zdeprecjonowane |
| Wydajność | nieznana, wymaga pomiaru |

Zalety:

- wykorzystuje istniejący kod `OPENMW_GL4ES_MANUAL_INIT`;
- GL4ES tłumaczy fixed function pipeline i GLSL zgodności;
- SDL2 potrafi utworzyć kontekst GLES na iOS;
- dostarcza szybki dowód, czy obecna architektura jest przenośna.

Wady:

- Apple nie rozwija OpenGL ES;
- GL4ES nie implementuje bezbłędnie całego desktopowego OpenGL;
- część efektów trzeba będzie wyłączyć albo uprościć;
- wynik na symulatorze nie zastępuje testu urządzenia.

### B. GL4ES + ANGLE + Metal

| Wymiar | Ocena |
|---|---|
| Zmiany w OpenMW | średnie/wysokie |
| Czas do pierwszej klatki | dłuższy |
| Ryzyko zgodności | wysokie |
| Ryzyko długoterminowe | średnie |
| Wydajność | ryzyko kosztu dwóch translacji |

Zalety:

- finalne komendy trafiają do Metal;
- ANGLE oficjalnie deklaruje backend Metal na iOS;
- eliminuje zależność od implementacji OpenGL ES Apple.

Wady:

- GL4ES i ANGLE tworzą podwójną warstwę translacji;
- SDL/OSG wymaga niestandardowej integracji kontekstu/powierzchni;
- większy rozmiar binarny i bardziej skomplikowane debugowanie;
- nadal nie rozwiązuje automatycznie shaderów i brakujących funkcji.

### C. Bezpośredni port OSG/OpenMW do Metal

| Wymiar | Ocena |
|---|---|
| Zmiany w OpenMW | bardzo wysokie |
| Czas do pierwszej klatki | najdłuższy |
| Ryzyko zgodności | bardzo wysokie |
| Ryzyko długoterminowe | najniższe po ukończeniu |
| Wydajność | potencjalnie najlepsza |

Opcja długoterminowo czysta, ale wymaga przepisania znacznej części
SceneGraph/render state, shaderów, pluginów i integracji MyGUI. Nie pasuje do
celu „port forka” jako pierwszej wersji.

### D. VulkanSceneGraph + MoltenVK

| Wymiar | Ocena |
|---|---|
| Zmiany w OpenMW | bardzo wysokie |
| Czas do pierwszej klatki | najdłuższy |
| Ryzyko zgodności | bardzo wysokie |
| Ryzyko długoterminowe | niskie/średnie |
| Wydajność | potencjalnie dobra |

To migracja silnika renderującego, nie adapter platformowy. Może być przyszłym
programem modernizacyjnym, ale nie ścieżką bootstrapu.

## Profil renderingu MVP

Pierwszy działający build ma celowo ograniczyć funkcje:

- jeden widok, bez stereo/multiview;
- brak postprocessingu i efektów wymagających compute shaderów;
- wyłączone dynamiczne cienie, jeśli blokują GL4ES;
- podstawowa woda i pogoda;
- ograniczone MSAA;
- dekompresja nieobsługiwanych formatów tekstur przy imporcie lub ładowaniu;
- statycznie zarejestrowane pluginy OSG;
- limit rozdzielczości render targetu niezależny od natywnego Retina;
- profil jakości `ios-low` jako ustawienie startowe.

Funkcje wracają pojedynczo, każda z testem obrazu i budżetu wydajności.

## Bramka decyzji

Ścieżka A przechodzi tylko, gdy:

- ładuje menu i scenę Seyda Neen na fizycznym urządzeniu;
- nie ma brakujących elementów krytycznych dla gameplay;
- stabilnie renderuje przez 20 minut;
- mediana frametime w profilu MVP mieści się w budżecie zaakceptowanym w
  `PERFORMANCE_BUDGET.md`;
- lista wymaganych workaroundów nie oznacza forka większości OSG.

Jeżeli A nie przejdzie z powodów implementacji GLES Apple, uruchamiamy B.
Jeżeli B nie przejdzie, oznaczamy bieżący port jako NO-GO i przygotowujemy
osobny ADR dla migracji renderera.

## Konsekwencje

- PoC zależy od fizycznego urządzenia i Maca z aktualnym Xcode.
- Część jakości graficznej będzie początkowo niższa niż na desktopie.
- Warstwa renderingu musi mieć feature flags i testy regresji obrazu.
- Nie obiecujemy Metal-native w MVP.
- Każda nowa funkcja OpenMW używająca GL wymaga oceny wpływu na profil iOS.

## Zadania wynikające z ADR

- [ ] Zbudować GL4ES statycznie dla `iphoneos/arm64`.
- [ ] Zbudować fork OSG statycznie z minimalnym zestawem pluginów.
- [ ] Utworzyć kontekst GLES 2 przed `openmw_gl4es_init`.
- [ ] Przetestować osobno GLES 3.0.
- [ ] Poprawić wersję GLES — iOS nie oferuje kontekstu GLES 3.2.
- [ ] Dodać profil funkcji `ios-low`.
- [ ] Uruchomić scenę testową z terenem, NIF, aktorem, GUI i wodą.
- [ ] Zapisać wynik bramki wraz z pomiarami.
- [ ] Wykonać mały spike ANGLE/Metal niezależnie od wyniku A.
