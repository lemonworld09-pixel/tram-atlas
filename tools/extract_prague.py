"""Make the small, attributed demo ZIP from PID's 23 Nov 2026 GTFS snapshot.

Usage: python tools/extract_prague.py path/to/PID_GTFS.zip demo/data/prague-22.zip
Standard library only. This is a data preparation tool, not the scene importer.
"""
import csv
import io
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


DAY = "20261123"
NAMES = ["Národní divadlo", "Újezd", "Tyršův dům"]
TIMES = ["10:00:00", "10:02:00", "10:04:00"]


def rows(archive, table):
    with archive.open(table + ".txt") as raw:
        yield from csv.DictReader(io.TextIOWrapper(raw, "utf-8-sig", newline=""))


def write_table(out, table, fields, records):
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fields.split(), extrasaction="ignore")
    writer.writeheader()
    writer.writerows(records)
    info = ZipInfo(table + ".txt", (2026, 11, 23, 0, 0, 0))
    out.writestr(info, stream.getvalue().encode("utf-8"), compress_type=ZIP_DEFLATED)


def main(source, dest):
    with ZipFile(source) as archive:
        calendar = list(rows(archive, "calendar"))
        exceptions = list(rows(archive, "calendar_dates"))
        weekday = date.fromisoformat("2026-11-23").strftime("%A").lower()
        active = {r["service_id"] for r in calendar
                  if r["start_date"] <= DAY <= r["end_date"] and r[weekday] == "1"}
        for r in exceptions:
            if r["date"] == DAY:
                (active.add if r["exception_type"] == "1" else active.discard)(r["service_id"])
        route = next(r for r in rows(archive, "routes")
                     if r["route_short_name"] == "22" and r["route_type"] == "0")
        trips = {r["trip_id"]: r for r in rows(archive, "trips")
                 if r["route_id"] == route["route_id"] and r["service_id"] in active
                 and r["trip_headsign"] == "Bílá Hora"}
        stops = {r["stop_id"]: r for r in rows(archive, "stops")}
        candidates = defaultdict(list)
        for row in rows(archive, "stop_times"):
            if row["trip_id"] in trips:
                candidates[row["trip_id"]].append(row)
        for trip_id, calls in candidates.items():
            calls.sort(key=lambda r: int(r["stop_sequence"]))
            names = [stops[r["stop_id"]]["stop_name"] for r in calls]
            times = [r["arrival_time"] for r in calls]
            start = next((i for i in range(len(calls)) if names[i:i+3] == NAMES
                          and times[i:i+3] == TIMES), None)
            if start is not None:
                break
        else:
            raise SystemExit("This archive does not contain the specified 23 Nov 2026 crossing.")
        trip = trips[trip_id]
        shape = [r for r in rows(archive, "shapes") if r["shape_id"] == trip["shape_id"]]
        service = trip["service_id"]
        # Keep the whole trip, so the example also exercises the editor's stop range.
        stop_ids = {r["stop_id"] for r in calls}
        with ZipFile(dest, "w") as out:
            write_table(out, "agency", "agency_id agency_name agency_url agency_timezone",
                        [r for r in rows(archive, "agency") if r["agency_id"] == route["agency_id"]])
            write_table(out, "routes", "route_id agency_id route_short_name route_long_name route_type", [route])
            write_table(out, "trips", "route_id service_id trip_id trip_headsign direction_id shape_id", [trip])
            write_table(out, "calendar", "service_id monday tuesday wednesday thursday friday saturday sunday start_date end_date",
                        [r for r in calendar if r["service_id"] == service])
            write_table(out, "calendar_dates", "service_id date exception_type",
                        [r for r in exceptions if r["service_id"] == service])
            write_table(out, "stops", "stop_id stop_name stop_lat stop_lon",
                        [r for ident, r in stops.items() if ident in stop_ids])
            write_table(out, "stop_times", "trip_id arrival_time departure_time stop_id stop_sequence shape_dist_traveled", calls)
            write_table(out, "shapes", "shape_id shape_pt_lat shape_pt_lon shape_pt_sequence shape_dist_traveled", shape)
        print(trip)
        print("Selected zero-based indices:", start, start + 2)
        for r in calls[start:start+3]:
            print(stops[r["stop_id"]], r)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
