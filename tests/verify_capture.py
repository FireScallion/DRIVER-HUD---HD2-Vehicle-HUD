"""Verify the exact supplied build capture without executing game code.

python tests/verify_capture.py /path/to/game_module_20260922T100015_513694Z.zip
This is a reproduction test for the captured evidence, not a generic live-image hash gate.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_DISK = '73374bd4e38386beb9a23bef480082b67d457ebc77485fbec5f488b4e95e201f'
EXPECTED_IMAGE = 'bade709aaec7fb7c7c9b2725d0ccf18c0a84249dc4d6e86c01d89d45723a6382'

def verify(path: Path) -> dict:
    checks = []
    def check(name, ok):
        if not ok:
            raise ValueError(name)
        checks.append(name)
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        meta_names = [n for n in names if n.endswith('capture.json')]
        bin_names = [n for n in names if n.endswith('game.module.mem.bin')]
        check('unambiguous metadata and image', len(meta_names) == len(bin_names) == 1)
        meta = json.loads(archive.read(meta_names[0]))
        image = archive.read(bin_names[0])
    check('complete capture', meta['status'] == 'COMPLETE' and meta['missing_bytes'] == 0)
    check('disk fingerprint matches supplied build', meta['disk_sha256'] == EXPECTED_DISK)
    check('length and read accounting', len(image) == meta['read_bytes'] == meta['module_size'] == 0x4770000)
    digest = hashlib.sha256(image).hexdigest()
    check('image SHA256 recomputed', digest == EXPECTED_IMAGE)
    check('recorded memory digest', meta['memory_sha256'] == digest)
    check('DOS signature', image[:2] == b'MZ')
    pe = struct.unpack_from('<I', image, 0x3c)[0]
    check('PE signature', image[pe:pe+4] == b'PE\0\0')
    machine, sections, timestamp = struct.unpack_from('<HHI', image, pe+4)
    check('machine sections timestamp', (machine, sections, timestamp) == (0x8664,16,0x6aa96b14))
    check('image size checksum', struct.unpack_from('<I',image,pe+80)[0] == 0x4770000 and struct.unpack_from('<I',image,pe+88)[0] == 0xf05b12)
    native = (ROOT/'src/native_reader.lua').read_text()
    block = native.split(' N.guards={',1)[1].split(' function N.check_module',1)[0]
    guards = re.findall(r'\{(0x[0-9a-f]+),"([0-9a-f]+)"\}', block)
    check('all 14 production ranges extracted', len(guards) == 14)
    for address, hex_bytes in guards:
        rva, data = int(address,16), bytes.fromhex(hex_bytes)
        check('production guard '+address, image[rva:rva+len(data)] == data)
    return {'archive':path.name, 'module_bytes':len(image), 'disk_sha256':EXPECTED_DISK,
            'image_sha256':digest,'checks':checks,'count':len(checks),'fails':0,
            'heap_captured':False,'live_runtime_test':False}

if __name__ == '__main__':
    if len(sys.argv)!=2:
        sys.exit(__doc__)
    try:
        result=verify(Path(sys.argv[1]))
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, struct.error) as exc:
        sys.exit('Capture verification failed: '+str(exc))
    print(json.dumps(result, indent=2))
