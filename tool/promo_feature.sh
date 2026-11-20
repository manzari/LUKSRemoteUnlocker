#!/bin/sh
# Renders promo/feature-graphic.svg into the 1024x500 Play Store feature graphic. Run via `make promo-feature`.
set -eu
# Without shared-mime-info librsvg cannot tell that the embedded screenshot is a JPEG.
apk add -q --no-cache rsvg-convert imagemagick font-inter shared-mime-info >/dev/null

OUT=promo/images/feature-graphic.png
rsvg-convert -w 1024 -h 500 promo/feature-graphic.svg -o "$OUT"
# Play rejects a PNG with an alpha channel.
magick "$OUT" -alpha off -strip "PNG24:$OUT"

chown "${HOST_UID:-0}:${HOST_GID:-0}" "$OUT"
