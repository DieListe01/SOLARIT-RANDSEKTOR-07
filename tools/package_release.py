"""Package a verified portable Windows build; never includes source or local data."""
from pathlib import Path
import sys
import zipfile

root = Path(__file__).resolve().parents[1]
version = sys.argv[1]
if not all(part.isdigit() for part in version.split('.')):
    raise SystemExit('Expected numeric release version')
build = root/'build'
with zipfile.ZipFile(build/f'ASHLINE-{version}-Windows.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in ['ASHLINE.exe','Spielstart.txt','LICENSE','THIRD_PARTY_NOTICES.md','GODOT-LICENSES.txt']:
        archive.write(build/name, name)
path=build/f'ASHLINE-{version}-Windows.zip'
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None
    print(path.name, len(archive.namelist()), 'files', path.stat().st_size, 'bytes; CRC verified')
