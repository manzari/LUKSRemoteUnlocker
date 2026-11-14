# syntax=docker/dockerfile:1
FROM debian:trixie-slim AS base
ARG DEBIAN_FRONTEND=noninteractive

FROM base AS target
RUN apt-get update \
 && apt-get install -y --no-install-recommends dropbear-bin openssh-server busybox procps \
 && rm -rf /var/lib/apt/lists/* /etc/ssh/ssh_host_*
COPY --chmod=755 fake-cryptroot-unlock bench-init bench-ctl /usr/local/bin/
COPY sshd_config /etc/bench/sshd_config
COPY --chmod=600 fixtures/id_ed25519_bench.pub /etc/bench/authorized_keys
COPY --chmod=600 fixtures/id_ed25519_bench.pub /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh
EXPOSE 2222 22
ENTRYPOINT ["/usr/local/bin/bench-init"]

FROM base AS client
RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-client expect \
 && rm -rf /var/lib/apt/lists/*
COPY --chmod=600 fixtures/id_ed25519_bench fixtures/id_ed25519_wrong /root/.ssh/
RUN chmod 700 /root/.ssh
CMD ["sleep", "infinity"]
