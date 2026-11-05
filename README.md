# RIFT ARENA — Godot 4 mobile hero brawler (vertical slice)

Oryginalny hero-brawler 3v3 w **Godot 4.7 (GDScript, renderer Mobile)**: 3 bohaterów (VOLT, BRUTE, NYX), mapa
**Fracture Yard**, tryb **RIFT CORE**, multiplayer ENet, boty, pełne menu, sterowanie dotykowe, presety eksportu Android/iOS.
Brak zewnętrznych assetów: modele, animacje, efekty, UI, dźwięki i muzyka powstają w kodzie (zero cudzego IP).

---

## 1. Struktura projektu

```
project.godot              renderer "mobile", poziomo (sensor landscape), autoloady
export_presets.cfg         presety Android + iOS
scenes/main.tscn           scena startowa (UI layer + mecz)
characters/hero.tscn       CharacterBody3D bohatera (PackedScene)
ui/*.tscn                  ekrany: home, play, room, characters, shop, settings, results
maps/fracture_yard_layout.gd   układ mapy (dane: ściany, skrzynie, krzaki, lampy, budynki) – symetria punktowa
resources/
  heroes/volt|brute|nyx.tres   ← WSZYSTKIE statystyki bohaterów (HP, obrażenia, prędkość, cooldowny, zasięg, ładowanie super…)
  modes/rift_core.tres         ← zasady trybu (czas, wynik, puls rdzenia, energia, respawn…)
  environment/arena_env.tres   oświetlenie / glow / tonemapping
  ui/rift_theme.tres           motyw UI (generowany z scripts/ui/ui_theme.gd)
shaders/                   toon (cel shading + hit flash), ground, foliage (wiatr + prześwit), panel (ściany/budynki),
                           energy, ring (fale/strefy/pęknięcia), hpbar
scripts/
  core/      settings (jakość LOW/MED/HIGH, InputMap, zapis), game_manager (przepływ ekranów), main, mats (cache), skins, prof
  data/      HeroData, AbilityData, ModeData  (klasy Resource)
  player/    hero.gd (CharacterBody3D: stan + ruch), player_input.gd (dotyk/klawiatura/pad/mysz + aim assist)
  characters/hero_rig.gd (szkielet stawów + bake meshy), hero_visual.gd, models/volt|brute|nyx_model.gd
  animation/ anim_library.gd (11 animacji generowanych jako Animation), hero_animator.gd (AnimationPlayer + AnimationTree)
  abilities/ ability_runner.gd (typy: projectile, melee, blink, charge, zone, blast, shockwave)
  combat/    combat.gd, health.gd, projectile_system.gd (pula), zone_system.gd
  match/     match.gd (serwerowa symulacja + RPC), match_view.gd (prezentacja/predykcja/interpolacja), rift_core_mode.gd
  bots/      bot_brain.gd (NavigationServer3D, role, zbieranie, eskorta, umiejętności)
  network/   net.gd (ENet host/join/dedykowany, kody pokoi)
  lobby/     lobby.gd (pokój, drużyny, READY, start – autorytatywnie na serwerze)
  camera/    game_camera.gd (śledzenie z wyprzedzeniem, shake, zoom, intro)
  map/       arena_map.gd, props.gd, rift_core_view.gd, uplink_view.gd
  vfx/       vfx.gd (pule cząsteczek, fale, światła, liczby obrażeń), projectile_view.gd, field_view.gd
  audio/     synth.gd (syntezator SFX i muzyki), audio_manager.gd (pule odtwarzaczy, crossfade)
  ui/        hud, touch_controls, minimap, ekrany menu, hero_showcase (model 3D w menu), ui_theme
tools/       narzędzia deweloperskie (testy automatyczne, zrzuty) – wykluczone z eksportu
```

## 2. Uruchomienie

1. Otwórz **Godot 4.7** → *Import* → wybierz `project.godot`.
2. Naciśnij **F5** (Run Project). Startuje ekran HOME.
3. **PLAY → PRACTICE**: mecz 3v3 z botami offline.

Sterowanie na PC (do testów): **WASD** ruch, **mysz** celowanie, **LPM** atak, **E / Shift** umiejętność, **Q / Spacja** super.
Pad: lewa gałka ruch, RB atak, LB umiejętność, Y super. Na telefonie sterowanie jest dotykowe (opis w sekcji 6).

Z linii poleceń (szybki start):
```
godot --path . -- practice=volt
```

## 3. Dwa klienty (multiplayer)

Multiplayer to prawdziwa sieć (ENet/UDP, port **24680**), autorytatywny serwer.

**Na jednym komputerze:** uruchom grę dwa razy (np. edytor F5 + drugi raz `godot --path .`).
1. Okno A: **PLAY → CREATE ROOM**. Pojawia się **ROOM CODE** (8 znaków, koduje IP:port hosta).
2. Okno B: **PLAY → JOIN ROOM**, wpisz kod (albo `127.0.0.1`) → **JOIN**.
3. W pokoju: **HERO** (wybór bohatera), **⇄ TEAM** (zmiana drużyny), **READY** (klient).
   Host: **FILL WITH BOTS** (boty dopełniają do 3v3) → **START MATCH**.

