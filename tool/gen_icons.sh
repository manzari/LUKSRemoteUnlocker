#!/bin/sh
# Renders docs/logo.svg into the launcher icons and the in-app asset. Run via `make icons`.
set -eu
apk add -q --no-cache rsvg-convert imagemagick >/dev/null

SRC=docs/logo.svg
RES=app/android/app/src/main/res
IOS=app/ios/Runner/Assets.xcassets/AppIcon.appiconset
SQUARE=$(mktemp -u).svg
sed 's/rx="112"/rx="0"/' "$SRC" > "$SQUARE"

render() { rsvg-convert -w "$2" -h "$2" "$1" -o "$3"; }

for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  render "$SRC" "${d#*:}" "$RES/mipmap-${d%:*}/ic_launcher.png"
done

render "$SRC" 512 app/assets/logo.png

# iOS icons are full-bleed and must not carry an alpha channel.
for i in 20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 29x29@3x:87 \
         40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 60x60@3x:180 \
         76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167 1024x1024@1x:1024; do
  out="$IOS/Icon-App-${i%:*}.png"
  render "$SQUARE" "${i#*:}" "$out"
  magick "$out" -alpha off "$out"
done

rm -f "$SQUARE"
chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$RES" "$IOS" app/assets
