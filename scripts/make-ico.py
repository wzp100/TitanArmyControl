#!/usr/bin/env python3
"""Assemble a multi-resolution Windows .ico from PNG files.

The repository keeps one source image (`Assets/AppIcon-1024.png`) and derives
the macOS .icns plus the Windows .ico from it, so both platforms ship the same
artwork. macOS' `sips` cannot write ICO, and PIL is not guaranteed to be
installed, so the container is packed directly: ICO is a small header followed
by the image payloads, and Windows Vista+ accepts PNG-compressed entries.

Usage:
    scripts/make-ico.py [--sizes 16,24,32,48,64,128,256] SRC.png OUT.ico
"""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path


def resize_with_sips(source: Path, size: int, destination: Path) -> None:
    """Downscale with the macOS-native image tool so no Python deps are needed."""
    if shutil.which("sips") is None:
        raise SystemExit("sips not found; this generator expects macOS")
    subprocess.run(
        ["sips", "-z", str(size), str(size), str(source), "--out", str(destination)],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def pack_ico(entries: list[tuple[int, bytes]]) -> bytes:
    header = struct.pack("<HHH", 0, 1, len(entries))
    offset = len(header) + 16 * len(entries)
    directory = bytearray()
    payload = bytearray()
    for size, data in entries:
        # 256 is encoded as 0 in the single-byte width/height fields.
        dimension = 0 if size >= 256 else size
        directory += struct.pack(
            "<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(data), offset
        )
        payload += data
        offset += len(data)
    return bytes(header + directory + payload)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--sizes", default="16,24,32,48,64,128,256")
    args = parser.parse_args()

    if not args.source.is_file():
        raise SystemExit(f"source image not found: {args.source}")

    sizes = [int(value) for value in args.sizes.split(",") if value.strip()]
    entries: list[tuple[int, bytes]] = []
    with tempfile.TemporaryDirectory() as scratch:
        for size in sizes:
            resized = Path(scratch) / f"icon-{size}.png"
            resize_with_sips(args.source, size, resized)
            entries.append((size, resized.read_bytes()))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    data = pack_ico(entries)
    args.output.write_bytes(data)
    print(f"wrote {args.output} ({len(data)} bytes, sizes {sizes})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
