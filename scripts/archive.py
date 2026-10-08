"""Create the release ZIP from an already verified signed package."""
from pathlib import Path
import sys
from zipfile import ZIP_DEFLATED, ZipFile

package, output = map(Path, sys.argv[1:])
with ZipFile(output, "x", ZIP_DEFLATED) as archive:
    for path in sorted(package.iterdir()):
        archive.write(path, f"{package.name}/{path.name}")
