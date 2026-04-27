"""
Maya City CBHI — Icon Generator
================================
Resizes the source logo into all required icon sizes for:
  - Web PWA icons (all 3 Flutter apps)
  - Android launcher icons (member app)
  - Web favicon (all 3 Flutter apps)

Usage:
  1. Save the Maya City CBHI logo as:  scripts/logo_source.png
  2. Run:  python scripts/generate_icons.py

Requirements:  pip install Pillow
"""

from pathlib import Path
from PIL import Image, ImageOps

# ── Source image ──────────────────────────────────────────────────────────────
SOURCE = Path(__file__).parent / "logo_source.png"

if not SOURCE.exists():
    print(f"ERROR: Source image not found at {SOURCE}")
    print("Please save the Maya City CBHI logo as:  scripts/logo_source.png")
    raise SystemExit(1)

src = Image.open(SOURCE).convert("RGBA")

# Make it square by padding with white (the logo has a white background)
w, h = src.size
size = max(w, h)
square = Image.new("RGBA", (size, size), (255, 255, 255, 255))
square.paste(src, ((size - w) // 2, (size - h) // 2))

print(f"Source image: {w}x{h} → padded to {size}x{size}")


def save(img: Image.Image, path: Path, size: int, mode: str = "RGBA") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    resized = img.resize((size, size), Image.LANCZOS)
    if mode == "RGB":
        # Flatten alpha onto white background for JPEG-style PNGs
        bg = Image.new("RGB", resized.size, (255, 255, 255))
        bg.paste(resized, mask=resized.split()[3])
        resized = bg
    resized.save(path, "PNG", optimize=True)
    print(f"  ✓ {path}  ({size}x{size})")


# ── Apps ──────────────────────────────────────────────────────────────────────
APPS = [
    Path("member_based_cbhi"),
    Path("cbhi_admin_desktop"),
    Path("cbhi_facility_desktop"),
]

print("\n── Asset logo (used in app UI) ──────────────────────────────────────────")
for app in APPS:
    save(square, app / "assets/images/logo.png", 512)

print("\n── Web PWA icons ────────────────────────────────────────────────────────")
for app in APPS:
    web_icons = app / "web/icons"
    save(square, web_icons / "Icon-192.png",          192)
    save(square, web_icons / "Icon-512.png",          512)
    save(square, web_icons / "Icon-maskable-192.png", 192)
    save(square, web_icons / "Icon-maskable-512.png", 512)

print("\n── Web favicon ──────────────────────────────────────────────────────────")
for app in APPS:
    save(square, app / "web/favicon.png", 32, mode="RGB")

print("\n── Android launcher icons (member app) ──────────────────────────────────")
ANDROID_RES = Path("member_based_cbhi/android/app/src/main/res")
android_sizes = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}
for folder, px in android_sizes.items():
    save(square, ANDROID_RES / folder / "ic_launcher.png",          px, mode="RGB")
    save(square, ANDROID_RES / folder / "ic_launcher_round.png",    px)
    save(square, ANDROID_RES / folder / "ic_launcher_foreground.png", px)

print("\n✅ All icons generated successfully!")
print("\nNext steps:")
print("  1. Run 'flutter pub get' in each app")
print("  2. For Android: rebuild the app to pick up new launcher icons")
print("  3. For web: the icons are picked up automatically on next build")
