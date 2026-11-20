#!/bin/sh
# Converts build/promo-shots/*.png into promo/images/*.jpg. Run after the PROMO_SHOTS test.
set -eu
apk add -q --no-cache imagemagick imagemagick-jpeg >/dev/null

mkdir -p promo/images
for png in build/promo-shots/*.png; do
  magick "$png" -strip -interlace JPEG -sampling-factor 4:4:4 -quality 85 \
    "promo/images/$(basename "${png%.png}").jpg"
done

chown -R "${HOST_UID:-0}:${HOST_GID:-0}" promo/images
