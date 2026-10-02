# ── Stage 1: build mkp224o + pcm_rms ─────────────────────────────────────────
# Compiled in (rather than pulled as a Docker image) so the vanity feature needs
# no Docker socket. Pinned to a fixed commit for reproducible, auditable builds.
FROM debian:trixie-slim AS builder
ARG MKP224O_REF=5172c0fd71740ca0b11da8149a2575dcf331d7ab
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gcc \
    libc6-dev \
    make \
    autoconf \
    automake \
    libsodium-dev \
    pkg-config \
    git \
    && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/cathugger/mkp224o.git /tmp/mkp224o \
    && cd /tmp/mkp224o \
    && git checkout "${MKP224O_REF}" \
    && ./autogen.sh && ./configure && make
RUN printf '%s\n' \
    '#include <stdio.h>' \
    '#include <math.h>' \
    '#include <stdint.h>' \
    'int main(void) {' \
    '    int16_t buf[4096];' \
    '    double sum = 0.0;' \
    '    long count = 0;' \
    '    size_t n;' \
    '    while ((n = fread(buf, sizeof(int16_t), 4096, stdin)) > 0) {' \
    '        for (size_t i = 0; i < n; i++) {' \
    '            double s = (double)buf[i];' \
    '            sum += s * s;' \
    '        }' \
    '        count += n;' \
    '    }' \
    '    if (count == 0) { printf("-91.0\n"); return 0; }' \
    '    double rms = sqrt(sum / count);' \
    '    double dbfs = 20.0 * log10(rms / 32768.0);' \
    '    printf("%.1f\n", dbfs);' \
    '    return 0;' \
    '}' > /tmp/pcm_rms.c \
    && gcc -O2 -o /tmp/pcm_rms /tmp/pcm_rms.c -lm

# ── Stage 2: runtime image ───────────────────────────────────────────────────
FROM debian:trixie-slim

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    tor \
    opus-tools \
    socat \
    openssl \
    alsa-utils \
    pulseaudio-utils \
    qrencode \
    ncurses-bin \
    libsodium23 \
    python3 \
    libopus0 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -G audio,debian-tor partyline

# Vanity .onion generator (Docker-only feature). libsodium23 above is its runtime dep.
COPY --from=builder /tmp/mkp224o/mkp224o /usr/local/bin/mkp224o
COPY --from=builder /tmp/pcm_rms /usr/local/bin/pcm_rms

# Tor on Debian uses the 'debian-tor' user.
# Pre-create data directories with correct permissions.
RUN mkdir -p /var/lib/tor/hidden_service /data/.partyline \
    && chmod 700 /var/lib/tor /var/lib/tor/hidden_service \
    && chown -R debian-tor:debian-tor /var/lib/tor \
    && chown -R partyline:partyline /data/.partyline

COPY docker/entrypoint.sh /
COPY --chown=partyline:partyline tor-party-line.sh /
RUN chmod +x /entrypoint.sh /tor-party-line.sh

ENV LANG=C.UTF-8
ENV DOCKER_MODE=1

ENTRYPOINT ["/entrypoint.sh"]
