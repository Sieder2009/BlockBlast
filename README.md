# BlockBlast

Ein Block-Puzzle im Stil von *Block Blast*, gebaut mit **Flutter**: Teile per Drag-and-Drop
auf ein 8 × 8-Feld ziehen, volle Reihen und Spalten abräumen, Rekord jagen.

**Im Browser spielen:** [sieder2009.github.io/Siederhub/projects/blockblast](https://sieder2009.github.io/Siederhub/projects/blockblast/)

## Spielregeln

- Unten liegen immer drei Teile. Ziehe sie aufs Feld. Gedreht wird nicht, die Teile kommen
  schon in ihrer Lage.
- Jede volle Reihe und jede volle Spalte verschwindet.
- Sind alle drei Teile gelegt, kommen drei neue.
- Passt keines der übrigen Teile mehr irgendwo hin, ist das Spiel vorbei.

## Punkte

| Aktion | Punkte |
|---|---|
| Teil legen | 1 Punkt pro Block |
| Linien abräumen | Linien² × 10 (1 Linie = 10, 2 = 40, 3 = 90 …) |
| Combo (mehrere Züge hintereinander mit Abräumen) | +10 je Combo-Stufe ab der zweiten |

## Was drin ist

- **37 Formen** (Einzelblock bis 5er-Stücke, L, T, S/Z, Quadrate) in 8 Farben.
- **Faire Teile:** Bei einem fast vollen Feld ist unter den drei neuen Teilen immer
  mindestens eins, das noch passt.
- **Vorschau beim Ziehen:** Das Feld zeigt grün/rot, ob das Teil passt, und hebt die Linien
  hervor, die beim Ablegen verschwinden würden.
- **Speichern:** Rekord und laufendes Spiel werden lokal gespeichert (`shared_preferences`).
  Nach einem Neustart geht es genau dort weiter.
- Punkte-Popups, Haptik-Feedback, Nachfrage vor „Neues Spiel“, „Neuer Rekord!“ am Ende.

## Starten

Voraussetzung: [Flutter](https://docs.flutter.dev/get-started/install) (stable, Dart ≥ 3.12).

```bash
flutter pub get
flutter run                 # auf Handy, Emulator oder Desktop
flutter run -d chrome       # im Browser
flutter test                # Widget-Test
```

## Builds

```bash
flutter build apk --release     # Android
flutter build windows           # Windows
flutter build web --release     # Web
```

Der Android-Signierschlüssel (`android/key.properties`, `*.jks`) ist absichtlich nicht im Repo.

Die Web-Version wird nicht hier gebaut, sondern vom [Siederhub](https://github.com/Sieder2009/Siederhub)-Workflow.
Er holt sich dieses Repo bei jedem Deploy frisch und veröffentlicht es unter `/projects/blockblast/`.
Nach Änderungen hier dort unter *Actions → Pages → Run workflow* neu starten.

## Aufbau

```
lib/main.dart     Spiellogik, Drag-and-Drop, Punkte, Speichern, Oberfläche
lib/shapes.dart   Formen, Farben, Teile-Zufall
test/             Widget-Test
```
