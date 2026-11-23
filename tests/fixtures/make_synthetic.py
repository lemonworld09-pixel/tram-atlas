"""Rebuild the hand-authored synthetic GTFS fixture (no external data)."""
import csv
import io
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


def table(archive, name, header, rows):
    out = io.StringIO(newline="")
    writer = csv.writer(out)
    writer.writerow(header.split())
    writer.writerows(rows)
    info = ZipInfo(name + ".txt", (2026, 1, 1, 0, 0, 0))
    archive.writestr(info, out.getvalue().encode("utf-8-sig"), ZIP_DEFLATED)


night = 'Night, "A"'
with ZipFile(Path(__file__).with_name("synthetic-night.zip"), "w") as z:
    table(z, "agency", "agency_id agency_name agency_url agency_timezone", [
        ("S", "Synthetic Test Transit", "https://example.org", "Europe/Prague")])
    table(z, "routes", "route_id agency_id route_short_name route_type",
          [("test", "S", "Synthetic N", 0), ("frequency-test", "S", "Synthetic F", 0)])
    table(z, "stops", "stop_id stop_name stop_lat stop_lon", [
        ("A", "Nábřeží, sever", 50.0, 14.0),
        ("B", 'Můstek "B"', 50.001, 14.002),
        ("C", "Závodní", 50.001, 14.004)])
    table(z, "trips", "route_id service_id trip_id trip_headsign direction_id shape_id", [
        ("test", "usual", "daytime", "Závodní", 0, "measured"),
        ("test", "usual", "missing", "Závodní", 0, ""),
        ("test", "extra", night, "Závodní", 0, 'rail, "north"'),
        ("frequency-test", "extra", "headway", "Závodní", 0, "measured")])
    table(z, "frequencies", "trip_id start_time end_time headway_secs exact_times", [
        ("headway", "23:00:00", "24:00:00", 300, 0), ("headway", "24:00:00", "25:00:00", 600, 1)])
    table(z, "calendar", "service_id monday tuesday wednesday thursday friday saturday sunday start_date end_date",
          [("usual", 1, 1, 0, 0, 0, 0, 0, "20261101", "20261130")])
    table(z, "calendar_dates", "service_id date exception_type",
          [("usual", "20261123", 2), ("extra", "20261123", 1)])
    # Key columns deliberately appear in the middle. Records for each ID are
    # discontiguous and sequence values are sparse and out of file order.
    shapes, times = [], []
    for seq, lat, lon, measure in [(80, 50.001, 14.004, 40), (30, 50.001, 14.002, 24),
                                   (20, 50.0, 14.002, 18), (10, 50.0, 14.0, 10)]:
        for shape in ('rail, "north"', "measured"):
            shapes.append((seq, shape, lat, lon, measure if shape == "measured" else ""))
    for seq, stop, arrival, departure, measure in [
        (60, "C", "24:24:00", "24:24:00", 40), (10, "A", "23:59:00", "23:59:00", 10),
        (25, "B", "24:15:00", "24:16:00", 24)]:
        for trip in (night, "daytime", "missing", "headway"):
            times.append((seq, trip, stop, arrival, departure, measure if trip == "daytime" else ""))
    table(z, "shapes", "shape_pt_sequence shape_id shape_pt_lat shape_pt_lon shape_dist_traveled", shapes)
    table(z, "stop_times", "stop_sequence trip_id stop_id arrival_time departure_time shape_dist_traveled", times)