**Telefony w tej samej sieci Wi-Fi:** host tworzy pokój, pozostali wpisują kod. Zezwól grze w zaporze Windows (sieć prywatna).

**Przez internet (PLAY → PLAY ONLINE):** gra łączy się przez WebSocket (`wss://`) z serwerem dedykowanym w chmurze
(adres w SETTINGS → ONLINE SERVER). Pierwszy gracz w pokoju zostaje hostem, wybiera bohaterów i startuje mecz; boty dopełniają 3v3.
Serwer online to ten sam projekt uruchomiony jako `godot --headless --path . -- server ws` (port z `$PORT`), zbudowany z `Dockerfile`.
Na planie Free hostingu serwer zasypia po ~15 min bez graczy; pierwsze połączenie może wtedy trwać do minuty.
Ograniczenie: jeden serwer = jeden pokój (kolejna grupa dołącza po zakończeniu meczu).

**Serwer dedykowany LAN (headless):**
```
godot --headless --path . -- server
```
Wypisuje ROOM CODE; pierwszy dołączający zostaje hostem pokoju. Ten sam kod działa na VPS-ie.

**Testy automatyczne:**
- `tools/run.sh tools/match_test.tscn -- volt 60 8 1`: pełny mecz 3v3 (autopilot), zrzuty, FPS.
- `tools/net_test.tscn`: dwa procesy (`-- host` i `-- client`) łączą się przez ENet i grają cały mecz.

## 4. Eksport Android

Wymagania (jednorazowo):
1. **Szablony eksportu**: Editor → *Manage Export Templates* → *Download and Install* (około 1,2 GB).
2. **JDK 17**: na tym komputerze jest Eclipse Adoptium. Editor → Editor Settings → Export → Android → *Java SDK Path*.
3. **Android SDK** (np. z Android Studio): *Android SDK Path* w tym samym miejscu.
4. **Debug keystore**: Godot tworzy go sam. Do wersji release ustaw własny keystore (*Release Keystore / User / Password*).

Eksport: **Project → Export… → Android** (preset jest gotowy: `com.riftarena.game`, arm64, ikony, orientacja pozioma, immersive, uprawnienia sieci).
- **APK do testów:** *Export Project* → `build/android/RiftArena.apk`. Zainstaluj go:
  ```
  adb install -r build/android/RiftArena.apk
  ```
  Albo podłącz telefon (USB debugging) i kliknij ikonę Androida **„Remote Deploy”** w prawym górnym rogu edytora.
- **AAB do Google Play:** w presecie włącz *Gradle Build → Use Gradle Build*, ustaw *Export Format = AAB*, zainstaluj *Android Build Template* (Project → Install Android Build Template) i eksportuj z release keystore.

## 5. Przygotowanie eksportu iOS

iOS **wymaga Maca** z **Xcode 15+** i konta Apple Developer (podpisywanie). Na Windows można tylko przygotować projekt.
1. Na Macu: Godot 4.7 + szablony eksportu, otwórz projekt.
2. **Project → Export → iOS**: preset zawiera bundle id `com.riftarena.game`, ikony, iOS 14+, arm64, `NSLocalNetworkUsageDescription`
   (wymagane do gry w sieci lokalnej) i pełny ekran. Uzupełnij **App Store Team ID**.
3. Eksport tworzy projekt Xcode (`build/ios/`). Otwórz go w Xcode → *Signing & Capabilities* → Run na iPhonie lub *Archive* → TestFlight.

Różnice względem Androida: iOS zawsze używa Metal (renderer Mobile działa), pyta o dostęp do sieci lokalnej przy pierwszym dołączeniu do pokoju, a safe area (Dynamic Island) jest uwzględniona w HUD i menu.

## 6. Co działa (zweryfikowane uruchomieniem)

- **Rozgrywka 3v3 RIFT CORE.** Rdzeń pulsuje co 7 s i wyrzuca odłamki energii (po 120 s jest „surge” z większą liczbą odłamków). Gracz niesie maksymalnie 8.
  Niosąc 4 lub więcej, świeci i krzaki go nie ukrywają. Energię przelewa się w Uplinku bazy. Śmierć upuszcza niesioną energię.
  Wygrywa drużyna, która pierwsza zdobędzie 14 punktów, a po 3:30 decyduje wynik.
