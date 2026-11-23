# Tram Atlas for Godot 4.6.1

Place this directory at `res://addons/tram_atlas/` and enable **Tram Atlas** in **Project → Project Settings → Plugins**.

1. Open the **Tram Atlas** editor dock and choose **Select GTFS ZIP…**.
2. Choose a service date, apply it, and select your route, direction or destination, trip and consecutive stop range.
3. Choose **Generate route scene…**, save the scene inside your project and press **F6**.
4. To use a custom vehicle, select the generated scene root and assign **Presentation → Vehicle Scene** in the Inspector. Use a PackedScene with a Node3D root, +Y up, −Z forward and the origin at rail height.

Select **Track** to edit the curve. Each Godot unit represents one metre. The named markers in **Stops** contain their GTFS IDs, arrival times and departure times. The root stores the timetable and distance offsets. If you edit the curve length, update these offsets and marker positions.

The saved scene contains its route geometry and schedule. The ZIP is only needed during import. Set **Preview Enabled** off to supply your own surroundings or UI. The root exposes `seek(service_seconds)`, `playing`, `speed`, and the `sampled(seconds)` signal.

Import requires a GTFS Schedule feed with timed calls and published shape geometry. Service dates include calendar exceptions. A clock reading of 24:15 belongs to the preceding service date. Headway-based templates are flagged in the dock. Between timetable entries the vehicle uses distance interpolation.

MIT license. The owner of each GTFS feed sets its data license.
