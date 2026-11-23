"""Bundle the standalone addon. Run this after changing its source."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parents[1]
source = root / "addons" / "tram_atlas"
output = root / "dist" / "tram-atlas-addon.zip"
output.parent.mkdir(exist_ok=True)
with ZipFile(output, "w") as archive:
    for path in sorted(source.rglob("*")):
        if path.is_file():
            entry = ZipInfo(path.relative_to(root).as_posix(), (2026, 11, 23, 0, 0, 0))
            archive.writestr(entry, path.read_bytes(), compress_type=ZIP_DEFLATED)
print(output)