- **Bohaterowie.** Model z rigiem z 14 stawów, 11 animacji (idle, walk, run, attack, hit, ability, super, death, respawn, victory, defeat)
  blendowanych w AnimationTree (BlendSpace1D + OneShot + Transition), pochylanie w biegu, kroki z kurzem i dźwiękiem.
  - VOLT: seria 3 pocisków, teleport z kolizją ścian, Overload (wybuch obszarowy).
  - BRUTE: zamach młotem w łuku, szarża z odrzutem, Quake Slam (pęknięcia ziemi, fala, spowolnienie, shake).
  - NYX: 2 drony z pociskami naprowadzanymi, pole Stasis (spowolnienie + DPS), Mending Bloom (leczenie sojuszników).
- **Combat feel.** Hit flash, iskry, liczby obrażeń, dźwięk, odrzut i reakcja animacją przy każdym trafieniu. Mocne ataki: fale uderzeniowe, błysk światła, camera shake.
  Regeneracja HP po 3 s bez obrażeń, super ładowany zadanymi obrażeniami (+15% za eliminację), ochrona po respawnie.
- **Kamera.** Śledzenie z wyprzedzeniem ruchu i celu, intro (zbliżenie), zoom przy celowaniu superem, trauma shake. Drużyna Red widzi mapę obróconą.
- **Sterowanie mobilne.** Pływający joystick ruchu z dead zone, analog AIM (przeciągnij i puść = strzał, wychylenie do krawędzi = ogień ciągły),
  przycisk ATTACK z aim assistem (priorytet: nosiciele energii i ranni), umiejętność i super (dotknięcie = szybkie użycie, przeciągnięcie = ręczne celowanie z podglądem,
  powrót na przycisk = anulowanie), pełny multitouch, safe area, skalowanie na dowolne proporcje.
- **Multiplayer.** Serwer autorytatywny (60 Hz), snapshoty 20 Hz filtrowane per drużyna (wróg w krzaku nie jest w ogóle wysyłany),
  wejścia klienta przez RPC, predykcja ruchu własnej postaci z korektą, interpolacja innych graczy, zdarzenia przez kanał reliable,
  lobby z kodem pokoju, przejęcie postaci przez bota, gdy gracz wyjdzie, serwer dedykowany.
- **Boty.** Nawigacja po navmeshu (NavigationServer3D), celowanie z wyprzedzeniem i ludzkim błędem, czas reakcji, strafe,
  zbieranie i odnoszenie energii, eskorta nosiciela, wycofanie przy niskim HP, użycie umiejętności i superów.
- **Mapa Fracture Yard.** Bazy Blue i Red z Uplinkami, Mid z animowanym Rift Core, trzy linie (górna, środkowa, dolna), ściany, skrzynie, rift-grass (krzaki z wiatrem i prześwitem wokół gracza),
  lampy, przewody, budynki z oświetlonymi oknami, holo-szyldy HQ, pył w powietrzu.
- **UI.** HOME, PLAY, ROOM, CHARACTER SELECT (duży animowany model, statystyki, karty umiejętności), SHOP (skórki za monety Rift Coins zdobywane w meczach),
  SETTINGS (LOW/MEDIUM/HIGH, limit FPS 30/60/MAX, licznik FPS, głośność), HUD (wynik i postęp, timer, puls rdzenia, cel, HP, energia, minimapa, kill feed,
  ogłoszenia, odliczanie, respawn, winieta obrażeń, pauza), RESULTS (VICTORY/DEFEAT/DRAW, MVP, statystyki, nagroda).
- **Audio.** Ponad 20 własnych SFX i dwie pętle muzyczne (menu, bitwa) plus jingle zwycięstwa i porażki, syntezowane przy starcie.
- **Wydajność.** Pule pocisków, cząsteczek, fal, świateł i liczb obrażeń. Meshe bohatera są scalane per staw (około 14 draw calli zamiast 45),
  skrzynie i krzaki to MultiMesh, HUD przerysowuje się tylko przy zmianie, minimapa 10 Hz. Wyniki na Intel HD 520 przy 1280×720:
  **LOW ok. 55 FPS, MEDIUM ok. 50–54 FPS, HIGH ok. 32 FPS.** Pętla renderu chodzi z częstotliwością ekranu (120/144 Hz na mocnych telefonach).

## 7. Ograniczenia i następne kroki

- Nie testowane na fizycznym telefonie (brak szablonów eksportu i SDK na tym komputerze). Pierwszy krok to APK na Androida i pomiar FPS.
- Multiplayer działa w sieci lokalnej (kod pokoju = IP). Do gry przez internet potrzebny jest serwer dedykowany na VPS albo relay/matchmaking.
- Modele są proceduralne (prymitywy z cel-shadingiem). Architektura pozwala podmienić `models/*_model.gd` na sceny GLTF z własnym szkieletem.
- Boty grają sensownie, ale BRUTE czasem zbyt rzadko dochodzi do walki wręcz. Warto dostroić jego podchodzenie.
- Do zrobienia: rozdzielczość tekstur fontów (własny font zamiast systemowego), wibracje (haptics), samouczek, kolejka matchmakingu, ranking, więcej bohaterów i map.
