"""Package a verified local export; never includes caches, saves or engine tooling."""
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
with zipfile.ZipFile(build/f'ASHLINE-{version}-Source.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for directory in ['scripts','scenes','data','assets','tests','docs','installer']:
        for file in sorted((root/directory).rglob('*')):
            if file.is_file(): archive.write(file, file.relative_to(root).as_posix())
    for file in sorted((root/'.github').rglob('*')):
        if file.is_file(): archive.write(file, file.relative_to(root).as_posix())
    for file in sorted((root/'tools').glob('*')):
        if file.is_file() and file.suffix in ['.py','.ps1','.gd','.uid']:
            archive.write(file, file.relative_to(root).as_posix())
    for file in sorted(root.iterdir()):
        if file.is_file() and file.suffix in ['.godot','.cfg','.md','.txt','.cmd','.ps1'] or file.is_file() and file.name in ['LICENSE','.gitignore']:
            archive.write(file, file.name)
for kind in ['Windows','Source']:
    path=build/f'ASHLINE-{version}-{kind}.zip'
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        print(path.name, len(archive.namelist()), 'files', path.stat().st_size, 'bytes; CRC verified')
