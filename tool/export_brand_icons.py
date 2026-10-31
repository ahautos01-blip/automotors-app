"""Export platform icons from the approved original without cropping its artwork.

Requires Pillow. Run with --check to verify exports without writing files.
"""
from pathlib import Path
import argparse
import json
import shutil
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/automotors_app_icon.png"

def targets():
    folder = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text(encoding="utf-8"))
    result = {}
    for item in contents["images"]:
        if "filename" not in item:
            continue
        scale = float(item["scale"].removesuffix("x"))
        width, height = (round(float(v) * scale) for v in item["size"].split("x"))
        result[folder / item["filename"]] = (width, height)
    for directory in ("web/icons", "icons", "publicacion/icons"):
        for name, size in (("Icon-192.png", 192), ("Icon-512.png", 512),
                           ("Icon-maskable-192.png", 192), ("Icon-maskable-512.png", 512),
                           ("favicon.png", 64)):
            result[ROOT / directory / name] = (size, size)
    for name in ("web/favicon.png", "favicon.png", "publicacion/favicon.png"):
        result[ROOT / name] = (16, 16)
    return result

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    with Image.open(SOURCE) as original:
        original.load()
        if original.size != (1024, 1024) or original.mode != "RGB":
            raise ValueError("The approved source must be an opaque RGB 1024 x 1024 PNG.")
        files = targets()
        for path, size in files.items():
            expected = original if size == original.size else original.resize(size, Image.Resampling.LANCZOS)
            if not args.check:
                if size == original.size:
                    shutil.copyfile(SOURCE, path)
                else:
                    expected.save(path, format="PNG", optimize=True)
            with Image.open(path) as actual:
                actual.load()
                if actual.mode != "RGB" or actual.size != size or actual.tobytes() != expected.tobytes():
                    raise ValueError("Incorrect icon export: " + str(path.relative_to(ROOT)))
    print(f"Verified {len(files)} opaque icon exports from the approved original.")

if __name__ == "__main__":
    main()
