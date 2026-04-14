

# Fix PWA Icons

## Problem
Both `icon-192.png` and `icon-512.png` are identical 1024×1024 files. The manifest declares them as 192×192 and 512×512, so platforms ignore them and show a fallback "S" (from "StartClock").

## Fix
1. Resize the uploaded image to actual 192×192 and 512×512 using Python Pillow
2. Also add an `apple-touch-icon` link in `index.html` (iOS doesn't use the manifest for icons)
3. Add `purpose: "any maskable"` to manifest icons for Android adaptive icons

## Files changed
- `public/icon-192.png` — resized to 192×192
- `public/icon-512.png` — resized to 512×512
- `index.html` — add `<link rel="apple-touch-icon" href="/icon-192.png">`
- `public/manifest.json` — add `purpose` field to icons

