#!/bin/sh
# Converts build/promo-shots/*.png into promo/images/*.webp. Run after the PROMO_SHOTS test.
set -eu
apk add -q --no-cache libwebp-tools >/dev/null

mkdir -p promo/images
for png in build/promo-shots/*.png; do
  cwebp -quiet -q 85 "$png" -o "promo/images/$(basename "${png%.png}").webp"
done

chown -R "${HOST_UID:-0}:${HOST_GID:-0}" promo/images
