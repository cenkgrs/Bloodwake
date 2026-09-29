#!/usr/bin/env python3
"""Resize the textures embedded in a prop .glb, in place.

Generators hand back 4096 maps as a matter of course. Seen through this game's
orthographic camera a boulder covers about eighty pixels, so almost all of that
is memory nobody looks at - and the project ships a Mobile profile where eighteen
4K maps across six props would not survive.

Normal maps stay PNG because JPEG ringing on a normal reads as dented metal;
colour and roughness/metallic are re-encoded as JPEG where they already were.

    python3 godot/tools/shrink_prop_textures.py <max_px> <file.glb> ...
"""
import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image

GLB_MAGIC = 0x46546C67
JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942


def read(path):
    raw = path.read_bytes()
    assert struct.unpack_from('<I', raw, 0)[0] == GLB_MAGIC, 'not a glb: %s' % path
    offset, meta, blob = 12, None, b''
    while offset < len(raw):
        length, kind = struct.unpack_from('<II', raw, offset)
        chunk = raw[offset + 8: offset + 8 + length]
        if kind == JSON_CHUNK:
            meta = json.loads(chunk.decode('utf8'))
        elif kind == BIN_CHUNK:
            blob = chunk
        offset += 8 + length
    return meta, blob


def pad(data, filler):
    return data + filler * (-len(data) % 4)


def write(path, meta, blob):
    js = pad(json.dumps(meta, separators=(',', ':')).encode('utf8'), b' ')
    bin_data = pad(blob, b'\x00')
    total = 12 + 8 + len(js) + 8 + len(bin_data)
    with open(path, 'wb') as out:
        out.write(struct.pack('<III', GLB_MAGIC, 2, total))
        out.write(struct.pack('<II', len(js), JSON_CHUNK))
        out.write(js)
        out.write(struct.pack('<II', len(bin_data), BIN_CHUNK))
        out.write(bin_data)


def shrink(path, limit):
    meta, blob = read(path)
    images = meta.get('images', [])
    if not images:
        print('%-18s no embedded textures' % path.name)
        return

    # Every buffer view is rebuilt into a fresh blob, so accessors keep working
    # while the image views move and change length.
    views = meta['bufferViews']
    owner = {img['bufferView']: i for i, img in enumerate(images) if 'bufferView' in img}
    replacement = {}
    for view_index, image_index in owner.items():
        view = views[view_index]
        start = view.get('byteOffset', 0)
        source = blob[start: start + view['byteLength']]
        picture = Image.open(io.BytesIO(source))
        if max(picture.size) <= limit:
            continue
        ratio = limit / float(max(picture.size))
        picture = picture.resize((max(1, int(picture.width * ratio)),
                                  max(1, int(picture.height * ratio))), Image.LANCZOS)
        mime = images[image_index].get('mimeType', 'image/png')
        buffer = io.BytesIO()
        if mime == 'image/jpeg':
            picture.convert('RGB').save(buffer, 'JPEG', quality=90, optimize=True)
        else:
            picture.save(buffer, 'PNG', optimize=True)
        replacement[view_index] = buffer.getvalue()

    if not replacement:
        print('%-18s already within %d' % (path.name, limit))
        return

    rebuilt = bytearray()
    for index, view in enumerate(views):
        start = view.get('byteOffset', 0)
        data = replacement.get(index, blob[start: start + view['byteLength']])
        while len(rebuilt) % 4:
            rebuilt.append(0)
        view['byteOffset'] = len(rebuilt)
        view['byteLength'] = len(data)
        rebuilt += data
    meta['buffers'][0]['byteLength'] = len(rebuilt)

    was = path.stat().st_size
    write(path, meta, bytes(rebuilt))
    print('%-18s %6.1f MB -> %5.1f MB  (%d textures capped at %d)'
          % (path.name, was / 1048576, path.stat().st_size / 1048576, len(replacement), limit))


if __name__ == '__main__':
    cap = int(sys.argv[1])
    for name in sys.argv[2:]:
        shrink(Path(name), cap)
