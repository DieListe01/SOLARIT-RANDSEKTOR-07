"""Fetch only the official Windows release member of Godot's template archive.

HTTP ranges avoid downloading the 1.3 GB cross-platform archive. Build tool only.
"""
import io
import urllib.request
import zipfile
from pathlib import Path

URL = 'https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'

class RemoteArchive(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL, method='HEAD'), timeout=30) as r:
            self.length = int(r.headers['Content-Length'])
        self.position = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.position
    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position + offset if whence == 1 else self.length + offset
        return self.position

    def read(self, size=-1):
        if size == 0: return b''
        stop = self.length if size < 0 else min(self.length, self.position + size)
        if stop <= self.position: return b''
        request = urllib.request.Request(URL, headers={'Range': f'bytes={self.position}-{stop-1}'})
        with urllib.request.urlopen(request, timeout=120) as r:
            if r.status != 206: raise RuntimeError('Server did not honor HTTP range request')
            data = r.read()
        self.position += len(data)
        return data

root = Path(__file__).resolve().parents[1]
target = root / 'tools' / 'windows_release_x86_64.exe'
with zipfile.ZipFile(RemoteArchive()) as archive:
    member = 'templates/windows_release_x86_64.exe'
    data = archive.read(member)  # zipfile also verifies the archive member's CRC.
    target.write_bytes(data)
    print(f'Official Godot 4.7.2 template: {len(data):,} bytes -> {target}')
