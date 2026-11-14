FROM dart:3.14.0-sdk

ARG UID=1000
ARG GID=1000

RUN apt-get update \
 && apt-get install -y --no-install-recommends git openssh-client \
 && rm -rf /var/lib/apt/lists/* \
 && (getent group "${GID}" >/dev/null || groupadd -g "${GID}" dev) \
 && useradd -o -m -u "${UID}" -g "${GID}" -s /bin/bash dev \
 && install -d -o "${UID}" -g "${GID}" /work

USER dev
WORKDIR /work
ENV HOME=/home/dev \
    PUB_CACHE=/home/dev/.pub-cache \
    PATH=/home/dev/.pub-cache/bin:/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN dart --disable-analytics >/dev/null && mkdir -p "${PUB_CACHE}"
