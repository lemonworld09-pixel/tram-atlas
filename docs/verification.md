# Verification

Godot 4.6.1 Standard, official build `14d19694e`, Windows, Compatibility renderer (OpenGL 3.3 on GeForce RTX 5070). Graphical editor tests used native Godot editor controls and playback. Repeatable checks use Godot's command-line scene runner.

## Prague and the editor

The official November 23 PID ZIP contained **483** active line 22 trips on the service date. The full archive and the bundled one-trip extract independently produced the same 23 curve vertices, three stop names, stop offsets and service seconds. The scene used in the diorama is `demo/data/crossing.tscn`, written by the addon's own feed reader and scene builder. The separate file `demo/prague.tscn` instances it and adds the model, scenery and UI.

In a separate blank project with the addon copied in, a temporary QA driver exercised the graphical editor's ZIP and scene-save dialogs, service-date Apply, route, destination, trip and stop-range controls. It checked an inactive day, selected the November 23 trip and stops 27–29, generated and saved the scene, closed the editor, reopened it in another editor process and invoked **Play Current Scene**. The saved path, follower, stop markers, default vehicle, following camera and timetable were present. Test automation invoked native controls and editor actions. The driver was excluded from the shipped addon.

The graphical editor also enabled the addon from a disabled state and disabled it after a full import. In the scripted second-save check, Godot 4.6.1 emitted an internal `List::erase` diagnostic after returning a successful save. The same diagnostic reproduced with the addon disabled on a plain cube scene. Reloaded data and runtime checks passed in both transit projects.

The same editor workflow was repeated against the **full 45,921,793-byte PID archive** using the final addon. It listed 865 routes and eight direction/destination groups on line 22. The selected trip and stops again produced 23 vertices. After restart, Play Current Scene, the 12× generic speed setting, the 10:01 midpoint and reverse scrubbing all passed.

| Prague service clock | Position on route | Local position (east X, south Z) |
| --- | ---: | ---: |
| 10:00:00 · Národní divadlo | 0.00 m | (0.00, 3.00) |
| 10:01:00 · on Most Legií | 315.64 m | (−315.38, 15.70) |
| 10:02:00 · Újezd | 631.28 m | (−630.69, 29.69) |
| 10:04:00 · Tyršův dům | 1,004.62 m | (−689.06, −303.12) |

The graphical demo test clicks the stop buttons out of order, drags the scrubber backwards from 10:03 to 10:01, and checks the vehicle's direction against the curve tangent. It also switches cameras both ways, changes speed, pauses, resumes, reaches the terminus and replays. Stop positions agree within 2 cm with a separate calculation from PID's shape CSV. The captures in `docs/images` come from the running game viewport. [Overview](images/prague-crossing.png) · [Tram view](images/prague-tram-view.png)

The controls and camera switches passed at window sizes **960 × 600**, **1280 × 800**, **1440 × 900** and **1920 × 1080**. Visual reviews covered the departure, the bridge and all three station positions in both cameras. The coupled rear car follows a second sample of the curved track. Reversing the service clock also restores the position of the excursion boats. Runtime verification covered Windows desktop on the named Godot build.

A clean copy in a directory with spaces had no `.godot` cache and no timetable ZIP. The Windows launcher imported all three fonts and opened the playable scene. The same copy then passed the graphical control and position tests. Playback uses the saved Godot resources.

## Second city and synthetic service

The full TriMet Schedule ZIP was also tested on **2026-11-23**. The graphical editor loaded all 82 routes. Searching for **193** selected **Portland Streetcar NS**, with 146 active trips on that date. Trip **18333343**, direction 0 toward **NW 23rd & Marshall**, stops **NW 18th & Northrup → NW 21st & Northrup → NW 22nd & Northrup**, produced 26 vertices and 547.71 m. The published arrivals were 05:39, 05:40 and 05:41. The generated scene was saved, reopened and played from the editor. The generic controls paused the trip, selected 12× and scrubbed back and forth. The vehicle matched each stop marker and faced the travel direction. The archive's SHA-256 was `e6c6a68e6b33232de60387552a84f9a2a860f31bafb749bf18f9d7eb64b4605c`. The TriMet download stays outside the shipped project. [TriMet GTFS source](https://developer.trimet.org/GTFS.shtml)

The **synthetic** archive `tests/fixtures/synthetic-night.zip` exercises calendar additions and removals, exception-only calendars, unordered records, quoted UTF-8 names, independent distance units, incomplete geometry and unsupported frequency templates. Its night trip arrives at its middle stop at 24:15:00 and leaves at 24:16:00. The runtime held at 254.14 m throughout the minute, moved forward, then returned to that same point on a reverse seek. Replacing the vehicle with a different PackedScene and reloading the saved route preserved the replacement.

## Reproduce

From the project folder, run the following with the Godot executable on your PATH. The first command prepares imported assets on a fresh checkout.

```sh
godot --headless --editor --import
godot --headless -s tests/feed_test.gd
godot --headless -s tests/night_playback.gd
godot --resolution 1440x900 -s tests/playback_qa.gd
godot --headless -s tests/public_feed.gd -- /path/to/TriMet.zip 193 2026-11-23
```

To regenerate the **saved route** from the committed example ZIP, run `godot --headless -s tools/build_crossing.gd`. It writes `demo/data/crossing.tscn`. To recreate the ZIP itself from the archived November 23 PID source, run `python tools/extract_prague.py /path/to/PID_GTFS.zip demo/data/prague-22.zip`. PID's public download rolls forward.

To rebuild the standalone addon package, run `python tools/package_addon.py`. All 24 shipped entries were checked byte-for-byte against the addon directory. A fresh project containing only the extracted addon then imported the full TriMet feed and passed the three-stop position test.
