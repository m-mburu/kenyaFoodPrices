"""Simplify a county polygon coverage while keeping shared borders aligned.

Build-time helper for build_county_display_geometry.R. Requires Shapely 2.1+;
the deployed R package reads the generated R data file and does not use Python.
"""

import csv
import sys
from pathlib import Path

import shapely
from shapely import (
    coverage_is_valid,
    coverage_simplify,
    from_wkb,
    get_num_coordinates,
    get_num_geometries,
    to_wkb,
)


input_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
tolerance_m = float(sys.argv[3])
csv.field_size_limit(sys.maxsize)

with input_path.open(newline="", encoding="utf-8") as input_file:
    rows = list(csv.DictReader(input_file, delimiter="\t"))

geometries = [from_wkb(bytes.fromhex(row["wkb"])) for row in rows]
if not coverage_is_valid(geometries):
    raise ValueError("Input county geometries are not a valid polygon coverage")

simplified = coverage_simplify(geometries, tolerance_m)
if not coverage_is_valid(simplified):
    raise ValueError("Simplified county geometries are not a valid coverage")

for row, original, display in zip(rows, geometries, simplified):
    if display.is_empty or not display.is_valid:
        raise ValueError(f"Invalid or empty display geometry: {row['GID_1']}")
    if get_num_geometries(display) != get_num_geometries(original):
        raise ValueError(f"Polygon components changed: {row['GID_1']}")
    point = original.representative_point()
    if not display.covers(point):
        raise ValueError(
            f"County representative point moved outside: {row['GID_1']}"
        )
    row["wkb"] = to_wkb(display, hex=True)
    row["display_points"] = str(get_num_coordinates(display))
    row["shapely_version"] = shapely.__version__

with output_path.open("w", newline="", encoding="utf-8") as output_file:
    writer = csv.DictWriter(
        output_file,
        fieldnames=[
            "GID_1",
            "county",
            "wkb",
            "display_points",
            "shapely_version",
        ],
        delimiter="\t",
        lineterminator="\n",
    )
    writer.writeheader()
    writer.writerows(rows)

print(
    f"Simplified {len(rows)} counties at {tolerance_m:g} m; "
    f"{sum(get_num_coordinates(g) for g in geometries)} to "
    f"{sum(int(row['display_points']) for row in rows)} coordinates."
)
